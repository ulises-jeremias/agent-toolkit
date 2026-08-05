"""Tests for Claude → abstract tool mapping."""
from __future__ import annotations

import pytest

from agent_toolkit.compiler.model import AbstractTool
from agent_toolkit.compiler.tool_mapping import map_claude_tools, parse_claude_tool_names


def test_map_claude_tools_deduplicates_abstract() -> None:
    mapped, unknown = map_claude_tools(["Read", "Grep", "Glob"])
    assert unknown == []
    assert mapped == [AbstractTool.FS_READ, AbstractTool.FS_SEARCH]


def test_map_claude_tools_reports_unknown() -> None:
    mapped, unknown = map_claude_tools(["Read", "NotARealTool"])
    assert mapped == [AbstractTool.FS_READ]
    assert unknown == ["NotARealTool"]
