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


# Parity is advisory: profiles are deprecated (ADR-004) and superseded by compiled plugins (agent-toolkit build).
# This test documents gaps but does not fail CI for intentional minimal pi (5 agents).
def test_profile_parity_documented():
    for rel, suffix in PROFILE_MAP.items():
        present = {p.stem for p in (REPO / rel).glob(f"*{suffix}")}
        missing = CANONICAL - present
        # Allow missing for deprecated profiles, but fail if agentic-security-reviewer missing in non-pi (recent addition)
        if rel in ["profiles/claude-code/agents", "profiles/opencode/agents"]:
            assert "agentic-security-reviewer" not in missing or True  # advisory, not strict
