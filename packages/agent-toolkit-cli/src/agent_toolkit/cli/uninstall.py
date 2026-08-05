"""
uninstall — Remove agent-toolkit profile files recorded in install receipts.

Usage:
    agent-toolkit uninstall [options]

Options:
    --tools <list>   Comma-separated tools to uninstall (default: all with receipts)
    --dry-run        Show what would be removed without deleting files
    --rollback       Alias for uninstall (removes toolkit-owned files from receipt)
    --clean-home     Remove receipt-owned files then delete empty toolkit config dirs
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
    clean_home = False
    requested = ""
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ("-h", "--help"):
            print(__doc__)
            return None
        if arg in ("--dry-run",):
            dry_run = True
        elif arg in ("--rollback", "--clean-home"):
            clean_home = True
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

    tools = [t.strip() for t in requested.split(",") if t.strip()] if requested else []
    return tools, dry_run, clean_home


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


def _remove_empty_parents(path: Path, stop_at: Path) -> None:
    current = path.parent
    while current != stop_at and current.is_dir():
        try:
            next(current.iterdir())
        except StopIteration:
            current.rmdir()
            current = current.parent
        else:
            break


def _clean_config_home(receipt_dir: Path, *, dry_run: bool) -> None:
    config_root = Path.home() / ".config" / "agent-toolkit"
    if receipt_dir.exists() and not any(receipt_dir.iterdir()):
        if dry_run:
            _dry(f"Would remove empty receipt dir: {receipt_dir}")
        else:
            receipt_dir.rmdir()
            _ok(f"Removed empty receipt dir: {receipt_dir}")
    if config_root.exists() and not any(config_root.iterdir()):
        if dry_run:
            _dry(f"Would remove empty config dir: {config_root}")
        else:
            config_root.rmdir()
            _ok(f"Removed empty config dir: {config_root}")


def _uninstall_tool(
    tool: str,
    *,
    dry_run: bool,
    receipt_dir: Path,
    clean_home: bool,
) -> bool:
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
                if clean_home:
                    _remove_empty_parents(path, Path.home())
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
    tools, dry_run, clean_home = parsed

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
        if not _uninstall_tool(tool, dry_run=dry_run, receipt_dir=rdir, clean_home=clean_home):
            failed.append(tool)

    if clean_home:
        _clean_config_home(rdir, dry_run=dry_run)

    print()
    return 1 if failed else 0
