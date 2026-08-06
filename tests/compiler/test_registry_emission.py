"""Tests for registry-based hooks/MCP emission."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.registry_emit import (
    emit_claude_hooks_json,
    emit_claude_mcp_json,
    resolve_hook_ids,
    resolve_mcp_ids,
    rewrite_hook_command_for_bundle,
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
    assert "session-start-context" in payload["hooks"]["SessionStart"][0]["command"]


def test_emit_claude_hooks_json_bundle_relative():
    payload = emit_claude_hooks_json(
        ["session-start-context"],
        HOOKS_DIR,
        bundle_relative=True,
    )
    assert payload is not None
    command = payload["hooks"]["SessionStart"][0]["command"]
    assert command.startswith("bash hooks/scripts/")
    assert "capabilities/" not in command


def test_rewrite_hook_command_for_bundle():
    canonical = ["bash", "capabilities/hooks/scripts/session-start-context.sh"]
    rewritten = rewrite_hook_command_for_bundle(canonical)
    assert rewritten == ["bash", "hooks/scripts/session-start-context.sh"]


def test_emit_claude_mcp_json():
    payload = emit_claude_mcp_json(["github"], MCP_DIR)
    assert payload is not None
    assert "github" in payload["mcpServers"]
    env = payload["mcpServers"]["github"].get("env", {})
    assert "GITHUB_PERSONAL_ACCESS_TOKEN" in env or "GITHUB_TOKEN" in env


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

    command = hooks["hooks"]["SessionStart"][0]["command"]
    assert command.startswith("bash hooks/scripts/")
    assert "capabilities/" not in command
    script = out / "hooks" / "scripts" / "session-start-context.sh"
    assert script.is_file()
    assert script.stat().st_mode & 0o111


def test_agents_product_without_hooks_mcp(adapter, graph):
    product = graph.products["agent-toolkit-agents"]
    result = adapter.compile(graph, product)
    out = adapter.output_root / "agent-toolkit-agents"
    assert not (out / "hooks" / "hooks.json").exists()
    assert not (out / ".mcp.json").exists()
    assert any("hooks" in u for u in result.unsupported)


def test_emit_registries_flag(adapter, graph):
    product = graph.products["agent-toolkit-agents"]
    adapter.compile(graph, product, emit_registries=True)
    out = adapter.output_root / "agent-toolkit-agents"
    assert (out / "hooks" / "hooks.json").is_file()
    assert (out / ".mcp.json").is_file()
    mcp_ids = resolve_mcp_ids(
        [], target_id="claude-code", registry_dir=MCP_DIR, emit_registries=True
    )
    assert mcp_ids  # at least github from registry
