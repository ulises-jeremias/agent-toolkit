"""Tests for OpenAI Codex CLI loop runner (#225)."""

from __future__ import annotations

import subprocess
from pathlib import Path
from types import SimpleNamespace

from agent_toolkit.loop import runner


def test_try_codex_runner_missing_binary_returns_false(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner.shutil, "which", lambda _n: None)
    assert runner._try_codex_runner("prompt", tmp_path) is False


def test_try_codex_runner_writes_report_on_success(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner.shutil, "which", lambda n: "/bin/codex" if n == "codex" else None)
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)

    captured: dict = {}

    def fake_run(cmd, **kwargs):
        captured["cmd"] = cmd
        captured["input"] = kwargs.get("input_text")
        captured["timeout"] = kwargs.get("timeout")
        # Simulate --output-last-message writing the report.
        Path(cmd[cmd.index("--output-last-message") + 1]).write_text(
            "# Codex report\n", encoding="utf-8"
        )
        return SimpleNamespace(returncode=0, stdout="", stderr="progress")

    monkeypatch.setattr(runner, "_run_with_live_output", fake_run)

    assert runner._try_codex_runner("fix tests", tmp_path, wall_timeout=900) is True
    assert (tmp_path / "report.md").read_text(encoding="utf-8").startswith("# Codex")
    assert captured["cmd"][0:2] == ["/bin/codex", "exec"]
    assert "--ask-for-approval" in captured["cmd"]
    assert "never" in captured["cmd"]
    assert "--sandbox" in captured["cmd"]
    assert "workspace-write" in captured["cmd"]
    assert captured["cmd"][-1] == "-"
    assert captured["input"] == "fix tests"
    assert captured["timeout"] == 900


def test_try_codex_runner_falls_back_to_stdout(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner.shutil, "which", lambda n: "/bin/codex" if n == "codex" else None)
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)
    monkeypatch.setattr(
        runner,
        "_run_with_live_output",
        lambda *_a, **_k: SimpleNamespace(returncode=0, stdout="from stdout\n", stderr=""),
    )
    assert runner._try_codex_runner("p", tmp_path) is True
    assert (tmp_path / "report.md").read_text(encoding="utf-8") == "from stdout\n"


def test_try_codex_runner_timeout_returns_false(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner.shutil, "which", lambda n: "/bin/codex" if n == "codex" else None)
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)

    def boom(*_a, **_k):
        raise subprocess.TimeoutExpired(cmd=["codex"], timeout=900)

    monkeypatch.setattr(runner, "_run_with_live_output", boom)
    assert runner._try_codex_runner("prompt", tmp_path) is False


def test_try_codex_runner_nonzero_exit_returns_false(monkeypatch, tmp_path: Path):
    monkeypatch.setattr(runner.shutil, "which", lambda n: "/bin/codex" if n == "codex" else None)
    monkeypatch.setattr(runner, "_install_gate_into_environ", lambda *_a, **_k: {})
    monkeypatch.setattr(runner, "workspace_root", lambda: tmp_path)
    monkeypatch.setattr(
        runner,
        "_run_with_live_output",
        lambda *_a, **_k: SimpleNamespace(returncode=1, stdout="", stderr="no auth"),
    )
    assert runner._try_codex_runner("prompt", tmp_path) is False
