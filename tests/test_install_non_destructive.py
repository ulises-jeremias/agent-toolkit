"""Non-destructive install: preserve user-modified profile files."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from agent_toolkit.cli import install as install_mod
from agent_toolkit.installer.merge import merge_json_objects


@pytest.fixture()
def fake_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: home))
    return home


@pytest.fixture()
def toolkit_with_cursor_profile(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    root = tmp_path / "toolkit"
    rules = root / "profiles" / "cursor" / "rules"
    rules.mkdir(parents=True)
    (rules / "assistant.mdc").write_text("toolkit-default\n", encoding="utf-8")
    monkeypatch.setattr(install_mod, "toolkit_root", lambda: root)
    return root


@pytest.fixture()
def toolkit_with_opencode_profile(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    root = tmp_path / "toolkit"
    profile = root / "profiles" / "opencode"
    profile.mkdir(parents=True)
    (profile / "opencode.json").write_text(
        json.dumps({"$schema": "https://opencode.ai/config.schema.json", "toolkit": True}),
        encoding="utf-8",
    )
    agents = profile / "agents"
    agents.mkdir()
    (agents / "assistant.md").write_text("assistant\n", encoding="utf-8")
    monkeypatch.setattr(install_mod, "toolkit_root", lambda: root)
    return root


def test_install_skips_user_modified_profile_file(
    fake_home: Path,
    toolkit_with_cursor_profile: Path,
) -> None:
    dst = fake_home / ".cursor" / "rules" / "assistant.mdc"
    dst.parent.mkdir(parents=True)
    user_content = "user-customized content\n"
    dst.write_text(user_content, encoding="utf-8")

    ok = install_mod._install_cursor(dry_run=False, force=False)

    assert ok is True
    assert dst.read_text(encoding="utf-8") == user_content


def test_install_force_overwrites_user_modified_file(
    fake_home: Path,
    toolkit_with_cursor_profile: Path,
) -> None:
    dst = fake_home / ".cursor" / "rules" / "assistant.mdc"
    dst.parent.mkdir(parents=True)
    dst.write_text("user-customized content\n", encoding="utf-8")

    ok = install_mod._install_cursor(dry_run=False, force=True)

    assert ok is True
    assert dst.read_text(encoding="utf-8") == "toolkit-default\n"


def test_claude_install_never_writes_settings_json(
    fake_home: Path,
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    root = tmp_path / "toolkit"
    profile = root / "profiles" / "claude-code"
    profile.mkdir(parents=True)
    (profile / "CLAUDE.md").write_text("# Claude\n", encoding="utf-8")
    (profile / "settings.json").write_text(
        json.dumps({"enabledPlugins": {"toolkit@marketplace": True}}),
        encoding="utf-8",
    )
    monkeypatch.setattr(install_mod, "toolkit_root", lambda: root)

    settings = fake_home / ".claude" / "settings.json"
    settings.parent.mkdir(parents=True)
    original = {"enabledPlugins": {"user-plugin@local": True}}
    settings.write_text(json.dumps(original), encoding="utf-8")

    ok = install_mod._install_claude_code(dry_run=False, force=True)

    assert ok is True
    assert json.loads(settings.read_text(encoding="utf-8")) == original


def test_merge_json_preserves_user_keys() -> None:
    base = {"userKey": "keep", "shared": {"a": 1}}
    overlay = {"toolkitKey": "add", "shared": {"b": 2}}
    merged, patches = merge_json_objects(base, overlay)

    assert merged["userKey"] == "keep"
    assert merged["toolkitKey"] == "add"
    assert merged["shared"] == {"a": 1, "b": 2}
    assert any(p["path"] == "/toolkitKey" for p in patches)


def test_opencode_install_merges_config_without_overwriting_user_keys(
    fake_home: Path,
    toolkit_with_opencode_profile: Path,
) -> None:
    dst = fake_home / ".config" / "opencode" / "opencode.json"
    dst.parent.mkdir(parents=True)
    user_config = {
        "$schema": "https://opencode.ai/config.schema.json",
        "customProvider": {"baseURL": "http://localhost:8080"},
    }
    dst.write_text(json.dumps(user_config, indent=2), encoding="utf-8")

    ok = install_mod._install_opencode(dry_run=False, force=False)

    assert ok is True
    result = json.loads(dst.read_text(encoding="utf-8"))
    assert result["customProvider"] == user_config["customProvider"]
    assert result["toolkit"] is True
