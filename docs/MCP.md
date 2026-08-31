# MCP Templates

Model Context Protocol (MCP) is an open standard that lets AI tools connect to external services as structured data sources and action providers. With MCP, your AI coding assistant can read GitHub issues, post Slack messages, query Linear, and more — all through a secure, declarative interface.

agent-toolkit ships MCP configuration templates for the most commonly used services. These templates are stubs — they contain no secrets. All credential values are represented as `${ENV_VAR}` placeholders that you fill in at install time.

Templates live in `mcp/templates/<provider>/`. Each template directory contains:
- `config.template.json` — the MCP configuration stub (copy and fill in credentials)
- `README.md` — provider-specific setup notes
- `config.local.template.json` — optional PAT/stdio fallback (Notion only)

---

## Why Env Var Placeholders?

MCP configurations reference secrets (API tokens, OAuth credentials). Committing those to a repository — even a private one — creates a security risk. agent-toolkit templates use `${VARIABLE_NAME}` placeholders so:

1. The templates can be committed and shared safely
2. Secrets stay in your environment (`.env` files, shell profile, secret manager)
3. Rotating a token requires only updating the environment variable, not editing config files

Never substitute real credentials directly into the template files and commit them.

---

## Provider Table

| Provider | Type | Transport | Env vars | Description |
|----------|------|-----------|----------|-------------|
| GitHub | Command | stdio | `GITHUB_PERSONAL_ACCESS_TOKEN` | Repos, PRs, issues, releases, Actions |
| Slack | Command | stdio | `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID` | Channels, messages, reactions, threads |
| Notion | HTTP / Command | streamable_http or stdio | OAuth (remote) or `NOTION_TOKEN` (local) | Pages, databases, data sources |
| Linear | HTTP/SSE | streamable_http | None (OAuth via browser) | Issues, projects, cycles, comments |
| Figma | HTTP | streamable_http | `FIGMA_OAUTH_TOKEN`, `FIGMA_REGION` | Files, components, design tokens |
| ClickUp | Command | stdio | `CLICKUP_API_TOKEN` | Tasks, lists, spaces, docs, comments |
| Chrome DevTools | Command | stdio | None (opt `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS`, `CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS`) | Live Chrome: network, console, performance traces, rendering diagnostics |

---

## Per-Provider Setup

### GitHub

**Template:** `mcp/templates/github/config.template.json`

```json
{
  "name": "github",
  "command": "docker",
  "args": [
    "run",
    "-i",
    "--rm",
    "-e",
    "GITHUB_PERSONAL_ACCESS_TOKEN",
    "ghcr.io/github/github-mcp-server"
  ],
  "env": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN}"
  }
}
```

**Setup:**

1. Create a GitHub personal access token (classic or fine-grained) at https://github.com/settings/tokens
   - Required scopes: `repo`, `read:org`, `workflow` (add `delete_repo` only if needed)
2. Ensure Docker is available locally.
3. Export the token:
   ```bash
   export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here
   ```
4. Copy the template to your tool's MCP config location (see [Adding MCP to Your Tool](#adding-mcp-to-your-tool) below)

**What it enables:** List and create issues, review PRs, check Actions run status, read repository contents, manage releases.

---

### Slack

**Template:** `mcp/templates/slack/config.template.json`

```json
{
  "name": "slack",
  "command": "npx",
  "args": ["-y", "@modelcontextprotocol/server-slack"],
  "env": {
    "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}",
    "SLACK_TEAM_ID": "${SLACK_TEAM_ID}"
  }
}
```

**Setup:**

1. Create a Slack app at https://api.slack.com/apps
2. Under **OAuth & Permissions**, add bot token scopes:
   - `channels:history`, `channels:read`, `chat:write`, `reactions:write`, `users:read`
3. Install the app to your workspace and copy the **Bot User OAuth Token** (`SLACK_BOT_TOKEN`)
4. Copy your workspace ID into `SLACK_TEAM_ID` (starts with `T`)
5. Export both values:
   ```bash
   export SLACK_BOT_TOKEN=xoxb-your-bot-token
   export SLACK_TEAM_ID=T01234567
   ```
6. Copy the template into your MCP client config

**What it enables:** List channels, read history, post messages, reply in threads, add reactions.

---

### Notion

**Template (recommended):** `mcp/templates/notion/config.template.json` — remote OAuth

```json
{
  "name": "notion",
  "transport": "streamable_http",
  "url": "https://mcp.notion.com/mcp",
  "auth": "oauth"
}
```

**Local PAT fallback:** `mcp/templates/notion/config.local.template.json`

```json
{
  "name": "notion",
  "command": "npx",
  "args": ["-y", "@notionhq/notion-mcp-server"],
  "env": {
    "NOTION_TOKEN": "${NOTION_TOKEN}"
  }
}
```

**Setup (remote OAuth — recommended):**

1. Copy `config.template.json` to your MCP client
2. Complete the browser OAuth flow on first connect
3. See [Notion MCP documentation](https://developers.notion.com/docs/mcp)

**Setup (local stdio fallback):**

1. Create a Notion integration at https://www.notion.so/profile/integrations
2. Share each page/database with the integration
3. Export `NOTION_TOKEN` and copy `config.local.template.json`

**What it enables:** Search, read, and write Notion pages, databases, and data sources.

---

### Linear

**Template:** `mcp/templates/linear/config.template.json`

```json
{
  "name": "linear",
  "transport": "streamable_http",
  "url": "https://mcp.linear.app/mcp",
  "auth": "oauth"
}
```

Linear's MCP uses OAuth — there are no API keys to manage. The MCP client handles the browser-based OAuth flow automatically on first connection.

**Setup:**

1. No token setup required — Linear MCP uses OAuth
2. Copy the template to your tool's MCP config (see below)
3. On first use, your AI tool will open a browser to authorize the Linear connection
4. Accept the permissions and the connection is established

**Windows/WSL fallback:** If the streamable HTTP transport is not available in your environment, use the SSE fallback:
```json
{
  "name": "linear",
  "command": "wsl",
  "args": ["npx", "-y", "mcp-remote", "https://mcp.linear.app/sse", "--transport", "sse-only"]
}
```

**What it enables:** Create and update issues, manage projects and cycles, add comments, query sprints and assignments.

---

### Figma

**Template:** `mcp/templates/figma/config.template.json`

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

**Setup:**

1. Generate a Figma personal access token at https://www.figma.com/settings → Security → Personal access tokens
   - Scope: `File content (read-only)` is sufficient for design-to-code workflows
2. Find your region (typically `us` or `eu` — check your Figma account settings)
3. Export the values:
   ```bash
   export FIGMA_OAUTH_TOKEN=figd_your_token_here
   export FIGMA_REGION=us
   ```
4. Copy the template to your tool's MCP config

**What it enables:** Fetch design context, read file structure, extract component metadata, get screenshots for design-to-code workflows. Required for the `figma`, `figma-implement-design`, and `figma-code-connect-components` skills.

---

### ClickUp

**Template:** `mcp/templates/clickup/config.template.json`

```json
{
  "name": "clickup",
  "command": "mcp-clickup-server",
  "env": {
    "CLICKUP_API_TOKEN": "${CLICKUP_API_TOKEN}"
  }
}
```

**Setup:**

1. Get your ClickUp API token at https://app.clickup.com/settings/apps
2. Export the token:
   ```bash
   export CLICKUP_API_TOKEN=pk_your_token_here
   ```
3. Install the MCP server and copy the template

**What it enables:** View and create tasks, manage lists and spaces, add comments, read and write Docs.

---

## Adding MCP to Your AI Tool

### Claude Code

Add your filled-in MCP config to `~/.claude/claude_desktop_config.json` (or the project-level `.claude/mcp.json`):

```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN", "ghcr.io/github/github-mcp-server"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_your_token"
      }
    },
    "slack": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-slack"],
      "env": {
        "SLACK_BOT_TOKEN": "xoxb-...",
        "SLACK_TEAM_ID": "T01234567"
      }
    }
  }
}
```

Claude Code reads MCP servers from this file and makes their tools available in every session.

### Cursor

Go to **Cursor Settings → MCP** and add server entries. Cursor supports both command-based (stdio) and HTTP-based (streamable_http) transports.

For command-based servers, fill in the command and environment variables directly in the Cursor MCP settings UI. For HTTP-based servers (Linear, Figma), paste the URL and headers.

### OpenCode

Add MCP server entries to `~/.config/opencode/opencode.json`:

```json
{
  "mcp": {
    "github": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "-e", "GITHUB_PERSONAL_ACCESS_TOKEN", "ghcr.io/github/github-mcp-server"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_your_token"
      }
    }
  }
}
```

### Windsurf

Add MCP entries to Windsurf's MCP configuration file (typically `~/.codeium/windsurf/mcp_config.json` — check your Windsurf version's documentation for the exact path).

---

## Security Notes

- Store tokens in a password manager or secrets manager, not in `.bashrc` or `.zshrc` (which may be committed)
- Use `.env` files with `direnv` or a similar tool for per-project secrets
- Prefer fine-grained tokens with the minimum required scopes
- Rotate tokens periodically — MCP servers use whatever scope the token has, so a compromised token with broad scopes is a significant risk
- Never commit filled-in MCP config files containing real tokens to any repository

The `validate-skills.vsh` script scans for common secret patterns. It will warn if it detects what looks like a real token in any tracked file.

### Chrome DevTools

**Template:** `mcp/templates/chrome-devtools/config.template.json`
**Registry:** `mcp/registry/chrome-devtools.yaml` (ChromeDevTools/chrome-devtools-mcp, Apache-2.0)

```json
{
  "name": "chrome-devtools",
  "command": "npx",
  "args": ["-y", "chrome-devtools-mcp@latest"]
}
```

**Setup:** See `skills/tooling/chrome-devtools/SKILL.md` for Playwright vs DevTools decision table and `mcp/templates/chrome-devtools/README.md` for host-specific wiring. `mcp/registry/chrome-devtools.yaml` documents provenance (official Google ChromeDevTools, npm `chrome-devtools-mcp`, Apache-2.0). Chrome DevTools MCP exposes all browser content — avoid sensitive pages. Usage stats enabled by default — opt out with `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1` or `--no-usage-statistics`. Update checks ping npm — disable with `CHROME_DEVTOOLS_MCP_NO_UPDATE_CHECKS=1`.

**When to use:** `design-assessment` / `design-improvement` request `browser.performance / browser.network / browser.console / browser.runtime-debug` → Chrome DevTools; `browser.interact / browser.assert` → Playwright. Either alone is valid degraded mode.

