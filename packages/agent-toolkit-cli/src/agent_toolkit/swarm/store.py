"""Swarm store — filesystem layout, atomic writes, observability."""

from __future__ import annotations

import json
import os
import re
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import STATE_VERSION

# Default swarm root relative to repo: .agent-toolkit/swarm/runs/<run-id>
SWARM_DIR_NAME = ".agent-toolkit"
SWARM_SUBDIR = "swarm"
RUNS_SUBDIR = "runs"

ALLOWED_PATH_RE = re.compile(r"^[a-zA-Z0-9._/-]+$")


def swarm_root_for_repo(repo_root: Path) -> Path:
    return repo_root / SWARM_DIR_NAME / SWARM_SUBDIR


def run_dir_for(repo_root: Path, run_id: str) -> Path:
    # Validate run_id strictly to prevent traversal
    if not re.match(r"^[a-zA-Z0-9][a-zA-Z0-9._-]{2,64}$", run_id):
        raise ValueError(f"Invalid run_id: {run_id!r}")
    return swarm_root_for_repo(repo_root) / RUNS_SUBDIR / run_id


def ensure_run_dirs(run_dir: Path) -> None:
    for sub in ["artifacts", "handoffs/outbox", "handoffs/queued", "handoffs/active", "handoffs/completed", "handoffs/failed", "prompts", "worktrees", "runner/opencode/agents"]:
        (run_dir / sub).mkdir(parents=True, exist_ok=True)


def atomic_write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_path = tempfile.mkstemp(dir=str(path.parent), prefix=".tmp-")
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, sort_keys=True)
            f.write("\n")
        os.replace(tmp_path, path)
    finally:
        try:
            Path(tmp_path).unlink(missing_ok=True)
        except Exception:
            pass


def atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_path = tempfile.mkstemp(dir=str(path.parent), prefix=".tmp-")
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
            f.write(text)
        os.replace(tmp_path, path)
    finally:
        try:
            Path(tmp_path).unlink(missing_ok=True)
        except Exception:
            pass


def append_trace(run_dir: Path, event: dict[str, Any]) -> None:
    trace_path = run_dir / "trace.jsonl"
    trace_path.parent.mkdir(parents=True, exist_ok=True)
    line = json.dumps(event, ensure_ascii=False)
    with trace_path.open("a", encoding="utf-8") as f:
        f.write(line + "\n")


def now_ts() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def is_path_contained(base: Path, candidate: Path) -> bool:
    try:
        candidate.resolve().relative_to(base.resolve())
        return True
    except ValueError:
        return False


def validate_artifact_path(run_dir: Path, artifact: str) -> Path:
    # Must be relative, no traversal, stay under run_dir/artifacts or run_dir
    if os.path.isabs(artifact):
        raise ValueError(f"Artifact path must be relative: {artifact!r}")
    if ".." in Path(artifact).parts:
        raise ValueError(f"Artifact path traversal: {artifact!r}")
    # Normalize
    p = (run_dir / artifact).resolve()
    base = run_dir.resolve()
    if not is_path_contained(base, p) and p != base:
        raise ValueError(f"Artifact escape: {artifact!r}")
    return p


def read_json(path: Path) -> Any:
    if not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def write_state(run_dir: Path, state: dict[str, Any]) -> None:
    state = dict(state)
    state["version"] = STATE_VERSION
    state["updated_at"] = now_ts()
    atomic_write_json(run_dir / "state.json", state)
    append_trace(run_dir, {"ts": now_ts(), "kind": "state_changed", "state": state.get("run_state")})


def read_state(run_dir: Path) -> dict[str, Any] | None:
    return read_json(run_dir / "state.json")


def list_runs(repo_root: Path) -> list[Path]:
    runs_root = swarm_root_for_repo(repo_root) / RUNS_SUBDIR
    if not runs_root.is_dir():
        return []
    return sorted([p for p in runs_root.iterdir() if p.is_dir()])


def sanitize_args(args: list[str]) -> list[str]:
    # Redact secrets in args for logging: look for token-like values
    redacted: list[str] = []
    for a in args:
        low = a.lower()
        if any(k in low for k in ["token", "secret", "key", "password"]):
            redacted.append("[REDACTED]")
        else:
            redacted.append(a)
    return redacted
