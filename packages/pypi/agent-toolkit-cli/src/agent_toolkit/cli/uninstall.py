"""
uninstall — Remove agent-toolkit profile files recorded in install receipts.

Usage:
    agent-toolkit uninstall [options]

Options:
    --tools <list>   Comma-separated tools to uninstall (default: all with receipts)
    --dry-run        Show what would be removed without deleting files
    --rollback       Alias for uninstall (removes toolkit-owned files from receipt)
    --help           Show this help message
"""

from __future__ import annotations

import sys
from pathlib import Path

from agent_toolkit.installer import tracking
from agent_toolkit.installer.receipt import InstallReceipt

_VALID_TOOLS = ("claude-code", "cursor", "opencode", "copilot", "windsurf", "pi")
_TOOL_RECEIPT_TARGETS = {
    "claude-code": "claude-code",
    "cursor": "cursor",
    "opencode": "opencode",
    "copilot": "copilot",
    "windsurf": "windsurf",
    "pi": "pi",
}


def _info(msg: str) -> None:
    print(f"  [info]  {msg}")


def _ok(msg: str) -> None:
    print(f"  ✓  {msg}")


def _skip(msg: str) -> None:
    print(f"  -  {msg}")


def _dry(msg: str) -> None:
    print(f"  [dry]   {msg}")


def _err(msg: str) -> None:
    print(f"  ✗  {msg}", file=sys.stderr)


def _parse_args(args: list[str]) -> tuple[list[str], bool, bool] | None:
    dry_run = False
    requested = ""
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            print(__doc__)
            return None
        if arg in ("--dry-run",):
            dry_run = True
        elif arg in ("--rollback",):
            dry_run = False  # rollback is uninstall with side effects
        elif arg == "--tools":
            if i + 1 >= len(args):
                _err("--tools requires an argument")
                return None
            requested = args[i + 1]
            i += 1
        else:
            _err(f"Unknown option: {arg}")
            return None
        i += 1

    if requested:
        tools = [t.strip() for t in requested.split(",") if t.strip()]
    else:
        tools = []
    return tools, dry_run, True


def _discover_tools(receipt_dir: Path) -> list[str]:
    found: list[str] = []
    if not receipt_dir.is_dir():
        return found
    for path in sorted(receipt_dir.glob(f"*-{tracking.PRODUCT}.json")):
        target = path.name[: -len(f"-{tracking.PRODUCT}.json")]
        for tool, receipt_target in _TOOL_RECEIPT_TARGETS.items():
            if receipt_target == target and tool not in found:
                found.append(tool)
    return found


def _uninstall_tool(tool: str, *, dry_run: bool, receipt_dir: Path) -> bool:
    target = _TOOL_RECEIPT_TARGETS.get(tool)
    if target is None:
        _err(f"Unknown tool: {tool}")
        return False

    receipt = InstallReceipt.load(target, tracking.PRODUCT, receipt_dir)
    if receipt is None:
        _skip(f"No receipt for {tool} — nothing to uninstall")
        return True

    _info(f"Uninstalling {tool} ({len(receipt.artifacts)} artifact(s) from receipt)")
    removed = 0
    for entry in receipt.artifacts:
        if entry.ownership != "created":
            _skip(f"Skipping non-owned file ({entry.ownership}): {entry.path}")
            continue
        path = Path(entry.path)
        if not path.exists():
            _skip(f"Already absent: {path}")
            continue
        if dry_run:
            _dry(f"Would remove: {path}")
        else:
            try:
                path.unlink()
                _ok(f"Removed: {path}")
            except OSError as exc:
                _err(f"Failed to remove {path}: {exc}")
                return False
        removed += 1

    if not dry_run:
        receipt_path = receipt_dir / f"{target}-{tracking.PRODUCT}.json"
        if receipt_path.exists():
            receipt_path.unlink()
            _ok(f"Removed receipt: {receipt_path}")

    _info(f"{tool}: processed {removed} owned file(s)")
    return True


def cmd_uninstall(args: list[str]) -> int:
    parsed = _parse_args(args)
    if parsed is None:
        return 0 if any(a in ("-h", "--help") for a in args) else 2
    tools, dry_run, _ = parsed

    rdir = tracking.receipt_dir()
    if not tools:
        tools = _discover_tools(rdir)
        if not tools:
            _err("No install receipts found. Nothing to uninstall.")
            return 1

    print()
    print("agent-toolkit uninstall")
    if dry_run:
        _info("DRY RUN — no files will be deleted")

    failed: list[str] = []
    for tool in tools:
        if tool not in _VALID_TOOLS:
            _err(f"Unknown tool: {tool}")
            failed.append(tool)
            continue
        if not _uninstall_tool(tool, dry_run=dry_run, receipt_dir=rdir):
            failed.append(tool)

    print()
    return 1 if failed else 0
