"""
memory — Persistent knowledge base management.

Usage:
    agent-toolkit memory <subcommand> [args]

Subcommands:
    add --type <type> [--title TITLE] [--workspace PATH] "content"
                       Add a learning, process, or todo entry
    search "query"     Case-insensitive search across all knowledge files
    inject             Output full knowledge base for AI session injection
    review             Show stale or old entries
    todo               List unchecked todos

Types for add:
    learning   Factual session learning (knowledge/learnings/general.md)
    process    How-to procedure (knowledge/processes/<topic>.md)
    todo       Follow-up item (knowledge/todos/pending.md)

Options:
    --workspace PATH   Override workspace root
    --help             Show this help message
"""
from __future__ import annotations

import os
import re
import sys
from datetime import date, timedelta
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
    if override:
        p = Path(override).expanduser().resolve()
        return p if p.is_dir() else None

    env = os.environ.get("AGENT_TOOLKIT_WORKSPACE")
    if env:
        p = Path(env).expanduser().resolve()
        return p if p.is_dir() else None

    current = Path.cwd()
    for candidate in [current, *current.parents]:
        if (candidate / "AGENTS.md").exists() or (candidate / "knowledge").is_dir():
            return candidate

    return None


# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------

def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _prepend_after_marker(path: Path, marker: str, entry: str) -> None:
    """Insert entry immediately after the first occurrence of marker."""
    content = _read(path)
    if marker not in content:
        _write(path, content + "\n" + entry)
        return
    idx = content.index(marker) + len(marker)
    _write(path, content[:idx] + "\n" + entry + content[idx:])


def _prepend_table_row(path: Path, header_row: str, new_row: str) -> None:
    """Insert new_row right after the header+separator of a markdown table."""
    content = _read(path)
    if header_row not in content:
        _write(path, content + "\n" + new_row + "\n")
        return
    idx = content.index(header_row) + len(header_row)
    rest = content[idx:]
    sep_match = re.match(r"\n\|[-| :]+\|", rest)
    if sep_match:
        idx += sep_match.end()
    _write(path, content[:idx] + "\n" + new_row + content[idx:])


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_add(args: list[str], knowledge: Path) -> int:
    """Add a new entry to the knowledge base."""
    type_ = ""
    title = ""
    content = ""
    i = 0
    while i < len(args):
        match args[i]:
            case "--type" if i + 1 < len(args):
                type_ = args[i + 1]; i += 2
            case "--title" if i + 1 < len(args):
                title = args[i + 1]; i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit memory add --type <type> [--title TITLE] \"content\"")
                print("Types: learning, process, todo")
                return 0
            case _:
                content = args[i]; i += 1

    if not type_ or not content:
        print("Usage: agent-toolkit memory add --type <type> \"content\"", file=sys.stderr)
        print("Types: learning, process, todo", file=sys.stderr)
        return 1

    today = date.today().isoformat()

    match type_:
        case "learning":
            path = knowledge / "learnings" / "general.md"
            if not path.exists():
                _write(path, "# General Learnings\n\n| Date | Learning | Context |\n|------|----------|---------|")
            row = f"| {today} | {content} | Session |"
            _prepend_table_row(path, "| Date | Learning | Context |", row)
            print(_green(f"Added learning to {path.relative_to(knowledge.parent)}"))

        case "process":
            topic = re.sub(r"[^a-z0-9-]", "-", (title or "general").lower()).strip("-") or "general"
            path = knowledge / "processes" / f"{topic}.md"
            if not path.exists():
                _write(path, f"# Process: {title or topic}\n\n<!-- How-to procedures -->\n")
            entry = f"\n## {today}\n\n{content}\n"
            _write(path, _read(path) + entry)
            print(_green(f"Added process to {path.relative_to(knowledge.parent)}"))

        case "todo":
            path = knowledge / "todos" / "pending.md"
            if not path.exists():
                _write(path, "# Pending Todos\n\n<!-- Add pending items with date added -->\n")
            marker = "<!-- Add pending items with date added -->"
            entry = f"- [ ] {today} - {content}\n"
            _prepend_after_marker(path, marker, entry)
            print(_green(f"Added todo to {path.relative_to(knowledge.parent)}"))

        case _:
            print(f"Unknown type: {type_}", file=sys.stderr)
            print("Valid types: learning, process, todo", file=sys.stderr)
            return 1

    return 0


def cmd_search(args: list[str], knowledge: Path) -> int:
    """Case-insensitive search across all knowledge files."""
    query_parts: list[str] = []
    i = 0
    while i < len(args):
        match args[i]:
            case "--help" | "-h":
                print("Usage: agent-toolkit memory search \"query\"")
                return 0
            case _:
                query_parts.append(args[i]); i += 1

    query = " ".join(query_parts)
    if not query:
        print("Usage: agent-toolkit memory search \"query\"", file=sys.stderr)
        return 1

    query_lower = query.lower()
    print(f"\n{_blue(f'=== Searching: {query} ===')}\n")
    found_any = False

    if not knowledge.is_dir():
        print(_dim("  (knowledge/ directory not found)"))
        print()
        return 0

    for md_file in sorted(knowledge.rglob("*.md")):
        content = _read(md_file)
        lines = content.splitlines()
        matched: list[tuple[int, str]] = [
            (i + 1, line) for i, line in enumerate(lines)
            if query_lower in line.lower()
        ]
        if not matched:
            continue

        found_any = True
        try:
            rel = md_file.relative_to(knowledge.parent)
        except ValueError:
            rel = md_file

        print(f"  {_cyan(str(rel))}:")
        for lineno, line in matched[:5]:
            # Show 1 line of context before and after if possible
            ctx_start = max(0, lineno - 2)
            ctx_end = min(len(lines), lineno + 1)
            for ci in range(ctx_start, ctx_end):
                prefix = _dim(f"  {ci + 1}:") + " "
                text = lines[ci].strip()
                if ci == lineno - 1:
                    # Highlight the matching line
                    print(f"  {_yellow(f'{ci + 1}:')} {text}")
                else:
                    print(f"  {_dim(f'{ci + 1}:')} {_dim(text)}")
        if len(matched) > 5:
            print(_dim(f"    ... and {len(matched) - 5} more matches"))
        print()

    if not found_any:
        print(_dim("  (no results found)"))
    print()
    return 0


def cmd_inject(args: list[str], knowledge: Path) -> int:
    """Output full knowledge base as a formatted block for AI session injection."""
    for arg in args:
        if arg in ("--help", "-h"):
            print("Usage: agent-toolkit memory inject [--workspace PATH]")
            return 0

    print("<!-- agent-toolkit memory inject -->\n")
    print("## Knowledge Base Summary\n")

    has_output = False

    # Todos
    todos_path = knowledge / "todos" / "pending.md"
    if todos_path.exists():
        content = todos_path.read_text(encoding="utf-8")
        unchecked = [l for l in content.splitlines() if l.startswith("- [ ]")]
        if unchecked:
            print("### Pending Todos\n")
            for item in unchecked[:15]:
                print(item)
            print()
            has_output = True

    # Recent learnings
    learnings_path = knowledge / "learnings" / "general.md"
    if learnings_path.exists():
        content = learnings_path.read_text(encoding="utf-8")
        rows = [l for l in content.splitlines() if re.match(r"^\| \d{4}", l)]
        if rows:
            print("### Recent Learnings\n")
            print("| Date | Learning | Context |")
            print("|------|----------|---------|")
            for row in rows[:10]:
                print(row)
            print()
            has_output = True

    # Processes index
    procs_dir = knowledge / "processes"
    if procs_dir.is_dir():
        proc_files = sorted(
            p.stem for p in procs_dir.iterdir()
            if p.is_file() and p.suffix == ".md"
        )
        if proc_files:
            print("### Known Processes\n")
            for name in proc_files:
                print(f"- `knowledge/processes/{name}.md`")
            print()
            has_output = True

    if not has_output:
        print(_dim("(knowledge base is empty)"))

    print("<!-- end agent-toolkit memory inject -->")
    return 0


def cmd_review(args: list[str], knowledge: Path) -> int:
    """Show stale entries (>30 days) and old todos (>14 days)."""
    stale_days = 30
    todo_days = 14
    i = 0
    while i < len(args):
        match args[i]:
            case "--stale-days" if i + 1 < len(args):
                try:
                    stale_days = int(args[i + 1])
                    todo_days = stale_days // 2
                except ValueError:
                    pass
                i += 2
            case "--help" | "-h":
                print("Usage: agent-toolkit memory review [--stale-days N]")
                return 0
            case _:
                i += 1

    today = date.today()
    stale_cutoff = (today - timedelta(days=stale_days)).isoformat()
    todo_cutoff = (today - timedelta(days=todo_days)).isoformat()

    print(f"\n{_blue('=== Memory Review ===')}\n")
    found_any = False

    # Scan markdown files for dated entries
    print(f"{_cyan('Learnings older than')} {stale_days} {_cyan('days:')}")
    learnings_path = knowledge / "learnings" / "general.md"
    if learnings_path.exists():
        content = learnings_path.read_text(encoding="utf-8")
        stale_rows = []
        for line in content.splitlines():
            m = re.match(r"^\| (\d{4}-\d{2}-\d{2}) \|", line)
            if m and m.group(1) < stale_cutoff:
                stale_rows.append(line)
        if stale_rows:
            for row in stale_rows[:10]:
                print(f"  {row}")
            found_any = True
        else:
            print(_dim(f"  (none older than {stale_days} days)"))
    else:
        print(_dim("  (no learnings file)"))
    print()

    print(f"{_cyan('Todos older than')} {todo_days} {_cyan('days:')}")
    todos_path = knowledge / "todos" / "pending.md"
    if todos_path.exists():
        content = todos_path.read_text(encoding="utf-8")
        old_todos = []
        for line in content.splitlines():
            m = re.match(r"^- \[ \] (\d{4}-\d{2}-\d{2}) ", line)
            if m and m.group(1) < todo_cutoff:
                old_todos.append(line)
        if old_todos:
            for item in old_todos[:10]:
                print(f"  {item}")
            found_any = True
        else:
            print(_dim(f"  (none older than {todo_days} days)"))
    else:
        print(_dim("  (no todos file)"))
    print()

    if not found_any:
        print(_dim("Knowledge base is up to date — no stale entries."))
    return 0


def cmd_todo(args: list[str], knowledge: Path) -> int:
    """List unchecked todos from pending.md."""
    show_done = False
    for arg in args:
        match arg:
            case "--done":
                show_done = True
            case "--help" | "-h":
                print("Usage: agent-toolkit memory todo [--done]")
                return 0

    path = knowledge / "todos" / "pending.md"
    if not path.exists():
        print(_dim("(no todos file found)"))
        return 0

    content = path.read_text(encoding="utf-8")
    lines = content.splitlines()

    unchecked = [l for l in lines if l.startswith("- [ ]")]
    done = [l for l in lines if l.startswith("- [x]") or l.startswith("- [X]")]

    if not unchecked and not done:
        print(_dim("(no todos found)"))
        return 0

    if unchecked:
        print(f"\n{_cyan('Pending Todos:')}\n")
        for item in unchecked:
            print(f"  {item}")
        print()

    if show_done and done:
        print(f"\n{_dim('Completed Todos:')}\n")
        for item in done:
            print(f"  {_dim(item)}")
        print()
    elif not unchecked:
        print(_dim("(no pending todos)"))

    return 0


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def cmd_memory(args: list[str]) -> int:
    """Router for memory subcommands."""
    # Extract --workspace before routing
    workspace_path: str | None = None
    filtered_args: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--workspace" and i + 1 < len(args):
            workspace_path = args[i + 1]
            i += 2
        else:
            filtered_args.append(args[i])
            i += 1

    if not filtered_args or filtered_args[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0

    ws = _find_workspace(workspace_path)
    if ws is None:
        print("Error: workspace not found.", file=sys.stderr)
        print("Set AGENT_TOOLKIT_WORKSPACE or run from inside a workspace directory.", file=sys.stderr)
        return 1

    knowledge = ws / "knowledge"
    sub = filtered_args[0]
    rest = filtered_args[1:]

    match sub:
        case "add":
            return cmd_add(rest, knowledge)
        case "search":
            return cmd_search(rest, knowledge)
        case "inject":
            return cmd_inject(rest, knowledge)
        case "review":
            return cmd_review(rest, knowledge)
        case "todo":
            return cmd_todo(rest, knowledge)
        case _:
            print(f"Unknown memory subcommand: {sub}", file=sys.stderr)
            print("Run 'agent-toolkit memory --help' for usage.", file=sys.stderr)
            return 1
