"""Docs and catalog tier labels must match loop.yaml mutation-safety tiers."""
from __future__ import annotations

from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

REPO_ROOT = Path(__file__).resolve().parents[1]
LOOPS_DIR = REPO_ROOT / "loops"
CATALOG_PATH = REPO_ROOT / "catalogs" / "loop-catalog.yaml"

# README loop templates table (Tier column) — mutation tier, not cadence.
README_TIERS: dict[str, str] = {
    "issue-triage": "L1",
    "oss-triage": "L1",
    "oss-daily-briefing": "L1",
    "changelog-drafter": "L1",
    "daily-triage": "L1",
    "ci-sweeper": "L2",
    "dep-sweeper": "L2",
    "post-merge-cleanup": "L2",
    "pr-babysitter": "L2",
    "oss-pr-monitor": "L3",
}


def _loop_tiers_from_yaml() -> dict[str, str]:
    tiers: dict[str, str] = {}
    for path in sorted(LOOPS_DIR.glob("*/loop.yaml")):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        tiers[path.parent.name] = str(data["tier"]).upper()
    return tiers


def test_catalog_tiers_match_loop_yaml() -> None:
    catalog = yaml.safe_load(CATALOG_PATH.read_text(encoding="utf-8"))
    yaml_tiers = _loop_tiers_from_yaml()
    for entry in catalog.get("loops", []):
        name = entry["name"]
        assert name in yaml_tiers, f"catalog entry {name} has no loops/{name}/loop.yaml"
        assert str(entry["tier"]).upper() == yaml_tiers[name], (
            f"catalog tier for {name} ({entry['tier']}) != loop.yaml ({yaml_tiers[name]})"
        )


def test_readme_inventory_tiers_match_loop_yaml() -> None:
    yaml_tiers = _loop_tiers_from_yaml()
    for name, expected in README_TIERS.items():
        assert name in yaml_tiers
        assert yaml_tiers[name] == expected.upper(), (
            f"{name}: README expects {expected}, loop.yaml has {yaml_tiers[name]}"
        )


def test_merge_close_requires_l3() -> None:
    from agent_toolkit.loop.gh_gate import tier_forbids

    for path in LOOPS_DIR.glob("*/loop.yaml"):
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
        allow = {str(a).lower() for a in (data.get("allowlist") or [])}
        if allow & {"merge", "close"}:
            tier = str(data["tier"]).upper()
            assert tier.startswith("L3"), (
                f"{path.parent.name} allowlists merge/close but tier is {tier}"
            )
            assert tier_forbids(tier, "merge") is None
            assert tier_forbids(tier, "close") is None
