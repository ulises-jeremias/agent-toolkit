"""At least one product covers the full skill catalog (#50)."""

from __future__ import annotations

from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent


def test_complete_product_covers_all_skills():
    skills = {
        f"{p.parent.parent.name}/{p.parent.name}" for p in (REPO / "skills").rglob("SKILL.md")
    }
    products = yaml.safe_load((REPO / "distributions" / "products.yaml").read_text())["products"]
    complete = next(p for p in products if p["id"] == "agent-toolkit-complete")
    included = set(complete.get("includes", {}).get("skills", []))
    assert skills <= included
