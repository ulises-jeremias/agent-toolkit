"""
Cursor IDE/CLI target adapter.

Compiles canonical IR into Cursor plugin bundles:
  plugins/<product-id>/.cursor-plugin/plugin.json   — marketplace manifest
  plugins/<product-id>/skills/<name>/SKILL.md        — on-demand procedures
  plugins/<product-id>/agents/<name>/AGENT.md        — agent personas

Key differences from Claude Code:
- Manifest key is `.cursor-plugin/`, not `.claude-plugin/`
- Rules (.mdc) are a separate surface from skills:
    * Rules = persistent behavioral constraints (always-on in session)
    * Skills = on-demand procedures with resources (invoked explicitly)
  Rules are generated from agent/assistant instructions; they are NOT
  a substitute for skills in the plugin bundle.
- Hook event names differ (workspaceOpen, sessionStart vs session.start)
- MCP config goes in .cursor/mcp.json, not .mcp.json

Official docs: https://cursor.com/docs/plugins
Research: docs/research/platform-capability-matrix.md (2026-08-04)
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path

from agent_toolkit.compiler.model import (
    Agent,
    CanonicalGraph,
    CompilationResult,
    Product,
    Skill,
)
from agent_toolkit.compiler.targets.base import TargetAdapter


# Cursor supports these .mdc rule frontmatter fields.
# We generate rules only from skill/agent behavioral constraints —
# NOT as a substitute for skills in the plugin bundle.
_CURSOR_RULE_HEADER = """\
---
description: {description}
alwaysApply: {always_apply}
---
"""


class CursorAdapter(TargetAdapter):
    """Compiles agent-toolkit products into Cursor plugin bundles.

    Cursor reads both IDE and CLI from the same plugin bundle.
    The generated bundle is installable via the Cursor marketplace or
    local plugin development linking.

    Capability parity:
      native:               skills, agents, plugin manifest
      native-experimental:  hooks (not yet implemented — pending hook model)
      manual:               MCP (user configures ~/.cursor/mcp.json separately)
      unsupported:          Windsurf-style always-on global rules
    """

    target_id = "cursor"
    package_type = "plugin"
    maturity = "stable"

    def compile(self, graph: CanonicalGraph, product: Product) -> CompilationResult:
        result = CompilationResult(target=self.target_id, product=product.id)
        out_dir = self.output_root / product.id

        # 1. Emit .cursor-plugin/plugin.json
        plugin_json = self._build_plugin_json(product)
        self._write_file(
            out_dir / ".cursor-plugin" / "plugin.json",
            json.dumps(plugin_json, indent=2) + "\n",
            result,
        )
        result.emitted.append("plugin-manifest")

        # 2. Emit skills (same Agent Skills SKILL.md format as Claude Code)
        for skill_id in product.included_skills:
            skill = graph.skills.get(skill_id)
            if skill is None:
                result.warnings.append(f"Skill '{skill_id}' not found — skipping")
                result.omitted.append(f"skill:{skill_id}")
                continue
            self._emit_skill(skill, out_dir, result)

        # 3. Emit agents (AGENT.md format)
        for agent_id in product.included_agents:
            agent = graph.agents.get(agent_id)
            if agent is None:
                result.warnings.append(f"Agent '{agent_id}' not found — skipping")
                result.omitted.append(f"agent:{agent_id}")
                continue
            self._emit_agent(agent, out_dir, result)

        # 4. Explicitly document unsupported/pending capabilities
        #    (never silently drop — always report)
        result.unsupported.extend([
            "hooks (pending canonical hook model — Cursor uses workspaceOpen/sessionStart events)",
            "mcp (.cursor/mcp.json — user configures manually; not bundled in plugin)",
            "cursor-rules (.mdc) — generated as a separate profile surface, not in plugin bundle",
        ])

        return result

    # ── manifest ──────────────────────────────────────────────────────────────

    def _build_plugin_json(self, product: Product) -> dict:
        """Build the .cursor-plugin/plugin.json manifest.

        Schema matches Claude Code plugin.json (both platforms share this format),
        but Cursor resolves plugin root from .cursor-plugin/ not .claude-plugin/.
        """
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
                "email": "ulisescf.24@gmail.com",
            },
            "homepage": "https://github.com/ulises-jeremias/agent-toolkit",
            "repository": "https://github.com/ulises-jeremias/agent-toolkit",
            "license": "MIT",
            "keywords": [
                "agent-toolkit",
                product.id.replace("agent-toolkit-", ""),
                "cursor",
                "skills",
                "agents",
            ],
        }

    # ── skills ────────────────────────────────────────────────────────────────

    def _emit_skill(self, skill: Skill, out_dir: Path, result: CompilationResult) -> None:
        """Copy SKILL.md (and references/) into plugin skills/ directory.

        Cursor discovers skills at <plugin-root>/skills/<name>/SKILL.md —
        the same path as Claude Code. No transformation needed.
        """
        if not skill.source_path.exists():
            result.warnings.append(f"Skill source missing: {skill.source_path}")
            result.omitted.append(f"skill:{skill.id}")
            return

        dst = out_dir / "skills" / skill.name
        dst.mkdir(parents=True, exist_ok=True)

        content = skill.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "SKILL.md", content, result)

        # Copy references/ (progressive disclosure)
        self._copy_skill_references(skill, dst, result)

        result.emitted.append(f"skill:{skill.id}")

    # ── agents ────────────────────────────────────────────────────────────────

    def _emit_agent(self, agent: Agent, out_dir: Path, result: CompilationResult) -> None:
        """Copy AGENT.md into plugin agents/ directory.

        Cursor discovers agents at <plugin-root>/agents/<name>/AGENT.md.
        """
        if not agent.source_path.exists():
            result.warnings.append(f"Agent source missing: {agent.source_path}")
            result.omitted.append(f"agent:{agent.id}")
            return

        dst = out_dir / "agents" / agent.name
        dst.mkdir(parents=True, exist_ok=True)

        content = agent.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "AGENT.md", content, result)
        result.emitted.append(f"agent:{agent.id}")

    # ── parity document ───────────────────────────────────────────────────────

    @staticmethod
    def parity_notes() -> str:
        """Return honest parity notes for documentation generation."""
        return (
            "Cursor IDE and Cursor CLI both read from the same plugin bundle and "
            "the same ~/.cursor/rules/ directory. No separate surface needed.\n"
            "\n"
            "Rules (.mdc files) are generated separately as a profile surface "
            "(`profiles/cursor/rules/`) for users who install profiles manually. "
            "They are NOT duplicated inside the plugin bundle because rules represent "
            "persistent behavioral constraints, not the same semantic as on-demand skills.\n"
            "\n"
            "MCP: user configures ~/.cursor/mcp.json independently. The plugin does "
            "not bundle MCP server configuration (pending MCP registry implementation).\n"
            "\n"
            "Hooks: Cursor supports workspaceOpen, sessionStart, sessionEnd, and other "
            "lifecycle events. These require the canonical hook model to be defined first "
            "(see issue #16)."
        )
