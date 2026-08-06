"""Tests for agent-toolkit project init (#208)."""

from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.cli.project import cmd_init, cmd_project


def test_project_init_creates_dirs_and_gitignore(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    monkeypatch.chdir(tmp_path)

    assert cmd_init([], tmp_path) == 0
    out = capsys.readouterr().out
    assert "Initialized project directories" in out

    assert (tmp_path / "repos" / "github.com").is_dir()
    assert (tmp_path / "projects").is_dir()

    gitignore = (tmp_path / ".gitignore").read_text(encoding="utf-8")
    assert "repos/" in gitignore
    assert "projects/" in gitignore


def test_project_init_idempotent(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    monkeypatch.chdir(tmp_path)

    assert cmd_init([], tmp_path) == 0
    assert cmd_init([], tmp_path) == 0
    out = capsys.readouterr().out
    assert out.count("Initialized project directories") == 2

    gitignore = (tmp_path / ".gitignore").read_text(encoding="utf-8")
    assert gitignore.count("repos/") == 1
    assert gitignore.count("projects/") == 1


def test_project_init_preserves_existing_gitignore(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    (tmp_path / ".gitignore").write_text("node_modules/\n", encoding="utf-8")

    assert cmd_init([], tmp_path) == 0

    lines = (tmp_path / ".gitignore").read_text(encoding="utf-8").splitlines()
    assert lines[0] == "node_modules/"
    assert "repos/" in lines
    assert "projects/" in lines


def test_project_init_help_exits_0(capsys: pytest.CaptureFixture[str]) -> None:
    assert cmd_init(["--help"], Path("/tmp")) == 0
    assert "project init" in capsys.readouterr().out


def test_project_init_via_router(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    monkeypatch.chdir(tmp_path)

    assert cmd_project(["init", "--workspace", str(tmp_path)]) == 0
    assert (tmp_path / "repos" / "github.com").is_dir()
    assert (tmp_path / "projects").is_dir()


def test_project_init_unknown_subcommand(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    assert cmd_project(["nope"]) == 1


def test_project_init_rejects_unexpected_args(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    assert cmd_init(["--workspace"], tmp_path) == 1
