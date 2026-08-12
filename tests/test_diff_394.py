"""Tests for #394 diff — absorb upstream practices without duplication."""

import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]


def test_diff_report_exists():
    txt = (ROOT / "docs/research/diff-394-documentation-and-adrs.md").read_text()
    assert "Scope:" in txt and "addyosmani/agent-skills" in txt
    assert "Overlaps" in txt and "Gaps" in txt and "Decision" in txt
    assert "REJECT vendoring" in txt
    assert "ADOPT absorb" in txt
    assert "G1" in txt and "G5" in txt
    assert "288 lines" in txt


def test_adr_extended_convention_first_and_lifecycle():
    txt = (ROOT / "skills/delivery/adr/SKILL.md").read_text()
    assert "Match existing convention first" in txt
    assert "docs/research/diff-394-documentation-and-adrs.md" in txt
    assert "PROPOSED → ACCEPTED" in txt
    assert "don't delete old adrs" in txt.lower()
    assert "Red flags & verification" in txt
    assert "personas/" in txt and "HOW agent thinks" in txt


def test_docs_generator_extended_inline_and_verification():
    txt = (ROOT / "skills/ops/docs-generator/SKILL.md").read_text()
    assert "Inline Documentation (why, not what)" in txt
    assert "Comment the *why*, not the *what*" in txt
    assert "Document Known Gotchas" in txt
    assert "docs/research/diff-394-documentation-and-adrs.md" in txt
    assert "Verification (after documenting)" in txt
    assert "personas/" in txt and "HOW agent thinks" in txt


def test_no_new_skill_added_for_394():
    # Should remain 77 skills — count via validate-skills output is 77, but also ensure no new file named documentation-and-adrs
    assert not (ROOT / "skills/documentation-and-adrs").exists()
    assert not (ROOT / "skills/ops/documentation-and-adrs").exists()
    # adr + docs-generator still exist
    assert (ROOT / "skills/delivery/adr/SKILL.md").exists()
    assert (ROOT / "skills/ops/docs-generator/SKILL.md").exists()


def test_preserve_persona_vs_skill_distinction():
    adr = (ROOT / "skills/delivery/adr/SKILL.md").read_text()
    docgen = (ROOT / "skills/ops/docs-generator/SKILL.md").read_text()
    diff = (ROOT / "docs/research/diff-394-documentation-and-adrs.md").read_text()
    for txt in [adr, docgen, diff]:
        # must preserve distinction
        assert "personas/" in txt.lower() or "persona" in txt.lower()
    assert "docs/CONCEPTS.md" in diff or "docs/CONCEPTS.md" in adr
