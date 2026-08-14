# Plugins

This directory contains marketplace plugin bundles — now **Agent Plugins 1.0 portable** + legacy Claude Code / Cursor.

## Plugins

| Plugin | What's included | Portable (Agent Plugins 1.0) | Legacy |
|--------|----------------|------------------------------|--------|
| `agent-toolkit-core` | Core skills + code-reviewer agent + github MCP | `plugin.json` + `skills/` + `mcp.json` | `.claude-plugin/` + `agents/` |
| `agent-toolkit-agents` | All 16 agent personas | `plugin.json` + `agents/` via extension | `.claude-plugin/` |
| `agent-toolkit-forge` | GitHub/GitLab automation skills | `plugin.json` + `skills/` | `.claude-plugin/` |
| `agent-toolkit-complete` | Full catalog + MCP | `plugin.json` + `skills/` + `mcp.json` | `.claude-plugin/` |

## Adding the marketplace

**Claude Code (legacy):**
```
/plugin marketplace add ulises-jeremias/agent-toolkit
```

**Cursor / VS Code / Copilot / Codex / Kiro (Agent Plugins 1.0):**
- Cursor: Dashboard → Plugins → Import `https://github.com/ulises-jeremias/agent-toolkit` (discovers `plugin.json` at plugin root)
- VS Code / Copilot: discover `plugin.json` + `skills/` + `mcp.json` per spec
- Or: `uvx --from agent-toolkit-cli agent-toolkit install` (auto-detects and installs to each client's plugin dir)

## Structure

Each plugin is **dual emit** — portable + legacy for Claude Code:

```text
plugins/<plugin-name>/
├── plugin.json                 ← Agent Plugins 1.0 manifest ($schema, name, extensions)
├── mcp.json                    ← Agent Plugins MCP (if product includes MCP)
├── skills/                     ← Portable skills (immediate children with SKILL.md)
│   └── <name>/SKILL.md
├── agents/                     ← Legacy agents (ignored by Agent Plugins clients, kept for Claude)
├── .claude-plugin/
│   └── plugin.json             ← Claude Code marketplace metadata (legacy, kept until Claude supports Agent Plugins)
├── .cursor-plugin/
│   └── plugin.json             ← Cursor marketplace metadata (legacy, kept)
└── com.anthropic.claude-code/  ← Extension namespace for Claude-specific hooks/agents (per §8)
    └── README.md
```

Portable vs legacy:
- **Portable v1:** `plugin.json` + `skills/` + `mcp.json` (spec §4-§7). Validated via `schemas/agent-plugins/1.0.0/*.schema.json`.
- **Not portable v1:** `agents/`, `hooks/`, `commands`, `rules` — remain client-specific in `com.anthropic.claude-code/` and are ignored by Agent Plugins clients.

Plugins are kept in sync with canonical sources via `scripts/gen-surfaces.vsh` and the compiler (`agent_toolkit.compiler.targets.agent_plugins`). Never edit plugin bundles directly — edit the canonical source (`skills/`, `agents/`, `mcp/registry/`) and re-run the build.

See [docs/AGENT_PLUGINS.md](../docs/AGENT_PLUGINS.md) for the full spec, support matrix, and migration guide.

## Validation

```bash
v run scripts/validate-agent-plugins.vsh --check  # Agent Plugins 1.0
v run scripts/validate-manifests.vsh              # Claude/Cursor legacy manifests
v run scripts/validate-skills.vsh                 # SKILL.md frontmatter
```

## Spec

- <https://agent-plugins.org>
- <https://github.com/agentplugins/agent-plugins-spec> — v1.0.0 (2026-08-06)
