"""Tests for registry-based hooks/MCP emission."""
from __future__ import annotations

import json
from pathlib import Path

import pytest


from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.registry_emit import (
    emit_claude_hooks_json,
    emit_claude_mcp_json,
    resolve_hook_ids,
    resolve_mcp_ids,
)
from agent_toolkit.compiler.targets.claude_code import ClaudeCodeAdapter

REPO_ROOT = Path(__file__).parent.parent.parent
HOOKS_DIR = REPO_ROOT / "capabilities" / "hooks"
MCP_DIR = REPO_ROOT / "mcp" / "registry"


@pytest.fixture
def graph():
    return load_graph(REPO_ROOT)


@pytest.fixture
def adapter(tmp_path):
    return ClaudeCodeAdapter(tmp_path / "plugins", REPO_ROOT)


def test_resolve_hooks_from_product():
    ids = resolve_hook_ids(
        ["session-start-context"],
        target_id="claude-code",
        hooks_dir=HOOKS_DIR,
    )
    assert ids == ["session-start-context"]


def test_emit_registries_includes_supported_hooks():
    ids = resolve_hook_ids(
        [],
        target_id="claude-code",
        hooks_dir=HOOKS_DIR,
        emit_registries=True,
    )
    assert "session-start-context" in ids


def test_emit_claude_hooks_json():
    payload = emit_claude_hooks_json(["session-start-context"], HOOKS_DIR)
    assert payload is not None
    assert "SessionStart" in payload["hooks"]
    assert payload["hooks"]["SessionStart"][0]["command"] == "agent-toolkit workspace context"


def test_emit_claude_mcp_json():
    payload = emit_claude_mcp_json(["github"], MCP_DIR)
    assert payload is not None
    assert "github" in payload["mcpServers"]
    assert payload["mcpServers"]["github"]["env"]["GITHUB_TOKEN"] == "${GITHUB_TOKEN}"


def test_adapter_emits_hooks_and_mcp(adapter, graph):
    product = graph.products["agent-toolkit-core"]
    result = adapter.compile(graph, product)
    out = adapter.output_root / "agent-toolkit-core"
    assert (out / "hooks" / "hooks.json").is_file()
    assert (out / ".mcp.json").is_file()
    assert "hooks" in result.emitted
    assert "mcp" in result.emitted

    hooks = json.loads((out / "hooks" / "hooks.json").read_text())
    mcp = json.loads((out / ".mcp.json").read_text())
    assert "SessionStart" in hooks["hooks"]
    assert "github" in mcp["mcpServers"]


def test_agents_product_without_hooks_mcp(adapter, graph):
    product = graph.products["agent-toolkit-agents"]
    result = adapter.compile(graph, product)
    out = adapter.output_root / "agent-toolkit-agents"
    assert not (out / "hooks" / "hooks.json").exists()
    assert not (out / ".mcp.json").exists()
    assert any("hooks" in u for u in result.unsupported)


def test_emit_registries_flag(adapter, graph):
    product = graph.products["agent-toolkit-agents"]
    result = adapter.compile(graph, product, emit_registries=True)
    out = adapter.output_root / "agent-toolkit-agents"
    assert (out / "hooks" / "hooks.json").is_file()
    assert (out / ".mcp.json").is_file()
    mcp_ids = resolve_mcp_ids([], target_id="claude-code", registry_dir=MCP_DIR, emit_registries=True)
    assert mcp_ids  # at least github from registry
