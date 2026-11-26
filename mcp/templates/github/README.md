# GitHub MCP Template

Official server: [`github/github-mcp-server`](https://github.com/github/github-mcp-server)
(`ghcr.io/github/github-mcp-server`). The npm package
`@modelcontextprotocol/server-github` is **deprecated** as of April 2025.

## Required environment variables

- `GITHUB_PERSONAL_ACCESS_TOKEN` — fine-grained or classic PAT

The template passes `GITHUB_READ_ONLY=1` to the server. This disables write
tools by default. Read-only mode does not limit which repositories the token
can read, so prefer a fine-grained PAT scoped to only the repositories and
read permissions you need.

## Opting into writes locally

The core plugin workflows use the GitHub CLI for changes; they do not require
write access through MCP. If you separately need GitHub MCP write tools, make
that choice in your user-owned MCP client configuration: set
`GITHUB_READ_ONLY` to `0` and pass that variable through to the Docker
container. Use a fine-grained PAT with only the specific write permissions
needed. Do not change the shared template or check a token into the repository.

## Usage

1. Ensure Docker is available.
2. Copy `config.template.json` into your MCP client config.
3. Export `GITHUB_PERSONAL_ACCESS_TOKEN`.
