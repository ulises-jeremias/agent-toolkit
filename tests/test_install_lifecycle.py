"""Install lifecycle tests in isolated HOME directories (clean-home)."""
from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.cli.install import cmd_install
from agent_toolkit.cli.uninstall import cmd_uninstall
from agent_toolkit.installer.receipt import InstallReceipt
from agent_toolkit.installer.tracking import PRODUCT, receipt_dir


@pytest.fixture()
def clean_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Simulate a clean user home with no prior toolkit install."""
    home = tmp_path / "home"
    home.mkdir()
    monkeypatch.setattr(Path, "home", classmethod(lambda cls: home))
    return home


@pytest.fixture()
def receipt_store(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    rd = tmp_path / "receipts"
    rd.mkdir()
    monkeypatch.setattr("agent_toolkit.installer.tracking.receipt_dir", lambda: rd)
    return rd


@pytest.fixture()
def toolkit_with_cursor(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    root = tmp_path / "toolkit"
    rules = root / "profiles" / "cursor" / "rules"
    rules.mkdir(parents=True)
    (rules / "assistant.mdc").write_text("version-1\n", encoding="utf-8")
    (rules / "architect.mdc").write_text("architect-v1\n", encoding="utf-8")
    monkeypatch.setattr("agent_toolkit.cli.install.toolkit_root", lambda: root)
    return root


def test_clean_home_install_writes_receipt_and_files(
    clean_home: Path,
    receipt_store: Path,
    toolkit_with_cursor: Path,
) -> None:
    rc = cmd_install(["--tools", "cursor", "--force"])
    assert rc == 0

    dst = clean_home / ".cursor" / "rules" / "assistant.mdc"
    assert dst.is_file()
    assert dst.read_text(encoding="utf-8") == "version-1\n"

    receipt = InstallReceipt.load("cursor", PRODUCT, receipt_store)
    assert receipt is not None
    assert len(receipt.artifacts) == 2


def test_update_replaces_files_when_forced(
    clean_home: Path,
    receipt_store: Path,
    toolkit_with_cursor: Path,
) -> None:
    cmd_install(["--tools", "cursor", "--force"])

    # Simulate toolkit update with changed content
    rules = toolkit_with_cursor / "profiles" / "cursor" / "rules"
    (rules / "assistant.mdc").write_text("version-2\n", encoding="utf-8")

    rc = cmd_install(["--tools", "cursor", "--force"])
    assert rc == 0
    assert (clean_home / ".cursor" / "rules" / "assistant.mdc").read_text(
        encoding="utf-8"
    ) == "version-2\n"


def test_uninstall_removes_installed_artifacts(
    clean_home: Path,
    receipt_store: Path,
    toolkit_with_cursor: Path,
) -> None:
    cmd_install(["--tools", "cursor", "--force"])
    rules_dir = clean_home / ".cursor" / "rules"
    assert (rules_dir / "assistant.mdc").is_file()

    rc = cmd_uninstall(["--tools", "cursor"])
    assert rc == 0
    assert not (rules_dir / "assistant.mdc").exists()
    assert not (rules_dir / "architect.mdc").exists()
    assert InstallReceipt.load("cursor", PRODUCT, receipt_store) is None


def test_rollback_alias_uninstalls_owned_files(
    clean_home: Path,
    receipt_store: Path,
    toolkit_with_cursor: Path,
) -> None:
    cmd_install(["--tools", "cursor", "--force"])
    installed = clean_home / ".cursor" / "rules" / "assistant.mdc"
    assert installed.is_file()

    rc = cmd_uninstall(["--tools", "cursor", "--rollback"])
    assert rc == 0
    assert not installed.exists()


def test_uninstall_dry_run_preserves_clean_home_state(
    clean_home: Path,
    receipt_store: Path,
    toolkit_with_cursor: Path,
) -> None:
    cmd_install(["--tools", "cursor", "--force"])
    installed = clean_home / ".cursor" / "rules" / "assistant.mdc"

    rc = cmd_uninstall(["--tools", "cursor", "--dry-run"])
    assert rc == 0
    assert installed.is_file()
    assert InstallReceipt.load("cursor", PRODUCT, receipt_store) is not None


def test_install_dry_run_does_not_write_to_clean_home(
    clean_home: Path,
    receipt_store: Path,
    toolkit_with_cursor: Path,
) -> None:
    rc = cmd_install(["--tools", "cursor", "--dry-run"])
    assert rc == 0
    assert not (clean_home / ".cursor").exists()
    assert not list(receipt_store.glob("*.json"))
