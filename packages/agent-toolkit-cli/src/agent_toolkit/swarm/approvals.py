"""Swarm approvals — gates for plan, architecture, cost, final."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .store import append_trace, atomic_write_json, now_ts

GATE_DESCRIPTIONS = {
    "plan": "Plan approval: review task contract, acceptance criteria, risk assessment before implementation.",
    "architecture": "Architecture decision approval: public contract changes or migration requires human decision.",
    "cost_escalation": "Cost escalation approval: raising budget or switching to expensive model requires approval.",
    "final": "Final integration approval: changes must be approved before base-branch merge.",
}


def default_gates_for_recipe(recipe: dict[str, Any]) -> list[dict[str, Any]]:
    spec = recipe.get("spec", {}) if isinstance(recipe, dict) else {}
    gates_cfg = spec.get("gates", {}) if isinstance(spec.get("gates"), dict) else {}
    gates: list[dict[str, Any]] = []
    if gates_cfg.get("require_plan_approval"):
        gates.append({"id": "plan", "description": GATE_DESCRIPTIONS["plan"], "required": True, "approved": False})
    # architecture gate is on-demand, not default
    # cost gate is on-demand
    if gates_cfg.get("require_final_approval", True):
        gates.append({"id": "final", "description": GATE_DESCRIPTIONS["final"], "required": True, "approved": False})
    return gates


def approvals_path(run_dir: Path) -> Path:
    return run_dir / "approvals.json"


def load_approvals(run_dir: Path) -> list[dict[str, Any]]:
    p = approvals_path(run_dir)
    if not p.is_file():
        return []
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
        if isinstance(data, list):
            return data
        if isinstance(data, dict) and "gates" in data:
            return data["gates"]  # type: ignore
        return []
    except Exception:
        return []


def save_approvals(run_dir: Path, gates: list[dict[str, Any]]) -> None:
    atomic_write_json(approvals_path(run_dir), gates)


def request_approval(run_dir: Path, gate_id: str, description: str | None = None) -> dict[str, Any]:
    gates = load_approvals(run_dir)
    for g in gates:
        if g.get("id") == gate_id:
            return g
    gate = {"id": gate_id, "description": description or GATE_DESCRIPTIONS.get(gate_id, gate_id), "required": True, "approved": False, "requested_at": now_ts()}
    gates.append(gate)
    save_approvals(run_dir, gates)
    append_trace(run_dir, {"ts": now_ts(), "kind": "approval_requested", "gate": gate_id})
    return gate


def approve_gate(run_dir: Path, gate_id: str) -> dict[str, Any] | None:
    gates = load_approvals(run_dir)
    for g in gates:
        if g.get("id") == gate_id:
            g["approved"] = True
            g["approved_at"] = now_ts()
            save_approvals(run_dir, gates)
            append_trace(run_dir, {"ts": now_ts(), "kind": "approval_granted", "gate": gate_id})
            return g
    return None


def reject_gate(run_dir: Path, gate_id: str, reason: str) -> dict[str, Any] | None:
    gates = load_approvals(run_dir)
    for g in gates:
        if g.get("id") == gate_id:
            g["approved"] = False
            g["rejected"] = True
            g["reason"] = reason
            g["rejected_at"] = now_ts()
            save_approvals(run_dir, gates)
            append_trace(run_dir, {"ts": now_ts(), "kind": "approval_rejected", "gate": gate_id, "reason": reason})
            return g
    return None


def all_required_approved(run_dir: Path) -> bool:
    gates = load_approvals(run_dir)
    for g in gates:
        if g.get("required") and not g.get("approved"):
            return False
    return True
