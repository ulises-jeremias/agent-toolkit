"""
Canonical intermediate representation for agent-toolkit capabilities.

This module defines the platform-neutral capability model that all canonical
sources (SKILL.md, AGENT.md, loop.yaml, etc.) are parsed into before being
compiled into target-specific artifacts.
"""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any


class Stability(str, Enum):
    STABLE = "stable"
    EXPERIMENTAL = "experimental"
    DEPRECATED = "deprecated"


class ModelClass(str, Enum):
    """Abstract model tier — target adapters map to platform-specific models."""
    FAST = "fast"
    BALANCED = "balanced"
    DEEP = "deep"
    INHERIT = "inherit"


class AbstractTool(str, Enum):
    """Platform-neutral tool vocabulary. Adapters map to native tool names."""
    FS_READ = "fs.read"
    FS_SEARCH = "fs.search"
    FS_WRITE = "fs.write"
    SHELL_READONLY = "shell.readonly"
    SHELL_EXECUTE = "shell.execute"
    GIT_READ = "git.read"
    GIT_WRITE = "git.write"
    WEB_SEARCH = "web.search"
    WEB_FETCH = "web.fetch"
    AGENT_DELEGATE = "agent.delegate"
    USER_ASK = "user.ask"


@dataclass
class Requirement:
    """A runtime requirement for a capability."""
    name: str
    description: str
    install_url: str = ""
    required: bool = False
    env_var: str = ""  # if env-var based, not binary


@dataclass
class SecurityPolicy:
    approval_required: bool = False
    default_enabled: bool = True
    rationale: str = ""
    no_dangerous_bypass: bool = True


@dataclass
class Provenance:
    """Tracks the source of a capability for audit."""
    source_path: Path
    source_hash: str = ""
    generated_by: str = "agent-toolkit"
    generator_version: str = ""


@dataclass
class Skill:
    """A canonical skill parsed from skills/<domain>/<name>/SKILL.md."""
    id: str                          # e.g. "core/assistant"
    name: str                        # must match directory name
    domain: str                      # e.g. "core"
    description: str
    stability: Stability = Stability.STABLE
    source_path: Path = field(default_factory=Path)
    tags: list[str] = field(default_factory=list)
    requires: list[Requirement] = field(default_factory=list)
    compatibility: str = ""          # human-readable compat note
    metadata: dict[str, Any] = field(default_factory=dict)
    provenance: Provenance | None = None


@dataclass
class Agent:
    """A canonical agent persona parsed from agents/<name>/AGENT.md."""
    id: str
    name: str
    description: str
    instructions: str                # body of AGENT.md
    model_class: ModelClass = ModelClass.INHERIT
    max_turns: int = 0               # 0 = platform default
    allowed_tools: list[AbstractTool] = field(default_factory=list)
    denied_tools: list[AbstractTool] = field(default_factory=list)
    delegates_to: list[str] = field(default_factory=list)
    read_only: bool = False
    background_eligible: bool = False
    dependent_skills: list[str] = field(default_factory=list)
    dependent_mcp: list[str] = field(default_factory=list)
    stability: Stability = Stability.STABLE
    source_path: Path = field(default_factory=Path)
    metadata: dict[str, Any] = field(default_factory=dict)
    provenance: Provenance | None = None


@dataclass
class Product:
    """A distributable plugin/bundle product parsed from distributions/products.yaml."""
    id: str
    name: str
    description: str
    stability: Stability = Stability.STABLE
    included_skills: list[str] = field(default_factory=list)   # skill IDs
    included_agents: list[str] = field(default_factory=list)   # agent IDs
    excluded: list[str] = field(default_factory=list)
    requires: list[Requirement] = field(default_factory=list)
    security: SecurityPolicy = field(default_factory=SecurityPolicy)
    target_overrides: dict[str, Any] = field(default_factory=dict)


@dataclass
class CanonicalGraph:
    """The resolved capability graph — all canonical sources loaded and validated."""
    skills: dict[str, Skill] = field(default_factory=dict)      # id → Skill
    agents: dict[str, Agent] = field(default_factory=dict)      # id → Agent
    products: dict[str, Product] = field(default_factory=dict)  # id → Product
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    @property
    def is_valid(self) -> bool:
        return len(self.errors) == 0


@dataclass
class CompilationResult:
    """Result from a target adapter compilation."""
    target: str
    product: str
    emitted: list[str] = field(default_factory=list)        # capability IDs
    transformed: list[str] = field(default_factory=list)    # with degradation
    omitted: list[str] = field(default_factory=list)        # safely dropped
    unsupported: list[str] = field(default_factory=list)    # not supported
    warnings: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    artifacts: list[Path] = field(default_factory=list)

    @property
    def is_valid(self) -> bool:
        return len(self.errors) == 0

    def report(self) -> str:
        lines = [f"Target: {self.target}  Product: {self.product}"]
        if self.emitted:
            lines.append(f"  ✓ emitted:     {', '.join(self.emitted)}")
        if self.transformed:
            lines.append(f"  ~ transformed: {', '.join(self.transformed)}")
        if self.omitted:
            lines.append(f"  - omitted:     {', '.join(self.omitted)}")
        if self.unsupported:
            lines.append(f"  ✗ unsupported: {', '.join(self.unsupported)}")
        for w in self.warnings:
            lines.append(f"  ⚠ {w}")
        for e in self.errors:
            lines.append(f"  ✗ ERROR: {e}")
        return "\n".join(lines)
