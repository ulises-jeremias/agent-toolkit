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
| **Agent Plugins 1.0** | plugin (`plugin.json` + `mcp.json` + `skills/`) | native (portable) | native (via `com.anthropic.claude-code` extension) | unsupported* | native (stdio `mcp.json`) | stable |
| OpenCode | companion-assets | native | native | unsupported† | unsupported† | stable |
| Copilot CLI | plugin (plugin.json) | native | native | unsupported* | unknown-blocked | stable |
| Copilot Repository | repository-customization | native | native | unsupported | unsupported | stable |
| Gemini CLI | extension (gemini-extension.json) | native | native | unsupported* | unsupported* | stable |
| Pi Coding Agent | companion-assets | native | native | unsupported† | unsupported† | stable |
| Windsurf | customization-bundle | native | generated (rules) | unsupported | unsupported | stable |
| OpenAI Codex | plugin (.codex-plugin/) | native | native | unknown-blocked | unknown-blocked | experimental |

*hooks: no stable cross-tool canonical model yet — see target certification docs
†requires TypeScript runtime plugin

> **Agent Plugins 1.0** is the portable `plugin.json` target for Cursor, VS Code, Copilot, Kiro, and Codex. It emits `plugin.json` (`$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`) + `skills/` + `mcp.json` (+ `com.anthropic.claude-code` extension for Claude compatibility). Validate with `python3 scripts/validate-agent-plugins.py --check`; CI job is `Validate Agent Plugins 1.0`. See `docs/AGENT_PLUGINS.md`.

## Install commands

**Primary consumer flow** (auto-detects installed tools):

```bash
uvx --from agent-toolkit-cli agent-toolkit install
agent-toolkit doctor
```

`agent-toolkit install` deploys profiles for: Claude Code, Cursor, OpenCode,
Copilot, Windsurf, and Pi. **Gemini CLI** and **OpenAI Codex** are compile /
release targets today (`agent-toolkit build --target …`); profile install for
those tools is deferred until consumer install paths are certified.

**Advanced** (build, selective tools, release engineering):

```bash
# Install profiles for specific tools only
agent-toolkit install --tools cursor,claude-code

# Build for a specific target
agent-toolkit build --target claude-code --check
agent-toolkit build --target cursor --product agent-toolkit-core

# Release dry run (generates dist/ without publishing)
agent-toolkit release --dry-run --output dist/
```

See [INSTALLATION.md](INSTALLATION.md) for marketplace, Homebrew/AUR, and manual methods.

## Target certification

Per-target certification packages document official contracts vs adapter behavior:

| Target | Certification doc |
|--------|-------------------|
| OpenCode | [`docs/targets/opencode-certification.md`](targets/opencode-certification.md) |
| Copilot CLI | [`docs/targets/copilot-certification.md`](targets/copilot-certification.md) |
| Copilot Repository | [`docs/targets/copilot-certification.md`](targets/copilot-certification.md) |

## Research sources

All capability claims are based on official documentation as of 2026-08-04.
See `docs/research/platform-capability-matrix.md` and `docs/research/source-ledger.md`.

Per-target certification: `docs/certification/windsurf.md` (customization bundle, ADR-002).
