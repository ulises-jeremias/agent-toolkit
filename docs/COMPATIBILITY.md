# Compatibility

## Minimum AI tool versions

| Target | Minimum version | Notes |
|--------|----------------|-------|
| Claude Code | Any current version | Plugin marketplace supported — legacy `.claude-plugin/` only (does not yet support Agent Plugins 1.0) |
| Cursor | 2.5+ | Plugin system added in 2.5 — supports Agent Plugins 1.0 (`plugin.json` + `mcp.json` + `skills/`) |
| VS Code + GitHub Copilot | Any current | Agent Plugins 1.0 via `plugin.json` (extension `com.github.copilot`) — see `docs/AGENT_PLUGINS.md` |
| Kiro | Any current | Agent Plugins 1.0 supported |
| GitHub Copilot CLI | Any current | Open Plugin Spec optional |
| Gemini CLI | 0.1.0+ | Extension system available |
| OpenCode | 0.3+ | JS/TS module plugins |
| Pi Coding Agent | Any current | npm package system |
| Windsurf/Devin | Any current | No marketplace — bundle only — see `docs/certification/windsurf.md` |
| OpenAI Codex | Recent | Marketplace launched March 2026 (experimental) — also supports Agent Plugins 1.0 |

### Agent Plugins 1.0

[Agent Plugins 1.0](https://agent-plugins.org) (`plugin.json` `$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json` + `skills/` + `mcp.json` + `com.*` extensions) is the portable standard for Cursor, VS Code, GitHub Copilot, ChatGPT/Codex, and Kiro. Every `plugins/<name>/` bundle in this repo is dual-emit: portable `plugin.json`/`mcp.json` for those clients and legacy `.claude-plugin/plugin.json` for Claude Code. The compiler target is `agent-plugins` (`capabilities/targets/registry.yaml` → `AgentPluginsAdapter`); validation is `scripts/validate-agent-plugins.vsh --check` and CI job `Validate Agent Plugins 1.0`. Until Claude Code implements the spec, keep `.claude-plugin/` and the `com.anthropic.claude-code` extension. See `docs/AGENT_PLUGINS.md` and `plugins/README.md`.

## Python version

agent-toolkit-cli requires Python 3.10+.

Tested on: 3.10, 3.11, 3.12, 3.13 — Ubuntu + macOS + Windows.

## Known incompatibilities

### Windsurf

Windsurf/Devin Desktop does not support a third-party plugin marketplace.
The `windsurf` compiler target generates a **customization bundle** (rules + AGENTS.md),
not a plugin. This is the strongest integration currently possible.

### OpenAI Codex

The Codex marketplace launched March 2026 and is experimental.
The `maturity: experimental` flag is set in the adapter.
Self-serve marketplace submission was "coming soon" as of the research date (2026-08-04).

### Copilot CLI vs Copilot IDE/Cloud

The Copilot CLI plugin (`copilot-cli` target) and the repository surface
(`copilot-repository` target) are distinct. Installing the CLI plugin does NOT
automatically apply `.github/copilot-instructions.md` to IDE/cloud agents.
Both surfaces must be configured independently.

## Compiler output compatibility

Generated plugin bundles are valid for all tools listed above.
Compatibility is verified by contract tests in `tests/compiler/`.
