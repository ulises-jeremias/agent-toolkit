"""Tests for loop init / template resolution / workspace loops (#200/#201/#202/#207)."""
from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit._paths import find_workspace_root
from agent_toolkit.loop import runner


def test_find_workspace_root_harness_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("AGENT_TOOLKIT_WORKSPACE", raising=False)
    monkeypatch.setenv("HARNESS_DIR", str(tmp_path))
    assert find_workspace_root() == tmp_path.resolve()


def test_find_workspace_root_prefers_agent_toolkit_workspace(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    a = tmp_path / "a"
    b = tmp_path / "b"
    a.mkdir()
    b.mkdir()
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(a))
    monkeypatch.setenv("HARNESS_DIR", str(b))
    assert find_workspace_root() == a.resolve()


def test_loop_init_from_bundled_template(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.delenv("AI_WORKSPACE", raising=False)
    monkeypatch.delenv("HARNESS_DIR", raising=False)
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    monkeypatch.chdir(tmp_path)
    # Ensure toolkit loops are discoverable via editable install / repo
    assert runner.resolve_template("oss-pr-monitor") is not None
    assert runner.workspace_root() == tmp_path.resolve()
    assert runner.cmd_init(["oss-pr-monitor"]) == 0
    loop_dir = tmp_path / "loops" / "oss-pr-monitor"
    assert (loop_dir / "LOOP.md").is_file()
    assert (loop_dir / "STATE.md").is_file()
    assert (loop_dir / "runs").is_dir()
    assert runner.cmd_init(["oss-pr-monitor"]) == 1  # already exists


def test_loop_init_custom_name_and_user_template(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("AGENT_TOOLKIT_ROOT", raising=False)
    monkeypatch.delenv("AI_WORKSPACE", raising=False)
    monkeypatch.delenv("HARNESS_DIR", raising=False)
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    monkeypatch.chdir(tmp_path)
    tpl = tmp_path / "templates" / "loops"
    tpl.mkdir(parents=True)
    (tpl / "weekly-dep.yaml").write_text(
        "name: weekly-dep\ntier: L2\ncadence: 7d\ngoal: keep deps fresh\n",
        encoding="utf-8",
    )
    assert runner.cmd_init(["weekly-dep", "--name", "deps-acme"]) == 0
    loop_dir = tmp_path / "loops" / "deps-acme"
    text = (loop_dir / "LOOP.md").read_text(encoding="utf-8")
    assert "name: deps-acme" in text
    assert "tier: L2" in text


def test_resolve_loop_dir_prefers_workspace(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    user = tmp_path / "loops" / "oss-pr-monitor"
    user.mkdir(parents=True)
    (user / "LOOP.md").write_text("---\nname: oss-pr-monitor\ntier: L3\n---\n", encoding="utf-8")
    resolved = runner.resolve_loop_dir("oss-pr-monitor")
    assert resolved == user
