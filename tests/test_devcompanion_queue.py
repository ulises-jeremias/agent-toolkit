"""Tests for devcompanion harness queue storage (#203)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

import agent_toolkit.cli.devcompanion_queue as dq


@pytest.fixture(autouse=True)
def _clear_harness_env(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("HARNESS_DC_HOME", raising=False)
    monkeypatch.delenv("HARNESS_DIR", raising=False)


def test_resolve_harness_dc_home_from_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    custom = tmp_path / "dc-home"
    monkeypatch.setenv("HARNESS_DC_HOME", str(custom))
    assert dq.resolve_harness_dc_home() == custom


def test_resolve_harness_dc_home_from_harness_dir(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("HARNESS_DIR", "/tmp/my-harness")
    assert dq.resolve_harness_dc_home() == dq.default_harness_dc_home()


def test_resolve_harness_dc_home_unset() -> None:
    assert dq.resolve_harness_dc_home() is None


def test_get_dc_config_legacy(tmp_path: Path) -> None:
    cfg = dq.get_dc_config(tmp_path)
    assert cfg.harness_mode is False
    assert cfg.queue_dir == tmp_path / ".devcompanion" / "queue"
    assert cfg.runs_dir == tmp_path / ".devcompanion" / "runs"


def test_get_dc_config_harness_from_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    dc_home = tmp_path / "harness-dc"
    monkeypatch.setenv("HARNESS_DC_HOME", str(dc_home))
    cfg = dq.get_dc_config(tmp_path / "workspace")
    assert cfg.harness_mode is True
    assert cfg.dc_home == dc_home
    assert cfg.queue_pending == dc_home / "queue" / "pending"
    assert cfg.queue_processing == dc_home / "queue" / "processing"
    assert cfg.queue_done == dc_home / "queue" / "done"
    assert cfg.queue_failed == dc_home / "queue" / "failed"
    assert cfg.runs_dir == dc_home / "queue" / "artifacts"


def test_harness_queue_write_and_status(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    dc_home = tmp_path / "dc"
    monkeypatch.setenv("HARNESS_DC_HOME", str(dc_home))
    cfg = dq.get_dc_config(tmp_path)

    job = {
        "id": "test-job",
        "created_at": "2026-08-05T12:00:00Z",
        "request": "do something",
        "repo_path": "/repo/path",
        "llm": True,
        "limits": {"timeout_sec": 1800, "max_steps": 25},
        "actions_allowed": ["plan_only"],
    }
    job_path = dq.queue_job_path(cfg, "test-job")
    dq.write_job(job_path, job)

    assert job_path == dc_home / "queue" / "pending" / "test-job.job"
    assert job_path.exists()
    assert "status" not in json.loads(job_path.read_text(encoding="utf-8"))
    assert dq.job_status(cfg, "test-job") == "pending"


def test_harness_move_to_done(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    dc_home = tmp_path / "dc"
    monkeypatch.setenv("HARNESS_DC_HOME", str(dc_home))
    cfg = dq.get_dc_config(tmp_path)

    job_path = dq.queue_job_path(cfg, "move-me")
    dq.write_job(job_path, {"id": "move-me", "request": "x", "repo_path": "/p"})

    assert dq.mark_job_done(cfg, "move-me", "2026-08-05T12:00:00Z")
    assert not job_path.exists()
    assert (cfg.queue_done / "move-me.job").exists()
    assert dq.job_status(cfg, "move-me") == "done"


def test_harness_run_once_flow(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Simulate run-once state transitions: pending → processing → done."""
    dc_home = tmp_path / "dc"
    monkeypatch.setenv("HARNESS_DC_HOME", str(dc_home))
    cfg = dq.get_dc_config(tmp_path)

    pending_path = dq.queue_job_path(cfg, "run-me")
    dq.write_job(pending_path, {"id": "run-me", "request": "x", "repo_path": "/p"})

    pending = dq.pending_jobs(cfg)
    assert len(pending) == 1
    job_file, job = pending[0]

    cfg.queue_processing.mkdir(parents=True, exist_ok=True)
    processing_file = cfg.queue_processing / job_file.name
    job_file.rename(processing_file)

    cfg.queue_done.mkdir(parents=True, exist_ok=True)
    processing_file.rename(cfg.queue_done / processing_file.name)

    assert dq.job_status(cfg, "run-me") == "done"
    assert dq.pending_jobs(cfg) == []


def test_legacy_queue_uses_json_with_status(tmp_path: Path) -> None:
    cfg = dq.get_dc_config(tmp_path)
    job_path = dq.queue_job_path(cfg, "legacy-job")
    dq.write_job(
        job_path,
        {
            "id": "legacy-job",
            "created_at": "2026-08-05T12:00:00Z",
            "project": "my-api",
            "project_path": "/projects/my-api",
            "request": "review code",
            "status": "pending",
        },
    )

    assert job_path.suffix == ".json"
    assert dq.job_status(cfg, "legacy-job") == "pending"

    dq.move_job(cfg, "legacy-job", "running")
    assert dq.job_status(cfg, "legacy-job") == "running"


def test_job_project_path_normalizes_repo_path() -> None:
    assert dq.job_project_path({"repo_path": "/a/b/c"}) == "/a/b/c"
    assert dq.job_project_path({"project_path": "/x/y"}) == "/x/y"
    assert dq.job_project_name({"project": "foo"}) == "foo"
    assert dq.job_project_name({"repo_path": "/repos/bar"}) == "bar"


def test_devcompanion_queue_integration(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """End-to-end queue + run-once with harness layout (--no-llm)."""
    workspace = tmp_path / "ws"
    workspace.mkdir()
    projects = workspace / "projects"
    projects.mkdir()
    repo = tmp_path / "repo"
    repo.mkdir()
    (projects / "demo").symlink_to(repo, target_is_directory=True)

    dc_home = tmp_path / "harness-dc"
    monkeypatch.setenv("HARNESS_DC_HOME", str(dc_home))
    monkeypatch.setenv("AGENT_TOOLKIT_WORKSPACE", str(workspace))
    monkeypatch.chdir(workspace)

    from agent_toolkit.cli import devcompanion

    assert devcompanion._cfg().harness_mode is True

    rc = devcompanion._cmd_queue(["demo", "--request", "test harness queue", "--id", "demo-1"])
    assert rc == 0
    assert (dc_home / "queue" / "pending" / "demo-1.job").exists()

    rc = devcompanion._cmd_run_once(["--no-llm"])
    assert rc == 0
    assert not (dc_home / "queue" / "pending" / "demo-1.job").exists()
    assert (dc_home / "queue" / "done" / "demo-1.job").exists()
    assert (dc_home / "queue" / "artifacts" / "demo-1" / "plan.md").exists()
