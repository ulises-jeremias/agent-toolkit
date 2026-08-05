"""
OpenAI Codex target adapter.

OpenAI Codex launched a plugin marketplace in March 2026. As of the research
date (2026-08-04) it is in early experimental status — self-serve marketplace
submission is "coming soon" and the plugin API surface is still evolving.

**IMPORTANT**: This adapter is labeled ``maturity = "experimental"`` because:
  1. The Codex plugin API may change without notice.
  2. Marketplace submission requires explicit authorization from OpenAI.
  3. Hooks and MCP integration are unknown-blocked (not confirmed by official docs).

Generated artifacts:
  .codex-plugin/plugin.json    — manifest (different directory from .claude-plugin/)
  skills/<name>/SKILL.md       — on-demand procedures
  agents/<name>/AGENT.md       — agent personas

NOT generated:
  Hooks     — unknown-blocked; not confirmed in official Codex plugin docs.
  MCP       — unknown-blocked; not confirmed in official Codex plugin docs.

Marketplace note:
  Codex artifacts MUST NOT be submitted to the Codex marketplace without
  explicit authorization from OpenAI. The marketplace is gated as of 2026-08-04.
  Use this adapter to generate the plugin structure for local development only.

Path distinction from Claude Code / Cursor:
  Claude Code: .claude-plugin/plugin.json
  Cursor:      .cursor-plugin/plugin.json
  Codex:       .codex-plugin/plugin.json   ← this adapter

Research: docs/research/platform-capability-matrix.md (2026-08-04)
Marketplace: https://marketplace.openai.com/codex (gated, submission "coming soon")
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


# Settings that must never appear in a publicly distributed Codex plugin.
# These bypass safety mechanisms and are forbidden in any marketplace submission.
_FORBIDDEN_CODEX_SETTINGS = {
    "skipDangerousModePermissionPrompt",
    "autoAcceptPermissions",
    "disablePermissionPrompts",
    "allowUnsafeCode",
}

_PRIVATE_HOSTNAME_PATTERNS = (".local", "192.168.", "10.", "172.16.")


class CodexAdapter(TargetAdapter):
    """Compiles agent-toolkit products into OpenAI Codex plugin bundles.

    EXPERIMENTAL: The Codex plugin API launched in March 2026 and is still
    evolving. Self-serve marketplace submission is "coming soon" as of
    2026-08-04. Do NOT submit generated artifacts to the marketplace without
    explicit OpenAI authorization.

    The generated bundle structure mirrors the Codex plugin format:
      .codex-plugin/plugin.json   — manifest
      skills/<name>/SKILL.md      — on-demand skills
      agents/<name>/AGENT.md      — agent personas

    Capability parity:
      native (experimental):  plugin manifest, skills, agents
      unknown-blocked:        hooks (not confirmed in official Codex docs)
      unknown-blocked:        MCP (not confirmed in official Codex docs)
      unsupported:            lifecycle hooks, MCP integration

    Maturity: experimental — API may change without notice.
    """

    target_id = "codex"
    package_type = "plugin"
    maturity = "experimental"  # MUST remain "experimental" — marketplace is gated

    def compile(self, graph: CanonicalGraph, product: Product) -> CompilationResult:
        result = CompilationResult(target=self.target_id, product=product.id)
        out_dir = self.output_root / product.id

        # 1. Emit .codex-plugin/plugin.json (NOT .claude-plugin/ — different path)
        plugin_json = self._build_plugin_json(product)
        self._write_file(
            out_dir / ".codex-plugin" / "plugin.json",
            json.dumps(plugin_json, indent=2) + "\n",
            result,
        )
        result.emitted.append("plugin-manifest")

        # 2. Emit skills to skills/<name>/SKILL.md
        for skill_id in product.included_skills:
            skill = graph.skills.get(skill_id)
            if skill is None:
                result.warnings.append(f"Skill '{skill_id}' not found — skipping")
                result.omitted.append(f"skill:{skill_id}")
                continue
            self._emit_skill(skill, out_dir, result)

        # 3. Emit agents to agents/<name>/AGENT.md
        for agent_id in product.included_agents:
            agent = graph.agents.get(agent_id)
            if agent is None:
                result.warnings.append(f"Agent '{agent_id}' not found — skipping")
                result.omitted.append(f"agent:{agent_id}")
                continue
            self._emit_agent(agent, out_dir, result)

        # 4. Explicitly document unsupported capabilities.
        #    Never silently drop a capability — always report.
        result.unsupported.extend([
            "hooks — unknown-blocked: lifecycle hooks not confirmed in official Codex plugin docs",
            "mcp — unknown-blocked: MCP integration not confirmed in official Codex plugin docs",
        ])

        # 5. Add an experimental maturity warning to every compilation result.
        result.warnings.append(
            "Codex plugin API is experimental (maturity='experimental'). "
            "Do NOT submit to Codex marketplace without explicit OpenAI authorization. "
            "Self-serve submission is 'coming soon' as of 2026-08-04."
        )

        return result

    # ── manifest ──────────────────────────────────────────────────────────────

    def _build_plugin_json(self, product: Product) -> dict:
        """Build .codex-plugin/plugin.json manifest.

        The Codex manifest uses the same general shape as Claude Code / Cursor
        plugin.json but is placed in .codex-plugin/ (not .claude-plugin/).

        Security:
          - No forbidden settings (skipDangerousModePermissionPrompt, etc.)
          - No private hostnames or IPs
          - maturity field is always set to "experimental"
        """
        try:
            from agent_toolkit import __version__
            version = __version__
        except ImportError:
            version = "1.0.0"

        manifest = {
            "name": product.id,
            "version": version,
            "description": product.description,
            "maturity": self.maturity,  # always "experimental" — accurately labels this plugin
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
                "codex",
                "skills",
                "agents",
            ],
        }

        # Validate — raise loudly if forbidden settings sneak in
        errors = self.validate_plugin_json(manifest)
        # In practice this should never trigger since we build the dict above,
        # but defensive validation is always correct.
        for err in errors:
            raise ValueError(f"Generated Codex plugin.json is invalid: {err}")

        return manifest

    @staticmethod
    def validate_plugin_json(data: dict) -> list[str]:
        """Return error messages for any forbidden plugin.json fields or values."""
        errors = []
        for field in _FORBIDDEN_CODEX_SETTINGS:
            if field in data:
                errors.append(
                    f"Forbidden field '{field}' in .codex-plugin/plugin.json — "
                    "this setting bypasses safety mechanisms and is prohibited "
                    "in any Codex marketplace submission"
                )
        text = json.dumps(data)
        for pattern in _PRIVATE_HOSTNAME_PATTERNS:
            if pattern in text:
                errors.append(
                    f"Possible private hostname '{pattern}' in plugin.json — "
                    "public distributions must never contain machine-specific URLs"
                )
        return errors

    # ── skills ────────────────────────────────────────────────────────────────

    def _emit_skill(self, skill: Skill, out_dir: Path, result: CompilationResult) -> None:
        """Copy SKILL.md to skills/<name>/SKILL.md.

        Codex discovers skills at <plugin-root>/skills/<name>/SKILL.md —
        the same path convention as Claude Code and Cursor.
        """
        if not skill.source_path.exists():
            result.warnings.append(f"Skill source missing: {skill.source_path}")
            result.omitted.append(f"skill:{skill.id}")
            return

        dst = out_dir / "skills" / skill.name
        dst.mkdir(parents=True, exist_ok=True)

        content = skill.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "SKILL.md", content, result)

        # Progressive disclosure: copy references/
        self._copy_skill_references(skill, dst, result)

        result.emitted.append(f"skill:{skill.id}")

    # ── agents ────────────────────────────────────────────────────────────────

    def _emit_agent(self, agent: Agent, out_dir: Path, result: CompilationResult) -> None:
        """Copy AGENT.md to agents/<name>/AGENT.md."""
        if not agent.source_path.exists():
            result.warnings.append(f"Agent source missing: {agent.source_path}")
            result.omitted.append(f"agent:{agent.id}")
            return

        dst = out_dir / "agents" / agent.name
        dst.mkdir(parents=True, exist_ok=True)

        content = agent.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "AGENT.md", content, result)
        result.emitted.append(f"agent:{agent.id}")

    # ── parity notes ──────────────────────────────────────────────────────────

    @staticmethod
    def parity_notes() -> str:
        return (
            "OpenAI Codex plugin support is EXPERIMENTAL. The marketplace launched "
            "in March 2026 but self-serve submission is 'coming soon' as of 2026-08-04. "
            "Generated artifacts MUST NOT be submitted to the marketplace without "
            "explicit authorization from OpenAI.\n"
            "\n"
            "Manifest path: .codex-plugin/plugin.json\n"
            "  (distinct from .claude-plugin/ and .cursor-plugin/ — same general schema)\n"
            "\n"
            "Hooks and MCP are unknown-blocked — neither surface is confirmed by "
            "official Codex plugin documentation. They are explicitly reported in "
            "CompilationResult.unsupported rather than silently dropped.\n"
            "\n"
            "The ``maturity`` field in plugin.json is always set to 'experimental' "
            "to accurately represent the current state of the Codex plugin ecosystem. "
            "This must not be changed to 'stable' until the Codex plugin API is "
            "officially stable and marketplace submission is open to all publishers."
        )
