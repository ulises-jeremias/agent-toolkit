"""npm launcher invokes a native binary (ADR-025 / #536).

Delegates to packages/npm/agent-toolkit-cli/test/launcher.test.js so pytest
and `npm test` share one suite. Prefer `npm test --prefix packages/npm/agent-toolkit-cli`
locally; CI also runs a dedicated Node matrix (`validate.yml` → `test-npm`).
"""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
LAUNCHER_TEST = REPO / "packages/npm/agent-toolkit-cli/test/launcher.test.js"
NPM_PKG = REPO / "packages/npm/agent-toolkit-cli"


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


@pytest.mark.skipif(shutil.which("npm") is None, reason="npm required for package.json test script")
def test_npm_test_script_matches_node_suite() -> None:
    pkg = (NPM_PKG / "package.json").read_text(encoding="utf-8")
    assert '"test": "node --test test/launcher.test.js"' in pkg
