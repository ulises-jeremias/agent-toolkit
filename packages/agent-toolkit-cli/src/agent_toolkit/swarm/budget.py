"""Budget enforcement — reuse loop budget ideas, add swarm specifics."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


DEFAULTS = {
    "max_total_tokens": 900000,
    "max_cost_usd": 4.00,
    "max_wall_seconds": 7200,
    "max_concurrency": 2,
    "max_role_round_trips": 2,
}


def resolve_budget(spec_budget: dict[str, Any] | None, cli_overrides: dict[str, Any] | None = None) -> dict[str, Any]:
    merged = dict(DEFAULTS)
    if spec_budget:
        merged.update({k: v for k, v in spec_budget.items() if v is not None})
    if cli_overrides:
        merged.update({k: v for k, v in cli_overrides.items() if v is not None})
    # Clamp concurrency
    try:
        merged["max_concurrency"] = max(1, min(6, int(merged.get("max_concurrency", 2))))
    except Exception:
        merged["max_concurrency"] = 2
    return merged


def check_limits(budget: dict[str, Any], usage: dict[str, Any]) -> list[str]:
    violated: list[str] = []
    total_tokens = usage.get("total_tokens", 0) or 0
    cost = usage.get("cost_usd", 0) or 0
    wall = usage.get("wall_seconds", 0) or 0
    if budget.get("max_total_tokens") is not None and total_tokens >= int(budget["max_total_tokens"]):
        violated.append("max_total_tokens")
    if budget.get("max_cost_usd") is not None and cost >= float(budget["max_cost_usd"]):
        violated.append("max_cost_usd")
    if budget.get("max_wall_seconds") is not None and wall >= int(budget["max_wall_seconds"]):
        violated.append("max_wall_seconds")
    return violated


def per_role_limit(budget: dict[str, Any], role: str) -> int | None:
    per = budget.get("per_role") or {}
    entry = per.get(role) if isinstance(per, dict) else None
    if isinstance(entry, dict):
        v = entry.get("max_tokens")
        if v is not None:
            try:
                return int(v)
            except Exception:
                return None
    return None


def load_budget(run_dir: Path) -> dict[str, Any]:
    p = run_dir / "budget.json"
    if p.is_file():
        try:
            return json.loads(p.read_text(encoding="utf-8"))
        except Exception:
            return {}
    return {}


def save_budget(run_dir: Path, budget: dict[str, Any], usage: dict[str, Any]) -> None:
    from .store import atomic_write_json
    data = {"budget": budget, "usage": usage}
    atomic_write_json(run_dir / "budget.json", data)


def estimate_cost(tokens: int, price_per_mtok: float | None) -> float | None:
    if price_per_mtok is None:
        return None
    return tokens / 1_000_000 * price_per_mtok
