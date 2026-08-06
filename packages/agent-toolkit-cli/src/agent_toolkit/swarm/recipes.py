"""Swarm recipes — built-in pair/team/full, YAML loading, validation."""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from .models import API_VERSION, KIND, RolePolicy

BUILTIN_RECIPES: dict[str, dict[str, Any]] = {
    "pair": {
        "apiVersion": API_VERSION,
        "kind": KIND,
        "metadata": {"name": "pair", "description": "Two-role implementer + reviewer/integrator workflow"},
        "spec": {
            "ui": "auto",
            "transport": "filesystem",
            "workspace": {"strategy": "worktree-per-writer", "base_ref": "HEAD", "integration_branch": True, "keep_on_failure": True},
            "execution": {"max_concurrency": 2, "lazy_start": True, "resumable": True, "max_role_round_trips": 2},
            "budget": {"max_total_tokens": 900000, "max_cost_usd": 4.00, "max_wall_seconds": 7200},
            "gates": {"require_plan_approval": False, "require_final_approval": True, "allow_direct_base_merge": False, "allow_push": False},
            "roles": {
                "implementer": {
                    "persona": "tdd-guide",
                    "policy": "writer",
                    "model_profile": "coding",
                    "worktree": "implementer",
                    "consumes": ["task-contract"],
                    "produces": ["commit", "implementation-report"],
                    "receive_mode": "task",
                    "skills": ["tdd"],
                },
                "reviewer": {
                    "persona": "code-reviewer",
                    "policy": "reviewer-writer",
                    "model_profile": "review",
                    "worktree": "reviewer",
                    "consumes": ["commit"],
                    "produces": ["feedback", "reviewed-commit"],
                    "receive_mode": "task",
                    "skills": ["code-review"],
                },
                "integrator": {
                    "persona": "architect",
                    "policy": "integrator",
                    "model_profile": "architecture",
                    "worktree": "integration",
                    "consumes": ["reviewed-commit"],
                    "produces": ["final-candidate", "final-report"],
                    "receive_mode": "batch",
                    "skills": [],
                },
            },
        },
    },
    "team": {
        "apiVersion": API_VERSION,
        "kind": KIND,
        "metadata": {"name": "team", "description": "Four-role planner → implementer → reviewer → architect workflow"},
        "spec": {
            "ui": "auto",
            "transport": "filesystem",
            "workspace": {"strategy": "worktree-per-writer", "base_ref": "HEAD", "integration_branch": True, "keep_on_failure": True},
            "execution": {"max_concurrency": 2, "lazy_start": True, "resumable": True, "max_role_round_trips": 2},
            "budget": {"max_total_tokens": 900000, "max_cost_usd": 4.00, "max_wall_seconds": 7200},
            "gates": {"require_plan_approval": True, "require_final_approval": True, "allow_direct_base_merge": False, "allow_push": False},
            "roles": {
                "planner": {
                    "persona": "planner",
                    "policy": "read-only",
                    "model_profile": "planning",
                    "worktree": None,
                    "consumes": [],
                    "produces": ["task-contract", "acceptance-criteria", "risk-assessment"],
                    "receive_mode": "task",
                    "skills": ["planning"],
                },
                "implementer": {
                    "persona": "tdd-guide",
                    "policy": "writer",
                    "model_profile": "coding",
                    "worktree": "implementer",
                    "consumes": ["task-contract"],
                    "produces": ["commit", "implementation-report"],
                    "receive_mode": "task",
                    "skills": ["tdd"],
                },
                "reviewer": {
                    "persona": "code-reviewer",
                    "policy": "reviewer-writer",
                    "model_profile": "review",
                    "worktree": "reviewer",
                    "consumes": ["commit"],
                    "produces": ["feedback", "reviewed-commit"],
                    "receive_mode": "task",
                    "skills": ["code-review"],
                },
                "architect": {
                    "persona": "architect",
                    "policy": "integrator",
                    "model_profile": "architecture",
                    "worktree": "integration",
                    "consumes": ["reviewed-commit"],
                    "produces": ["final-candidate", "final-report"],
                    "receive_mode": "batch",
                    "skills": ["architecture"],
                },
            },
        },
    },
    "full": {
        "apiVersion": API_VERSION,
        "kind": KIND,
        "metadata": {"name": "full", "description": "Six-role planner → implementer → refactorer → architect → hardener → qa workflow"},
        "spec": {
            "ui": "auto",
            "transport": "filesystem",
            "workspace": {"strategy": "worktree-per-writer", "base_ref": "HEAD", "integration_branch": True, "keep_on_failure": True},
            "execution": {"max_concurrency": 2, "lazy_start": True, "resumable": True, "max_role_round_trips": 2},
            "budget": {"max_total_tokens": 1200000, "max_cost_usd": 8.00, "max_wall_seconds": 10800},
            "gates": {"require_plan_approval": True, "require_final_approval": True, "allow_direct_base_merge": False, "allow_push": False},
            "roles": {
                "planner": {"persona": "planner", "policy": "read-only", "model_profile": "planning", "worktree": None, "consumes": [], "produces": ["task-contract"], "receive_mode": "task", "skills": ["planning"]},
                "implementer": {"persona": "tdd-guide", "policy": "writer", "model_profile": "coding", "worktree": "implementer", "consumes": ["task-contract"], "produces": ["commit"], "receive_mode": "task", "skills": []},
                "refactorer": {"persona": "refactor-cleaner", "policy": "writer", "model_profile": "review", "worktree": "reviewer", "consumes": ["commit"], "produces": ["refactored-commit"], "receive_mode": "task", "skills": []},
                "architect": {"persona": "architect", "policy": "integrator", "model_profile": "architecture", "worktree": "integration", "consumes": ["refactored-commit"], "produces": ["integrated-commit"], "receive_mode": "batch", "skills": []},
                "hardener": {"persona": "security-reviewer", "policy": "reviewer-writer", "model_profile": "hardening", "worktree": "hardener", "consumes": ["integrated-commit"], "produces": ["hardened-commit"], "receive_mode": "task", "skills": []},
                "qa": {"persona": "e2e-runner", "policy": "reviewer-writer", "model_profile": "qa", "worktree": "qa", "consumes": ["hardened-commit"], "produces": ["qa-report", "final-report"], "receive_mode": "task", "skills": []},
            },
        },
    },
}

VALID_POLICIES = {p.value for p in RolePolicy}


def list_recipes() -> list[str]:
    return sorted(BUILTIN_RECIPES.keys())


def get_recipe(name: str) -> dict[str, Any] | None:
    return BUILTIN_RECIPES.get(name)


def validate_recipe(data: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if data.get("apiVersion") != API_VERSION:
        errors.append(f"apiVersion must be {API_VERSION!r}")
    if data.get("kind") != KIND:
        errors.append(f"kind must be {KIND!r}")
    meta = data.get("metadata") or {}
    if not meta.get("name"):
        errors.append("metadata.name required")
    spec = data.get("spec")
    if not isinstance(spec, dict):
        errors.append("spec must be object")
        return errors
    roles = spec.get("roles")
    if not isinstance(roles, dict) or not roles:
        errors.append("spec.roles must be non-empty object")
    else:
        for rname, rdef in roles.items():
            if not re.match(r"^[a-z][a-z0-9_-]{1,31}$", rname):
                errors.append(f"invalid role name {rname!r}")
            if not isinstance(rdef, dict):
                errors.append(f"role {rname} must be object")
                continue
            policy = rdef.get("policy")
            if policy not in VALID_POLICIES:
                errors.append(f"role {rname} policy {policy!r} invalid, must be one of {VALID_POLICIES}")
            if rdef.get("receive_mode") not in ("task", "batch", None):
                errors.append(f"role {rname} receive_mode must be task|batch")
    return errors


def load_recipe_file(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    try:
        import yaml  # type: ignore
        data = yaml.safe_load(text)
        if not isinstance(data, dict):
            raise ValueError("YAML top level must be mapping")
        return data
    except ImportError:
        # minimal fallback: only JSON
        import json
        return json.loads(text)
