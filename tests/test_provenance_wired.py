"""Provenance sidecar is emitted on compile and build --check (#67)."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.claude_code import ClaudeCodeAdapter

REPO = Path(__file__).resolve().parent.parent


def test_compile_writes_provenance(tmp_path):
    graph = load_graph(REPO)
    product = graph.products["agent-toolkit-core"]
    adapter = ClaudeCodeAdapter(tmp_path / "plugins", REPO)
    adapter._provenance_records = []
    result = adapter.compile(graph, product)
    adapter._finalize_provenance(product, result)
    prov = tmp_path / "plugins" / "agent-toolkit-core" / ".provenance.json"
    assert prov.is_file(), "expected .provenance.json"
    assert "provenance" in result.emitted
    data = json.loads(prov.read_text())
    assert data["product"] == product.id
    assert data["target"] == "claude-code"
    assert len(data["artifacts"]) >= 1


def test_build_check_emits_provenance_in_temp(tmp_path):
    graph = load_graph(REPO)
    product = graph.products["agent-toolkit-core"]
    adapter = ClaudeCodeAdapter(tmp_path / "plugins", REPO)
    result = adapter.check(graph, product)
    assert "provenance" in result.emitted
    assert not (tmp_path / "plugins" / product.id / ".provenance.json").exists()
