# Claude Code Extension (non-portable)

This directory contains Claude Code-specific plugin components that are **not** part of the portable Agent Plugins 1.0 contract (agents, hooks, commands).

Portable components are at the plugin root:
- `plugin.json` — Agent Plugins manifest
- `skills/` — portable skills
- `mcp.json` — portable MCP servers

Client-specific components remain here and are ignored by other Agent Plugins clients per §8.

See https://code.claude.com/docs/en/plugins for Claude Code plugin details.
