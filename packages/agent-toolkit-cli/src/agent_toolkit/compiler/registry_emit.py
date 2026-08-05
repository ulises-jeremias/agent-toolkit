"""Emit hooks and MCP configurations from canonical registries into target formats."""
from __future__ import annotations

import json
from pathlib import Path

from agent_toolkit.compiler.hook_registry import HookDefinition, load_hooks
from agent_toolkit.compiler.mcp_registry import McpProvider, load_registry

# Canonical event → Claude Code hook event name
_CLAUDE_HOOK_EVENTS: dict[str, str] = {
    "session.start": "SessionStart",
    "session.end": "SessionEnd",
    "tool.before": "PreToolUse",
    "tool.after": "PostToolUse",
    "prompt.before_submit": "UserPromptSubmit",
}


def _hooks_dict(hooks_dir: Path) -> dict[str, HookDefinition]:
    hooks, _errors = load_hooks(hooks_dir)
    return hooks


def _mcp_dict(registry_dir: Path) -> dict[str, McpProvider]:
    providers, _errors = load_registry(registry_dir)
    return providers


def resolve_hook_ids(
    product_hooks: list[str],
    *,
    target_id: str,
    hooks_dir: Path,
    emit_registries: bool = False,
) -> list[str]:
    """Return hook IDs to emit for a product/target."""
    registry = _hooks_dict(hooks_dir)
    if product_hooks:
        return [hid for hid in product_hooks if hid in registry]
    if not emit_registries:
        return []
    return [
        hook.id
        for hook in registry.values()
        if hook.is_supported_for(target_id)
    ]


def resolve_mcp_ids(
    product_mcp: list[str],
    *,
    target_id: str,
    registry_dir: Path,
    emit_registries: bool = False,
) -> list[str]:
    """Return MCP provider IDs to emit for a product/target."""
    registry = _mcp_dict(registry_dir)
    if product_mcp:
        return [pid for pid in product_mcp if pid in registry]
    if not emit_registries:
        return []
    return [
        provider.id
        for provider in registry.values()
        if provider.is_supported_for(target_id)
    ]


def emit_claude_hooks_json(
    hook_ids: list[str],
    hooks_dir: Path,
    target_id: str = "claude-code",
) -> dict | None:
    """Build Claude Code hooks/hooks.json content from canonical hook IDs."""
    registry = _hooks_dict(hooks_dir)
    hooks_block: dict[str, list[dict]] = {}

    for hook_id in hook_ids:
        hook = registry.get(hook_id)
        if hook is None or not hook.is_supported_for(target_id):
            continue
        event_name = _CLAUDE_HOOK_EVENTS.get(hook.event, hook.event)
        if hook.handler_type != "command" or not hook.command:
            continue
        entry = {
            "type": "command",
            "command": " ".join(hook.command),
            "timeout": hook.timeout_ms,
        }
        hooks_block.setdefault(event_name, []).append(entry)

    if not hooks_block:
        return None
    return {"hooks": hooks_block}


def emit_claude_mcp_json(
    provider_ids: list[str],
    registry_dir: Path,
    target_id: str = "claude-code",
) -> dict | None:
    """Build Claude Code .mcp.json content from canonical MCP provider IDs."""
    registry = _mcp_dict(registry_dir)
    servers: dict[str, dict] = {}

    for provider_id in provider_ids:
        provider = registry.get(provider_id)
        if provider is None or not provider.is_supported_for(target_id):
            continue
        env = {var: f"${{{var}}}" for var in provider.env_vars}
        if provider.package.startswith("@"):
            servers[provider_id] = {
                "command": "npx",
                "args": ["-y", provider.package],
                "env": env,
            }
        else:
            servers[provider_id] = {
                "command": provider.package or provider_id,
                "env": env,
            }

    if not servers:
        return None
    return {"mcpServers": servers}


def hooks_json_text(hook_ids: list[str], hooks_dir: Path, target_id: str = "claude-code") -> str | None:
    payload = emit_claude_hooks_json(hook_ids, hooks_dir, target_id)
    if payload is None:
        return None
    return json.dumps(payload, indent=2) + "\n"


def mcp_json_text(
    provider_ids: list[str],
    registry_dir: Path,
    target_id: str = "claude-code",
) -> str | None:
    payload = emit_claude_mcp_json(provider_ids, registry_dir, target_id)
    if payload is None:
        return None
    return json.dumps(payload, indent=2) + "\n"
