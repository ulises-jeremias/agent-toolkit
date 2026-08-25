"""Validate profiles/<tool>/agents parity with canonical agents/."""

import pathlib

REPO = pathlib.Path(__file__).resolve().parent.parent
CANONICAL = {p.name for p in (REPO / "agents").iterdir() if p.is_dir()}

# Profiles that should mirror canonical agents (hand-maintained, legacy)
PROFILE_MAP = {
    "profiles/claude-code/agents": ".md",
    "profiles/opencode/agents": ".md",
    "profiles/cursor/rules": ".mdc",
    "profiles/windsurf/rules": ".mdc",
}


def test_canonical_agents_exist():
    assert len(CANONICAL) >= 1, f"expected at least one canonical agent, got {CANONICAL}"
    # Each entry in agents/ must have an AGENT.md; validator enforces name==dir and valid frontmatter.
    # Count is derived dynamically — docs/SKILL_ROUTING and catalogs/agent-catalog.yaml are source of truth, not hardcoded numbers.


def test_no_contribution_planner_in_profiles():
    for base in ["profiles/claude-code/agents", "profiles/opencode/agents"]:
        assert not (REPO / base / "contribution-planner.md").exists(), (
            f"{base}/contribution-planner.md should be removed (belongs to agentic-workstation, not toolkit)"
        )


def test_claude_settings_has_no_inline_agents():
    import json

    data = json.loads((REPO / "profiles/claude-code/settings.json").read_text())
    assert "agents" not in data, (
        "settings.json should not define inline agents (use agents/*.md + compiled plugins)"
    )


# Post-#869, deprecated profiles are synchronized to canonical 18 for harness-specific adapter correctness
# (ADR-004 fallback). Build output remains canonical, but profiles must not drift.
def test_profile_parity_documented():
    for rel, suffix in PROFILE_MAP.items():
        present = {p.stem for p in (REPO / rel).glob(f"*{suffix}")}
        missing = CANONICAL - present
        extra = present - CANONICAL
        assert missing == set(), f"{rel}: missing agents vs canonical {sorted(missing)}"
        assert extra == set(), f"{rel}: extra agents not in canonical {sorted(extra)}"


def test_archived_agents_not_in_profiles():
    """#865 archived 7 specialists -> references, not agents. Profiles must not contain them."""
    archived = {
        "database-reviewer",
        "performance-optimizer",
        "refactor-cleaner",
        "docs-lookup",
        "reference-lookup",
        "typescript-reviewer",
        "tech-assistant",
    }
    for rel, suffix in PROFILE_MAP.items():
        present = {p.stem for p in (REPO / rel).glob(f"*{suffix}")}
        found = archived & present
        assert found == set(), f"{rel}: archived agents still present {sorted(found)}"


def test_pi_profile_parity():
    """Pi (Tier B) now ships full 18 agents-as-skills per #869."""
    present = {p.name for p in (REPO / "profiles/pi/skills").iterdir() if p.is_dir()}
    missing = CANONICAL - present
    extra = present - CANONICAL
    assert missing == set(), f"profiles/pi/skills: missing {sorted(missing)}"
    assert extra == set(), f"profiles/pi/skills: extra {sorted(extra)}"
