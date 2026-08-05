"""Malformed frontmatter/registry YAML must surface as errors, not silent defaults."""
from __future__ import annotations

from pathlib import Path

import pytest


from agent_toolkit.compiler.loader import _parse_frontmatter, load_skills
from agent_toolkit.compiler.hook_registry import load_hooks
from agent_toolkit.compiler.mcp_registry import load_registry


def test_parse_frontmatter_reports_invalid_yaml() -> None:
    text = "---\nname: [unclosed\n---\nbody\n"
    fm, body, err = _parse_frontmatter(text)
    assert err is not None
    assert fm == {}
    assert "body" in body


def test_load_skills_skips_invalid_frontmatter(tmp_path: Path) -> None:
    skill_dir = tmp_path / "core" / "broken"
    skill_dir.mkdir(parents=True)
    (skill_dir / "SKILL.md").write_text(
        "---\nname: [broken\n---\n# Broken\n",
        encoding="utf-8",
    )
    skills, errors = load_skills(tmp_path)
    assert "core/broken" not in skills
    assert errors
    assert any("invalid YAML" in e for e in errors)


def test_load_hooks_reports_invalid_yaml(tmp_path: Path) -> None:
    (tmp_path / "bad.yaml").write_text("id: [broken\n", encoding="utf-8")
    hooks, errors = load_hooks(tmp_path)
    assert hooks == {}
    assert errors


def test_load_registry_reports_invalid_yaml(tmp_path: Path) -> None:
    (tmp_path / "bad.yaml").write_text("id: [broken\n", encoding="utf-8")
    providers, errors = load_registry(tmp_path)
    assert providers == {}
    assert errors
