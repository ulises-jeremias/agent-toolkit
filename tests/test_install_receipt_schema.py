"""Validate install receipts against schemas/install-receipt.schema.json (#511)."""

from __future__ import annotations

import copy
import json
from pathlib import Path
from typing import Any

import pytest

jsonschema = pytest.importorskip("jsonschema")

from jsonschema import Draft202012Validator, ValidationError, validate  # noqa: E402

from agent_toolkit.installer.receipt import ArtifactEntry, InstallReceipt  # noqa: E402

REPO_ROOT = Path(__file__).parent.parent
SCHEMA_PATH = REPO_ROOT / "schemas" / "install-receipt.schema.json"


def _load_schema() -> dict[str, Any]:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def _sample_receipt() -> dict[str, Any]:
    r = InstallReceipt.create(
        "agent-toolkit-profiles",
        "cursor",
        "user-home",
        "1.10.0",
        "abc123def456",
    )
    r.artifacts.append(
        ArtifactEntry("/tmp/at-ok/.cursor/rules/assistant.mdc", "deadbeefcafebabe", "created")
    )
    r.config_patches = [{"op": "add", "path": "/toolkit", "value": True}]
    return r.to_dict()


def test_install_receipt_schema_file_exists():
    assert SCHEMA_PATH.is_file()


def test_python_receipt_to_dict_validates():
    schema = _load_schema()
    data = _sample_receipt()
    validate(instance=data, schema=schema)


def test_schema_rejects_nonempty_secrets():
    schema = _load_schema()
    data = _sample_receipt()
    data["secrets"] = ["leak"]
    with pytest.raises(ValidationError, match=r"secrets|maxItems"):
        validate(instance=data, schema=schema)


def test_schema_rejects_path_escape():
    schema = _load_schema()
    data = _sample_receipt()
    data["artifacts"][0]["path"] = "../../etc/passwd"
    with pytest.raises(ValidationError):
        validate(instance=data, schema=schema)


def test_schema_rejects_bad_ownership():
    schema = _load_schema()
    data = _sample_receipt()
    data["artifacts"][0]["ownership"] = "owned"
    with pytest.raises(ValidationError, match="ownership|created|merged"):
        validate(instance=data, schema=schema)


def test_schema_rejects_wrong_schema_version():
    schema = _load_schema()
    data = _sample_receipt()
    data["schemaVersion"] = 2
    with pytest.raises(ValidationError):
        validate(instance=data, schema=schema)


def test_schema_rejects_missing_required():
    schema = _load_schema()
    data = _sample_receipt()
    broken = copy.deepcopy(data)
    del broken["product"]
    with pytest.raises(ValidationError, match="product"):
        validate(instance=broken, schema=schema)


def test_draft202012_validator_compiles():
    schema = _load_schema()
    Draft202012Validator.check_schema(schema)
