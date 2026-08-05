"""Tests for loop run live progress flags."""
from __future__ import annotations

from agent_toolkit.loop import runner


def test_cmd_run_usage_includes_quiet():
    assert "--quiet" in runner.__doc__


def test_try_claude_runner_quiet_uses_capture(monkeypatch, tmp_path):
    calls: list[dict] = []

    def fake_run(*args, **kwargs):
        calls.append(kwargs)
        class R:
            returncode = 0
            stdout = "done"
            stderr = ""

        return R()

    monkeypatch.setattr(runner.shutil, "which", lambda _: "/usr/bin/claude")
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner.subprocess, "run", fake_run)

    assert runner._try_claude_runner("prompt", tmp_path, {}, quiet=True)
    assert calls[0]["capture_output"] is True


def test_try_claude_runner_live_streams(monkeypatch, tmp_path):
    calls: list[dict] = []

    def fake_run(*args, **kwargs):
        calls.append(kwargs)
        class R:
            returncode = 0
            stdout = "done"
            stderr = ""

        return R()

    monkeypatch.setattr(runner.shutil, "which", lambda _: "/usr/bin/claude")
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner.subprocess, "run", fake_run)

    assert runner._try_claude_runner("prompt", tmp_path, {}, quiet=False)
    assert "capture_output" not in calls[0]
