"""Queue storage backends for devcompanion (#203).

Legacy (workspace-local):
    WORKSPACE/.devcompanion/queue/<job-id>.json  (status field)

Harness-compatible:
    $HARNESS_DC_HOME/queue/{pending,processing,done,failed}/<job-id>.job
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path


def default_harness_dc_home() -> Path:
    return Path.home() / ".local" / "share" / "agentic-harness" / "dev-companion"


def resolve_harness_dc_home() -> Path | None:
    """Return harness DC home when HARNESS_DC_HOME or HARNESS_DIR is set."""
    explicit = os.environ.get("HARNESS_DC_HOME", "").strip()
    if explicit:
        return Path(explicit).expanduser()
    if os.environ.get("HARNESS_DIR", "").strip():
        return default_harness_dc_home()
    return None


@dataclass(frozen=True)
class DCConfig:
    harness_mode: bool
    dc_home: Path
    queue_dir: Path
    runs_dir: Path
    queue_pending: Path
    queue_processing: Path
    queue_done: Path
    queue_failed: Path


def get_dc_config(workspace_root: Path) -> DCConfig:
    harness_home = resolve_harness_dc_home()
    if harness_home is not None:
        queue_root = harness_home / "queue"
        artifacts = queue_root / "artifacts"
        return DCConfig(
            harness_mode=True,
            dc_home=harness_home,
            queue_dir=queue_root,
            runs_dir=artifacts,
            queue_pending=queue_root / "pending",
            queue_processing=queue_root / "processing",
            queue_done=queue_root / "done",
            queue_failed=queue_root / "failed",
        )

    dc_home = workspace_root / ".devcompanion"
    queue_dir = dc_home / "queue"
    return DCConfig(
        harness_mode=False,
        dc_home=dc_home,
        queue_dir=queue_dir,
        runs_dir=dc_home / "runs",
        queue_pending=queue_dir,
        queue_processing=queue_dir,
        queue_done=queue_dir,
        queue_failed=queue_dir,
    )


def read_job(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def write_job(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def job_project_path(job: dict) -> str:
    return str(job.get("project_path") or job.get("repo_path") or "")


def job_project_name(job: dict) -> str:
    if job.get("project"):
        return str(job["project"])
    repo = job_project_path(job)
    return Path(repo).name if repo else "?"


def job_status(cfg: DCConfig, job_id: str) -> str | None:
    """Return queue state for a job id (harness dirs or legacy status field)."""
    if cfg.harness_mode:
        for state, directory in (
            ("pending", cfg.queue_pending),
            ("processing", cfg.queue_processing),
            ("done", cfg.queue_done),
            ("failed", cfg.queue_failed),
        ):
            if (directory / f"{job_id}.job").exists():
                return state
        return None

    path = cfg.queue_dir / f"{job_id}.json"
    if not path.exists():
        return None
    return read_job(path).get("status")


def find_job_path(cfg: DCConfig, job_id: str) -> Path | None:
    if cfg.harness_mode:
        for directory in (
            cfg.queue_pending,
            cfg.queue_processing,
            cfg.queue_done,
            cfg.queue_failed,
        ):
            path = directory / f"{job_id}.job"
            if path.exists():
                return path
        return None

    path = cfg.queue_dir / f"{job_id}.json"
    return path if path.exists() else None


def iter_jobs(cfg: DCConfig) -> list[tuple[str, Path, dict]]:
    """Return (status, path, job_dict) sorted by file mtime."""
    items: list[tuple[str, Path, dict]] = []

    if cfg.harness_mode:
        for state, directory in (
            ("pending", cfg.queue_pending),
            ("processing", cfg.queue_processing),
            ("done", cfg.queue_done),
            ("failed", cfg.queue_failed),
        ):
            if not directory.is_dir():
                continue
            for path in directory.glob("*.job"):
                try:
                    items.append((state, path, read_job(path)))
                except Exception:
                    pass
    else:
        if cfg.queue_dir.is_dir():
            for path in cfg.queue_dir.glob("*.json"):
                try:
                    job = read_job(path)
                    items.append((str(job.get("status", "?")), path, job))
                except Exception:
                    pass

    items.sort(key=lambda item: item[1].stat().st_mtime)
    return items


def pending_jobs(cfg: DCConfig) -> list[tuple[Path, dict]]:
    if cfg.harness_mode:
        cfg.queue_pending.mkdir(parents=True, exist_ok=True)
        jobs: list[tuple[Path, dict]] = []
        for path in sorted(cfg.queue_pending.glob("*.job"), key=lambda p: p.stat().st_mtime):
            try:
                jobs.append((path, read_job(path)))
            except Exception:
                pass
        return jobs

    cfg.queue_dir.mkdir(parents=True, exist_ok=True)
    jobs = []
    for path in sorted(cfg.queue_dir.glob("*.json"), key=lambda p: p.stat().st_mtime):
        try:
            job = read_job(path)
            if job.get("status") == "pending":
                jobs.append((path, job))
        except Exception:
            pass
    return jobs


def queue_job_path(cfg: DCConfig, job_id: str) -> Path:
    if cfg.harness_mode:
        return cfg.queue_pending / f"{job_id}.job"
    return cfg.queue_dir / f"{job_id}.json"


def move_job(cfg: DCConfig, job_id: str, dest_state: str) -> Path | None:
    """Move a job file to done/failed/processing/pending (harness) or update status (legacy)."""
    if cfg.harness_mode:
        source = find_job_path(cfg, job_id)
        if source is None:
            return None
        dest_dir = {
            "pending": cfg.queue_pending,
            "processing": cfg.queue_processing,
            "done": cfg.queue_done,
            "failed": cfg.queue_failed,
        }.get(dest_state)
        if dest_dir is None:
            return None
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / f"{job_id}.job"
        source.rename(dest)
        return dest

    path = cfg.queue_dir / f"{job_id}.json"
    if not path.exists():
        return None
    job = read_job(path)
    job["status"] = dest_state
    write_job(path, job)
    return path


def mark_job_done(cfg: DCConfig, job_id: str, completed_at: str) -> bool:
    if cfg.harness_mode:
        for src_dir in (cfg.queue_pending, cfg.queue_processing, cfg.queue_failed):
            src = src_dir / f"{job_id}.job"
            if src.exists():
                cfg.queue_done.mkdir(parents=True, exist_ok=True)
                src.rename(cfg.queue_done / f"{job_id}.job")
                return True
        return (cfg.queue_done / f"{job_id}.job").exists()

    path = cfg.queue_dir / f"{job_id}.json"
    if not path.exists():
        return False
    job = read_job(path)
    job["status"] = "done"
    job["completed_at"] = completed_at
    write_job(path, job)
    return True
