"""Basic CLI smoke tests."""

import subprocess
import sys


def test_help():
    result = subprocess.run(
        [sys.executable, "-m", "agent_toolkit", "help"],
        capture_output=True,
        text=True,
        cwd=str(__file__).split("tests")[0],
    )
    # Help exits 0 and contains key commands
    assert "loop" in result.stdout
    assert "install" in result.stdout


def test_version():
    result = subprocess.run(
        [sys.executable, "-m", "agent_toolkit", "version"],
        capture_output=True,
        text=True,
        cwd=str(__file__).split("tests")[0],
    )
    assert result.returncode == 0
    assert "agent-toolkit" in result.stdout
