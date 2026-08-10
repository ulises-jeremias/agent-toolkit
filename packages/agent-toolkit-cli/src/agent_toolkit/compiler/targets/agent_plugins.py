"""
Agent Plugins 1.0 target adapter — portable plugin format.

Compiles canonical IR into Agent Plugins 1.0 compliant bundles:
  plugins/<product-id>/plugin.json      — manifest with $schema
  plugins/<product-id>/skills/<name>/SKILL.md
  plugins/<product-id>/mcp.json         — if product includes MCP
  plugins/<product-id>/com.anthropic.claude-code/ — extension dir (agents/hooks)

Spec: https://agent-plugins.org/ + https://github.com/agentplugins/agent-plugins-spec
Clients: Cursor, VS Code, GitHub Copilot, ChatGPT/Codex, Kiro — NOT Claude Code (legacy .claude-plugin kept).

This adapter is the source of truth for the plugin root manifest; bump-version preserves $schema.
"""

from __future__ import annotations

import json
from pathlib import Path

from agent_toolkit.compiler.model import CanonicalGraph, CompilationResult, Product, Skill
from agent_toolkit.compiler.targets.base import TargetAdapter


class AgentPluginsAdapter(TargetAdapter):
    """Compiles products into Agent Plugins 1.0 portable bundles."""

    target_id = "agent-plugins"
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

        # 1. Emit portable manifest at plugin root
        plugin_json = self._build_plugin_json(product)
        self._write_file(
            out_dir / "plugin.json",
            json.dumps(plugin_json, indent=2) + "\n",
            result,
        )
        result.emitted.append("plugin-manifest")

        # 2. Emit skills (Agent Skills spec, immediate children of skills/)
        for skill_id in product.included_skills:
            skill = graph.skills.get(skill_id)
            if skill is None:
                result.warnings.append(f"Skill '{skill_id}' not found — skipping")
                result.omitted.append(f"skill:{skill_id}")
                continue
            self._emit_skill(skill, out_dir, result)

        # 3. Emit MCP if included
        from agent_toolkit.compiler.registry_emit import (
            mcp_json_text_agent_plugins,
            resolve_mcp_ids,
        )

        # We need to support both legacy mcp registry and new agent-plugins mcp.json
        # For now, emit mcp.json if product has mcp
        try:
            mcp_ids = resolve_mcp_ids(
                product.included_mcp,
                target_id=self.target_id,
                registry_dir=self.repo_root / "mcp" / "registry",
                emit_registries=emit_registries,
            )
            if mcp_ids:
                mcp_text = mcp_json_text_agent_plugins(
                    mcp_ids, self.repo_root / "mcp" / "registry", self.target_id
                )
                if mcp_text:
                    self._write_file(out_dir / "mcp.json", mcp_text, result)
                    result.emitted.append("mcp")
        except Exception as e:
            result.warnings.append(f"MCP emit failed: {e}")

        # 4. Document non-portable components (agents/hooks) as extension
        if product.included_agents or product.included_hooks:
            result.unsupported.append(
                "agents/hooks are not portable in Agent Plugins 1.0 — emitted via com.anthropic.claude-code/ extension (ignored by portable clients)"
            )

        return result

    def _build_plugin_json(self, product: Product) -> dict:
        try:
            from agent_toolkit import __version__

            version = __version__
        except ImportError:
            version = "1.0.0"

        # Map product id to keywords
        keywords = ["agent-toolkit", product.id.replace("agent-toolkit-", "")]
        if product.id == "agent-toolkit-core":
            keywords = ["agent-toolkit", "core", "skills", "agents"]
        elif product.id == "agent-toolkit-complete":
            keywords = ["agent-toolkit", "complete", "skills", "agents", "mcp"]

        return {
            "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
            "name": product.id,
            "version": version,
            "description": product.description,
            "author": {
                "name": "ulises-jeremias",
                "url": "https://github.com/ulises-jeremias/agent-toolkit",
            },
            "homepage": "https://github.com/ulises-jeremias/agent-toolkit",
            "repository": "https://github.com/ulises-jeremias/agent-toolkit",
            "license": "MIT",
            "keywords": keywords,
            "extensions": {
                "com.anthropic.claude-code": {
                    "agents": "agents/",
                    "hooks": "hooks/",
                    "skills": "skills/",
                },
                "com.agent-toolkit.cli": {
                    "product": product.id,
                    "stability": product.stability.value
                    if hasattr(product.stability, "value")
                    else str(product.stability),
                },
            },
        }

    def _emit_skill(self, skill: Skill, out_dir: Path, result: CompilationResult) -> None:
        if not skill.source_path.exists():
            result.warnings.append(f"Skill source not found: {skill.source_path}")
            result.omitted.append(f"skill:{skill.id}")
            return
        dst = out_dir / "skills" / skill.name
        dst.mkdir(parents=True, exist_ok=True)
        content = skill.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "SKILL.md", content, result)
        self._copy_skill_references(skill, dst, result)
        result.emitted.append(f"skill:{skill.id}")

    def _copy_skill_references(
        self, skill: Skill, dst: Path, result: CompilationResult, *, text_mode: bool = False
    ) -> None:
        # Copy references/ if present (text_mode kept for base compatibility)
        src_ref = skill.source_path.parent / "references"
        if src_ref.is_dir():
            import shutil

            dst_ref = dst / "references"
            if dst_ref.exists():
                shutil.rmtree(dst_ref)
            shutil.copytree(src_ref, dst_ref)
            result.emitted.append(f"skill:{skill.id}:references")
