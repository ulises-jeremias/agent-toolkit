"""Regression tests for P0 provenance governance (gates 1-13).

Covers:
- first-party valid, upstream with provenance valid, missing provenance invalid
- full 40-char SHA valid, short SHAs (7,12,39) invalid
- mutable branch invalid, tag without commit invalid, tag+commit valid
- SPDX subset
- multi-source
- pure prompt with cve_policy not-applicable
- schema vs validator agreement
- non-skill capability types
- origin explicit (gate 2)
"""
from __future__ import annotations

import json
import re
import tempfile
from pathlib import Path

import pytest
import yaml
import jsonschema
from jsonschema import Draft202012Validator

REPO_ROOT = Path(__file__).parent.parent
UPSTREAM_SCHEMA = json.loads((REPO_ROOT / "schemas/upstream.schema.json").read_text())
SKILL_FRONTMATTER_SCHEMA = json.loads((REPO_ROOT / "schemas/skill-md-frontmatter.schema.json").read_text())

# Import validator functions
import importlib.util, sys
spec = importlib.util.spec_from_file_location("validate_upstream", REPO_ROOT / "scripts" / "validate-upstream.py")
vu = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vu)

SHA40 = "f" * 40
SHORT7 = "abc1234"
SHORT12 = "abc123456789"
SHORT39 = "f" * 39
TAG = "v1.2.3"

def make_frontmatter(data: dict) -> str:
    return yaml.safe_dump(data, sort_keys=False)

def write_skill(tmp_path: Path, fm: dict) -> Path:
    p = tmp_path / "SKILL.md"
    p.write_text(f"---\n{make_frontmatter(fm)}---\n\n# Test\n", encoding="utf-8")
    return p

# ---- Gate 2: origin explicit ----

def test_first_party_valid(tmp_path):
    fm = {"name": "test", "description": "desc", "origin": {"type": "first-party"}}
    p = write_skill(tmp_path, fm)
    assert vu.validate_one(p) == []

def test_first_party_with_upstream_invalid(tmp_path):
    fm = {"name": "test", "description": "desc", "origin": {"type": "first-party"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    errs = vu.validate_one(p)
    assert any("first-party must not have" in e for e in errs)

def test_first_party_missing_origin_invalid(tmp_path):
    fm = {"name": "test", "description": "desc"}
    p = write_skill(tmp_path, fm)
    errs = vu.validate_one(p)
    assert any("missing origin" in e for e in errs)

def test_upstream_with_provenance_valid(tmp_path):
    fm = {"name": "test", "description": "desc", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    assert vu.validate_one(p) == []

def test_upstream_without_provenance_invalid(tmp_path):
    fm = {"name": "test", "description": "desc", "origin": {"type": "upstream"}}
    p = write_skill(tmp_path, fm)
    errs = vu.validate_one(p)
    assert any("requires 'upstream' or 'sources'" in e for e in errs)

def test_external_without_provenance_invalid(tmp_path):
    # Same as upstream — external is distribution mode, but origin is upstream
    fm = {"name": "test", "description": "desc", "origin": {"type": "upstream"}, "distribution": {"mode": "external"}}
    p = write_skill(tmp_path, fm)
    errs = vu.validate_one(p)
    assert any("requires 'upstream'" in e for e in errs)

def test_vendored_without_provenance_invalid(tmp_path):
    fm = {"name": "test", "description": "desc", "origin": {"type": "upstream"}, "distribution": {"mode": "vendored"}}
    p = write_skill(tmp_path, fm)
    errs = vu.validate_one(p)
    assert any("requires" in e for e in errs)

def test_undeclared_third_party_cannot_pass(tmp_path):
    # New third-party skill that omits origin and upstream — must fail gate 2
    fm = {"name": "third-party-skill", "description": "desc", "upstream": {"repository": "evil/repo", "path": "x", "ref": SHA40, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    errs = vu.validate_one(p)
    # Missing origin -> fails, even though upstream present
    assert any("missing origin" in e for e in errs)
    # Also test completely missing both -> fails
    fm2 = {"name": "third-party-skill", "description": "desc"}
    p2 = write_skill(tmp_path, fm2)
    errs2 = vu.validate_one(p2)
    assert any("missing origin" in e for e in errs2)

# ---- Gate 1: Full SHA ----

def test_40_char_sha_valid(tmp_path):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    assert vu.validate_one(p) == []

def test_short_sha_7_invalid(tmp_path):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHORT7, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    errs = vu.validate_one(p)
    assert any("short SHA" in e or "40-char" in e for e in errs)

def test_short_sha_12_invalid(tmp_path):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHORT12, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    assert any("short SHA" in e or "40-char" in e for e in vu.validate_one(p))

def test_short_sha_39_invalid(tmp_path):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHORT39, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    assert any("short SHA" in e for e in vu.validate_one(p))

def test_mutable_branch_invalid(tmp_path):
    for ref in ["main", "master", "latest", "develop", "stable"]:
        fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": ref, "license": "MIT"}}
        p = write_skill(tmp_path, fm)
        assert any("mutable" in e or "40-char" in e for e in vu.validate_one(p)), f"ref {ref} should be rejected"

def test_tag_without_commit_invalid(tmp_path):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": TAG, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    assert any("requires commit" in e for e in vu.validate_one(p))

def test_tag_with_40_char_commit_valid(tmp_path):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": TAG, "commit": SHA40, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    assert vu.validate_one(p) == []

def test_tag_with_short_commit_invalid(tmp_path):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": TAG, "commit": SHORT7, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    assert any("40-char" in e for e in vu.validate_one(p))

# ---- Gate 6: SPDX ----

@pytest.mark.parametrize("spdx,should_pass", [
    ("MIT", True),
    ("Apache-2.0", True),
    ("AGPL-3.0-only", True),
    ("MIT OR Apache-2.0", True),
    ("MIT AND CC-BY-4.0", True),
    ("LicenseRef-Unknown", True),
    ("LicenseRef-Custom-1.0", True),
    ("NOASSERTION", True),
    ("garbage-license", False),
    ("MIT OR", False),
    ("UNKNOWN", False),
    ("MIT AND CC-BY-4.0 AND Apache-2.0", False),  # too complex for V1
])
def test_spdx_subset(tmp_path, spdx, should_pass):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHA40, "license": spdx}}
    p = write_skill(tmp_path, fm)
    errs = vu.validate_one(p)
    has_license_error = any("license" in e.lower() or "spdx" in e.lower() for e in errs)
    assert (not has_license_error) == should_pass, f"SPDX {spdx!r} expected {'pass' if should_pass else 'fail'} got errs={errs}"

# ---- Gate 9: Multi-source ----

def test_multi_source_valid(tmp_path):
    fm = {
        "name": "t", "description": "d",
        "origin": {"type": "upstream"},
        "sources": [
            {"role": "wrapper", "repository": "vercel-labs/agent-skills", "path": "skills/web-design-guidelines", "ref": SHA40, "license": "MIT"},
            {"role": "rules", "repository": "vercel-labs/web-interface-guidelines", "path": "command.md", "ref": SHA40, "license": "MIT"},
        ]
    }
    p = write_skill(tmp_path, fm)
    assert vu.validate_one(p) == []

def test_multi_source_missing_license_invalid(tmp_path):
    fm = {
        "name": "t", "description": "d",
        "origin": {"type": "upstream"},
        "sources": [
            {"role": "wrapper", "repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"},
            {"role": "rules", "repository": "c/d", "path": "y", "ref": SHA40, "license": ""},
        ]
    }
    p = write_skill(tmp_path, fm)
    assert any("license" in e for e in vu.validate_one(p))

def test_both_upstream_and_sources_invalid(tmp_path):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"}, "sources": [{"repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"}]}
    p = write_skill(tmp_path, fm)
    assert any("cannot have both" in e for e in vu.validate_one(p))

# ---- Pure prompt with no CVE ----

def test_pure_prompt_cve_not_applicable_valid(tmp_path):
    fm = {
        "name": "t", "description": "d",
        "origin": {"type": "upstream"},
        "upstream": {"repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"},
        "security": {"scripts": False, "shell": False, "network": False, "cve_policy": "not-applicable"}
    }
    p = write_skill(tmp_path, fm)
    assert vu.validate_one(p) == []

# ---- Trust / maintenance separation ----

def test_trust_reviewed_maintenance_quiet_valid(tmp_path):
    fm = {
        "name": "t", "description": "d",
        "origin": {"type": "upstream"},
        "upstream": {"repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"},
        "trust": {"tier": "reviewed", "reviewed_at": "2026-08-11", "reviewed_by": "alice"},
        "maintenance": {"status": "quiet", "last_activity": "2025-01-01"},
    }
    p = write_skill(tmp_path, fm)
    assert vu.validate_one(p) == []

def test_deprecated_verified_alias_still_passes(tmp_path):
    fm = {
        "name": "t", "description": "d",
        "origin": {"type": "upstream"},
        "upstream": {"repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"},
        "trust": {"tier": "verified"}
    }
    p = write_skill(tmp_path, fm)
    # verified is deprecated alias for reviewed — should not error
    assert vu.validate_one(p) == []

# ---- Distribution mode semantics ----

@pytest.mark.parametrize("mode", ["vendored", "external", "native-plugin", "generated"])
def test_distribution_modes_valid(tmp_path, mode):
    fm = {"name": "t", "description": "d", "origin": {"type": "first-party"}, "distribution": {"mode": mode}}
    # first-party with distribution is allowed (mode indicates how it's delivered)
    p = write_skill(tmp_path, fm)
    # For first-party, distribution mode is okay
    assert vu.validate_one(p) == []

def test_distribution_invalid_mode(tmp_path):
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHA40, "license": "MIT"}, "distribution": {"mode": "bundled"}}
    p = write_skill(tmp_path, fm)
    assert any("distribution.mode" in e for e in vu.validate_one(p))

# ---- Gate 10: Non-skill fixtures ----

def test_non_skill_agent_provenance():
    data = {
        "origin": {"type": "upstream"},
        "capability": {"kind": "agent", "id": "security-reviewer"},
        "upstream": {"repository": "example/agents", "path": "agents/security", "ref": SHA40, "license": "MIT"}
    }
    assert vu.validate_capability_fixture(data, "agent") == []

def test_non_skill_mcp_provenance():
    data = {
        "origin": {"type": "upstream"},
        "capability": {"kind": "mcp", "id": "slack"},
        "sources": [
            {"repository": "example/mcp", "path": "servers/slack", "ref": SHA40, "license": "Apache-2.0"}
        ]
    }
    assert vu.validate_capability_fixture(data, "mcp") == []

def test_non_skill_hook_provenance():
    data = {
        "origin": {"type": "first-party"},
        "capability": {"kind": "hook", "id": "pre-commit-validate"}
    }
    assert vu.validate_capability_fixture(data, "hook") == []

def test_non_skill_plugin_provenance():
    data = {
        "origin": {"type": "upstream"},
        "capability": {"kind": "plugin", "id": "my-plugin"},
        "upstream": {"repository": "example/plugin", "path": "plugin", "ref": "v2.0.0", "commit": SHA40, "license": "MIT"}
    }
    assert vu.validate_capability_fixture(data, "plugin") == []

# ---- Gate 13: Schema vs validator agreement ----

def test_schema_and_validator_agree_on_valid_skill(tmp_path):
    from referencing import Registry, Resource
    registry = Registry().with_resource(
        uri="https://raw.githubusercontent.com/ulises-jeremias/agent-toolkit/main/schemas/upstream.schema.json",
        resource=Resource.from_contents(UPSTREAM_SCHEMA)
    )
    registry = registry.with_resource(uri="upstream.schema.json", resource=Resource.from_contents(UPSTREAM_SCHEMA))
    validator = Draft202012Validator(SKILL_FRONTMATTER_SCHEMA, registry=registry)
    # Valid first-party
    instance = {"name": "test", "description": "d", "origin": {"type": "first-party"}}
    validator.validate(instance)  # should not raise
    fm = {"name": "test", "description": "d", "origin": {"type": "first-party"}}
    p = write_skill(tmp_path, fm)
    assert vu.validate_one(p) == []

def test_schema_rejects_short_sha_validator_also(tmp_path):
    from referencing import Registry, Resource
    registry = Registry().with_resource(
        uri="https://raw.githubusercontent.com/ulises-jeremias/agent-toolkit/main/schemas/upstream.schema.json",
        resource=Resource.from_contents(UPSTREAM_SCHEMA)
    )
    registry = registry.with_resource(uri="upstream.schema.json", resource=Resource.from_contents(UPSTREAM_SCHEMA))
    validator = Draft202012Validator(SKILL_FRONTMATTER_SCHEMA, registry=registry)
    instance_bad = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHORT7, "license": "MIT"}}
    schema_fails = False
    try:
        validator.validate(instance_bad)
    except jsonschema.ValidationError:
        schema_fails = True
    fm = {"name": "t", "description": "d", "origin": {"type": "upstream"}, "upstream": {"repository": "a/b", "path": "x", "ref": SHORT7, "license": "MIT"}}
    p = write_skill(tmp_path, fm)
    validator_fails = len(vu.validate_one(p)) > 0
    assert schema_fails and validator_fails, "both schema and validator should reject short SHA"

def test_policy_exceeds_schema_documented(tmp_path):
    # Policy: origin required for every skill, but schema makes it optional for backwards compat.
    # Documented in validator: schema allows missing origin, validator rejects.
    from referencing import Registry, Resource
    registry = Registry().with_resource(
        uri="https://raw.githubusercontent.com/ulises-jeremias/agent-toolkit/main/schemas/upstream.schema.json",
        resource=Resource.from_contents(UPSTREAM_SCHEMA)
    )
    registry = registry.with_resource(uri="upstream.schema.json", resource=Resource.from_contents(UPSTREAM_SCHEMA))
    validator = Draft202012Validator(SKILL_FRONTMATTER_SCHEMA, registry=registry)
    instance_no_origin = {"name": "t", "description": "d"}
    # Schema should pass (optional)
    validator.validate(instance_no_origin)
    # Validator should fail (policy)
    fm = {"name": "t", "description": "d"}
    p = write_skill(tmp_path, fm)
    assert len(vu.validate_one(p)) > 0
    # This is intentional documented divergence per gate 13
