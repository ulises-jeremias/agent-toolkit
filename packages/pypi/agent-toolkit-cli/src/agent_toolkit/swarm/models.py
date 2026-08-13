"""Swarm domain model — typed dataclasses for orchestration."""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from enum import Enum
from typing import Any

# Valid identifiers: lower kebab or snake, must start with letter
_ROLE_RE = re.compile(r"^[a-z][a-z0-9_-]{1,31}$")
_RUN_ID_RE = re.compile(r"^[a-zA-Z0-9][a-zA-Z0-9._-]{2,64}$")
_BRANCH_SAFE_RE = re.compile(r"^[a-zA-Z0-9/._-]+$")
_SHA_RE = re.compile(r"^[0-9a-f]{40}$")

API_VERSION = "agent-toolkit.dev/v1alpha1"
KIND = "SwarmRecipe"
STATE_VERSION = 1
HANDOFF_VERSION = 1


class RolePolicy(str, Enum):
    READ_ONLY = "read-only"
    WRITER = "writer"
    REVIEWER_WRITER = "reviewer-writer"
    INTEGRATOR = "integrator"


class UIBackend(str, Enum):
    AUTO = "auto"
    HERDR = "herdr"
    TMUX = "tmux"
    HEADLESS = "headless"


class RunnerName(str, Enum):
    OPENCODE = "opencode"
    CLAUDE = "claude"
    CODEX = "codex"
    CURSOR = "cursor"
    COPILOT = "copilot"
    MUSE = "muse"
    SKELETON = "skeleton"


class RunState(str, Enum):
    PLANNING = "planning"
    AWAITING_PLAN_APPROVAL = "awaiting_plan_approval"
    RUNNING = "running"
    AWAITING_HUMAN = "awaiting_human"
    PAUSED = "paused"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"
    BUDGET_EXHAUSTED = "budget_exhausted"
    CLEANUP_PENDING = "cleanup_pending"


class RoleState(str, Enum):
    INACTIVE = "inactive"
    STARTING = "starting"
    IDLE = "idle"
    READY = "ready"
    WORKING = "working"
    BLOCKED = "blocked"
    AWAITING_HANDOFF = "awaiting_handoff"
    COMPLETED = "completed"
    FAILED = "failed"
    STOPPED = "stopped"


def validate_role_name(name: str) -> str:
    if not _ROLE_RE.match(name):
        raise ValueError(f"Invalid role name: {name!r} (must match {_ROLE_RE.pattern})")
    return name


def validate_run_id(run_id: str) -> str:
    if not _RUN_ID_RE.match(run_id):
        raise ValueError(f"Invalid run id: {run_id!r}")
    return run_id


def validate_branch(branch: str) -> str:
    if (
        not _BRANCH_SAFE_RE.match(branch)
        or ".." in branch
        or branch.startswith("/")
        or branch.endswith("/")
    ):
        raise ValueError(f"Invalid branch: {branch!r}")
    return branch


def validate_commit_sha(sha: str) -> str:
    if not _SHA_RE.match(sha.lower()):
        raise ValueError(f"Invalid commit SHA (must be 40 hex chars): {sha!r}")
    return sha.lower()


@dataclass(frozen=True)
class RoleBudget:
    max_tokens: int | None = None
    max_cost_usd: float | None = None
    max_wall_seconds: int | None = None


@dataclass(frozen=True)
class RunBudget:
    max_total_tokens: int | None = None
    max_cost_usd: float | None = None
    max_wall_seconds: int | None = None
    max_concurrency: int = 2
    max_role_round_trips: int = 2
    max_handoffs: int | None = None
    max_artifact_bytes: int | None = None
    per_role: dict[str, RoleBudget] = field(default_factory=dict)


@dataclass(frozen=True)
class ApprovalGate:
    id: str
    description: str
    required: bool = True
    approved: bool = False


@dataclass(frozen=True)
class WorktreeAssignment:
    role: str
    path: str
    branch: str
    owned: bool = True


@dataclass(frozen=True)
class RunnerDefinition:
    name: str
    kind: str
    model: str | None = None
    capabilities: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class ModelProfile:
    name: str
    mapping: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class TaskContract:
    title: str
    body: str
    acceptance: str | None = None


@dataclass(frozen=True)
class Handoff:
    version: int
    type: str
    from_role: str
    to_role: str
    priority: int
    artifact: str | None = None
    commit: str | None = None
    branch: str | None = None
    blocking: bool = False
    handoff_id: str | None = None


@dataclass(frozen=True)
class ArtifactReference:
    path: str
    role: str
    size_bytes: int | None = None


@dataclass(frozen=True)
class CommitReference:
    sha: str
    branch: str


@dataclass(frozen=True)
class RoleAssignment:
    role: str
    persona: str
    policy: RolePolicy
    model_profile: str
    runner: str
    worktree: str | None = None
    consumes: list[str] = field(default_factory=list)
    produces: list[str] = field(default_factory=list)
    receive_mode: str = "task"  # task | batch
    skills: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class SwarmRecipe:
    api_version: str
    kind: str
    name: str
    description: str
    spec: dict[str, Any]

    @property
    def roles(self) -> dict[str, Any]:
        return self.spec.get("roles", {})  # type: ignore


@dataclass(frozen=True)
class SwarmRun:
    run_id: str
    recipe: str
    run_state: RunState
    roles: dict[str, RoleState]
    budget: RunBudget
    ui_backend: UIBackend
    runner: str
    model_profile: str
    created_at: str
    worktrees: list[WorktreeAssignment] = field(default_factory=list)


@dataclass(frozen=True)
class TraceEvent:
    ts: str
    kind: str
    run_id: str
    details: dict[str, Any] = field(default_factory=dict)
