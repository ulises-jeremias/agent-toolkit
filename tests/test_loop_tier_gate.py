"""Gate/tier consistency for loops that allowlist merge/close."""

from __future__ import annotations

from pathlib import Path

import pytest

yaml = pytest.importorskip("yaml")

from agent_toolkit.loop.gh_gate import evaluate_action, tier_forbids  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[1]


def test_l1_forbids_all_mutations() -> None:
    for action in ("merge", "close", "comment", "label"):
        assert tier_forbids("L1", action)
        ok, _ = evaluate_action(
            action,
            tier="L1",
            allowlist=[action],
            deny=[],
        )
        assert ok is False


def test_l2_forbids_merge_and_close() -> None:
    assert tier_forbids("L2", "merge")
    assert tier_forbids("L2", "close")
    ok, reason = evaluate_action(
        "merge",
        tier="L2",
        allowlist=["merge", "close", "comment", "label"],
        deny=[],
    )
    assert ok is False
    assert "L2" in reason


def test_l3_allows_allowlisted_merge() -> None:
    assert tier_forbids("L3", "merge") is None
    ok, reason = evaluate_action(
        "merge",
        tier="L3",
        allowlist=["merge", "close", "comment", "label"],
        deny=["approve"],
    )
    assert ok is True
    assert reason == "allowlisted"


def test_oss_pr_monitor_tier_allows_its_allowlist() -> None:
    loop_path = REPO_ROOT / "loops" / "oss-pr-monitor" / "loop.yaml"
    data = yaml.safe_load(loop_path.read_text(encoding="utf-8"))
    tier = str(data["tier"]).upper()
    allow = list(data.get("allowlist") or [])
    deny = list(data.get("deny") or [])
    assert tier.startswith("L3"), f"oss-pr-monitor must be L3, got {tier}"
    for action in ("merge", "close"):
        assert action in allow
        ok, reason = evaluate_action(action, tier=tier, allowlist=allow, deny=deny)
        assert ok is True, f"{action} blocked at {tier}: {reason}"
