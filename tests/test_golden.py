"""Golden/snapshot tests for deterministic compiler output.

Compiles a small representative fixture set into every implemented target
and verifies the output is deterministic (same input → same output every run).
"""
from __future__ import annotations

import hashlib
import tempfile
from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.model import CanonicalGraph, Skill, Agent, Product, Stability
from agent_toolkit.compiler.targets.claude_code import ClaudeCodeAdapter
from agent_toolkit.compiler.targets.cursor import CursorAdapter
from agent_toolkit.compiler.targets.opencode import OpenCodeAdapter

FIXTURES_DIR = Path(__file__).parent / "golden" / "fixtures"
REPO_ROOT = Path(__file__).parent.parent


def build_fixture_graph() -> CanonicalGraph:
    """Build a minimal canonical graph from fixture files."""
    graph = CanonicalGraph()

    skill_md = FIXTURES_DIR / "skill-minimal" / "SKILL.md"
    graph.skills["test/test-skill"] = Skill(
        id="test/test-skill",
        name="test-skill",
        domain="test",
        description="A minimal test skill for golden snapshot testing.",
        stability=Stability.STABLE,
        source_path=skill_md,
    )

    agent_md = FIXTURES_DIR / "agent-read-only" / "AGENT.md"
    graph.agents["test-agent"] = Agent(
        id="test-agent",
        name="test-agent",
        description="A read-only test agent for golden snapshot testing.",
        instructions="You are a read-only analysis agent. Never modify files.",
        source_path=agent_md,
    )

    graph.products["fixture-product"] = Product(
        id="fixture-product",
        name="Fixture Product",
        description="Test product for golden snapshots.",
        included_skills=["test/test-skill"],
        included_agents=["test-agent"],
    )

    return graph


def content_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()[:16]


@pytest.mark.parametrize("adapter_cls", [
    ClaudeCodeAdapter, CursorAdapter, OpenCodeAdapter
])
def test_output_is_deterministic(adapter_cls):
    """Same input must produce identical output on every run."""
    graph = build_fixture_graph()

    digests_run1 = {}
    with tempfile.TemporaryDirectory() as d1:
        adapter = adapter_cls(Path(d1), REPO_ROOT)
        adapter.compile(graph, graph.products["fixture-product"])
        for f in sorted(Path(d1).rglob("*")):
            if f.is_file():
                rel = str(f.relative_to(d1))
                digests_run1[rel] = content_digest(f)

    digests_run2 = {}
    with tempfile.TemporaryDirectory() as d2:
        adapter = adapter_cls(Path(d2), REPO_ROOT)
        adapter.compile(graph, graph.products["fixture-product"])
        for f in sorted(Path(d2).rglob("*")):
            if f.is_file():
                rel = str(f.relative_to(d2))
                digests_run2[rel] = content_digest(f)

    assert digests_run1 == digests_run2, (
        f"{adapter_cls.__name__}: non-deterministic output detected\n"
        f"Run 1: {sorted(digests_run1)}\n"
        f"Run 2: {sorted(digests_run2)}"
    )


@pytest.mark.parametrize("adapter_cls", [
    ClaudeCodeAdapter, CursorAdapter, OpenCodeAdapter
])
def test_no_machine_paths_in_output(adapter_cls):
    """Generated files must not contain absolute machine paths."""
    graph = build_fixture_graph()

    with tempfile.TemporaryDirectory() as d:
        adapter = adapter_cls(Path(d), REPO_ROOT)
        adapter.compile(graph, graph.products["fixture-product"])
        for f in sorted(Path(d).rglob("*")):
            if f.is_file() and f.suffix in (".md", ".json", ".yaml", ".toml"):
                text = f.read_text(errors="replace")
                assert "/home/" not in text, f"Machine /home/ path in {f}"
                assert str(Path.home()) not in text
