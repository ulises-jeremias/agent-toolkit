"""Tests for agent-toolkit update command."""

from __future__ import annotations

from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent


@pytest.fixture
def fake_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(REPO_ROOT))
    monkeypatch.setenv("AGENT_TOOLKIT_OFFLINE", "1")
    from agent_toolkit._paths import reset_toolkit_root

    reset_toolkit_root()
    return tmp_path


def test_update_check_detects_changes(fake_home: Path) -> None:
    cursor_rules = fake_home / ".cursor" / "rules"
    cursor_rules.mkdir(parents=True)
    installed = cursor_rules / "assistant.mdc"
    installed.write_text("stale content")

    from agent_toolkit.cli.update import cmd_update

    rc = cmd_update(["--tools", "cursor", "--check"])
    assert rc == 1  # changes pending


def test_update_applies_changes(fake_home: Path) -> None:
    cursor_rules = fake_home / ".cursor" / "rules"
    cursor_rules.mkdir(parents=True)
    installed = cursor_rules / "assistant.mdc"
    installed.write_text("stale content")

    from agent_toolkit.cli.update import cmd_update

    rc = cmd_update(["--tools", "cursor"])
    assert rc == 0
    src = REPO_ROOT / "profiles" / "cursor" / "rules" / "assistant.mdc"
    if src.is_file():
        assert installed.read_bytes() == src.read_bytes()


def test_update_up_to_date(fake_home: Path) -> None:
    src_dir = REPO_ROOT / "profiles" / "cursor" / "rules"
    if not src_dir.is_dir():
        pytest.skip("cursor profile not present")

    cursor_rules = fake_home / ".cursor" / "rules"
    cursor_rules.mkdir(parents=True)
    for src_file in src_dir.rglob("*"):
        if src_file.is_file():
            rel = src_file.relative_to(src_dir)
            dst = cursor_rules / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            dst.write_bytes(src_file.read_bytes())

    from agent_toolkit.cli.update import cmd_update

    rc = cmd_update(["--tools", "cursor", "--check"])
    assert rc == 0
