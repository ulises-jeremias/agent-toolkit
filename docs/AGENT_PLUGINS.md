# Agent Plugins 1.0 — Portable Plugin Standard

> **Spec:** [`agent-plugins.org`](https://agent-plugins.org) + [`agentplugins/agent-plugins-spec`](https://github.com/agentplugins/agent-plugins-spec) — v1.0.0 published 2026-08-06 by Vercel + AWS + Anysphere (Cursor) + GitHub + Microsoft + OpenAI.

`agent-toolkit` now emits **Agent Plugins 1.0 compliant** plugin bundles for every compatible client, while keeping **dual compatibility with Claude Code** (which does not yet support the standard) via legacy `.claude-plugin/` manifests.

## What Agent Plugins solves

Agent Skills (`SKILL.md`) and MCP servers are reusable across clients, but clients historically expected different metadata paths. Agent Plugins gives them **one predictable home**:

```text
my-plugin/
├── plugin.json                 # $schema + name (portable manifest)
├── skills/
│   └── summarize/
│       ├── SKILL.md
│       ├── scripts/
│       └── references/
├── mcp.json                    # $schema + mcpServers (stdio / streamable-http)
└── com.example.client/         # client-specific extension (reverse-domain)
```

A minimal manifest:

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "my-plugin"
}
```

Clients that support Skills discover them under `skills/`; those that support MCP read `mcp.json`. One invalid component does not disable the others.

## Support matrix in this repo

| Client | Agent Plugins 1.0 | Legacy path | Notes |
|---|---|---|---|
| **Claude Code** | ❌ No | `plugins/<id>/.claude-plugin/plugin.json` + `skills/` + `agents/` + `hooks/` | Dual emit keeps `plugin.json` at root compliant + legacy dir. See [plugins/README.md](../plugins/README.md). |
| **Cursor** | ✅ Yes | `plugins/<id>/.cursor-plugin/plugin.json` (kept) + `plugins/<id>/plugin.json` (portable) | Cursor reads portable `plugin.json` + `skills/` + `mcp.json`; extension `com.cursor.*` ignored by others. |
| **VS Code** | ✅ Yes | `plugin.json` at root |  |
| **GitHub Copilot** | ✅ Yes |  | Copilot CLI + Copilot Repository targets also emit `plugin.json` |
| **ChatGPT / Codex** | ✅ Yes | `.codex-plugin/plugin.json` kept |  |
| **Kiro** | ✅ Yes |  |  |

**Result:** `agent-toolkit` authors a skill once (`skills/<domain>/<name>/SKILL.md`) and the compiler emits it to **all** of the above via one build.

## What v1 covers (and what it doesn't)

- **Portable v1:** `skills/` + `mcp.json` only. Both have their own specs; Agent Plugins only defines *discovery* and *loading*.
- **Not portable v1:** `agents/`, `hooks/`, `commands`, `rules` — these remain **client-specific** and live in extension namespaces:

```text
plugins/agent-toolkit-core/
├── plugin.json                 # portable
├── skills/                     # portable
├── mcp.json                    # portable (github)
├── agents/                     # legacy, ignored by Agent Plugins clients per §7/§8
├── .claude-plugin/plugin.json  # legacy Claude Code
└── com.anthropic.claude-code/  # extension namespace for Claude-specific hooks/agents
    └── README.md
```

`extensions` in `plugin.json` declares the mapping:

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "agent-toolkit-core",
  "version": "1.8.4",
  "extensions": {
    "com.anthropic.claude-code": { "agents": "agents/", "hooks": "hooks/" },
    "com.agent-toolkit.cli": { "product": "agent-toolkit-core", "stability": "stable" }
  }
}
```

Other clients ignore `com.anthropic.claude-code`.

## MCP in Agent Plugins

Portable `mcp.json` (closed schema, no top-level extra):

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  "mcpServers": {
    "github": {
      "type": "stdio",
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN", "ghcr.io/github/github-mcp-server"],
      "cwd": "${PLUGIN_ROOT}",
      "env": { "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}" }
    },
    "slack": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "cwd": "${PLUGIN_ROOT}"
    }
  }
}
```

- `command` is a single token (bare name or `./`-relative path), no shell string, no placeholder expansion.
- `cwd` may be `./` relative, `${PLUGIN_ROOT}`, or `${PLUGIN_DATA}` (client-managed persistent dir, created before launch, preserved across updates).
- `args`/`env`/`cwd` support `${PLUGIN_ROOT}`/`${PLUGIN_DATA}` expansion (single, non-recursive).
- `env` must **not** contain `PLUGIN_ROOT`/`PLUGIN_DATA` (reserved, injected by client).
- Remote transports: `streamable-http` (current) and `sse` (legacy HTTP+SSE, optional). Clients MUST support at least one of `stdio` or `streamable-http`.

In `agent-toolkit`, `mcp/registry/*.yaml` is the canonical source; the compiler emits both legacy `.mcp.json` (Claude) and portable `mcp.json` (Agent Plugins) via `registry_emit.py`.

## Validation

Vendored schemas: `schemas/agent-plugins/1.0.0/plugin.schema.json` and `mcp.schema.json` (copied from spec).

```bash
python3 scripts/validate-agent-plugins.py        # all plugins
python3 scripts/validate-agent-plugins.py --check # CI mode
```

Checks: `$schema` const, `name` regex `^(?!.*(?:--|\\.\\.))[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$`, closed manifest (unknown top-level → report-and-ignore), `skills/` immediate children with `SKILL.md`, `mcp.json` closed, `command`/`cwd` containment, no `PLUGIN_ROOT` in `env`.

Compiler target `agent-plugins` (`capabilities/targets/registry.yaml` → `agent_toolkit.compiler.targets.agent_plugins.AgentPluginsAdapter`) emits `plugin.json` + `skills/` + `mcp.json` for every product. `scripts/bump-version.py` preserves `$schema` and `extensions` when bumping `plugins/*/plugin.json`.

## Installation

`agent-toolkit install` remains the primary entry-point:

```bash
uvx --from agent-toolkit-cli agent-toolkit install
# or
uv tool install agent-toolkit-cli && agent-toolkit install
```

The installer auto-detects clients:
- **Agent Plugins clients** (Cursor, VS Code, Copilot, Codex, Kiro): copies the portable plugin dir (`plugin.json` + `skills/` + `mcp.json`) to the client's plugin discovery path (e.g., `~/.cursor/plugins/`, `~/.vscode/extensions/`). The client then discovers `plugin.json` at the root.
- **Claude Code**: keeps legacy `.claude-plugin/plugin.json` + `skills/` symlinking to `~/.claude/plugins/`.

`PLUGIN_DATA` is created by the client before launching stdio MCP servers (writable, persisted across updates). Use it for caches, `node_modules`, venvs.

## Why keep Claude Code legacy?

Claude Code does not implement Agent Plugins 1.0 yet. Until it does, we **dual emit**: every `plugins/<id>/` contains both `plugin.json` (portable) and `.claude-plugin/plugin.json` (Claude). The root `plugin.json` is report-and-ignore for unknown fields (`skills`, `agents` kept for backward compat), so Claude's installer continues to work. The compiler will drop the legacy dir only when Claude announces support.

## References

- Spec: <https://github.com/agentplugins/agent-plugins-spec/blob/main/spec/1.0.0.md>
- Schemas: `schemas/agent-plugins/1.0.0/*.schema.json`
- Announcement: <https://vercel.com/blog/introducing-agent-plugins> (Vercel, 2026-08-06, authors Jonathan Hefner, contrib. Eric Dodds, Andrew Qu)
- TSC: AWS, Cursor, Microsoft, OpenAI, Vercel
