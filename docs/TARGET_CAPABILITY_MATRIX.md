# Target Capability Matrix

> Generated from `capabilities/targets/registry.yaml` — do not hand-edit.
> Run `python3 scripts/generate-target-matrix.py` to regenerate, or `python3 scripts/generate-target-matrix.py --check` in CI.

_Researched at: 2026-08-25 — sources per target below._

## Adapter Tiers (#868)

Tiers describe the **harness adapter richness** — what the harness natively supports and what the compiler may emit. Least-common-denominator is rejected: each target receives the richest correct subset it supports. `tier` is stored in `capabilities/targets/registry.yaml` (`tier: A/B/C/D`) per #868.

| Tier | Label | What the adapter supports | Targets |
|------|-------|---------------------------|---------|
| **A** | Rich multi-agent | Holistic + specialist agents, delegation (auto/nested/parallel), permissions, models, hooks, MCP, marketplace | Claude Code, Cursor |
| **B** | Custom agents, limited delegation | Agents + routing guidance, explicit handoffs; some delegation/MCP/hooks partial or bridged | OpenCode, Gemini CLI, GitHub Copilot CLI, Pi Coding Agent, OpenAI Codex |
| **C** | Skills + instructions | Agent Skills, global routing guidance, rules/instructions, MCP where native; no subagents/delegation | GitHub Copilot Repository, Muse Code, Agent Plugins (Portable) |
| **D** | Minimal | Richest correct subset only (rules + manual MCP); no marketplace/extensions, no custom agent delegation | Windsurf |

> **Gating:** if a capability is `false`/`unknown` the compiler **must not** emit its config (e.g., no subagent config where `subagents: false`). Partial/unknown degrade gracefully via instruction fallback, not invalid config.

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Supported (native/stable) |
| ❌ | Not supported |
| ◐ partial | Partial / bridged / requires runtime |
| ❓ unknown | Could not confirm from official docs |
| `v1` | Agent Plugins 1.0 portable |
| `v1` (portable) | Portable via agent-plugins.org (skills + mcp.json) |
| `custom` | Tool-specific custom format |
| `custom` (requires extension X) | Custom agents via client extension — not portable without that extension |
| — | None / not applicable |

> **Portable vs extension (#973):** `agent_plugins: v1` with `agent_plugins_extension: portable` means portable Agent Plugins 1.0 (skills + mcp.json) per https://agent-plugins.org — guaranteed across Cursor, VS Code, Copilot, Codex, Claude Code. `custom` with `agent_plugins_extension: <extension>` (e.g. `opencode.json`, `gemini-extension.json`, `pi-package.json`) means custom-agent support requires that vendor-specific extension inside an otherwise portable `plugin.json` — not portable without it. `none` = no plugin manifest.

## Capability × Target

| Capability | Claude Code | Cursor | OpenCode | Gemini CLI | GitHub Copilot CLI | GitHub Copilot Repository | Pi Coding Agent | Windsurf | OpenAI Codex | Muse Code | Agent Plugins (Portable) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Agent Skills | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◐ partial | ✅ | ✅ | ✅ |
| Agent Plugins | `v1` (portable) | `v1` (portable) | `custom` (requires opencode.json) | `custom` (requires gemini-extension.json) | `v1` (portable) | — | `custom` (requires pi-package.json) | — | `v1` (portable) | `custom` (requires muse-plugin) | `v1` (portable) |
| Native Custom Agents | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◐ partial | ✅ | ✅ | ✅ |
| Primary / Default Agents | ✅ | ✅ | ◐ partial | ◐ partial | ✅ | ❌ | ◐ partial | ❌ | ✅ | ❌ | ❌ |
| Subagents | ✅ | ✅ | ✅ | ◐ partial | ◐ partial | ❌ | ✅ | ❌ | ✅ | ❌ | ❌ |
| Automatic Delegation | ✅ | ✅ | ◐ partial | ◐ partial | ◐ partial | ❌ | ◐ partial | ❌ | ◐ partial | ❌ | ❌ |
| Nested Delegation | ✅ | ◐ partial | ◐ partial | ◐ partial | ◐ partial | ❌ | ◐ partial | ❌ | ◐ partial | ❌ | ❌ |
| Parallel Agents | ✅ | ✅ | ✅ | ◐ partial | ◐ partial | ❌ | ◐ partial | ❌ | ✅ | ❌ | ❌ |
| Agent Permissions | ✅ | ✅ | ✅ | ✅ | ◐ partial | ◐ partial | ✅ | ❌ | ◐ partial | ◐ partial | ❌ |
| Agent Models | ✅ | ✅ | ✅ | ✅ | ◐ partial | ❌ | ✅ | ❌ | ✅ | ◐ partial | ❌ |
| MCP | ✅ | ✅ | ◐ partial | ✅ | ❓ unknown | ❌ | ◐ partial | ✅ | ◐ partial | ◐ partial | ✅ |
| Hooks | ✅ | ✅ | ◐ partial | ✅ | ❓ unknown | ❌ | ◐ partial | ❌ | ❓ unknown | ❌ | ❌ |
| Commands | ✅ | ✅ | ✅ | ✅ | ✅ | ◐ partial | ✅ | ❌ | ◐ partial | ✅ | ✅ |
| Rules / Instructions | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Plugin Marketplace | ✅ | ✅ | ◐ partial | ✅ | ✅ | ❌ | ◐ partial | ❌ | ✅ | ❌ | ✅ |

## Build Commands & Tiers

| Target | `build` | `diff` | `release` | Tier | Maturity | Aliases |
|--------|---------|--------|-----------|------|----------|---------|
| Claude Code (`claude-code`) | ✅ | ✅ | ✅ | A | stable | — |
| Cursor (`cursor`) | ✅ | ✅ | ✅ | A | stable | — |
| OpenCode (`opencode`) | ✅ | ✅ | ✅ | B | stable | — |
| Gemini CLI (`gemini-cli`) | ✅ | ❌ | ✅ | B | stable | `gemini` |
| GitHub Copilot CLI (`copilot-cli`) | ✅ | ❌ | ✅ | B | stable | `copilot` |
| GitHub Copilot Repository (`copilot-repository`) | ✅ | ❌ | ✅ | C | stable | — |
| Pi Coding Agent (`pi`) | ✅ | ❌ | ✅ | B | stable | — |
| Windsurf (`windsurf`) | ✅ | ❌ | ✅ | D | limited | — |
| OpenAI Codex (`codex`) | ✅ | ❌ | ✅ | B | experimental | — |
| Muse Code (`muse-code`) | ✅ | ❌ | ✅ | C | stable | `muse` |
| Agent Plugins (Portable) (`agent-plugins`) | ✅ | ✅ | ✅ | C | stable | — |

## Tier Assignment

| Target | Tier | Rationale |
|--------|------|-----------|
| Claude Code (`claude-code`) | A | Full plugin (.claude-plugin/) - native skills/agents/subagents, nested+parallel+auto delegation, perms/models, 33 hooks, MCP, v1 marketplace |
| Cursor (`cursor`) | A | Full plugin (.cursor-plugin/) v2.5+ - skills/agents/subagents, auto+parallel delegation, perms/models, 16+ hooks, MCP, v1 marketplace; nested partial only |
| OpenCode (`opencode`) | B | JS/TS module - native agents/subagents/parallel/perms/models, but auto/nested partial and MCP/hooks require TypeScript runtime bridge |
| Gemini CLI (`gemini-cli`) | B | Extension (gemini-extension.json) + TOML commands - native agents, MCP/hooks native, but primary/subagents/delegation/parallel partial |
| GitHub Copilot CLI (`copilot-cli`) | B | Open Plugin Spec (plugin.json) - native agents/primary/subagents partial, perms/models partial, MCP/hooks unknown - limited delegation |
| GitHub Copilot Repository (`copilot-repository`) | C | Repository customization (.github/copilot-instructions.md, .github/agents/*.agent.md, .github/skills/) - no plugin/marketplace, no subagents/delegation/hooks/MCP |
| Pi Coding Agent (`pi`) | B | npm package (pi-package.json) - native agents/subagents/perms/models, but MCP/hooks/parallel partial requiring TypeScript ExtensionAPI |
| Windsurf (`windsurf`) | D | No marketplace extensions per docs.devin.ai - customization bundle only: rules .mdc + manual MCP, no agents/subagents/delegation/perms/models/hooks/commands |
| OpenAI Codex (`codex`) | B | Experimental .codex-plugin (Mar 2026) - native agents/subagents/parallel, MCP partial, hooks unknown-blocked, delegation partial |
| Muse Code (`muse-code`) | C | Custom plugin - skills under ~/.config/muse/skills + .agents/skills fallback, agents true but no primary/subagents/delegation/hooks, MCP partial, no marketplace |
| Agent Plugins (Portable) (`agent-plugins`) | C | Synthetic portable plugin.json + skills/ + mcp.json for Cursor/VS Code/Copilot/Kiro/Codex; agents via com.anthropic.claude-code extension; no primary/subagents/delegation |

## Per-Target Details

### Claude Code (`claude-code`)

- **Adapter:** `agent_toolkit.compiler.targets.claude_code.ClaudeCodeAdapter`
- **Aliases:** —
- **Commands:** build=✅ diff=✅ release=✅
- **Tier:** A
- **Tier rationale:** Full plugin (.claude-plugin/) - native skills/agents/subagents, nested+parallel+auto delegation, perms/models, 33 hooks, MCP, v1 marketplace
- **Agent Plugins:** `v1` (portable via https://agent-plugins.org)
- **Maturity:** stable
- **Researched at:** 2026-08-25
- **Sources:**
  - https://docs.anthropic.com/en/docs/claude-code
  - https://code.claude.com/docs/en/plugins
  - https://code.claude.com/docs/en/hooks
  - https://agent-plugins.org
  - https://modelcontextprotocol.io
- **Notes:** Full plugin (.claude-plugin/) with native skills, agents, subagents, hooks (33 events), MCP, and Agent Plugins v1 portable.

### Cursor (`cursor`)

- **Adapter:** `agent_toolkit.compiler.targets.cursor.CursorAdapter`
- **Aliases:** —
- **Commands:** build=✅ diff=✅ release=✅
- **Tier:** A
- **Tier rationale:** Full plugin (.cursor-plugin/) v2.5+ - skills/agents/subagents, auto+parallel delegation, perms/models, 16+ hooks, MCP, v1 marketplace; nested partial only
- **Agent Plugins:** `v1` (portable via https://agent-plugins.org)
- **Maturity:** stable
- **Researched at:** 2026-08-25
- **Sources:**
  - https://docs.cursor.com
  - https://cursor.com/docs/plugins
  - https://docs.cursor.com/context/rules
  - https://docs.cursor.com/context/mcp
  - https://agent-plugins.org
- **Notes:** Plugin (.cursor-plugin/) stable GA v2.5+; hooks 16+ events, MCP native, rules .mdc. Nested delegation partially confirmed.

### OpenCode (`opencode`)

- **Adapter:** `agent_toolkit.compiler.targets.opencode.OpenCodeAdapter`
- **Aliases:** —
- **Commands:** build=✅ diff=✅ release=✅
- **Tier:** B
- **Tier rationale:** JS/TS module - native agents/subagents/parallel/perms/models, but auto/nested partial and MCP/hooks require TypeScript runtime bridge
- **Agent Plugins:** `custom` (requires extension `opencode.json (requires TypeScript runtime)` — not portable without it)
- **Maturity:** stable
- **Researched at:** 2026-08-25
- **Sources:**
  - https://opencode.ai/docs
  - https://opencode.ai/docs/plugins
  - https://opencode.ai/docs/mcp
- **Notes:** JS/TS module via opencode.json + .opencode/skills; hooks/MCP/tool interception require TypeScript runtime plugin (issue

### Gemini CLI (`gemini-cli`)

- **Adapter:** `agent_toolkit.compiler.targets.gemini_cli.GeminiCLIAdapter`
- **Aliases:** `gemini`
- **Commands:** build=✅ diff=❌ release=✅
- **Tier:** B
- **Tier rationale:** Extension (gemini-extension.json) + TOML commands - native agents, MCP/hooks native, but primary/subagents/delegation/parallel partial
- **Agent Plugins:** `custom` (requires extension `gemini-extension.json` — not portable without it)
- **Maturity:** stable
- **Researched at:** 2026-08-25
- **Sources:**
  - https://github.com/google-gemini/gemini-cli/blob/main/docs/extensions/index.md
  - https://github.com/google-gemini/gemini-cli
  - https://geminicli.com/docs
  - https://modelcontextprotocol.io
- **Notes:** Extension (gemini-extension.json) + commands.toml; hooks 8+ events, MCP native, TOML commands. Subagent/parallel partially confirmed.

### GitHub Copilot CLI (`copilot-cli`)

- **Adapter:** `agent_toolkit.compiler.targets.copilot.CopilotCLIAdapter`
- **Aliases:** `copilot`
- **Commands:** build=✅ diff=❌ release=✅
- **Tier:** B
- **Tier rationale:** Open Plugin Spec (plugin.json) - native agents/primary/subagents partial, perms/models partial, MCP/hooks unknown - limited delegation
- **Agent Plugins:** `v1` (portable via https://agent-plugins.org)
- **Maturity:** stable
- **Researched at:** 2026-08-25
- **Sources:**
  - https://docs.github.com/en/copilot
  - https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference
  - https://agent-plugins.org
- **Notes:** Plugin (root plugin.json) via Open Plugin Spec; MCP/hooks not confirmed in official docs — marked unknown per source-ledger.

### GitHub Copilot Repository (`copilot-repository`)

- **Adapter:** `agent_toolkit.compiler.targets.copilot.CopilotRepositoryAdapter`
- **Aliases:** —
- **Commands:** build=✅ diff=❌ release=✅
- **Tier:** C
- **Tier rationale:** Repository customization (.github/copilot-instructions.md, .github/agents/*.agent.md, .github/skills/) - no plugin/marketplace, no subagents/delegation/hooks/MCP
- **Agent Plugins:** `none` / extension `none`
- **Maturity:** stable
- **Researched at:** 2026-08-25
- **Sources:**
  - https://docs.github.com/en/copilot/customizing-copilot
  - https://docs.github.com/en/copilot/customizing-copilot/using-custom-instructions
- **Notes:** Repository customization (.github/copilot-instructions.md, .github/agents/*.agent.md, .github/skills/); no plugin marketplace — repo-scoped only.

### Pi Coding Agent (`pi`)

- **Adapter:** `agent_toolkit.compiler.targets.pi.PiAdapter`
- **Aliases:** —
- **Commands:** build=✅ diff=❌ release=✅
- **Tier:** B
- **Tier rationale:** npm package (pi-package.json) - native agents/subagents/perms/models, but MCP/hooks/parallel partial requiring TypeScript ExtensionAPI
- **Agent Plugins:** `custom` (requires extension `pi-package.json (requires TypeScript ExtensionAPI)` — not portable without it)
- **Maturity:** stable
- **Researched at:** 2026-08-25
- **Sources:**
  - https://pi.dev/docs/latest/extensions
  - https://pi.dev/docs
  - https://opencode.ai/docs/plugins
- **Notes:** npm package (pi-package.json) auto-discovery; hooks/MCP/tool registration require TypeScript ExtensionAPI — partial.

### Windsurf (`windsurf`)

- **Adapter:** `agent_toolkit.compiler.targets.windsurf.WindsurfAdapter`
- **Aliases:** —
- **Commands:** build=✅ diff=❌ release=✅
- **Tier:** D
- **Tier rationale:** No marketplace extensions per docs.devin.ai - customization bundle only: rules .mdc + manual MCP, no agents/subagents/delegation/perms/models/hooks/commands
- **Agent Plugins:** `none` / extension `none`
- **Maturity:** limited
- **Researched at:** 2026-08-25
- **Sources:**
  - https://docs.devin.ai/desktop/getting-started
  - https://docs.codeium.com/windsurf
  - https://docs.codeium.com/windsurf/cascade
- **Notes:** No open marketplace extensions (docs.devin.ai) — distributed as customization bundle (rules .mdc + manual MCP). Skills via generated rules.

### OpenAI Codex (`codex`)

- **Adapter:** `agent_toolkit.compiler.targets.codex.CodexAdapter`
- **Aliases:** —
- **Commands:** build=✅ diff=❌ release=✅
- **Tier:** B
- **Tier rationale:** Experimental .codex-plugin (Mar 2026) - native agents/subagents/parallel, MCP partial, hooks unknown-blocked, delegation partial
- **Agent Plugins:** `v1` (portable via https://agent-plugins.org)
- **Maturity:** experimental
- **Researched at:** 2026-08-25
- **Sources:**
  - https://developers.openai.com/codex
  - https://github.com/openai/codex
  - https://agent-plugins.org
- **Notes:** Plugin (.codex-plugin/) experimental launched March 2026; hooks/MCP not confirmed — marked unknown/partial; self-serve marketplace pending.

### Muse Code (`muse-code`)

- **Adapter:** `agent_toolkit.compiler.targets.muse_code.MuseCodeAdapter`
- **Aliases:** `muse`
- **Commands:** build=✅ diff=❌ release=✅
- **Tier:** C
- **Tier rationale:** Custom plugin - skills under ~/.config/muse/skills + .agents/skills fallback, agents true but no primary/subagents/delegation/hooks, MCP partial, no marketplace
- **Agent Plugins:** `custom` (requires extension `muse-plugin (custom ~/.config/muse/skills)` — not portable without it)
- **Maturity:** stable
- **Researched at:** 2026-08-25
- **Sources:**
  - https://developer.meta.com/ai/products/muse-code/
  - https://github.com/vercel-labs/skills
- **Notes:** Agent Skills under ~/.config/muse/skills/<name>/SKILL.md + .agents/skills fallback; custom plugin format, no marketplace yet.

### Agent Plugins (Portable) (`agent-plugins`)

- **Adapter:** `agent_toolkit.compiler.targets.agent_plugins.AgentPluginsAdapter`
- **Aliases:** —
- **Commands:** build=✅ diff=✅ release=✅
- **Tier:** C
- **Tier rationale:** Synthetic portable plugin.json + skills/ + mcp.json for Cursor/VS Code/Copilot/Kiro/Codex; agents via com.anthropic.claude-code extension; no primary/subagents/delegation
- **Agent Plugins:** `v1` (portable via https://agent-plugins.org)
- **Maturity:** stable
- **Researched at:** 2026-08-25
- **Sources:**
  - https://agent-plugins.org
  - https://github.com/vercel-labs/skills
- **Notes:** Synthetic portable target (plugin.json + skills/ + mcp.json) for Cursor/VS Code/Copilot/Kiro/Codex; agents via com.anthropic.claude-code extension; not a harness.

## See also

- `capabilities/targets/registry.yaml` — source of truth (validated by `schemas/target-capability-registry.schema.json`)
- `schemas/target-capability-registry.schema.json` — JSON schema
- `docs/TARGETS.md` — supported targets overview and install commands
- `docs/research/platform-capability-matrix.md` — prior research (2026-08-04) and capability value definitions
- `docs/research/source-ledger.md` — source URLs and dates
- `agent-toolkit build --check` — compiler drift check

