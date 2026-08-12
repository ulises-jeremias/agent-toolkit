"""
update — Refresh installed profiles from toolkit data.

Usage:
    agent-toolkit update [options]

Options:
    --tools <list>   Comma-separated tools to update (default: auto-detect installed)
    --check          Dry-run — show what would change without writing files
    --pin <version>  Download capability data from a specific release before updating
    --help           Show this help message

Examples:
    agent-toolkit update
    agent-toolkit update --tools cursor,opencode
    agent-toolkit update --check
    agent-toolkit update --pin 1.1.0
"""

from __future__ import annotations

import hashlib
import shutil
import sys
from collections.abc import Callable, Iterator
from dataclasses import dataclass, field
from pathlib import Path

from agent_toolkit._paths import reset_toolkit_root, toolkit_root
from agent_toolkit.cli.install import (
    _VALID_TOOLS,
    _detect_claude_code,
    _detect_cursor,
    _detect_opencode,
    _detect_pi,
    _detect_windsurf,
    _windsurf_config_dir,
)

_PARSE_HELP = object()
_PARSE_ERROR = object()


@dataclass
class FileMapping:
    src: Path
    dst: Path


@dataclass
class ToolUpdatePlan:
    tool: str
    changed: list[Path] = field(default_factory=list)
    added: list[Path] = field(default_factory=list)
    up_to_date: list[Path] = field(default_factory=list)


def _file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _iter_files(root: Path) -> Iterator[Path]:
    if not root.is_dir():
        return
    for path in sorted(root.rglob("*")):
        if path.is_file():
            yield path


def _mappings_for_tool(tool: str, data_root: Path, home: Path) -> list[FileMapping]:
    mappings: list[FileMapping] = []

    if tool == "claude-code":
        src = data_root / "profiles" / "claude-code"
        if src.is_dir():
            claude = src / "CLAUDE.md"
            if claude.is_file():
                mappings.append(FileMapping(claude, home / ".claude" / "CLAUDE.md"))
            agents = src / "agents"
            if agents.is_dir():
                for f in _iter_files(agents):
                    rel = f.relative_to(agents)
                    mappings.append(FileMapping(f, home / ".claude" / "agents" / rel))

    elif tool == "cursor":
        src = data_root / "profiles" / "cursor" / "rules"
        if src.is_dir():
            for f in _iter_files(src):
                rel = f.relative_to(src)
                mappings.append(FileMapping(f, home / ".cursor" / "rules" / rel))

    elif tool == "opencode":
        src = data_root / "profiles" / "opencode"
        cfg = src / "opencode.json"
        if cfg.is_file():
            mappings.append(FileMapping(cfg, home / ".config" / "opencode" / "opencode.json"))
        agents = src / "agents"
        if agents.is_dir():
            for f in _iter_files(agents):
                rel = f.relative_to(agents)
                mappings.append(FileMapping(f, home / ".config" / "opencode" / "agents" / rel))

    elif tool == "windsurf":
        src = data_root / "profiles" / "windsurf"
        config_dir = _windsurf_config_dir()
        for sub in ("rules", "memories"):
            sub_src = src / sub
            if sub_src.is_dir():
                for f in _iter_files(sub_src):
                    rel = f.relative_to(sub_src)
                    mappings.append(FileMapping(f, config_dir / sub / rel))

    elif tool == "pi":
        src = data_root / "profiles" / "pi" / "skills"
        if src.is_dir():
            for f in _iter_files(src):
                rel = f.relative_to(src)
                mappings.append(FileMapping(f, home / ".pi" / "agent" / "skills" / rel))

    return mappings


def _plan_tool_update(tool: str, data_root: Path, home: Path) -> ToolUpdatePlan | None:
    mappings = _mappings_for_tool(tool, data_root, home)
    if not mappings:
        return None

    plan = ToolUpdatePlan(tool=tool)
    for mapping in mappings:
        if not mapping.src.is_file():
            continue
        src_hash = _file_hash(mapping.src)
        if mapping.dst.is_file():
            if _file_hash(mapping.dst) == src_hash:
                plan.up_to_date.append(mapping.dst)
            else:
                plan.changed.append(mapping.dst)
        else:
            plan.added.append(mapping.dst)
    return plan


def _detect_installed_tools() -> list[str]:
    detectors: list[tuple[str, Callable[[], bool]]] = [
        ("claude-code", _detect_claude_code),
        ("cursor", _detect_cursor),
        ("opencode", _detect_opencode),
        ("windsurf", _detect_windsurf),
        ("pi", _detect_pi),
    ]
    return [name for name, fn in detectors if fn()]


def _apply_plan(plan: ToolUpdatePlan, data_root: Path, home: Path, *, check_only: bool) -> int:
    updated = 0
    mappings = _mappings_for_tool(plan.tool, data_root, home)
    targets = {m.dst for m in mappings if m.dst in plan.changed or m.dst in plan.added}

    for mapping in mappings:
        if mapping.dst not in targets:
            continue
        rel = mapping.dst.relative_to(home) if mapping.dst.is_relative_to(home) else mapping.dst
        if check_only:
            print(f"  ~ would update: ~/{rel}")
            updated += 1
            continue
        mapping.dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(mapping.src, mapping.dst)
        print(f"  ✓ updated: ~/{rel}")
        updated += 1
    return updated


def _parse_args(args: list[str]):
    tools: list[str] = []
    check_only = False
    pin: str | None = None
    requested = ""

    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            print(__doc__)
            return _PARSE_HELP
        if arg == "--check":
            check_only = True
        elif arg == "--tools":
            if i + 1 >= len(args):
                print("  ✗  --tools requires an argument", file=sys.stderr)
                return _PARSE_ERROR
            requested = args[i + 1]
            i += 1
        elif arg == "--pin":
            if i + 1 >= len(args):
                print("  ✗  --pin requires an argument", file=sys.stderr)
                return _PARSE_ERROR
            pin = args[i + 1]
            i += 1
        else:
            print(f"  ✗  Unknown option: {arg}", file=sys.stderr)
            return _PARSE_ERROR
        i += 1

    if requested:
        tools = [t.strip() for t in requested.split(",") if t.strip()]
    return tools, check_only, pin


def cmd_update(args: list[str]) -> int:
    """Refresh installed profiles from toolkit data."""
    result = _parse_args(args)
    if result is _PARSE_HELP:
        return 0
    if result is _PARSE_ERROR:
        return 2

    tools, check_only, pin = result

    print()
    print("agent-toolkit update")

    # Refresh capability data cache when pinned or stale
    if pin:
        from agent_toolkit.data_sync import download_data

        reset_toolkit_root()
        try:
            download_data(pin, force=True)
        except RuntimeError as exc:
            print(f"  ✗  {exc}", file=sys.stderr)
            return 1
    else:
        from agent_toolkit import __version__
        from agent_toolkit._paths import _offline_mode
        from agent_toolkit.data_sync import cached_version, download_data

        cv = cached_version()
        if cv is None or cv.lstrip("v") != __version__.lstrip("v"):
            if _offline_mode():
                print("  ⚠  Data refresh skipped: offline mode (AGENT_TOOLKIT_OFFLINE)")
            else:
                try:
                    download_data(__version__, force=True, quiet=check_only)
                    reset_toolkit_root()
                except (RuntimeError, OSError) as exc:
                    print(f"  ⚠  Data refresh skipped: {exc}")

    try:
        data_root = toolkit_root()
    except EnvironmentError as exc:
        print(f"  ✗  {exc}", file=sys.stderr)
        return 1

    print(f"  Data: {data_root}")
    if check_only:
        print("  [check] Dry run — no files will be written")

    if not tools:
        tools = _detect_installed_tools()
        if not tools:
            print("  ⚠  No installed tools detected. Use --tools to specify targets.")
            return 1
        print(f"  Tools: {', '.join(tools)}")

    home = Path.home()
    total_changes = 0
    any_errors = False

    for tool in tools:
        if tool not in _VALID_TOOLS:
            print(f"  ⚠  Unknown tool: {tool}")
            any_errors = True
            continue

        plan = _plan_tool_update(tool, data_root, home)
        if plan is None:
            print(f"  ⚠  No profile data for: {tool}")
            continue

        pending = len(plan.changed) + len(plan.added)
        if pending == 0:
            print(f"  ✓ {tool}: up to date ({len(plan.up_to_date)} files)")
            continue

        print(f"  → {tool}: {len(plan.changed)} changed, {len(plan.added)} new")
        total_changes += _apply_plan(plan, data_root, home, check_only=check_only)

    print()
    if check_only:
        print(f"  {total_changes} file(s) would be updated")
        return 1 if total_changes else 0

    if total_changes:
        print(f"  Updated {total_changes} file(s)")
    else:
        print("  All profiles up to date")
    return 1 if any_errors else 0
