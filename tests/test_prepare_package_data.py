"""Tests for scripts/prepare-package-data.sh — pip wheel must ship hook registry."""
from __future__ import annotations

import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
SCRIPT = REPO_ROOT / "scripts" / "prepare-package-data.sh"
DATA_DEST = (
    REPO_ROOT
    / "packages"
    / "agent-toolkit-cli"
    / "src"
    / "agent_toolkit"
    / "data"
)


def test_prepare_package_data_script_lists_capabilities():
    text = SCRIPT.read_text(encoding="utf-8")
    assert "capabilities" in text


def test_prepare_package_data_copies_capabilities(tmp_path, monkeypatch):
    """Running the script must copy capabilities/hooks for pip-installed CLI."""
    dest = tmp_path / "data"
    monkeypatch.setenv("DEST_OVERRIDE", str(dest))
    # Run with a patched DEST via subshell — script uses fixed DEST; invoke inline copy check instead.
    subprocess.run(["bash", str(SCRIPT)], check=True, cwd=REPO_ROOT)
    assert (DATA_DEST / "capabilities" / "hooks").is_dir()
    assert list((DATA_DEST / "capabilities" / "hooks").glob("*.yaml"))
