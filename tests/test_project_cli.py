"""Tests for project lifecycle CLI subcommands."""
from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.cli import project as project_mod


@pytest.fixture
def workspace(tmp_path: Path) -> Path:
    ws = tmp_path / "workspace"
    ws.mkdir()
    (ws / "AGENTS.md").write_text("# test workspace\n", encoding="utf-8")
    return ws


def test_project_help_exits_0() -> None:
    assert project_mod.cmd_project(["--help"]) == 0


def test_project_init_help_exits_0(workspace: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(workspace)
    assert project_mod.cmd_project(["init", "--help"]) == 0


def test_project_init_creates_manifest(workspace: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(workspace)
    assert project_mod.cmd_project(["init"]) == 0
    assert (workspace / "projects").is_dir()
    assert (workspace / "repos").is_dir()
    assert (workspace / "projects.yaml").is_file()
    assert project_mod.cmd_project(["init"]) == 0  # idempotent


def test_project_list_empty(workspace: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(workspace)
    project_mod.cmd_project(["init"])
    assert project_mod.cmd_project(["list"]) == 0


def test_project_add_and_sync(workspace: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(workspace)
    project_mod.cmd_project(["init"])

    repo = workspace / "repos" / "local" / "demo"
    repo.mkdir(parents=True)
    (repo / "README.md").write_text("demo\n", encoding="utf-8")

    assert project_mod.cmd_project(["add", str(repo)]) == 0
    link = workspace / "projects" / "demo"
    assert link.is_symlink()
    assert link.resolve() == repo

    assert project_mod.cmd_project(["sync"]) == 0
    yaml_text = (workspace / "projects.yaml").read_text(encoding="utf-8")
    assert "name: demo" in yaml_text
    assert str(repo) in yaml_text


def test_project_remove(workspace: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(workspace)
    project_mod.cmd_project(["init"])

    repo = workspace / "repos" / "local" / "demo"
    repo.mkdir(parents=True)
    project_mod.cmd_project(["add", str(repo)])

    assert project_mod.cmd_project(["remove", "demo"]) == 0
    assert not (workspace / "projects" / "demo").exists()
    assert repo.is_dir()  # repo preserved
