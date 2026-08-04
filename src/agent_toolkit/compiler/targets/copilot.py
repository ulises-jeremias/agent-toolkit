"""
GitHub Copilot CLI and Repository target adapter.

GitHub Copilot has TWO distinct distribution surfaces — both generated from
the same canonical IR but published separately:

1. **Copilot CLI Plugin** — installable via `copilot plugin install`
   Root-level `plugin.json` (NOT `.copilot-plugin/` — different schema
   from Claude Code / Cursor).
   Discovery paths: skills/, agents/, hooks.json

2. **Repository Surface** — files committed to a project repository
   `.github/copilot-instructions.md`    — global instructions
   `.github/agents/<name>.agent.md`     — agent personas (different format!)
   `.github/skills/<name>/SKILL.md`     — on-demand skills
   `.github/hooks/<name>.json`          — lifecycle hooks (future)

Official docs:
  https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference
Research:
  docs/research/platform-capability-matrix.md (2026-08-04)

Key differences from Claude Code / Cursor:
- CLI plugin.json is at ROOT level, not in .copilot-plugin/
- Agent format uses .agent.md extension (not AGENT.md)
- Each surface (CLI plugin, repository) must be generated independently
- Hooks require both Bash (.sh) AND PowerShell (.ps1) handlers
- MCP: unknown-blocked (not confirmed from official docs as of research date)
"""
from __future__ import annotations

import json
import textwrap
from pathlib import Path

from agent_toolkit.compiler.model import (
    Agent,
    CanonicalGraph,
    CompilationResult,
    Product,
    Skill,
)
from agent_toolkit.compiler.targets.base import TargetAdapter


class CopilotCLIAdapter(TargetAdapter):
    """Generates GitHub Copilot CLI plugin bundle.

    The plugin is installed via:
      copilot plugin install <name>@<marketplace>
    or declared in .github/copilot/settings.json.

    Capability parity:
      native:         skills, agents (.agent.md format), plugin manifest
      unknown-blocked: MCP (not confirmed from official docs)
      unsupported:    hooks (handler format unclear; cross-platform requires
                      both Bash + PowerShell — pending canonical hook model #16)
    """

    target_id = "copilot-cli"
    package_type = "plugin"
    maturity = "stable"

    def compile(self, graph: CanonicalGraph, product: Product) -> CompilationResult:
        result = CompilationResult(target=self.target_id, product=product.id)
        out_dir = self.output_root / product.id

        # 1. Root-level plugin.json (different from .claude-plugin/plugin.json)
        self._write_file(
            out_dir / "plugin.json",
            json.dumps(self._build_plugin_json(product), indent=2) + "\n",
            result,
        )
        result.emitted.append("plugin-manifest")

        # 2. Skills
        for skill_id in product.included_skills:
            skill = graph.skills.get(skill_id)
            if skill is None:
                result.warnings.append(f"Skill '{skill_id}' not found — skipping")
                result.omitted.append(f"skill:{skill_id}")
                continue
            self._emit_skill(skill, out_dir, result)

        # 3. Agents (.agent.md format — distinct from AGENT.md)
        for agent_id in product.included_agents:
            agent = graph.agents.get(agent_id)
            if agent is None:
                result.warnings.append(f"Agent '{agent_id}' not found — skipping")
                result.omitted.append(f"agent:{agent_id}")
                continue
            self._emit_agent_cli(agent, out_dir, result)

        # 4. Explicitly report what is not yet implemented
        result.unsupported.extend([
            "hooks (cross-platform Bash+PowerShell handlers required — pending #16)",
            "mcp (unknown-blocked: not confirmed in official Copilot CLI docs)",
        ])

        return result

    def _build_plugin_json(self, product: Product) -> dict:
        try:
            from agent_toolkit import __version__
            version = __version__
        except ImportError:
            version = "1.0.0"

        return {
            "name": product.id,
            "version": version,
            "description": product.description,
            "author": {
                "name": "ulises-jeremias",
                "url": "https://github.com/ulises-jeremias/agent-toolkit",
            },
            "repository": "https://github.com/ulises-jeremias/agent-toolkit",
            "license": "MIT",
            "skills": "skills/",
            "agents": "agents/",
        }

    def _emit_skill(self, skill: Skill, out_dir: Path, result: CompilationResult) -> None:
        if not skill.source_path.exists():
            result.warnings.append(f"Skill source missing: {skill.source_path}")
            result.omitted.append(f"skill:{skill.id}")
            return

        dst = out_dir / "skills" / skill.name
        dst.mkdir(parents=True, exist_ok=True)
        content = skill.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "SKILL.md", content, result)

        refs_src = skill.source_path.parent / "references"
        if refs_src.is_dir():
            for ref_file in sorted(refs_src.rglob("*")):
                if ref_file.is_file():
                    rel = ref_file.relative_to(skill.source_path.parent)
                    ref_dst = dst / rel
                    ref_dst.parent.mkdir(parents=True, exist_ok=True)
                    ref_dst.write_bytes(ref_file.read_bytes())
                    result.artifacts.append(ref_dst)

        result.emitted.append(f"skill:{skill.id}")

    def _emit_agent_cli(self, agent: Agent, out_dir: Path, result: CompilationResult) -> None:
        """Emit agent in Copilot CLI .agent.md format.

        The Copilot CLI agent format uses <name>.agent.md (not AGENT.md).
        Content is the same AGENT.md body with frontmatter.
        """
        if not agent.source_path.exists():
            result.warnings.append(f"Agent source missing: {agent.source_path}")
            result.omitted.append(f"agent:{agent.id}")
            return

        dst = out_dir / "agents"
        dst.mkdir(parents=True, exist_ok=True)

        content = agent.source_path.read_text(encoding="utf-8", errors="replace")
        # Write as <name>.agent.md (Copilot CLI convention)
        self._write_file(dst / f"{agent.name}.agent.md", content, result)
        result.emitted.append(f"agent:{agent.id}")


class CopilotRepositoryAdapter(TargetAdapter):
    """Generates GitHub Copilot repository-scoped assets.

    These are committed to a project repository and activate for
    all Copilot surfaces (IDE, cloud-agent, CLI) within that repo.

    Generated files:
      .github/copilot-instructions.md     ← global instructions
      .github/agents/<name>.agent.md      ← agent personas
      .github/skills/<name>/SKILL.md      ← on-demand skills

    Capability parity:
      native:      copilot-instructions.md, agents (.agent.md), skills
      unsupported: hooks, MCP (not confirmed for repository surface)
    """

    target_id = "copilot-repository"
    package_type = "repository-customization"
    maturity = "stable"

    def compile(self, graph: CanonicalGraph, product: Product) -> CompilationResult:
        result = CompilationResult(target=self.target_id, product=product.id)
        out_dir = self.output_root / product.id

        # 1. Global instructions from assistant agent body
        self._emit_instructions(graph, product, out_dir, result)

        # 2. Skills
        for skill_id in product.included_skills:
            skill = graph.skills.get(skill_id)
            if skill is None:
                result.omitted.append(f"skill:{skill_id}")
                continue
            self._emit_skill_repo(skill, out_dir, result)

        # 3. Agents
        for agent_id in product.included_agents:
            agent = graph.agents.get(agent_id)
            if agent is None:
                result.omitted.append(f"agent:{agent_id}")
                continue
            self._emit_agent_repo(agent, out_dir, result)

        result.unsupported.extend([
            "hooks (unknown-blocked for repository surface)",
            "mcp (unknown-blocked for repository surface)",
        ])
        return result

    def _emit_instructions(
        self, graph: CanonicalGraph, product: Product, out_dir: Path, result: CompilationResult
    ) -> None:
        """Generate .github/copilot-instructions.md from assistant agent."""
        # Build instructions from assistant agent + product description
        lines = [
            f"# {product.name}",
            "",
            product.description,
            "",
            "## Available skills",
            "",
        ]
        for skill_id in product.included_skills:
            skill = graph.skills.get(skill_id)
            if skill:
                lines.append(f"- **{skill.name}**: {skill.description[:80]}")
        lines.extend(["", "## Available agents", ""])
        for agent_id in product.included_agents:
            agent = graph.agents.get(agent_id)
            if agent:
                lines.append(f"- **{agent.name}**: {agent.description[:80]}")

        content = "\n".join(lines) + "\n"
        github_dir = out_dir / ".github"
        github_dir.mkdir(parents=True, exist_ok=True)
        self._write_file(github_dir / "copilot-instructions.md", content, result)
        result.emitted.append("copilot-instructions.md")

    def _emit_skill_repo(self, skill: Skill, out_dir: Path, result: CompilationResult) -> None:
        if not skill.source_path.exists():
            result.omitted.append(f"skill:{skill.id}")
            return
        dst = out_dir / ".github" / "skills" / skill.name
        dst.mkdir(parents=True, exist_ok=True)
        content = skill.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "SKILL.md", content, result)
        result.emitted.append(f"skill:{skill.id}")

    def _emit_agent_repo(self, agent: Agent, out_dir: Path, result: CompilationResult) -> None:
        if not agent.source_path.exists():
            result.omitted.append(f"agent:{agent.id}")
            return
        dst = out_dir / ".github" / "agents"
        dst.mkdir(parents=True, exist_ok=True)
        content = agent.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / f"{agent.name}.agent.md", content, result)
        result.emitted.append(f"agent:{agent.id}")
