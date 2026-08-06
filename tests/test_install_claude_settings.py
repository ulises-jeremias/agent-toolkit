"""Regression: Claude Code install must not overwrite ~/.claude/settings.json."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from agent_toolkit.cli import install as install_mod


@pytest.fixture()
def fake_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: home))
    return home


@pytest.fixture()
def toolkit_with_claude_profile(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    root = tmp_path / "toolkit"
    profile = root / "profiles" / "claude-code"
    profile.mkdir(parents=True)
    (profile / "CLAUDE.md").write_text("# Claude instructions\n", encoding="utf-8")
    (profile / "settings.json").write_text(
        json.dumps({"enabledPlugins": {"should-not-install@marketplace": True}}),
        encoding="utf-8",
    )
    agents = profile / "agents"
    agents.mkdir()
    (agents / "code-reviewer.md").write_text("reviewer\n", encoding="utf-8")
    monkeypatch.setattr(install_mod, "toolkit_root", lambda: root)
    return root


def test_claude_install_preserves_existing_user_settings(
    fake_home: Path,
    toolkit_with_claude_profile: Path,
) -> None:
    settings = fake_home / ".claude" / "settings.json"
    settings.parent.mkdir(parents=True)
    original = {"enabledPlugins": {"user-plugin@local": True}, "custom": "keep-me"}
    settings.write_text(json.dumps(original, indent=2), encoding="utf-8")
    before = settings.read_bytes()

    ok = install_mod._install_claude_code(dry_run=False, force=True)

    assert ok is True
    assert settings.read_bytes() == before
    assert json.loads(settings.read_text(encoding="utf-8")) == original
    assert (fake_home / ".claude" / "CLAUDE.md").is_file()
    assert (fake_home / ".claude" / "agents" / "code-reviewer.md").is_file()


def test_claude_install_does_not_create_settings_when_absent(
    fake_home: Path,
    toolkit_with_claude_profile: Path,
) -> None:
    ok = install_mod._install_claude_code(dry_run=False, force=True)

    assert ok is True
    assert not (fake_home / ".claude" / "settings.json").exists()
    assert (fake_home / ".claude" / "CLAUDE.md").is_file()
