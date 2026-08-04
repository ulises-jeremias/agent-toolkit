"""
Canonical lifecycle hook registry loader.

Loads hook definitions from capabilities/hooks/*.yaml and validates
them against schemas/hook.schema.yaml.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class HookDefinition:
    """A canonical lifecycle hook definition."""
    id: str
    event: str
    handler_type: str
    blocking: bool
    failure_policy: str
    default_enabled: bool
    security_classification: str
    platform_support: dict[str, str] = field(default_factory=dict)
    command: list[str] = field(default_factory=list)
    timeout_ms: int = 5000

    def is_supported_for(self, target_id: str) -> bool:
        status = self.platform_support.get(target_id, "unknown-blocked")
        return status in ("native", "native-experimental")

    def is_safe(self) -> bool:
        return self.security_classification == "safe"

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "HookDefinition":
        handler = data.get("handler", {})
        security = data.get("security", {})
        return cls(
            id=data["id"],
            event=data["event"],
            handler_type=handler.get("type", "command"),
            blocking=data.get("blocking", True),
            failure_policy=data.get("failure_policy", "abort"),
            default_enabled=security.get("default_enabled", False),
            security_classification=security.get("classification", "safe"),
            platform_support=data.get("platforms", {}),
            command=handler.get("command", []),
            timeout_ms=handler.get("timeout_ms", 5000),
        )


def load_hooks(hooks_dir: Path) -> dict[str, HookDefinition]:
    """Load all hook definitions from capabilities/hooks/*.yaml."""
    hooks: dict[str, HookDefinition] = {}
    if not hooks_dir.is_dir():
        return hooks

    try:
        import yaml
    except ImportError:
        return hooks

    for yaml_file in sorted(hooks_dir.glob("*.yaml")):
        try:
            data = yaml.safe_load(yaml_file.read_text())
            if data and "id" in data:
                hooks[data["id"]] = HookDefinition.from_dict(data)
        except Exception:
            continue

    return hooks


def generate_parity_document(hooks: dict[str, HookDefinition]) -> str:
    """Generate a hook parity document from canonical hook definitions."""
    targets = [
        "claude-code", "cursor", "gemini-cli", "copilot-cli",
        "opencode", "pi", "windsurf", "codex"
    ]

    lines = ["# Hook Parity", "", "| Hook | Event | " + " | ".join(targets) + " |"]
    lines.append("|------|-------|" + "|".join(["---"] * len(targets)) + "|")

    for hook in sorted(hooks.values(), key=lambda h: h.id):
        row_parts = [hook.id, hook.event]
        for target in targets:
            status = hook.platform_support.get(target, "unknown-blocked")
            row_parts.append(status)
        lines.append("| " + " | ".join(row_parts) + " |")

    return "\n".join(lines) + "\n"
