"""Swarm state machine — run and role states, transitions."""

from __future__ import annotations

from typing import Any

from .models import RoleState, RunState

RUN_TRANSITIONS: dict[RunState, set[RunState]] = {
    RunState.PLANNING: {RunState.AWAITING_PLAN_APPROVAL, RunState.RUNNING, RunState.FAILED, RunState.CANCELLED},
    RunState.AWAITING_PLAN_APPROVAL: {RunState.RUNNING, RunState.CANCELLED, RunState.FAILED},
    RunState.RUNNING: {RunState.AWAITING_HUMAN, RunState.PAUSED, RunState.COMPLETED, RunState.FAILED, RunState.CANCELLED, RunState.BUDGET_EXHAUSTED},
    RunState.AWAITING_HUMAN: {RunState.RUNNING, RunState.PAUSED, RunState.COMPLETED, RunState.FAILED, RunState.CANCELLED},
    RunState.PAUSED: {RunState.RUNNING, RunState.CANCELLED, RunState.FAILED},
    RunState.COMPLETED: {RunState.CLEANUP_PENDING},
    RunState.FAILED: {RunState.CLEANUP_PENDING, RunState.RUNNING},
    RunState.CANCELLED: {RunState.CLEANUP_PENDING},
    RunState.BUDGET_EXHAUSTED: {RunState.RUNNING, RunState.CANCELLED, RunState.CLEANUP_PENDING},
    RunState.CLEANUP_PENDING: set(),
}

ROLE_TRANSITIONS: dict[RoleState, set[RoleState]] = {
    RoleState.INACTIVE: {RoleState.STARTING, RoleState.IDLE},
    RoleState.STARTING: {RoleState.IDLE, RoleState.WORKING, RoleState.FAILED, RoleState.STOPPED},
    RoleState.IDLE: {RoleState.READY, RoleState.WORKING, RoleState.STOPPED, RoleState.FAILED},
    RoleState.READY: {RoleState.WORKING, RoleState.BLOCKED, RoleState.COMPLETED, RoleState.FAILED, RoleState.STOPPED},
    RoleState.WORKING: {RoleState.AWAITING_HANDOFF, RoleState.BLOCKED, RoleState.COMPLETED, RoleState.FAILED, RoleState.STOPPED, RoleState.IDLE},
    RoleState.BLOCKED: {RoleState.WORKING, RoleState.FAILED, RoleState.STOPPED},
    RoleState.AWAITING_HANDOFF: {RoleState.WORKING, RoleState.COMPLETED, RoleState.FAILED, RoleState.STOPPED},
    RoleState.COMPLETED: {RoleState.WORKING, RoleState.STOPPED},
    RoleState.FAILED: {RoleState.STARTING, RoleState.STOPPED},
    RoleState.STOPPED: {RoleState.STARTING},
}


def can_transition_run(from_state: str, to_state: str) -> bool:
    try:
        f = RunState(from_state)
        t = RunState(to_state)
    except ValueError:
        return False
    return t in RUN_TRANSITIONS.get(f, set())


def can_transition_role(from_state: str, to_state: str) -> bool:
    try:
        f = RoleState(from_state)
        t = RoleState(to_state)
    except ValueError:
        return False
    return t in ROLE_TRANSITIONS.get(f, set())


def initial_run_state(recipe_name: str, requires_plan_approval: bool) -> str:
    if recipe_name in ("team", "full") and requires_plan_approval:
        return RunState.AWAITING_PLAN_APPROVAL.value
    if recipe_name in ("team", "full"):
        return RunState.PLANNING.value
    return RunState.RUNNING.value
