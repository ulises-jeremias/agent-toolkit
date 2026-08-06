"""Tests for agent-toolkit memory review (#226)."""

from __future__ import annotations

from datetime import date, timedelta
from pathlib import Path

from agent_toolkit.cli import memory as memory_mod


def _seed_knowledge(root: Path) -> Path:
    knowledge = root / "knowledge"
    (knowledge / "learnings").mkdir(parents=True)
    (knowledge / "processes").mkdir(parents=True)
    (knowledge / "todos").mkdir(parents=True)
    return knowledge


def test_review_clean_returns_0(tmp_path: Path, capsys):
    knowledge = _seed_knowledge(tmp_path)
    (knowledge / "learnings" / "general.md").write_text(
        "# Learnings\n\n| Date | Learning | Context |\n|------|----------|---------|\n"
        f"| {date.today().isoformat()} | Prefer uv for Python tooling | Session |\n",
        encoding="utf-8",
    )
    assert memory_mod.cmd_review([], knowledge) == 0
    out = capsys.readouterr().out
    assert "no issues found" in out.lower() or "clean" in out.lower()


def test_review_detects_duplicates(tmp_path: Path, capsys):
    knowledge = _seed_knowledge(tmp_path)
    today = date.today().isoformat()
    (knowledge / "learnings" / "general.md").write_text(
        "# Learnings\n\n| Date | Learning | Context |\n|------|----------|---------|\n"
        f"| {today} | Always run pytest before pushing changes to main | Session |\n"
        f"| {today} | Always run pytest before pushing changes onto main | Session |\n",
        encoding="utf-8",
    )
    assert memory_mod.cmd_review([], knowledge) == 1
    out = capsys.readouterr().out
    assert "Duplicates" in out
    assert "%" in out


def test_review_detects_contradictions(tmp_path: Path, capsys):
    knowledge = _seed_knowledge(tmp_path)
    (knowledge / "learnings" / "general.md").write_text(
        "# Learnings\n\n"
        "- Use npm for package installs in this monorepo\n"
        "- Don't use npm; prefer pnpm instead\n",
        encoding="utf-8",
    )
    assert memory_mod.cmd_review([], knowledge) == 1
    out = capsys.readouterr().out
    assert "Contradictions" in out
    assert "npm" in out.lower()


def test_review_detects_orphaned_and_stale(tmp_path: Path, capsys):
    knowledge = _seed_knowledge(tmp_path)
    old = (date.today() - timedelta(days=120)).isoformat()
    (knowledge / "learnings" / "general.md").write_text(
        "# Learnings\n\n| Date | Learning | Context |\n|------|----------|---------|\n"
        f"| {old} | See docs/missing-runbook.md for the deploy steps | Session |\n",
        encoding="utf-8",
    )
    rc = memory_mod.cmd_review(["--stale-after", "90"], knowledge)
    assert rc == 1
    out = capsys.readouterr().out
    assert "Orphaned" in out or "missing path" in out
    assert "Stale" in out


def test_review_fix_prints_suggestions(tmp_path: Path, capsys):
    knowledge = _seed_knowledge(tmp_path)
    today = date.today().isoformat()
    (knowledge / "learnings" / "general.md").write_text(
        "# Learnings\n\n| Date | Learning | Context |\n|------|----------|---------|\n"
        f"| {today} | Prefer ruff check before commit in this repo | Session |\n"
        f"| {today} | Prefer ruff check before committing in this repo | Session |\n",
        encoding="utf-8",
    )
    assert memory_mod.cmd_review(["--fix"], knowledge) == 1
    out = capsys.readouterr().out
    assert "suggestion" in out.lower()


def test_similarity_threshold():
    assert memory_mod._similarity("hello world", "hello world") == 1.0
    assert memory_mod._similarity("run pytest before push", "run pytest before pushing") >= 0.8
    assert memory_mod._similarity("alpha", "zzzzz completely different") < 0.5
