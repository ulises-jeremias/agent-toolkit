"""Swarm CLI integration tests — offline, using tmp git repos and fake binaries."""

import subprocess
import json
import tempfile
from pathlib import Path
import os
import shutil

def run_swarm(args, cwd, extra_env=None):
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    # Use uv run --project
    cmd = ["uv", "run", "--project", "/home/ulisesjcf/.ai-workspace/repos/github.com/ulises-jeremias/agent-toolkit", "agent-toolkit", "swarm"] + args
    res = subprocess.run(cmd, cwd=str(cwd), capture_output=True, text=True, env=env, timeout=15)
    return res

def init_repo(tmpdir: Path) -> Path:
    subprocess.run(["git", "init", "-q"], cwd=str(tmpdir), check=True)
    subprocess.run(["git", "config", "user.email", "test@test.com"], cwd=str(tmpdir), check=True)
    subprocess.run(["git", "config", "user.name", "Test"], cwd=str(tmpdir), check=True)
    (tmpdir / "README.md").write_text("hello\n")
    subprocess.run(["git", "add", "."], cwd=str(tmpdir), check=True)
    subprocess.run(["git", "commit", "-qm", "init"], cwd=str(tmpdir), check=True)
    return tmpdir

def test_swarm_plan_pair():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        res = run_swarm(["plan", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Test task"], repo)
        assert res.returncode == 0, res.stderr
        assert "Swarm plan" in res.stdout

def test_swarm_start_pair_creates_worktree():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        res = run_swarm(["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Implement feature"], repo)
        assert res.returncode == 0, res.stderr + res.stdout
        runs = list((repo / ".agent-toolkit" / "swarm" / "runs").iterdir())
        assert len(runs) == 1
        run_dir = runs[0]
        assert (run_dir / "state.json").is_file()
        assert (run_dir / "trace.jsonl").is_file()
        assert (run_dir / "worktrees" / "implementer").is_dir()

def test_swarm_start_plan_approval_for_team():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        res = run_swarm(["start", "--recipe", "team", "--ui", "tmux", "--runner", "skeleton", "Feature X"], repo)
        assert res.returncode == 0, res.stderr
        run_id = (repo / ".agent-toolkit" / "swarm" / "runs").iterdir().__next__().name
        status = run_swarm(["status", run_id, "--json"], repo)
        data = json.loads(status.stdout)
        assert data["state"]["run_state"] == "awaiting_plan_approval"

def test_swarm_promote_pair_to_team():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        run_swarm(["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo)
        run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
        res = run_swarm(["promote", run_id, "--to", "team"], repo)
        assert res.returncode == 0, res.stderr
        status = run_swarm(["status", run_id, "--json"], repo)
        data = json.loads(status.stdout)
        assert data["state"]["recipe"] == "team"
        assert "planner" in data["state"]["roles"]

def test_swarm_handoff_and_task_next():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        run_swarm(["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo)
        run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
        # create artifact handoff
        res = run_swarm(["handoff", "create", "--type", "artifact", "--from", "implementer", "--to", "reviewer", "--artifact", "artifacts/task-contract.md", "--run-id", run_id], repo)
        assert res.returncode == 0, res.stderr
        # task next for reviewer should succeed
        res2 = run_swarm(["task", "next", "--role", "reviewer", "--run-id", run_id, "--json"], repo)
        assert res2.returncode == 0, res2.stderr
        data = json.loads(res2.stdout)
        assert data["type"] == "artifact"

def test_swarm_cleanup_dirty_refuses():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        run_swarm(["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo)
        run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
        run_dir = repo / ".agent-toolkit" / "swarm" / "runs" / run_id
        wt = run_dir / "worktrees" / "implementer"
        # make dirty
        (wt / "dirty.txt").write_text("dirty")
        sub = subprocess.run(["git", "status", "--porcelain"], cwd=str(wt), capture_output=True, text=True)
        # Now cleanup without force should fail
        res = run_swarm(["cleanup", run_id], repo)
        assert res.returncode != 0
        assert "uncommitted changes" in (res.stdout + res.stderr).lower() or "dirty" in (res.stdout + res.stderr).lower() or "not remove" in (res.stdout+res.stderr).lower()

def test_swarm_herdr_explicit_missing_fails():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        # Simulate herdr missing by PATH override (create fake PATH without herdr)
        fake_path = tempfile.mkdtemp()
        # copy tmux but not herdr
        # For test, set PATH to contain no herdr by using empty dir + original PATH but prepend empty
        # Instead use extra_env to make herdr unavailable via which mock — we create a temp bin with no herdr
        # We'll pass PATH that excludes herdr's dir
        orig_path = os.environ.get("PATH", "")
        # find herdr location and exclude it
        herdr_path = shutil.which("herdr")
        herdr_dir = str(Path(herdr_path).parent) if herdr_path else ""
        new_path = ":".join([p for p in orig_path.split(":") if p != herdr_dir])
        env = {"PATH": new_path}
        res = run_swarm(["start", "--recipe", "pair", "--ui", "herdr", "--runner", "skeleton", "Task"], repo, extra_env=env)
        # Should fail with actionable error
        assert res.returncode != 0
        assert "Herdr was explicitly requested" in (res.stdout + res.stderr)

def test_swarm_auto_fallback_to_tmux():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        # auto should succeed regardless of herdr availability (herdr or tmux)
        res = run_swarm(["start", "--recipe", "pair", "--ui", "auto", "--runner", "skeleton", "Task"], repo)
        assert res.returncode == 0, res.stderr + res.stdout
        assert "swarm run created" in res.stdout.lower()

def test_swarm_status_json_and_artifacts():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        run_swarm(["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo)
        run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
        res = run_swarm(["status", run_id, "--json"], repo)
        assert res.returncode == 0
        data = json.loads(res.stdout)
        assert "state" in data
        res2 = run_swarm(["artifacts", run_id, "--json"], repo)
        assert res2.returncode == 0
        arts = json.loads(res2.stdout)
        assert any(a["name"] == "task-contract.md" for a in arts)
