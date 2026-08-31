"""Capability-surface gates (ADR-030).

Parity semantics: the canonical capability contract must be covered by the
programmatic API surface. Presentation parity (TUI/Web) is NOT required —
external clients own their presentation.
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


def test_registered_routes_const_matches_attributes():
    """The `registered_api_routes` const consumed by runtime selfcheck must
    exactly mirror the @['...'] route attributes in server.veb.v."""
    text = SERVER.read_text(encoding="utf-8")
    attrs = set(re.findall(r"@\['([^']+)';", text))
    attrs.discard("/")

    m = re.search(r"const registered_api_routes = \[(.*?)\]", text, re.DOTALL)
    assert m, "registered_api_routes const missing"
    const_items = set(re.findall(r"'([^']+)'", m.group(1)))

    assert attrs == const_items, (
        f"drift — attributes-only: {sorted(attrs - const_items)}, "
        f"const-only: {sorted(const_items - attrs)}"
    )


def test_openapi_paths_match_registered_routes():
    """OpenAPI must describe exactly the registered server API routes (the
    landing '/' is presentation, not an API path)."""
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    openapi_paths = {p.replace("{", ":").replace("}", "") for p in spec["paths"]}
    text = SERVER.read_text(encoding="utf-8")
    registered = set(re.findall(r"@\['([^']+)';", text))
    registered.discard("/")

    missing_in_openapi = registered - openapi_paths
    assert not missing_in_openapi, f"routes without OpenAPI docs: {sorted(missing_in_openapi)}"

    undeclared_in_server = openapi_paths - registered
    assert not undeclared_in_server, f"OpenAPI paths without routes: {sorted(undeclared_in_server)}"


def test_openapi_version_matches_version_file():
    """OpenAPI info.version must match VERSION file (stale artifact detection)."""
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    openapi_version = spec.get("info", {}).get("version", "")
    version_file = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    assert openapi_version == version_file, (
        f"OpenAPI version {openapi_version!r} != VERSION {version_file!r} — run python3 scripts/generate_surface.py"
    )


def test_contract_to_openapi_to_routes_triple_parity():
    """Triple parity: contract (api:true) ↔ openapi operations ↔ registered routes ↔ CLI help."""
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    contract_api = {c["name"] for c in data.get("commands", []) if c.get("api", True)}
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    openapi_ops = {op["operationId"] for p in spec["paths"].values() for op in p.values()}
    # Filter to contract-mirrored ops (exclude server-native like health, selfcheck, jobs, etc.)
    contract_ops = openapi_ops & contract_api
    assert contract_api == contract_ops, (
        f"contract→openapi drift: missing {sorted(contract_api - contract_ops)}"
    )
    text = SERVER.read_text(encoding="utf-8")
    registered = set(re.findall(r"@\['([^']+)';", text))
    registered.discard("/")
    # Also check CLI help generated from contract exists and is fresh (handled by generate_surface --check)
    help_path = ROOT / "docs" / "surface" / "cli-help.md"
    assert help_path.exists(), "docs/surface/cli-help.md missing — run generate_surface.py"
    help_text = help_path.read_text(encoding="utf-8")
    for name in contract_api:
        assert f"`{name}`" in help_text, f"CLI help missing contract command {name!r}"
