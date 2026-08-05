"""Validate distributions/products.yaml against schemas/products.schema.yaml."""
from __future__ import annotations

import copy
from pathlib import Path
from typing import Any

import pytest

yaml = pytest.importorskip("yaml")
jsonschema = pytest.importorskip("jsonschema")

from jsonschema import ValidationError, validate

REPO_ROOT = Path(__file__).parent.parent
PRODUCTS_PATH = REPO_ROOT / "distributions" / "products.yaml"
PRODUCTS_SCHEMA_PATH = REPO_ROOT / "schemas" / "products.schema.yaml"


def _load_yaml(path: Path) -> dict[str, Any]:
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"{path.name}: expected mapping, got {type(data).__name__}")
    return data


def _load_products_schema() -> dict[str, Any]:
    return _load_yaml(PRODUCTS_SCHEMA_PATH)


def test_products_schema_file_exists():
    assert PRODUCTS_SCHEMA_PATH.is_file()


def test_products_yaml_validates_against_schema():
    """Current product catalog must satisfy products.schema.yaml."""
    schema = _load_products_schema()
    data = _load_yaml(PRODUCTS_PATH)
    validate(instance=data, schema=schema)


def test_broken_product_include_rejected_by_schema():
    """Schema must reject invalid includes (e.g. malformed skill IDs)."""
    schema = _load_products_schema()
    data = _load_yaml(PRODUCTS_PATH)
    broken = copy.deepcopy(data)
    broken["products"][0]["includes"]["skills"] = ["not-a-valid-skill-id"]

    with pytest.raises(ValidationError, match="skills"):
        validate(instance=broken, schema=schema)


def test_product_missing_includes_rejected():
    schema = _load_products_schema()
    data = _load_yaml(PRODUCTS_PATH)
    broken = copy.deepcopy(data)
    del broken["products"][0]["includes"]

    with pytest.raises(ValidationError, match="includes"):
        validate(instance=broken, schema=schema)
