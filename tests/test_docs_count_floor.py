"""Docs count-floor guard.

Docs express the *total* skill count as a floor ("116+ skills"), never an exact
number, so prose doesn't need editing every time a capability is added. This
test asserts the floor never overstates reality (N <= actual). The precise SoT
remains `agent-toolkit inventory` / `catalogs/skill-catalog.yaml`.

Domain-specific counts ("11 design skills") are legitimate and are not floors —
they refer to a curated subset, not the catalog total.
"""

from __future__ import annotations

import re
from pathlib import Path

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG = REPO_ROOT / "catalogs" / "skill-catalog.yaml"

DOC_GLOBS = ["README.md", "docs/**/*.md", "AGENTS.md", "docs/wiki/*.md"]

# Total-count phrasings that must carry a '+' (floor), not an exact number.
# These are the phrases that previously read "85 skills" etc.
TOTAL_FLOOR_PATTERNS = [
    re.compile(r"(\d{2,})\+\s*skills"),
]


def _actual_skill_count() -> int:
    data = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))
    return int(data.get("count", len(data.get("skills", []))))


def _docs() -> list[Path]:
    out = []
    for g in DOC_GLOBS:
        out.extend(REPO_ROOT.glob(g))
    return [p for p in out if p.is_file()]


def test_skill_floor_never_overstates() -> None:
    actual = _actual_skill_count()
    for doc in _docs():
        text = doc.read_text(encoding="utf-8")
        for m in re.finditer(r"(\d{2,})\+\s*skills", text):
            floor = int(m.group(1))
            assert floor <= actual, f"{doc}: claims {floor}+ skills but catalog has only {actual}"
