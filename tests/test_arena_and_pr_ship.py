"""Contract, schema, registry, unslop, and parity tests for quality/arena and forge/pr-ship."""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest
import yaml

jsonschema = pytest.importorskip("jsonschema")

REPO = Path(__file__).resolve().parent.parent
ARENA_SKILL = REPO / "skills" / "quality" / "arena" / "SKILL.md"
PR_SHIP_SKILL = REPO / "skills" / "forge" / "pr-ship" / "SKILL.md"
WORK_SKILL = REPO / "skills" / "core" / "work" / "SKILL.md"
FRONTMATTER_SCHEMA = REPO / "schemas" / "skill-md-frontmatter.schema.json"
REGISTRY = REPO / "capabilities" / "skills" / "registry.yaml"
REGISTRY_SCHEMA = REPO / "schemas" / "skill-capability-registry.schema.json"
GOAL_V2_SCHEMA = REPO / "schemas" / "goal-v2.schema.json"
GOAL_EVIDENCE_SCHEMA = REPO / "schemas" / "goal-evidence-v1.schema.json"
PRODUCTS = REPO / "distributions" / "products.yaml"
CATALOG = REPO / "catalogs" / "skill-catalog.yaml"
LAYOUT = REPO / "catalogs" / "skills-layout.json"
SKILL_ROUTING = REPO / "docs" / "SKILL_ROUTING.md"

UNSLOP_BANNED_WORDS = (
    "additionally",
    "crucial",
    "delve",
    "enhance",
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
    "wedge",
    "vector",
    "nexus",
    "primitive",
    "harness",
    "surface",
    "scaffolding",
    "paradigm",
    "ratchet",
    "north star",
    "flywheel",
)


def _parse_skill(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    match = re.match(r"^---\n(.*?)\n---\n(.*)$", text, re.DOTALL)
    assert match, f"{path} must start with YAML frontmatter"
    frontmatter = yaml.safe_load(match.group(1))
    assert isinstance(frontmatter, dict)
    return frontmatter, match.group(2)


def _validate_frontmatter(fm: dict) -> None:
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


def _registry_entries() -> dict[str, dict]:
    data = yaml.safe_load(REGISTRY.read_text(encoding="utf-8"))
    reg_schema = json.loads(REGISTRY_SCHEMA.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator(reg_schema).validate(data)
    return {entry["id"]: entry for entry in data["skills"]}


@pytest.mark.parametrize(
    ("skill_path", "expected_name", "expected_domain"),
    [
        (ARENA_SKILL, "arena", "quality"),
        (PR_SHIP_SKILL, "pr-ship", "forge"),
    ],
)
def test_frontmatter_validates_against_schema_and_attribution(
    skill_path: Path, expected_name: str, expected_domain: str
) -> None:
    fm, _ = _parse_skill(skill_path)
    _validate_frontmatter(fm)
    assert fm["name"] == expected_name
    assert fm["origin"] == {"type": "first-party"}
    assert fm["metadata"]["domain"] == expected_domain
    assert "universal" in fm["tools"]
    inspired_by = fm["metadata"].get("inspired_by", [])
    assert inspired_by, f"{expected_name} must declare metadata.inspired_by attribution"
    for item in inspired_by:
        assert item["repository"] == "cursor/plugins"
        assert re.match(r"^[0-9a-f]{40}$", item["ref"])
        assert item["path"].startswith("pstack/")


def test_registry_entries_and_references() -> None:
    entries = _registry_entries()
    assert "quality/arena" in entries
    assert "forge/pr-ship" in entries

    arena = entries["quality/arena"]
    assert arena["domain"] == "quality"
    assert arena["origin"] == "first-party"
    assert arena["holistic_owner"] == "reviewer"
    assert arena["role"] == "review"
    assert arena["specialist_justified"] is True

    pr_ship = entries["forge/pr-ship"]
    assert pr_ship["domain"] == "forge"
    assert pr_ship["origin"] == "first-party"
    assert pr_ship["holistic_owner"] == "platform-engineer"
    assert pr_ship["role"] == "ops"

    all_ids = set(entries.keys())
    for entry in (arena, pr_ship):
        for field in ("overlap", "complementary", "prerequisites", "follow_ups"):
            for ref in entry[field]:
                assert ref in all_ids, f"{entry['id']} {field} references unknown skill {ref!r}"


def test_arena_skill_covers_bakeoff_rubric_grafting_and_evidence_contract() -> None:
    _, body = _parse_skill(ARENA_SKILL)
    evidence_schema = json.loads(GOAL_EVIDENCE_SCHEMA.read_text(encoding="utf-8"))

    assert "implementer != reviewer != verifier" in body
    assert "forge/worktree" in body
    assert "Candidate A" in body
    assert "Candidate B" in body
    for criterion in (
        "Correctness",
        "Root-cause depth",
        "Minimal diff",
        "Test and verification proof",
        "Regression risk",
    ):
        assert criterion in body, f"arena missing judging criterion {criterion!r}"

    assert "cherry-pick" in body.lower()
    assert "graft" in body.lower()

    for field in evidence_schema["required"]:
        assert f"`{field}`" in body, f"arena missing Goal evidence field {field!r}"
    for mode in evidence_schema["properties"]["mode"]["enum"]:
        assert f"`{mode}`" in body, f"arena missing evidence mode {mode!r}"
    assert "Never claim `pass` using `mode: fixture`" in body


def test_pr_ship_skill_covers_frontier_dual_checks_safety_and_policy_ceiling() -> None:
    _, body = _parse_skill(PR_SHIP_SKILL)
    goal_v2 = json.loads(GOAL_V2_SCHEMA.read_text(encoding="utf-8"))
    evidence_schema = json.loads(GOAL_EVIDENCE_SCHEMA.read_text(encoding="utf-8"))
    valid_effects = set(goal_v2["$defs"]["permissionEffects"]["items"]["enum"])

    assert "Stage 1: Resolve conflicts first" in body
    assert "Stage 2: Skeptical review thread triage" in body
    assert "Stage 3: Dual GitHub check verification and CI triage" in body
    assert "Stage 4: Serialize lockfiles, clean prose, and ship" in body

    assert "check-runs" in body
    assert "/status" in body
    assert "green-to-red" in body
    assert "frozen lockfile" in body.lower()
    assert "Same-lockfile PR serialization" in body
    assert "48h" in body or "48 hours" in body
    assert "gh pr merge --admin" in body
    assert "Push before replying with the exact SHA" in body

    for effect in (
        "github.read",
        "repository.write",
        "process.execute",
        "git.commit",
        "git.push",
        "github.comment.create",
        "github.pr.update",
        "github.pr.create",
        "github.merge",
        "release.publish",
    ):
        assert effect in valid_effects
        assert f"`{effect}`" in body, f"pr-ship missing Goal v2 effect {effect!r}"

    for field in evidence_schema["required"]:
        assert f"`{field}`" in body, f"pr-ship missing Goal evidence field {field!r}"


@pytest.mark.parametrize("skill_path", [ARENA_SKILL, PR_SHIP_SKILL])
def test_skills_have_zero_unslop_violations(skill_path: Path) -> None:
    _, body = _parse_skill(skill_path)
    assert "\u2014" not in body, f"{skill_path} must not contain em dashes"
    assert "\u2013" not in body, f"{skill_path} must not contain en dashes"
    for banned in UNSLOP_BANNED_WORDS:
        assert re.search(rf"\b{re.escape(banned)}\b", body, re.IGNORECASE) is None, (
            f"unslop violation in {skill_path}: {banned!r}"
        )


def test_arena_and_pr_ship_wired_into_work_products_catalogs_and_plugins() -> None:
    _, work_body = _parse_skill(WORK_SKILL)
    assert "quality/arena" in work_body
    assert "forge/pr-ship" in work_body

    products = yaml.safe_load(PRODUCTS.read_text(encoding="utf-8"))["products"]
    by_id = {p["id"]: p for p in products}
    assert "quality/arena" in by_id["agent-toolkit-craft"]["includes"]["skills"]
    assert "quality/arena" in by_id["agent-toolkit-complete"]["includes"]["skills"]
    assert "forge/pr-ship" in by_id["agent-toolkit-forge"]["includes"]["skills"]
    assert "forge/pr-ship" in by_id["agent-toolkit-complete"]["includes"]["skills"]

    catalog = yaml.safe_load(CATALOG.read_text(encoding="utf-8"))
    catalog_ids = {s["id"] for s in catalog["skills"]}
    assert "quality/arena" in catalog_ids
    assert "forge/pr-ship" in catalog_ids

    layout = json.loads(LAYOUT.read_text(encoding="utf-8"))
    assert "arena" in layout["groups"]["quality"]
    assert "pr-ship" in layout["groups"]["forge"]
    layout_ids = {s["id"] for s in layout["skills"]}
    assert "quality/arena" in layout_ids
    assert "forge/pr-ship" in layout_ids

    routing = SKILL_ROUTING.read_text(encoding="utf-8")
    assert "quality/arena" in routing
    assert "forge/pr-ship" in routing

    craft_plugin = REPO / "plugins" / "agent-toolkit-craft" / "skills" / "arena" / "SKILL.md"
    forge_plugin = REPO / "plugins" / "agent-toolkit-forge" / "skills" / "pr-ship" / "SKILL.md"
    complete_arena = REPO / "plugins" / "agent-toolkit-complete" / "skills" / "arena" / "SKILL.md"
    complete_pr_ship = (
        REPO / "plugins" / "agent-toolkit-complete" / "skills" / "pr-ship" / "SKILL.md"
    )

    for plugin_copy, canonical in (
        (craft_plugin, ARENA_SKILL),
        (complete_arena, ARENA_SKILL),
        (forge_plugin, PR_SHIP_SKILL),
        (complete_pr_ship, PR_SHIP_SKILL),
    ):
        assert plugin_copy.is_file(), f"missing plugin copy: {plugin_copy}"
        assert plugin_copy.read_text(encoding="utf-8") == canonical.read_text(encoding="utf-8")
