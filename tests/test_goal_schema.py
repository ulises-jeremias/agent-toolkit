"""Portable Goal schemas keep v1 legacy and make v2 permissions explicit."""

import copy
import json
from pathlib import Path

import pytest

jsonschema = pytest.importorskip("jsonschema")

ROOT = Path(__file__).resolve().parents[1]
V1_SCHEMA = json.loads((ROOT / "schemas" / "goal-v1.schema.json").read_text())
V2_SCHEMA = json.loads((ROOT / "schemas" / "goal-v2.schema.json").read_text())


def legacy_goal() -> dict[str, object]:
    return {
        "schema_version": 1,
        "id": "sample-goal",
        "title": "Sample objective",
        "authorized_repositories": [{"owner": "owner", "name": "repo", "path": "/work/repo"}],
        "acceptance_criteria": [{"id": "done", "description": "Done", "verification": "Review"}],
        "deadline": "2026-12-01T00:00:00Z",
        "budget": {"max_attempts": 2, "wall_seconds": 3600, "provider_turns": 4},
        "delivery_mode": "draft",
        "tasks": [
            {
                "id": "docs",
                "title": "Update docs",
                "repository": "owner/repo",
                "base_sha": "a" * 40,
                "paths": ["docs"],
                "recipe": "feature",
                "runner": "local-v",
                "verifier": "independent-review",
            }
        ],
    }


def permission_goal() -> dict[str, object]:
    goal = legacy_goal()
    goal["schema_version"] = 2
    goal["policy_ceiling"] = [
        "repository.read",
        "repository.write",
        "process.execute",
    ]
    task = copy.deepcopy(goal["tasks"][0])
    task["permissions"] = ["repository.read", "repository.write"]
    goal["tasks"] = [task]
    return goal


def test_goal_v1_schema_preserves_legacy_manifests_without_permission_fields() -> None:
    jsonschema.Draft202012Validator(V1_SCHEMA).validate(legacy_goal())


def test_goal_v2_schema_accepts_declared_permissions_and_policy_ceiling() -> None:
    jsonschema.Draft202012Validator(V2_SCHEMA).validate(permission_goal())


@pytest.mark.parametrize(
    "mutate",
    [
        lambda goal: goal.pop("policy_ceiling"),
        lambda goal: goal["tasks"][0].pop("permissions"),
        lambda goal: goal["tasks"][0].update(permissions=["shell.bypass"]),
        lambda goal: goal["policy_ceiling"].append("repository.read"),
        lambda goal: goal["tasks"][0].update(permissions=["repository.write"]),
    ],
)
def test_goal_v2_schema_rejects_missing_or_invalid_permission_contract(mutate) -> None:
    goal = permission_goal()
    mutate(goal)
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.Draft202012Validator(V2_SCHEMA).validate(goal)


def test_goal_v1_schema_rejects_v2_document_instead_of_mislabeling_it() -> None:
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.Draft202012Validator(V1_SCHEMA).validate(permission_goal())


def test_goal_v1_schema_rejects_v2_permissions_after_version_downgrade() -> None:
    downgraded = permission_goal()
    downgraded["schema_version"] = 1
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.Draft202012Validator(V1_SCHEMA).validate(downgraded)
