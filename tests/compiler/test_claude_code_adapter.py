"""Contract tests for the Claude Code adapter."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.claude_code import ClaudeCodeAdapter

REPO_ROOT = Path(__file__).parent.parent.parent


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.fixture
def adapter(tmp_path):
    return ClaudeCodeAdapter(tmp_path / "plugins", REPO_ROOT)


def test_manifest_created(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)
    manifest = adapter.output_root / "agent-toolkit-core" / ".claude-plugin" / "plugin.json"
    assert manifest.exists()
    assert "plugin-manifest" in result.emitted


def test_manifest_valid_json(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)
    manifest = adapter.output_root / "agent-toolkit-core" / ".claude-plugin" / "plugin.json"
    data = json.loads(manifest.read_text())
    for field in ("name", "version", "description", "author"):
        assert field in data, f"manifest missing '{field}'"


def test_no_dangerous_mode_bypass(adapter, graph):
    for product in graph.products.values():
        adapter.compile(graph, product)
        manifest_path = adapter.output_root / product.id / ".claude-plugin" / "plugin.json"
        if manifest_path.exists():
            data = json.loads(manifest_path.read_text())
            assert "skipDangerousModePermissionPrompt" not in data


def test_unsupported_reported(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)
    unsupported = " ".join(result.unsupported).lower()
    assert "hook" in unsupported
    assert "mcp" in unsupported


def test_check_mode_no_files(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.check(graph, product)
    assert result.artifacts == []
    assert result.is_valid


@pytest.mark.parametrize("product_id", ["agent-toolkit-core", "agent-toolkit-agents", "agent-toolkit-forge"])
def test_all_products(adapter, graph, product_id):
    if product_id not in graph.products:
        pytest.skip(f"Product {product_id} not defined")
    result = adapter.compile(graph, graph.products[product_id])
    assert result.errors == []


def test_plugin_manifest_uses_claude_plugin_dir(adapter, graph):
    """Official contract: manifest lives under .claude-plugin/, not plugin root."""
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)
    manifest = adapter.output_root / "agent-toolkit-core" / ".claude-plugin" / "plugin.json"
    wrong = adapter.output_root / "agent-toolkit-core" / "plugin.json"
    assert manifest.is_file()
    assert not wrong.exists()


def test_validate_settings_rejects_dangerous_bypass():
    errors = ClaudeCodeAdapter.validate_settings({"skipDangerousModePermissionPrompt": True})
    assert errors


def test_parity_notes_document_plugin_local_settings():
    notes = ClaudeCodeAdapter.parity_notes()
    assert "settings.json" in notes.lower() or "plugin-local" in notes.lower()
    assert "hook" in notes.lower()
    assert "mcp" in notes.lower()
