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

# Interactive bootstrap — when swarm starts without a task, the first agent must NOT invent work.
# It does a very brief context analysis and then waits for the user to provide the first request.
INTERACTIVE_BOOTSTRAP = """# Interactive mode — No initial task
> This swarm was started **without an initial prompt/task**. The user will provide the first request next in this same Herdr/Tmux session.

**Instructions for the first agent (planner/implementer):**
- **Do NOT invent work** or start tasks on your own. Do not create a plan or code yet.
- Do only a **very brief** context analysis (max 3-4 sentences / 30 seconds):
  - If you detect a **workspace** (exists `AGENTS.md` and/or `knowledge/` or `find_workspace_root()` is not None, e.g. `~/.ai-workspace`):
    Run `agent-toolkit workspace context` and briefly review `AGENTS.md` + `knowledge/todos/pending.md`.
    Also check `projects/` and `loops/` if present. Summarize in 2-3 lines what workspace it is.
  - If no workspace, briefly review the current repo (`git status`, `cat README.md` / `pyproject.toml`).
- Then **stay on standby** and confirm with a short message:
  "Brief analysis done — awaiting your first request. When you provide the task, I will apply `assistant` (discovery) + `workflow-generic-project` (plan -> approval -> implement -> review -> draft PR)."
- When the user sends the request (via chat or `agent-toolkit swarm handoff create --type artifact --from planner --to implementer --artifact artifacts/task-contract.md --run-id <run-id>`), apply the full flow: discovery per `assistant` (order README -> docs/ -> AGENTS.md -> CONTRIBUTING -> PR templates -> Makefile/package.json -> devcontainer/CI), then `workflow-generic-project` with plan approval gate before implementing, and `github-cli-workflow` for draft PR.
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
    # Empty / whitespace-only task_contract means interactive bootstrap — do not invent work
    if task_contract and task_contract.strip():
        parts.append(f"# Task Contract\n{task_contract[:3000]}")
    else:
        # No task provided — inject bootstrap: analyze context very briefly, then wait for user
        parts.append(INTERACTIVE_BOOTSTRAP)
        # Also hint workspace context command for faster readiness
        try:
            from agent_toolkit._paths import find_workspace_root

            ws = find_workspace_root()
            if ws is not None:
                parts.append(
                    f"# Workspace context hint\nDetected workspace at `{ws}` — run `agent-toolkit workspace context` to see session state before waiting."
                )
        except Exception:
            pass
    if handoff:
        parts.append(f"# Current Handoff\n{handoff}")
    if included_skills:
        parts.append(f"# Skills: {', '.join(included_skills)}")
    # Handoff instructions — explicit like swarm-forge, per role
    try:
        roles = spec.get("roles", {})
        current = roles.get(role, {})
        produces = current.get("produces", [])
        # Find consumers of what we produce
        next_roles = []
        for other_name, other_def in roles.items():
            if other_name == role:
                continue
            consumes = other_def.get("consumes", [])
            # Check if any of our produces is consumed by other
            for p in produces:
                if p in consumes:
                    next_roles.append(other_name)
                    break
        # For pair/team/full, also add fallback based on known chain
        if not next_roles:
            # Fallback chain for known recipes
            chain = {
                "pair": {"implementer": ["reviewer"], "reviewer": ["integrator"]},
                "team": {
                    "planner": ["implementer"],
                    "implementer": ["reviewer"],
                    "reviewer": ["architect"],
                },
                "full": {
                    "planner": ["implementer"],
                    "implementer": ["refactorer"],
                    "refactorer": ["architect"],
                    "architect": ["hardener"],
                    "hardener": ["qa"],
                },
            }.get(recipe_name, {})
            next_roles = chain.get(role, [])
        if next_roles:
            handoff_lines = [
                "## Handoff — delegate to next role when done",
                f"Your role `{role}` produces: {', '.join(produces) if produces else 'artifact'}",
                f"Next role(s): {', '.join(next_roles)}",
                "When you complete your work:",
                "1. If you created/modified code, commit it on your worktree branch (`git add` + `git commit`), then:",
                f"   `agent-toolkit swarm handoff create --type commit --from {role} --to {next_roles[0]} --commit <40-hex-sha> --branch <your-branch>`",
                "2. If you created an artifact (e.g., `artifacts/review.md`), then:",
                f"   `agent-toolkit swarm handoff create --type artifact --from {role} --to {next_roles[0]} --artifact artifacts/<file>.md`",
                "The next role will run `agent-toolkit swarm task next --role <next> --run-id <run_id>` to pick it up. Do not wait — the handoff is durable and the daemon will notify. The next role's tmux window will be auto-created by the handoff.",
                "IMPORTANT: After you finish writing the artifact or committing code, immediately run the `handoff create` command above — do NOT ask the user for confirmation, do NOT wait for 'do the handoff'.",
                f"Run ID for this swarm: `{role_def.get('_run_id', 'see task contract')}` — if the command says 'No run found', add `--run-id <run_id>` or ensure `AGENT_TOOLKIT_SWARM_RUN_ID` is exported (it is in your tmux env).",
            ]
            parts.append("\n".join(handoff_lines))
        else:
            parts.append(
                "## Handoff\nWhen done, create a handoff if your work should be reviewed: `agent-toolkit swarm handoff create --type artifact --from "
                + role
                + " --to <next> --artifact artifacts/<file>.md` (or `--type commit` with --commit/--branch for code)."
            )
    except Exception:
        pass
    # Enforce size limit 12k chars
    text = "\n\n".join(parts)
    if len(text) > 12000:
        text = text[:12000] + "\n[truncated]"
    is_interactive = not task_contract or not task_contract.strip()
    manifest = {
        "role": role,
        "persona": persona,
        "policy": policy,
        "recipe": recipe_name,
        "includes": [
            "global_protocol",
            "recipe_workflow",
            "persona",
            "interactive_bootstrap" if is_interactive else None,
            "task_contract" if task_contract and task_contract.strip() else None,
            "handoff" if handoff else None,
            "skills" if included_skills else None,
        ],
        "size_chars": len(text),
        "model_profile_task": role_def.get("model_profile"),
        "is_interactive": is_interactive,
    }
    manifest["includes"] = [x for x in manifest["includes"] if x]
    return text, manifest
