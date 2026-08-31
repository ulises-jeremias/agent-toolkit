# Notion MCP Template

Official server: [`makenotion/notion-mcp-server`](https://github.com/makenotion/notion-mcp-server)

Provides tools to search, read, and write Notion pages, databases, and data sources.

## Recommended setup (remote OAuth)

`config.template.json` uses Notion's hosted MCP at `https://mcp.notion.com/mcp` — no API token in config files. Your MCP client handles the browser OAuth flow on first connect.

1. Copy `config.template.json` into your MCP client config.
2. Connect once and complete OAuth in the browser.
3. See [Notion MCP documentation](https://developers.notion.com/docs/mcp) for client-specific steps.

## Offline / PAT fallback (local stdio)

When remote OAuth is unavailable, use `config.local.template.json` with the official npm package `@notionhq/notion-mcp-server`.

### Required environment variables

- `NOTION_TOKEN` — internal integration token (starts with `ntn_` or `secret_` depending on integration type)

### Getting a token

1. Go to [Notion integrations](https://www.notion.so/profile/integrations) and create an internal integration.
2. Copy the integration secret into `NOTION_TOKEN`.
3. **Important:** share each page or database with the integration via Notion's **Share → Connect to** menu before the server can access it.

### Usage

1. Copy `config.local.template.json` into your MCP client config.
2. Export `NOTION_TOKEN` or set it in the client config env block.
