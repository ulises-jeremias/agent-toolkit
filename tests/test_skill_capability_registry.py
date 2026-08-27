"""Skill capability registry — 116+ skills, no orphans, design routing (#863)."""

from __future__ import annotations

import json
import re
from pathlib import Path

import yaml

try:
    from jsonschema import validate

    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False

REPO = Path(__file__).resolve().parent.parent
REGISTRY = REPO / "capabilities" / "skills" / "registry.yaml"
SCHEMA = REPO / "schemas" / "skill-capability-registry.schema.json"
CATALOG = REPO / "catalogs" / "skill-catalog.yaml"
ROUTING_DOC = REPO / "docs" / "SKILL_ROUTING.md"
DESIGNER_AGENT = REPO / "agents" / "designer" / "AGENT.md"
ORCHESTRATION = REPO / "skills" / "core" / "assistant" / "references" / "ORCHESTRATION.md"

DESIGN_SKILLS = [
    "design/frontend-design",
    "design/frontend-design-review",
    "design/web-design-guidelines",
    "design/design-assessment",
    "design/design-improvement",
    "design/figma",
    "design/figma-code-connect-components",
    "design/figma-create-design-system-rules",
    "design/figma-create-new-file",
    "design/figma-implement-design",
    "accessibility/review",
]

ROUTING_PHRASES = [
    "New visual direction / creative frontend",
    "Existing frontend quality/design review",
    "Concrete web-interface best-practice audit",
    "Evidence-based holistic UX/UI diagnosis",
    "Iterative browser-grounded remediation",
    "Figma-driven work",
    "Accessibility-sensitive UI",
]

HOLISTIC_OWNERS = {
    "assistant",
    "planner",
    "architect",
    "designer",
    "implementer",
    "reviewer",
    "qa-engineer",
    "security-engineer",
    "platform-engineer",
    "data-engineer",
    "researcher",
}


def _load_registry():
    assert REGISTRY.is_file(), f"missing registry: {REGISTRY}"
    return yaml.safe_load(REGISTRY.read_text(encoding="utf-8"))


def _load_catalog():
    assert CATALOG.is_file(), f"missing catalog: {CATALOG}"
    return yaml.safe_load(CATALOG.read_text(encoding="utf-8"))


def test_registry_file_exists():
    assert REGISTRY.is_file()
    assert SCHEMA.is_file()


def test_registry_validates_against_schema():
    data = _load_registry()
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))
    if HAS_JSONSCHEMA:
        validate(data, schema)
    else:
        assert "skills" in data and "count" in data


def test_registry_count_matches_catalog_and_filesystem():
    data = _load_registry()
    cat = _load_catalog()
    fs_ids = {
        str(p.parent.relative_to(REPO / "skills")) for p in (REPO / "skills").rglob("SKILL.md")
    }
    reg_ids = {s["id"] for s in data["skills"]}
    cat_ids = {s["id"] for s in cat["skills"]}
    assert data["count"] == len(data["skills"])
    assert data["count"] == cat["count"]
    assert data["count"] == len(fs_ids)
    assert reg_ids == cat_ids == fs_ids


def test_no_orphan_skills():
    data = _load_registry()
    orphans = [s["id"] for s in data["skills"] if not s.get("holistic_owner")]
    assert orphans == [], f"orphaned skills (no holistic_owner): {orphans}"
    for s in data["skills"]:
        assert s["holistic_owner"] in HOLISTIC_OWNERS, (
            f"{s['id']}: invalid holistic_owner {s['holistic_owner']!r}"
        )


def test_every_skill_has_triggers_and_contraindications():
    data = _load_registry()
    no_triggers = [s["id"] for s in data["skills"] if not s.get("triggers")]
    assert no_triggers == [], f"skills with no triggers: {no_triggers}"
    short_contra = [s["id"] for s in data["skills"] if len(s.get("contraindications", "")) < 10]
    assert short_contra == [], f"skills with missing/short contraindications: {short_contra}"


def test_references_are_real_skill_ids():
    data = _load_registry()
    all_ids = {s["id"] for s in data["skills"]}
    for s in data["skills"]:
        for field in ("overlap", "complementary", "prerequisites", "follow_ups"):
            for ref in s.get(field, []) or []:
                assert ref in all_ids, f"{s['id']}: {field} references unknown {ref!r}"


def test_origin_matches_frontmatter():
    data = _load_registry()
    reg_orig = {s["id"]: s["origin"] for s in data["skills"]}
    for p in (REPO / "skills").rglob("SKILL.md"):
        sid = str(p.parent.relative_to(REPO / "skills"))
        text = p.read_text(encoding="utf-8")
        m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
        fm = yaml.safe_load(m.group(1)) if m else {}
        expected = "unknown"
        if isinstance(fm.get("origin"), dict):
            expected = fm["origin"].get("type", "unknown")
        elif "origin" in fm:
            expected = str(fm["origin"])
        else:
            expected = "upstream" if "upstream" in fm or "sources" in fm else "first-party"
        # normalize
        if expected not in ("first-party", "upstream"):
            expected = "upstream" if "upstream" in fm or "sources" in fm else "first-party"
        assert reg_orig.get(sid) == expected, (
            f"{sid}: registry origin {reg_orig.get(sid)!r} != frontmatter {expected!r}"
        )


def test_upstream_gate():
    data = _load_registry()
    for s in data["skills"]:
        if s["origin"] == "upstream":
            assert "upstream" in s, f"{s['id']}: origin upstream must have upstream metadata"
            u = s["upstream"]
            assert u.get("repository") and "/" in u["repository"]
            assert u.get("path")
            assert u.get("ref")
            assert u.get("license")
        else:
            assert "upstream" not in s, f"{s['id']}: first-party must not have upstream"


def test_design_skills_owned_by_designer():
    data = _load_registry()
    reg_by_id = {s["id"]: s for s in data["skills"]}
    for did in DESIGN_SKILLS:
        assert did in reg_by_id, f"design skill missing: {did}"
        assert reg_by_id[did]["holistic_owner"] == "designer", (
            f"{did}: expected designer, got {reg_by_id[did]['holistic_owner']!r}"
        )
    # also check designer agent exists
    assert DESIGNER_AGENT.is_file(), f"missing designer agent: {DESIGNER_AGENT}"
    assert ORCHESTRATION.is_file()


def test_design_routing_doc_coverage():
    assert ROUTING_DOC.is_file()
    text = ROUTING_DOC.read_text(encoding="utf-8")
    for phrase in ROUTING_PHRASES:
        assert phrase in text, f"routing doc missing phrase: {phrase!r}"
    assert "capabilities/skills/registry.yaml" in text


def test_orchestration_design_section():
    text = ORCHESTRATION.read_text(encoding="utf-8")
    for did in [
        "frontend-design",
        "design-assessment",
        "web-design-guidelines",
        "design-improvement",
    ]:
        assert did in text, f"ORCHESTRATION.md Design section missing: {did}"


def test_designer_agent_five_scenarios():
    assert DESIGNER_AGENT.is_file()
    text = DESIGNER_AGENT.read_text(encoding="utf-8")
    # must encode the five canonical routes
    for skill in [
        "frontend-design",
        "frontend-design-review",
        "web-design-guidelines",
        "design-assessment",
        "design-improvement",
    ]:
        assert skill in text, f"designer agent missing skill: {skill}"
    # must have self-test section
    assert "Five-scenario" in text or "five-scenario" in text.lower() or "self-test" in text.lower()


def test_roles_and_costs_enums():
    data = _load_registry()
    valid_roles = {"creation", "review", "validation", "research", "ops"}
    valid_costs = {"low", "medium", "high"}
    for s in data["skills"]:
        assert s["role"] in valid_roles, f"{s['id']}: invalid role {s['role']!r}"
        assert s["context_cost"] in valid_costs, (
            f"{s['id']}: invalid context_cost {s['context_cost']!r}"
        )
        assert isinstance(s["network_required"], bool)
        assert isinstance(s["mcp_required"], list)


def test_version_is_1():
    data = _load_registry()
    assert data.get("version") == 1
