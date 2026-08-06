"""Tests for Cursor Agent CLI loop runner (#223)."""

from __future__ import annotations

import subprocess
from pathlib import Path
from types import SimpleNamespace

from agent_toolkit.loop import runner


def test_resolve_cursor_cli_prefers_cursor_agent(monkeypatch):
    def which(name: str):
        return {
            "cursor-agent": "/usr/bin/cursor-agent",
            "agent": "/usr/bin/agent",
            "cursor": "/usr/bin/cursor",
        }.get(name)

    monkeypatch.setattr(runner.shutil, "which", which)
    assert runner._resolve_cursor_cli_bin() == "/usr/bin/cursor-agent"


def test_resolve_cursor_cli_falls_back_to_agent(monkeypatch):
    def which(name: str):
        return {"agent": "/opt/agent"}.get(name)

    monkeypatch.setattr(runner.shutil, "which", which)
    assert runner._resolve_cursor_cli_bin() == "/opt/agent"


def test_try_cursor_runner_missing_binary_returns_false(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner.shutil, "which", lambda _n: None)
    assert runner._try_cursor_runner("prompt", tmp_path) is False


def test_try_cursor_runner_writes_report_on_success(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner, "_resolve_cursor_cli_bin", lambda: "/bin/cursor-agent")
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)

    captured: dict = {}

    def fake_run(cmd, **kwargs):
        captured["cmd"] = cmd
        captured["timeout"] = kwargs.get("timeout")
        return SimpleNamespace(returncode=0, stdout="# Report\n\nok\n", stderr="")

    monkeypatch.setattr(runner, "_run_with_live_output", fake_run)

    assert runner._try_cursor_runner("do the thing", tmp_path, wall_timeout=900) is True
    assert (tmp_path / "report.md").read_text(encoding="utf-8").startswith("# Report")
    assert captured["cmd"][0] == "/bin/cursor-agent"
    assert "--print" in captured["cmd"]
    assert "--force" in captured["cmd"]
    assert "--trust" in captured["cmd"]
    assert "do the thing" in captured["cmd"]
    assert captured["timeout"] == 900


def test_try_cursor_runner_timeout_returns_false(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner, "_resolve_cursor_cli_bin", lambda: "/bin/cursor-agent")
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)

    def boom(*_a, **_k):
        raise subprocess.TimeoutExpired(cmd=["cursor-agent"], timeout=900)

    monkeypatch.setattr(runner, "_run_with_live_output", boom)
    assert runner._try_cursor_runner("prompt", tmp_path) is False
    assert not (tmp_path / "report.md").exists()


def test_try_cursor_runner_nonzero_exit_returns_false(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner, "_resolve_cursor_cli_bin", lambda: "/bin/cursor-agent")
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)
    monkeypatch.setattr(
        runner,
        "_run_with_live_output",
        lambda *_a, **_k: SimpleNamespace(returncode=2, stdout="", stderr="auth failed"),
    )
    assert runner._try_cursor_runner("prompt", tmp_path) is False
