"""
Author: RawNuke
Copyright (c) 2026 RawNuke. All rights reserved.

Contract tests for packs skills/agents advisory status.
Skills/agents in pack config.yaml are docs-only; loop/pack.py does not apply them.
"""

from __future__ import annotations

from pathlib import Path

import yaml

from agent_toolkit.loop.pack import apply_loop_pack_overrides, load_pack


def test_apply_loop_pack_overrides_does_not_merge_skills() -> None:
    """Skills key in pack data must not appear in merged loop meta."""
    meta: dict[str, object] = {"tier": "L1", "cadence": "1d"}
    pack_data: dict[str, object] = {
        "skills": {"forge/workflow-generic-project": {"enabled": True}},
        "loops": {"demo": {"enabled": True, "cadence": "15m"}},
    }
    merged = apply_loop_pack_overrides(meta, pack_data, "demo")
    assert "skills" not in merged
    assert merged["cadence"] == "15m"


def test_apply_loop_pack_overrides_does_not_merge_agents() -> None:
    """Agents key in pack data must not appear in merged loop meta."""
    meta: dict[str, object] = {"tier": "L2", "cadence": "1d"}
    pack_data: dict[str, object] = {
        "agents": {"architect": {"enabled": True}},
        "loops": {"demo": {"enabled": True, "cadence": "6h"}},
    }
    merged = apply_loop_pack_overrides(meta, pack_data, "demo")
    assert "agents" not in merged
    assert merged["cadence"] == "6h"


def test_top_level_skills_agents_never_leak_into_merged_meta() -> None:
    """Even when pack has skills, agents, and loops at top level, only loop keys merge."""
    meta: dict[str, object] = {
        "tier": "L1",
        "cadence": "1d",
        "goal": "do work",
        "budget": {"max_tokens": 80000},
    }
    pack_data: dict[str, object] = {
        "pack": "test",
        "skills": {"delivery/task": {"enabled": True}},
        "agents": {"planner": {"enabled": True}},
        "loops": {
            "test-loop": {
                "enabled": True,
                "cadence": "30m",
                "budget": {"max_wall_seconds": 300},
            }
        },
    }
    merged = apply_loop_pack_overrides(meta, pack_data, "test-loop")
    assert "skills" not in merged
    assert "agents" not in merged
    assert merged["cadence"] == "30m"
    assert merged["budget"]["max_wall_seconds"] == 300
    assert merged["goal"] == "do work"


def test_missing_loop_entry_returns_original_meta_unchanged() -> None:
    """When a loop name is not in pack data, meta returns unchanged with no skills/agents."""
    meta: dict[str, object] = {"tier": "L3", "cadence": "2d"}
    pack_data: dict[str, object] = {
        "skills": {"core/memory": {"enabled": True}},
        "agents": {"code-reviewer": {"enabled": True}},
    }
    merged = apply_loop_pack_overrides(meta, pack_data, "nonexistent")
    assert merged == meta
    assert "skills" not in merged
    assert "agents" not in merged


def test_pack_skills_and_agents_are_advisory_in_all_pack_configs() -> None:
    """Every pack config.yaml with skills: or agents: must state they are advisory."""
    repo_root = Path(__file__).resolve().parent.parent
    packs_dir = repo_root / "packs"
    configs = sorted(packs_dir.glob("*/config.yaml"))

    assert len(configs) >= 1, "Expected at least one pack config.yaml"

    for config_path in configs:
        text = config_path.read_text(encoding="utf-8")
        data = yaml.safe_load(text)

        has_skills = "skills" in data
        has_agents = "agents" in data

        if has_skills or has_agents:
            assert "advisory" in text.lower() or "not applied" in text.lower(), (
                f"{config_path.relative_to(repo_root)} has skills: or agents: "
                "but does not state they are advisory"
            )


def test_load_pack_preserves_skills_and_agents_keys() -> None:
    """load_pack returns the raw YAML dict including skills and agents keys."""
    import tempfile

    with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False, encoding="utf-8") as f:
        f.write(
            "pack: test\n"
            "skills:\n  forge/test:\n    enabled: true\n"
            "agents:\n  reviewer:\n    enabled: true\n"
            "loops:\n  loop-a:\n    enabled: true\n"
        )
        tmp_path = Path(f.name)

    try:
        data = load_pack(tmp_path)
        assert data["pack"] == "test"
        assert "skills" in data
        assert "agents" in data
        assert "loops" in data
    finally:
        tmp_path.unlink(missing_ok=True)
