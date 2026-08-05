"""
update — Refresh installed profiles from bundled toolkit data.

Usage:
    agent-toolkit update [options]

Options:
    --tools <list>   Comma-separated tools to update (default: all detected)
    --check          Show what would change without writing files
    --pin <version>  Reserved: pin to a specific release version
    --help           Show this help message
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

from agent_toolkit._paths import toolkit_root
from agent_toolkit.cli.install import (
    _VALID_TOOLS,
    _copy_dir,
    _copy_file,
    _detect_claude_code,
    _detect_cursor,
    _detect_opencode,
    _detect_pi,
    _detect_windsurf,
    _info,
    _ok,
    _warn,
)


def _file_digest(path: Path) -> str:
    if not path.is_file():
        return ""
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _compare_tree(src_dir: Path, dst_dir: Path) -> list[str]:
    changes: list[str] = []
    if not src_dir.is_dir():
        return changes
    for src_file in sorted(src_dir.rglob("*")):
        if not src_file.is_file():
            continue
        rel = src_file.relative_to(src_dir)
        dst_file = dst_dir / rel
        if _file_digest(src_file) != _file_digest(dst_file):
            changes.append(str(rel))
    return changes


def _profile_pairs(tool: str) -> list[tuple[Path, Path]]:
    root = toolkit_root()
    home = Path.home()
    pairs: list[tuple[Path, Path]] = []
    if tool == "claude-code":
        pairs.append((root / "profiles" / "claude-code" / "CLAUDE.md", home / ".claude" / "CLAUDE.md"))
        pairs.append((root / "profiles" / "claude-code" / "agents", home / ".claude" / "agents"))
    elif tool == "cursor":
        pairs.append((root / "profiles" / "cursor" / "rules", home / ".cursor" / "rules"))
    elif tool == "opencode":
        pairs.append((root / "profiles" / "opencode" / "agents", home / ".config" / "opencode" / "agents"))
    elif tool == "windsurf":
        pairs.append((root / "profiles" / "windsurf" / "rules", home / ".codeium" / "windsurf" / "rules"))
    elif tool == "pi":
        pairs.append((root / "profiles" / "pi" / "skills", home / ".pi" / "agent" / "skills"))
    return pairs


def _detect_installed_tools() -> list[str]:
    tools: list[str] = []
    if _detect_claude_code():
        tools.append("claude-code")
    if _detect_cursor():
        tools.append("cursor")
    if _detect_opencode():
        tools.append("opencode")
    if _detect_windsurf():
        tools.append("windsurf")
    if _detect_pi():
        tools.append("pi")
    return tools


def cmd_update(args: list[str]) -> int:
    tools: list[str] = []
    check_only = False
    pin: str | None = None

    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            print(__doc__)
            return 0
        if arg == "--check":
            check_only = True
        elif arg == "--tools":
            if i + 1 >= len(args):
                print("  ✗  --tools requires an argument", file=sys.stderr)
                return 2
            tools = [t.strip() for t in args[i + 1].split(",") if t.strip()]
            i += 1
        elif arg == "--pin":
            if i + 1 >= len(args):
                print("  ✗  --pin requires an argument", file=sys.stderr)
                return 2
            pin = args[i + 1]
            i += 1
        else:
            print(f"  ✗  Unknown option: {arg}", file=sys.stderr)
            return 2
        i += 1

    if pin:
        _warn(f"--pin {pin} is reserved for a future release; using bundled data")

    if not tools:
        tools = _detect_installed_tools()
    if not tools:
        _warn("No installed tools detected for update")
        return 1

    print()
    print("agent-toolkit update")
    _info(f"Tools: {', '.join(tools)}")
    if check_only:
        _info("CHECK ONLY — no files will be written")

    total_changes = 0
    for tool in tools:
        if tool not in _VALID_TOOLS:
            _warn(f"Skipping unknown tool: {tool}")
            continue
        print()
        _info(f"Checking {tool}...")
        changes: list[str] = []
        for src, dst in _profile_pairs(tool):
            if src.is_dir():
                changes.extend(_compare_tree(src, dst))
            elif src.is_file():
                if _file_digest(src) != _file_digest(dst):
                    changes.append(src.name)
        if not changes:
            _ok(f"{tool}: up to date")
            continue
        total_changes += len(changes)
        for rel in changes[:10]:
            print(f"    ~ {rel}")
        if len(changes) > 10:
            print(f"    ... and {len(changes) - 10} more")
        if not check_only:
            for src, dst in _profile_pairs(tool):
                if src.is_dir():
                    _copy_dir(src, dst, dry_run=False, force=True)
                elif src.is_file():
                    _copy_file(src, dst, dry_run=False, force=True)
            _ok(f"{tool}: updated {len(changes)} file(s)")

    print()
    if check_only:
        _info(f"Would update {total_changes} file(s) across {len(tools)} tool(s)")
    else:
        _ok(f"Update complete ({total_changes} file(s) changed)")
    return 0
