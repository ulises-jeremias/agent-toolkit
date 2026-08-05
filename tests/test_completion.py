"""Tests for shell completion command."""
from __future__ import annotations

from agent_toolkit.cli.completion import cmd_completion


def test_completion_bash_includes_install_tools(capsys):
    rc = cmd_completion(["bash"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "claude-code" in out
    assert "complete -F _agent_toolkit_completions agent-toolkit" in out


def test_completion_fish_lists_mcp_providers(capsys):
    rc = cmd_completion(["fish"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "github" in out
    assert "setup" in out


def test_completion_unknown_shell(capsys):
    rc = cmd_completion(["powershell"])
    assert rc == 2
