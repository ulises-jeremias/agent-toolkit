"""Install source resolution prefers compiler-generated plugins/ artifacts."""
from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.cli import install as install_mod
from agent_toolkit.installer import sources


@pytest.fixture()
def fake_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: home))
    return home


def test_agent_install_sources_prefers_plugins_over_profiles(tmp_path: Path) -> None:
    root = tmp_path / "repo"
    plugins = root / "plugins" / "agent-toolkit-agents" / "agents" / "architect"
    plugins.mkdir(parents=True)
    compiled = "compiled architect content\n"
    (plugins / "AGENT.md").write_text(compiled, encoding="utf-8")

    profile = root / "profiles" / "claude-code" / "agents"
    profile.mkdir(parents=True)
    (profile / "architect.md").write_text("stale profile content\n", encoding="utf-8")

    agents = sources.agent_install_sources("claude-code", data_root=root)
    assert agents["architect"].read_text(encoding="utf-8") == compiled


def test_claude_install_uses_compiled_agents(
    fake_home: Path,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    root = tmp_path / "repo"
    plugins = root / "plugins" / "agent-toolkit-agents" / "agents" / "tech-assistant"
    plugins.mkdir(parents=True)
    marker = "from plugins tech-assistant\n"
    (plugins / "AGENT.md").write_text(marker, encoding="utf-8")

    profile = root / "profiles" / "claude-code"
    profile.mkdir(parents=True)
    (profile / "CLAUDE.md").write_text("# Claude\n", encoding="utf-8")
    agents = profile / "agents"
    agents.mkdir()
    (agents / "tech-assistant.md").write_text("stale profile\n", encoding="utf-8")

    monkeypatch.setattr(install_mod, "toolkit_root", lambda: root)

    ok = install_mod._install_claude_code(dry_run=False, force=True)

    assert ok is True
    installed = fake_home / ".claude" / "agents" / "tech-assistant.md"
    assert installed.is_file()
    assert installed.read_text(encoding="utf-8") == marker


def test_agent_install_sources_falls_back_to_profiles(tmp_path: Path) -> None:
    root = tmp_path / "repo"
    profile = root / "profiles" / "opencode" / "agents"
    profile.mkdir(parents=True)
    (profile / "assistant.md").write_text("profile assistant\n", encoding="utf-8")

    agents = sources.agent_install_sources("opencode", data_root=root)
    assert "assistant" in agents
    assert agents["assistant"].name == "assistant.md"
