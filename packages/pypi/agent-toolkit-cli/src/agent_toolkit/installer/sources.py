"""Resolve install source paths — prefer compiler-generated plugins/ over hand profiles/."""

from __future__ import annotations

import os
from pathlib import Path

from agent_toolkit._paths import toolkit_root

# Default products whose compiled agents are installed for profile-based targets.
_DEFAULT_AGENT_PRODUCTS = (
    "agent-toolkit-core",
    "agent-toolkit-agents",
    "agent-toolkit-forge",
)


def find_repo_root(data_root: Path | None = None) -> Path:
    """Return repo root containing plugins/ compiler output."""
    root = data_root or toolkit_root()
    if (root / "plugins").is_dir():
        return root
    if (root.parent / "plugins").is_dir():
        return root.parent
    return root


def plugins_dir(data_root: Path | None = None) -> Path | None:
    """Return plugins/ output directory when compiler artifacts are present."""
    override = os.environ.get("AGENT_TOOLKIT_INSTALL_SOURCE", "").strip()
    if override:
        path = Path(override)
        return path if path.is_dir() else None

    repo = find_repo_root(data_root)
    plugins = repo / "plugins"
    return plugins if plugins.is_dir() else None


def compiled_agent_files(
    data_root: Path | None = None,
    *,
    products: tuple[str, ...] = _DEFAULT_AGENT_PRODUCTS,
) -> dict[str, Path]:
    """Map agent name -> AGENT.md path from compiled plugin bundles."""
    root = data_root or toolkit_root()
    plugins = root / "plugins"
    if not plugins.is_dir():
        repo_plugins = plugins_dir(data_root)
        if repo_plugins is None:
            return {}
        plugins = repo_plugins

    agents: dict[str, Path] = {}
    for product_id in products:
        agents_dir = plugins / product_id / "agents"
        if not agents_dir.is_dir():
            continue
        for agent_dir in sorted(agents_dir.iterdir()):
            if not agent_dir.is_dir():
                continue
            agent_md = agent_dir / "AGENT.md"
            if agent_md.is_file():
                agents[agent_dir.name] = agent_md
    return agents


def agent_install_sources(
    tool: str,
    data_root: Path | None = None,
) -> dict[str, Path]:
    """Return agent-name -> source file for a profile install target.

    Prefers compiler-generated ``plugins/*/agents/*/AGENT.md`` artifacts.
    Falls back to ``profiles/<tool>/agents/*.md`` when plugins are unavailable.
    """
    compiled = compiled_agent_files(data_root)
    if compiled:
        return compiled

    root = data_root or toolkit_root()
    profile_agents = root / "profiles" / tool / "agents"
    if not profile_agents.is_dir():
        return {}

    return {path.stem: path for path in sorted(profile_agents.glob("*.md")) if path.is_file()}


def profile_file(tool: str, *parts: str, data_root: Path | None = None) -> Path:
    """Return a profile-relative path (rules, CLAUDE.md, etc.)."""
    root = data_root or toolkit_root()
    return root / "profiles" / tool / Path(*parts)
