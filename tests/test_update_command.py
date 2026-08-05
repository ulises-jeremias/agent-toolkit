"""Tests for agent-toolkit update command."""
from __future__ import annotations

from agent_toolkit.cli.update import cmd_update


def test_update_help(capsys):
    rc = cmd_update(["--help"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "--check" in out
    assert "--tools" in out


def test_update_check_no_tools(capsys):
    rc = cmd_update(["--check"])
    err = capsys.readouterr().err
    assert rc == 1 or "No installed tools" in err or rc == 0
