"""The published Goal evidence JSON Schema matches the native receipt contract."""

import json
from pathlib import Path

import pytest

jsonschema = pytest.importorskip("jsonschema")

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = json.loads((ROOT / "schemas" / "goal-evidence-v1.schema.json").read_text())


def valid_receipt(mode: str) -> dict[str, object]:
    return {
        "task_id": "evaluation",
        "attempt": 1,
        "repository": "veasel-labs/veasel",
        "base_sha": "a" * 40,
        "candidate_sha": "b" * 40,
        "mode": mode,
        "environment": "synthetic-24-worker-evaluation",
        "verifier_identity": "fixture-validator",
        "verifier_version": "v1",
        "result": "pass",
        "digests": ["sha256:" + "c" * 64],
    }


@pytest.mark.parametrize("mode", ["fixture", "hermetic", "real"])
def test_goal_evidence_schema_accepts_declared_execution_modes(mode: str) -> None:
    jsonschema.Draft202012Validator(SCHEMA).validate(valid_receipt(mode))


def test_goal_evidence_schema_rejects_undeclared_simulation_mode() -> None:
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.Draft202012Validator(SCHEMA).validate(valid_receipt("simulated"))
