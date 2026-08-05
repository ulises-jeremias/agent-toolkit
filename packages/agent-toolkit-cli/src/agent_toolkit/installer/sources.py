"""Resolve install artifact sources — prefer compiler plugins/ over hand profiles/."""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

_PROFILE_PARITY_BASELINES: dict[str, dict[str, int]] = {
    "cursor": {"rules": 14},
    "windsurf": {"rules": 14},
    "pi": {"skills": 6},
}


@dataclass(frozen=True)
class InstallSource:
    path: Path
    kind: str  # "plugins" | "profiles"
    label: str


def _count_files(directory: Path) -> int:
    if not directory.is_dir():
        return 0
    return sum(1 for p in directory.rglob("*") if p.is_file())


def _plugin_agents_dir(root: Path) -> Path | None:
    for path in (
        root / "plugins" / "agent-toolkit-agents" / "agents",
        root / "dist" / "plugins" / "agent-toolkit-agents" / "agents",
    ):
        if path.is_dir() and any(path.iterdir()):
            return path
    return None


def _plugin_skills_dirs(root: Path) -> list[Path]:
    found: list[Path] = []
    for base in (root / "plugins", root / "dist" / "plugins"):
        if not base.is_dir():
            continue
        for product_dir in sorted(base.iterdir()):
            skills = product_dir / "skills"
            if skills.is_dir() and any(skills.iterdir()):
                found.append(skills)
    return found


def resolve_agents_source(root: Path, profile_tool: str) -> InstallSource:
    plugin_agents = _plugin_agents_dir(root)
    if plugin_agents is not None:
        return InstallSource(plugin_agents, "plugins", "agent-toolkit-agents/agents")
    profile_agents = root / "profiles" / profile_tool / "agents"
    return InstallSource(profile_agents, "profiles", f"profiles/{profile_tool}/agents")


def resolve_pi_skills_source(root: Path) -> InstallSource:
    if _plugin_skills_dirs(root):
        return InstallSource(root / "plugins", "plugins", "plugins/*/skills")
    return InstallSource(root / "profiles" / "pi" / "skills", "profiles", "profiles/pi/skills")


def resolve_profile_dir(root: Path, tool: str, *parts: str) -> InstallSource:
    rel = Path("profiles") / tool / Path(*parts)
    return InstallSource(root / rel, "profiles", str(rel))


def uneven_profile_warnings(root: Path, tool: str) -> list[str]:
    warnings: list[str] = []
    baseline = _PROFILE_PARITY_BASELINES.get(tool)
    if baseline is None:
        return warnings
    for surface, expected in baseline.items():
        profile_dir = root / "profiles" / tool / surface
        if not profile_dir.is_dir():
            continue
        actual = _count_files(profile_dir)
        if actual < expected:
            warnings.append(
                f"{tool} {surface}/ has {actual} file(s); reference baseline is {expected} "
                f"({expected - actual} missing vs cursor/full set). Install may be incomplete."
            )
    return warnings


def collect_pi_skill_files(root: Path, source: InstallSource) -> list[tuple[Path, str]]:
    if source.kind == "plugins":
        pairs: list[tuple[Path, str]] = []
        for skills_dir in _plugin_skills_dirs(root):
            for skill_md in sorted(skills_dir.rglob("SKILL.md")):
                pairs.append((skill_md, skill_md.parent.name))
        return pairs
    if not source.path.is_dir():
        return []
    return [(p, p.parent.name) for p in sorted(source.path.rglob("*.md")) if p.is_file()]


def list_plugin_agent_files(agents_dir: Path) -> list[tuple[Path, str]]:
    if not agents_dir.is_dir():
        return []
    pairs: list[tuple[Path, str]] = []
    for agent_dir in sorted(agents_dir.iterdir()):
        if not agent_dir.is_dir():
            continue
        agent_md = agent_dir / "AGENT.md"
        if agent_md.is_file():
            pairs.append((agent_md, f"{agent_dir.name}.md"))
    return pairs
