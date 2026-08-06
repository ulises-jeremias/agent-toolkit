"""Tests for declarative compile-target registry."""

from __future__ import annotations

from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

from agent_toolkit.compiler.target_registry import (  # noqa: E402
    adapter_import_path,
    load_target_registry,
    registry_by_id,
    resolve_adapter_class,
    resolve_target_id,
    target_ids_for,
)

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_registry_file_exists() -> None:
    path = REPO_ROOT / "capabilities" / "targets" / "registry.yaml"
    assert path.is_file()


def test_loads_ten_build_targets() -> None:
    registry = load_target_registry(REPO_ROOT)
    build_ids = target_ids_for("build", registry)
    assert len(build_ids) == 10
    assert "claude-code" in build_ids
    assert "codex" in build_ids


def test_diff_defaults_to_three_targets() -> None:
    registry = load_target_registry(REPO_ROOT)
    diff_ids = target_ids_for("diff", registry)
    assert diff_ids == ["claude-code", "cursor", "opencode"]


def test_release_includes_adapter_paths() -> None:
    registry = load_target_registry(REPO_ROOT)
    release_ids = target_ids_for("release", registry)
    by_id = registry_by_id(registry)
    assert len(release_ids) == len(set(release_ids))
    assert adapter_import_path(by_id["gemini-cli"]).endswith("GeminiCLIAdapter")


def test_aliases_resolve_to_canonical_id() -> None:
    registry = load_target_registry(REPO_ROOT)
    assert resolve_target_id("gemini", registry) == "gemini-cli"
    assert resolve_target_id("copilot", registry) == "copilot-cli"


def test_resolve_adapter_class_for_alias() -> None:
    cls = resolve_adapter_class("gemini", REPO_ROOT)
    assert cls is not None
    assert cls.__name__ == "GeminiCLIAdapter"


def test_registry_yaml_is_valid() -> None:
    path = REPO_ROOT / "capabilities" / "targets" / "registry.yaml"
    data = yaml.safe_load(path.read_text(encoding="utf-8"))
    assert data["version"] == 1
    ids = [entry["id"] for entry in data["targets"]]
    assert len(ids) == len(set(ids))
