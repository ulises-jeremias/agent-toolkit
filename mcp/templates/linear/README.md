# Linear MCP Template

Connects an AI tool to Linear via the official remote MCP server
(`https://mcp.linear.app/mcp`, OAuth — no API token needed).

## Required environment variables

- None. Authentication is OAuth, prompted by your AI tool on first call.

## How to use

The transport is **streamable HTTP**, not a local `command`/`wrapper.sh`. Each
AI tool registers MCP servers slightly differently — pick the relevant
configuration file and copy the URL from `config.template.json`:

| AI tool | Configuration file |
|---------|--------------------|
| Claude Code | `~/.claude/mcp.json` (or `claude mcp add linear --transport http --url https://mcp.linear.app/mcp`) |
| Cursor | `~/.cursor/mcp.json` |
| OpenCode | `~/.config/opencode/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` |

The first Linear tool call triggers an OAuth window in your browser. After login
the session is cached by the AI tool.

## Windows / WSL fallback

If direct streamable-HTTP connections are blocked on Windows, run the MCP
through WSL using `mcp-remote`:

```jsonc
{
  "mcpServers": {
    "linear": {
      "command": "wsl",
      "args": ["npx", "-y", "mcp-remote", "https://mcp.linear.app/sse", "--transport", "sse-only"]
    }
  }
}
```

That snippet is also embedded in `config.template.json` under the
`_comment_windows_wsl_fallback` key for reference.

## See also

- `~/.local/share/agent-toolkit/skills/linear/SKILL.md` — the linear skill that
  drives this MCP.
- `docs/MCP_TEMPLATES.md`
