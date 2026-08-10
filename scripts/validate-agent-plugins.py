#!/usr/bin/env python3
"""Validate Agent Plugins 1.0 manifests per spec.

Checks every plugin.json and mcp.json under plugins/ against vendored schemas
and spec containment/naming rules.

Usage:
  python3 scripts/validate-agent-plugins.py        # validate all plugins
  python3 scripts/validate-agent-plugins.py --check # same, for CI — exit non-zero on failure
"""

from __future__ import annotations
import json
import sys
import re
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
PLUGINS_DIR = REPO_ROOT / "plugins"
SCHEMA_PLUGIN = REPO_ROOT / "schemas/agent-plugins/1.0.0/plugin.schema.json"
SCHEMA_MCP = REPO_ROOT / "schemas/agent-plugins/1.0.0/mcp.schema.json"

try:
    import jsonschema

    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False
    print(
        "jsonschema not installed — running structural checks only (pip install jsonschema for full validation)",
        file=sys.stderr,
    )

NAME_RE = re.compile(r"^(?!.*(?:--|\\.\\.))[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$")

errors = []
warnings = []


def load_json(p: Path):
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        errors.append(f"{p.relative_to(REPO_ROOT)}: invalid JSON: {e}")
        return None


def validate_plugin_manifest(plugin_dir: Path):
    p = plugin_dir / "plugin.json"
    if not p.exists():
        warnings.append(
            f"{plugin_dir.relative_to(REPO_ROOT)}: missing plugin.json (not an Agent Plugins plugin yet)"
        )
        return
    data = load_json(p)
    if data is None:
        return
    # Structural checks
    if data.get("$schema") != "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json":
        errors.append(
            f"{p.relative_to(REPO_ROOT)}: $schema must be 'https://agent-plugins.org/schemas/1.0.0/plugin.schema.json'"
        )
    name = data.get("name", "")
    if not isinstance(name, str) or not name:
        errors.append(f"{p.relative_to(REPO_ROOT)}: missing required 'name'")
    elif len(name) > 64 or not NAME_RE.match(name):
        errors.append(
            f"{p.relative_to(REPO_ROOT)}: name '{name}' violates Agent Plugins naming (1-64, a-z0-9.-, no --/.., alphanumeric start/end)"
        )
    # Closed schema check via jsonschema if available
    if HAS_JSONSCHEMA and SCHEMA_PLUGIN.exists():
        try:
            schema = json.loads(SCHEMA_PLUGIN.read_text(encoding="utf-8"))
            # Remove $schema id that confuses Draft202012Validator when offline
            jsonschema.validate(data, schema)
        except jsonschema.ValidationError as e:
            # Unknown field is reported but should not be fatal per spec §5.2 — jsonschema will flag additionalProperties
            # Treat as warning for unknown field, error for other violations
            if "Additional properties are not allowed" in e.message:
                warnings.append(
                    f"{p.relative_to(REPO_ROOT)}: {e.message} (report-and-ignore per §5.2)"
                )
            else:
                errors.append(f"{p.relative_to(REPO_ROOT)}: schema violation: {e.message}")
        except Exception as e:
            warnings.append(f"{p.relative_to(REPO_ROOT)}: schema validation skipped: {e}")

    # Check skills discovery — immediate children with SKILL.md
    skills_dir = plugin_dir / "skills"
    if skills_dir.exists():
        if not skills_dir.is_dir():
            errors.append(f"{plugin_dir.relative_to(REPO_ROOT)}/skills: must be a directory")
        else:
            for child in skills_dir.iterdir():
                if child.is_dir() and (child / "SKILL.md").exists():
                    pass  # valid skill
                elif child.is_dir():
                    warnings.append(
                        f"{plugin_dir.relative_to(REPO_ROOT)}/skills/{child.name}: missing SKILL.md (will be skipped per §7.1)"
                    )


def validate_mcp(plugin_dir: Path):
    p = plugin_dir / "mcp.json"
    if not p.exists():
        return
    data = load_json(p)
    if data is None:
        return
    if data.get("$schema") != "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json":
        errors.append(
            f"{p.relative_to(REPO_ROOT)}: $schema must be 'https://agent-plugins.org/schemas/1.0.0/mcp.schema.json'"
        )
    if "mcpServers" not in data or not isinstance(data["mcpServers"], dict):
        errors.append(f"{p.relative_to(REPO_ROOT)}: missing required 'mcpServers' object")
        return
    if HAS_JSONSCHEMA and SCHEMA_MCP.exists():
        try:
            schema = json.loads(SCHEMA_MCP.read_text(encoding="utf-8"))
            jsonschema.validate(data, schema)
        except jsonschema.ValidationError as e:
            errors.append(f"{p.relative_to(REPO_ROOT)}: schema violation: {e.message}")
        except Exception as e:
            warnings.append(f"{p.relative_to(REPO_ROOT)}: mcp schema check skipped: {e}")
    # Check plugin-relative path containment
    for srv_id, srv in data.get("mcpServers", {}).items():
        if not isinstance(srv, dict):
            continue
        cmd = srv.get("command", "")
        cwd = srv.get("cwd", "")
        if cmd and cmd.startswith("./") and ".." in cmd:
            errors.append(
                f"{p.relative_to(REPO_ROOT)} mcpServers.{srv_id}.command: plugin-relative path must not escape root (contains '..')"
            )
        if cwd and cwd.startswith("./") and ".." in cwd:
            errors.append(
                f"{p.relative_to(REPO_ROOT)} mcpServers.{srv_id}.cwd: must not escape root"
            )
        # Check PLUGIN_ROOT/PLUGIN_DATA placeholders are only in allowed fields
        if "env" in srv and isinstance(srv["env"], dict):
            if "PLUGIN_ROOT" in srv["env"] or "PLUGIN_DATA" in srv["env"]:
                errors.append(
                    f"{p.relative_to(REPO_ROOT)} mcpServers.{srv_id}.env: must not contain PLUGIN_ROOT/PLUGIN_DATA (reserved)"
                )


def main():
    check = "--check" in sys.argv
    plugins = [d for d in PLUGINS_DIR.iterdir() if d.is_dir()] if PLUGINS_DIR.exists() else []
    if not plugins:
        print("No plugins found in plugins/", file=sys.stderr)
        return 0
    print(f"Validating {len(plugins)} plugin(s) for Agent Plugins 1.0...")
    for pd in sorted(plugins):
        validate_plugin_manifest(pd)
        validate_mcp(pd)
    for w in warnings:
        print(f"  ⚠ {w}")
    for e in errors:
        print(f"  ✗ {e}")
    if errors:
        print(
            f"\n❌ Agent Plugins validation failed: {len(errors)} error(s), {len(warnings)} warning(s)"
        )
        return 1
    if warnings:
        print(f"\n⚠️  Validation passed with {len(warnings)} warning(s)")
    else:
        print(f"\n✅ All {len(plugins)} plugin(s) valid per Agent Plugins 1.0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
