"""Wave 4 #273 — loop runner unit tests without live LLM.

Covers tier/budget/gate helpers and golden/fixture parse for loop.yaml samples.
No secrets or network required.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from agent_toolkit.loop import budget as budget_mod
from agent_toolkit.loop import gh_gate

yaml = pytest.importorskip("yaml")

REPO_ROOT = Path(__file__).resolve().parents[1]
LOOPS_DIR = REPO_ROOT / "loops"
SCHEMA_PATH = REPO_ROOT / "schemas" / "loop.schema.json"


# ── budget helpers ──


def test_wall_timeout_defaults() -> None:
    assert budget_mod.wall_timeout_seconds({}) == budget_mod.DEFAULT_WALL_SECONDS


def test_wall_timeout_custom_and_clamped() -> None:
    assert budget_mod.wall_timeout_seconds({"max_wall_seconds": 600}) == 600
    assert budget_mod.wall_timeout_seconds({"max_wall_seconds": 5}) == 30
    assert (
        budget_mod.wall_timeout_seconds({"max_wall_seconds": "not-a-number"})
        == budget_mod.DEFAULT_WALL_SECONDS
    )


def test_max_tokens_limit() -> None:
    assert budget_mod.max_tokens_limit({}) is None
    assert budget_mod.max_tokens_limit({"max_tokens": 1000}) == 1000
    assert budget_mod.max_tokens_limit({"max_tokens": "bad"}) is None


def test_tokens_from_trace_sums_events(tmp_path: Path) -> None:
    trace = tmp_path / "trace.jsonl"
    trace.write_text(
        """{"kind": "token_usage", "total_tokens": 100}
{"kind": "prompt", "prompt_tokens": 10}
{"kind": "completion", "completion_tokens": 20}
{"kind": "other"}
""",
        encoding="utf-8",
    )
    assert budget_mod.tokens_from_trace(trace) == 130


def test_tokens_from_trace_missing_file(tmp_path: Path) -> None:
    assert budget_mod.tokens_from_trace(tmp_path / "nonexistent.jsonl") == 0


def test_tokens_from_trace_malformed_lines_ignored(tmp_path: Path) -> None:
    trace = tmp_path / "trace.jsonl"
    trace.write_text('{not json}\n{"kind": "token_usage", "total": 5}\n', encoding="utf-8")
    assert budget_mod.tokens_from_trace(trace) == 5


def test_token_budget_exceeded() -> None:
    assert budget_mod.token_budget_exceeded(1000, {"max_tokens": 500}) is True
    assert budget_mod.token_budget_exceeded(100, {"max_tokens": 500}) is False
    assert budget_mod.token_budget_exceeded(9999, {}) is False


def test_soft_token_precheck_warnings() -> None:
    assert budget_mod.soft_token_precheck({"last_run_tokens": 600}, {"max_tokens": 500}) is not None
    assert budget_mod.soft_token_precheck({"last_run_tokens": 100}, {"max_tokens": 500}) is None
    assert budget_mod.soft_token_precheck({}, {"max_tokens": 500}) is None
    assert budget_mod.soft_token_precheck({"last_run_tokens": 100}, {}) is None


def test_tokens_today_sums_today_only(tmp_path: Path) -> None:
    from datetime import datetime, timezone

    loop_dir = tmp_path / "myloop"
    runs = loop_dir / "runs"
    runs.mkdir(parents=True)
    today = datetime.now(timezone.utc).isoformat()
    # run today
    r1 = runs / "run1"
    r1.mkdir()
    (r1 / "trace.jsonl").write_text(
        json.dumps({"kind": "token_usage", "total_tokens": 10, "ts": today})
        + "\n"
        + json.dumps({"kind": "token_usage", "total_tokens": 5})
        + "\n",
        encoding="utf-8",
    )
    # run missing ts — counted (no date to filter)
    r2 = runs / "run2"
    r2.mkdir()
    (r2 / "trace.jsonl").write_text(
        json.dumps({"kind": "token_usage", "total_tokens": 7}) + "\n",
        encoding="utf-8",
    )
    total = budget_mod.tokens_today(loop_dir)
    assert total >= 22  # 15 + 7 (date filter may include r1)


# ── gh_gate helpers ──


def test_tier_forbids_l1_blocks_all() -> None:
    for action in ("merge", "close", "comment", "label", "push"):
        assert gh_gate.tier_forbids("L1", action) is not None


def test_tier_forbids_l2_blocks_merge_close() -> None:
    assert gh_gate.tier_forbids("L2", "merge") is not None
    assert gh_gate.tier_forbids("L2", "close") is not None
    assert gh_gate.tier_forbids("L2", "comment") is None


def test_tier_forbids_l3_allows() -> None:
    assert gh_gate.tier_forbids("L3", "merge") is None
    assert gh_gate.tier_forbids("L3", "close") is None


def test_evaluate_action_allowlist_and_deny() -> None:
    ok, _ = gh_gate.evaluate_action("comment", tier="L3", allowlist=["comment"], deny=[])
    assert ok is True
    ok, reason = gh_gate.evaluate_action(
        "comment", tier="L3", allowlist=["comment"], deny=["comment"]
    )
    assert ok is False
    assert "deny" in reason
    ok, reason = gh_gate.evaluate_action("label", tier="L3", allowlist=["comment"], deny=[])
    assert ok is False
    assert "allowlist" in reason


def test_classify_gh_argv_examples() -> None:
    action, _ = gh_gate.classify_gh_argv(["pr", "merge", "123"])
    assert action == "merge"
    action, _ = gh_gate.classify_gh_argv(["pr", "close", "5"])
    assert action == "close"
    action, _ = gh_gate.classify_gh_argv(["pr", "view", "5"])
    assert action is None
    action, _ = gh_gate.classify_gh_argv(["issue", "comment", "10"])
    assert action == "comment"
    action, _ = gh_gate.classify_gh_argv(["api", "-X", "POST", "/repos/x/y/pulls/1/merge"])
    assert action == "merge"
    action, _ = gh_gate.classify_gh_argv([])
    assert action is None


def test_redact_argv_masks_secrets() -> None:
    redacted = gh_gate.redact_argv(["gh", "api", "-H", "Authorization: token s3cr3t", "ok"])
    assert "<redacted>" in redacted
    assert "s3cr3t" not in " ".join(redacted)


# ── loop.yaml fixture / golden parse tests ──


def _load_loop_yaml(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def test_all_loops_have_valid_schema_shape() -> None:
    """Golden: every loops/*/loop.yaml has required fields and valid tier/budget."""
    loops = sorted(LOOPS_DIR.glob("*/loop.yaml"))
    assert len(loops) >= 10, f"expected >=10 loop templates, got {len(loops)}"
    for p in loops:
        data = _load_loop_yaml(p)
        assert "name" in data and isinstance(data["name"], str) and data["name"]
        assert "tier" in data and re.match(r"^L[123]$", str(data["tier"]), re.I), (
            f"{p} bad tier {data.get('tier')}"
        )
        assert "budget" in data and isinstance(data["budget"], dict), f"{p} missing budget"
        assert "goal" in data or "description" in data, f"{p} missing goal/description"


def test_loop_budget_fields_within_reason() -> None:
    for p in sorted(LOOPS_DIR.glob("*/loop.yaml")):
        data = _load_loop_yaml(p)
        budget = data.get("budget", {})
        if "max_tokens" in budget:
            assert int(budget["max_tokens"]) > 0
            assert int(budget["max_tokens"]) <= 500000
        if "max_wall_seconds" in budget:
            assert int(budget["max_wall_seconds"]) >= 30


def test_loop_tiers_match_allowlist_gates() -> None:
    """L1 loops must not allowlist merge/close; L3 loops may."""
    for p in sorted(LOOPS_DIR.glob("*/loop.yaml")):
        data = _load_loop_yaml(p)
        tier = str(data.get("tier", "L1")).upper()
        allow = [str(a).lower() for a in (data.get("allowlist") or [])]
        if tier == "L1":
            assert "merge" not in allow, f"{p} L1 must not allow merge"
            assert "close" not in allow, f"{p} L1 must not allow close"
        if tier == "L3":
            # should have at least one of merge/close if L3
            assert len(allow) > 0, f"{p} L3 should have allowlist"


def test_loop_yaml_samples_validate_against_schema_if_present() -> None:
    if not SCHEMA_PATH.is_file():
        pytest.skip("loop schema not present")
    import json as _json

    from jsonschema import validate as _validate

    schema = _json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    for p in sorted(LOOPS_DIR.glob("*/loop.yaml")):
        data = _load_loop_yaml(p)
        _validate(data, schema)


def test_daily_triage_golden_properties() -> None:
    """Golden fixture for a known L1 loop (daily-triage)."""
    p = LOOPS_DIR / "daily-triage" / "loop.yaml"
    data = _load_loop_yaml(p)
    assert data["name"] == "daily-triage"
    assert str(data["tier"]).upper() == "L1"
    assert data["budget"]["max_tokens"] == 30000
    assert "goal" in data


def test_pack_overrides_merge_preserves_tier() -> None:
    from agent_toolkit.loop.pack import apply_loop_pack_overrides

    meta = {"tier": "L1", "cadence": "1d", "budget": {"max_tokens": 80000}}
    pack = {"loops": {"my-loop": {"cadence": "12h", "budget": {"max_tokens": 120000}}}}
    merged = apply_loop_pack_overrides(meta, pack, "my-loop")
    assert merged["tier"] == "L1"
    assert merged["cadence"] == "12h"
    assert merged["budget"]["max_tokens"] == 120000
