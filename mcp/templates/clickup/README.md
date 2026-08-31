# ClickUp MCP Template

> **Deprecated** — The ClickUp MCP server is no longer the recommended integration.
> Use the [`clickup` CLI](https://triptechtravel.github.io/clickup-cli/) instead.
> The workstation installs the global skill at `~/.local/share/agent-toolkit/skills/clickup-cli/SKILL.md`.

## Why the CLI is preferred

| | ClickUp MCP | `clickup` CLI |
|---|---|---|
| Token cost | High — MCP responses are verbose JSON blobs | Low — structured `--json`/`--jq` output, ~90% less noise with `rtk` |
| Auth | Requires server process + API token in config | Token stored in system keyring; CI via `--with-token` |
| Git integration | None | Auto-detects task IDs from branch names |
| Maintenance | External server process to keep running | Single binary, no daemon |

## Migration

Remove the ClickUp MCP server from your agent config and install the CLI instead:

```bash
# Install (macOS/Linux with Homebrew)
brew install triptechtravel/tap/clickup

# Install (go)
go install github.com/triptechtravel/clickup-cli/cmd/clickup@latest

# Authenticate
clickup auth login

# Select default space
clickup space select
```

The `clickup-cli` skill is deployed by chezmoi at `~/.local/share/agent-toolkit/skills/clickup-cli/` and linked globally for Claude Code, Cursor, Copilot, OpenCode, and pi.

## Legacy reference

The MCP config template below is kept for reference only. Do not use it for new setups.

### Required environment variables (legacy)

- `CLICKUP_API_TOKEN`
