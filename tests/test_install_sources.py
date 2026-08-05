"""Tests for install source resolution and uneven profile warnings."""
from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.installer.sources import (
    resolve_agents_source,
    resolve_pi_skills_source,
    uneven_profile_warnings,
)


def test_resolve_agents_prefers_plugins(tmp_path: Path) -> None:
    plugin_agents = tmp_path / "plugins" / "agent-toolkit-agents" / "agents" / "planner"
    plugin_agents.mkdir(parents=True)
    (plugin_agents / "AGENT.md").write_text("# Planner\n", encoding="utf-8")
    profile_agents = tmp_path / "profiles" / "claude-code" / "agents"
    profile_agents.mkdir(parents=True)
    (profile_agents / "planner.md").write_text("# old\n", encoding="utf-8")
    source = resolve_agents_source(tmp_path, "claude-code")
    assert source.kind == "plugins"


def test_resolve_agents_falls_back_to_profiles(tmp_path: Path) -> None:
    profile_agents = tmp_path / "profiles" / "claude-code" / "agents"
    profile_agents.mkdir(parents=True)
    (profile_agents / "planner.md").write_text("# planner\n", encoding="utf-8")
    source = resolve_agents_source(tmp_path, "claude-code")
    assert source.kind == "profiles"


def test_resolve_pi_skills_prefers_plugins(tmp_path: Path) -> None:
    skills = tmp_path / "plugins" / "agent-toolkit-core" / "skills" / "assistant"
    skills.mkdir(parents=True)
    (skills / "SKILL.md").write_text("# Assistant\n", encoding="utf-8")
    source = resolve_pi_skills_source(tmp_path)
    assert source.kind == "plugins"


def test_uneven_profile_warning_for_windsurf(tmp_path: Path) -> None:
    rules = tmp_path / "profiles" / "windsurf" / "rules"
    rules.mkdir(parents=True)
    for idx in range(10):
        (rules / f"rule-{idx}.mdc").write_text("x", encoding="utf-8")
    warnings = uneven_profile_warnings(tmp_path, "windsurf")
    assert warnings
    assert any("windsurf rules" in w for w in warnings)


def test_install_claude_uses_plugin_agents(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from agent_toolkit.cli import install as install_mod

    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: home))
    root = tmp_path / "toolkit"
    profile = root / "profiles" / "claude-code"
    profile.mkdir(parents=True)
    (profile / "CLAUDE.md").write_text("# Claude\n", encoding="utf-8")
    plugin_agent = root / "plugins" / "agent-toolkit-agents" / "agents" / "planner"
    plugin_agent.mkdir(parents=True)
    (plugin_agent / "AGENT.md").write_text("# Planner from plugins\n", encoding="utf-8")
    monkeypatch.setattr(install_mod, "toolkit_root", lambda: root)
    ok = install_mod._install_claude_code(dry_run=False, force=True)
    assert ok is True
    assert "plugins" in (home / ".claude" / "agents" / "planner.md").read_text(encoding="utf-8")
