<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%" alt="agent-toolkit banner">
</p>

<div align="center">

# Plugins

**Agent Plugins 1.0 portable bundles** plus legacy Claude Code / Cursor marketplaces.

[![Agent Plugins](https://img.shields.io/badge/Agent%20Plugins-1.0-7c3aed?style=flat&labelColor=1f2937)](https://agent-plugins.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-7c3aed?style=flat&labelColor=1f2937)](../LICENSE)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)
[![Validate](https://img.shields.io/github/actions/workflow/status/ulises-jeremias/agent-toolkit/validate.yml?branch=main&label=validate&style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/actions/workflows/validate.yml)

[Monorepo](https://github.com/ulises-jeremias/agent-toolkit) ·
[Installation](../docs/INSTALLATION.md) ·
[Agent Plugins spec](../docs/AGENT_PLUGINS.md)

</div>

This directory contains marketplace plugin bundles — now **Agent Plugins 1.0 portable** + legacy Claude Code / Cursor.

## Bundles

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

Plugins are kept in sync with canonical sources via `agent-toolkit build` and `agent-toolkit plugin sync`. Never edit plugin bundles directly — edit the canonical source (`skills/`, `agents/`, `mcp/registry/`) and re-run the build.

See [docs/AGENT_PLUGINS.md](../docs/AGENT_PLUGINS.md) for the full spec, support matrix, and migration guide.

## Validation

```bash
./scripts/validate-agent-plugins.vsh --check  # Agent Plugins 1.0
./scripts/validate-manifests.vsh              # Claude/Cursor legacy manifests
./scripts/validate-skills.vsh                 # SKILL.md frontmatter
```

## Spec

- <https://agent-plugins.org>
- <https://github.com/agentplugins/agent-plugins-spec> — v1.0.0 (2026-08-06)
