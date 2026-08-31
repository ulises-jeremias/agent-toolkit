# Chrome DevTools MCP — Template

Official: [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) — Apache-2.0 — `npm:chrome-devtools-mcp`.

## Quick start

**Claude Code (plugin + skills, recommended):**
```bash
/plugin marketplace add ChromeDevTools/chrome-devtools-mcp
/plugin install chrome-devtools-mcp@chrome-devtools-plugin
```
Restart Claude Code, check `/mcp` or `/skills`.

**Claude Code (MCP-only):**
```bash
claude mcp add chrome-devtools -- npx -y chrome-devtools-mcp@latest
```

**Generic (Cline/Gemini/Codex):**
```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest"]
    }
  }
}
```

### Slim mode (smaller context)
```json
{
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["-y", "chrome-devtools-mcp@latest", "--slim", "--headless"]
    }
  }
}
```

## Flags

- `--slim` — reduced tool set
- `--headless` — headless Chrome
- `--isolated` — per-session instance
- `--browser-url=http://127.0.0.1:9222` — attach to existing Chrome
- `--no-performance-crux` — disable CrUX fetch
- `--no-usage-statistics` — opt out Google stats (or `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1`, `CI=1` auto)
- `--no-update-checks` — disable npm update ping (`CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS=1`)

See `skills/tooling/chrome-devtools/SKILL.md` for Playwright vs DevTools decision table and `mcp/registry/chrome-devtools.yaml` for provenance.

## Security

DevTools exposes all browser content to the MCP client — avoid sensitive pages. Usage stats enabled by default — opt out as above. See skill for full boundaries.
