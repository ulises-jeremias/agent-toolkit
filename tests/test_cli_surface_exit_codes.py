"""#48 — consumer/advanced surface exit-code contract (CLI-011, CLI-012)."""
from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.cli import skills as skills_mod
from agent_toolkit.cli.devcompanion import TemplateNotFoundError, _load_template, _safe_parse, cmd_devcompanion


def test_skills_sync_unknown_tool_exits_1(tmp_path: Path) -> None:
    assert skills_mod._cmd_sync(["--tools", "not-a-real-tool"], tmp_path) == 1


def test_load_template_missing_raises(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    import agent_toolkit.cli.devcompanion as dc

    monkeypatch.setattr(dc, "TEMPLATES_DIR", tmp_path)
    with pytest.raises(TemplateNotFoundError):
        _load_template("missing-template")


def test_safe_parse_help_returns_0() -> None:
    import argparse

    p = argparse.ArgumentParser(prog="test")
    args, err = _safe_parse(p, ["--help"])
    assert args is None
    assert err == 0


def test_devcompanion_queue_missing_template_returns_1(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    import agent_toolkit.cli.devcompanion as dc

    projects = tmp_path / "projects"
    projects.mkdir()
    (projects / "demo").symlink_to(tmp_path, target_is_directory=True)
    monkeypatch.setattr(dc, "PROJECTS_DIR", projects)
    monkeypatch.setattr(dc, "TEMPLATES_DIR", tmp_path / "templates")
    monkeypatch.setattr(dc, "QUEUE_DIR", tmp_path / "queue")
    (tmp_path / "templates").mkdir()
    (tmp_path / "queue").mkdir()

    assert cmd_devcompanion(["queue", "demo", "--template", "nope"]) == 1
