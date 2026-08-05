"""
memory — Persistent knowledge base management.

Usage:
    agent-toolkit memory <subcommand> [args]

Subcommands:
    add --type <type> [--title TITLE] [--workspace PATH] "content"
                       Add a learning, process, or todo entry
    search "query"     Case-insensitive search across all knowledge files
    inject             Output full knowledge base for AI session injection
    review [--fix] [--stale-after N]
                       Detect duplicates, stale/orphan refs, and contradictions
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
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from difflib import SequenceMatcher
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


@dataclass(frozen=True)
class KnowledgeEntry:
    """A reviewable knowledge snippet with location metadata."""

    path: Path
    line_no: int
    text: str
    dated: date | None = None


_PATH_REF_RE = re.compile(
    r"(?<![\w])("
    r"(?:~/|\.{1,2}/|/)?"
    r"(?:[A-Za-z0-9_.-]+/)+[A-Za-z0-9_.-]+\.[A-Za-z0-9]+"
    r")"
)
_CONTRACTION_PAIR_RE = re.compile(
    r"\b(?:do\s+not|don't|dont|never|avoid)\s+(?:use|call|run|install)\s+([A-Za-z0-9_./-]+)",
    re.I,
)
_USE_RE = re.compile(
    r"\b(?:use|prefer|always\s+use|should\s+use)\s+([A-Za-z0-9_./-]+)",
    re.I,
)


def _similarity(a: str, b: str) -> float:
    """Return normalized similarity in [0, 1] (SequenceMatcher ≈ Levenshtein ratio)."""
    a_n = re.sub(r"\s+", " ", a.strip().lower())
    b_n = re.sub(r"\s+", " ", b.strip().lower())
    if not a_n or not b_n:
        return 0.0
    return SequenceMatcher(None, a_n, b_n).ratio()


def _parse_entry_date(text: str) -> date | None:
    m = re.search(r"\b(\d{4}-\d{2}-\d{2})\b", text)
    if not m:
        return None
    try:
        return date.fromisoformat(m.group(1))
    except ValueError:
        return None


def _collect_entries(knowledge: Path) -> list[KnowledgeEntry]:
    """Extract reviewable lines/sections from knowledge markdown files."""
    entries: list[KnowledgeEntry] = []
    if not knowledge.is_dir():
        return entries

    for md_file in sorted(knowledge.rglob("*.md")):
        lines = _read(md_file).splitlines()
        for i, line in enumerate(lines, start=1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or stripped.startswith("<!--"):
                continue
            # Table separator / header
            if re.match(r"^\|[-:| ]+\|$", stripped):
                continue
            if stripped.startswith("| Date |") or stripped.startswith("|------"):
                continue
            # Prefer meaningful content rows / bullets / process body lines
            if stripped.startswith("|") or stripped.startswith("- ") or len(stripped) >= 24:
                text = stripped
                if stripped.startswith("|"):
                    cells = [c.strip() for c in stripped.strip("|").split("|")]
                    text = " — ".join(c for c in cells if c)
                entries.append(
                    KnowledgeEntry(
                        path=md_file,
                        line_no=i,
                        text=text,
                        dated=_parse_entry_date(stripped),
                    )
                )
    return entries


def _extract_path_refs(text: str) -> list[str]:
    refs: list[str] = []
    for m in _PATH_REF_RE.finditer(text):
        refs.append(m.group(1))
    for m in re.finditer(r"`([^`]+)`", text):
        raw = m.group(1).strip()
        if "://" in raw or raw.startswith("http"):
            continue
        if "/" in raw or raw.startswith((".", "~")):
            refs.append(raw)
    # Deduplicate preserving order
    seen: set[str] = set()
    out: list[str] = []
    for ref in refs:
        if ref not in seen:
            seen.add(ref)
            out.append(ref)
    return out


def _resolve_ref(ref: str, workspace: Path) -> Path:
    if ref.startswith("~/"):
        return Path.home() / ref[2:]
    p = Path(ref)
    if p.is_absolute():
        return p
    return (workspace / ref).resolve()


def _find_duplicates(entries: list[KnowledgeEntry], *, threshold: float = 0.8) -> list[tuple[KnowledgeEntry, KnowledgeEntry, float]]:
    dupes: list[tuple[KnowledgeEntry, KnowledgeEntry, float]] = []
    for i, left in enumerate(entries):
        for right in entries[i + 1 :]:
            if left.path == right.path and left.line_no == right.line_no:
                continue
            ratio = _similarity(left.text, right.text)
            if ratio >= threshold:
                dupes.append((left, right, ratio))
    return dupes


def _find_contradictions(entries: list[KnowledgeEntry]) -> list[tuple[KnowledgeEntry, KnowledgeEntry, str]]:
    """Detect 'use X' vs 'don't use X' pairs across the knowledge base."""
    use_map: dict[str, list[KnowledgeEntry]] = {}
    avoid_map: dict[str, list[KnowledgeEntry]] = {}
    for entry in entries:
        for m in _USE_RE.finditer(entry.text):
            # Skip if the match is actually a negation captured loosely
            start = max(0, m.start() - 12)
            window = entry.text[start : m.start()].lower()
            if any(neg in window for neg in ("don't", "dont", "do not", "never", "avoid")):
                continue
            use_map.setdefault(m.group(1).lower(), []).append(entry)
        for m in _CONTRACTION_PAIR_RE.finditer(entry.text):
            avoid_map.setdefault(m.group(1).lower(), []).append(entry)

    hits: list[tuple[KnowledgeEntry, KnowledgeEntry, str]] = []
    for key, avoiders in avoid_map.items():
        for user in use_map.get(key, []):
            for avoider in avoiders:
                if user is avoider:
                    continue
                hits.append((user, avoider, key))
    return hits


def _find_stale_and_orphans(
    entries: list[KnowledgeEntry],
    knowledge: Path,
    *,
    stale_after: int,
) -> tuple[list[tuple[KnowledgeEntry, str]], list[tuple[KnowledgeEntry, str]]]:
    """Return (stale, orphaned) findings.

    Stale: entry older than threshold AND a referenced path/tool is missing.
    Orphaned: any referenced path that no longer exists (regardless of age).
    """
    workspace = knowledge.parent
    cutoff = date.today() - timedelta(days=stale_after)
    stale: list[tuple[KnowledgeEntry, str]] = []
    orphans: list[tuple[KnowledgeEntry, str]] = []

    for entry in entries:
        refs = _extract_path_refs(entry.text)
        missing: list[str] = []
        for ref in refs:
            target = _resolve_ref(ref, workspace)
            if not target.exists():
                missing.append(ref)

        mtime_date: date | None = entry.dated
        if mtime_date is None:
            try:
                mtime_date = datetime.fromtimestamp(
                    entry.path.stat().st_mtime, tz=timezone.utc
                ).date()
            except OSError:
                mtime_date = None

        for ref in missing:
            orphans.append((entry, f"missing path `{ref}`"))

        if missing and mtime_date is not None and mtime_date < cutoff:
            stale.append(
                (
                    entry,
                    f"last seen {mtime_date.isoformat()} (>{stale_after}d) and refs missing: "
                    + ", ".join(f"`{r}`" for r in missing),
                )
            )

    return stale, orphans


def cmd_review(args: list[str], knowledge: Path) -> int:
    """Detect duplicates, stale/orphan refs, and contradictions (#226).

    Exit codes: 0 if clean, 1 if any issues found.
    """
    stale_after = 90
    fix = False
    i = 0
    while i < len(args):
        match args[i]:
            case "--stale-after" | "--stale-days" if i + 1 < len(args):
                try:
                    stale_after = int(args[i + 1])
                except ValueError:
                    print(f"Invalid --stale-after value: {args[i + 1]}", file=sys.stderr)
                    return 1
                i += 2
            case "--fix":
                fix = True
                i += 1
            case "--help" | "-h":
                print(
                    "Usage: agent-toolkit memory review [--fix] [--stale-after N]\n"
                    "\n"
                    "Detects duplicates (similarity ≥ 80%), stale entries, contradictions,\n"
                    "and orphaned path references. Exit 1 when issues are found.\n"
                    "\n"
                    "  --stale-after N   Age threshold in days (default: 90)\n"
                    "  --fix            Print merge/fix suggestions (does not mutate files)\n"
                )
                return 0
            case _:
                print(f"Unknown review option: {args[i]}", file=sys.stderr)
                return 1

    entries = _collect_entries(knowledge)
    duplicates = _find_duplicates(entries)
    contradictions = _find_contradictions(entries)
    stale, orphans = _find_stale_and_orphans(entries, knowledge, stale_after=stale_after)

    print(f"\n{_blue('=== Memory Review ===')}\n")
    print(_dim(f"Scanned {len(entries)} entries under {knowledge} (stale-after={stale_after}d)"))
    print()

    issue_count = 0

    print(f"{_cyan('Duplicates')} (similarity ≥ 80%):")
    if duplicates:
        for left, right, ratio in duplicates[:20]:
            issue_count += 1
            rel_l = left.path.name
            rel_r = right.path.name
            print(
                f"  • {ratio:.0%}  {rel_l}:{left.line_no} ↔ {rel_r}:{right.line_no}"
            )
            print(_dim(f"      A: {left.text[:100]}"))
            print(_dim(f"      B: {right.text[:100]}"))
            if fix:
                print(
                    _yellow(
                        f"      suggestion: merge into one entry and delete the weaker duplicate "
                        f"({rel_r}:{right.line_no})"
                    )
                )
    else:
        print(_dim("  (none)"))
    print()

    print(f"{_cyan('Contradictions')} (use X vs don't use X):")
    if contradictions:
        seen: set[tuple[int, int, str]] = set()
        for user, avoider, key in contradictions:
            sig = (user.line_no, avoider.line_no, key)
            if sig in seen:
                continue
            seen.add(sig)
            issue_count += 1
            print(f"  • subject `{key}`")
            print(_dim(f"      use:     {user.path.name}:{user.line_no} — {user.text[:100]}"))
            print(_dim(f"      avoid:   {avoider.path.name}:{avoider.line_no} — {avoider.text[:100]}"))
            if fix:
                print(
                    _yellow(
                        "      suggestion: reconcile guidance; keep a single current recommendation"
                    )
                )
    else:
        print(_dim("  (none)"))
    print()

    print(f"{_cyan('Stale')} (older than {stale_after}d AND missing refs):")
    if stale:
        for entry, detail in stale[:20]:
            issue_count += 1
            print(f"  • {entry.path.name}:{entry.line_no} — {detail}")
            print(_dim(f"      {entry.text[:100]}"))
            if fix:
                print(_yellow("      suggestion: update the entry or remove obsolete guidance"))
    else:
        print(_dim("  (none)"))
    print()

    print(f"{_cyan('Orphaned references')} (path no longer exists):")
    if orphans:
        # Deduplicate by path+ref for display
        seen_o: set[tuple[str, int, str]] = set()
        for entry, detail in orphans[:30]:
            sig = (str(entry.path), entry.line_no, detail)
            if sig in seen_o:
                continue
            seen_o.add(sig)
            issue_count += 1
            print(f"  • {entry.path.name}:{entry.line_no} — {detail}")
            if fix:
                print(_yellow("      suggestion: fix the path or delete the orphaned note"))
    else:
        print(_dim("  (none)"))
    print()

    if issue_count == 0:
        print(_green("Knowledge base looks clean — no issues found."))
        return 0

    print(_yellow(f"Found {issue_count} issue(s)."))
    if not fix:
        print(_dim("Re-run with --fix for merge/update suggestions."))
    return 1


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
