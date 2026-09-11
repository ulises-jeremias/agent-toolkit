"""Tests for scripts/prepare-package-data.vsh — pip wheel must ship hook registry."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "scripts" / "prepare-package-data.vsh"
DATA_DEST = REPO_ROOT / "packages" / "pypi" / "agent-toolkit-cli" / "src" / "agent_toolkit" / "data"


def test_prepare_package_data_script_lists_capabilities():
    text = SCRIPT.read_text(encoding="utf-8")
    assert "capabilities" in text


def test_prepare_package_data_copies_capabilities(tmp_path, monkeypatch):
    """Running the script must copy capabilities/hooks for pip-installed CLI."""
    dest = tmp_path / "data"
    monkeypatch.setenv("DEST_OVERRIDE", str(dest))
    vbin = shutil.which("v")
    if not vbin:
        pytest.skip("v toolchain not on PATH")
    # `v run` (not shebang): portable across ubuntu/macos/windows CI runners.
    subprocess.run([vbin, "run", str(SCRIPT)], check=True, cwd=REPO_ROOT)
    assert (DATA_DEST / "capabilities" / "hooks").is_dir()
    assert list((DATA_DEST / "capabilities" / "hooks").glob("*.yaml"))
