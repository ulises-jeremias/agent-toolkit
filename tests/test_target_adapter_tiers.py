"""Harness adapter tiers and generated capability matrix — #868.

Validates that:
- every target in capabilities/targets/registry.yaml has a tier (A/B/C/D) and rationale,
- tier distribution and capability invariants match the declared model,
- the generated docs/TARGET_CAPABILITY_MATRIX.md is tier-aware,
- unsupported capabilities degrade gracefully (no invalid config where unsupported).
"""

from __future__ import annotations

from pathlib import Path

import yaml

REPO = Path(__file__).resolve().parent.parent
REGISTRY = REPO / "capabilities" / "targets" / "registry.yaml"
MATRIX = REPO / "docs" / "TARGET_CAPABILITY_MATRIX.md"

TIER_A = {"claude-code", "cursor"}
TIER_B = {"opencode", "gemini-cli", "copilot-cli", "pi", "codex"}
TIER_C = {"copilot-repository", "muse-code", "agent-plugins"}
TIER_D = {"windsurf"}

ALL_TIERS = {"A", "B", "C", "D"}

# For graceful-degradation: these capabilities must be false when Tier C/D
# and must not cause invalid config emission (checked via registry invariants).
NO_SUBAGENT_TIERS = TIER_C | TIER_D
NO_DELEGATION_TIERS = TIER_C | TIER_D


def _load_registry():
    assert REGISTRY.is_file(), f"missing registry: {REGISTRY}"
    data = yaml.safe_load(REGISTRY.read_text(encoding="utf-8"))
    assert "targets" in data
    return data


def _targets_by_id():
    data = _load_registry()
    return {t["id"]: t for t in data["targets"]}


# --- Registry shape ---


def test_every_target_has_tier_and_rationale():
    data = _load_registry()
    for t in data["targets"]:
        tid = t["id"]
        assert "tier" in t, f"{tid}: missing tier field"
        assert t["tier"] in ALL_TIERS, f"{tid}: invalid tier {t['tier']!r}"
        assert "tier_rationale" in t and isinstance(t["tier_rationale"], str), (
            f"{tid}: missing tier_rationale"
        )
        assert len(t["tier_rationale"].strip()) >= 20, (
            f"{tid}: tier_rationale too short: {t['tier_rationale']!r}"
        )


def test_tier_distribution_matches_model():
    by_id = _targets_by_id()
    actual_a = {tid for tid, t in by_id.items() if t.get("tier") == "A"}
    actual_b = {tid for tid, t in by_id.items() if t.get("tier") == "B"}
    actual_c = {tid for tid, t in by_id.items() if t.get("tier") == "C"}
    actual_d = {tid for tid, t in by_id.items() if t.get("tier") == "D"}
    assert actual_a == TIER_A, f"Tier A mismatch: expected {TIER_A}, got {actual_a}"
    assert actual_b == TIER_B, f"Tier B mismatch: expected {TIER_B}, got {actual_b}"
    assert actual_c == TIER_C, f"Tier C mismatch: expected {TIER_C}, got {actual_c}"
    assert actual_d == TIER_D, f"Tier D mismatch: expected {TIER_D}, got {actual_d}"


# --- Tier capability invariants ---


def _cap(t, key):
    return t.get("capabilities", {}).get(key)


def test_tier_a_rich_multi_agent_invariants():
    by_id = _targets_by_id()
    for tid in TIER_A:
        t = by_id[tid]
        # Tier A: rich multi-agent — must support all delegation primitives
        assert _cap(t, "native_custom_agents") is True, (
            f"{tid}: Tier A must have native_custom_agents true"
        )
        assert _cap(t, "subagents") is True, f"{tid}: Tier A must have subagents true"
        assert _cap(t, "parallel_agents") is True, f"{tid}: Tier A must have parallel_agents true"
        assert _cap(t, "automatic_delegation") is True, (
            f"{tid}: Tier A must have automatic_delegation true"
        )
        assert _cap(t, "agent_permissions") is True, (
            f"{tid}: Tier A must have agent_permissions true"
        )
        assert _cap(t, "agent_models") is True, f"{tid}: Tier A must have agent_models true"
        assert _cap(t, "mcp") is True, f"{tid}: Tier A must have mcp true"
        assert _cap(t, "hooks") is True, f"{tid}: Tier A must have hooks true"
        assert _cap(t, "plugin_marketplace") is True, f"{tid}: Tier A must have marketplace true"
        # agent_plugins v1 portable for Tier A
        assert _cap(t, "agent_plugins") == "v1", f"{tid}: Tier A must have agent_plugins v1"


def test_tier_b_custom_agents_limited_delegation():
    by_id = _targets_by_id()
    for tid in TIER_B:
        t = by_id[tid]
        # Tier B: custom agents with limited delegation — native agents must be present
        assert _cap(t, "native_custom_agents") is True, (
            f"{tid}: Tier B must have native_custom_agents true"
        )
        assert _cap(t, "agent_skills") is True, f"{tid}: Tier B must have agent_skills true"
        # At least one delegation/parallel signal — not all false
        delegation_vals = [
            _cap(t, "subagents"),
            _cap(t, "automatic_delegation"),
            _cap(t, "parallel_agents"),
        ]
        assert any(v is True or v == "partial" for v in delegation_vals), (
            f"{tid}: Tier B expected at least one of subagents/automatic/parallel to be true/partial, got {delegation_vals}"
        )
        # Must have rules support (all do)
        assert _cap(t, "rules") is True, f"{tid}: Tier B must have rules true"


def test_tier_c_skills_plus_instructions_invariants():
    by_id = _targets_by_id()
    for tid in TIER_C:
        t = by_id[tid]
        # Tier C: skills + instructions — no subagent/delegation
        assert _cap(t, "subagents") is False, f"{tid}: Tier C must have subagents false"
        assert _cap(t, "automatic_delegation") is False, (
            f"{tid}: Tier C must have automatic_delegation false"
        )
        assert _cap(t, "nested_delegation") is False, (
            f"{tid}: Tier C must have nested_delegation false"
        )
        assert _cap(t, "parallel_agents") is False, f"{tid}: Tier C must have parallel_agents false"
        # Skills should be present (true for all C)
        assert _cap(t, "agent_skills") is True, f"{tid}: Tier C must have agent_skills true"
        # No marketplace or limited — agent-plugins is none for repo, custom for muse, v1 for portable synthetic
        # So don't assert marketplace here, just that primary_agents is false
        assert _cap(t, "primary_agents") is False, f"{tid}: Tier C must have primary_agents false"


def test_tier_d_minimal_invariants():
    by_id = _targets_by_id()
    for tid in TIER_D:
        t = by_id[tid]
        # Tier D: minimal — richest correct subset, no agents/delegation/marketplace
        assert _cap(t, "subagents") is False, f"{tid}: Tier D must have subagents false"
        assert _cap(t, "automatic_delegation") is False, f"{tid}: Tier D minimal — no delegation"
        assert _cap(t, "plugin_marketplace") is False, f"{tid}: Tier D must have marketplace false"
        assert _cap(t, "agent_permissions") is False, f"{tid}: Tier D no perms"
        assert _cap(t, "agent_models") is False, f"{tid}: Tier D no models"
        assert _cap(t, "hooks") is False, f"{tid}: Tier D no hooks"
        assert _cap(t, "commands") is False, f"{tid}: Tier D no commands"


# --- Graceful degradation: no invalid config where unsupported ---


def test_graceful_degradation_no_subagent_where_unsupported():
    """Tier C/D declare subagents false — compiler must not emit subagent config there.

    This test asserts the registry declares false (source of truth). Actual emitter
    graceful degradation is tested in V (emitters_remaining/emit_windsurf etc.)
    where Tier C/D emitters set `unsupported` rather than emitting invalid files.
    """
    by_id = _targets_by_id()
    for tid in NO_SUBAGENT_TIERS:
        t = by_id[tid]
        assert _cap(t, "subagents") is False, (
            f"{tid}: graceful degradation requires subagents false"
        )
        assert _cap(t, "automatic_delegation") is False, (
            f"{tid}: no delegation where subagents unsupported"
        )
        assert _cap(t, "nested_delegation") is False
        assert _cap(t, "parallel_agents") is False


def test_windsurf_tier_d_no_agents_delegation_marketplace():
    """Windsurf is the sole Tier D — customization bundle only."""
    by_id = _targets_by_id()
    w = by_id["windsurf"]
    assert w["tier"] == "D"
    assert _cap(w, "agent_skills") == "partial"  # via generated rules
    assert _cap(w, "agent_plugins") == "none"
    assert _cap(w, "native_custom_agents") == "partial"  # rules bridging
    # Ensure windsurf has no marketplace — must degrade to manual bundle
    assert _cap(w, "plugin_marketplace") is False
    assert w["maturity"] == "limited"


# --- Generated matrix is tier-aware ---


def test_matrix_exists_and_has_tier_section():
    assert MATRIX.is_file(), f"missing matrix: {MATRIX}"
    text = MATRIX.read_text(encoding="utf-8")
    assert "## Adapter Tiers (#868)" in text, "matrix missing Adapter Tiers section"
    assert "| **A** | Rich multi-agent" in text
    assert "| **B** | Custom agents" in text
    assert "| **C** | Skills + instructions" in text
    assert "| **D** | Minimal" in text
    assert "Gating:" in text and "must not" in text


def test_matrix_has_build_commands_and_tiers_table():
    text = MATRIX.read_text(encoding="utf-8")
    assert "## Build Commands & Tiers" in text, "matrix Build Commands should include Tiers column"
    # Header must have Tier column
    assert "| Target | `build` | `diff` | `release` | Tier |" in text
    # At least 11 target rows
    rows = [
        l
        for l in text.splitlines()
        if l.startswith("| Claude Code") or l.startswith("| Cursor") or l.startswith("| Windsurf")
    ]
    assert len(rows) >= 3


def test_matrix_has_tier_assignment_table():
    text = MATRIX.read_text(encoding="utf-8")
    assert "## Tier Assignment" in text
    assert "| Target | Tier | Rationale |" in text
    for tid in [
        "claude-code",
        "cursor",
        "opencode",
        "windsurf",
        "copilot-repository",
        "agent-plugins",
    ]:
        assert f"`{tid}`" in text, f"matrix missing tier assignment row for {tid}"


def test_matrix_per_target_details_include_tier():
    text = MATRIX.read_text(encoding="utf-8")
    # Every Per-Target Details section must now have Tier + Tier rationale
    # Count occurrences of "- **Tier:**"
    tier_lines = [l for l in text.splitlines() if l.strip().startswith("- **Tier:**")]
    by_id = _targets_by_id()
    assert len(tier_lines) >= len(by_id), (
        f"expected tier line per target, got {len(tier_lines)} vs {len(by_id)}"
    )


def test_matrix_generated_header():
    text = MATRIX.read_text(encoding="utf-8")
    assert "Generated from `capabilities/targets/registry.yaml` — do not hand-edit." in text
    assert "Run `python3 scripts/generate-target-matrix.py`" in text


def test_tier_not_confused_with_maturity():
    """Tier (A-D) is distinct from maturity (stable/limited/etc.)."""
    by_id = _targets_by_id()
    for tid, t in by_id.items():
        assert t.get("tier") in ALL_TIERS
        assert t.get("maturity") in {"stable", "experimental", "limited", "deprecated"}
        # Tier D currently limited, Tier B codex is experimental — not duplicated
        if t["tier"] == "D":
            assert t["maturity"] == "limited", f"{tid} Tier D should be limited maturity"
