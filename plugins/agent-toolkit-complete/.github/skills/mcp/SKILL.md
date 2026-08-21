---
name: mcp
description: Configure and manage MCP providers for Agent Toolkit — setup, list, doctor, and per-tool
  deployment.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - mcp
  - integrations
  - github
  - slack
  - context
---
# MCP

Wire **Model Context Protocol** servers so agents can call external tools (GitHub, ClickUp, Slack, etc.) natively. This skill wraps `agent-toolkit mcp` and the MCP definitions in `mcp/` and `~/.local/share/agent-toolkit/mcp/`.

## When to use

- User asks "setup MCP", "connect GitHub/ClickUp/Slack", or an agent fails with MCP not configured.
- After `agent-toolkit install` — MCP needs auth beyond file copy.
- `agent-toolkit doctor` reports MCP integration missing.

## Prerequisites

- `agent-toolkit` installed; `mcp/` definitions exist in the repo or `~/.local/share/agent-toolkit/mcp/`.
- Auth for each provider: `gh auth login` (GitHub), `clickup auth login` (ClickUp), etc. Keys in `~/.config/agent-toolkit/` or env.
- Target tool supports MCP (Claude Code, Cursor, OpenCode — see `docs/MCP.md`).

## Workflow

### 1. Discover available providers

```bash
agent-toolkit mcp list
agent-toolkit mcp doctor
cat docs/MCP.md
ls mcp/
ls ~/.local/share/agent-toolkit/mcp/ 2>&1 | head
```

### 2. Setup a provider

```bash
agent-toolkit mcp setup --provider github
agent-toolkit mcp setup --provider clickup
# Or target a specific tool:
agent-toolkit plugin sync --tools claude-code  # also syncs MCP for that tool
```

For manual config, copy from `distributions/` or `mcp/` templates to `~/.config/<tool>/mcp.json` per `docs/MCP.md` — prefer the CLI.

### 3. Verify and use

```bash
agent-toolkit mcp doctor
agent-toolkit doctor  # check Integrations section
# In agent: try a tool call that needs MCP, e.g., gh pr view or clickup task list
```

If `doctor` flags missing auth, run `gh auth status` / `clickup auth status` and re-setup.

### 4. Deploy with profiles

`agent-toolkit install` copies MCP templates; `mcp setup` authenticates them. For per-project MCP (e.g., Copilot):

```bash
agent-toolkit install --tools copilot --dry-run  # shows would-copy for Copilot MCP
```

## Boundaries

- Never commit secrets — MCP auth lives in `~/.config/agent-toolkit/` or `~/.config/<provider>/`, not the repo. Use `.env.example` for templates.
- Do not hand-edit tool MCP JSON when `mcp setup` can do it — it handles path and env correctly.
- For swarms: MCP is per-runner, not per-run. Ensure the host's MCP is configured before `swarm start`.

## Delegates to

| Need | Skill |
|------|-------|
| Repo discovery before MCP wiring | `assistant` |
| Swarm that needs MCP tools | `swarm` |
| GitHub PR after swarm | `github-cli-workflow` |
| ClickUp/Slack tasks | `clickup-cli`, `slack-cli`, `linear` |
