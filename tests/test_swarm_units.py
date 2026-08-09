"""Swarm unit tests — offline, no LLM, no network."""

import json
import tempfile
from pathlib import Path

import pytest

from agent_toolkit.swarm.approvals import default_gates_for_recipe
from agent_toolkit.swarm.budget import check_limits, resolve_budget
from agent_toolkit.swarm.handoff import list_handoffs, validate_handoff, write_handoff_outbox
from agent_toolkit.swarm.models import (
    validate_branch,
    validate_commit_sha,
    validate_role_name,
    validate_run_id,
)
from agent_toolkit.swarm.recipes import get_recipe, list_recipes, validate_recipe
from agent_toolkit.swarm.runner import resolve_model
from agent_toolkit.swarm.state import can_transition_role, can_transition_run
from agent_toolkit.swarm.store import (
    atomic_write_json,
    ensure_run_dirs,
    run_dir_for,
    validate_artifact_path,
)
from agent_toolkit.swarm.worktree import branch_for_run_role


def test_role_validation():
    assert validate_role_name("implementer") == "implementer"
    with pytest.raises(ValueError):
        validate_role_name("../etc")
    with pytest.raises(ValueError):
        validate_role_name("Bad Role!")


def test_run_id_validation():
    assert validate_run_id("20260806T183330Z-abc123") == "20260806T183330Z-abc123"
    with pytest.raises(ValueError):
        validate_run_id("../../etc/passwd")


def test_branch_validation():
    assert validate_branch("agent-toolkit-swarm/run/role") == "agent-toolkit-swarm/run/role"
    with pytest.raises(ValueError):
        validate_branch("../escape")


def test_commit_validation():
    assert validate_commit_sha("a" * 40) == "a" * 40
    with pytest.raises(ValueError):
        validate_commit_sha("abc")


def test_recipes_list():
    assert "pair" in list_recipes()
    assert "team" in list_recipes()
    assert "full" in list_recipes()


def test_recipe_validate_pair():
    r = get_recipe("pair")
    assert r is not None
    errs = validate_recipe(r)
    assert errs == [], f"pair should validate: {errs}"


def test_recipe_invalid():
    errs = validate_recipe(
        {"apiVersion": "wrong", "kind": "SwarmRecipe", "metadata": {}, "spec": {}}
    )
    assert any("apiVersion" in e for e in errs)


def test_state_transitions():
    assert can_transition_run("running", "paused")
    assert not can_transition_run("completed", "running")
    assert can_transition_role("inactive", "starting")
    assert not can_transition_role("inactive", "completed")


def test_branch_generation():
    b = branch_for_run_role("20260806T183330Z-abc123", "implementer")
    assert b == "agent-toolkit-swarm/20260806T183330Z-abc123/implementer"
    with pytest.raises(ValueError):
        branch_for_run_role("run", "bad role!")


def test_artifact_path_containment():
    with tempfile.TemporaryDirectory() as td:
        repo = Path(td)
        run_dir = run_dir_for(repo, "20260806T000000Z-abcdef")
        run_dir.mkdir(parents=True)
        ensure_run_dirs(run_dir)
        # valid
        p = validate_artifact_path(run_dir, "artifacts/task-contract.md")
        assert p.name == "task-contract.md"
        # traversal should fail
        with pytest.raises(ValueError):
            validate_artifact_path(run_dir, "../../etc/passwd")
        with pytest.raises(ValueError):
            validate_artifact_path(run_dir, "/absolute/path")


def test_handoff_validation():
    with tempfile.TemporaryDirectory() as td:
        repo = Path(td)
        run_dir = run_dir_for(repo, "20260806T000000Z-abcdef")
        run_dir.mkdir(parents=True)
        ensure_run_dirs(run_dir)
        roles = {"implementer", "reviewer"}
        data = {
            "version": 1,
            "type": "artifact",
            "from": "implementer",
            "to": "reviewer",
            "priority": 10,
            "artifact": "artifacts/test.md",
        }
        errs = validate_handoff(data, run_dir, roles)
        assert errs == []
        # invalid type
        bad = dict(data, type="bad")
        errs2 = validate_handoff(bad, run_dir, roles)
        assert errs2
        # unknown role
        bad2 = dict(data, **{"from": "ghost"})
        errs3 = validate_handoff(bad2, run_dir, roles)
        assert errs3


def test_handoff_atomic_and_list():
    with tempfile.TemporaryDirectory() as td:
        repo = Path(td)
        run_dir = run_dir_for(repo, "20260806T000000Z-abcdef")
        ensure_run_dirs(run_dir)
        data = {
            "version": 1,
            "type": "artifact",
            "from": "implementer",
            "to": "reviewer",
            "priority": 5,
            "artifact": "artifacts/a.md",
        }
        dest = write_handoff_outbox(run_dir, data)
        assert dest.is_file()
        # list outbox
        items = list_handoffs(run_dir, "outbox")
        assert len(items) == 1


def test_budget_limits():
    b = resolve_budget(
        {"max_total_tokens": 100, "max_cost_usd": 1.0, "max_wall_seconds": 60, "max_concurrency": 2}
    )
    assert b["max_concurrency"] == 2
    violated = check_limits(b, {"total_tokens": 150, "cost_usd": 0.5, "wall_seconds": 10})
    assert "max_total_tokens" in violated


def test_model_profiles():
    m = resolve_model("balanced", "coding")
    assert "/" in m
    m2 = resolve_model("economy", "review")
    assert "/" in m2
    with pytest.raises(ValueError):
        resolve_model("balanced", "coding", override="badmodel")


def test_approvals_default():
    r = get_recipe("pair")
    gates = default_gates_for_recipe(r)
    assert any(g["id"] == "final" for g in gates)
    r2 = get_recipe("team")
    gates2 = default_gates_for_recipe(r2)
    assert any(g["id"] == "plan" for g in gates2)


def test_sanitize_and_secret_redaction():
    from agent_toolkit.swarm.store import sanitize_args

    args = ["--token", "secret123", "normal"]
    redacted = sanitize_args(args)
    assert "[REDACTED]" in redacted


def test_atomic_write_json():
    with tempfile.TemporaryDirectory() as td:
        p = Path(td) / "state.json"
        atomic_write_json(p, {"a": 1})
        assert json.loads(p.read_text())["a"] == 1
        atomic_write_json(p, {"b": 2})
        assert json.loads(p.read_text())["b"] == 2


def test_budget_exhausted_state_transitions():
    assert can_transition_run("running", "budget_exhausted")
    assert can_transition_run("budget_exhausted", "running")
    assert can_transition_run("budget_exhausted", "cancelled")
    assert can_transition_run("budget_exhausted", "cleanup_pending")
    assert not can_transition_run("budget_exhausted", "completed")
    assert not can_transition_run("completed", "budget_exhausted")


def test_budget_tight_limits_detection():
    b = resolve_budget({"max_total_tokens": 10, "max_cost_usd": 0.01, "max_wall_seconds": 5})
    violated = check_limits(b, {"total_tokens": 11, "cost_usd": 0.02, "wall_seconds": 6})
    assert "max_total_tokens" in violated
    assert "max_cost_usd" in violated
    assert "max_wall_seconds" in violated


def test_budget_limits_exact_boundary():
    b = resolve_budget({"max_total_tokens": 100, "max_cost_usd": 1.0, "max_wall_seconds": 60})
    violated_at_limit = check_limits(b, {"total_tokens": 100, "cost_usd": 1.0, "wall_seconds": 60})
    assert "max_total_tokens" in violated_at_limit
    assert "max_cost_usd" in violated_at_limit
    assert "max_wall_seconds" in violated_at_limit
    under = check_limits(b, {"total_tokens": 99, "cost_usd": 0.99, "wall_seconds": 59})
    assert under == []


def test_budget_exhausted_to_running_resume_path():
    assert can_transition_run("budget_exhausted", "running")
