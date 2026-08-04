# AI Coding Platform Plugin/Extension Capability Matrix

**Research Date:** 2026-08-04  
**Sources:** Official documentation only (see source-ledger.md)

## Capability Value Definitions

- `native` — officially supported, stable
- `native-experimental` — officially supported but beta/preview
- `generated` — compiled from canonical sources into target format
- `bridged` — works through an adapter
- `manual` — user must configure manually; no automated install
- `unsupported` — platform does not support this capability
- `unknown-blocked` — could not confirm from official documentation

---

## Platform Overview

| Platform | Package Type | Stability | Marketplace | Notes |
|----------|-------------|-----------|-------------|-------|
| Claude Code | Plugin (`.claude-plugin/`) | Stable GA | Yes (official + community) | Full plugin ecosystem |
| Cursor IDE/CLI | Plugin (`.cursor-plugin/`) | Stable GA | Yes (team + official) | v2.5+, hooks + MCP |
| GitHub Copilot CLI | Plugin (`plugin.json`) | Stable GA | Yes (copilot-plugins, awesome-copilot) | Open Plugin Spec |
| Gemini CLI | Extension (`gemini-extension.json`) | Stable GA | Yes (geminicli.com) | TOML commands |
| OpenCode | JS/TS Module | Stable | npm/git | No JSON manifest |
| Pi Coding Agent | npm Package | Stable | pi.dev/packages | Auto-discovery |
| Windsurf/Devin | **No marketplace extensions** | Limited | None | MCP + rules only |
| OpenAI Codex | Plugin (`.codex-plugin/`) | Experimental | Yes (launched March 2026) | Very new |

---

## Capability Matrix

| Capability | Claude Code | Cursor | Copilot CLI | Gemini CLI | OpenCode | Pi | Windsurf | Codex |
|-----------|------------|--------|-------------|------------|----------|----|----------|-------|
| **Plugin manifest** | native | native | native | native | unsupported | native (package.json) | unsupported | native-experimental |
| **Skills discovery** | native | native | native | native | generated | native | unsupported | native-experimental |
| **Agents/subagents** | native | native | native | native-experimental | unsupported | native | unsupported | native-experimental |
| **Slash commands** | native | native | native | native | native | native | unsupported | unknown-blocked |
| **Rules/context** | native | native | manual | manual | manual | manual | native (only mechanism) | unknown-blocked |
| **Lifecycle hooks** | native (33 events) | native (16+ events) | unknown-blocked | native (8+ events) | unsupported | unsupported | unsupported | unknown-blocked |
| **MCP servers** | native | native | unknown-blocked | native | bridged | bridged | native (manual config) | native-experimental |
| **Tool restrictions** | native | native | unknown-blocked | native | unsupported | unsupported | unsupported | unknown-blocked |
| **Permission system** | native | native | native | native | unsupported | unsupported | unsupported | native-experimental |
| **Local dev install** | native | native | native | native | native | native | manual | unknown-blocked |
| **Git distribution** | native | native | native | native | native | native | manual | unknown-blocked |
| **Update mechanism** | native | native | native | native | manual | native | manual | unknown-blocked |
| **Uninstall** | native | native | native | native | manual | native | manual | unknown-blocked |
| **CLI validation** | native (`claude plugin validate`) | unknown-blocked | unknown-blocked | native | unknown-blocked | unknown-blocked | unsupported | unknown-blocked |

---

## Critical Finding: Windsurf

**Windsurf/Devin Desktop does NOT have an open marketplace extension model.**

> "You cannot install extensions through any marketplace on Devin Desktop."

This means agent-toolkit must be distributed as a **native customization bundle** for Windsurf,
not a plugin. The bundle includes rules (`.mdc`), MCP server config (manual), and documentation.

This must be labeled accurately: it is a "Windsurf Customization Bundle", not a "Windsurf Plugin".

---

## Key Observations

### Universal patterns across all stable targets
1. Skills/on-demand procedures use SKILL.md (Agent Skills spec)
2. JSON manifests are standard (except OpenCode)
3. Directory-based auto-discovery is universal
4. MCP is supported across all meaningful targets
5. Git-based local distribution works everywhere

### Major divergences
- Gemini CLI uses TOML for commands (not YAML frontmatter)
- OpenCode requires JS/TS runtime code (not JSON manifest)
- Pi uses npm package registry
- Windsurf has no plugin mechanism — rules/MCP only
- OpenAI Codex marketplace is very new (March 2026)

---

## Distribution Strategy by Target

| Target | Recommended distribution | Install command |
|--------|--------------------------|----------------|
| Claude Code | Git marketplace | `/plugin marketplace add ulises-jeremias/agent-toolkit` |
| Cursor | Git marketplace | Import via Dashboard → Plugins |
| Copilot CLI | Git marketplace | `copilot plugin install NAME@MARKETPLACE` |
| Gemini CLI | GitHub release | `gemini extensions add ulises-jeremias/agent-toolkit-gemini` |
| OpenCode | npm | `opencode plugin add agent-toolkit-opencode` |
| Pi | npm | `pi install npm:agent-toolkit-pi` |
| Windsurf | Manual bundle | `agent-toolkit install --target windsurf --scope project` |
| Codex | Marketplace | Unknown (self-serve submission coming) |
