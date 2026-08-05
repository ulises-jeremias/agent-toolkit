"""Public concept consistency — README packs match filesystem."""
from __future__ import annotations

from pathlib import Path

REPO = Path(__file__).parent.parent


def test_readme_pack_names_match_filesystem():
    readme = (REPO / "README.md").read_text()
    packs_dir = REPO / "packs"
    real_packs = {
        p.name
        for p in packs_dir.iterdir()
        if p.is_dir() and not p.name.startswith(".")
    }
    for pack in real_packs:
        assert f"`{pack}`" in readme, f"README missing pack `{pack}`"
    assert "oss-ecosystem" not in readme
    assert "startup-delivery" not in readme


def test_concepts_doc_exists():
    assert (REPO / "docs" / "CONCEPTS.md").is_file()
