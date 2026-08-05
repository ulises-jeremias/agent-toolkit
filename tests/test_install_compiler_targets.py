"""Tests for installer gemini-cli/codex compiler alignment."""
from __future__ import annotations

from agent_toolkit.cli.install import _VALID_TOOLS


def test_valid_tools_includes_gemini_and_codex():
    assert "gemini-cli" in _VALID_TOOLS
    assert "codex" in _VALID_TOOLS


def test_install_help_lists_compiler_targets(capsys):
    from agent_toolkit.cli.install import cmd_install

    rc = cmd_install(["--help"])
    out = capsys.readouterr().out
    assert rc == 0
    assert "gemini-cli" in out or "codex" in out or "Valid:" in out
