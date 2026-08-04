#!/usr/bin/env python3
"""Validate Claude and Cursor marketplace manifests and plugin.json files."""

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
ERRORS: list[str] = []

def error(msg: str) -> None:
    ERRORS.append(msg)
    print(f"  ✗ {msg}")

def ok(msg: str) -> None:
    print(f"  ✓ {msg}")

def validate_marketplace(marketplace_path: Path, tool: str) -> None:
    if not marketplace_path.exists():
        error(f"Missing {marketplace_path.relative_to(REPO_ROOT)}")
        return

    try:
        data = json.loads(marketplace_path.read_text())
    except json.JSONDecodeError as e:
        error(f"{marketplace_path.relative_to(REPO_ROOT)}: invalid JSON: {e}")
        return

    for field in ["name", "owner", "metadata", "plugins"]:
        if not data.get(field):
            error(f"{tool} marketplace.json: missing '{field}'")

    plugin_root = data.get("metadata", {}).get("pluginRoot", "./plugins")
    plugin_root_path = REPO_ROOT / plugin_root.lstrip("./")

    for plugin in data.get("plugins", []):
        pname = plugin.get("name", "?")
        psource = plugin.get("source", "")
        plugin_dir = REPO_ROOT / psource.lstrip("./") if psource.startswith("./") else plugin_root_path / psource.lstrip("/")

        manifest_key = ".claude-plugin" if tool == "Claude Code" else ".cursor-plugin"
        plugin_json = plugin_dir / manifest_key / "plugin.json"

        if not plugin_json.exists():
            error(f"{tool} plugin '{pname}': {plugin_json.relative_to(REPO_ROOT)} not found")
            continue

        try:
            pdata = json.loads(plugin_json.read_text())
        except json.JSONDecodeError as e:
            error(f"{tool} plugin '{pname}': invalid plugin.json: {e}")
            continue

        if pdata.get("name") != pname:
            error(f"{tool} plugin '{pname}': name mismatch (marketplace='{pname}' vs plugin.json='{pdata.get('name')}')")
        
        for field in ["name", "version", "description", "author", "license"]:
            if not pdata.get(field):
                error(f"{tool} plugin '{pname}': plugin.json missing '{field}'")

        ok(f"{tool} plugin '{pname}' OK")

def main() -> int:
    print("\n🔍 Validating marketplace and plugin manifests...\n")

    print("── Claude Code ──")
    validate_marketplace(REPO_ROOT / ".claude-plugin/marketplace.json", "Claude Code")

    print("\n── Cursor ──")
    validate_marketplace(REPO_ROOT / ".cursor-plugin/marketplace.json", "Cursor")

    print()
    if ERRORS:
        print(f"❌ {len(ERRORS)} error(s) found")
        return 1
    print("✅ All manifests valid!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
