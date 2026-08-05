"""--json must emit pure JSON on stdout; diff --json preserves change exit codes (#53)."""
from __future__ import annotations

import io
import json
import sys
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent


def _run_cmd(fn, args: list[str]) -> tuple[int, str, str]:
    out = io.StringIO()
    err = io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        code = fn(args)
    return code, out.getvalue(), err.getvalue()


def test_build_json_stdout_is_pure_json(monkeypatch):
    pytest.importorskip("yaml")
    from agent_toolkit.cli.build import cmd_build

    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(REPO_ROOT))
    code, stdout, _stderr = _run_cmd(
        cmd_build,
        ["--check", "--target", "claude-code", "--product", "agent-toolkit-core", "--json"],
    )
    assert code == 0
    assert "Loading canonical graph" not in stdout
    assert "Building " not in stdout
    data = json.loads(stdout)
    assert isinstance(data, list)
    assert data, "expected at least one build result"


def test_diff_json_preserves_change_exit_code(monkeypatch, tmp_path):
    pytest.importorskip("yaml")
    from agent_toolkit.cli import diff as diff_mod

    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(REPO_ROOT))

    class _FakeAdapter:
        def __init__(self, *a, **k):
            self.output_root = tmp_path

        def compile(self, graph, product):
            art = self.output_root / product.id / "NEW.md"
            art.parent.mkdir(parents=True, exist_ok=True)
            art.write_text("new\n", encoding="utf-8")

            class _R:
                pass

            r = _R()
            r.artifacts = [art]
            return r

    monkeypatch.setattr(diff_mod, "_get_adapter", lambda *a, **k: _FakeAdapter())

    code, stdout, _stderr = _run_cmd(
        diff_mod.cmd_diff,
        ["--target", "claude-code", "--product", "agent-toolkit-core", "--json"],
    )
    data = json.loads(stdout)
    assert isinstance(data, list)
    assert any(not e.get("no_changes", True) for e in data)
    assert code == 1, "diff --json must exit 1 when changes exist"


def test_doctor_json_stdout_is_pure_json(monkeypatch):
    from agent_toolkit.cli.doctor import cmd_doctor

    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(REPO_ROOT))
    code, stdout, _stderr = _run_cmd(cmd_doctor, ["--json"])
    assert code in (0, 1)
    assert "agent-toolkit doctor" not in stdout
    assert "── Summary ──" not in stdout
    data = json.loads(stdout)
    assert "checks" in data
