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

try:
    import yaml
    _YAML = True
except ImportError:
    _YAML = False


def _parse_frontmatter(text: str) -> tuple[dict[str, Any], str]:
    """Parse YAML frontmatter from a Markdown file. Returns (frontmatter, body)."""
    m = re.match(r"^---[ \t]*\n(.*?)\n---[ \t]*\n?(.*)", text, re.DOTALL)
    if not m:
        return {}, text
    fm_text = m.group(1)
    body = m.group(2)
    if _YAML:
        try:
            fm = yaml.safe_load(fm_text) or {}
        except Exception:
            fm = {}
    else:
        fm = _simple_yaml(fm_text)
    return fm, body


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

        fm, _body = _parse_frontmatter(skill_md.read_text(errors="replace"))

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
        fm, body = _parse_frontmatter(agent_md.read_text(errors="replace"))

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

    if _YAML:
        data = yaml.safe_load(products_yaml.read_text()) or {}
    else:
        return products, ["PyYAML required to load products.yaml"]

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

    return graph
