"""Install/uninstall integration tests using a temporary HOME."""
from __future__ import annotations

import json
from pathlib import Path

import pytest

from agent_toolkit.cli.install import cmd_install
from agent_toolkit.cli.uninstall import cmd_uninstall
from agent_toolkit.installer.receipt import InstallReceipt
from agent_toolkit.installer.tracking import PRODUCT, receipt_dir


@pytest.fixture
def isolated_home(tmp_path, monkeypatch):
    monkeypatch.setenv("HOME", str(tmp_path))
    (tmp_path / ".cursor" / "rules").mkdir(parents=True)
    return tmp_path


def test_install_writes_receipt(isolated_home):
    rc = cmd_install(["--tools", "cursor", "--force"])
    assert rc == 0

    rdir = receipt_dir()
    receipt_path = rdir / f"cursor-{PRODUCT}.json"
    assert receipt_path.is_file()

    data = json.loads(receipt_path.read_text())
    assert data["product"] == PRODUCT
    assert data["target"] == "cursor"
    assert len(data["artifacts"]) >= 1


def test_uninstall_removes_receipt_artifacts(isolated_home):
    cmd_install(["--tools", "cursor", "--force"])
    rdir = receipt_dir()
    receipt = InstallReceipt.load("cursor", PRODUCT, rdir)
    assert receipt is not None
    artifact_paths = [Path(a.path) for a in receipt.artifacts]
    assert all(p.is_file() for p in artifact_paths)

    rc = cmd_uninstall(["--tools", "cursor"])
    assert rc == 0
    assert not (rdir / f"cursor-{PRODUCT}.json").exists()
    for path in artifact_paths:
        assert not path.exists()


def test_uninstall_dry_run_keeps_files(isolated_home):
    cmd_install(["--tools", "cursor", "--force"])
    rdir = receipt_dir()
    receipt = InstallReceipt.load("cursor", PRODUCT, rdir)
    assert receipt is not None
    paths = [Path(a.path) for a in receipt.artifacts]

    rc = cmd_uninstall(["--tools", "cursor", "--dry-run"])
    assert rc == 0
    assert (rdir / f"cursor-{PRODUCT}.json").is_file()
    assert all(p.is_file() for p in paths)
