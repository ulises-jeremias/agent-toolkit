"""Swarm role alignment — #870: swarm runtime roles vs canonical agent taxonomy."""

from __future__ import annotations

import pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent
AGENTS_DIR = REPO / "agents"
SWARM_ROLES_DOC = REPO / "docs" / "SWARM_ROLES.md"
SWARM_RECIPES = REPO / "docs" / "SWARM_RECIPES.md"
SWARMS_DOC = REPO / "docs" / "SWARMS.md"
ARCHITECTURE = REPO / "docs" / "ARCHITECTURE.md"

CANONICAL_AGENTS = {p.name for p in AGENTS_DIR.iterdir() if p.is_dir()}
RUNTIME_ONLY = {"integrator", "hardener", "refactorer"}


def test_swarm_roles_doc_exists():
    assert SWARM_ROLES_DOC.is_file(), "docs/SWARM_ROLES.md required by #870"
    text = SWARM_ROLES_DOC.read_text(encoding="utf-8")
    assert "Runtime Roles vs Canonical Agent Taxonomy" in text
    assert "Validate with `python3 -m pytest tests/test_swarm_alignment.py" in text


def test_vocab_section():
    text = SWARM_ROLES_DOC.read_text(encoding="utf-8")
    for term in ["Persona", "Runtime role", "Skill", "Model profile"]:
        assert term in text, f"vocab missing {term!r}"
    assert "Never conflate" in text or "never conflate" in text.lower()


def test_every_runtime_role_mapped():
    text = SWARM_ROLES_DOC.read_text(encoding="utf-8")
    for role in [
        "planner",
        "implementer",
        "reviewer",
        "integrator",
        "architect",
        "refactorer",
        "hardener",
        "qa",
        "designer",
    ]:
        assert f"`{role}`" in text, f"SWARM_ROLES.md missing runtime role `{role}`"


def test_integrator_positioned_as_runtime_not_holistic():
    text = SWARM_ROLES_DOC.read_text(encoding="utf-8")
    assert "integrator" in text.lower()
    assert "Runtime responsibility" in text or "runtime responsibility" in text
    assert "not a permanent daily persona" in text or "not a permanent" in text.lower()
    assert "`architect` in integrator policy" in text or "architect` acting as integrator" in text


def test_hardener_conditional_activation():
    text = SWARM_ROLES_DOC.read_text(encoding="utf-8")
    assert "hardener" in text
    assert "Conditional" in text
    assert "security-reviewer" in text
    assert "TYPESCRIPT_CHECKLIST.md" in text or "DATABASE_CHECKLIST.md" in text


def test_refactorer_not_inflated_to_agent():
    text = SWARM_ROLES_DOC.read_text(encoding="utf-8")
    assert "refactorer" in text
    assert "reviewer" in text.lower()
    assert "REFACTOR_CHECKLIST.md" in text
    assert "Do not add them to `agents/`" in text or "not holistic" in text


def test_no_runtime_role_is_canonical_except_planner_implementer_etc():
    for role in RUNTIME_ONLY:
        assert role not in CANONICAL_AGENTS, (
            f"runtime role {role!r} must not be a canonical agent dir"
        )


def test_recipe_tables_use_canonical_personas():
    text = SWARM_ROLES_DOC.read_text(encoding="utf-8")
    assert "### pair" in text
    assert "`implementer` | `implementer`" in text or "| `implementer`" in text
    assert "### team" in text
    assert "### full" in text
    assert "`qa` | `qa-engineer`" in text or "qa-engineer" in text


def test_invariants_section():
    text = SWARM_ROLES_DOC.read_text(encoding="utf-8")
    assert "## 4. Invariants" in text
    assert "No parallel taxonomy" in text
    assert "Integrator/hardener/refactorer are not holistic" in text or "not holistic" in text
    assert "Independent boundaries" in text or "Independent" in text


def test_existing_swarm_docs_reference_roles_doc():
    for path in [SWARM_RECIPES, SWARMS_DOC]:
        assert path.is_file(), f"missing {path}"
        text = path.read_text(encoding="utf-8")
        assert "SWARM_ROLES.md" in text or "SWARM_ROLES" in text, (
            f"{path.name} must reference SWARM_ROLES.md"
        )


def test_swarm_roles_references_canonical_sources():
    text = SWARM_ROLES_DOC.read_text(encoding="utf-8")
    for ref in [
        "docs/AGENT_TAXONOMY.md",
        "docs/SWARM_RECIPES.md",
        "capabilities/skills/registry.yaml",
    ]:
        assert ref in text, f"SWARM_ROLES.md should cite {ref}"


def test_architecture_swarms_section_consistent():
    assert ARCHITECTURE.is_file()
    assert SWARM_ROLES_DOC.is_file()
