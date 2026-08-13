"""Worktree and branch management."""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path
from typing import Any

ROLE_RE = re.compile(r"^[a-z][a-z0-9_-]{1,31}$")


def branch_for_run_role(run_id: str, role: str) -> str:
    if not ROLE_RE.match(role):
        raise ValueError(f"Invalid role: {role!r}")
    # Safe short prefix if too long (git branch limit ~ 255, filesystem limits)
    safe_run = re.sub(r"[^a-zA-Z0-9._-]", "-", run_id)[:32]
    return f"agent-toolkit-swarm/{safe_run}/{role}"


def worktree_path_for(run_dir: Path, role: str) -> Path:
    if not ROLE_RE.match(role):
        raise ValueError(f"Invalid role: {role!r}")
    return run_dir / "worktrees" / role


def git_run(args: list[str], cwd: Path, check: bool = True) -> subprocess.CompletedProcess:
    # Safe arg handling — no shell
    return subprocess.run(["git"] + args, cwd=str(cwd), capture_output=True, text=True, check=False)


def create_worktree(
    repo_root: Path, run_dir: Path, role: str, run_id: str, base_ref: str = "HEAD"
) -> dict[str, Any]:
    branch = branch_for_run_role(run_id, role)
    wt_path = worktree_path_for(run_dir, role)
    if wt_path.exists():
        return {"branch": branch, "path": str(wt_path), "exists": True}
    # Create branch if not exists
    res = git_run(["rev-parse", "--verify", branch], cwd=repo_root, check=False)
    if res.returncode != 0:
        # create branch from base_ref
        cre = git_run(["branch", branch, base_ref], cwd=repo_root, check=False)
        if cre.returncode != 0:
            raise RuntimeError(f"Failed to create branch {branch}: {cre.stderr}")
    # Create worktree
    wt_path.parent.mkdir(parents=True, exist_ok=True)
    res2 = git_run(["worktree", "add", str(wt_path), branch], cwd=repo_root, check=False)
    if res2.returncode != 0:
        raise RuntimeError(f"Failed to create worktree {wt_path}: {res2.stderr}")
    return {"branch": branch, "path": str(wt_path), "exists": False}


def remove_worktree(repo_root: Path, wt_path: Path, force: bool = False) -> bool:
    if not wt_path.exists():
        return False
    # Check dirty
    res = git_run(["status", "--porcelain"], cwd=wt_path, check=False)
    if res.returncode == 0 and res.stdout.strip() and not force:
        raise RuntimeError(f"Worktree dirty, refusing removal without --force: {wt_path}")
    # Remove worktree
    git_run(
        ["worktree", "remove", str(wt_path), "--force" if force else str(wt_path)],
        cwd=repo_root,
        check=False,
    )
    # Clean up directory if still exists
    if wt_path.exists():
        shutil.rmtree(wt_path, ignore_errors=True)
    return True


def is_worktree_dirty(wt_path: Path) -> bool:
    res = git_run(["status", "--porcelain"], cwd=wt_path, check=False)
    return bool(res.stdout.strip())


def validate_worktree_ownership(run_dir: Path, wt_path: Path) -> bool:
    # Check that wt_path is under run_dir/worktrees and owned
    try:
        wt_path.resolve().relative_to((run_dir / "worktrees").resolve())
        return True
    except ValueError:
        return False


def list_worktrees(repo_root: Path) -> list[dict[str, Any]]:
    res = git_run(["worktree", "list", "--porcelain"], cwd=repo_root, check=False)
    if res.returncode != 0:
        return []
    items: list[dict[str, Any]] = []
    cur: dict[str, Any] = {}
    for line in res.stdout.splitlines():
        if line.startswith("worktree "):
            if cur:
                items.append(cur)
            cur = {"worktree": line.split(" ", 1)[1]}
        elif line.startswith("branch "):
            cur["branch"] = line.split(" ", 1)[1]
        elif line.startswith("HEAD "):
            cur["head"] = line.split(" ", 1)[1]
    if cur:
        items.append(cur)
    return items
