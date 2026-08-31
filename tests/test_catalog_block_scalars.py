"""Regression tests for YAML block scalar handling in catalog generation (fixes #978).

The hand-rolled fm_field parser previously leaked block scalar markers
(`>`, `|`, `|+`, `|-`) into catalog descriptions. The fix replaces it
with Python's yaml.safe_load which correctly handles YAML 1.2 block
scalars per spec: folded `>` (fold to spaces), literal `|` (preserve
newlines), chomping `+`/`-`, quoted multiline and Unicode.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent


def yaml_load(fm: str):
    """Helper that mimics what generate-catalogs.vsh now does via python yaml."""
    return yaml.safe_load(fm)


def test_folded_block_scalar_becomes_space_joined():
    fm = "name: test\ndescription: >-\n  line1\n  line2\n"
    data = yaml_load(fm)
    assert data["description"] == "line1 line2", (
        f"folded >- should fold, got {data['description']!r}"
    )
    assert not data["description"].startswith(">"), "marker leaked"


def test_folded_keep_chomping():
    fm = "name: test\ndescription: >+\n  line1\n  line2\n"
    data = yaml_load(fm)
    # >+ keep: trailing newline preserved
    assert data["description"].startswith("line1 line2")
    assert data["description"].endswith("\n")


def test_literal_block_scalar_preserves_newlines():
    fm = "name: test\ndescription: |\n  line1\n  line2\n"
    data = yaml_load(fm)
    assert data["description"] == "line1\nline2\n", (
        f"literal | should preserve newlines, got {data['description']!r}"
    )
    assert not data["description"].startswith("|")


def test_literal_keep_and_strip_chomping():
    fm_keep = "name: test\ndescription: |+\n  line1\n  line2\n  \n"
    data_keep = yaml_load(fm_keep)
    assert data_keep["description"].endswith("\n\n") or data_keep["description"].endswith("\n"), (
        "keep should preserve trailing blanks"
    )

    fm_strip = "name: test\ndescription: |-\n  line1\n  line2\n"
    data_strip = yaml_load(fm_strip)
    assert data_strip["description"] == "line1\nline2", (
        f"strip |- should remove trailing newline, got {data_strip['description']!r}"
    )


def test_quoted_strings_unwrapped():
    fm_double = 'name: test\ndescription: "quoted: value"\n'
    assert yaml_load(fm_double)["description"] == "quoted: value"

    fm_single = "name: test\ndescription: 'single: value'\n"
    assert yaml_load(fm_single)["description"] == "single: value"


def test_unicode_preserved():
    fm = "name: test\ndescription: 'Unicode — → × test'\n"
    data = yaml_load(fm)
    assert "—" in data["description"]
    assert "→" in data["description"]
    assert "×" in data["description"]


def test_plain_multiline_folded():
    fm = "name: supply-chain-audit\ndescription: Inspect agent supply chain — skills/plugins/MCP/npm/py packages, hooks, scripts, remote prompts,\n  provenance, version pins, hashes, licenses, network and dangerous permissions — before adopting.\n"
    data = yaml_load(fm)
    # plain multiline should be folded to single space
    assert "remote prompts, provenance" in data["description"]
    assert not data["description"].startswith(">")
    assert not data["description"].startswith("|")


def test_generated_catalog_has_no_block_markers():
    """Verify the actual generated catalogs contain semantic values, not markers."""
    subprocess.check_call(["v", "run", str(REPO / "scripts" / "generate-catalogs.vsh")], cwd=REPO)
    catalog = yaml.safe_load((REPO / "catalogs" / "skill-catalog.yaml").read_text(encoding="utf-8"))
    for skill in catalog["skills"]:
        desc = skill["description"]
        assert not desc.startswith(">"), (
            f"{skill['id']} description leaks folded marker: {desc[:30]!r}"
        )
        assert not desc.startswith("|"), (
            f"{skill['id']} description leaks literal marker: {desc[:30]!r}"
        )
        assert not desc.lstrip().startswith(">-"), f"{skill['id']} leaks >-"
        assert not desc.lstrip().startswith("|+"), f"{skill['id']} leaks |+"

    # Also check agents
    agents = yaml.safe_load((REPO / "catalogs" / "agent-catalog.yaml").read_text(encoding="utf-8"))
    for agent in agents["agents"]:
        desc = agent["description"]
        assert not desc.startswith(">"), f"agent {agent['id']} leaks >"
        assert not desc.startswith("|"), f"agent {agent['id']} leaks |"


def test_known_folded_skill_is_correct():
    """architecture-diagram uses >- and previously leaked '>- WHAT'."""
    subprocess.check_call(["v", "run", str(REPO / "scripts" / "generate-catalogs.vsh")], cwd=REPO)
    catalog = yaml.safe_load((REPO / "catalogs" / "skill-catalog.yaml").read_text(encoding="utf-8"))
    ad = next(s for s in catalog["skills"] if s["id"] == "architecture/architecture-diagram")
    assert ad["description"].startswith("WHAT — Create"), (
        f"expected folded WHAT, got {ad['description'][:30]!r}"
    )
    assert not ad["description"].startswith(">-")
    assert ">-" not in ad["description"][:5]

    bq = next(s for s in catalog["skills"] if s["id"] == "quality/blast-radius")
    # blast-radius uses literal |, should be unwrapped and not start with |
    assert not bq["description"].startswith("|")
    assert "Find what a change" in bq["description"]


def test_literal_skill_preserves_semantics():
    """jira-collaboration and others use literal | — ensure not leaked."""
    subprocess.check_call(["v", "run", str(REPO / "scripts" / "generate-catalogs.vsh")], cwd=REPO)
    catalog = yaml.safe_load((REPO / "catalogs" / "skill-catalog.yaml").read_text(encoding="utf-8"))
    # Find a skill known to use | literal (e.g., jira-collaboration)
    jc = next((s for s in catalog["skills"] if s["id"] == "integrations/jira-collaboration"), None)
    if jc:
        assert not jc["description"].startswith("|")
        assert "Collaborate on issues" in jc["description"]


def test_generate_catalogs_check_passes():
    result = subprocess.run(
        ["v", "run", str(REPO / "scripts" / "generate-catalogs.vsh"), "--check"],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, f"--check failed:\n{result.stdout}\n{result.stderr}"


def test_block_scalar_with_indented_list_context():
    """YAML with block scalar followed by list fields should parse correctly."""
    fm = "name: test\ndescription: >-\n  folded description\n  second line\ndelegates:\n  - a\n  - b\n"
    data = yaml_load(fm)
    assert data["description"] == "folded description second line"
    assert data["delegates"] == ["a", "b"]
