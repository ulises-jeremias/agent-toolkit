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

## Adapter tiers (harness harness-specific adapters #868 / #869)

Per `capabilities/targets/registry.yaml` (`tier` + `tier_rationale`) — the compiler tiers are the SSOT.
Generated detail: `docs/TARGET_CAPABILITY_MATRIX.md` (Adapter Tiers, Tier Assignment).

| Tier | Label | Targets | What the adapter supports |
|------|-------|---------|---------------------------|
| **A — Rich multi-agent** | Full delegation, perms/models, hooks, MCP, marketplace | Claude Code, Cursor | Holistic + specialist agents, auto/nested/parallel delegation, `native_custom_agents: true`, `subagents: true` |
| **B — Custom agents, limited delegation** | Agents + routing, partial/bridged delegation/MCP/hooks | OpenCode, Gemini CLI, GitHub Copilot CLI, Pi, OpenAI Codex | `native_custom_agents: true`, delegation/parallel/MCP/hooks partial or unknown-blocked |
| **C — Skills + instructions** | Agent Skills, rules/instructions, no subagents/delegation | GitHub Copilot Repository, Muse Code, Agent Plugins | `agent_skills: true`, `subagents: false`, no nested/parallel |
| **D — Minimal** | Richest correct subset only (rules + manual MCP) | Windsurf | No marketplace/extensions, no custom delegation — customization bundle |

## Target matrix

| Target | Package type | Tier | Skills | Agents | Hooks | MCP | Maturity |
|--------|-------------|------|--------|--------|-------|-----|----------|
| Claude Code | plugin (.claude-plugin/) | A | native | native | native | native | stable |
| Cursor IDE/CLI | plugin (.cursor-plugin/) | A | native | native | native | native | stable |
| **Agent Plugins 1.0** | plugin (`plugin.json` + `mcp.json` + `skills/`) | C | native (portable) | native (via `com.anthropic.claude-code` extension) | — | native (stdio `mcp.json`) | stable |
| OpenCode | companion-assets | B | native | native | partial† | partial† | stable |
| Copilot CLI | plugin (plugin.json) | B | native | native | unknown-blocked | unknown-blocked | stable |
| Copilot Repository | repository-customization | C | native | native | — | — | stable |
| Gemini CLI | extension (gemini-extension.json) | B | native | native | native | native | stable |
| Pi Coding Agent | companion-assets | B | native | native | partial† | partial† | stable |
| Windsurf | customization-bundle | D | partial (via rules) | partial (via rules) | — | manual | limited |
| OpenAI Codex | plugin (.codex-plugin/) | B | native | native | unknown-blocked | partial | experimental |

Hooks/MCP modeled per target in registry (native/partial/unknown/—). † OpenCode/Pi require TypeScript runtime bridge for hooks/MCP/tool interception (#10).

> **Agent Plugins 1.0** is the portable `plugin.json` target for Cursor, VS Code, Copilot, Kiro, and Codex. It emits `plugin.json` (`$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`) + `skills/` + `mcp.json` (+ `com.anthropic.claude-code` extension for Claude compatibility). Validate with `./scripts/validate-agent-plugins.vsh --check`; CI job is `Validate Agent Plugins 1.0`. See `docs/AGENT_PLUGINS.md`.

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

# Releases are CI-only (the `release` command was retired, #527)
# See docs/RELEASING.md: push a v* tag to cut a release.
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

All capability claims are based on official documentation as of 2026-08-25 (researched_at in `capabilities/targets/registry.yaml`).
See `docs/research/platform-capability-matrix.md` and `docs/research/source-ledger.md` (prior research 2026-08-04, refreshed per-#862/#868).

Per-target certification: `docs/certification/windsurf.md` (customization bundle, ADR-002).
`docs/TARGET_CAPABILITY_MATRIX.md` is the generated, CI-checked view of `capabilities/targets/registry.yaml` — run `python3 scripts/generate-target-matrix.py --check` or `agent-toolkit build --check`.
