#!/usr/bin/env python3
"""Bump all version sources atomically. Usage: bump-version.py [--check] X.Y.Z"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def bump_file(path, pattern, repl, version):
    p = ROOT / path
    if not p.exists():
        return False
    t = p.read_text()
    new, n = re.subn(pattern, repl.format(version=version), t)
    if n == 0:
        return False
    if "--check" in sys.argv:
        print(f"would bump {path}")
        return True
    p.write_text(new)
    print(f"bumped {path}")
    return True


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    check = "--check" in sys.argv
    if not args:
        print("Usage: bump-version.py [--check] X.Y.Z", file=sys.stderr)
        sys.exit(2)
    version = args[0]
    if not re.match(r"^\d+\.\d+\.\d+", version):
        print(f"invalid version {version}", file=sys.stderr)
        sys.exit(2)
    changed = 0
    # VERSION
    p = ROOT / "VERSION"
    if p.exists():
        old = p.read_text().strip()
        if old != version:
            print(f"VERSION {old} -> {version}")
            if not check:
                p.write_text(version + "\n")
            changed += 1
    # __init__.py
    changed += bump_file(
        "packages/agent-toolkit-cli/src/agent_toolkit/__init__.py",
        r'__version__ = ".*"',
        '__version__ = "{version}"',
        version,
    )
    # V embedded_version fallback (parity with VERSION / __init__.py)
    changed += bump_file(
        "modules/agent_toolkit_core/version.v",
        r"pub const embedded_version = '.*'",
        "pub const embedded_version = '{version}'",
        version,
    )
    # package.json
    pkg = ROOT / "package.json"
    if pkg.exists():
        data = json.loads(pkg.read_text())
        if data.get("version") != version:
            print(f"package.json {data.get('version')} -> {version}")
            if not check:
                data["version"] = version
                pkg.write_text(json.dumps(data, indent=2) + "\n")
            changed += 1
    # marketplace jsons
    for mp in [".claude-plugin/marketplace.json", ".cursor-plugin/marketplace.json"]:
        mp_path = ROOT / mp
        if mp_path.exists():
            data = json.loads(mp_path.read_text())
            orig = json.dumps(data, sort_keys=True)
            if "metadata" in data and "version" in data["metadata"]:
                data["metadata"]["version"] = version
            for pl in data.get("plugins", []):
                if "version" in pl:
                    pl["version"] = version
            if json.dumps(data, sort_keys=True) != orig:
                print(f"bumped {mp}")
                if not check:
                    mp_path.write_text(json.dumps(data, indent=2) + "\n")
                changed += 1
    # plugins/*/plugin.json (Agent Plugins 1.0 — preserve $schema and extensions)
    for pl in (ROOT / "plugins").glob("*/plugin.json"):
        data = json.loads(pl.read_text())
        if data.get("version") != version:
            print(f"bumped {pl.relative_to(ROOT)}")
            if not check:
                data["version"] = version
                # Ensure Agent Plugins fields preserved: $schema, extensions
                if "$schema" not in data:
                    data["$schema"] = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
                pl.write_text(json.dumps(data, indent=2) + "\n")
            changed += 1
        elif "$schema" not in data:
            print(f"fixing $schema for {pl.relative_to(ROOT)}")
            if not check:
                data["$schema"] = "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
                pl.write_text(json.dumps(data, indent=2) + "\n")
            changed += 1
    # Legacy Claude/Cursor plugin manifests inside plugins/*/.claude-plugin/ and .cursor-plugin/
    for legacy in list((ROOT / "plugins").glob("*/.claude-plugin/plugin.json")) + list(
        (ROOT / "plugins").glob("*/.cursor-plugin/plugin.json")
    ):
        data = json.loads(legacy.read_text())
        if data.get("version") != version:
            print(f"bumped {legacy.relative_to(ROOT)}")
            if not check:
                data["version"] = version
                legacy.write_text(json.dumps(data, indent=2) + "\n")
            changed += 1
    if check and changed:
        print(f"{changed} files would change", file=sys.stderr)
        sys.exit(1)
    if not check:
        print(f"bumped {changed} files to {version}")
        # also sync marketplace via same


if __name__ == "__main__":
    main()
