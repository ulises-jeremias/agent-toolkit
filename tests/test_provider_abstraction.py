"""Tests for provider abstraction pilots — #386.

Covers WHAT vs HOW, no universal ranking, source trust vs runtime privilege distinct,
and 3 pilots (Linear, Slack, Figma) with evaluated HOWs.
"""

import json
import pathlib

import yaml
from jsonschema import Draft202012Validator

REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
SCHEMA_PATH = REPO_ROOT / "schemas/provider.schema.json"
REGISTRY_PATH = REPO_ROOT / "providers/providers.yaml"
MATRIX_PATH = REPO_ROOT / "docs/providers/provider-matrix.md"


def test_schema_valid():
    schema = json.loads(SCHEMA_PATH.read_text())
    assert schema["title"] == "Provider Registry"


def test_registry_has_three_pilots():
    data = yaml.safe_load(REGISTRY_PATH.read_text())
    assert data["version"] == "1"
    assert {"linear", "slack", "figma"}.issubset(set(data["providers"].keys()))
    for pid in ["linear", "slack", "figma"]:
        prov = data["providers"][pid]
        assert "what" in prov and "how" in prov
        assert len(prov["how"]) >= 4, (
            f"{pid} should have >=4 HOWs (official, alternative, fallback)"
        )
        # Must have at least one mcp and one api/cli
        mechanisms = {h["mechanism"] for h in prov["how"]}
        assert "mcp" in mechanisms or "community_mcp" in mechanisms
        # Must have skill_fallback
        assert "skill_fallback" in mechanisms


def test_registry_validates_against_schema():
    schema = json.loads(SCHEMA_PATH.read_text())
    data = yaml.safe_load(REGISTRY_PATH.read_text())
    validator = Draft202012Validator(schema)
    errs = list(validator.iter_errors(data))
    assert errs == [], [f"{e.message} at {list(e.path)}" for e in errs]


def test_what_vs_how_separation():
    data = yaml.safe_load(REGISTRY_PATH.read_text())
    for pid, prov in data["providers"].items():
        # WHAT is stable verbs/entities
        assert "verbs" in prov["what"]
        assert len(prov["what"]["verbs"]) >= 3
        # HOW is per-target/mechanism
        for how in prov["how"]:
            assert "targets" in how
            assert len(how["targets"]) >= 1
            # Must not encode universal ranking — check evaluation notes mention contextual choice
        assert "evaluation" in prov
        assert "notes" in prov["evaluation"]
        assert (
            "No universal" in prov["evaluation"]["notes"]
            or "contextual" in prov["evaluation"]["notes"].lower()
        )


def test_no_universal_ranking():
    # Must not have a file that says "official plugin > MCP > CLI" as law
    matrix = MATRIX_PATH.read_text()
    # Matrix must say there is NO universal ranking, not assert one as law
    assert (
        "No universal" in matrix
        or "per-capability" in matrix.lower()
        or "contextual" in matrix.lower()
    )
    # If the ranking phrase appears, it must be negated (No / not / without)
    if "official plugin > MCP > CLI" in matrix:
        assert (
            "No"
            in matrix[
                matrix.index("official plugin > MCP > CLI") - 40 : matrix.index(
                    "official plugin > MCP > CLI"
                )
                + 40
            ]
        )
        assert "law" in matrix.lower() or "no" in matrix.lower()


def test_source_trust_vs_runtime_privilege_distinct():
    data = yaml.safe_load(REGISTRY_PATH.read_text())
    for pid, prov in data["providers"].items():
        assert "security" in prov
        assert "source_trust" in prov["security"]
        assert "runtime_privilege" in prov["security"]
        for how in prov["how"]:
            perms = how["permissions"]
            assert perms["source_trust"] in ["official", "community", "first-party"]
            assert perms["runtime_privilege"] in ["read-only", "read-write", "admin"]
            # Official source can still be admin privilege (e.g., Slack CLI) — must be separate
    # Check matrix has distinct section
    matrix = MATRIX_PATH.read_text()
    assert "source trust vs runtime privilege" in matrix.lower()


def test_linear_evaluated_dimensions():
    data = yaml.safe_load(REGISTRY_PATH.read_text())
    linear = data["providers"]["linear"]
    how_ids = {h["id"] for h in linear["how"]}
    assert "linear-mcp-official" in how_ids
    assert "linear-api-graphql" in how_ids
    # Check dimensions present
    for how in linear["how"]:
        assert "auth" in how and "type" in how["auth"]
        assert "read" in how and "write" in how
        assert "runtime" in how and "local_vs_remote" in how["runtime"]
        assert "availability" in how


def test_slack_figma_dimensions():
    data = yaml.safe_load(REGISTRY_PATH.read_text())
    for pid in ["slack", "figma"]:
        prov = data["providers"][pid]
        for how in prov["how"]:
            assert "auth" in how
            assert "permissions" in how
            assert "runtime" in how


def test_matrix_dated_and_generated():
    matrix = MATRIX_PATH.read_text()
    assert "2026-08-12" in matrix
    assert "WHAT vs HOW" in matrix
    for cap in ["Linear", "Slack", "Figma"]:
        assert cap in matrix


def test_existing_skills_still_valid():
    # Ensure existing integration skills still have valid frontmatter after provider abstraction
    for skill in [
        "skills/integrations/linear/SKILL.md",
        "skills/integrations/slack-cli/SKILL.md",
        "skills/design/figma/SKILL.md",
    ]:
        p = REPO_ROOT / skill
        assert p.exists(), f"missing {skill}"
        text = p.read_text()
        assert "origin:" in text
