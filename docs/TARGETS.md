# Supported Targets

agent-toolkit compiles canonical capabilities into target-native artifacts.
Each target receives the strongest integration it actually supports.

## Capability values

- `native` — officially supported, stable
- `native-experimental` — officially supported but beta/preview
- `generated` — compiled from canonical sources into target format
- `bridged` — works through an adapter
- `manual` — user must configure manually
- `unsupported` — platform does not support this capability
- `unknown-blocked` — could not confirm from official documentation

## Target matrix

| Target | Package type | Skills | Agents | Hooks | MCP | Maturity |
|--------|-------------|--------|--------|-------|-----|----------|
| Claude Code | plugin (.claude-plugin/) | native | native | unsupported* | unsupported* | stable |
| Cursor IDE/CLI | plugin (.cursor-plugin/) | native | native | unsupported* | manual | stable |
| OpenCode | companion-assets | native | native | unsupported† | unsupported† | stable |
| Copilot CLI | plugin (plugin.json) | native | native | unsupported* | unknown-blocked | stable |
| Copilot Repository | repository-customization | native | native | unsupported | unsupported | stable |
| Gemini CLI | extension (gemini-extension.json) | native | native | unsupported* | unsupported* | stable |
| Pi Coding Agent | companion-assets | native | native | unsupported† | unsupported† | stable |
| Windsurf | customization-bundle | native | generated (rules) | unsupported | unsupported | stable |
| OpenAI Codex | plugin (.codex-plugin/) | native | native | unknown-blocked | unknown-blocked | experimental |

*pending canonical hook model (issue #16)
†requires TypeScript runtime plugin

## Install commands

```bash
# Build for a specific target
agent-toolkit build --target claude-code --check
agent-toolkit build --target cursor --product agent-toolkit-core

# Install profiles (profiles are a fallback for non-marketplace installs)
agent-toolkit install --tools cursor,claude-code

# Release dry run (generates dist/ without publishing)
agent-toolkit release --dry-run --output dist/
```

## Research sources

All capability claims are based on official documentation as of 2026-08-04.
See `docs/research/platform-capability-matrix.md` and `docs/research/source-ledger.md`.
