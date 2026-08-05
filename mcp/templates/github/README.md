# GitHub MCP Template

Official server: [`github/github-mcp-server`](https://github.com/github/github-mcp-server)
(`ghcr.io/github/github-mcp-server`). The npm package
`@modelcontextprotocol/server-github` is **deprecated** as of April 2025.

## Required environment variables

- `GITHUB_PERSONAL_ACCESS_TOKEN` — fine-grained or classic PAT

## Usage

1. Ensure Docker is available.
2. Copy `config.template.json` into your MCP client config.
3. Export `GITHUB_PERSONAL_ACCESS_TOKEN`.
4. Optionally run `./wrapper.sh` as a local launcher example.
