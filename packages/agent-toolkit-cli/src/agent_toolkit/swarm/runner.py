"""Runner abstraction and OpenCode agent generation."""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Any

RUNNER_CAPS: dict[str, dict[str, Any]] = {
    "opencode": {"interactive": True, "resume": True, "per_role_model": True, "usage_data": True, "herdr": "official"},
    "claude": {"interactive": True, "resume": True, "per_role_model": True, "usage_data": True, "herdr": "official"},
    "codex": {"interactive": True, "resume": True, "per_role_model": True, "usage_data": True, "herdr": "official"},
    "cursor": {"interactive": True, "resume": True, "per_role_model": True, "usage_data": True, "herdr": "official"},
    "copilot": {"interactive": True, "resume": False, "per_role_model": False, "usage_data": False, "herdr": "custom"},
    "muse": {"interactive": True, "resume": True, "per_role_model": True, "usage_data": True, "herdr": "detect"},
    "skeleton": {"interactive": False, "resume": False, "per_role_model": False, "usage_data": False, "herdr": "none"},
}

def list_runners() -> list[str]:
    return sorted(RUNNER_CAPS.keys())

def runner_available(name: str) -> bool:
    bin_map = {
        "opencode": "opencode",
        "claude": "claude",
        "codex": "codex",
        "cursor": "cursor-agent",
        "copilot": "copilot",
        "muse": "muse",
        "skeleton": "true",
    }
    binary = bin_map.get(name, name)
    return shutil.which(binary) is not None

def capability_matrix() -> dict[str, dict[str, Any]]:
    return {k: dict(v, available=runner_available(k)) for k, v in RUNNER_CAPS.items()}

MODEL_PROFILES = {
    "economy": {"planning": "anthropic/claude-3-5-haiku-20241022", "coding": "anthropic/claude-3-5-haiku-20241022", "review": "openai/gpt-4o-mini", "architecture": "anthropic/claude-3-5-haiku-20241022", "hardening": "anthropic/claude-3-5-haiku-20241022", "qa": "openai/gpt-4o-mini"},
    "balanced": {"planning": "anthropic/claude-sonnet-4-20250514", "coding": "anthropic/claude-sonnet-4-20250514", "review": "openai/gpt-4o", "architecture": "anthropic/claude-sonnet-4-20250514", "hardening": "openai/gpt-4o", "qa": "anthropic/claude-3-5-haiku-20241022"},
    "quality": {"planning": "anthropic/claude-opus-4-20250514", "coding": "anthropic/claude-opus-4-20250514", "review": "openai/gpt-4o", "architecture": "anthropic/claude-opus-4-20250514", "hardening": "anthropic/claude-opus-4-20250514", "qa": "openai/gpt-4o"},
    "private": {"planning": "ollama/llama3.1", "coding": "ollama/llama3.1", "review": "ollama/llama3.1", "architecture": "ollama/llama3.1", "hardening": "ollama/llama3.1", "qa": "ollama/llama3.1"},
}

def resolve_model(profile: str, task_class: str, override: str | None = None) -> str | None:
    if override:
        if "/" not in override:
            raise ValueError(f"Model must be provider/model format: {override!r}")
        return override
    mapping = MODEL_PROFILES.get(profile) or MODEL_PROFILES["balanced"]
    return mapping.get(task_class)

def discover_models(runner: str) -> list[str]:
    # Try to list models via runner CLI if available
    cmds = {
        "opencode": ["opencode", "models"],
        "claude": ["claude", "models"],
    }
    cmd = cmds.get(runner)
    if not cmd or not shutil.which(cmd[0]):
        # Return profile models as fallback
        vals = set()
        for m in MODEL_PROFILES.values():
            vals.update(m.values())
        return sorted(vals)
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
        if res.returncode == 0:
            # naive parse: each line contains model id
            models: list[str] = []
            for line in res.stdout.splitlines():
                line = line.strip()
                if "/" in line and not line.startswith("#"):
                    models.append(line.split()[0])
            if models:
                return models
    except Exception:
        pass
    vals2 = set()
    for m in MODEL_PROFILES.values():
        vals2.update(m.values())
    return sorted(vals2)

# OpenCode permission generation
OPENCODE_PERMISSIONS = {
    "read-only": {
        "edit": "deny",
        "external_directory": "deny",
        "websearch": "allow",
        "skill": "allow",
        "bash": {"*": "ask", "git status *": "allow", "git log *": "allow", "git diff *": "allow"},
    },
    "writer": {
        "edit": "allow",
        "external_directory": "deny",
        "bash": {"*": "ask", "git status *": "allow", "git diff *": "allow", "git log *": "allow", "git add *": "allow", "git commit *": "ask", "git push *": "deny", "git reset --hard*": "deny", "git clean *": "deny"},
    },
    "reviewer-writer": {
        "edit": "allow",
        "external_directory": "deny",
        "bash": {"*": "ask", "git status *": "allow", "git diff *": "allow", "git log *": "allow"},
    },
    "integrator": {
        "edit": "allow",
        "external_directory": "deny",
        "bash": {"*": "ask", "git status *": "allow", "git diff *": "allow", "git log *": "allow", "git merge *": "ask", "git push *": "deny"},
    },
}

def generate_opencode_agent(run_dir: Path, role: str, persona: str, policy: str, model: str, recipe_name: str, run_id: str, worktree: str | None) -> Path:
    agents_dir = run_dir / "runner" / "opencode" / "agents"
    agents_dir.mkdir(parents=True, exist_ok=True)
    perm = OPENCODE_PERMISSIONS.get(policy, OPENCODE_PERMISSIONS["read-only"])
    content = f"""---
description: "Swarm role {role} ({persona}) for recipe {recipe_name}, run {run_id}"
mode: primary
model: {model}
permission:
  edit: {perm.get('edit','deny')}
  external_directory: {perm.get('external_directory','deny')}
---

# Role: {role} ({persona})

You are the **{role}** role in the Agent Toolkit Swarm `{recipe_name}` (run `{run_id}`).

## Policy
- Policy: {policy}
- Worktree: {worktree or 'read-only (no worktree)'}
- Permissions: {json.dumps(perm)}

## Workflow
- Read the task contract at `artifacts/task-contract.md` if present.
- Follow the handoff protocol: use `agent-toolkit swarm handoff create` and `agent-toolkit swarm task next/complete` — do not move queue files manually.
- Work only inside your worktree path when you have one.
- Do not push, do not merge to base branch, do not publish releases.
- Keep artifacts small (<1MB) and do not include secrets.

## Handoff commands
```bash
agent-toolkit swarm handoff create --type artifact --to <role> --artifact artifacts/<file>.md
agent-toolkit swarm task next
agent-toolkit swarm task complete --handoff <id>
```

## Context manifest
- Run ID: {run_id}
- Role: {role}
- Recipe: {recipe_name}
- Model: {model}
"""
    path = agents_dir / f"{role}.md"
    path.write_text(content, encoding="utf-8")
    return path
