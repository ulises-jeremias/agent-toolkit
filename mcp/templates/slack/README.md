# Slack MCP Template

Official server: [`@modelcontextprotocol/server-slack`](https://github.com/modelcontextprotocol/servers/tree/main/src/slack)

Provides tools to list channels, read history, post messages, reply in threads, and manage reactions.

## Required environment variables

- `SLACK_BOT_TOKEN` (starts with `xoxb-`) — Bot User OAuth Token
- `SLACK_TEAM_ID` (starts with `T`) — workspace ID

Optional:

- `SLACK_CHANNEL_IDS` — comma-separated channel IDs to limit which channels are listed (e.g. `C01234567,C76543210`)

### Getting tokens

1. Go to [Slack API Apps](https://api.slack.com/apps) and create a new app.
2. Under **OAuth & Permissions**, add bot token scopes:
   - `channels:history`, `channels:read`, `chat:write`, `reactions:write`, `users:read`
3. Install the app to your workspace and copy the **Bot User OAuth Token** (`SLACK_BOT_TOKEN`).
4. Find your workspace ID (`SLACK_TEAM_ID`) under **Settings → Workspace ID** in the Slack app admin UI, or from any channel URL (`/archives/C…` pages include the team context).

> **Note:** This official server uses the Bot Token API — **not** Socket Mode. You do **not** need `SLACK_APP_TOKEN`.

## Usage

1. Copy `config.template.json` into your MCP client config.
2. Export both required variables before starting the client:
   ```bash
   export SLACK_BOT_TOKEN=xoxb-...
   export SLACK_TEAM_ID=T...
   ```
3. Optionally set `SLACK_CHANNEL_IDS` to restrict channel visibility.
