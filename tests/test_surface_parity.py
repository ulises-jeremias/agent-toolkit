"""Capability-surface gates (ADR-030).

Parity semantics after ADR-030: the canonical capability contract must be
covered by the programmatic API surface. Presentation parity (TUI/Web) is NOT
required — external clients own their presentation.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs" / "compatibility" / "cli-contract.yaml"
OPENAPI = ROOT / "docs" / "surface" / "openapi.json"
SERVER = ROOT / "modules" / "agent_toolkit_server" / "server.veb.v"

RETIRED_ARTIFACTS = [
    ROOT / "modules" / "agent_toolkit_server" / "tui_registry.v",
    ROOT / "docs" / "surface" / "web_nav.json",
]


def _commands():
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    return [c["name"] for c in data.get("commands", [])]


# Server-native infrastructure endpoints. These are capabilities of the
# programmatic API itself (platform plane), not mirrors of CLI contract
# commands. ADR-030: capability parity applies to contract commands;
# infrastructure endpoints live only on the API surface.
SERVER_NATIVE_PATHS = {
    "/api/v1/health",
    "/api/v1/openapi.json",
    "/api/v1/selfcheck",
    "/api/v1/jobs",
    "/api/v1/jobs/:id/log",
    "/api/v1/doctor/fix",
    "/api/v1/loops",
    "/api/v1/loops/:name/status",
    "/api/v1/loops/:name/run",
    "/api/v1/loops/:name/schedule",
    "/api/v1/swarms",
}


def _commands():
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    return [c["name"] for c in data.get("commands", [])]


def test_every_command_has_openapi_operation():
    """Every contract command with a programmatic surface (`api` not false)
    must have a corresponding OpenAPI operation."""
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    api_commands = [c["name"] for c in data.get("commands", []) if c.get("api", True)]
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    ops = {op["operationId"] for p in spec["paths"].values() for op in p.values()}
    missing = set(api_commands) - ops
    assert not missing, f"missing routes for: {sorted(missing)}"


def test_openapi_has_scopes_and_confirm_flags():
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    for p in spec["paths"].values():
        for op in p.values():
            assert "x-scope" in op, op["operationId"]
            assert isinstance(op.get("x-confirm-required"), bool)


def test_retired_presentation_artifacts_absent():
    """ADR-030 retired TUI/Web generated registries — they must not reappear."""
    for artifact in RETIRED_ARTIFACTS:
        assert not artifact.exists(), (
            f"{artifact.name} was retired by ADR-030 and must not be regenerated"
        )


def test_server_routes_cover_openapi_paths():
    """Every API path declared by the contract/OpenAPI must have a registered
    veb route in server.veb.v, and vice versa (landing '/' and server-native
    infrastructure endpoints excluded)."""
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    openapi_paths = {p.replace("{", ":").replace("}", "") for p in spec["paths"]}

    text = SERVER.read_text(encoding="utf-8")
    registered = set(re.findall(r"@\['([^']+)';", text))

    # The landing page route is presentation, not a contract capability.
    registered.discard("/")

    missing_in_server = openapi_paths - registered
    assert not missing_in_server, (
        f"contract paths without server route: {sorted(missing_in_server)}"
    )

    undeclared = registered - openapi_paths - SERVER_NATIVE_PATHS
    assert not undeclared, (
        f"server routes not covered by contract or SERVER_NATIVE_PATHS: {sorted(undeclared)}"
    )
