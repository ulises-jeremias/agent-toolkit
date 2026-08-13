#!/usr/bin/env python3
"""
Sync canonical agents/ and skills/ into plugin bundle surfaces.
Run with --check to fail on drift (used in CI).

.. deprecated::
   Primary gate is `agent-toolkit build --check` (ADR-003). This script remains
   for dual-run CI (`check-surfaces`) until removal at v1.6.0+ after `check-build`
   has been required on main.
"""

import argparse
import filecmp
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
AGENTS_DIR = REPO_ROOT / "agents"
SKILLS_DIR = REPO_ROOT / "skills"
PLUGINS_DIR = REPO_ROOT / "plugins"

# Map: plugin_name -> list of (source_dir, dest_subdir) tuples
SURFACES: dict[str, list[tuple[str, str]]] = {
    "agent-toolkit-core": [
        # (source relative to REPO_ROOT, destination in plugin)
        ("agents/code-reviewer", "agents/code-reviewer"),
        ("skills/core/assistant", "skills/assistant"),
        ("skills/core/dev-companion", "skills/dev-companion"),
        ("skills/core/output-handshake", "skills/output-handshake"),
        ("skills/core/pr-fallback", "skills/pr-fallback"),
        ("skills/core/workspace-knowledge-sync", "skills/workspace-knowledge-sync"),
        ("skills/core/onboarding", "skills/onboarding"),
    ],
    "agent-toolkit-agents": [
        (f"agents/{d.name}", f"agents/{d.name}") for d in sorted(AGENTS_DIR.iterdir()) if d.is_dir()
    ],
    "agent-toolkit-forge": [
        (f"skills/forge/{d.name}", f"skills/{d.name}")
        for d in sorted((SKILLS_DIR / "forge").iterdir())
        if d.is_dir()
    ],
}


def dirs_in_sync(src: Path, dst: Path) -> bool:
    if not dst.exists():
        return False
    cmp = filecmp.dircmp(src, dst)
    if cmp.left_only or cmp.right_only or cmp.diff_files:
        return False
    return all(dirs_in_sync(src / sub, dst / sub) for sub in cmp.common_dirs)


def sync_surface(src: Path, dst: Path, check: bool) -> bool:
    if not src.exists():
        return True  # source gone, skip
    in_sync = dirs_in_sync(src, dst)
    if in_sync:
        return True
    if check:
        print(f"  DRIFT: {src.relative_to(REPO_ROOT)} → {dst.relative_to(REPO_ROOT)}")
        return False
    # Sync
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    print(f"  synced: {src.relative_to(REPO_ROOT)} → {dst.relative_to(REPO_ROOT)}")
    return True


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true", help="Fail if surfaces are out of sync")
    args = parser.parse_args()

    mode = "checking" if args.check else "syncing"
    print(f"\n{'🔍' if args.check else '🔄'} gen-surfaces ({mode} plugin bundles)...\n")

    drift = False
    for plugin_name, surfaces in SURFACES.items():
        plugin_dir = PLUGINS_DIR / plugin_name
        if not plugin_dir.exists():
            print(f"  ⚠ Plugin dir missing: {plugin_name}")
            continue
        print(f"── {plugin_name} ──")
        for src_rel, dst_rel in surfaces:
            src = REPO_ROOT / src_rel
            dst = plugin_dir / dst_rel
            ok = sync_surface(src, dst, args.check)
            if not ok:
                drift = True

    print()
    if drift:
        print("❌ Plugin surfaces are out of sync — run: python3 scripts/gen-surfaces.py")
        return 1
    print("✅ All plugin surfaces are in sync!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
