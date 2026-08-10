"""CLI contract tests for cmd_inventory and cmd_matrix in agent_toolkit.cli.build."""

# Author: RawNuke
# Copyright (c) 2026 RawNuke. All rights reserved.

from __future__ import annotations

import re
from pathlib import Path

import pytest

import agent_toolkit._paths as paths_mod
from agent_toolkit.cli import build as build_mod

REPO_ROOT = Path(__file__).resolve().parent.parent


@pytest.fixture()
def clone_root(monkeypatch: pytest.MonkeyPatch) -> Path:
    """Resolve the toolkit root inside the repository clone."""
    monkeypatch.setenv("AGENT_TOOLKIT_ROOT", str(REPO_ROOT))
    monkeypatch.setenv("AGENT_TOOLKIT_OFFLINE", "1")
    paths_mod.reset_toolkit_root()
    yield REPO_ROOT
    paths_mod.reset_toolkit_root()


def test_cmd_inventory_prints_header_and_counts(
    clone_root: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """cmd_inventory prints the header and counts, then returns 0."""
    rc = build_mod.cmd_inventory([])
    out = capsys.readouterr().out
    assert rc == 0
    assert "agent-toolkit Inventory" in out
    assert re.search(r"Skills: \d+ across \d+ domains", out)
    assert re.search(r"Agents: \d+", out)
    assert re.search(r"Products: \d+", out)


def test_cmd_inventory_lists_agents_and_products(
    clone_root: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    """cmd_inventory lists agents and products with their counts."""
    rc = build_mod.cmd_inventory([])
    out = capsys.readouterr().out
    assert rc == 0
    assert "Agents: " in out
    assert "Products: " in out
    assert "agent-toolkit-core" in out
    assert re.search(r"skills: \d+  agents: \d+", out)
    assert "✓" in out


def test_cmd_matrix_prints_matrix_content_when_present(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    """cmd_matrix prints the matrix file content when the file exists."""
    matrix = tmp_path / "docs" / "research" / "platform-capability-matrix.md"
    matrix.parent.mkdir(parents=True)
    matrix.write_text("UNIQUE MATRIX CONTENT\nsecond line\n", encoding="utf-8")
    monkeypatch.setattr(build_mod, "_find_repo_root", lambda: tmp_path)
    rc = build_mod.cmd_matrix([])
    out = capsys.readouterr().out
    assert rc == 0
    assert "UNIQUE MATRIX CONTENT" in out
    assert "second line" in out


def test_cmd_matrix_fallback_when_matrix_missing(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    """cmd_matrix prints the fallback message when the matrix file is missing."""
    monkeypatch.setattr(build_mod, "_find_repo_root", lambda: tmp_path)
    rc = build_mod.cmd_matrix([])
    out = capsys.readouterr().out
    assert rc == 0
    assert "Matrix not found." in out
    expected_path = tmp_path / "docs" / "research" / "platform-capability-matrix.md"
    assert str(expected_path) in out
