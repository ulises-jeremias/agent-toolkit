"""Contract tests for pack composition in agent_toolkit.loop.pack.

Author: RawNuke
Copyright (c) 2026 RawNuke. All rights reserved.

Covers pack path resolution, YAML loading (with the simple-parser fallback),
loop entry lookup and the loop override merge matrix. Focus is the
resolution and merge behaviour; skills/agents advisory keys are covered by
test_pack_skills_agents_advisory.py and are not duplicated here.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

from agent_toolkit.loop.pack import (
    apply_loop_pack_overrides,
    load_pack,
    loop_pack_entry,
    resolve_pack_path,
)


class TestResolvePackPath:
    def test_absolute_existing_file_returns_path(self, tmp_path: Path) -> None:
        target = tmp_path / "pack.yaml"
        target.write_text("name: demo\n", encoding="utf-8")
        assert resolve_pack_path(target, tmp_path) == target

    def test_absolute_missing_file_returns_none(self, tmp_path: Path) -> None:
        target = tmp_path / "missing.yaml"
        assert resolve_pack_path(target, tmp_path) is None

    def test_relative_bare_name_resolves_under_workspace(self, tmp_path: Path) -> None:
        (tmp_path / "demo.yaml").write_text("name: demo\n", encoding="utf-8")
        assert resolve_pack_path("demo.yaml", tmp_path) == tmp_path / "demo.yaml"

    def test_packs_prefix_resolution(self, tmp_path: Path) -> None:
        packs = tmp_path / "packs"
        packs.mkdir()
        (packs / "demo.yaml").write_text("name: demo\n", encoding="utf-8")
        assert resolve_pack_path("packs/demo.yaml", tmp_path) == packs / "demo.yaml"

    def test_packs_name_resolves_under_packs_dir(self, tmp_path: Path) -> None:
        packs = tmp_path / "packs"
        packs.mkdir()
        (packs / "demo.yaml").write_text("name: demo\n", encoding="utf-8")
        assert resolve_pack_path("demo", tmp_path) == packs / "demo.yaml"

    def test_packs_name_with_extension_resolves(self, tmp_path: Path) -> None:
        packs = tmp_path / "packs"
        packs.mkdir()
        (packs / "demo.yaml").write_text("name: demo\n", encoding="utf-8")
        assert resolve_pack_path("demo.yaml", tmp_path) == packs / "demo.yaml"

    def test_no_match_returns_none(self, tmp_path: Path) -> None:
        assert resolve_pack_path("nope", tmp_path) is None


class TestLoadPack:
    def test_yaml_dict_loads(self, tmp_path: Path) -> None:
        pack_path = tmp_path / "pack.yaml"
        pack_path.write_text("name: demo\nloops:\n  a:\n    enabled: true\n", encoding="utf-8")
        data = load_pack(pack_path)
        assert data["name"] == "demo"
        assert data["loops"]["a"]["enabled"] is True

    def test_non_dict_yaml_returns_empty(self, tmp_path: Path) -> None:
        pack_path = tmp_path / "list.yaml"
        pack_path.write_text("- a\n- b\n", encoding="utf-8")
        assert load_pack(pack_path) == {}

    def test_scalar_yaml_returns_empty(self, tmp_path: Path) -> None:
        pack_path = tmp_path / "scalar.yaml"
        pack_path.write_text("just a string\n", encoding="utf-8")
        assert load_pack(pack_path) == {}

    def test_simple_parser_fallback(self, tmp_path: Path, monkeypatch: Any) -> None:
        """Without PyYAML, flat keys, budget sub-keys and lists still parse."""
        pack_path = tmp_path / "pack.yaml"
        pack_path.write_text(
            "name: demo\ntier: L1\ncadence: 1d\nbudget:\n  max_tokens: 50000\ndeny:\n  - merge\n",
            encoding="utf-8",
        )
        monkeypatch.setitem(sys.modules, "yaml", None)
        data = load_pack(pack_path)
        assert data["name"] == "demo"
        assert data["tier"] == "L1"
        assert data["cadence"] == "1d"
        assert data["budget"] == {"max_tokens": 50000}
        assert data["deny"] == ["merge"]


class TestLoopPackEntry:
    def test_missing_loops_key_returns_empty(self) -> None:
        assert loop_pack_entry({"pack": "demo"}, "a") == {}

    def test_loop_name_not_present_returns_empty(self) -> None:
        assert loop_pack_entry({"loops": {"a": {"enabled": True}}}, "b") == {}

    def test_non_dict_loops_returns_empty(self) -> None:
        assert loop_pack_entry({"loops": ["a", "b"]}, "a") == {}
        assert loop_pack_entry({"loops": "demo"}, "a") == {}

    def test_valid_entry_returned(self) -> None:
        entry = {"enabled": True, "cadence": "15m"}
        assert loop_pack_entry({"loops": {"a": entry}}, "a") == entry


class TestApplyLoopPackOverrides:
    def _meta(self) -> dict[str, Any]:
        return {
            "enabled": True,
            "cadence": "1d",
            "tier": "L1",
            "verifier": None,
            "goal": "old goal",
            "budget": {"max_tokens": 50000},
            "request": "keep me",
        }

    def test_merges_only_allowed_keys(self) -> None:
        pack_data: dict[str, Any] = {
            "loops": {
                "a": {
                    "enabled": True,
                    "cadence": "15m",
                    "tier": "L2",
                    "verifier": "reviewer",
                    "goal": "new goal",
                }
            }
        }
        merged = apply_loop_pack_overrides(self._meta(), pack_data, "a")
        assert merged["enabled"] is True
        assert merged["cadence"] == "15m"
        assert merged["tier"] == "L2"
        assert merged["verifier"] == "reviewer"
        assert merged["goal"] == "new goal"
        assert merged["request"] == "keep me"

    def test_budget_merges_on_top_of_meta_budget(self) -> None:
        pack_data: dict[str, Any] = {
            "loops": {"a": {"budget": {"max_wall_seconds": 600, "max_runs_per_day": 2}}}
        }
        merged = apply_loop_pack_overrides(self._meta(), pack_data, "a")
        assert merged["budget"] == {
            "max_tokens": 50000,
            "max_wall_seconds": 600,
            "max_runs_per_day": 2,
        }

    def test_budget_added_when_meta_has_no_budget(self) -> None:
        meta = self._meta()
        meta["budget"] = {}
        pack_data: dict[str, Any] = {"loops": {"a": {"budget": {"max_tokens": 100}}}}
        merged = apply_loop_pack_overrides(meta, pack_data, "a")
        assert merged["budget"] == {"max_tokens": 100}

    def test_entry_enabled_false_forces_false(self) -> None:
        pack_data: dict[str, Any] = {"loops": {"a": {"enabled": False, "cadence": "2d"}}}
        merged = apply_loop_pack_overrides(self._meta(), pack_data, "a")
        assert merged["enabled"] is False
        assert merged["cadence"] == "2d"

    def test_unknown_keys_are_ignored(self) -> None:
        pack_data: dict[str, Any] = {"loops": {"a": {"skills": {"x": 1}, "agents": {"y": 2}}}}
        merged = apply_loop_pack_overrides(self._meta(), pack_data, "a")
        assert "skills" not in merged
        assert "agents" not in merged

    def test_no_entry_returns_copy_without_mutating_input(self) -> None:
        meta = self._meta()
        pack_data: dict[str, Any] = {"loops": {"a": {"enabled": False}}}
        merged = apply_loop_pack_overrides(meta, pack_data, "missing")
        assert merged == meta
        assert merged is not meta
        assert meta["enabled"] is True
