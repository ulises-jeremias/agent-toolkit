"""
Gemini CLI extension adapter.

Generates a Gemini CLI extension bundle from the canonical IR.

Official docs:
  https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/index.md
  https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/reference.md
Gallery:
  https://geminicli.com/extensions/
Research:
  docs/research/platform-capability-matrix.md (2026-08-04)

Key differences from Claude Code / Cursor:
- Manifest: gemini-extension.json (at extension root)
- Commands: TOML format (not YAML frontmatter or Markdown)
  Skills map to Gemini commands via TOML definitions
- MCP: native (mcpServers array in gemini-extension.json)
- Hooks: native (hooks/hooks.json, 8+ events: SessionStart, BeforeTool, etc.)
- Distribution: GitHub repo or geminicli.com gallery
- Path variables: use ${extensionPath} (not absolute paths)
- Context files: NOT a large always-on GEMINI.md — prefer minimal context
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

# Minimum Gemini CLI version supporting the extension system
MIN_GEMINI_CLI_VERSION = "0.1.0"

# Gemini uses TOML for commands — we generate a TOML block per skill
_TOML_COMMAND_TEMPLATE = """\
[[commands]]
name = "{name}"
description = "{description}"
"""


class GeminiCLIAdapter(TargetAdapter):
    """Compiles agent-toolkit products into Gemini CLI extension bundles.

    Extension is installable via:
      gemini extensions add ulises-jeremias/agent-toolkit-gemini

    Or linked for local development:
      gemini extensions link /path/to/extension

    Capability parity:
      native:              skills (as TOML commands), agents, plugin manifest
      native:              MCP (mcpServers in gemini-extension.json — pending MCP registry #15)
      native-experimental: hooks (hooks/hooks.json — pending canonical hook model #16)
      unsupported:         always-on GEMINI.md (prefer minimal context + commands)
    """

    target_id = "gemini-cli"
    package_type = "extension"
    maturity = "stable"

    def compile(self, graph: CanonicalGraph, product: Product) -> CompilationResult:
        result = CompilationResult(target=self.target_id, product=product.id)
        out_dir = self.output_root / product.id

        # 1. gemini-extension.json manifest
        manifest = self._build_manifest(product, graph)
        self._write_file(
            out_dir / "gemini-extension.json",
            json.dumps(manifest, indent=2) + "\n",
            result,
        )
        result.emitted.append("extension-manifest")

        # 2. Skills → bundled SKILL.md + TOML commands that inject the body via @{…}
        commands_toml_lines: list[str] = []
        for skill_id in product.included_skills:
            skill = graph.skills.get(skill_id)
            if skill is None:
                result.warnings.append(f"Skill '{skill_id}' not found — skipping")
                result.omitted.append(f"skill:{skill_id}")
                continue
            rel_skill = self._emit_skill_file(skill, out_dir, result)
            if rel_skill is None:
                continue
            commands_toml_lines.extend(self._skill_to_toml_command(skill, rel_skill))
            result.emitted.append(f"skill:{skill_id}")

        if commands_toml_lines:
            self._write_file(
                out_dir / "commands.toml",
                "\n".join(commands_toml_lines) + "\n",
                result,
            )
            result.emitted.append("commands.toml")

        # 3. Agent context files (minimal — not large always-on context)
        for agent_id in product.included_agents:
            agent = graph.agents.get(agent_id)
            if agent is None:
                result.warnings.append(f"Agent '{agent_id}' not found — skipping")
                result.omitted.append(f"agent:{agent_id}")
                continue
            self._emit_agent_context(agent, out_dir, result)

        # 4. Explicitly document pending capabilities
        result.unsupported.extend([
            "hooks (hooks/hooks.json — pending canonical hook model #16)",
            "mcp (mcpServers — pending MCP registry #15; field reserved in manifest)",
            "excludeTools (tool restrictions — pending agent model with abstract tools)",
        ])

        return result

    def _build_manifest(self, product: Product, graph: CanonicalGraph) -> dict:
        """Build gemini-extension.json manifest.

        Uses ${extensionPath} variable for bundled resource references.
        Never uses absolute machine paths.
        """
        try:
            from agent_toolkit import __version__
            version = __version__
        except ImportError:
            version = "1.0.0"

        manifest: dict = {
            "name": product.id,
            "version": version,
            "description": product.description,
            "author": "ulises-jeremias",
            "repository": "https://github.com/ulises-jeremias/agent-toolkit",
            "license": "MIT",
            "geminiCliVersion": f">={MIN_GEMINI_CLI_VERSION}",
            "contextFiles": [],      # Minimal context — no large always-on files
            "commands": "${extensionPath}/commands.toml",
            # MCP servers placeholder — populated by MCP registry (issue #15)
            # "mcpServers": [],
            # Hooks placeholder — populated by hook model (issue #16)
            # "hooks": "${extensionPath}/hooks/hooks.json",
        }
        return manifest

    def _emit_skill_file(
        self, skill: Skill, out_dir: Path, result: CompilationResult
    ) -> str | None:
        """Copy SKILL.md into the extension bundle; return path relative to out_dir."""
        if not skill.source_path.exists():
            result.warnings.append(f"Skill source missing: {skill.source_path}")
            result.omitted.append(f"skill:{skill.id}")
            return None

        dst = out_dir / "skills" / skill.name
        dst.mkdir(parents=True, exist_ok=True)
        content = skill.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(dst / "SKILL.md", content, result)

        refs_src = skill.source_path.parent / "references"
        if refs_src.is_dir():
            for ref_file in sorted(refs_src.rglob("*")):
                if ref_file.is_file():
                    rel = ref_file.relative_to(skill.source_path.parent)
                    ref_content = ref_file.read_text(encoding="utf-8", errors="replace")
                    self._write_file(dst / rel, ref_content, result)

        return f"skills/{skill.name}/SKILL.md"

    def _skill_to_toml_command(self, skill: Skill, skill_relpath: str) -> list[str]:
        """Convert a canonical skill to a Gemini TOML command block.

        Gemini CLI uses TOML for command definitions. The prompt injects the
        bundled SKILL.md via ``@{path}`` so maturity=stable ships real body
        content (not a stub pointer).
        """
        safe_name = skill.name.replace("-", "_").replace(" ", "_")
        desc = (skill.description or "").replace('"', "'")[:200]

        lines = [
            "[[commands]]",
            f'name = "{safe_name}"',
            f'description = "{desc}"',
            'prompt = """',
            f"Follow the `{skill.name}` skill instructions for {{{{args}}}}.",
            "",
            f"@{{{skill_relpath}}}",
            '"""',
            "",
        ]
        return lines

    def _emit_agent_context(
        self, agent: Agent, out_dir: Path, result: CompilationResult
    ) -> None:
        """Emit a minimal agent context file.

        Gemini prefers on-demand commands over large always-on context.
        We emit a compact context file, not the full AGENT.md.
        """
        if not agent.source_path.exists():
            result.warnings.append(f"Agent source missing: {agent.source_path}")
            result.omitted.append(f"agent:{agent.id}")
            return

        ctx_dir = out_dir / "context"
        ctx_dir.mkdir(parents=True, exist_ok=True)

        # Copy full AGENT.md for reference — context is opt-in
        content = agent.source_path.read_text(encoding="utf-8", errors="replace")
        self._write_file(ctx_dir / f"{agent.name}.md", content, result)
        result.emitted.append(f"agent:{agent.id}")
