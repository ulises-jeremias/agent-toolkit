#!/usr/bin/env python3
"""generate-surface.py — emit OpenAPI, CLI help from cli-contract.yaml SSOT.

Part of feature-complete serve epic (#831, Phase 0), ADR-030 canonical.
Usage:
  python3 scripts/generate_surface.py            # write artifacts
  python3 scripts/generate_surface.py --check    # fail if stale
Outputs (idempotent, canonical per ADR-030):
  docs/surface/openapi.json  (embedded by server, parity-gated)
  docs/surface/cli-help.md   (docs/reference)
Legacy dist/surface/cli-help.md is deprecated — canonical is docs/surface;
dist is kept as symlink or removed (checked in --check).
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs" / "compatibility" / "cli-contract.yaml"
OUT = ROOT / "docs" / "surface"

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
        if not cmd.get("api", True):
            # Human/CLI-only capability (ADR-030): no programmatic surface.
            continue
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


# Server-native infrastructure endpoints: capabilities of the API itself,
# not mirrors of CLI contract commands (ADR-030). Documented in OpenAPI and
# enforced against registered veb routes by tests/test_surface_parity.py.
SERVER_NATIVE_PATHS = {
    "/api/v1/health": ("get", "health"),
    "/api/v1/openapi.json": ("get", "get_openapi"),
    "/api/v1/selfcheck": ("get", "selfcheck"),
    "/api/v1/jobs": ("post", "create_job"),
    "/api/v1/jobs/{id}/log": ("get", "get_job_log"),
    "/api/v1/jobs/{id}/events": ("get", "stream_job_events"),
    "/api/v1/doctor/fix": ("post", "doctor_fix"),
    "/api/v1/loops/{name}/status": ("get", "loop_status_by_name"),
    "/api/v1/loops/{name}/run": ("post", "run_loop_by_name"),
    "/api/v1/loops/{name}/schedule": ("post", "schedule_loop_by_name"),
    "/api/v1/swarms": ("get", "list_swarms"),
    "/api/v1/loops": ("get", "list_loops"),
}


def add_native_paths(paths: dict) -> None:
    for path, (method, op_id) in SERVER_NATIVE_PATHS.items():
        if path in paths:
            continue
        paths[path] = {
            method: {
                "operationId": op_id,
                "summary": f"Server-native endpoint ({op_id})",
                "x-scope": "read:*" if method == "get" else "write:*",
                "x-confirm-required": False,
                "responses": {"200": {"description": "OK"}},
            }
        }


def main() -> int:
    check = "--check" in sys.argv
    contract = load()
    OUT.mkdir(parents=True, exist_ok=True)

    # Validate CLI_SURFACES.md contains every contract command (SSOT check for #969)
    cli_surfaces = ROOT / "docs" / "CLI_SURFACES.md"
    if cli_surfaces.exists():
        import re as _re

        text = cli_surfaces.read_text(encoding="utf-8")
        found = set(_re.findall(r"\| `([^`]+)` \|", text))
        contract_names = {c["name"] for c in contract.get("commands", [])}
        missing = contract_names - found
        if missing:
            stale.append(f"docs/CLI_SURFACES.md (missing contract commands: {', '.join(sorted(missing))})")
            if not check:
                print(f"warning: docs/CLI_SURFACES.md missing {sorted(missing)} — update manually or regenerate")

    openapi = gen_openapi(contract)
    add_native_paths(openapi["paths"])
    artifacts = {
        OUT / "openapi.json": json.dumps(openapi, indent=2) + "\n",
        OUT / "cli-help.md": gen_help_md(contract),
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
    # Legacy dist/surface handling: canonical is docs/surface per ADR-030.
    # dist/surface/* is deprecated; canonical is docs/surface. Any file under
    # dist/surface that is not a symlink to canonical must be removed.
    legacy_files = [
        (ROOT / "dist" / "surface" / "cli-help.md", OUT / "cli-help.md"),
        (ROOT / "dist" / "surface" / "openapi.json", OUT / "openapi.json"),
    ]
    # web_nav.json is retired per ADR-030 and must not exist
    retired = ROOT / "dist" / "surface" / "web_nav.json"
    if retired.exists() or retired.is_symlink():
        stale.append(str(retired.relative_to(ROOT)) + " (retired per ADR-030)")
        if not check:
            retired.unlink(missing_ok=True)
            print(f"removed retired {retired.relative_to(ROOT)}")
    for legacy, canonical in legacy_files:
        if legacy.exists() or legacy.is_symlink():
            if legacy.is_symlink():
                # Symlink should point to canonical
                target = legacy.readlink() if hasattr(legacy, "readlink") else None
                if target is not None and canonical.exists():
                    # Resolve symlink target relative to dist/surface
                    resolved = (legacy.parent / target).resolve() if not target.is_absolute() else target
                    if resolved != canonical.resolve():
                        stale.append(str(legacy.relative_to(ROOT)) + " (symlink target mismatch)")
                        if not check and canonical.exists():
                            legacy.unlink(missing_ok=True)
                            legacy.symlink_to(f"../../docs/surface/{canonical.name}")
                            print(f"fixed symlink {legacy.relative_to(ROOT)} -> ../../docs/surface/{canonical.name}")
            else:
                # Regular file: must be identical to canonical, else stale
                if canonical.exists():
                    legacy_content = legacy.read_text(encoding="utf-8") if legacy.exists() else None
                    canonical_content = canonical.read_text(encoding="utf-8")
                    if legacy_content != canonical_content:
                        stale.append(str(legacy.relative_to(ROOT)) + f" (diverged from docs/surface/{canonical.name})")
                        if not check:
                            # Remove stale duplicate; canonical is docs/surface
                            legacy.unlink(missing_ok=True)
                            print(f"removed stale {legacy.relative_to(ROOT)} (canonical is docs/surface/{canonical.name})")
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
