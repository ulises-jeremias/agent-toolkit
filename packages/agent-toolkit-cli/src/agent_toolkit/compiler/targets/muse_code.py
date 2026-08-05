"""
Muse Code target adapter (Meta).

Muse Code (https://developer.meta.com/ai/products/muse-code/) is Meta's agentic CLI for complex coding
workstreams. It follows the Agent Skills specification:

  Project scope: .agents/skills/<name>/SKILL.md
  User scope:    ~/.config/muse/skills/<name>/SKILL.md  (XDG: $XDG_CONFIG_HOME/muse)

Muse also supports `muse skills import --from claude|codex` to migrate
existing skills, and project-local `.agents/skills` which is the primary
portable contract (AGENTS.md as primary agent contract, .agents/skills
for skills).

This adapter generates static companion assets for Muse Code:

  skills/<name>/SKILL.md  — on-demand procedures (native SKILL.md format)
  agents/<name>/AGENT.md  — agent personas (for future muse agent support)

No plugin marketplace exists yet for Muse Code; install is via
`muse skills install` (personal scope) or git-tracked `.agents/skills`
(project scope). The adapter therefore uses package_type "skills" and
maturity "stable".

Install path: `agent-toolkit install --target muse-code` copies skills to
  ~/.config/muse/skills/ and/or .agents/skills/ via the installer.
"""

from __future__ import annotations

import json
from pathlib import Path

from agent_toolkit.compiler.model import (
    Agent,
    CanonicalGraph,
    CompilationResult,
    Product,
    Skill,
)
from agent_toolkit.compiler.targets.base import TargetAdapter


class MuseCodeAdapter(TargetAdapter):
    """Compiles agent-toolkit products into Muse Code skills."""

    target_id = "muse-code"
    package_type = "skills"
    maturity = "stable"

    def compile(
        self,
        graph: CanonicalGraph,
        product: Product,
        *,
        emit_registries: bool = False,
    ) -> CompilationResult:
        result = CompilationResult(target=self.target_id, product=product.id)
        out_dir = self.output_root / product.id

        # Emit skills — Muse uses the universal SKILL.md format (Agent Skills spec)
        for skill_id in product.included_skills:
            skill = graph.skills.get(skill_id)
            if skill is None:
                result.warnings.append(f"Skill '{skill_id}' not found — skipping")
                result.omitted.append(f"skill:{skill_id}")
                continue
            self._emit_skill(skill, out_dir, result)

        # Emit agents as .agents compatible markdown (future Muse agent support)
        for agent_id in product.included_agents:
            agent = graph.agents.get(agent_id)
            if agent is None:
                result.warnings.append(f"Agent '{agent_id}' not found — skipping")
                result.omitted.append(f"agent:{agent_id}")
                continue
            self._emit_agent(agent, out_dir, result)

        self._finalize_provenance(product, result)
        return result

    def _emit_skill(self, skill: Skill, out_dir: Path, result: CompilationResult) -> None:
        # Muse prefers `.agents/skills/<name>/SKILL.md` (project) and
        # `~/.config/muse/skills/<name>/SKILL.md` (user). We emit to `skills/`
        # which the installer maps to both locations.
        src = skill.source_path
        if src and src.is_file():
            content = src.read_text(encoding="utf-8")
        else:
            # Fallback: minimal frontmatter + description
            content = f"---\nname: {skill.name}\ndescription: {skill.description}\n---\n\n# {skill.name}\n\n{skill.description}\n"
        dest = out_dir / "skills" / skill.name / "SKILL.md"
        self._write_file(dest, content, result, source_file=src)
        result.emitted.append(f"skill:{skill.name}")

    def _emit_agent(self, agent: Agent, out_dir: Path, result: CompilationResult) -> None:
        src = getattr(agent, "source_path", None)
        if src and Path(src).is_file():
            content = Path(src).read_text(encoding="utf-8")
        else:
            content = f"---\nname: {agent.name}\ndescription: {getattr(agent, 'description', '')}\n---\n\n# {agent.name}\n"
        dest = out_dir / "agents" / agent.name / "AGENT.md"
        self._write_file(dest, content, result, source_file=src)
        result.emitted.append(f"agent:{agent.name}")

    def _build_plugin_json(self, product: Product, graph: CanonicalGraph | None = None) -> dict:  # noqa: ARG002
        return {
            "name": product.id,
            "version": getattr(product, "version", "0.0.0"),
            "description": getattr(product, "description", ""),
            "skills": list(product.included_skills),
            "agents": list(product.included_agents),
            "target": self.target_id,
        }
