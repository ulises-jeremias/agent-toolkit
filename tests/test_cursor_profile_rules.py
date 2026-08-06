"""Certification: Cursor profile rules (.mdc) match official frontmatter contract."""

from __future__ import annotations

import re
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
RULES_DIR = REPO_ROOT / "profiles" / "cursor" / "rules"


@pytest.fixture(scope="module")
def rule_files() -> list[Path]:
    if not RULES_DIR.is_dir():
        pytest.skip("profiles/cursor/rules not present")
    files = sorted(RULES_DIR.glob("*.mdc"))
    if not files:
        pytest.skip("no .mdc rule files")
    return files


def test_rules_use_mdc_extension(rule_files: list[Path]) -> None:
    for path in rule_files:
        assert path.suffix == ".mdc", f"Cursor rules must use .mdc: {path}"


def test_rules_have_yaml_frontmatter(rule_files: list[Path]) -> None:
    for path in rule_files:
        text = path.read_text(encoding="utf-8")
        assert text.startswith("---\n"), f"Missing frontmatter opener in {path.name}"
        assert "\n---\n" in text[4:], f"Missing frontmatter closer in {path.name}"


def test_rules_frontmatter_has_description(rule_files: list[Path]) -> None:
    for path in rule_files:
        text = path.read_text(encoding="utf-8")
        fm = text.split("\n---\n", 1)[0]
        assert re.search(r"^description:\s*.+", fm, re.M), (
            f"Missing description in {path.name} frontmatter"
        )


def test_rules_frontmatter_has_always_apply(rule_files: list[Path]) -> None:
    for path in rule_files:
        text = path.read_text(encoding="utf-8")
        fm = text.split("\n---\n", 1)[0]
        assert re.search(r"^alwaysApply:\s*(true|false)\s*$", fm, re.M), (
            f"Missing alwaysApply in {path.name} frontmatter"
        )


def test_plugin_compile_does_not_emit_mdc_in_bundle(tmp_path) -> None:
    """Rules are a profile surface — plugin bundle must not silently include .mdc files."""
    pytest.importorskip("yaml")
    from agent_toolkit.compiler.loader import load_graph
    from agent_toolkit.compiler.targets.cursor import CursorAdapter

    graph = load_graph(REPO_ROOT)
    adapter = CursorAdapter(tmp_path / "plugins", REPO_ROOT)
    product = graph.products["agent-toolkit-core"]
    adapter.compile(graph, product)

    mdc_files = list((adapter.output_root / product.id).rglob("*.mdc"))
    assert mdc_files == [], f"Plugin bundle must not emit .mdc rules: {mdc_files}"
