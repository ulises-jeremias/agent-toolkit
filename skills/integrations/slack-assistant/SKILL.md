---
name: slack-assistant
description: Interact with Slack workspaces for reading channels/messages, sending messages, adding reactions, and browsing canvases. Use when the user asks about Slack channels, messages, or notifications — NOT for Slack app development (use the slack-cli skill for that).
metadata:
  author: ulises-jeremias
  version: "1.0"
compatibility: Requires slackcli (shaharia-lab) — install via run_onchange_45 script. Authenticate with `slackcli auth login` before first use.
---

# Slack Assistant (`slackcli`)

Use the `slackcli` CLI (from [shaharia-lab/slackcli](https://github.com/shaharia-lab/slackcli))
for Slack **workspace automation**: reading messages, sending messages, reactions, and canvases.

> **Important:** This is NOT the official Slack Developer CLI (`slack`/`slack-dev`).
> Use the `slack-cli` skill for Slack app development workflows.

## Default Workspaces

| Context | Workspace |
|---|---|
| | `` (.slack.com) |

Use `--workspace=<name-or-id>` to target a specific workspace.
Without `--workspace`, the default workspace set via `slackcli auth set-default` is used.

## When to Use

- User asks "what's in #channel-name" or "check the Slack channel"
- User wants to send a message or reply to a thread
- User asks about Slack canvases
- User wants to add a reaction to a message
- Workspace is .slack.com (or whichever workspace the user indicates)

## Authentication

```bash
# List authenticated workspaces
slackcli auth list

# Login with a bot/user token (run once per workspace)
slackcli auth login --token=<your-bot-token> --workspace-name="My Team"

# Login with browser session tokens (no Slack app needed)
slackcli auth parse-curl --login    # paste cURL from browser DevTools

# Set default workspace
slackcli auth set-default T1234567  # use workspace ID from auth list
```

Configuration is stored in `~/.config/slackcli/workspaces.json`.

## Conversation Commands

```bash
# List all channels in the default workspace
slackcli conversations list

# List channels in a specific workspace
slackcli conversations list --workspace=

# Filter by type
slackcli conversations list --types=public_channel
slackcli conversations list --types=im

# Read recent messages from a channel
slackcli conversations read C1234567890

# Read a specific thread
slackcli conversations read C1234567890 --thread-ts=1234567890.123456

# Read with limit and JSON output (includes ts/thread_ts for replies)
slackcli conversations read C1234567890 --limit=50 --json
```

## Message Commands

```bash
# Send a message to a channel
slackcli messages send --recipient-id=C1234567890 --message="Hello team!"

# Send a DM to a user
slackcli messages send --recipient-id=U9876543210 --message="Hey there!"

# Reply to a thread
slackcli messages send --recipient-id=C1234567890 \
  --thread-ts=1234567890.123456 --message="Great idea!"

# Add an emoji reaction to a message
slackcli messages react --channel-id=C1234567890 \
  --timestamp=1234567890.123456 --emoji=+1
```

Common emojis: `+1`, `heart`, `fire`, `eyes`, `tada`, `rocket`, `white_check_mark`

## Canvas Commands

```bash
# List canvases in the workspace
slackcli canvas list
slackcli canvas list --channel=C1234567890

# Read canvas content as markdown
slackcli canvas read F1234567890

# Read canvas in JSON format
slackcli canvas read F1234567890 --json
```

## Multi-Workspace Usage

```bash
# Use workspace explicitly
slackcli conversations list --workspace=

slackcli conversations list

# Use workspace by Slack team ID
slackcli conversations list --workspace=T1234567
```

## Workflow for Reading a Channel

1. Find the channel ID: `slackcli conversations list --workspace=| grep <name>`
2. Read recent messages: `slackcli conversations read <channel-id> --limit=20`
3. For threaded replies: use `--thread-ts=<ts>` from the message timestamp

## Notes

- Channel IDs start with `C`, user IDs start with `U`, team IDs start with `T`
- Timestamps in Slack are Unix epoch with microseconds (e.g., `1234567890.123456`)
- Use `--json` for programmatic processing; plain output is human-readable
- Browser session tokens expire with the browser session — prefer bot tokens for automation
- Run `slackcli update` to update to the latest release
