"""Loop budget helpers: wall-clock timeout and token accounting."""
from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_WALL_SECONDS = 900


def wall_timeout_seconds(budget: dict[str, Any]) -> int:
    """Per-run wall-clock limit from loop budget (never bypassed by --force)."""
    raw = budget.get("max_wall_seconds")
    if raw is None:
        return DEFAULT_WALL_SECONDS
    try:
        return max(30, int(raw))
    except (TypeError, ValueError):
        return DEFAULT_WALL_SECONDS


def max_tokens_limit(budget: dict[str, Any]) -> int | None:
    """Per-run token ceiling, or None when unset."""
    raw = budget.get("max_tokens")
    if raw is None:
        return None
    try:
        return int(raw)
    except (TypeError, ValueError):
        return None


def tokens_from_trace(trace_path: Path) -> int:
    """Sum token_usage / prompt+completion events from a trace.jsonl file."""
    if not trace_path.is_file():
        return 0
    total = 0
    for line in trace_path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        kind = event.get("kind", "")
        if kind == "token_usage":
            total += int(event.get("total_tokens") or event.get("total") or 0)
        elif kind in ("prompt", "completion"):
            total += int(event.get("prompt_tokens", 0) or 0)
            total += int(event.get("completion_tokens", 0) or 0)
    return total


def tokens_today(loop_dir: Path) -> int:
    """Sum tokens recorded in today's run traces under loop_dir/runs/."""
    runs_dir = loop_dir / "runs"
    if not runs_dir.is_dir():
        return 0
    today = datetime.now(timezone.utc).date()
    total = 0
    for run in runs_dir.iterdir():
        if not run.is_dir():
            continue
        trace = run / "trace.jsonl"
        if not trace.is_file():
            continue
        try:
            first_line = trace.read_text(encoding="utf-8").splitlines()[0]
            event = json.loads(first_line)
            ts = event.get("ts", "")
            if ts:
                run_day = datetime.fromisoformat(str(ts).replace("Z", "+00:00")).date()
                if run_day != today:
                    continue
        except (IndexError, json.JSONDecodeError, ValueError):
            pass
        total += tokens_from_trace(trace)
    return total


def token_budget_exceeded(tokens_used: int, budget: dict[str, Any]) -> bool:
    limit = max_tokens_limit(budget)
    if limit is None:
        return False
    return tokens_used >= limit


def soft_token_precheck(state: dict[str, Any], budget: dict[str, Any]) -> str | None:
    """Warn when last run tokens suggest the next run may hit max_tokens immediately."""
    limit = max_tokens_limit(budget)
    if limit is None:
        return None
    last_tokens = state.get("last_run_tokens")
    if last_tokens is None:
        return None
    try:
        last = int(last_tokens)
    except (TypeError, ValueError):
        return None
    if last >= limit:
        return (
            f"Last run used {last:,} tokens (limit {limit:,}). "
            "Run may exit with budget_exhausted."
        )
    return None
