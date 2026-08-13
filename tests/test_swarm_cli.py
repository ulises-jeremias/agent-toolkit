"""Swarm CLI integration tests — offline, using tmp git repos and fake binaries."""

import contextlib
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path


def run_swarm(args, cwd, extra_env=None):
    env = os.environ.copy()
    if extra_env:
        env.update(extra_env)
    # Use uv run --project — resolve repo root dynamically for CI portability
    repo_root = Path(__file__).resolve().parents[1]
    cmd = [
        "uv",
        "run",
        "--project",
        str(repo_root),
        "agent-toolkit-py",
        "swarm",
    ] + args
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


def _run_id(repo: Path) -> str | None:
    """Return the most-recent run_id created under `repo`, or None."""
    runs = repo / ".agent-toolkit" / "swarm" / "runs"
    try:
        return next(runs.iterdir()).name
    except (StopIteration, FileNotFoundError):
        return None


@contextlib.contextmanager
def cleanup_run(repo: Path):
    """Ensure `swarm cleanup` runs after a `start` so tests never leak
    tmux servers / socket files under /tmp/tmux-<uid>/.

    The cleanup is best-effort: failures are swallowed because the tmux
    server may already be gone (e.g. previous assertion error aborted the
    test before reaching finally). The purpose is to tear down whatever
    survived, not to assert correctness of cleanup here.
    """
    yield
    run_id = _run_id(repo)
    if not run_id:
        return
    with contextlib.suppress(Exception):
        run_swarm(["cleanup", run_id, "--force"], repo)
    # If the swarm CLI itself could not remove the tmux socket (e.g. the run was
    # aborted before state.json captured the run_id, or `cleanup` errored on
    # dirty worktrees), kill the per-run tmux server directly so tests do not
    # accumulate /tmp/tmux-<uid>/agent-toolkit-swarm-* socket files.
    sock = f"agent-toolkit-swarm-{run_id}"
    with contextlib.suppress(Exception):
        subprocess.run(
            ["tmux", "-L", sock, "kill-server"],
            capture_output=True,
            timeout=5,
        )
    for base in ("/tmp", os.environ.get("TMPDIR", "/tmp")):
        cand = Path(base) / f"tmux-{os.getuid()}" / sock
        if cand.is_socket():
            with contextlib.suppress(FileNotFoundError):
                cand.unlink()


def test_swarm_plan_pair():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        res = run_swarm(
            ["plan", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Test task"], repo
        )
        assert res.returncode == 0, res.stderr
        assert "Swarm plan" in res.stdout


def test_swarm_start_pair_creates_worktree():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        with cleanup_run(repo):
            res = run_swarm(
                [
                    "start",
                    "--recipe",
                    "pair",
                    "--ui",
                    "tmux",
                    "--runner",
                    "skeleton",
                    "Implement feature",
                ],
                repo,
            )
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
        with cleanup_run(repo):
            res = run_swarm(
                ["start", "--recipe", "team", "--ui", "tmux", "--runner", "skeleton", "Feature X"],
                repo,
            )
            assert res.returncode == 0, res.stderr
            run_id = (repo / ".agent-toolkit" / "swarm" / "runs").iterdir().__next__().name
            status = run_swarm(["status", run_id, "--json"], repo)
            data = json.loads(status.stdout)
            assert data["state"]["run_state"] == "awaiting_plan_approval"


def test_swarm_promote_pair_to_team():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        with cleanup_run(repo):
            run_swarm(
                ["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo
            )
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
        with cleanup_run(repo):
            run_swarm(
                ["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo
            )
            run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
            # create artifact handoff
            res = run_swarm(
                [
                    "handoff",
                    "create",
                    "--type",
                    "artifact",
                    "--from",
                    "implementer",
                    "--to",
                    "reviewer",
                    "--artifact",
                    "artifacts/task-contract.md",
                    "--run-id",
                    run_id,
                ],
                repo,
            )
            assert res.returncode == 0, res.stderr
            # task next for reviewer should succeed
            res2 = run_swarm(
                ["task", "next", "--role", "reviewer", "--run-id", run_id, "--json"], repo
            )
            assert res2.returncode == 0, res2.stderr
            data = json.loads(res2.stdout)
            assert data["type"] == "artifact"


def test_swarm_cleanup_dirty_refuses():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        with cleanup_run(repo):
            run_swarm(
                ["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo
            )
            run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
            run_dir = repo / ".agent-toolkit" / "swarm" / "runs" / run_id
            wt = run_dir / "worktrees" / "implementer"
            # make dirty
            (wt / "dirty.txt").write_text("dirty")
            subprocess.run(
                ["git", "status", "--porcelain"], cwd=str(wt), capture_output=True, text=True
            )
            # Now cleanup without force should fail
            res = run_swarm(["cleanup", run_id], repo)
            assert res.returncode != 0
            assert (
                "uncommitted changes" in (res.stdout + res.stderr).lower()
                or "dirty" in (res.stdout + res.stderr).lower()
                or "not remove" in (res.stdout + res.stderr).lower()
            )


def test_swarm_herdr_explicit_missing_fails():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        # Simulate herdr missing by PATH override (create fake PATH without herdr)
        tempfile.mkdtemp()
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
        res = run_swarm(
            ["start", "--recipe", "pair", "--ui", "herdr", "--runner", "skeleton", "Task"],
            repo,
            extra_env=env,
        )
        # Should fail with actionable error
        assert res.returncode != 0
        assert "Herdr was explicitly requested" in (res.stdout + res.stderr)


def test_swarm_auto_fallback_to_tmux():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        with cleanup_run(repo):
            # auto should succeed when a backend is available; on CI macos without tmux/herdr it correctly reports no backend
            res = run_swarm(
                ["start", "--recipe", "pair", "--ui", "auto", "--runner", "skeleton", "Task"], repo
            )
            if res.returncode != 0 and "No interactive backend available" in (
                res.stdout + res.stderr
            ):
                import pytest

                pytest.skip(
                    "No herdr/tmux available on this runner — auto correctly reports no backend"
                )
            assert res.returncode == 0, res.stderr + res.stdout
            assert "swarm run created" in res.stdout.lower()


def test_swarm_status_json_and_artifacts():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        with cleanup_run(repo):
            run_swarm(
                ["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo
            )
            run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
            res = run_swarm(["status", run_id, "--json"], repo)
            assert res.returncode == 0
            data = json.loads(res.stdout)
            assert "state" in data
            res2 = run_swarm(["artifacts", run_id, "--json"], repo)
            assert res2.returncode == 0
            arts = json.loads(res2.stdout)
            assert any(a["name"] == "task-contract.md" for a in arts)


# budget_exhausted resume / report path — see docs/SWARM_ARCHITECTURE.md


def test_swarm_status_surfaces_budget_exhausted():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        with cleanup_run(repo):
            run_swarm(
                ["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo
            )
            run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
            run_dir = repo / ".agent-toolkit" / "swarm" / "runs" / run_id
            state = json.loads((run_dir / "state.json").read_text())
            state["run_state"] = "budget_exhausted"
            (run_dir / "state.json").write_text(json.dumps(state))
            res = run_swarm(["status", run_id, "--json"], repo)
            assert res.returncode == 0, res.stderr
            data = json.loads(res.stdout)
            assert data["state"]["run_state"] == "budget_exhausted"


def test_swarm_resume_from_budget_exhausted():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        with cleanup_run(repo):
            run_swarm(
                ["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo
            )
            run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
            run_dir = repo / ".agent-toolkit" / "swarm" / "runs" / run_id
            state = json.loads((run_dir / "state.json").read_text())
            state["run_state"] = "budget_exhausted"
            (run_dir / "state.json").write_text(json.dumps(state))
            res = run_swarm(["resume", run_id], repo)
            assert res.returncode == 0, res.stderr
            assert "running" in res.stdout
            state2 = json.loads((run_dir / "state.json").read_text())
            assert state2["run_state"] == "running"


def test_swarm_report_on_budget_exhausted():
    with tempfile.TemporaryDirectory() as td:
        repo = init_repo(Path(td))
        with cleanup_run(repo):
            run_swarm(
                ["start", "--recipe", "pair", "--ui", "tmux", "--runner", "skeleton", "Task"], repo
            )
            run_id = next((repo / ".agent-toolkit" / "swarm" / "runs").iterdir()).name
            run_dir = repo / ".agent-toolkit" / "swarm" / "runs" / run_id
            state = json.loads((run_dir / "state.json").read_text())
            state["run_state"] = "budget_exhausted"
            (run_dir / "state.json").write_text(json.dumps(state))
            res = run_swarm(["report", run_id], repo)
            output = res.stdout + res.stderr
            assert (
                "No final-report.md yet" in output
                or "budget_exhausted" in output
                or "partial" in output.lower()
            )
