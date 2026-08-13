"""pack_npm.py copies ADR-018 floating binaries into npm platform packages."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def test_pack_npm_copies_floating_linux_binary(tmp_path: Path) -> None:
    src = tmp_path / "binaries"
    src.mkdir()
    (src / "agent-toolkit-linux-x86_64").write_bytes(b"fake-elf")
    dest = REPO / "packages/npm/agent-toolkit-cli-linux-x64/bin/agent-toolkit"
    env = os.environ.copy()
    env["RELEASE_BIN_DIR"] = str(src)
    env["RELEASE_VERSION"] = "9.9.9"
    restore = os.environ.copy()
    restore["RELEASE_BIN_DIR"] = str(tmp_path / "empty")
    (tmp_path / "empty").mkdir()
    try:
        subprocess.run(
            [sys.executable, str(REPO / "scripts/pack_npm.py")],
            cwd=REPO,
            env=env,
            check=True,
        )
        assert dest.is_file()
        assert dest.read_bytes() == b"fake-elf"
        pkg = json.loads(
            (REPO / "packages/npm/agent-toolkit-cli-linux-x64/package.json").read_text()
        )
        assert pkg["version"] == "9.9.9"
        assert "README.md" in pkg["files"]
        meta = json.loads((REPO / "packages/npm/agent-toolkit-cli/package.json").read_text())
        assert meta["version"] == "9.9.9"
    finally:
        dest.unlink(missing_ok=True)
        subprocess.run(
            [sys.executable, str(REPO / "scripts/pack_npm.py")],
            cwd=REPO,
            env=restore,
            check=True,
        )
    restored = json.loads((REPO / "packages/npm/agent-toolkit-cli/package.json").read_text())
    assert restored["version"] == (REPO / "VERSION").read_text().strip()
