"""
Loads canonical sources (SKILL.md, AGENT.md, products.yaml) into the CanonicalGraph IR.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

from agent_toolkit.compiler.model import (
    Agent, CanonicalGraph, ModelClass, Product, Provenance,
    Requirement, SecurityPolicy, Skill, Stability,
)

_PYYAML_REQUIRED = (
    "PyYAML is required to load YAML sources (products.yaml, frontmatter). "
    "Install with: uv sync"
)


def _require_yaml():
    try:
        import yaml
    except ImportError as exc:
        raise ImportError(_PYYAML_REQUIRED) from exc
    return yaml


def _parse_frontmatter(text: str) -> tuple[dict[str, Any], str, str | None]:
    """Parse YAML frontmatter from a Markdown file.

    Returns (frontmatter, body, error). On YAML parse failure, frontmatter is
    empty and error describes the failure (fail-closed — callers must not treat
    the file as valid metadata).
    """
    m = re.match(r"^---[ \t]*\n(.*?)\n---[ \t]*\n?(.*)", text, re.DOTALL)
    if not m:
        return {}, text, None
    fm_text = m.group(1)
    body = m.group(2)
    yaml = _require_yaml()
    try:
        loaded = yaml.safe_load(fm_text)
    except Exception as exc:
        return {}, body, f"invalid YAML frontmatter: {exc}"
    if loaded is None:
        fm: dict[str, Any] = {}
    elif not isinstance(loaded, dict):
        return {}, body, f"frontmatter must be a mapping, got {type(loaded).__name__}"
    else:
        fm = loaded
    return fm, body, None


def _simple_yaml(text: str) -> dict[str, Any]:
    """Minimal YAML parser for simple key: value frontmatter (no PyYAML)."""
    result: dict[str, Any] = {}
    for line in text.splitlines():
        m = re.match(r"^(\w[\w-]*):\s*(.*)$", line.strip())
        if m:
            result[m.group(1)] = m.group(2).strip().strip('"').strip("'")
    return result


def load_skills(skills_root: Path) -> tuple[dict[str, Skill], list[str]]:
    """Load all SKILL.md files from skills/<domain>/<name>/SKILL.md."""
    skills: dict[str, Skill] = {}
    errors: list[str] = []

    for skill_md in sorted(skills_root.rglob("SKILL.md")):
        domain_dir = skill_md.parent.parent
        domain = domain_dir.name
        skill_name = skill_md.parent.name
        skill_id = f"{domain}/{skill_name}"

        fm, _body, fm_err = _parse_frontmatter(skill_md.read_text(errors="replace"))
        if fm_err:
            errors.append(f"{skill_md}: {fm_err}")
            continue

        declared_name = fm.get("name", "")
        if declared_name and declared_name != skill_name:
            errors.append(
                f"Skill name mismatch: directory '{skill_name}' vs "
                f"frontmatter name '{declared_name}' in {skill_md}"
            )

        # Handle YAML block scalars in description (>-, |-, etc.)
        raw_desc = fm.get("description", "")
        if isinstance(raw_desc, str) and raw_desc.strip() in (">-", ">", "|-", "|", ">+", "|+"):
            # Extract from raw frontmatter text
            raw_text = skill_md.read_text(errors="replace")
            fm_match = re.search(r"^---[ \t]*\n(.*?)\n---", raw_text, re.DOTALL)
            if fm_match:
                fm_text = fm_match.group(1)
                block = re.search(
                    r"^description:[ \t]*[|>][\-+]?[ \t]*\n((?:[ \t]+.+\n?)+)",
                    fm_text, re.MULTILINE
                )
                if block:
                    lines = [l.strip() for l in block.group(1).splitlines() if l.strip()]
                    raw_desc = " ".join(lines)
        description = str(raw_desc).strip()[:120]

        skills[skill_id] = Skill(
            id=skill_id,
            name=skill_name,
            domain=domain,
            description=str(description).strip()[:120],
            stability=Stability(fm.get("stability", "stable")) if fm.get("stability") in ("stable", "experimental", "deprecated") else Stability.STABLE,
            source_path=skill_md,
            tags=fm.get("tags", []) if isinstance(fm.get("tags"), list) else [],
            compatibility=str(fm.get("compatibility", "")),
            metadata=fm,
        )

    return skills, errors


def load_agents(agents_root: Path) -> tuple[dict[str, Agent], list[str]]:
    """Load all AGENT.md files from agents/<name>/AGENT.md."""
    agents: dict[str, Agent] = {}
    errors: list[str] = []

    for agent_md in sorted(agents_root.rglob("AGENT.md")):
        agent_name = agent_md.parent.name
        fm, body, fm_err = _parse_frontmatter(agent_md.read_text(errors="replace"))
        if fm_err:
            errors.append(f"{agent_md}: {fm_err}")
            continue

        declared_name = fm.get("name", "")
        if declared_name and declared_name != agent_name:
            errors.append(
                f"Agent name mismatch: directory '{agent_name}' vs "
                f"frontmatter name '{declared_name}' in {agent_md}"
            )

        # Map tools string to list
        tools_str = fm.get("tools", "")
        # abstract_tools = []  # TODO: map from Claude-specific to abstract

        mc_str = fm.get("model_class", "inherit")
        mc = ModelClass(mc_str) if mc_str in ("fast", "balanced", "deep", "inherit") else ModelClass.INHERIT

        agents[agent_name] = Agent(
            id=agent_name,
            name=agent_name,
            description=str(fm.get("description", ""))[:200],
            instructions=body.strip(),
            model_class=mc,
            source_path=agent_md,
            metadata=fm,
        )

    return agents, errors


def load_products(products_yaml: Path) -> tuple[dict[str, Product], list[str]]:
    """Load products from distributions/products.yaml."""
    products: dict[str, Product] = {}
    errors: list[str] = []

    if not products_yaml.exists():
        return products, [f"products.yaml not found: {products_yaml}"]

    yaml = _require_yaml()
    data = yaml.safe_load(products_yaml.read_text()) or {}

    for p in data.get("products", []):
        pid = p.get("id", "")
        if not pid:
            errors.append("Product missing 'id' field")
            continue

        inc = p.get("includes", {})
        sec_data = p.get("security", {})
        sec = SecurityPolicy(
            approval_required=sec_data.get("approval_required", False),
            default_enabled=sec_data.get("default_enabled", True),
            rationale=sec_data.get("rationale", ""),
        )

        products[pid] = Product(
            id=pid,
            name=p.get("name", pid),
            description=p.get("description", ""),
            stability=Stability(p.get("stability", "stable")) if p.get("stability") in ("stable", "experimental", "deprecated") else Stability.STABLE,
            included_skills=inc.get("skills", []),
            included_agents=inc.get("agents", []),
            included_hooks=inc.get("hooks", []),
            included_mcp=inc.get("mcp", []),
            security=sec,
            target_overrides=p.get("targets", {}),
        )

    return products, errors


def load_graph(repo_root: Path) -> CanonicalGraph:
    """Load all canonical sources into a CanonicalGraph."""
    graph = CanonicalGraph()

    skills, errs = load_skills(repo_root / "skills")
    graph.skills.update(skills)
    graph.errors.extend(errs)

    agents, errs = load_agents(repo_root / "agents")
    graph.agents.update(agents)
    graph.errors.extend(errs)

    products_yaml = repo_root / "distributions" / "products.yaml"
    products, errs = load_products(products_yaml)
    graph.products.update(products)
    graph.errors.extend(errs)

    from agent_toolkit.compiler.hook_registry import load_hooks
    from agent_toolkit.compiler.mcp_registry import load_registry

    hooks_registry, hook_errs = load_hooks(repo_root / "capabilities" / "hooks")
    mcp_registry, mcp_errs = load_registry(repo_root / "mcp" / "registry")
    graph.errors.extend(hook_errs)
    graph.errors.extend(mcp_errs)

    # Validate references
    for pid, product in graph.products.items():
        for skill_id in product.included_skills:
            if skill_id not in graph.skills:
                graph.warnings.append(
                    f"Product '{pid}' references skill '{skill_id}' not found in skills/"
                )
        for agent_id in product.included_agents:
            if agent_id not in graph.agents:
                graph.warnings.append(
                    f"Product '{pid}' references agent '{agent_id}' not found in agents/"
                )
        for hook_id in product.included_hooks:
            if hook_id not in hooks_registry:
                graph.warnings.append(
                    f"Product '{pid}' references hook '{hook_id}' not found in capabilities/hooks/"
                )
        for mcp_id in product.included_mcp:
            if mcp_id not in mcp_registry:
                graph.warnings.append(
                    f"Product '{pid}' references MCP provider '{mcp_id}' not found in mcp/registry/"
                )

    return graph
