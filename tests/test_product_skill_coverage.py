"""Product catalog must cover stable canonical skills."""
from __future__ import annotations

from pathlib import Path

import pytest

from agent_toolkit.compiler.loader import load_graph

# Skills intentionally excluded from distributable products (experimental, internal-only).
INTENTIONAL_EXCLUSIONS: frozenset[str] = frozenset()

# Minimum fraction of stable skills that must appear in at least one product.
MIN_COVERAGE_RATIO = 1.0


def _repo_root() -> Path:
    here = Path(__file__).resolve()
    for parent in here.parents:
        if (parent / "skills").is_dir() and (parent / "distributions" / "products.yaml").is_file():
            return parent
    pytest.fail("Could not locate agent-toolkit repo root from tests/")


def test_product_skill_coverage_tracked() -> None:
    repo = _repo_root()
    graph = load_graph(repo)

    stable_skill_ids = {
        sid for sid, skill in graph.skills.items() if skill.stability.value == "stable"
    }
    assert stable_skill_ids, "expected at least one stable skill in skills/"

    covered: set[str] = set()
    for product in graph.products.values():
        covered.update(product.included_skills)

    eligible = stable_skill_ids - INTENTIONAL_EXCLUSIONS
    uncovered = sorted(eligible - covered)
    ratio = len(eligible & covered) / len(eligible) if eligible else 1.0

    assert ratio >= MIN_COVERAGE_RATIO, (
        f"Product skill coverage {ratio:.0%} below minimum {MIN_COVERAGE_RATIO:.0%}. "
        f"Uncovered stable skills ({len(uncovered)}): {', '.join(uncovered)}"
    )


def test_no_duplicate_skill_across_products() -> None:
    repo = _repo_root()
    graph = load_graph(repo)

    seen: dict[str, str] = {}
    duplicates: list[str] = []
    for pid, product in graph.products.items():
        for skill_id in product.included_skills:
            if skill_id in seen:
                duplicates.append(f"{skill_id}: {seen[skill_id]} + {pid}")
            else:
                seen[skill_id] = pid

    assert not duplicates, "Skills must not appear in multiple products:\n" + "\n".join(duplicates)
