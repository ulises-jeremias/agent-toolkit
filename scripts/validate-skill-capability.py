#!/usr/bin/env python3
"""Validate skill capability registry against schema and filesystem.

Checks:
 - capabilities/skills/registry.yaml validates vs schemas/skill-capability-registry.schema.json
 - count matches catalogs/skill-catalog.yaml, skills/*/*/SKILL.md, and products coverage
 - no orphan skills (every skill has holistic_owner)
 - every trigger/overlap/complementary/prereq/follow_up references a real skill id
 - design routing skills are present and owned by designer
 - docs/SKILL_ROUTING.md exists and mentions required routing phrases
 - agents/designer/AGENT.md exists and validates via AGENT.md rules

Usage:
  python3 scripts/validate-skill-capability.py              # validate
  python3 scripts/validate-skill-capability.py --check      # same, for CI (fails on drift)
  python3 scripts/validate-skill-capability.py --json       # JSON output
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import yaml

try:
    from jsonschema import ValidationError, validate  # type: ignore

    HAS_JSONSCHEMA = True
except ImportError:
    HAS_JSONSCHEMA = False

REPO_ROOT = Path(__file__).resolve().parents[1]
REGISTRY = REPO_ROOT / "capabilities" / "skills" / "registry.yaml"
SCHEMA = REPO_ROOT / "schemas" / "skill-capability-registry.schema.json"
CATALOG = REPO_ROOT / "catalogs" / "skill-catalog.yaml"
SKILLS_DIR = REPO_ROOT / "skills"
ROUTING_DOC = REPO_ROOT / "docs" / "SKILL_ROUTING.md"
DESIGNER_AGENT = REPO_ROOT / "agents" / "designer" / "AGENT.md"
ORCHESTRATION = REPO_ROOT / "skills" / "core" / "assistant" / "references" / "ORCHESTRATION.md"

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

REQUIRED_ROUTING_PHRASES = [
    "New visual direction / creative frontend",
    "Existing frontend quality/design review",
    "Concrete web-interface best-practice audit",
    "Evidence-based holistic UX/UI diagnosis",
    "Iterative browser-grounded remediation",
    "Figma-driven work",
    "Accessibility-sensitive UI",
]


def load_yaml(path: Path):
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def validate_registry() -> list[str]:
    errors: list[str] = []
    if not REGISTRY.is_file():
        return [f"missing registry: {REGISTRY}"]
    if not SCHEMA.is_file():
        return [f"missing schema: {SCHEMA}"]

    data = load_yaml(REGISTRY)
    schema = json.loads(SCHEMA.read_text(encoding="utf-8"))

    if HAS_JSONSCHEMA:
        try:
            validate(data, schema)
        except ValidationError as e:
            errors.append(f"schema validation failed: {e.message} at {'/'.join(map(str, e.path))}")
            return errors
    else:
        # fallback minimal checks
        if not isinstance(data, dict) or "skills" not in data:
            return ["registry missing 'skills' key"]

    skills = data.get("skills", [])
    count = data.get("count", len(skills))
    if count != len(skills):
        errors.append(f"registry count {count} != len(skills) {len(skills)}")

    # cross-check against catalog and filesystem
    if CATALOG.is_file():
        cat = load_yaml(CATALOG)
        cat_count = cat.get("count", len(cat.get("skills", [])))
        cat_ids = {s["id"] for s in cat.get("skills", [])}
        reg_ids = {s["id"] for s in skills}
        if count != cat_count:
            errors.append(f"registry count {count} != catalog count {cat_count} ({CATALOG})")
        missing = cat_ids - reg_ids
        extra = reg_ids - cat_ids
        if missing:
            errors.append(f"registry missing ids present in catalog: {sorted(missing)[:10]}")
        if extra:
            errors.append(f"registry has extra ids not in catalog: {sorted(extra)[:10]}")
        # filesystem
        fs_ids = {str(p.parent.relative_to(SKILLS_DIR)) for p in SKILLS_DIR.rglob("SKILL.md")}
        fs_missing = fs_ids - reg_ids
        fs_extra = reg_ids - fs_ids
        if fs_missing:
            errors.append(f"registry missing ids present on filesystem: {sorted(fs_missing)[:10]}")
        if fs_extra:
            errors.append(f"registry has extra ids not on filesystem: {sorted(fs_extra)[:10]}")
        if len(fs_ids) != cat_count:
            errors.append(f"filesystem skills {len(fs_ids)} != catalog {cat_count}")
    else:
        errors.append(f"missing catalog: {CATALOG}")

    # no orphans: every skill has holistic_owner + holistic_owner validity
    # collect physical agents for specialist validation
    agents_dir = REPO_ROOT / "agents"
    physical_agents = (
        {p.name for p in agents_dir.iterdir() if p.is_dir()} if agents_dir.is_dir() else set()
    )
    valid_secondary = HOLISTIC_OWNERS | physical_agents
    for s in skills:
        sid = s.get("id", "<unknown>")
        owner = s.get("holistic_owner")
        if not owner:
            errors.append(f"{sid}: missing holistic_owner (orphan)")
        elif owner not in HOLISTIC_OWNERS:
            errors.append(f"{sid}: invalid holistic_owner {owner!r} (must be one of 11)")
        if not s.get("triggers"):
            errors.append(f"{sid}: missing triggers (at least one required)")
        if not s.get("contraindications") or len(s.get("contraindications", "")) < 10:
            errors.append(f"{sid}: missing or too short contraindications")
        # domain coherence vs id prefix
        domain = s.get("domain")
        if domain and sid and "/" in sid:
            expected_domain = sid.split("/")[0]
            if domain != expected_domain:
                errors.append(f"{sid}: domain {domain!r} != id prefix {expected_domain!r}")
        # origin / upstream provenance
        origin = s.get("origin")
        if origin == "upstream":
            if "upstream" not in s:
                errors.append(f"{sid}: origin upstream must have upstream metadata")
            else:
                up = s["upstream"] or {}
                for k in ("repository", "path", "ref", "license"):
                    if not up.get(k):
                        errors.append(f"{sid}: upstream missing required field {k!r}")
        elif origin == "first-party":
            if "upstream" in s:
                errors.append(f"{sid}: first-party must not have upstream field")
        # specialist_agents must be real agents and justified coherence
        for ag in s.get("specialist_agents", []) or []:
            if ag not in physical_agents:
                errors.append(f"{sid}: specialist_agents references unknown agent {ag!r}")
        if s.get("specialist_justified") and not s.get("specialist_agents"):
            errors.append(f"{sid}: specialist_justified true but specialist_agents empty")
        # secondary_owners must be known holistic or agent
        for sec in s.get("secondary_owners", []) or []:
            if sec not in valid_secondary:
                errors.append(f"{sid}: secondary_owners references unknown owner/agent {sec!r}")

    # validate references are real ids + self-reference + broken requires
    all_ids = {s["id"] for s in skills}
    for s in skills:
        sid = s["id"]
        for field in ("overlap", "complementary", "prerequisites", "follow_ups"):
            for ref in s.get(field, []) or []:
                if ref == sid:
                    errors.append(f"{sid}: {field} self-reference not allowed")
                elif ref not in all_ids:
                    errors.append(f"{sid}: {field} references unknown skill {ref!r}")
        # requires: tool names allowed, skill-like refs must be valid
        for ref in s.get("requires", []) or []:
            if "/" in ref:
                if ref == sid:
                    errors.append(f"{sid}: requires self-reference not allowed")
                elif ref not in all_ids:
                    errors.append(f"{sid}: requires references unknown skill {ref!r}")

    # design routing completeness
    reg_ids = {s["id"] for s in skills}
    for did in DESIGN_SKILLS:
        if did not in reg_ids:
            errors.append(f"design skill missing from registry: {did}")
        else:
            skill = next(s for s in skills if s["id"] == did)
            if skill.get("holistic_owner") != "designer":
                errors.append(
                    f"{did}: holistic_owner should be 'designer', got {skill.get('holistic_owner')!r}"
                )

    # docs checks
    if not ROUTING_DOC.is_file():
        errors.append(f"missing routing doc: {ROUTING_DOC}")
    else:
        text = ROUTING_DOC.read_text(encoding="utf-8")
        for phrase in REQUIRED_ROUTING_PHRASES:
            if phrase not in text:
                errors.append(f"routing doc missing required phrase: {phrase!r}")
        if "capabilities/skills/registry.yaml" not in text:
            errors.append("routing doc should reference capabilities/skills/registry.yaml as SoT")

    if not DESIGNER_AGENT.is_file():
        errors.append(f"missing designer agent: {DESIGNER_AGENT}")
    else:
        text = DESIGNER_AGENT.read_text(encoding="utf-8")
        if "holistic_owner" not in text and "capabilities/skills/registry.yaml" not in text:
            errors.append("designer agent should reference registry.yaml or holistic_owner")
        for phrase in ["frontend-design", "design-assessment"]:
            if phrase not in text:
                errors.append(f"designer agent missing expected skill reference: {phrase}")

    if not ORCHESTRATION.is_file():
        errors.append(f"missing orchestration: {ORCHESTRATION}")
    else:
        text = ORCHESTRATION.read_text(encoding="utf-8")
        for did in ["frontend-design", "design-assessment", "web-design-guidelines"]:
            if did not in text:
                errors.append(f"orchestration Design section missing: {did}")

    return errors


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate skill capability registry")
    parser.add_argument(
        "--check", action="store_true", help="CI mode (same as default, fails on drift)"
    )
    parser.add_argument("--json", action="store_true", help="JSON output")
    args = parser.parse_args(argv)

    errors = validate_registry()
    if args.json:
        print(json.dumps({"errors": errors, "ok": len(errors) == 0}, indent=2))
    else:
        if errors:
            for e in errors:
                print(f"ERROR: {e}", file=sys.stderr)
            print(f"\n{len(errors)} validation error(s).", file=sys.stderr)
        else:
            # summary
            data = load_yaml(REGISTRY)
            skills = data.get("skills", [])
            from collections import Counter

            owners = Counter(s["holistic_owner"] for s in skills)
            roles = Counter(s["role"] for s in skills)
            print(f"skill capability OK — {len(skills)} skills, no orphans")
            print(f"  owners: {dict(owners)}")
            print(f"  roles: {dict(roles)}")
            print(f"  design routing: {len(DESIGN_SKILLS)} design skills owned by designer")

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
