"""Parity gate: every command in cli-contract.yaml must appear in generated surface artifacts."""

from __future__ import annotations

import json
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = ROOT / "docs" / "compatibility" / "cli-contract.yaml"
OPENAPI = ROOT / "docs" / "surface" / "openapi.json"
TUI = ROOT / "modules" / "agent_toolkit_server" / "tui_registry.v"


def _commands():
    data = yaml.safe_load(CONTRACT.read_text(encoding="utf-8"))
    return [c["name"] for c in data.get("commands", [])]


def test_every_command_has_openapi_operation():
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    ops = {op["operationId"] for p in spec["paths"].values() for op in p.values()}
    missing = set(_commands()) - ops
    assert not missing, f"missing routes for: {sorted(missing)}"


def test_openapi_has_scopes_and_confirm_flags():
    spec = json.loads(OPENAPI.read_text(encoding="utf-8"))
    for p in spec["paths"].values():
        for op in p.values():
            assert "x-scope" in op, op["operationId"]
            assert isinstance(op.get("x-confirm-required"), bool)


def test_tui_registry_lists_all_commands():
    text = TUI.read_text(encoding="utf-8")
    import re

    names = set(re.findall(r"name:\s*'([^']+)'", text))
    missing = set(_commands()) - names
    assert not missing, f"TUI registry missing: {sorted(missing)}"
