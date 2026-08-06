"""Tests for Claude → abstract tool mapping (#70)."""

from __future__ import annotations

from pathlib import Path

from agent_toolkit.compiler.loader import load_agents
from agent_toolkit.compiler.model import AbstractTool
from agent_toolkit.compiler.tool_mapping import map_claude_tools, parse_claude_tool_names


def test_parse_and_map_standard_reviewer_tools():
    names = parse_claude_tool_names("Read, Grep, Glob, Bash")
    mapped, unknown = map_claude_tools(names)
    assert unknown == []
    assert AbstractTool.FS_READ in mapped
    assert AbstractTool.FS_SEARCH in mapped
    assert AbstractTool.SHELL_EXECUTE in mapped


def test_unknown_tool_reported():
    mapped, unknown = map_claude_tools(["Read", "NotARealTool"])
    assert AbstractTool.FS_READ in mapped
    assert unknown == ["NotARealTool"]


def test_load_agents_populates_allowed_tools(tmp_path: Path):
    agent_dir = tmp_path / "docs-lookup"
    agent_dir.mkdir()
    (agent_dir / "AGENT.md").write_text(
        "---\nname: docs-lookup\ndescription: Docs\ntools: Read, Grep, Glob\n---\n\nBody.\n",
        encoding="utf-8",
    )
    agents, errors = load_agents(tmp_path)
    assert errors == []
    agent = agents["docs-lookup"]
    assert AbstractTool.FS_READ in agent.allowed_tools
    assert agent.read_only is True
