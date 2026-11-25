# Get started with Agent Toolkit

Agent Toolkit is a portable library of skills, agent definitions, MCP
templates, context packs, and workflow recipes, distributed through a native
CLI. It works alongside the coding tools you already use.

For interactive coding, use [Veasel Code](https://github.com/veasel-labs/veasel).
Its TUI and Desktop are designed around one backend and session history;
packaged shared-session acceptance is tracked in [Veasel #550](https://github.com/veasel-labs/veasel/issues/550).
The official Veasel plugin catalog is maintained in
[`veasel-labs/agent-toolkit`](https://github.com/veasel-labs/agent-toolkit).

## Install the CLI

Follow the supported channels and platform-specific steps in
[Installation](INSTALLATION.md). Choose one install channel; each distributes
the same canonical V CLI.

Confirm the CLI and inspect available portable capabilities:

```sh
agent-toolkit doctor
agent-toolkit inventory
```

## Preview capability installation

Toolkit can place capabilities into supported coding-tool profiles. Preview
the exact files, conflicts, and changes before writing anything:

```sh
agent-toolkit install --dry-run --offline
```

Review that output, then run `agent-toolkit install` without `--force` to apply
the intended targets. A preview does not sign in to a provider, configure MCP
secrets, or prove that a coding-tool account is authenticated. Use each tool's
own sign-in and status commands for account state.

Skills live under `skills/`, portable agent definitions under `agents/`, MCP
templates under `mcp/templates/`, and reusable workflow recipes under
`loops/` and `packs/`. Check the relevant guide before installing or editing
user-owned files:

- [Skills](HOW_TO_ADD_SKILL.md)
- [Agent definitions](HOW_TO_ADD_AGENT.md)
- [Profiles and target compatibility](PROFILES.md)
- [MCP templates and security](MCP.md)
- [Trust and provenance](TRUST.md)

## Use Veasel Code for interactive coding

Install Veasel Code from its
[official releases](https://github.com/veasel-labs/veasel/releases/latest)
and follow its documentation for TUI, Desktop, providers, and shared sessions.
Agent Toolkit remains independently useful when you use another supported
coding tool; Veasel Code is the associated graphical coding product.

## Existing Toolkit Desktop data

The former Agent Toolkit Electron Desktop is not included in new Toolkit
releases. Existing installations, workspaces, settings, and credentials are
left in place; Veasel does not automatically import or delete them. Before
removing an older Toolkit Desktop installation or its data directory, review
the [compatibility and migration notes](VEASEL_COMPATIBILITY.md) and keep a
backup. Historical source and tests remain in the repository while unique
capabilities and data formats are accounted for.
