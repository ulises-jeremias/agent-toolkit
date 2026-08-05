"""Stale artifacts under product output are removed on recompile (#69)."""
from __future__ import annotations

from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_graph
from agent_toolkit.compiler.targets.claude_code import ClaudeCodeAdapter

REPO = Path(__file__).resolve().parent.parent


def test_stale_file_removed_on_recompile(tmp_path):
    graph = load_graph(REPO)
    product = graph.products["agent-toolkit-core"]
    out = tmp_path / "plugins"
    adapter = ClaudeCodeAdapter(out, REPO)
    adapter.compile(graph, product)
    stale = out / product.id / "STALE_ARTIFACT.txt"
    stale.parent.mkdir(parents=True, exist_ok=True)
    stale.write_text("stale\n")
    assert stale.exists()
    result = adapter.compile(graph, product)
    adapter._cleanup_stale_artifacts(product, result)
    assert not stale.exists(), "stale artifact should be removed"
