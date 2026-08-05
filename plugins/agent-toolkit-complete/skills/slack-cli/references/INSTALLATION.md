# Official Slack CLI Installation

Reference: <https://docs.slack.dev/tools/slack-cli/guides/installing-the-slack-cli-for-mac-and-linux>

## Install (macOS/Linux)

```bash
curl -fsSL https://downloads.slack-edge.com/slack-cli/install.sh | bash
```

## If another `slack` binary already exists

Install with an alias:

```bash
curl -fsSL https://downloads.slack-edge.com/slack-cli/install.sh | bash -s -- slack-dev
```

Then use `slack-dev` in commands.

## Verify

```bash
slack version
slack --help
```

`slack --help` should describe the CLI as:

`CLI to create, run, and deploy Slack apps`

## Authorize

```bash
slack login
slack list
```

## Important

This official CLI is for Slack app development and platform operations.
It is different from community chat-focused CLIs (e.g., `slack chat send` style commands).
