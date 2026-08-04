# Figma MCP Template

Connects an AI tool to the remote Figma MCP server
(`https://mcp.figma.com/mcp`, streamable HTTP with bearer-token auth).

## Required environment variables

- `FIGMA_OAUTH_TOKEN` — personal access token or OAuth token with read +
  assets scopes.
- `FIGMA_REGION` — Figma region header (default `us-east-1`).

Store them in `~/.config/agent-toolkit/env.d/figma.env` (covered by `dots-loadenv`):

```bash
mkdir -p ~/.config/agent-toolkit/env.d
cat >> ~/.config/agent-toolkit/env.d/figma.env <<'EOF'
export FIGMA_OAUTH_TOKEN="<paste-token-here>"
export FIGMA_REGION="us-east-1"
EOF
chmod 600 ~/.config/agent-toolkit/env.d/figma.env
```

`dots-doctor` will pick up `figma.env` under "Integrations" without printing
the value.

> [!CAUTION]
> Tokens copied from the Figma UI must not include surrounding quotes. Never
> commit `figma.env` to a repository.

## How to use

The transport is **streamable HTTP** — there is no local `command`/`wrapper.sh`.
Each AI tool registers MCP servers in its own configuration file:

| AI tool | Configuration file |
|---------|--------------------|
| Claude Code | `~/.claude/mcp.json` (or `claude mcp add figma --transport http --url https://mcp.figma.com/mcp --header "Authorization: Bearer $FIGMA_OAUTH_TOKEN" --header "X-Figma-Region: $FIGMA_REGION"`) |
| Cursor | `~/.cursor/mcp.json` |
| OpenCode | `~/.config/opencode/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` |

Copy the values from `config.template.json` and substitute the env vars at
registration time. Restart your AI tool so it re-reads the MCP config.

## Verify

1. Run `dots-doctor` and confirm `figma.env` is listed under Integrations.
2. Restart your AI tool.
3. Ask the AI to call `whoami` on the Figma MCP — it should return your Figma
   user identity.

## See also

- `~/.local/share/agent-toolkit/skills/figma/SKILL.md` and the `figma-*` skill
  family.
- `docs/MCP_TEMPLATES.md`
