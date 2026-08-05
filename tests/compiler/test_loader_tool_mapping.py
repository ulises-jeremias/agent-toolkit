"""Tests that loader maps Claude tools to abstract tools on agents."""
from __future__ import annotations

from pathlib import Path

import pytest

pytest.importorskip("yaml")

from agent_toolkit.compiler.loader import load_agents
from agent_toolkit.compiler.model import AbstractTool


def test_load_agents_maps_claude_tools(tmp_path: Path) -> None:
    agent_dir = tmp_path / "code-reviewer"
    agent_dir.mkdir()
    (agent_dir / "AGENT.md").write_text(
        "---\nname: code-reviewer\ndescription: Review.\ntools: Read, Grep, Glob, Bash\n---\n# R\n",
        encoding="utf-8",
    )
    agents, errors = load_agents(tmp_path)
    assert errors == []
    assert agents["code-reviewer"].allowed_tools == [
        AbstractTool.FS_READ, AbstractTool.FS_SEARCH, AbstractTool.SHELL_EXECUTE,
    ]
