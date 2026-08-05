"""Tests for agent abstract tool requirements and delegation contracts."""
from __future__ import annotations

from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_agents, load_graph, validate_agent_contracts
from agent_toolkit.compiler.model import AbstractTool, Agent, CanonicalGraph


def test_load_agents_explicit_allowed_tools(tmp_path: Path) -> None:
    agent_dir = tmp_path / "planner"
    agent_dir.mkdir()
    (agent_dir / "AGENT.md").write_text(
        "---\n"
        "name: planner\n"
        "description: Plans work.\n"
        "allowed_tools:\n"
        "  - fs.read\n"
        "  - fs.search\n"
        "read_only: true\n"
        "delegates_to:\n"
        "  - code-reviewer\n"
        "---\n"
        "# Planner\n",
        encoding="utf-8",
    )

    agents, errors = load_agents(tmp_path)
    assert errors == []
    agent = agents["planner"]
    assert agent.allowed_tools == [AbstractTool.FS_READ, AbstractTool.FS_SEARCH]
    assert agent.read_only is True
    assert agent.delegates_to == ["code-reviewer"]


def test_validate_delegates_to_unknown_agent() -> None:
    graph = CanonicalGraph()
    graph.agents["assistant"] = Agent(
        id="assistant",
        name="assistant",
        description="Routes work.",
        instructions="",
        delegates_to=["missing-agent"],
    )

    validate_agent_contracts(graph)
    assert any("delegates_to unknown agent" in e for e in graph.errors)


def test_validate_delegates_to_self_is_error() -> None:
    graph = CanonicalGraph()
    graph.agents["assistant"] = Agent(
        id="assistant",
        name="assistant",
        description="Routes work.",
        instructions="",
        delegates_to=["assistant"],
    )

    validate_agent_contracts(graph)
    assert any("cannot delegate_to itself" in e for e in graph.errors)


def test_validate_allowed_denied_overlap() -> None:
    graph = CanonicalGraph()
    graph.agents["reviewer"] = Agent(
        id="reviewer",
        name="reviewer",
        description="Review.",
        instructions="",
        allowed_tools=[AbstractTool.FS_READ],
        denied_tools=[AbstractTool.FS_READ],
    )

    validate_agent_contracts(graph)
    assert any("allowed_tools and denied_tools" in e for e in graph.errors)


def test_repo_agents_load_with_tool_mapping() -> None:
    repo_root = Path(__file__).parent.parent.parent
    graph = load_graph(repo_root)
    assert graph.is_valid, graph.errors
    assert graph.agents["code-reviewer"].allowed_tools
    assert graph.agents["code-reviewer"].read_only is False
