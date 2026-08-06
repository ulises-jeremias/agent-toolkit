"""README agent persona table must match agents/ directories."""

from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
README = REPO_ROOT / "README.md"
AGENTS_DIR = REPO_ROOT / "agents"


def _readme_agent_names() -> set[str]:
    text = README.read_text(encoding="utf-8")
    section = text.split("## 🤖 Agent Personas", maxsplit=1)[1].split("\n---\n", maxsplit=1)[0]
    return set(re.findall(r"^\| [^|\n]*`([a-z0-9-]+)` \|", section, re.MULTILINE))


def _agent_dir_names() -> set[str]:
    return {path.name for path in AGENTS_DIR.iterdir() if path.is_dir()}


def test_readme_agent_table_matches_agents_dir() -> None:
    readme_names = _readme_agent_names()
    agent_dirs = _agent_dir_names()
    assert readme_names == agent_dirs, (
        f"README/table drift: only in README={sorted(readme_names - agent_dirs)}, "
        f"only in agents/={sorted(agent_dirs - readme_names)}"
    )
