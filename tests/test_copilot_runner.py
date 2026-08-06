"""Tests for GitHub Copilot CLI loop runner (#224)."""

from __future__ import annotations

import subprocess
from pathlib import Path
from types import SimpleNamespace

from agent_toolkit.loop import runner


def test_resolve_copilot_cli_bin(monkeypatch):
    monkeypatch.setattr(
        runner.shutil, "which", lambda n: "/usr/bin/copilot" if n == "copilot" else None
    )
    assert runner._resolve_copilot_cli_bin() == "/usr/bin/copilot"


def test_try_copilot_runner_missing_binary_returns_false(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner.shutil, "which", lambda _n: None)
    assert runner._try_copilot_runner("prompt", tmp_path) is False


def test_try_copilot_runner_writes_report_on_success(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner, "_resolve_copilot_cli_bin", lambda: "/bin/copilot")
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)

    captured: dict = {}

    def fake_run(cmd, **kwargs):
        captured["cmd"] = cmd
        captured["timeout"] = kwargs.get("timeout")
        return SimpleNamespace(returncode=0, stdout="## Copilot report\n", stderr="")

    monkeypatch.setattr(runner, "_run_with_live_output", fake_run)

    assert runner._try_copilot_runner("summarize", tmp_path, wall_timeout=900) is True
    assert "Copilot report" in (tmp_path / "report.md").read_text(encoding="utf-8")
    assert captured["cmd"][:3] == ["/bin/copilot", "-p", "summarize"]
    assert "-s" in captured["cmd"]
    assert "--no-ask-user" in captured["cmd"]
    assert "--allow-all" in captured["cmd"]
    assert captured["timeout"] == 900


def test_try_copilot_runner_timeout_returns_false(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner, "_resolve_copilot_cli_bin", lambda: "/bin/copilot")
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)

    def boom(*_a, **_k):
        raise subprocess.TimeoutExpired(cmd=["copilot"], timeout=900)

    monkeypatch.setattr(runner, "_run_with_live_output", boom)
    assert runner._try_copilot_runner("prompt", tmp_path) is False


def test_try_copilot_runner_nonzero_exit_returns_false(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner, "_resolve_copilot_cli_bin", lambda: "/bin/copilot")
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)
    monkeypatch.setattr(
        runner,
        "_run_with_live_output",
        lambda *_a, **_k: SimpleNamespace(returncode=1, stdout="", stderr="not logged in"),
    )
    assert runner._try_copilot_runner("prompt", tmp_path) is False
