# Compatibility

## Minimum AI tool versions

| Target | Minimum version | Notes |
|--------|----------------|-------|
| Claude Code | Any current version | Plugin marketplace supported |
| Cursor | 2.5+ | Plugin system added in 2.5 |
| GitHub Copilot CLI | Any current | Open Plugin Spec optional |
| Gemini CLI | 0.1.0+ | Extension system available |
| OpenCode | 0.3+ | JS/TS module plugins |
| Pi Coding Agent | Any current | npm package system |
| Windsurf/Devin | Any current | No marketplace — bundle only |
| OpenAI Codex | Recent | Marketplace launched March 2026 (experimental) |

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
