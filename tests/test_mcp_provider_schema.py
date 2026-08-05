"""Validate MCP registry YAML against mcp-provider.schema.json."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "schemas" / "mcp-provider.schema.json"
REGISTRY_DIR = ROOT / "mcp" / "registry"


def _load_schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text())


def _validate_required_fields(data: dict, schema: dict) -> list[str]:
    errors: list[str] = []
    for field in schema.get("required", []):
        if field not in data:
            errors.append(f"missing required field: {field}")
    id_schema = schema.get("properties", {}).get("id", {})
    pattern = id_schema.get("pattern")
    if pattern and "id" in data:
        import re

        if not re.fullmatch(pattern, data["id"]):
            errors.append(f"id {data['id']!r} does not match pattern {pattern!r}")
    return errors


@pytest.mark.parametrize("yaml_file", sorted(REGISTRY_DIR.glob("*.yaml")))
def test_mcp_registry_entry_has_valid_id(yaml_file: Path):
    pytest.importorskip("yaml")
    import yaml

    schema = _load_schema()
    data = yaml.safe_load(yaml_file.read_text()) or {}
    errors = _validate_required_fields(data, schema)
    assert not errors, f"{yaml_file.name}: " + "; ".join(errors)
