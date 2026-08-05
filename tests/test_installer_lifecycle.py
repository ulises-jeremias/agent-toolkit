"""Isolated-HOME installer lifecycle: install, update, rollback, uninstall, clean-home."""
from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.cli import install as install_mod
from agent_toolkit.cli.uninstall import cmd_uninstall
from agent_toolkit.installer import tracking
from agent_toolkit.installer.receipt import InstallReceipt

PRODUCT = tracking.PRODUCT


@pytest.fixture()
def fake_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: home))
    return home


@pytest.fixture()
def receipt_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    rd = tmp_path / "receipts"
    rd.mkdir()
    monkeypatch.setattr(tracking, "receipt_dir", lambda: rd)
    return rd


@pytest.fixture()
def toolkit_with_cursor_profile(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    root = tmp_path / "toolkit"
    rules = root / "profiles" / "cursor" / "rules"
    rules.mkdir(parents=True)
    (rules / "assistant.mdc").write_text("cursor rules v1\n", encoding="utf-8")
    monkeypatch.setattr(install_mod, "toolkit_root", lambda: root)
    return root


def test_install_writes_receipt(
    fake_home: Path,
    receipt_dir: Path,
    toolkit_with_cursor_profile: Path,
) -> None:
    ok = install_mod._install_cursor(dry_run=False, force=True)
    assert ok is True

    receipt = InstallReceipt.load("cursor", PRODUCT, receipt_dir)
    assert receipt is not None
    assert len(receipt.artifacts) == 1
    assert receipt.artifacts[0].ownership == "created"
    assert (fake_home / ".cursor" / "rules" / "assistant.mdc").is_file()


def test_update_overwrites_and_refreshes_receipt(
    fake_home: Path,
    receipt_dir: Path,
    toolkit_with_cursor_profile: Path,
) -> None:
    install_mod._install_cursor(dry_run=False, force=True)

    rules = toolkit_with_cursor_profile / "profiles" / "cursor" / "rules" / "assistant.mdc"
    rules.write_text("cursor rules v2\n", encoding="utf-8")

    ok = install_mod._install_cursor(dry_run=False, force=True)
    assert ok is True
    assert (fake_home / ".cursor" / "rules" / "assistant.mdc").read_text(
        encoding="utf-8"
    ) == "cursor rules v2\n"

    receipt = InstallReceipt.load("cursor", PRODUCT, receipt_dir)
    assert receipt is not None
    assert len(receipt.artifacts) == 1


def test_uninstall_removes_receipt_owned_files(
    fake_home: Path,
    receipt_dir: Path,
    toolkit_with_cursor_profile: Path,
) -> None:
    install_mod._install_cursor(dry_run=False, force=True)
    installed = fake_home / ".cursor" / "rules" / "assistant.mdc"
    assert installed.is_file()

    rc = cmd_uninstall(["--tools", "cursor"])
    assert rc == 0
    assert not installed.exists()
    assert InstallReceipt.load("cursor", PRODUCT, receipt_dir) is None


def test_rollback_alias_removes_installed_files(
    fake_home: Path,
    receipt_dir: Path,
    toolkit_with_cursor_profile: Path,
) -> None:
    install_mod._install_cursor(dry_run=False, force=True)
    installed = fake_home / ".cursor" / "rules" / "assistant.mdc"

    rc = cmd_uninstall(["--tools", "cursor", "--rollback"])
    assert rc == 0
    assert not installed.exists()


def test_uninstall_dry_run_keeps_files(
    fake_home: Path,
    receipt_dir: Path,
    toolkit_with_cursor_profile: Path,
) -> None:
    install_mod._install_cursor(dry_run=False, force=True)
    installed = fake_home / ".cursor" / "rules" / "assistant.mdc"

    rc = cmd_uninstall(["--tools", "cursor", "--dry-run"])
    assert rc == 0
    assert installed.is_file()
    assert InstallReceipt.load("cursor", PRODUCT, receipt_dir) is not None


def test_clean_home_removes_empty_config_dirs(
    fake_home: Path,
    receipt_dir: Path,
    toolkit_with_cursor_profile: Path,
) -> None:
    install_mod._install_cursor(dry_run=False, force=True)
    config_root = fake_home / ".config" / "agent-toolkit"

    rc = cmd_uninstall(["--tools", "cursor", "--clean-home"])
    assert rc == 0
    assert not receipt_dir.exists()
    assert not config_root.exists()
    assert not (fake_home / ".cursor" / "rules" / "assistant.mdc").exists()


def test_install_dry_run_writes_no_receipt(
    fake_home: Path,
    receipt_dir: Path,
    toolkit_with_cursor_profile: Path,
) -> None:
    ok = install_mod._install_cursor(dry_run=True, force=True)
    assert ok is True
    assert InstallReceipt.load("cursor", PRODUCT, receipt_dir) is None
    assert not (fake_home / ".cursor" / "rules" / "assistant.mdc").exists()
