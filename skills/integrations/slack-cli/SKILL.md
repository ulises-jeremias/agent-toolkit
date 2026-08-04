---
name: slack-cli
description: Interact with the official Slack CLI to create, run, deploy, and manage Slack apps, environments, manifests, and triggers. Use when the user asks about Slack app development workflows, not workspace chat automation.
metadata:
  author: agent-toolkit
  version: "1.0"
compatibility: Requires official Slack CLI from docs.slack.dev (not rockymadden/slack-cli), plus curl and jq. See references/INSTALLATION.md.
---

# Slack CLI (Official Slack Developer CLI)

Use the official Slack Developer CLI documented at `docs.slack.dev/tools/slack-cli/`.

This CLI is for Slack **app development and platform management**.
It is **not** the community chat automation CLI (`slack chat send`, etc.).

## When to Use

- Create or initialize a Slack app project
- Log in/out and manage authorized teams for app development
- Run and deploy Slack apps
- Manage manifests, env vars, functions, and triggers
- Run diagnostics with `slack doctor`

## Setup

If `slack` is not found, or `slack --help` does not mention app development, see [references/INSTALLATION.md](references/INSTALLATION.md).

Some machines already have another `slack` binary (e.g., Slack desktop). In that case, the official CLI can be installed as `slack-dev`.

Use this detection pattern first:

```bash
if slack --help 2>/dev/null | grep -q "create, run, and deploy Slack apps"; then
  SLACK_CMD=slack
elif slack-dev --help 2>/dev/null | grep -q "create, run, and deploy Slack apps"; then
  SLACK_CMD=slack-dev
else
  echo "Official Slack CLI not found"
fi
```

Authorize after install:

```bash
"$SLACK_CMD" login
"$SLACK_CMD" list
```

## Core Commands

```bash
"$SLACK_CMD" version
"$SLACK_CMD" doctor
"$SLACK_CMD" login
"$SLACK_CMD" logout
"$SLACK_CMD" list
```

## Project Lifecycle

```bash
# Create a new project
"$SLACK_CMD" create

# Initialize an existing project directory
"$SLACK_CMD" init

# Run app locally
"$SLACK_CMD" run

# Deploy app
"$SLACK_CMD" deploy
```

## App and Platform Management

```bash
"$SLACK_CMD" manifest info
"$SLACK_CMD" manifest validate
"$SLACK_CMD" env list
"$SLACK_CMD" env add
"$SLACK_CMD" trigger list
"$SLACK_CMD" trigger create
"$SLACK_CMD" trigger access list
"$SLACK_CMD" activity
"$SLACK_CMD" app list
"$SLACK_CMD" app install
"$SLACK_CMD" app uninstall
```

## Recommended Workflow

1. `"$SLACK_CMD" login`
2. `"$SLACK_CMD" create` or `"$SLACK_CMD" init`
3. `"$SLACK_CMD" doctor`
4. `"$SLACK_CMD" run`
5. `"$SLACK_CMD" deploy`
6. `"$SLACK_CMD" trigger list` and validate trigger behavior

## Notes

- Prefer official docs and command reference for exact flags.
- Use `"$SLACK_CMD" <command> --help` before running destructive operations.
- Never use this skill for workspace chat automation (`chat.send`, `conversations.history`, reminders, etc. via community CLI patterns).
