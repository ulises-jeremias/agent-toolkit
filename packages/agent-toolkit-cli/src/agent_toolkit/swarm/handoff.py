"""Handoff protocol — durable filesystem queue with validation."""

from __future__ import annotations

import hashlib
import json
import os
import re
import tempfile
import time
from pathlib import Path
from typing import Any

from .models import HANDOFF_VERSION
from .store import atomic_write_text, is_path_contained, now_ts, validate_artifact_path

ALLOWED_TYPES = {"artifact", "commit", "feedback", "decision_request"}
SHA_RE = re.compile(r"^[0-9a-f]{40}$")
ROLE_RE = re.compile(r"^[a-z][a-z0-9_-]{1,31}$")


def handoff_id_for(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, sort_keys=True)
    return hashlib.sha256(raw.encode()).hexdigest()[:16]


def validate_handoff(data: dict[str, Any], run_dir: Path, roles: set[str]) -> list[str]:
    errors: list[str] = []
    if data.get("version") != HANDOFF_VERSION:
        errors.append(f"version must be {HANDOFF_VERSION}")
    htype = data.get("type")
    if htype not in ALLOWED_TYPES:
        errors.append(f"type must be one of {ALLOWED_TYPES}, got {htype!r}")
    frm = data.get("from")
    to = data.get("to")
    if not isinstance(frm, str) or not ROLE_RE.match(frm):
        errors.append(f"from invalid: {frm!r}")
    elif frm not in roles and frm != "human":
        errors.append(f"unknown from role: {frm!r}")
    if not isinstance(to, str) or (not ROLE_RE.match(to) and to != "human"):
        errors.append(f"to invalid: {to!r}")
    elif to not in roles and to != "human":
        errors.append(f"unknown to role: {to!r}")
    prio = data.get("priority")
    if not isinstance(prio, int) or not (0 <= prio <= 100):
        errors.append("priority must be int 0..100")
    artifact = data.get("artifact")
    if artifact is not None:
        if not isinstance(artifact, str):
            errors.append("artifact must be string")
        else:
            try:
                p = validate_artifact_path(run_dir, artifact)
                # ensure stays under run_dir, no traversal — already checked
                if artifact.startswith("/") or ".." in artifact:
                    errors.append("artifact traversal")
            except ValueError as e:
                errors.append(str(e))
            # size limit check (1 MB default artifact limit later)
            if artifact and len(artifact) > 512:
                errors.append("artifact path too long")
    if htype == "commit":
        commit = data.get("commit")
        branch = data.get("branch")
        if not isinstance(commit, str) or not SHA_RE.match(commit.lower()):
            errors.append("commit must be 40 hex chars")
        if not isinstance(branch, str) or not branch:
            errors.append("branch required for commit handoff")
        elif ".." in branch or branch.startswith("/"):
            errors.append("branch traversal")
    # blocking check for feedback
    if htype == "feedback":
        if "blocking" in data and not isinstance(data["blocking"], bool):
            errors.append("blocking must be bool")
    return errors


def write_handoff_outbox(run_dir: Path, data: dict[str, Any]) -> Path:
    # Atomically write to handoffs/outbox/<id>.json
    hid = data.get("handoff_id") or handoff_id_for(data)
    data = dict(data)
    data["handoff_id"] = hid
    data["created_at"] = now_ts()
    data.setdefault("version", HANDOFF_VERSION)
    outbox = run_dir / "handoffs" / "outbox"
    outbox.mkdir(parents=True, exist_ok=True)
    tmp_fd, tmp_path = tempfile.mkstemp(dir=str(outbox), prefix=".tmp-")
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, sort_keys=True)
        dest = outbox / f"{hid}.json"
        os.replace(tmp_path, dest)
        return dest
    finally:
        try:
            Path(tmp_path).unlink(missing_ok=True)
        except Exception:
            pass


def move_handoff(run_dir: Path, handoff_id: str, from_state: str, to_state: str) -> Path | None:
    src = run_dir / "handoffs" / from_state / f"{handoff_id}.json"
    dst = run_dir / "handoffs" / to_state / f"{handoff_id}.json"
    if not src.is_file():
        return None
    dst.parent.mkdir(parents=True, exist_ok=True)
    src.rename(dst)
    return dst


def list_handoffs(run_dir: Path, state: str) -> list[dict[str, Any]]:
    d = run_dir / "handoffs" / state
    if not d.is_dir():
        return []
    items: list[dict[str, Any]] = []
    for p in sorted(d.glob("*.json")):
        try:
            data = json.loads(p.read_text(encoding="utf-8"))
            items.append(data)
        except Exception:
            continue
    return items


def validate_commit_exists(repo_root: Path, sha: str) -> bool:
    import subprocess
    try:
        res = subprocess.run(["git", "cat-file", "-t", sha], cwd=str(repo_root), capture_output=True, text=True, timeout=5)
        return res.returncode == 0 and "commit" in res.stdout
    except Exception:
        return False


def resolve_sha(repo_root: Path, abbrev: str) -> str | None:
    import subprocess
    # Use git rev-parse to resolve ambiguous abbreviations
    try:
        res = subprocess.run(["git", "rev-parse", "--verify", abbrev + "^{commit}"], cwd=str(repo_root), capture_output=True, text=True, timeout=5)
        if res.returncode != 0:
            return None
        sha = res.stdout.strip()
        if SHA_RE.match(sha):
            # Check ambiguous: rev-parse should fail if ambiguous, but verify
            return sha
        return None
    except Exception:
        return None
