"""
devcompanion — background job queue for agent-toolkit workspaces.

Usage:
    agent-toolkit devcompanion queue <project> [--template NAME] [--request "..."] [--id ID]
    agent-toolkit devcompanion run-once [--no-llm]
    agent-toolkit devcompanion status
    agent-toolkit devcompanion done <job-id>
    agent-toolkit devcompanion sync-todos

Aliases: dc
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


# ── workspace detection ───────────────────────────────────────────────────────

def _find_workspace() -> Path:
    """Return workspace root: AGENT_TOOLKIT_WORKSPACE env, or walk up from CWD."""
    env = os.environ.get("AGENT_TOOLKIT_WORKSPACE")
    if env:
        return Path(env).resolve()
    # Walk up looking for a marker (.devcompanion dir, AGENTS.md, or CLAUDE.md)
    cwd = Path.cwd().resolve()
    for parent in [cwd, *cwd.parents]:
        if (parent / ".devcompanion").is_dir():
            return parent
        if (parent / "AGENTS.md").exists() or (parent / "CLAUDE.md").exists():
            return parent
    return cwd


WORKSPACE_ROOT: Path = _find_workspace()
PROJECTS_DIR: Path   = WORKSPACE_ROOT / "projects"
TEMPLATES_DIR: Path  = WORKSPACE_ROOT / "templates" / "jobs"
KNOWLEDGE_TODOS: Path = WORKSPACE_ROOT / "knowledge" / "todos" / "pending.md"

_DC_HOME: Path = WORKSPACE_ROOT / ".devcompanion"
QUEUE_DIR: Path  = _DC_HOME / "queue"
RUNS_DIR: Path   = _DC_HOME / "runs"


# ── colors ────────────────────────────────────────────────────────────────────

_USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text


def _blue(t: str) -> str:   return _c("1;34", t)
def _green(t: str) -> str:  return _c("1;32", t)
def _yellow(t: str) -> str: return _c("1;33", t)
def _red(t: str) -> str:    return _c("1;31", t)
def _cyan(t: str) -> str:   return _c("0;36", t)


def _log(msg: str) -> None:  print(f"{_blue('[devcompanion]')} {msg}")
def _ok(msg: str) -> None:   print(f"{_green('[devcompanion]')} {msg}")
def _warn(msg: str) -> None: print(f"{_yellow('[devcompanion]')} {msg}")
def _err(msg: str) -> None:  print(f"{_red('[devcompanion]')} {msg}", file=sys.stderr)


# ── time helpers ──────────────────────────────────────────────────────────────

def _utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ── job I/O ───────────────────────────────────────────────────────────────────

def _read_job(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_job(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def _job_path(job_id: str) -> Path:
    return QUEUE_DIR / f"{job_id}.json"


# ── project resolution ────────────────────────────────────────────────────────

def _resolve_project(name: str) -> Path | None:
    """Resolve project name → real repo path via projects/ symlinks."""
    if not PROJECTS_DIR.is_dir():
        return None
    link = PROJECTS_DIR / name
    if link.is_symlink():
        return link.resolve()
    # Fuzzy: partial match
    for entry in PROJECTS_DIR.iterdir():
        if entry.is_symlink() and name in entry.name:
            return entry.resolve()
    return None


def _list_projects() -> list[tuple[str, Path | None]]:
    if not PROJECTS_DIR.is_dir():
        return []
    result = []
    for entry in sorted(PROJECTS_DIR.iterdir()):
        if entry.is_symlink():
            target = entry.resolve() if entry.resolve().is_dir() else None
            result.append((entry.name, target))
    return result


# ── template loading ──────────────────────────────────────────────────────────

def _load_template(name: str) -> dict:
    tpl_file = TEMPLATES_DIR / f"{name}.yaml"
    if not tpl_file.exists():
        _err(f"Template not found: {name}  (looked in {TEMPLATES_DIR}/)")
        sys.exit(1)

    text = tpl_file.read_text(encoding="utf-8")
    lines = text.splitlines()

    def _extract(field: str) -> str:
        for i, line in enumerate(lines):
            if line.lstrip().startswith("#"):
                continue
            if re.match(rf"^{field}:\s*\|\s*$", line):
                block_lines = []
                for j in range(i + 1, len(lines)):
                    bl = lines[j]
                    if bl and not bl.startswith((" ", "\t", "#")):
                        break
                    if bl.lstrip().startswith("#"):
                        continue
                    block_lines.append(re.sub(r"^  ", "", bl))
                return "\n".join(block_lines).rstrip()
            m = re.match(rf"^{field}:\s+(.+)$", line)
            if m:
                return m.group(1).strip().strip('"').strip("'")
        return ""

    return {
        "name":        _extract("name") or name,
        "description": _extract("description"),
        "request":     _extract("request"),
    }


# ── todos sync ────────────────────────────────────────────────────────────────

def _sync_todos() -> None:
    """Scan done job plans for checklist items and sync to knowledge/todos/pending.md."""
    todos: list[str] = []

    runs_dir = RUNS_DIR
    if runs_dir.is_dir():
        for plan_md in sorted(runs_dir.rglob("plan.md")):
            try:
                for line in plan_md.read_text(encoding="utf-8").splitlines():
                    if line.strip().startswith("- [ ]"):
                        todos.append(line.strip())
            except Exception:
                pass

    KNOWLEDGE_TODOS.parent.mkdir(parents=True, exist_ok=True)
    existing = ""
    if KNOWLEDGE_TODOS.exists():
        existing = KNOWLEDGE_TODOS.read_text(encoding="utf-8")

    # Build a new section
    if todos:
        block = "\n## Synced from devcompanion runs\n\n" + "\n".join(todos) + "\n"
        # Replace existing synced section if present, else append
        marker = "\n## Synced from devcompanion runs\n"
        if marker in existing:
            pre = existing[: existing.index(marker)]
            KNOWLEDGE_TODOS.write_text(pre + block, encoding="utf-8")
        else:
            KNOWLEDGE_TODOS.write_text((existing.rstrip() + "\n" + block) if existing else block, encoding="utf-8")
        _ok(f"Synced {len(todos)} todo(s) → {KNOWLEDGE_TODOS}")
    else:
        _ok("No '- [ ]' items found in run plans.")


# ── runners ───────────────────────────────────────────────────────────────────

def _has_loops(repo_path: str) -> bool:
    """Check if project has agent-toolkit loops configured."""
    if not repo_path:
        return False
    loops_dir = Path(repo_path) / "loops"
    return loops_dir.is_dir() and any(loops_dir.iterdir())


def _try_loop_runner(job: dict, out_dir: Path) -> bool:
    """Try agent-toolkit loop run for the project."""
    repo_path = job.get("project_path", "")
    if not _has_loops(repo_path):
        return False

    toolkit_bin = shutil.which("agent-toolkit")
    if not toolkit_bin:
        return False

    request = job.get("request", "")
    try:
        result = subprocess.run(
            [toolkit_bin, "loop", "run", "--request", request],
            capture_output=True,
            text=True,
            cwd=repo_path,
            timeout=1800,
        )
    except subprocess.TimeoutExpired:
        _warn("agent-toolkit loop run timed out (1800s)")
        return False

    out_dir.mkdir(parents=True, exist_ok=True)
    if result.returncode == 0:
        plan_md = out_dir / "plan.md"
        if not plan_md.exists() and result.stdout.strip():
            plan_md.write_text(result.stdout, encoding="utf-8")
        _ok("agent-toolkit loop run completed")
        return True

    _warn(f"agent-toolkit loop run exited {result.returncode}: {result.stderr[:200]}")
    return False


def _try_claude_runner(job: dict, out_dir: Path) -> bool:
    """Try claude --print as a runner."""
    claude_bin = shutil.which("claude")
    if not claude_bin:
        return False

    repo_path = job.get("project_path", "")
    request = job.get("request", "")
    context = f"Repository: {repo_path}\n" if repo_path else ""

    prompt = (
        f"You are an AI assistant executing a background job.\n"
        f"Workspace root: {WORKSPACE_ROOT}\n"
        f"{context}"
        f"Output directory: {out_dir}\n\n"
        f"{request}\n\n"
        f"Write your plan to {out_dir}/plan.md. "
        f"Work from the workspace root shown above."
    )

    try:
        result = subprocess.run(
            [claude_bin, "--print", "--allowedTools", "Bash,Read,Write,Edit,Glob,Grep"],
            input=prompt,
            capture_output=True,
            text=True,
            cwd=str(WORKSPACE_ROOT),
            timeout=1800,
        )
    except subprocess.TimeoutExpired:
        _warn("claude runner timed out (1800s)")
        return False

    out_dir.mkdir(parents=True, exist_ok=True)
    if result.returncode == 0:
        plan_md = out_dir / "plan.md"
        if not plan_md.exists() and result.stdout.strip():
            plan_md.write_text(result.stdout, encoding="utf-8")
        _ok("claude runner completed")
        return True

    _warn(f"claude runner exited {result.returncode}: {result.stderr[:200]}")
    return False


def _skeleton_run(job: dict, out_dir: Path) -> int:
    """Built-in skeleton runner — generates a plan stub without LLM."""
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        job_id   = job.get("id", "unknown")
        project  = job.get("project", "unknown")
        request  = job.get("request", "(no request)")

        plan = f"""# Plan — {job_id}

**Generated**: {_utc_now()}
**Mode**: skeleton (no LLM)
**Project**: {project}

## Request

{request}

## Steps

> This is a skeleton plan. Run without --no-llm for AI-generated steps.

- [ ] Read project README and AGENTS.md
- [ ] Understand existing conventions and patterns
- [ ] Analyse the request in context
- [ ] Implement changes following project conventions
- [ ] Run tests and verify
- [ ] Create PR

## Notes

- Job ID: {job_id}
- Project path: {job.get("project_path", "not set")}
"""
        (out_dir / "plan.md").write_text(plan, encoding="utf-8")
        _ok(f"Skeleton plan written → {out_dir / 'plan.md'}")
        return 0
    except Exception as exc:
        _err(f"Skeleton runner failed: {exc}")
        return 1


# ── subcommands ───────────────────────────────────────────────────────────────

def _cmd_queue(argv: list[str]) -> int:
    import argparse

    p = argparse.ArgumentParser(prog="agent-toolkit devcompanion queue", add_help=True)
    p.add_argument("project",    nargs="?", help="Project name (maps to projects/<project>)")
    p.add_argument("--template", "-t",     help="Job template name from templates/jobs/")
    p.add_argument("--request",  "-r",     help="Custom request string")
    p.add_argument("--id",                 help="Custom job ID (default: <project>-<timestamp>)")
    args = p.parse_args(argv)

    if not args.project:
        _err("Usage: agent-toolkit devcompanion queue <project> [--template NAME] [--request \"...\"]")
        return 1

    # Resolve project path
    project_path = _resolve_project(args.project)
    if project_path is None:
        _err(f"Project not found: '{args.project}'")
        projects = _list_projects()
        if projects:
            print("\nKnown projects:")
            for name, target in projects:
                s = str(target) if target else _red("(broken)")
                print(f"  {_cyan(f'{name:<30}')} → {s}")
        else:
            print("  (no projects indexed)")
        return 1

    # Build request
    request = ""
    if args.template:
        tpl = _load_template(args.template)
        request = tpl["request"]
        if args.request:
            request = f"{request}\n\n---\n\n{args.request}"
    elif args.request:
        request = args.request
    else:
        _err("Provide --request or --template")
        return 1

    job_id = args.id or f"{args.project}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"
    job: dict = {
        "id":           job_id,
        "created_at":   _utc_now(),
        "project":      args.project,
        "project_path": str(project_path),
        "request":      request,
        "template":     args.template or "",
        "status":       "pending",
    }

    job_file = _job_path(job_id)
    _write_job(job_file, job)

    _log(f"Project : {args.project}")
    _log(f"Path    : {project_path}")
    _log(f"Job ID  : {job_id}")
    _ok(f"Job written → {job_file}")
    print()
    print(_cyan("Plan stub:"))
    print(f"  Run 'agent-toolkit devcompanion run-once' to execute")
    print(f"  Run 'agent-toolkit devcompanion status' to check progress")
    return 0


def _cmd_run_once(argv: list[str]) -> int:
    import argparse

    p = argparse.ArgumentParser(prog="agent-toolkit devcompanion run-once", add_help=True)
    p.add_argument("--no-llm", action="store_true", help="Always use skeleton plan, skip LLM")
    args = p.parse_args(argv)

    QUEUE_DIR.mkdir(parents=True, exist_ok=True)

    # Find the oldest pending job
    pending = sorted(
        (f for f in QUEUE_DIR.glob("*.json")),
        key=lambda f: f.stat().st_mtime,
    )
    # Filter to pending status only
    pending = [f for f in pending if _read_job(f).get("status") == "pending"]

    if not pending:
        _ok("No pending jobs.")
        return 0

    job_file = pending[0]
    job = _read_job(job_file)
    job_id = job["id"]
    out_dir = RUNS_DIR / job_id

    _log(f"Running job: {job_id}")
    _log(f"Project    : {job.get('project', '?')}")
    _log(f"Artifacts  → {out_dir}")

    # Mark as running
    job["status"] = "running"
    _write_job(job_file, job)

    rc = 1
    if args.no_llm:
        _log("--no-llm flag set, using skeleton runner.")
        rc = _skeleton_run(job, out_dir)
    else:
        # 1. agent-toolkit loop run (if project has loops)
        if _try_loop_runner(job, out_dir):
            rc = 0
        # 2. claude --print
        elif _try_claude_runner(job, out_dir):
            rc = 0
        # 3. Skeleton fallback
        else:
            _warn("No LLM runner found, falling back to skeleton plan.")
            rc = _skeleton_run(job, out_dir)

    # Update status
    job["status"] = "done" if rc == 0 else "failed"
    job["completed_at"] = _utc_now()
    _write_job(job_file, job)

    if rc == 0:
        _ok(f"Job done: {job_id}")
        plan_path = out_dir / "plan.md"
        if plan_path.exists():
            print()
            print(_cyan(f"── plan.md {'─' * 50}"))
            print(plan_path.read_text(encoding="utf-8")[:2000])
    else:
        _err(f"Job failed: {job_id}")

    return rc


def _cmd_status(_argv: list[str]) -> int:
    print()
    print(_blue("=== devcompanion queue status ==="))
    print()

    QUEUE_DIR.mkdir(parents=True, exist_ok=True)
    all_jobs = sorted(QUEUE_DIR.glob("*.json"), key=lambda f: f.stat().st_mtime)

    if not all_jobs:
        print("  (queue is empty)")
        print()
        return 0

    col_id      = 42
    col_project = 20
    col_status  = 12
    col_created = 20

    header = (
        f"{'JOB ID':<{col_id}}  "
        f"{'PROJECT':<{col_project}}  "
        f"{'STATUS':<{col_status}}  "
        f"{'CREATED AT':<{col_created}}"
    )
    print(_cyan(header))
    print("─" * (col_id + col_project + col_status + col_created + 6))

    status_color = {
        "pending": _yellow,
        "running": _cyan,
        "done":    _green,
        "failed":  _red,
    }

    for jf in all_jobs:
        try:
            job = _read_job(jf)
            jid      = job.get("id", jf.stem)[:col_id]
            project  = job.get("project", "?")[:col_project]
            status   = job.get("status", "?")
            created  = job.get("created_at", "")[:19]
            color    = status_color.get(status, lambda x: x)
            print(
                f"{jid:<{col_id}}  "
                f"{project:<{col_project}}  "
                f"{color(f'{status:<{col_status}}')}  "
                f"{created:<{col_created}}"
            )
        except Exception:
            print(f"  {jf.name} (unreadable)")

    print()
    return 0


def _cmd_done(argv: list[str]) -> int:
    import argparse

    p = argparse.ArgumentParser(prog="agent-toolkit devcompanion done", add_help=True)
    p.add_argument("job_id", nargs="?", help="Job ID to mark as done")
    args = p.parse_args(argv)

    if not args.job_id:
        _err("Usage: agent-toolkit devcompanion done <job-id>")
        return 1

    job_file = _job_path(args.job_id)
    if not job_file.exists():
        _warn(f"Job file not found: {args.job_id}.json")
        return 1

    job = _read_job(job_file)
    job["status"] = "done"
    job["completed_at"] = _utc_now()
    _write_job(job_file, job)
    _ok(f"Marked as done: {args.job_id}")

    # Archive: move to runs dir (informational only — file stays in queue with status=done)
    return 0


def _cmd_sync_todos(_argv: list[str]) -> int:
    _sync_todos()
    return 0


def _cmd_help(_argv: list[str]) -> int:
    print(f"""
{_blue('agent-toolkit devcompanion')} — background job queue for AI Workspace

{_cyan('Usage:')}
  agent-toolkit devcompanion queue <project> [options]   Queue a job
  agent-toolkit devcompanion run-once [--no-llm]         Run oldest pending job
  agent-toolkit devcompanion status                      Show all jobs
  agent-toolkit devcompanion done <job-id>               Mark a job as done
  agent-toolkit devcompanion sync-todos                  Sync todos from plan.md files

{_cyan('Queue options:')}
  --template NAME    Job template from templates/jobs/ directory
  --request "..."    Custom request string (required if no --template)
  --id ID            Custom job ID (default: <project>-<timestamp>)

{_cyan('Workspace detection:')}
  AGENT_TOOLKIT_WORKSPACE env var, or walk up from CWD looking for .devcompanion/

{_cyan('Queue location:')}
  {QUEUE_DIR}

{_cyan('Runs location:')}
  {RUNS_DIR}

{_cyan('Examples:')}
  agent-toolkit devcompanion queue my-api --template code-review
  agent-toolkit devcompanion queue my-api --request "add pagination to GET /users"
  agent-toolkit devcompanion run-once
  agent-toolkit devcompanion run-once --no-llm
  agent-toolkit devcompanion status
  agent-toolkit devcompanion done my-api-20260804-120000
  agent-toolkit devcompanion sync-todos

{_cyan('Alias:')}
  agent-toolkit dc <subcommand>
""")
    return 0


# ── entry point ───────────────────────────────────────────────────────────────

def cmd_devcompanion(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help", "help"):
        return _cmd_help([])

    subcommand = argv[0]
    rest = argv[1:]

    dispatch = {
        "queue":      _cmd_queue,
        "run-once":   _cmd_run_once,
        "status":     _cmd_status,
        "done":       _cmd_done,
        "sync-todos": _cmd_sync_todos,
        "help":       _cmd_help,
    }

    fn = dispatch.get(subcommand)
    if fn is None:
        _err(f"Unknown subcommand: {subcommand}")
        print("Run 'agent-toolkit devcompanion help' for usage.", file=sys.stderr)
        return 1

    return fn(rest)
