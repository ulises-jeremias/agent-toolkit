"""Loop run progress and live output tests."""
from __future__ import annotations

import io
import json
import subprocess
from pathlib import Path
from unittest import mock

import pytest

from agent_toolkit.loop import runner


def test_cmd_run_requires_loop_name() -> None:
    assert runner.cmd_run([]) == 1


def test_cmd_run_quiet_flag_parsed(monkeypatch: pytest.MonkeyPatch) -> None:
    runner._PROGRESS_QUIET = False
    monkeypatch.setattr(runner, "LOOPS_DIR", Path("/nonexistent-loops"))
    assert runner.cmd_run(["missing-loop", "--quiet"]) == 1
    assert runner._PROGRESS_QUIET is True


def test_trace_tailer_emits_repo_progress(capsys: pytest.CaptureFixture[str]) -> None:
    trace = Path("/tmp/test-trace-tail.jsonl")
    trace.write_text(
        json.dumps({"kind": "repo", "name": "agent-toolkit"}) + "\n",
        encoding="utf-8",
    )
    tailer = runner._TraceTailer(trace)
    tailer.poll()
    out = capsys.readouterr().out
    assert "repo: agent-toolkit" in out


def test_run_with_live_output_streams(capsys: pytest.CaptureFixture[str]) -> None:
    runner._PROGRESS_QUIET = False
    result = runner._run_with_live_output(
        ["/bin/echo", "hello-loop"],
        input_text="",
        cwd="/tmp",
        env={**dict(**{"PATH": "/usr/bin:/bin"}), **dict(__import__("os").environ)},
    )
    assert result.returncode == 0
    assert "hello-loop" in capsys.readouterr().out


def test_run_with_live_output_quiet_captures() -> None:
    runner._PROGRESS_QUIET = True
    result = runner._run_with_live_output(
        ["/bin/echo", "quiet-mode"],
        input_text="",
        cwd="/tmp",
        env={**dict(**{"PATH": "/usr/bin:/bin"}), **dict(__import__("os").environ)},
    )
    assert result.returncode == 0
    assert "quiet-mode" in result.stdout
