"""Tests for shell completion script generation."""

from __future__ import annotations

from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent


@pytest.fixture(autouse=True)
def _toolkit_root(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(REPO_ROOT))


def test_bash_completion_non_empty() -> None:
    from agent_toolkit.cli.completion import completion_bash

    script = completion_bash()
    assert "complete -F _agent_toolkit_completions agent-toolkit" in script
    assert "install" in script
    assert len(script.strip()) > 100


def test_zsh_completion_non_empty() -> None:
    from agent_toolkit.cli.completion import completion_zsh

    script = completion_zsh()
    assert "#compdef agent-toolkit" in script
    assert "install" in script
    assert len(script.strip()) > 100


def test_fish_completion_non_empty() -> None:
    from agent_toolkit.cli.completion import completion_fish

    script = completion_fish()
    assert "complete -c agent-toolkit" in script
    assert "install" in script
    assert len(script.strip()) > 100


def test_cmd_completion_help() -> None:
    from agent_toolkit.cli.completion import cmd_completion

    assert cmd_completion(["--help"]) == 0
