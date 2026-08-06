"""Prompt composition — combine protocol + recipe + role + persona + skills."""

from __future__ import annotations

from pathlib import Path
from typing import Any

GLOBAL_PROTOCOL = """# Agent Toolkit Swarm — Global Protocol
- You are a role in a multi-agent swarm. Work only on your assigned task.
- Do not push, do not merge to base branch, do not publish releases.
- Transfer code only via validated Git commits on your Toolkit-owned branch.
- Use durable handoffs via `agent-toolkit swarm handoff create` and `agent-toolkit swarm task next/complete`.
- Stay inside your worktree when you have one. Do not write outside `.agent-toolkit/swarm/runs/<run-id>/` except your worktree.
- Keep artifacts under 1MB, no secrets, no full transcript forwarding.
- Record decisions in artifacts and trace events.
"""

def load_persona_text(persona: str) -> str:
    # Load from bundled data/agents/<persona>/AGENT.md if exists
    try:
        from agent_toolkit._paths import find_toolkit_root
        root = find_toolkit_root()
        # Try package data
        candidates = [
            Path(root) / "agents" / persona / "AGENT.md",
            Path(__file__).parent.parent / "data" / "agents" / persona / "AGENT.md",
        ]
        for p in candidates:
            if p.is_file():
                return p.read_text(encoding="utf-8")[:2000]
    except Exception:
        pass
    return f"# Persona: {persona}\nAct as {persona} per Toolkit guidance."

def compose_role_prompt(
    recipe: dict[str, Any],
    role: str,
    role_def: dict[str, Any],
    task_contract: str | None,
    handoff: dict[str, Any] | None,
    included_skills: list[str] | None = None,
) -> tuple[str, dict[str, Any]]:
    persona = role_def.get("persona", role)
    persona_text = load_persona_text(persona)
    recipe_name = (recipe.get("metadata") or {}).get("name", "unknown")
    policy = role_def.get("policy", "read-only")
    parts: list[str] = [GLOBAL_PROTOCOL]
    parts.append(f"# Recipe: {recipe_name} — Role: {role}\nPolicy: {policy}\nPersona: {persona}\n")
    parts.append(persona_text)
    # Recipe workflow snippet
    spec = recipe.get("spec", {})
    workflow = f"Execution: {spec.get('execution', {})}\nWorkspace: {spec.get('workspace', {})}\n"
    parts.append(workflow)
    if task_contract:
        parts.append(f"# Task Contract\n{task_contract[:3000]}")
    if handoff:
        parts.append(f"# Current Handoff\n{handoff}")
    if included_skills:
        parts.append(f"# Skills: {', '.join(included_skills)}")
    # Enforce size limit 12k chars
    text = "\n\n".join(parts)
    if len(text) > 12000:
        text = text[:12000] + "\n[truncated]"
    manifest = {
        "role": role,
        "persona": persona,
        "policy": policy,
        "recipe": recipe_name,
        "includes": ["global_protocol", "recipe_workflow", "persona", "task_contract" if task_contract else None, "handoff" if handoff else None, "skills" if included_skills else None],
        "size_chars": len(text),
        "model_profile_task": role_def.get("model_profile"),
    }
    manifest["includes"] = [x for x in manifest["includes"] if x]
    return text, manifest
