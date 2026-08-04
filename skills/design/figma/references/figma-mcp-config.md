# Figma MCP — setup and troubleshooting

The Figma MCP is a **streamable HTTP** endpoint with bearer-token auth pulled
from an environment variable. agent-toolkit ships a tool-agnostic template at
`~/.local/share/agent-toolkit/mcp/figma/` (deployed by `chezmoi apply`).

## 1) Get a Figma token

1. In Figma → Settings → **Personal access tokens** (or your org's OAuth flow).
2. Create a token with the scopes you need (read + assets at minimum).
3. Store it persistently in `~/.config/agent-toolkit/env.d/` (covered by `dots-loadenv`):

   ```bash
   mkdir -p ~/.config/agent-toolkit/env.d
   cat >> ~/.config/agent-toolkit/env.d/figma.env <<'EOF'
   export FIGMA_OAUTH_TOKEN="<paste-token-here>"
   export FIGMA_REGION="us-east-1"   # change if your org uses a different region
   EOF
   chmod 600 ~/.config/agent-toolkit/env.d/figma.env
   ```

   `dots-doctor` will pick up `figma.env` under "Integrations" without ever
   printing the token value.

> [!CAUTION]
> Tokens copied from Figma should not include surrounding quotes. Never commit
> `figma.env` to a repository.

## 2) Register the MCP in your AI tool

Each AI tool registers MCP servers in a different file. Use the values from
`~/.local/share/agent-toolkit/mcp/figma/config.template.json` as reference:

| AI tool | Configuration file |
|---------|--------------------|
| Claude Code | `~/.claude/mcp.json` (or `claude mcp add figma --transport http --url https://mcp.figma.com/mcp --header "Authorization: Bearer $FIGMA_OAUTH_TOKEN" --header "X-Figma-Region: $FIGMA_REGION"`) |
| Cursor | `~/.cursor/mcp.json` |
| OpenCode | `~/.config/opencode/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` |

Required headers:

- `Authorization: Bearer ${FIGMA_OAUTH_TOKEN}`
- `X-Figma-Region: ${FIGMA_REGION}` (default `us-east-1`; change if your org
  uses another region)

Make sure `FIGMA_OAUTH_TOKEN` is exported in the shell that launches your AI
tool. With `dots-loadenv` already wired in `dots-bootstrap`, sourcing your shell
profile is enough.

## 3) Verify

1. Run `dots-doctor` and confirm `~/.config/agent-toolkit/env.d/figma.env` is listed
   under Integrations.
2. Restart your AI tool so it re-reads its MCP config.
3. Ask the AI to list Figma tools or call `whoami` — it should return your
   Figma user identity.

## Troubleshooting

- **Token not picked up**: confirm `echo $FIGMA_OAUTH_TOKEN` returns a value in
  the shell that launches your AI tool. If it doesn't, re-source the profile
  (`exec $SHELL -l`) or restart the IDE.
- **OAuth errors**: verify the bearer token is valid and not expired. Tokens
  copied from the Figma UI should not have surrounding quotes.
- **Network/region**: if your org runs in a non-default Figma region, update
  `FIGMA_REGION` in `figma.env` and restart the AI tool.
- **Generic / vague output**: re-state the project-specific rules from the
  parent `SKILL.md` and ensure you follow the required flow
  (`get_design_context` → optional `get_metadata` → `get_screenshot`).

## Link-based prompting

The remote Figma MCP server is link-based: copy the Figma frame/layer link and
provide that URL to the AI tool. The AI tool will extract the node ID from the
link (it cannot browse the page itself).

## Optional: per-server timeouts

Most AI tools allow per-server `startup_timeout_sec` (default ~10) and
`tool_timeout_sec` (default ~60). Adjust them in your AI tool's config if you
hit timeouts on large nodes.
