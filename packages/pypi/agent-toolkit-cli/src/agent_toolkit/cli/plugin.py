"""
plugin — Plugin bundle management for agent-toolkit.

Usage:
    agent-toolkit plugin <subcommand>

Subcommands:
    sync     Sync canonical agents/skills into plugin bundles
    check    Verify plugin bundles are in sync (exit 1 if drift)

Options:
    --help   Show this help message
"""

from __future__ import annotations

import filecmp
import shutil
import sys
import sys as _sys_win
from pathlib import Path

from agent_toolkit._paths import toolkit_root
from agent_toolkit.compiler.provenance import verify_generated_digests

if _sys_win.platform == "win32":
    try:
        _sys_win.stdout.reconfigure(encoding="utf-8", errors="replace")
        _sys_win.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


# ---------------------------------------------------------------------------
# gen-surfaces logic (inlined from scripts/gen-surfaces.py)
# ---------------------------------------------------------------------------


def _build_surfaces(toolkit_dir: Path) -> dict[str, list[tuple[str, str]]]:
    """Return the plugin→surfaces mapping, mirroring scripts/gen-surfaces.py."""
    agents_dir = toolkit_dir / "agents"
    skills_dir = toolkit_dir / "skills"

    surfaces: dict[str, list[tuple[str, str]]] = {
        "agent-toolkit-core": [
            ("agents/code-reviewer", "agents/code-reviewer"),
            ("skills/core/assistant", "skills/assistant"),
            ("skills/core/dev-companion", "skills/dev-companion"),
            ("skills/core/output-handshake", "skills/output-handshake"),
            ("skills/core/pr-fallback", "skills/pr-fallback"),
            ("skills/core/workspace-knowledge-sync", "skills/workspace-knowledge-sync"),
            ("skills/core/onboarding", "skills/onboarding"),
        ],
    }

    # agent-toolkit-agents: one entry per agent directory
    if agents_dir.is_dir():
        surfaces["agent-toolkit-agents"] = [
            (f"agents/{d.name}", f"agents/{d.name}")
            for d in sorted(agents_dir.iterdir())
            if d.is_dir()
        ]
    else:
        surfaces["agent-toolkit-agents"] = []

    # agent-toolkit-forge: one entry per forge skill directory
    forge_dir = skills_dir / "forge"
    if forge_dir.is_dir():
        surfaces["agent-toolkit-forge"] = [
            (f"skills/forge/{d.name}", f"skills/{d.name}")
            for d in sorted(forge_dir.iterdir())
            if d.is_dir()
        ]
    else:
        surfaces["agent-toolkit-forge"] = []

    return surfaces


def _dirs_in_sync(src: Path, dst: Path) -> bool:
    """Recursively compare two directories. Return True if identical."""
    if not dst.exists():
        return False
    cmp = filecmp.dircmp(src, dst)
    if cmp.left_only or cmp.right_only or cmp.diff_files:
        return False
    return all(_dirs_in_sync(src / sub, dst / sub) for sub in cmp.common_dirs)


def _sync_surface(
    src: Path,
    dst: Path,
    toolkit_dir: Path,
    *,
    check: bool,
) -> bool:
    """Sync or check a single surface directory.

    In check mode returns False on drift.
    In sync mode returns True after syncing (or skip if source missing).
    """
    if not src.exists():
        return True  # source gone, silently skip

    in_sync = _dirs_in_sync(src, dst)
    if in_sync:
        return True

    if check:
        try:
            src_rel = src.relative_to(toolkit_dir)
            dst_rel = dst.relative_to(toolkit_dir)
        except ValueError:
            src_rel, dst_rel = src, dst
        print(f"  ✗  DRIFT: {src_rel} → {dst_rel}")
        return False

    # Sync
    try:
        if dst.exists():
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
        try:
            src_rel = src.relative_to(toolkit_dir)
            dst_rel = dst.relative_to(toolkit_dir)
        except ValueError:
            src_rel, dst_rel = src, dst
        print(f"  ✓  synced: {src_rel} → {dst_rel}")
        return True
    except (PermissionError, OSError) as exc:
        print(f"  ✗  Failed to sync {src} → {dst}: {exc}", file=sys.stderr)
        return False


def _run_gen_surfaces(toolkit_dir: Path, *, check: bool) -> int:
    """Run the full surface sync/check logic.

    Returns 0 on success, 1 if any drift or errors.
    """
    plugins_dir = toolkit_dir / "plugins"
    surfaces = _build_surfaces(toolkit_dir)

    mode = "checking" if check else "syncing"
    mode_icon = "🔍" if check else "🔄"
    print(f"\n{mode_icon} plugin bundles ({mode})...\n")

    drift = False
    for plugin_name, surface_pairs in surfaces.items():
        plugin_dir = plugins_dir / plugin_name
        if not plugin_dir.exists():
            print(f"  ⚠  Plugin dir missing: {plugin_name}")
            continue

        print(f"── {plugin_name} ──")
        for src_rel, dst_rel in surface_pairs:
            src = toolkit_dir / src_rel
            dst = plugin_dir / dst_rel
            ok = _sync_surface(src, dst, toolkit_dir, check=check)
            if not ok:
                drift = True

        if check:
            provenance_path = plugin_dir / ".provenance.json"
            if provenance_path.exists():
                for msg in verify_generated_digests(plugins_dir, provenance_path):
                    print(f"  ✗  {msg}")
                    drift = True

        print()

    if drift:
        print("  ✗  Plugin surfaces are out of sync")
        if check:
            print("     Run: agent-toolkit plugin sync")
        return 1

    print("  ✓  All plugin surfaces are in sync!")
    return 0


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------


def _cmd_sync(toolkit_dir: Path) -> int:
    """Sync canonical agents/skills into plugin bundles."""
    return _run_gen_surfaces(toolkit_dir, check=False)


def _cmd_check(toolkit_dir: Path) -> int:
    """Verify plugin bundles are in sync. Exit 1 if drift detected."""
    return _run_gen_surfaces(toolkit_dir, check=True)


# ---------------------------------------------------------------------------
# Argument parsing & dispatch
# ---------------------------------------------------------------------------


def cmd_plugin(args: list[str]) -> int:
    """Plugin bundle management entry point.

    Returns 0 on success, 1 on failure or drift.
    """
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return 0

    toolkit_dir = toolkit_root()
    if toolkit_dir is None:
        print("  ✗  Cannot locate toolkit directory", file=sys.stderr)
        return 1

    subcommand = args[0]

    if subcommand == "sync":
        return _cmd_sync(toolkit_dir)
    elif subcommand == "check":
        return _cmd_check(toolkit_dir)
    else:
        print(f"  ✗  Unknown subcommand: {subcommand}", file=sys.stderr)
        print("  Valid subcommands: sync, check", file=sys.stderr)
        return 1
