"""
Canonical MCP provider registry loader.

Loads provider metadata from mcp/registry/*.yaml and provides
a registry for the compiler to use when rendering MCP configurations.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class McpProvider:
    """Canonical MCP provider definition."""
    id: str
    display_name: str
    purpose: str
    provenance: str
    package: str
    env_vars: list[str]
    read_tools: list[str] = field(default_factory=list)
    write_tools: list[str] = field(default_factory=list)
    destructive_tools: list[str] = field(default_factory=list)
    default_approval: str = "read-only"
    security_notes: str = ""
    platform_support: dict[str, str] = field(default_factory=dict)

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "McpProvider":
        auth = data.get("auth", {})
        tools = data.get("tools", {})
        impl = data.get("implementation", {})
        security = data.get("security", {})
        return cls(
            id=data["id"],
            display_name=data.get("display_name", data["id"]),
            purpose=data.get("purpose", ""),
            provenance=impl.get("provenance", "unknown"),
            package=impl.get("package", ""),
            env_vars=auth.get("env", []),
            read_tools=tools.get("read", []),
            write_tools=tools.get("write", []),
            destructive_tools=tools.get("destructive", []),
            default_approval=data.get("approval", {}).get("default", "read-only"),
            security_notes=security.get("notes", ""),
            platform_support=data.get("platforms", {}),
        )

    def is_supported_for(self, target_id: str) -> bool:
        status = self.platform_support.get(target_id, "unknown-blocked")
        return status in ("native", "bridged", "generated")


def load_registry(registry_dir: Path) -> dict[str, McpProvider]:
    """Load all providers from mcp/registry/*.yaml."""
    providers: dict[str, McpProvider] = {}
    if not registry_dir.is_dir():
        return providers

    try:
        import yaml
    except ImportError:
        return providers

    for yaml_file in sorted(registry_dir.glob("*.yaml")):
        try:
            data = yaml.safe_load(yaml_file.read_text())
            if data and "id" in data:
                providers[data["id"]] = McpProvider.from_dict(data)
        except Exception:
            continue

    return providers
