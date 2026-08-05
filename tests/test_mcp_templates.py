"""Validate MCP templates align with registry packages (no invented binaries)."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.mcp_registry import load_registry

REPO_ROOT = Path(__file__).parent.parent
REGISTRY_DIR = REPO_ROOT / "mcp" / "registry"
TEMPLATES_DIR = REPO_ROOT / "mcp" / "templates"


def _stdio_templates() -> list[tuple[str, dict]]:
    out: list[tuple[str, dict]] = []
    for provider_dir in sorted(TEMPLATES_DIR.iterdir()):
        if not provider_dir.is_dir():
            continue
        template_file = provider_dir / "config.template.json"
        if not template_file.is_file():
            continue
        data = json.loads(template_file.read_text())
        if data.get("transport") in ("streamable_http", "http"):
            continue
        out.append((provider_dir.name, data))
    return out


def test_stdio_templates_use_supported_launcher_with_registry_package():
    providers, _ = load_registry(REGISTRY_DIR)
    for name, template in _stdio_templates():
        provider = providers.get(name)
        assert provider is not None, f"Missing registry entry for template {name}"
        cmd = template.get("command")
        assert cmd in ("npx", "docker", "uvx"), f"{name}: unexpected command {cmd}"
        args = template.get("args", [])
        if cmd == "npx":
            assert args[:2] == ["-y", provider.package], (
                f"{name}: args must be ['-y', {provider.package!r}], got {args!r}"
            )
        else:
            # docker/uvx: package id should appear in args somewhere
            assert any(provider.package in str(a) for a in args), (
                f"{name}: registry package {provider.package!r} not found in args {args!r}"
            )


def test_registry_providers_have_required_fields():
    providers, errors = load_registry(REGISTRY_DIR)
    assert not errors, errors
    for pid, provider in providers.items():
        assert provider.display_name
        assert provider.package
        assert provider.env_vars is not None
