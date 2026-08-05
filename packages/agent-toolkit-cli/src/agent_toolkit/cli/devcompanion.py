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

import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import sys as _sys
if _sys.platform == 'win32':
    try:
        _sys.stdout.reconfigure(encoding='utf-8', errors='replace')
        _sys.stderr.reconfigure(encoding='utf-8', errors='replace')
    except Exception:
        pass

from agent_toolkit.cli.devcompanion_queue import (
    DCConfig,
    find_job_path,
    get_dc_config,
    iter_jobs,
    job_project_name,
    job_project_path,
    mark_job_done,
    pending_jobs,
    queue_job_path,
    read_job,
    write_job,
)


# ── workspace detection ───────────────────────────────────────────────────────

def _find_workspace() -> Path:
    """Return workspace root: AGENT_TOOLKIT_WORKSPACE / HARNESS_DIR / walk-up / cwd."""
    from agent_toolkit._paths import find_workspace_root

    ws = find_workspace_root()
    if ws is not None:
        return ws
    # Devcompanion also accepts .devcompanion as a marker
    cwd = Path.cwd().resolve()
    for parent in [cwd, *cwd.parents]:
        if (parent / ".devcompanion").is_dir():
            return parent
    return cwd


WORKSPACE_ROOT: Path = _find_workspace()


def _workspace() -> Path:
    """Fresh workspace root (respects env changes in tests)."""
    return _find_workspace()


def _projects_dir() -> Path:
    return _workspace() / "projects"


def _templates_dir() -> Path:
    return _workspace() / "templates" / "jobs"


def _knowledge_todos() -> Path:
    return _workspace() / "knowledge" / "todos" / "pending.md"


def _cfg() -> DCConfig:
    return get_dc_config(_workspace())


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


# ── project resolution ────────────────────────────────────────────────────────

def _resolve_project(name: str) -> Path | None:
    """Resolve project name → real repo path via projects/ symlinks."""
    projects_dir = _projects_dir()
    if not projects_dir.is_dir():
        return None
    link = projects_dir / name
    if link.is_symlink():
        return link.resolve()
    for entry in projects_dir.iterdir():
        if entry.is_symlink() and name in entry.name:
            return entry.resolve()
    return None


def _list_projects() -> list[tuple[str, Path | None]]:
    projects_dir = _projects_dir()
    if not projects_dir.is_dir():
        return []
    result = []
    for entry in sorted(projects_dir.iterdir()):
        if entry.is_symlink():
            target = entry.resolve() if entry.resolve().is_dir() else None
            result.append((entry.name, target))
    return result


# ── template loading ──────────────────────────────────────────────────────────

def _load_template(name: str) -> dict:
    templates_dir = _templates_dir()
    tpl_file = templates_dir / f"{name}.yaml"
    if not tpl_file.exists():
        _err(f"Template not found: {name}  (looked in {templates_dir}/)")
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
    cfg = _cfg()
    runs_dir = cfg.runs_dir

    if runs_dir.is_dir():
        for plan_md in sorted(runs_dir.rglob("plan.md")):
            try:
                for line in plan_md.read_text(encoding="utf-8").splitlines():
                    if line.strip().startswith("- [ ]"):
                        todos.append(line.strip())
            except Exception:
                pass

    knowledge_todos = _knowledge_todos()
    knowledge_todos.parent.mkdir(parents=True, exist_ok=True)
    existing = ""
    if knowledge_todos.exists():
        existing = knowledge_todos.read_text(encoding="utf-8")

    if todos:
        block = "\n## Synced from devcompanion runs\n\n" + "\n".join(todos) + "\n"
        marker = "\n## Synced from devcompanion runs\n"
        if marker in existing:
            pre = existing[: existing.index(marker)]
            knowledge_todos.write_text(pre + block, encoding="utf-8")
        else:
            knowledge_todos.write_text((existing.rstrip() + "\n" + block) if existing else block, encoding="utf-8")
        _ok(f"Synced {len(todos)} todo(s) → {knowledge_todos}")
    else:
        _ok("No '- [ ]' items found in run plans.")


# ── runners ───────────────────────────────────────────────────────────────────

def _import_harness_runner():
    """Try to import the harness workstation runner."""
    runner_root = os.environ.get("HARNESS_RUNNER_DIR", "").strip()
    if not runner_root:
        runner_root = str(Path.home() / ".local" / "share" / "agentic-harness" / "runner")
    runner_dir = Path(runner_root) / "runner"
    if not runner_dir.is_dir():
        return None, f"runner dir not found: {runner_dir}"
    if str(runner_dir) not in sys.path:
        sys.path.insert(0, str(runner_dir))
    try:
        import dots_ai_devcompanion_runner as runner_mod
        return runner_mod, None
    except ImportError as exc:
        return None, str(exc)


def _has_loops(repo_path: str) -> bool:
    if not repo_path:
        return False
    loops_dir = Path(repo_path) / "loops"
    return loops_dir.is_dir() and any(loops_dir.iterdir())


def _try_harness_runner(job_file: Path, out_dir: Path) -> bool:
    runner, _reason = _import_harness_runner()
    if runner is None:
        return False

    argv = ["--job", str(job_file), "--out", str(out_dir)]
    try:
        rc = runner.main(argv)
    except Exception as exc:
        _warn(f"Harness runner failed: {exc}")
        return False

    if rc is None:
        rc = 0
    if rc == 0:
        _ok("Harness runner completed")
        return True

    _warn(f"Harness runner exited {rc}")
    return False


def _try_loop_runner(job: dict, out_dir: Path) -> bool:
    repo_path = job_project_path(job)
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
    claude_bin = shutil.which("claude")
    if not claude_bin:
        return False

    repo_path = job_project_path(job)
    request = job.get("request", "")
    context = f"Repository: {repo_path}\n" if repo_path else ""

    prompt = (
        f"You are an AI assistant executing a background job.\n"
        f"Workspace root: {_workspace()}\n"
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
            cwd=str(_workspace()),
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


def _try_opencode_runner(job: dict, out_dir: Path) -> bool:
    opencode_bin = shutil.which("opencode")
    if not opencode_bin:
        return False

    request = job.get("request", "")
    prompt = (
        f"You are executing an autonomous loop run in an agentic-harness workspace.\n"
        f"Workspace root: {_workspace()}\n"
        f"Output directory: {out_dir}\n\n"
        f"{request}\n\n"
        f"Write your final report to {out_dir}/report.md and your plan to "
        f"{out_dir}/plan.md. Work from the workspace root shown above."
    )
    try:
        result = subprocess.run(
            [opencode_bin, "run", "--print-logs"],
            input=prompt,
            capture_output=True,
            text=True,
            cwd=str(_workspace()),
            timeout=900,
        )
    except subprocess.TimeoutExpired:
        _warn("opencode runner timed out (900s)")
        return False

    if result.returncode == 0:
        out_dir.mkdir(parents=True, exist_ok=True)
        report_md = out_dir / "report.md"
        if not report_md.exists() and result.stdout.strip():
            report_md.write_text(result.stdout, encoding="utf-8")
        _ok("opencode runner completed")
        return True

    _warn(f"opencode runner exited {result.returncode}: {result.stderr[:200]}")
    return False


def _skeleton_run(job: dict, out_dir: Path) -> int:
    out_dir.mkdir(parents=True, exist_ok=True)
    try:
        job_id = job.get("id", "unknown")
        project = job_project_name(job)
        request = job.get("request", "(no request)")

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
- Project path: {job_project_path(job) or "not set"}
"""
        (out_dir / "plan.md").write_text(plan, encoding="utf-8")
        _ok(f"Skeleton plan written → {out_dir / 'plan.md'}")
        return 0
    except Exception as exc:
        _err(f"Skeleton runner failed: {exc}")
        return 1


def _dispatch_run(cfg: DCConfig, job_file: Path, job: dict, out_dir: Path, no_llm: bool) -> int:
    if no_llm:
        _log("--no-llm flag set, using skeleton runner.")
        return _skeleton_run(job, out_dir)

    if cfg.harness_mode:
        runner, reason = _import_harness_runner()
        if runner is not None:
            if _try_harness_runner(job_file, out_dir):
                return 0
        elif reason:
            _warn(f"Harness runner not available ({reason}). Trying fallbacks.")

        if _try_claude_runner(job, out_dir):
            return 0
        if _try_opencode_runner(job, out_dir):
            return 0
        _warn("No LLM runner found, falling back to skeleton plan.")
        return _skeleton_run(job, out_dir)

    if _try_loop_runner(job, out_dir):
        return 0
    if _try_claude_runner(job, out_dir):
        return 0
    _warn("No LLM runner found, falling back to skeleton plan.")
    return _skeleton_run(job, out_dir)


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

    cfg = _cfg()
    job_id = args.id or f"{args.project}-{datetime.now().strftime('%Y%m%d-%H%M%S')}"

    if cfg.harness_mode:
        job: dict = {
            "id":              job_id,
            "created_at":      _utc_now(),
            "request":         request,
            "repo_path":       str(project_path),
            "llm":             True,
            "limits":          {"timeout_sec": 1800, "max_steps": 25},
            "actions_allowed": ["plan_only"],
        }
    else:
        job = {
            "id":           job_id,
            "created_at":   _utc_now(),
            "project":      args.project,
            "project_path": str(project_path),
            "request":      request,
            "template":     args.template or "",
            "status":       "pending",
        }

    job_file = queue_job_path(cfg, job_id)
    write_job(job_file, job)

    _log(f"Project : {args.project}")
    _log(f"Path    : {project_path}")
    _log(f"Job ID  : {job_id}")
    _ok(f"Job written → {job_file}")
    print()
    print(_cyan("Plan stub:"))
    print("  Run 'agent-toolkit devcompanion run-once' to execute")
    print("  Run 'agent-toolkit devcompanion status' to check progress")
    return 0


def _cmd_run_once(argv: list[str]) -> int:
    import argparse

    p = argparse.ArgumentParser(prog="agent-toolkit devcompanion run-once", add_help=True)
    p.add_argument("--no-llm", action="store_true", help="Always use skeleton plan, skip LLM")
    args = p.parse_args(argv)

    cfg = _cfg()
    pending = pending_jobs(cfg)

    if not pending:
        _ok("No pending jobs.")
        return 0

    job_file, job = pending[0]
    job_id = job["id"]
    out_dir = cfg.runs_dir / job_id

    _log(f"Running job: {job_id}")
    _log(f"Project    : {job_project_name(job)}")
    _log(f"Artifacts  → {out_dir}")

    if cfg.harness_mode:
        cfg.queue_processing.mkdir(parents=True, exist_ok=True)
        processing_file = cfg.queue_processing / job_file.name
        job_file.rename(processing_file)
        job_file = processing_file
    else:
        job["status"] = "running"
        write_job(job_file, job)

    rc = _dispatch_run(cfg, job_file, job, out_dir, args.no_llm)

    if cfg.harness_mode:
        dest_dir = cfg.queue_done if rc == 0 else cfg.queue_failed
        dest_dir.mkdir(parents=True, exist_ok=True)
        if job_file.exists():
            job_file.rename(dest_dir / job_file.name)
    else:
        job["status"] = "done" if rc == 0 else "failed"
        job["completed_at"] = _utc_now()
        write_job(job_file, job)

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
    cfg = _cfg()
    print()
    print(_blue("=== devcompanion queue status ==="))
    print()

    jobs = iter_jobs(cfg)
    if not jobs:
        print("  (queue is empty)")
        print()
        return 0

    if cfg.harness_mode:
        for state, directory, color in (
            ("pending", cfg.queue_pending, _yellow),
            ("processing", cfg.queue_processing, _cyan),
            ("done", cfg.queue_done, _green),
            ("failed", cfg.queue_failed, _red),
        ):
            if not directory.is_dir():
                continue
            state_jobs = [item for item in jobs if item[0] == state]
            print(f"{color(f'{state:<12}')} {len(state_jobs)} job(s)")
            for _, jf, job in state_jobs[:5]:
                jid = job.get("id", jf.stem)
                project = job_project_name(job)
                request = job.get("request", "").split("\n")[0][:60]
                print(f"  {_cyan(f'{jid:<45}')} [{project}] {request}")
            if len(state_jobs) > 5:
                print(f"  … and {len(state_jobs) - 5} more")
            print()
        return 0

    col_id = 42
    col_project = 20
    col_status = 12
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
        "done": _green,
        "failed": _red,
    }

    for status, jf, job in jobs:
        try:
            jid = job.get("id", jf.stem)[:col_id]
            project = job_project_name(job)[:col_project]
            created = job.get("created_at", "")[:19]
            color = status_color.get(status, lambda x: x)
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

    cfg = _cfg()
    job_id = args.job_id

    if cfg.harness_mode:
        if mark_job_done(cfg, job_id, _utc_now()):
            _ok(f"Marked as done: {job_id}")
            return 0
        _warn(f"Job file not found: {job_id}.job")
        return 1

    job_file = find_job_path(cfg, job_id)
    if job_file is None:
        _warn(f"Job file not found: {job_id}.json")
        return 1

    job = read_job(job_file)
    job["status"] = "done"
    job["completed_at"] = _utc_now()
    write_job(job_file, job)
    _ok(f"Marked as done: {job_id}")
    return 0


def _cmd_sync_todos(_argv: list[str]) -> int:
    _sync_todos()
    return 0


def _cmd_help(_argv: list[str]) -> int:
    cfg = _cfg()
    queue_loc = str(cfg.dc_home / "queue") if cfg.harness_mode else str(cfg.queue_dir)
    mode = "harness (.job files)" if cfg.harness_mode else "workspace (.json files)"
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

{_cyan('Queue mode:')}
  {mode}
  HARNESS_DC_HOME or HARNESS_DIR → harness queue under ~/.local/share/agentic-harness/dev-companion

{_cyan('Queue location:')}
  {queue_loc}

{_cyan('Runs location:')}
  {cfg.runs_dir}

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
