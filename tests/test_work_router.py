"""Contract, schema, registry, and parity tests for the unified core/work router."""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest
import yaml

jsonschema = pytest.importorskip("jsonschema")

REPO = Path(__file__).resolve().parent.parent
WORK_SKILL = REPO / "skills" / "core" / "work" / "SKILL.md"
FRONTMATTER_SCHEMA = REPO / "schemas" / "skill-md-frontmatter.schema.json"
REGISTRY = REPO / "capabilities" / "skills" / "registry.yaml"
REGISTRY_SCHEMA = REPO / "schemas" / "skill-capability-registry.schema.json"
GOAL_V2_SCHEMA = REPO / "schemas" / "goal-v2.schema.json"
GOAL_EVIDENCE_SCHEMA = REPO / "schemas" / "goal-evidence-v1.schema.json"
PRODUCTS = REPO / "distributions" / "products.yaml"
CATALOG = REPO / "catalogs" / "skill-catalog.yaml"
LAYOUT = REPO / "catalogs" / "skills-layout.json"
ORCHESTRATION = REPO / "skills" / "core" / "assistant" / "references" / "ORCHESTRATION.md"
SKILL_ROUTING = REPO / "docs" / "SKILL_ROUTING.md"


def _parse_work_skill() -> tuple[dict, str]:
    text = WORK_SKILL.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    assert match, "skills/core/work/SKILL.md must start with YAML frontmatter"
    frontmatter = yaml.safe_load(match.group(1))
    assert isinstance(frontmatter, dict)
    return frontmatter, match.group(2)


def _registry_entry() -> dict:
    data = yaml.safe_load(REGISTRY.read_text(encoding="utf-8"))
    matches = [entry for entry in data["skills"] if entry["id"] == "core/work"]
    assert len(matches) == 1, f"expected single core/work entry, got {len(matches)}"
    return matches[0]


def test_work_skill_frontmatter_validates_against_schema() -> None:
    fm, _ = _parse_work_skill()
    schema = json.loads(FRONTMATTER_SCHEMA.read_text(encoding="utf-8"))
    upstream_schema = json.loads(
        (REPO / "schemas" / "upstream.schema.json").read_text(encoding="utf-8")
    )
    try:
        from referencing import Registry, Resource

        registry = Registry().with_resources(
            [
                ("upstream.schema.json", Resource.from_contents(upstream_schema)),
                (
                    "https://raw.githubusercontent.com/ulises-jeremias/agent-toolkit/main/schemas/upstream.schema.json",
                    Resource.from_contents(upstream_schema),
                ),
            ]
        )
        jsonschema.Draft202012Validator(schema, registry=registry).validate(fm)
    except ImportError:
        jsonschema.Draft202012Validator(schema).validate(fm)
    assert fm["name"] == "work"
    assert fm["origin"] == {"type": "first-party"}
    assert "universal" in fm["tools"]
    assert "work" in fm["triggers"]


def test_work_skill_registry_entry_and_references() -> None:
    reg_data = yaml.safe_load(REGISTRY.read_text(encoding="utf-8"))
    reg_schema = json.loads(REGISTRY_SCHEMA.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator(reg_schema).validate(reg_data)

    entry = _registry_entry()
    assert entry["domain"] == "core"
    assert entry["origin"] == "first-party"
    assert entry["holistic_owner"] == "assistant"
    assert entry["role"] == "ops"
    assert "work" in entry["triggers"]
    all_ids = {s["id"] for s in reg_data["skills"]}
    for field in ("overlap", "complementary", "prerequisites", "follow_ups"):
        for ref in entry[field]:
            assert ref in all_ids, f"core/work {field} references unknown skill {ref!r}"


def test_work_skill_covers_all_goal_v2_policy_ceiling_effects() -> None:
    _, body = _parse_work_skill()
    goal_v2 = json.loads(GOAL_V2_SCHEMA.read_text(encoding="utf-8"))
    effects = goal_v2["$defs"]["permissionEffects"]["items"]["enum"]
    for effect in effects:
        assert f"`{effect}`" in body, f"work router must document Goal v2 effect {effect!r}"
    assert "policy_ceiling" in body
    assert "delivery_mode" in body


def test_work_skill_enforces_independent_verification_and_receipt_contract() -> None:
    _, body = _parse_work_skill()
    evidence_schema = json.loads(GOAL_EVIDENCE_SCHEMA.read_text(encoding="utf-8"))
    assert "implementer != reviewer != verifier" in body
    assert "cross-vendor" in body.lower()
    for field in evidence_schema["required"]:
        assert f"`{field}`" in body, f"work router missing Goal evidence field {field!r}"
    for mode in evidence_schema["properties"]["mode"]["enum"]:
        assert f"`{mode}`" in body, f"work router missing evidence mode {mode!r}"


def test_work_skill_enforces_conflict_first_pr_shipping_and_playbooks() -> None:
    _, body = _parse_work_skill()
    for playbook in (
        "Discovery",
        "Investigation and RCA",
        "Feature implementation",
        "Cross-vendor review and arena",
        "Visual and accessibility QA",
        "Conflict-first PR shipping",
        "Durable Goal and Loop verification",
    ):
        assert playbook in body, f"work router missing playbook {playbook!r}"
    for skill_ref in (
        "forge/fix-merge-conflicts",
        "forge/gh-address-comments",
        "forge/gh-fix-ci",
        "quality/unslop",
        "quality/deslop",
        "quality/deep-review",
        "quality/blast-radius",
    ):
        assert skill_ref in body, f"work router missing delegation reference {skill_ref!r}"
    assert "Push the fix before replying with the exact SHA" in body
    assert "frozen lockfile" in body.lower()


def test_work_skill_has_zero_unslop_violations() -> None:
    _, body = _parse_work_skill()
    assert "\u2014" not in body, "work skill must not use em dashes"
    assert "\u2013" not in body, "work skill must not use en dashes"
    for banned in (
        "additionally",
        "crucial",
        "delve",
        "foster",
        "landscape",
        "pivotal",
        "showcase",
        "testament",
        "underscore",
        "vibrant",
        "utilize",
        "leverage",
        "substrate",
        "flywheel",
        "paradigm",
    ):
        assert re.search(rf"\b{banned}\b", body, re.IGNORECASE) is None, (
            f"unslop violation in work skill: {banned!r}"
        )


def test_work_skill_wired_into_products_catalogs_and_plugins() -> None:
    products = yaml.safe_load(PRODUCTS.read_text(encoding="utf-8"))["products"]
    by_id = {p["id"]: p for p in products}
    assert "core/work" in by_id["agent-toolkit-core"]["includes"]["skills"]
    assert "core/work" in by_id["agent-toolkit-complete"]["includes"]["skills"]

    catalog = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))
    assert any(s["id"] == "core/work" for s in catalog["skills"])

    layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
    assert "work" in layout["groups"]["core"]
    assert any(s["id"] == "core/work" for s in layout["skills"])

    assert "core/work" in SKILL_ROUTING.read_text(encoding="utf-8")
    assert "**work**" in ORCHESTRATION.read_text(encoding="utf-8")

    core_plugin_skill = REPO / "plugins" / "agent-toolkit-core" / "skills" / "work" / "SKILL.md"
    complete_plugin_skill = (
        REPO / "plugins" / "agent-toolkit-complete" / "skills" / "work" / "SKILL.md"
    )
    assert core_plugin_skill.is_file()
    assert complete_plugin_skill.is_file()
    canonical = WORK_SKILL.read_text(encoding="utf-8")
    assert core_plugin_skill.read_text(encoding="utf-8") == canonical
    assert complete_plugin_skill.read_text(encoding="utf-8") == canonical
