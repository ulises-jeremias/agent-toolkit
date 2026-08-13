"""npm launcher invokes a native binary (ADR-025 / #536)."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
LAUNCHER_TEST = REPO / "packages/npm/agent-toolkit-cli/test/launcher.test.js"


@pytest.mark.skipif(shutil.which("node") is None, reason="node required for npm launcher tests")
def test_npm_launcher_node_suite() -> None:
    proc = subprocess.run(
        ["node", "--test", str(LAUNCHER_TEST)],
        cwd=REPO,
        check=False,
        capture_output=True,
        text=True,
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
