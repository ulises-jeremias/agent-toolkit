"""Tests for loop budget enforcement, --pack overrides, and devcompanion gh-gate (#42)."""
from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from agent_toolkit.loop import budget, pack, runner
from agent_toolkit.loop.pack import apply_loop_pack_overrides, load_pack


def test_parse_run_args_with_pack() -> None:
    name, force, quiet, pack_path, selected = runner._parse_run_args(
        ["oss-daily-briefing", "--pack", "/tmp/pack.yaml", "--force", "--quiet"]
    )
    assert name == "oss-daily-briefing"
    assert force is True
    assert quiet is True
    assert pack_path == Path("/tmp/pack.yaml")
    assert selected == "auto"


def test_apply_pack_overrides_budget_and_cadence() -> None:
    meta = {"tier": "L1", "cadence": "1d", "budget": {"max_tokens": 80000, "max_wall_seconds": 900}}
    pack_data = {
        "loops": {
            "oss-daily-briefing": {
                "enabled": True,
                "cadence": "12h",
                "budget": {"max_tokens": 120000, "max_wall_seconds": 600},
            }
        }
    }
    merged = apply_loop_pack_overrides(meta, pack_data, "oss-daily-briefing")
    assert merged["cadence"] == "12h"
    assert merged["budget"]["max_tokens"] == 120000
    assert merged["budget"]["max_wall_seconds"] == 600
    assert merged["tier"] == "L1"


def test_pack_disabled_loop_skips(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    monkeypatch.chdir(tmp_path)

    loop_dir = tmp_path / "loops" / "demo-loop"
    loop_dir.mkdir(parents=True)
    (loop_dir / "LOOP.md").write_text(
        "---\nname: demo-loop\ntier: L1\ncadence: 1d\nbudget:\n  max_runs_per_day: 10\n---\n",
        encoding="utf-8",
    )
    (loop_dir / "STATE.md").write_text(
        "---\nlast_run: never\nruns_today: 0\n---\n",
        encoding="utf-8",
    )

    pack_file = tmp_path / "packs" / "demo.yaml"
    pack_file.parent.mkdir(parents=True)
    pack_file.write_text(
        "pack: demo\nloops:\n  demo-loop:\n    enabled: false\n",
        encoding="utf-8",
    )

    rc = runner.cmd_run(["demo-loop", "--pack", str(pack_file)])
    assert rc == 0
    assert not any((loop_dir / "runs").iterdir()) if (loop_dir / "runs").exists() else True


def test_wall_timeout_enforced_on_subprocess(tmp_path: Path) -> None:
    trace = tmp_path / "trace.jsonl"
    trace.write_text("", encoding="utf-8")
    with pytest.raises(subprocess.TimeoutExpired):
        runner._run_with_live_output(
            ["sleep", "5"],
            input_text="",
            cwd=str(tmp_path),
            env={"PATH": "/usr/bin:/bin", **dict(__import__("os").environ)},
            trace_file=trace,
            timeout=1,
        )


def test_token_trace_tailer_triggers_budget_exhausted() -> None:
    trace = Path("/tmp/loop-budget-trace-test.jsonl")
    trace.write_text(
        json.dumps({"kind": "token_usage", "total_tokens": 50000}) + "\n",
        encoding="utf-8",
    )
    tailer = runner._TraceTailer(trace, max_tokens=40000)
    tailer.poll()
    assert tailer.budget_exhausted is True
    assert tailer.tokens_used >= 40000


def test_tokens_from_trace_and_budget_check() -> None:
    trace = Path("/tmp/loop-budget-sum-test.jsonl")
    trace.write_text(
        json.dumps({"kind": "prompt", "prompt_tokens": 1000, "completion_tokens": 0}) + "\n"
        + json.dumps({"kind": "completion", "prompt_tokens": 0, "completion_tokens": 500}) + "\n",
        encoding="utf-8",
    )
    assert budget.tokens_from_trace(trace) == 1500
    assert budget.token_budget_exceeded(1500, {"max_tokens": 1500})
    assert not budget.token_budget_exceeded(1499, {"max_tokens": 1500})


def test_cmd_run_records_pack_budget_in_trace(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(runner, "_try_claude_runner", lambda *a, **k: False)
    monkeypatch.setattr(runner, "_try_opencode_runner", lambda *a, **k: False)
    monkeypatch.setattr(runner, "_queue_via_devcompanion", lambda *a, **k: False)

    loop_dir = tmp_path / "loops" / "budget-loop"
    loop_dir.mkdir(parents=True)
    (loop_dir / "LOOP.md").write_text(
        "---\nname: budget-loop\ntier: L1\ncadence: 1d\n"
        "budget:\n  max_runs_per_day: 5\n  max_wall_seconds: 120\n  max_tokens: 25000\n---\n",
        encoding="utf-8",
    )
    (loop_dir / "STATE.md").write_text("---\nlast_run: never\nruns_today: 0\n---\n", encoding="utf-8")

    pack_file = tmp_path / "packs" / "override.yaml"
    pack_file.parent.mkdir(parents=True)
    pack_file.write_text(
        "pack: override\nloops:\n  budget-loop:\n    budget:\n      max_wall_seconds: 45\n      max_tokens: 10000\n",
        encoding="utf-8",
    )

    rc = runner.cmd_run(["budget-loop", "--pack", str(pack_file)])
    assert rc == 0

    runs = list((loop_dir / "runs").iterdir())
    assert len(runs) == 1
    trace_lines = (runs[0] / "trace.jsonl").read_text(encoding="utf-8").splitlines()
    start = json.loads(trace_lines[0])
    assert start["max_wall_seconds"] == 45
    assert start["max_tokens"] == 10000


def test_load_pack_from_yaml_file(tmp_path: Path) -> None:
    path = tmp_path / "config.yaml"
    path.write_text("pack: test\nloops:\n  foo:\n    enabled: true\n", encoding="utf-8")
    data = load_pack(path)
    assert data["pack"] == "test"
    assert pack.loop_pack_entry(data, "foo")["enabled"] is True


def test_devcompanion_claude_runner_installs_gate(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    from agent_toolkit.cli import devcompanion

    out_dir = tmp_path / "artifacts" / "job-1"
    job = {"id": "job-1", "request": "review code", "repo_path": str(tmp_path)}

    installed: list[dict] = []

    def fake_install(run_dir: Path, **kwargs: object) -> dict[str, str]:
        installed.append({"run_dir": str(run_dir), **kwargs})
        return {
            "PATH": f"{run_dir}/.gate/bin:/usr/bin",
            "LOOP_GATE_TIER": str(kwargs.get("tier", "L1")),
        }

    monkeypatch.setattr("agent_toolkit.loop.gh_gate.install_gh_shim", fake_install)

    def fake_which(name: str) -> str | None:
        if name == "claude":
            return "/usr/bin/claude"
        if name == "gh":
            return "/usr/bin/gh"
        return None

    monkeypatch.setattr("shutil.which", fake_which)

    captured: dict[str, str] = {}

    def fake_run(cmd: list[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
        env = kwargs.get("env")
        if isinstance(env, dict):
            captured.update(env)
        return subprocess.CompletedProcess(cmd, 0, "# plan", "")

    monkeypatch.setattr("subprocess.run", fake_run)

    assert devcompanion._try_claude_runner(job, out_dir) is True
    assert installed
    assert captured.get("LOOP_GATE_TIER") == "L1"
    assert ".gate/bin" in captured.get("PATH", "")


def test_devcompanion_mutating_job_refuses_without_gh(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    from agent_toolkit.cli import devcompanion
    from agent_toolkit.cli.devcompanion_queue import get_dc_config

    dc_home = tmp_path / "dc"
    monkeypatch.setenv("HARNESS_DC_HOME", str(dc_home))
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(tmp_path))

    cfg = get_dc_config(tmp_path)
    job = {
        "id": "mut-1",
        "template": "create-pr",
        "request": "open a draft PR",
        "repo_path": str(tmp_path),
        "actions_allowed": ["plan_only"],
    }
    out_dir = cfg.runs_dir / "mut-1"

    def fake_which(name: str) -> str | None:
        if name == "claude":
            return "/usr/bin/claude"
        return None

    monkeypatch.setattr("shutil.which", fake_which)

    rc = devcompanion._dispatch_run(cfg, Path("mut-1.job"), job, out_dir, no_llm=False)
    assert rc == 2


def test_devcompanion_mutating_job_requires_gate_when_gh_missing_on_install(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    from agent_toolkit.cli import devcompanion

    out_dir = tmp_path / "out"
    job = {
        "id": "mut-2",
        "template": "fix-ci",
        "request": "fix CI",
        "actions_allowed": ["write", "push"],
    }

    def fake_which(name: str) -> str | None:
        if name == "claude":
            return "/usr/bin/claude"
        if name == "gh":
            return "/usr/bin/gh"
        return None

    monkeypatch.setattr("shutil.which", fake_which)

    def fail_install(*_a: object, **_k: object) -> dict[str, str]:
        raise RuntimeError("real `gh` binary not found on PATH")

    monkeypatch.setattr("agent_toolkit.loop.gh_gate.install_gh_shim", fail_install)

    assert devcompanion._try_claude_runner(job, out_dir) is False
