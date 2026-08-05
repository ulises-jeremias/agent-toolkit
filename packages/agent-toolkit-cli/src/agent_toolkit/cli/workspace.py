"""
workspace — AI workspace scaffolding and session context.

Usage:
    agent-toolkit workspace <subcommand> [args]

Subcommands:
    init [--dir PATH] [--name NAME]   Scaffold a new harness workspace
    context [--workspace PATH]        Output a session state snapshot
    sync [--workspace PATH]           Sync loop escalations into todos

Options:
    --help    Show this help message
"""
from __future__ import annotations

import json
import os
import re
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


# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------

_USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def _c(code: str, text: str) -> str:
    return f"\033[{code}m{text}\033[0m" if _USE_COLOR else text


def _blue(t: str) -> str:   return _c("1;34", t)
def _green(t: str) -> str:  return _c("1;32", t)
def _yellow(t: str) -> str: return _c("1;33", t)
def _cyan(t: str) -> str:   return _c("0;36", t)
def _dim(t: str) -> str:    return _c("0;37", t)


# ---------------------------------------------------------------------------
# Workspace root detection
# ---------------------------------------------------------------------------

def _find_workspace(override: str | None = None) -> Path | None:
    """Locate workspace root via env, override, or walking up from CWD."""
    from agent_toolkit._paths import find_workspace_root

    return find_workspace_root(override=override)


# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------

def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def _require_workspace(override: str | None = None) -> Path | None:
    ws = _find_workspace(override)
    if ws is None:
        print("Error: workspace not found.", file=sys.stderr)
        print("Set AGENT_TOOLKIT_WORKSPACE or run from inside a workspace directory.", file=sys.stderr)
    return ws


def _parse_frontmatter_text(content: str) -> dict:
    """Parse YAML frontmatter from markdown text."""
    from agent_toolkit.loop.runner import _parse_simple_yaml

    lines = content.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    end = next((i for i, l in enumerate(lines[1:], 1) if l.strip() == "---"), None)
    if end is None:
        return {}
    yaml_block = "\n".join(lines[1:end])
    try:
        import yaml  # type: ignore
        loaded = yaml.safe_load(yaml_block)
        return loaded if isinstance(loaded, dict) else {}
    except ImportError:
        return _parse_simple_yaml(yaml_block)


def _parse_yaml_file(path: Path) -> dict:
    """Parse a YAML file (PyYAML when available, else minimal parser)."""
    from agent_toolkit.loop.runner import _parse_simple_yaml

    text = path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore
        loaded = yaml.safe_load(text)
        return loaded if isinstance(loaded, dict) else {}
    except ImportError:
        return _parse_simple_yaml(text)


def _persona_path(ws: Path, name: str) -> Path:
    return ws / "personas" / f"{name}.md"


def _load_persona_meta(ws: Path, name: str) -> dict | None:
    path = _persona_path(ws, name)
    if not path.exists():
        return None
    return _parse_frontmatter_text(path.read_text(encoding="utf-8"))


def _append_persona_history(ws: Path, line: str) -> None:
    history = ws / ".persona-history"
    with history.open("a", encoding="utf-8") as fh:
        fh.write(line + "\n")


def _utc_timestamp() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _format_persona_constraints(persona_name: str, meta: dict) -> str:
    allow = meta.get("allow") or []
    deny = meta.get("deny") or []
    handoffs = meta.get("handoffs") or []
    output_fmt = meta.get("output_format", "")

    lines = ["  <persona-constraints>", f"    persona: {persona_name}"]
    if allow:
        lines.append(f"    allow: [{', '.join(str(x) for x in allow)}]")
    if deny:
        lines.append(f"    deny: [{', '.join(str(x) for x in deny)}]")
    if output_fmt:
        lines.append(f"    output_format: {output_fmt}")
    if handoffs:
        lines.append("    handoffs:")
        for h in handoffs:
            if not isinstance(h, dict):
                continue
            when = h.get("when", "")
            to = h.get("to", "")
            lines.append(f'      - when: "{when}"')
            lines.append(f"        to: {to}")
    lines.append("  </persona-constraints>")
    return "\n".join(lines)


def _pack_notes(ws: Path, pack_ref: str) -> str:
    """Return notes field from an active pack, if any."""
    pack_path = Path(pack_ref)
    if not pack_path.is_absolute():
        pack_path = ws / pack_ref
    if not pack_path.exists():
        return ""
    data = _parse_yaml_file(pack_path)
    notes = data.get("notes")
    if isinstance(notes, str) and notes.strip():
        return notes.strip()
    return ""


def _resolve_pack_file(ws: Path, pack_arg: str) -> Path | None:
    """Resolve a pack path relative to workspace root."""
    candidate = Path(pack_arg)
    if candidate.is_absolute():
        return candidate if candidate.is_file() else None
    for rel in (pack_arg, f"packs/{pack_arg}", f"packs/{pack_arg}.yaml"):
        path = ws / rel
        if path.is_file():
            return path
    return None


def _pack_rel_path(ws: Path, pack_path: Path) -> str:
    try:
        return str(pack_path.relative_to(ws))
    except ValueError:
        return str(pack_path)


# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------

_AGENTS_MD_TEMPLATE = """\
# AGENTS.md — AI Workspace Orchestrator

> Generated by: agent-toolkit workspace init
> Customize this file to reflect your team's workflows and tools.

**Purpose**: Session that orchestrates multi-repository work.

## Work Context

- **Repos**: ./projects/ symlinks · ./repos/ cloned on-demand
- **Knowledge**: ./knowledge/ — persistent memory across sessions
- **Personas**: ./personas/ — focused work modes
- **Packs**: ./packs/ — context bundles per client/project

## Available Commands

```
agent-toolkit workspace context        # Print session snapshot
agent-toolkit workspace sync           # Sync loop escalations into todos
agent-toolkit memory add --type <t>    # Add learning/process/todo
agent-toolkit memory search <query>    # Search knowledge base
agent-toolkit memory inject            # Output context block for session
agent-toolkit memory todo              # List pending todos
agent-toolkit project clone <org/repo> # Clone a repo and symlink it
agent-toolkit project list             # List indexed projects
agent-toolkit project scan             # Check project/repo consistency
```

## Operating Rules

- Run `agent-toolkit workspace context` at session start
- Run `agent-toolkit memory search <topic>` before asking known questions
- Save discoveries: `agent-toolkit memory add --type learning "..."`
- Queue background work: `agent-toolkit devcompanion queue <project>`
"""

_KNOWLEDGE_README = """\
# Knowledge Base

Persistent memory across sessions. Add entries with:

```
agent-toolkit memory add --type learning "Always run tests before committing"
agent-toolkit memory add --type process "How to deploy: ..."
agent-toolkit memory add --type todo "Investigate slow query in reports"
```

## Structure

- `learnings/general.md` — factual session learnings
- `processes/<topic>.md` — how-to procedures
- `todos/pending.md` — pending follow-ups
"""

_LEARNINGS_GENERAL = """\
# General Learnings

<!-- Add new entries with: agent-toolkit memory add --type learning "..." -->

| Date | Learning | Context |
|------|----------|---------|
"""

_TODOS_PENDING = """\
# Pending Todos

<!-- Add pending items with date added -->
<!-- agent-toolkit memory add --type todo "description" -->
"""

_PACKS_README = """\
# Packs

Context bundles for switching between clients or projects.

Create a YAML file here:

```yaml
# packs/my-client.yaml
name: my-client
description: Context for my-client engagement
projects:
  - my-client-api
  - my-client-frontend
notes: |
  Key contacts: ...
```

Load with: `agent-toolkit workspace context --pack packs/my-client.yaml`
"""

_PERSONA_IMPLEMENTER = """\
---
allow:
  - write_files
  - run_tests
  - run_build
  - create_commits
deny:
  - merge_prs
  - deploy_production
output_format: code_first
handoffs:
  - when: "implementation complete, needs review"
    to: reviewer
---

# Implementer Persona

> Bias toward action. Write code, run tests, create commits.

## Focus

- Write clean, idiomatic code following project conventions
- Run tests to verify changes work
- Create commits with clear messages
- Ask only when genuinely blocked

## Constraints

- **Do not** merge PRs or deploy to production
- Handoff to **reviewer** when implementation is complete
"""

_PERSONA_REVIEWER = """\
---
allow:
  - read_files
  - run_tests
  - post_comments
  - approve_prs
deny:
  - write_files
  - create_commits
output_format: critique_and_feedback
handoffs:
  - when: "review complete, changes needed"
    to: implementer
  - when: "security concerns found"
    to: architect
---

# Reviewer Persona

> Analyze and critique. No changes — feedback only.

## Focus

- Read code carefully for correctness, clarity, and security
- Run tests to verify coverage
- Post clear, actionable feedback
- Approve PRs when quality bar is met

## Constraints

- **Do not** write or modify files
- **Do not** create commits
- Handoff to **implementer** when changes are needed
"""

_PERSONA_RESEARCHER = """\
---
allow:
  - read_files
  - search_web
  - read_docs
deny:
  - write_files
  - create_commits
  - run_tests
output_format: summary_and_findings
handoffs:
  - when: "research complete, ready to implement"
    to: implementer
  - when: "architectural decision needed"
    to: architect
---

# Researcher Persona

> Explore and summarize. No implementation.

## Focus

- Read codebases to understand structure and patterns
- Search documentation and references
- Produce clear summaries of findings
- Identify options with tradeoffs

## Constraints

- **Do not** modify any files
- **Do not** run tests or builds
- Handoff to **implementer** or **architect** when done
"""

_PERSONA_ARCHITECT = """\
---
allow:
  - read_files
  - write_docs
  - create_adrs
  - design_schemas
deny:
  - write_application_code
  - create_commits
output_format: design_document
handoffs:
  - when: "design finalized, ready to build"
    to: implementer
  - when: "security review needed"
    to: reviewer
---

# Architect Persona

> System design, tradeoffs, ADRs.

## Focus

- Analyze system design and architectural tradeoffs
- Write ADRs (Architecture Decision Records)
- Design schemas, APIs, and data models
- Evaluate technical options at the system level

## Constraints

- **Do not** write application code
- Write design documents and ADRs, not implementation
- Handoff to **implementer** when design is finalized
"""

_GITIGNORE = """\
# Cloned repos (managed by agent-toolkit project clone)
repos/
# Project symlinks (managed by agent-toolkit project clone/add)
projects/
# Active state files
.active-persona
.active-pack
.active-profile
.persona-history
"""


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_init(args: list[str]) -> int:
    """Scaffold a new harness workspace."""
    target_dir = Path.cwd()
    name = ""
    i = 0
    while i < len(args):
        match args[i]:
            case "--dir" if i + 1 < len(args):
                target_dir = Path(args[i + 1]).expanduser().resolve()
                i += 2
            case "--name" if i + 1 < len(args):
                name = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace init [--dir PATH] [--name NAME]")
                return 0
            case _:
                print(f"Unknown option: {args[i]}", file=sys.stderr)
                return 1

    if name:
        target_dir = target_dir / name

    target_dir.mkdir(parents=True, exist_ok=True)
    created: list[str] = []

    def _create(rel: str, content: str) -> None:
        path = target_dir / rel
        if not path.exists():
            _write(path, content)
            created.append(rel)
        else:
            print(f"  {_yellow('skip')}  {rel} (already exists)")

    # Core files
    _create("AGENTS.md", _AGENTS_MD_TEMPLATE)
    _create(".gitignore", _GITIGNORE)

    # Knowledge
    _create("knowledge/README.md", _KNOWLEDGE_README)
    _create("knowledge/learnings/general.md", _LEARNINGS_GENERAL)
    _create("knowledge/todos/pending.md", _TODOS_PENDING)

    # Packs
    _create("packs/README.md", _PACKS_README)

    # Personas
    _create("personas/implementer.md", _PERSONA_IMPLEMENTER)
    _create("personas/reviewer.md", _PERSONA_REVIEWER)
    _create("personas/researcher.md", _PERSONA_RESEARCHER)
    _create("personas/architect.md", _PERSONA_ARCHITECT)

    # Directories (gitignored, so just ensure they exist)
    for d in ("projects", "repos"):
        (target_dir / d).mkdir(exist_ok=True)
        gitkeep = target_dir / d / ".gitkeep"
        if not gitkeep.exists():
            gitkeep.touch()
            created.append(f"{d}/.gitkeep")

    print(f"\n{_green('Workspace initialized:')} {target_dir}\n")
    for rel in created:
        print(f"  {_green('++')}  {rel}")
    print()
    print(f"Next steps:")
    print(f"  cd {target_dir}")
    print(f"  agent-toolkit workspace context")
    print(f"  agent-toolkit project clone owner/my-repo")
    print()
    return 0


def cmd_context(args: list[str]) -> int:
    """Output a session state snapshot."""
    workspace_path: str | None = None
    i = 0
    while i < len(args):
        match args[i]:
            case "--workspace" if i + 1 < len(args):
                workspace_path = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace context [--workspace PATH]")
                return 0
            case _:
                print(f"Unknown option: {args[i]}", file=sys.stderr)
                return 1

    ws = _find_workspace(workspace_path)
    if ws is None:
        print("Error: workspace not found.", file=sys.stderr)
        print("Set AGENT_TOOLKIT_WORKSPACE or run from inside a workspace directory.", file=sys.stderr)
        return 1

    now = datetime.now(timezone.utc)
    knowledge = ws / "knowledge"
    projects_dir = ws / "projects"
    loops_dir = ws / "loops"
    packs_dir = ws / "packs"

    print()
    print(_blue("=== AI Workspace — Session Context ==="))
    print()
    print(f"Date      : {now.strftime('%Y-%m-%d %H:%M UTC')}")
    print(f"Workspace : {ws}")
    print()

    # Git branch
    try:
        result = subprocess.run(
            ["git", "-C", str(ws), "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            print(f"Branch    : {result.stdout.strip()}")
            print()
    except Exception:
        pass

    # Projects
    print(_blue("── Projects ──────────────────────────────────────────────"))
    project_count = 0
    if projects_dir.is_dir():
        for link in sorted(projects_dir.iterdir()):
            if link.is_symlink():
                target = link.resolve()
                status = _green("ok") if target.exists() else _yellow("broken")
                print(f"  [{status}]  {link.name:30s} -> {link.readlink()}")
                project_count += 1
        if project_count == 0:
            print(_dim("  (no projects indexed — run: agent-toolkit project clone owner/repo)"))
    else:
        print(_dim("  (projects/ directory not found)"))
    print()

    # Pending todos
    print(_blue("── Pending Todos ──────────────────────────────────────────"))
    todos_path = knowledge / "todos" / "pending.md"
    if todos_path.exists():
        content = todos_path.read_text(encoding="utf-8")
        unchecked = [l for l in content.splitlines() if l.startswith("- [ ]")]
        if unchecked:
            for item in unchecked[:10]:
                print(f"  {item}")
            if len(unchecked) > 10:
                print(_dim(f"  ... and {len(unchecked) - 10} more"))
        else:
            print(_dim("  (no pending todos)"))
    else:
        print(_dim("  (no todos file)"))
    print()

    # Recent learnings
    print(_blue("── Recent Learnings ───────────────────────────────────────"))
    learnings_path = knowledge / "learnings" / "general.md"
    if learnings_path.exists():
        content = learnings_path.read_text(encoding="utf-8")
        rows = [l for l in content.splitlines() if re.match(r"^\| \d{4}", l)]
        if rows:
            for row in rows[:3]:
                print(f"  {row}")
        else:
            print(_dim("  (no learnings recorded yet)"))
    else:
        print(_dim("  (no learnings file)"))
    print()

    # Loop status summary
    if loops_dir.is_dir():
        print(_blue("── Loop Status ────────────────────────────────────────────"))
        loop_names = sorted(d.name for d in loops_dir.iterdir() if d.is_dir())
        if loop_names:
            for loop_name in loop_names:
                state_file = loops_dir / loop_name / "STATE.md"
                last_run = "(no STATE.md)"
                if state_file.exists():
                    content = state_file.read_text(encoding="utf-8")
                    # Look for last run date in STATE.md
                    for line in content.splitlines():
                        m = re.search(r"(\d{4}-\d{2}-\d{2})", line)
                        if m:
                            last_run = m.group(1)
                            break
                print(f"  {loop_name:35s} last: {last_run}")
        else:
            print(_dim("  (no loops configured)"))
        print()

    # Active pack
    active_pack_file = ws / ".active-pack"
    if active_pack_file.exists():
        pack = active_pack_file.read_text(encoding="utf-8").strip()
        print(_blue("── Active Pack ────────────────────────────────────────────"))
        print(f"  {pack}")
        notes = _pack_notes(ws, pack)
        if notes:
            print()
            for line in notes.splitlines():
                print(f"  {line}")
        print()

    # Active persona
    active_persona_file = ws / ".active-persona"
    if active_persona_file.exists():
        persona = active_persona_file.read_text(encoding="utf-8").strip()
        print(_blue("── Active Persona ─────────────────────────────────────────"))
        print(f"  Persona: {persona}")
        print()
        meta = _load_persona_meta(ws, persona)
        if meta:
            print(_format_persona_constraints(persona, meta))
        print()

    # AGENTS.md hash
    agents_md = ws / "AGENTS.md"
    if agents_md.exists():
        import hashlib
        spec_hash = hashlib.sha256(agents_md.read_bytes()).hexdigest()[:12]
        print(f"Spec      : AGENTS.md@{spec_hash}")
        print()

    print(_blue("──────────────────────────────────────────────────────────"))
    print()
    return 0


def cmd_sync(args: list[str]) -> int:
    """Sync loop escalations into knowledge/todos/pending.md."""
    workspace_path: str | None = None
    i = 0
    while i < len(args):
        match args[i]:
            case "--workspace" if i + 1 < len(args):
                workspace_path = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace sync [--workspace PATH]")
                return 0
            case _:
                print(f"Unknown option: {args[i]}", file=sys.stderr)
                return 1

    ws = _find_workspace(workspace_path)
    if ws is None:
        print("Error: workspace not found.", file=sys.stderr)
        print("Set AGENT_TOOLKIT_WORKSPACE or run from inside a workspace directory.", file=sys.stderr)
        return 1

    loops_dir = ws / "loops"
    todos_path = ws / "knowledge" / "todos" / "pending.md"

    if not loops_dir.is_dir():
        print(_dim("No loops/ directory found — nothing to sync."))
        return 0

    today = datetime.now().date().isoformat()
    todos_content = _read(todos_path)
    new_todos: list[str] = []

    for loop_dir in sorted(loops_dir.iterdir()):
        if not loop_dir.is_dir():
            continue
        # Scan for escalation markers in reports and STATE.md
        for candidate in ["report.md", "STATE.md", "request.md"]:
            report = loop_dir / candidate
            if not report.exists():
                continue
            content = report.read_text(encoding="utf-8")
            for line in content.splitlines():
                if any(marker in line.lower() for marker in ["escalat", "action required", "todo:", "follow-up:"]):
                    # Extract the meaningful part
                    clean = line.strip().lstrip("#").lstrip("-").lstrip(">").strip()
                    if len(clean) < 10:
                        continue
                    todo_line = f"- [ ] {today} - [loop:{loop_dir.name}] {clean}"
                    # Avoid duplicates
                    if todo_line not in todos_content and todo_line not in new_todos:
                        new_todos.append(todo_line)

    if not new_todos:
        print(_dim("No escalations found in loop reports."))
        return 0

    # Append new todos
    todos_path.parent.mkdir(parents=True, exist_ok=True)
    marker = "<!-- Add pending items with date added -->"
    if marker in todos_content:
        idx = todos_content.index(marker) + len(marker)
        insert = "\n" + "\n".join(new_todos)
        new_content = todos_content[:idx] + insert + todos_content[idx:]
    else:
        new_content = todos_content + "\n" + "\n".join(new_todos) + "\n"

    _write(todos_path, new_content)
    print(_green(f"Synced {len(new_todos)} escalation(s) into knowledge/todos/pending.md"))
    for t in new_todos:
        print(f"  {t}")
    return 0


def cmd_use_persona(args: list[str]) -> int:
    """Activate a persona work mode."""
    workspace_path: str | None = None
    i = 0
    while i < len(args):
        match args[i]:
            case "--workspace" if i + 1 < len(args):
                workspace_path = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace use-persona <name> [--workspace PATH]")
                return 0
            case _:
                break

    if i >= len(args):
        print("Usage: agent-toolkit workspace use-persona <name>", file=sys.stderr)
        return 1

    persona = args[i]
    ws = _require_workspace(workspace_path)
    if ws is None:
        return 1

    persona_file = _persona_path(ws, persona)
    if not persona_file.exists():
        print(f"Persona not found: {persona}", file=sys.stderr)
        cmd_personas([])
        return 1

    active_file = ws / ".active-persona"
    from_persona = active_file.read_text(encoding="utf-8").strip() if active_file.exists() else ""
    ts = _utc_timestamp()
    if from_persona and from_persona != persona:
        _append_persona_history(ws, f"{ts} transition: {from_persona} → {persona}")
    elif not from_persona:
        _append_persona_history(ws, f"{ts} activate: → {persona}")

    _write(active_file, persona + "\n")
    print(_green(f"Activated persona: {persona}"))
    return 0


def cmd_handoff(args: list[str]) -> int:
    """Transition from active persona to another (validates handoff rules)."""
    workspace_path: str | None = None
    i = 0
    while i < len(args):
        match args[i]:
            case "--workspace" if i + 1 < len(args):
                workspace_path = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace handoff <name> [--workspace PATH]")
                return 0
            case _:
                break

    if i >= len(args):
        print("Usage: agent-toolkit workspace handoff <name>", file=sys.stderr)
        return 1

    to_persona = args[i]
    ws = _require_workspace(workspace_path)
    if ws is None:
        return 1

    active_file = ws / ".active-persona"
    if not active_file.exists():
        print("No active persona to handoff from. Use 'workspace use-persona <name>' first.", file=sys.stderr)
        return 1

    from_persona = active_file.read_text(encoding="utf-8").strip()
    if not _persona_path(ws, to_persona).exists():
        print(f"Target persona not found: {to_persona}", file=sys.stderr)
        cmd_personas([])
        return 1

    meta = _load_persona_meta(ws, from_persona) or {}
    handoffs = meta.get("handoffs") or []
    allowed = {h.get("to") for h in handoffs if isinstance(h, dict) and h.get("to")}
    if allowed and to_persona not in allowed:
        allowed_str = ", ".join(sorted(allowed))
        print(
            f"Invalid handoff from '{from_persona}' to '{to_persona}'. "
            f"Allowed targets: {allowed_str}",
            file=sys.stderr,
        )
        return 1

    ts = _utc_timestamp()
    _append_persona_history(ws, f"{ts} handoff: {from_persona} → {to_persona}")
    _write(active_file, to_persona + "\n")
    print(_green(f"Handoff: {from_persona} → {to_persona}"))
    return 0


def cmd_history(args: list[str]) -> int:
    """Show recent persona transitions."""
    workspace_path: str | None = None
    count = 10
    i = 0
    while i < len(args):
        match args[i]:
            case "--workspace" if i + 1 < len(args):
                workspace_path = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace history [count] [--workspace PATH]")
                return 0
            case arg if arg.isdigit():
                count = int(arg)
                i += 1
            case _:
                print(f"Unknown option: {args[i]}", file=sys.stderr)
                return 1

    ws = _require_workspace(workspace_path)
    if ws is None:
        return 1

    history_file = ws / ".persona-history"
    if not history_file.exists():
        print("No persona transitions recorded yet.")
        return 0

    lines = history_file.read_text(encoding="utf-8").splitlines()
    recent = lines[-count:] if count else lines
    print(f"Recent persona transitions (last {len(recent)}):")
    print()
    for line in recent:
        print(f"  {line}")
    return 0


def cmd_personas(args: list[str]) -> int:
    """List available personas."""
    workspace_path: str | None = None
    i = 0
    while i < len(args):
        match args[i]:
            case "--workspace" if i + 1 < len(args):
                workspace_path = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace personas [--workspace PATH]")
                return 0
            case _:
                print(f"Unknown option: {args[i]}", file=sys.stderr)
                return 1

    ws = _require_workspace(workspace_path)
    if ws is None:
        return 1

    personas_dir = ws / "personas"
    print(_blue("── Available Personas ─────────────────────────────────────"))
    if not personas_dir.is_dir():
        print(_dim("  (no personas directory)"))
        print()
        return 0

    found = False
    for path in sorted(personas_dir.glob("*.md")):
        found = True
        name = path.stem
        meta = _parse_frontmatter_text(path.read_text(encoding="utf-8"))
        allow = meta.get("allow") or []
        deny = meta.get("deny") or []
        output_fmt = meta.get("output_format", "")
        allow_s = ", ".join(str(x) for x in allow) if allow else "-"
        deny_s = ", ".join(str(x) for x in deny) if deny else "-"
        fmt_s = output_fmt or "-"
        print(f"  {name:20s} allow=[{allow_s}] deny=[{deny_s}] format={fmt_s}")

    if not found:
        print(_dim("  (no personas defined)"))
    print()
    print("Usage: agent-toolkit workspace use-persona <name>")
    return 0


def cmd_load(args: list[str]) -> int:
    """Load a context pack or composable profile."""
    workspace_path: str | None = None
    profile_name: str | None = None
    pack_arg: str | None = None
    i = 0
    while i < len(args):
        match args[i]:
            case "--workspace" if i + 1 < len(args):
                workspace_path = args[i + 1]
                i += 2
            case "--profile" if i + 1 < len(args):
                profile_name = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace load <pack-path> | --profile <name>")
                return 0
            case arg if not arg.startswith("-"):
                pack_arg = arg
                i += 1
            case _:
                print(f"Unknown option: {args[i]}", file=sys.stderr)
                return 1

    ws = _require_workspace(workspace_path)
    if ws is None:
        return 1

    if profile_name:
        return _load_profile(ws, profile_name)
    if not pack_arg:
        print("Usage: agent-toolkit workspace load <pack-path> | --profile <name>", file=sys.stderr)
        return 1
    return _load_pack(ws, pack_arg)


def _load_pack(ws: Path, pack_arg: str) -> int:
    pack_path = _resolve_pack_file(ws, pack_arg)
    if pack_path is None:
        print(f"Pack not found: {pack_arg}", file=sys.stderr)
        packs_dir = ws / "packs"
        if packs_dir.is_dir():
            available = sorted(
                str(p.relative_to(ws))
                for p in packs_dir.rglob("*.yaml")
                if p.is_file()
            )
            if available:
                print("\nAvailable packs:", file=sys.stderr)
                for item in available:
                    print(f"  {item}", file=sys.stderr)
        return 1

    rel = _pack_rel_path(ws, pack_path)
    _write(ws / ".active-pack", rel + "\n")
    data = _parse_yaml_file(pack_path)
    print(_green(f"Loaded pack: {rel}"))
    desc = data.get("description")
    if desc:
        print(f"  {desc}")
    return 0


def _load_profile(ws: Path, profile_name: str) -> int:
    profile_path = ws / "profiles" / f"{profile_name}.yaml"
    if not profile_path.exists():
        print(f"Profile not found: {profile_name}", file=sys.stderr)
        print(f"Looked in: {profile_path}", file=sys.stderr)
        return 1

    data = _parse_yaml_file(profile_path)
    _write(ws / ".active-profile", profile_name + "\n")
    print(_green(f"Profile loaded: {profile_name}"))
    desc = data.get("description")
    if desc:
        print(f"  {desc}")

    pack_ref = data.get("pack")
    if pack_ref:
        pack_path = _resolve_pack_file(ws, str(pack_ref))
        if pack_path is None:
            print(f"  (pack '{pack_ref}' not found — skipped)", file=sys.stderr)
        else:
            rel = _pack_rel_path(ws, pack_path)
            _write(ws / ".active-pack", rel + "\n")
            print(_green(f"  Pack: {rel}"))

    persona = data.get("persona")
    if persona:
        if not _persona_path(ws, str(persona)).exists():
            print(f"  (persona '{persona}' not found — skipped)", file=sys.stderr)
        else:
            active_file = ws / ".active-persona"
            from_persona = active_file.read_text(encoding="utf-8").strip() if active_file.exists() else ""
            ts = _utc_timestamp()
            if from_persona and from_persona != persona:
                _append_persona_history(ws, f"{ts} profile: {from_persona} → {persona}")
            elif not from_persona:
                _append_persona_history(ws, f"{ts} profile: → {persona}")
            _write(active_file, str(persona) + "\n")
            print(_green(f"  Persona: {persona}"))

    return 0


def cmd_profiles(args: list[str]) -> int:
    """List available profiles."""
    workspace_path: str | None = None
    i = 0
    while i < len(args):
        match args[i]:
            case "--workspace" if i + 1 < len(args):
                workspace_path = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace profiles [--workspace PATH]")
                return 0
            case _:
                print(f"Unknown option: {args[i]}", file=sys.stderr)
                return 1

    ws = _require_workspace(workspace_path)
    if ws is None:
        return 1

    profiles_dir = ws / "profiles"
    print(_blue("── Available Profiles ─────────────────────────────────────"))
    if not profiles_dir.is_dir():
        print(_dim("  (no profiles/ directory)"))
        print()
        return 0

    found = False
    for path in sorted(profiles_dir.glob("*.yaml")):
        found = True
        data = _parse_yaml_file(path)
        name = data.get("name") or path.stem
        pack = data.get("pack") or "-"
        persona = data.get("persona") or "-"
        desc = data.get("description") or ""
        print(f"  {name:25s} pack={pack} persona={persona}")
        if desc:
            print(_dim(f"    {desc}"))

    if not found:
        print(_dim("  (no profiles defined)"))
    print()
    print("Usage: agent-toolkit workspace load --profile <name>")
    return 0


def _validate_packs(ws: Path) -> list[str]:
    errors: list[str] = []
    packs_dir = ws / "packs"
    if not packs_dir.is_dir():
        return errors
    for path in sorted(packs_dir.glob("*.yaml")):
        try:
            data = _parse_yaml_file(path)
        except Exception as exc:
            errors.append(f"{path.name}: invalid YAML ({exc})")
            continue
        if not isinstance(data, dict):
            errors.append(f"{path.name}: root must be a mapping")
            continue
        for field in ("name", "description"):
            if not data.get(field):
                errors.append(f"{path.name}: missing required field '{field}'")
    return errors


def _validate_loops(ws: Path) -> list[str]:
    errors: list[str] = []
    loops_dir = ws / "loops"
    if not loops_dir.is_dir():
        return errors
    for loop_dir in sorted(loops_dir.iterdir()):
        if not loop_dir.is_dir():
            continue
        loop_md = loop_dir / "LOOP.md"
        if not loop_md.exists():
            continue
        meta = _parse_frontmatter_text(loop_md.read_text(encoding="utf-8"))
        if not meta:
            errors.append(f"{loop_dir.name}/LOOP.md: missing or invalid frontmatter")
            continue
        for field in ("name", "tier", "cadence", "request"):
            if not meta.get(field):
                errors.append(f"{loop_dir.name}/LOOP.md: missing required field '{field}'")
    return errors


def _validate_personas(ws: Path) -> list[str]:
    errors: list[str] = []
    personas_dir = ws / "personas"
    if not personas_dir.is_dir():
        return errors
    for path in sorted(personas_dir.glob("*.md")):
        meta = _parse_frontmatter_text(path.read_text(encoding="utf-8"))
        if not meta:
            errors.append(f"{path.name}: missing or invalid YAML frontmatter")
            continue
        for field in ("allow", "deny"):
            val = meta.get(field)
            if val is not None and not isinstance(val, list):
                errors.append(f"{path.name}: '{field}' must be a list")
    return errors


def _validate_profiles(ws: Path) -> list[str]:
    errors: list[str] = []
    profiles_dir = ws / "profiles"
    if not profiles_dir.is_dir():
        return errors
    for path in sorted(profiles_dir.glob("*.yaml")):
        try:
            data = _parse_yaml_file(path)
        except Exception as exc:
            errors.append(f"{path.name}: invalid YAML ({exc})")
            continue
        if not isinstance(data, dict):
            errors.append(f"{path.name}: root must be a mapping")
            continue
        if not data.get("name") and not path.stem:
            errors.append(f"{path.name}: missing required field 'name'")
        pack_ref = data.get("pack")
        if pack_ref and _resolve_pack_file(ws, str(pack_ref)) is None:
            errors.append(f"{path.name}: referenced pack '{pack_ref}' not found")
        persona = data.get("persona")
        if persona and not _persona_path(ws, str(persona)).exists():
            errors.append(f"{path.name}: referenced persona '{persona}' not found")
    return errors


def _validate_knowledge(ws: Path) -> list[str]:
    errors: list[str] = []
    knowledge = ws / "knowledge"
    if not knowledge.is_dir():
        errors.append("knowledge/: directory not found")
        return errors
    for sub in ("learnings", "todos", "processes"):
        if not (knowledge / sub).is_dir():
            errors.append(f"knowledge/{sub}/: required directory missing")
    return errors


def _validate_jobs(ws: Path) -> list[str]:
    errors: list[str] = []
    jobs_dir = ws / "templates" / "jobs"
    if not jobs_dir.is_dir():
        return errors
    for path in sorted(jobs_dir.glob("*.yaml")):
        try:
            data = _parse_yaml_file(path)
        except Exception as exc:
            errors.append(f"{path.name}: invalid YAML ({exc})")
            continue
        if not isinstance(data, dict):
            errors.append(f"{path.name}: root must be a mapping")
            continue
        for field in ("name", "request"):
            if not data.get(field):
                errors.append(f"{path.name}: missing required field '{field}'")
    return errors


_SURFACES = {
    "packs": _validate_packs,
    "loops": _validate_loops,
    "personas": _validate_personas,
    "profiles": _validate_profiles,
    "knowledge": _validate_knowledge,
    "jobs": _validate_jobs,
}


def cmd_validate(args: list[str]) -> int:
    """Validate workspace schema integrity."""
    workspace_path: str | None = None
    surface = "all"
    i = 0
    while i < len(args):
        match args[i]:
            case "--workspace" if i + 1 < len(args):
                workspace_path = args[i + 1]
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit workspace validate [surface] [--workspace PATH]")
                print("Surfaces: all, packs, loops, personas, profiles, knowledge, jobs")
                return 0
            case arg if not arg.startswith("-"):
                surface = arg
                i += 1
            case _:
                print(f"Unknown option: {args[i]}", file=sys.stderr)
                return 1

    ws = _require_workspace(workspace_path)
    if ws is None:
        return 1

    if surface != "all" and surface not in _SURFACES:
        print(f"Unknown surface: {surface}", file=sys.stderr)
        print("Valid surfaces: all, packs, loops, personas, profiles, knowledge, jobs", file=sys.stderr)
        return 1

    print()
    print("Context Validation")
    print("------------------")

    surfaces = list(_SURFACES.keys()) if surface == "all" else [surface]
    all_errors: list[str] = []
    for name in surfaces:
        print(_blue(f"Validating {name}/ ..."))
        errors = _SURFACES[name](ws)
        if errors:
            for err in errors:
                print(f"  {_yellow('✗')}  {err}", file=sys.stderr)
            all_errors.extend(errors)
        else:
            print(f"  {_green('✓')}  {name}/ OK")

    print()
    if all_errors:
        print(f"  {_yellow(str(len(all_errors)))} violation(s) found.", file=sys.stderr)
        return 1
    print(f"  {_green('All context files valid.')}")
    print()
    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def cmd_workspace(args: list[str]) -> int:
    """Router for workspace subcommands."""
    if not args or args[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0

    sub = args[0]
    rest = args[1:]

    match sub:
        case "init":
            return cmd_init(rest)
        case "context":
            return cmd_context(rest)
        case "sync":
            return cmd_sync(rest)
        case "use-persona":
            return cmd_use_persona(rest)
        case "handoff":
            return cmd_handoff(rest)
        case "history":
            return cmd_history(rest)
        case "personas":
            return cmd_personas(rest)
        case "load":
            return cmd_load(rest)
        case "profiles":
            return cmd_profiles(rest)
        case "validate":
            return cmd_validate(rest)
        case _:
            print(f"Unknown workspace subcommand: {sub}", file=sys.stderr)
            print("Run 'agent-toolkit workspace --help' for usage.", file=sys.stderr)
            return 1
