#!/usr/bin/env python3
"""generate-surface.py — emit OpenAPI, CLI help, TUI registry and Web nav
from docs/compatibility/cli-contract.yaml (SSOT for all surfaces).

Part of feature-complete serve epic (#831, Phase 0).
Usage:
  python3 scripts/generate_surface.py            # write artifacts
  python3 scripts/generate_surface.py --check    # fail if stale
Outputs (idempotent):
  dist/surface/openapi.json
  dist/surface/cli-help.md
  modules/agent_toolkit_server/tui_registry.v
  dist/surface/web_nav.json
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs" / "compatibility" / "cli-contract.yaml"
OUT = ROOT / "docs" / "surface"
TUI_REG = ROOT / "modules" / "agent_toolkit_server" / "tui_registry.v"

# effect-noun → scope mapping (ADR-029 policy scopes)
SCOPE_BY_EFFECT = {
    "write-profiles-receipts": "write:fs",
    "update-profiles-cache": "write:fs",
    "delete-owned-files": "write:fs",
    "optional-fix-writes": "write:fs",
    "write-catalog": "write:catalog",
    "write-plugins": "write:plugins",
    "write-loops": "write:loops",
    "write-swarm": "write:swarm",
    "write-memory": "write:memory",
    "write-projects": "write:projects",
    "write-dc": "write:dc",
    "write-mcp": "write:mcp",
    "write-workspace": "write:workspace",
}

MUTATING_SUBSTRINGS = (
    "run",
    "start",
    "schedule",
    "sync",
    "add",
    "queue",
    "setup",
    "clone",
    "remove",
    "install",
    "update",
    "uninstall",
    "scan",
    "emit",
)

DESTRUCTIVE = {
    "uninstall",
    "install",
    "plugin",
    "build",
    "doctor",
    "mcp",
    "skills",
    "project",
    "devcompanion",
    "swarm",
    "workspace",
}

READ_ONLY = {"help", "version", "inventory", "matrix", "diff", "doctor"}


def load() -> dict:
    return yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))


def is_mutating(cmd: dict) -> bool:
    name = cmd["name"]
    if name in READ_ONLY:
        return False
    effects = cmd.get("effects") or {}
    fs = str(effects.get("filesystem", ""))
    if any(k in fs for k in ("write", "delete", "update")):
        return True
    return any(s in name for s in MUTATING_SUBSTRINGS) or name in DESTRUCTIVE


def scope_for(cmd: dict) -> str:
    if not is_mutating(cmd):
        return "read:*"
    effects = cmd.get("effects") or {}
    fs = str(effects.get("filesystem", ""))
    for key, scope in SCOPE_BY_EFFECT.items():
        if key in fs:
            return scope
    # fallback by command group
    n = cmd["name"]
    fallback = {
        "loop": "write:loops",
        "swarm": "write:swarm",
        "memory": "write:memory",
        "project": "write:projects",
        "devcompanion": "write:dc",
        "mcp": "write:mcp",
        "plugin": "write:plugins",
        "skills": "write:catalog",
        "build": "write:plugins",
        "workspace": "write:workspace",
        "install": "write:fs",
        "update": "write:fs",
        "uninstall": "write:fs",
        "doctor": "write:fs",
    }
    return fallback.get(n, "write:*")


def needs_confirm(cmd: dict) -> bool:
    return is_mutating(cmd) and cmd["name"] in DESTRUCTIVE


def route_for(cmd: dict) -> tuple[str, str]:
    """Return (method, path)."""
    n = cmd["name"]
    if n == "help":
        return "GET", "/api/v1/help"
    if n == "version":
        return "GET", "/api/v1/version"
    if n == "completion":
        return "GET", "/api/v1/completion/{shell}"
    if n == "loop":
        return "POST", "/api/v1/loops/{sub}"
    if n == "swarm":
        return "POST", "/api/v1/swarms/{sub}"
    if n == "workspace":
        if is_mutating(cmd):
            return "POST", "/api/v1/workspace/{sub}"
        return "GET", "/api/v1/workspace/context"
    if n == "project":
        return "POST", "/api/v1/project/{sub}"
    if n == "devcompanion":
        return "POST", "/api/v1/dc/{sub}"
    if n == "memory":
        return "POST", "/api/v1/memory/{sub}"
    if n == "mcp":
        return "POST", "/api/v1/mcp/{sub}"
    if n == "plugin":
        return "POST", "/api/v1/plugin/{sub}"
    if n == "skills":
        return "POST", "/api/v1/skills/{sub}"
    if is_mutating(cmd):
        return "POST", f"/api/v1/{n}"
    return "GET", f"/api/v1/{n}"


def gen_openapi(contract: dict) -> dict:
    paths: dict = {}
    for cmd in contract.get("commands", []):
        method, path = route_for(cmd)
        op = {
            "operationId": cmd["name"],
            "summary": cmd.get("summary", cmd["name"]),
            "tags": [cmd.get("surface", "misc")],
            "x-scope": scope_for(cmd),
            "x-confirm-required": needs_confirm(cmd),
            "responses": {
                "200": {"description": "ok"},
                "403": {"description": "scope denied"},
                "428": {"description": "confirm required"},
            },
        }
        paths.setdefault(path, {})[method.lower()] = op
    return {
        "openapi": "3.1.0",
        "info": {
            "title": "agent-toolkit serve API",
            "version": Path(ROOT / "VERSION").read_text().strip(),
            "description": "Generated from docs/compatibility/cli-contract.yaml — do not hand-edit.",
        },
        "paths": paths,
    }


def gen_help_md(contract: dict) -> str:
    groups: dict[str, list] = {}
    for cmd in contract.get("commands", []):
        groups.setdefault(cmd.get("surface", "misc"), []).append(cmd)
    order = ["meta", "consumer", "advanced"]
    lines = [
        "# agent-toolkit CLI reference",
        "",
        "_Generated from docs/compatibility/cli-contract.yaml — do not hand-edit._",
        "",
    ]
    for g in order + [k for k in groups if k not in order]:
        cmds = sorted(groups.get(g, []), key=lambda c: c["name"])
        if not cmds:
            continue
        lines += [f"## {g}", "", "| Command | Summary | Flags | Scope |", "|---|---|---|---|"]
        for c in cmds:
            flags = "`" + "` `".join(c.get("flags", [])) + "`" if c.get("flags") else "—"
            lines.append(f"| `{c['name']}` | {c.get('summary', '')} | {flags} | `{scope_for(c)}` |")
        lines.append("")
    return "\n".join(lines) + "\n"


V_HEADER = """// Code generated by scripts/generate_surface.py — DO NOT EDIT.
// Regenerate: python3 scripts/generate_surface.py
module agent_toolkit_server

pub struct TuiAction {
pub:
	name    string
	title   string
	method  string
	route   string
	scope   string
	confirm bool
}

pub fn tui_actions() []TuiAction {
	return [
"""


def gen_tui_registry(contract: dict) -> str:
    rows = []
    for cmd in contract.get("commands", []):
        method, path = route_for(cmd)
        title = cmd.get("summary", cmd["name"]).replace("'", "\\'")
        confirm = "true" if needs_confirm(cmd) else "false"
        rows.append(
            "\t\tTuiAction{ name: '%s', title: '%s', method: '%s', route: '%s', scope: '%s', confirm: %s },"
            % (cmd["name"], title, method.upper(), path, scope_for(cmd), confirm)
        )
    return V_HEADER + "\n".join(rows) + "\n\t]\n}\n"


def gen_web_nav(contract: dict) -> dict:
    groups: dict[str, list] = {}
    for cmd in contract.get("commands", []):
        method, path = route_for(cmd)
        groups.setdefault(cmd.get("surface", "misc"), []).append(
            {
                "name": cmd["name"],
                "method": method.upper(),
                "route": path,
                "scope": scope_for(cmd),
                "confirm": needs_confirm(cmd),
            }
        )
    order = ["meta", "consumer", "advanced"]
    return {
        "groups": [
            {"title": g, "items": sorted(groups[g], key=lambda i: i["name"])}
            for g in order
            if g in groups
        ]
    }


def main() -> int:
    check = "--check" in sys.argv
    contract = load()
    OUT.mkdir(parents=True, exist_ok=True)

    artifacts = {
        OUT / "openapi.json": json.dumps(gen_openapi(contract), indent=2) + "\n",
        OUT / "cli-help.md": gen_help_md(contract),
        TUI_REG: gen_tui_registry(contract),
        OUT / "web_nav.json": json.dumps(gen_web_nav(contract), indent=2) + "\n",
    }

    stale = []
    for path, content in artifacts.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current != content:
            stale.append(str(path.relative_to(ROOT)))
            if not check:
                path.write_text(content, encoding="utf-8")
                print(f"wrote {path.relative_to(ROOT)}")
    if stale:
        print(f"{'stale' if check else 'updated'}: {', '.join(stale)}")
        if check:
            print("Run: python3 scripts/generate_surface.py")
            return 1
    else:
        print("surface artifacts up to date")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
