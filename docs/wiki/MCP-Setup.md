# MCP Setup

Canonical: [`docs/MCP.md`](../MCP.md). Templates: [`mcp/templates/`](../../mcp/templates/) (7 providers: github, slack, notion, linear, figma, clickup, chrome-devtools).

CLI: `agent-toolkit mcp list` / `agent-toolkit mcp setup <provider>` / `agent-toolkit mcp doctor`.

Templates use `${ENV_VAR}` placeholders only — never commit real credentials.
