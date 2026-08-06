"""Tests for loop --runner selection and help documentation."""

from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.loop import runner


def test_parse_run_args_runner_flag() -> None:
    name, force, quiet, pack_path, selected = runner._parse_run_args(
        ["demo", "--runner", "claude", "--quiet"]
    )
    assert name == "demo"
    assert force is False
    assert quiet is True
    assert pack_path is None
    assert selected == "claude"


def test_parse_run_args_runner_equals_form() -> None:
    *_rest, selected = runner._parse_run_args(["demo", "--runner=codex"])
    assert selected == "codex"


def test_parse_run_args_runner_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_LOOP_RUNNER", "cursor")
    *_rest, selected = runner._parse_run_args(["demo"])
    assert selected == "cursor"


def test_parse_run_args_flag_overrides_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_LOOP_RUNNER", "cursor")
    *_rest, selected = runner._parse_run_args(["demo", "--runner", "opencode"])
    assert selected == "opencode"


def test_parse_run_args_runner_alias() -> None:
    *_rest, selected = runner._parse_run_args(["demo", "--runner", "devcompanion"])
    assert selected == "queue"


def test_parse_run_args_unknown_runner() -> None:
    with pytest.raises(ValueError, match="Unknown runner"):
        runner._parse_run_args(["demo", "--runner", "nope"])


def test_normalize_runner_auto_default() -> None:
    assert runner._normalize_runner_name(None) == "auto"
    assert runner._normalize_runner_name("") == "auto"
    assert runner._normalize_runner_name("  AUTO ") == "auto"


def test_loop_help_documents_runner_and_env() -> None:
    doc = runner.__doc__ or ""
    assert "--runner" in doc
    assert "AGENT_TOOLKIT_LOOP_RUNNER" in doc
    assert "HARNESS_RUNNER_DIR" in doc
    assert "CURSOR_API_KEY" in doc
    assert "COPILOT_GITHUB_TOKEN" in doc
    assert "OPENAI_API_KEY" in doc
    assert "codex" in doc
    assert "skeleton" in doc


def test_dispatch_explicit_missing_claude_raises(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(runner.shutil, "which", lambda _n: None)
    with pytest.raises(ValueError, match="claude"):
        runner._dispatch_loop_runner(
            "claude",
            prompt="hi",
            run_dir=tmp_path,
            rid="r1",
            loop_name="demo",
            meta={"tier": "L1"},
            trace_file=tmp_path / "trace.jsonl",
            wall_timeout=900,
            token_limit=None,
            plan_md=tmp_path / "plan.md",
            tier="L1",
        )


def test_dispatch_skeleton_writes_plan(tmp_path: Path) -> None:
    plan = tmp_path / "plan.md"
    trace = tmp_path / "trace.jsonl"
    trace.write_text("", encoding="utf-8")
    queued, exhausted = runner._dispatch_loop_runner(
        "skeleton",
        prompt="hi",
        run_dir=tmp_path,
        rid="r1",
        loop_name="demo",
        meta={"tier": "L1", "goal": "ship it"},
        trace_file=trace,
        wall_timeout=900,
        token_limit=None,
        plan_md=plan,
        tier="L1",
    )
    assert queued is False
    assert exhausted is False
    assert plan.exists()
    assert "Skeleton runner" in plan.read_text(encoding="utf-8")
