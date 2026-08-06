"""Fail when advertised skill reference files are empty (#76)."""

from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).resolve().parent.parent


def test_no_empty_delivery_reference_files():
    empty = []
    for path in (REPO / "skills" / "delivery").rglob("*.md"):
        if "references" not in path.parts:
            continue
        if path.stat().st_size == 0:
            empty.append(str(path.relative_to(REPO)))
    assert not empty, "empty skill reference files:\n" + "\n".join(empty)
