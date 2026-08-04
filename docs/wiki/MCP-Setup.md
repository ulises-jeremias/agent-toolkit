# MCP Setup

Model Context Protocol (MCP) is an open standard that lets AI tools connect to external services
as structured data sources and action providers. With MCP, your AI coding assistant can read GitHub
issues, post Slack messages, query Linear, and more — all through a secure, declarative interface.

agent-toolkit ships MCP configuration templates for the most commonly used services.

---

## What Is MCP and Why Does It Matter?

Without MCP, an AI assistant can only see what you paste into the chat. With MCP, the AI can
directly query live data — reading the current state of your GitHub issues, posting to Slack,
or pulling design context from Figma — without you having to copy and paste.

MCP connections are declared in a configuration file. The AI tool reads the config, launches MCP
server processes in the background, and makes their capabilities available as tools during the
session. From the AI's perspective, MCP tools work just like reading a file or running a shell
command.

**What agent-toolkit adds:** Ready-to-use configuration stubs for 6 popular MCP providers.
These templates contain `${ENV_VAR}` placeholders instead of real credentials, so you can commit
and share the templates safely.

---

## Template Structure

Templates live in `mcp/templates/<provider>/`. Each template directory contains:

- `config.template.json` — the MCP configuration stub (copy and fill in credentials)
- `README.md` — provider-specific setup notes

Templates never contain real credentials. All sensitive values use `${VARIABLE_NAME}` placeholders.

---

## Security: Protecting Your Credentials

Before setting up any MCP provider, internalize these rules:

- **Never substitute real tokens into template files and commit them.** Use the copied file as
  a local config, not a version-controlled file.
- **Store tokens in a password manager or secrets manager**, not in `.bashrc` or `.zshrc`
  (which may be committed or synced to cloud).
- **Use `direnv` or a `.env` file** with your shell profile for per-project secrets.
- **Prefer fine-grained tokens** with the minimum required scopes.
- **Rotate tokens periodically.** MCP servers use whatever scope the token has — a compromised
  broad-scope token is a significant risk.
- The `validate-skills.sh` script scans for common secret patterns and will warn if it detects
  what looks like a real token in any tracked file.

**The safe config location:** `~/.config/agent-toolkit/mcp-config.json`

This file is outside any repository and never accidentally committed. Reference it from your AI
tool's MCP configuration.

---

## Provider 1: GitHub

**Env vars:** `GITHUB_TOKEN`

**What it enables:** List and create issues, review PRs, check Actions run status, read repository
contents, manage releases.

**Connectivity test:**

```bash
curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user
```

Should return your GitHub user object.

### Setup

1. Create a GitHub personal access token at <https://github.com/settings/tokens>
   - Classic token scopes: `repo`, `read:org`, `workflow`
   - Fine-grained token: repository access + read/write Issues, Pull Requests, Actions
   - Add `delete_repo` only if needed by specific workflows
2. Export the token in your shell profile or `.env` file:
   ```bash
   export GITHUB_TOKEN=ghp_your_token_here
   ```
3. Install the MCP server:
   ```bash
   npm install -g @anthropic-ai/mcp-server-github
   ```
4. Copy the template to your config location:
   ```bash
   cp ~/.agent-toolkit/mcp/templates/github/config.template.json \
      ~/.config/agent-toolkit/mcp-github.json
   ```

**Config template:**

```json
{
  "name": "github",
  "command": "mcp-github-server",
  "env": {
    "GITHUB_TOKEN": "${GITHUB_TOKEN}"
  }
}
```

### Per-tool configuration

**Claude Code** — add to `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "github": {
      "command": "mcp-github-server",
      "env": {
        "GITHUB_TOKEN": "ghp_your_token"
      }
    }
  }
}
```

Or use the project-level `.claude/mcp.json` for project-scoped MCP servers.

**Cursor** — go to Cursor Settings → MCP → Add Server. Enter the command and environment
variables in the UI.

**OpenCode** — add to `~/.config/opencode/opencode.json`:

```json
{
  "mcp": {
    "github": {
      "command": "mcp-github-server",
      "env": {
        "GITHUB_TOKEN": "ghp_your_token"
      }
    }
  }
}
```

---

## Provider 2: Slack

**Env vars:** `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN`

**What it enables:** Read channel history, post messages, add reactions, browse Slack canvases.

**Connectivity test:**

```bash
curl -H "Authorization: Bearer $SLACK_BOT_TOKEN" https://slack.com/api/auth.test
```

Should return `"ok": true`.

### Setup

1. Create a Slack app at <https://api.slack.com/apps>
2. Under **OAuth & Permissions**, add bot token scopes:
   - `channels:history`, `channels:read`, `chat:write`, `reactions:write`, `users:read`
3. Under **Socket Mode**, enable Socket Mode and create an App-Level Token with `connections:write`
   scope
4. Install the app to your workspace
5. Export the tokens:
   ```bash
   export SLACK_BOT_TOKEN=xoxb-your-bot-token
   export SLACK_APP_TOKEN=xapp-your-app-token
   ```
6. Install the MCP server:
   ```bash
   npm install -g @anthropic-ai/mcp-server-slack
   ```

**Config template:**

```json
{
  "name": "slack",
  "command": "mcp-slack-server",
  "env": {
    "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}",
    "SLACK_APP_TOKEN": "${SLACK_APP_TOKEN}"
  }
}
```

### Per-tool configuration

Add to your tool's MCP config using the same pattern as GitHub. Both tokens must be present —
the Slack MCP server requires both bot token (for API calls) and app token (for Socket Mode).

**Troubleshooting:** If the bot does not see messages in a channel, make sure the bot is invited
to that channel (`/invite @your-bot-name`).

---

## Provider 3: Notion

**Env vars:** `NOTION_API_TOKEN`

**What it enables:** Read and write Notion pages and databases, query blocks, create content.

**Connectivity test:**

```bash
curl -H "Authorization: Bearer $NOTION_API_TOKEN" \
     -H "Notion-Version: 2022-06-28" \
     https://api.notion.com/v1/users/me
```

### Setup

1. Create a Notion integration at <https://www.notion.so/my-integrations>
   - Select the workspace you want to connect
   - Grant read/write content access
2. Copy the Internal Integration Token
3. In Notion, share each database or page with your integration (Share menu → Connect to
   integration)
4. Export the token:
   ```bash
   export NOTION_API_TOKEN=secret_your_token_here
   ```

**Config template:**

```json
{
  "name": "notion",
  "command": "mcp-notion-server",
  "env": {
    "NOTION_API_TOKEN": "${NOTION_API_TOKEN}"
  }
}
```

**Important:** The Notion MCP server can only access pages and databases that have been explicitly
shared with the integration. If you cannot see a page, check that it is shared in Notion's UI.

---

## Provider 4: Linear

**Env vars:** None (uses OAuth via browser)

**What it enables:** Create and update issues, manage projects and cycles, add comments, query
sprints and assignments.

**Connectivity test:** Trigger a connection in your AI tool. It will open a browser for OAuth.
After authorizing, run a Linear query to confirm.

### Setup

Linear's MCP uses OAuth — there are no API keys to manage. The MCP client handles the
browser-based OAuth flow automatically on first connection.

1. No token setup required
2. Copy the template to your tool's MCP config (see below)
3. On first use, your AI tool will open a browser to authorize the Linear connection
4. Accept the permissions and the connection is established

**Config template (streamable HTTP transport):**

```json
{
  "name": "linear",
  "transport": "streamable_http",
  "url": "https://mcp.linear.app/mcp",
  "auth": "oauth"
}
```

**Windows/WSL fallback** — if streamable HTTP is not available in your environment:

```json
{
  "name": "linear",
  "command": "wsl",
  "args": ["npx", "-y", "mcp-remote", "https://mcp.linear.app/sse", "--transport", "sse-only"]
}
```

### Per-tool configuration

**Claude Code** — add to `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "linear": {
      "transport": "streamable_http",
      "url": "https://mcp.linear.app/mcp",
      "auth": "oauth"
    }
  }
}
```

**Cursor** — go to Settings → MCP. Add an HTTP-based server entry with the URL
`https://mcp.linear.app/mcp`.

---

## Provider 5: Figma

**Env vars:** `FIGMA_OAUTH_TOKEN`, `FIGMA_REGION`

**What it enables:** Fetch design context, read file structure, extract component metadata, get
screenshots for design-to-code workflows. Required for the `figma`, `figma-implement-design`, and
`figma-code-connect-components` skills.

**Connectivity test:**

```bash
curl -H "Authorization: Bearer $FIGMA_OAUTH_TOKEN" https://api.figma.com/v1/me
```

### Setup

1. Generate a Figma personal access token at <https://www.figma.com/settings> → Security →
   Personal access tokens
   - Scope: `File content (read-only)` is sufficient for design-to-code workflows
2. Find your region (typically `us` or `eu` — check your Figma account settings)
3. Export the values:
   ```bash
   export FIGMA_OAUTH_TOKEN=figd_your_token_here
   export FIGMA_REGION=us
   ```

**Config template (HTTP transport):**

```json
{
  "name": "figma",
  "transport": "streamable_http",
  "url": "https://mcp.figma.com/mcp",
  "headers": {
    "Authorization": "Bearer ${FIGMA_OAUTH_TOKEN}",
    "X-Figma-Region": "${FIGMA_REGION}"
  }
}
```

### Per-tool configuration

**Claude Code** — add to `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "figma": {
      "transport": "streamable_http",
      "url": "https://mcp.figma.com/mcp",
      "headers": {
        "Authorization": "Bearer figd_your_token",
        "X-Figma-Region": "us"
      }
    }
  }
}
```

**Cursor** — add as an HTTP server in Settings → MCP. Paste the URL and set the Authorization
and X-Figma-Region headers.

---

## Provider 6: ClickUp

**Env vars:** `CLICKUP_API_TOKEN`

**What it enables:** View and create tasks, manage lists and spaces, add comments, read and write
Docs.

**Connectivity test:**

```bash
curl -H "Authorization: $CLICKUP_API_TOKEN" https://api.clickup.com/api/v2/user
```

### Setup

1. Get your ClickUp API token at <https://app.clickup.com/settings/apps>
2. Export the token:
   ```bash
   export CLICKUP_API_TOKEN=pk_your_token_here
   ```
3. Install the MCP server:
   ```bash
   npm install -g mcp-clickup-server
   ```

**Config template:**

```json
{
  "name": "clickup",
  "command": "mcp-clickup-server",
  "env": {
    "CLICKUP_API_TOKEN": "${CLICKUP_API_TOKEN}"
  }
}
```

---

## Adding Multiple MCP Servers to Claude Code

All servers go in the `mcpServers` object in `~/.claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "github": {
      "command": "mcp-github-server",
      "env": { "GITHUB_TOKEN": "ghp_your_token" }
    },
    "slack": {
      "command": "mcp-slack-server",
      "env": {
        "SLACK_BOT_TOKEN": "xoxb-...",
        "SLACK_APP_TOKEN": "xapp-..."
      }
    },
    "linear": {
      "transport": "streamable_http",
      "url": "https://mcp.linear.app/mcp",
      "auth": "oauth"
    }
  }
}
```

Claude Code reads this file at startup and makes all MCP server tools available in every session.

---

## Troubleshooting MCP Errors

**MCP server not found:**

```bash
which mcp-github-server
```

If not found, install it: `npm install -g @anthropic-ai/mcp-server-github`

**Environment variable not set:**

```bash
echo $GITHUB_TOKEN
```

If empty, the server will start but fail on all API calls. Add the export to your shell profile
and restart your AI tool.

**HTTP transport: network error:**

For Linear and Figma (HTTP-based MCP), verify:

1. Your network can reach the endpoint:
   ```bash
   curl -I https://mcp.linear.app/mcp
   ```
2. Your corporate firewall is not blocking the MCP endpoint
3. Your VPN is not interfering

**Claude Code: MCP server crashes on startup:**

Check Claude Code's logs. The server output is usually in `~/.claude/logs/`. Look for startup
errors from the MCP server process.

**Cursor: MCP server not appearing:**

Go to Cursor Settings → MCP and verify the server entry is saved. Restart Cursor after adding
new MCP servers.

**OpenCode: MCP server not connecting:**

Verify the entry in `~/.config/opencode/opencode.json` is valid JSON. OpenCode will silently
ignore malformed JSON entries.
