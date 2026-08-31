# V `mcp` command family

**Issue:** [#518](https://github.com/ulises-jeremias/agent-toolkit/issues/518) (EPIC 4b [#551](https://github.com/ulises-jeremias/agent-toolkit/issues/551))

MCP provider management matching Python `cli/mcp.py`:

- `list` — templates under `mcp/templates/`
- `setup <provider> [--offline]` — non-interactive; records **env var names only** in `~/.config/agent-toolkit/mcp-config.json`
- `health [provider]` — registry YAML + env names, no network
- `doctor [provider]` — env presence; `--offline` aliases health
- `uninstall <provider>` — drop local config entry

**Credentials:** never stored, never printed. Tokens stay in the process environment.
