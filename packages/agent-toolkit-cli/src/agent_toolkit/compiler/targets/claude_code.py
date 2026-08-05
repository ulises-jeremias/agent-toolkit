"""
Claude Code target adapter.

Compiles canonical IR into Claude Code plugin bundles:
  plugins/<product-id>/.claude-plugin/plugin.json
  plugins/<product-id>/skills/<name>/SKILL.md
  plugins/<product-id>/agents/<name>/AGENT.md
  plugins/<product-id>/.mcp.json  (TODO: from MCP registry)
  plugins/<product-id>/hooks/hooks.json  (TODO: from hooks model)

Official docs: https://code.claude.com/docs/en/plugins
"""
from __future__ import annotations

import json
from pathlib import Path

from agent_toolkit.compiler.model import (
    CanonicalGraph, CompilationResult, Product, Skill, Agent,
)
from agent_toolkit.compiler.targets.base import TargetAdapter


FORBIDDEN_SETTINGS = {
    "skipDangerousModePermissionPrompt",
    "autoAcceptPermissions",
    "disablePermissionPrompts",
}


class ClaudeCodeAdapter(TargetAdapter):
    """Compiles agent-toolkit products into Claude Code plugin bundles."""

    target_id = "claude-code"
    package_type = "plugin"
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
        hooks_dir = self.repo_root / "capabilities" / "hooks"
        mcp_dir = self.repo_root / "mcp" / "registry"

        # Emit plugin.json
        plugin_json = self._build_plugin_json(product, graph)
        self._write_file(
            out_dir / ".claude-plugin" / "plugin.json",
            json.dumps(plugin_json, indent=2) + "\n",
            result,
        )
        result.emitted.append("plugin-manifest")

        # Emit skills
        for skill_id in product.included_skills:
            skill = graph.skills.get(skill_id)
            if skill is None:
                result.warnings.append(f"Skill '{skill_id}' not found — skipping")
                result.omitted.append(f"skill:{skill_id}")
                continue
            self._emit_skill(skill, out_dir, result)

        # Emit agents
        for agent_id in product.included_agents:
            agent = graph.agents.get(agent_id)
            if agent is None:
                result.warnings.append(f"Agent '{agent_id}' not found — skipping")
                result.omitted.append(f"agent:{agent_id}")
                continue
            self._emit_agent(agent, out_dir, result)

        from agent_toolkit.compiler.registry_emit import (
            hooks_json_text,
            mcp_json_text,
            resolve_hook_ids,
            resolve_mcp_ids,
        )

        hook_ids = resolve_hook_ids(
            product.included_hooks,
            target_id=self.target_id,
            hooks_dir=hooks_dir,
            emit_registries=emit_registries,
        )
        hooks_text = hooks_json_text(hook_ids, hooks_dir, self.target_id)
        if hooks_text:
            self._write_file(out_dir / "hooks" / "hooks.json", hooks_text, result)
            result.emitted.append("hooks")

        mcp_ids = resolve_mcp_ids(
            product.included_mcp,
            target_id=self.target_id,
            registry_dir=mcp_dir,
            emit_registries=emit_registries,
        )
        mcp_text = mcp_json_text(mcp_ids, mcp_dir, self.target_id)
        if mcp_text:
            self._write_file(out_dir / ".mcp.json", mcp_text, result)
            result.emitted.append("mcp")

        pending: list[str] = []
        if not hook_ids:
            pending.append("hooks (hooks/hooks.json — none included for this product)")
        if not mcp_ids:
            pending.append(".mcp.json (none included for this product)")
        result.unsupported.extend(pending)

        return result

    def _build_plugin_json(self, product: Product, graph: CanonicalGraph) -> dict:
        """Build the .claude-plugin/plugin.json manifest."""
        import sys

        # Import version from package
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
            "keywords": ["agent-toolkit", product.id.replace("agent-toolkit-", "")],
        }

    def _emit_skill(self, skill: Skill, out_dir: Path, result: CompilationResult) -> None:
        """Copy skill SKILL.md to plugin bundle skills/ directory."""
        if not skill.source_path.exists():
            result.warnings.append(f"Skill source not found: {skill.source_path}")
            result.omitted.append(f"skill:{skill.id}")
            return

        # Claude Code discovers skills at <plugin-root>/skills/<name>/SKILL.md
        dst = out_dir / "skills" / skill.name
        dst.mkdir(parents=True, exist_ok=True)

        # Copy SKILL.md
        content = skill.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "SKILL.md", content, result)

        # Copy references/ directory if present
        self._copy_skill_references(skill, dst, result)

        result.emitted.append(f"skill:{skill.id}")

    def _emit_agent(self, agent: Agent, out_dir: Path, result: CompilationResult) -> None:
        """Copy agent AGENT.md to plugin bundle agents/ directory."""
        if not agent.source_path.exists():
            result.warnings.append(f"Agent source not found: {agent.source_path}")
            result.omitted.append(f"agent:{agent.id}")
            return

        dst = out_dir / "agents" / agent.name
        dst.mkdir(parents=True, exist_ok=True)

        content = agent.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "AGENT.md", content, result)
        result.emitted.append(f"agent:{agent.id}")

    @staticmethod
    def validate_settings(settings: dict) -> list[str]:
        """Validate a settings.json for forbidden fields."""
        return [
            f"Forbidden setting: {k} — must not ship in public plugin defaults"
            for k in FORBIDDEN_SETTINGS
            if k in settings
        ]

    @staticmethod
    def parity_notes() -> str:
        """Return honest parity notes for certification docs."""
        return (
            "Claude Code plugin bundles emit skills, agents, and plugin.json under "
            ".claude-plugin/. Hooks and .mcp.json are not generated yet — reported as "
            "unsupported until the canonical hook model and MCP registry are wired in.\n"
            "\n"
            "Never ship or overwrite ~/.claude/settings.json from public profiles. "
            "Plugin settings are plugin-local; users enable marketplace plugins in their "
            "own settings file."
        )
