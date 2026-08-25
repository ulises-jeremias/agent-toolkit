# Target Capability Matrix

> Generated from `capabilities/targets/registry.yaml` — do not hand-edit.
> Run `python3 scripts/generate-target-matrix.py` to regenerate, or `python3 scripts/generate-target-matrix.py --check` in CI.

_Researched at: 2026-08-25 — sources per target below._

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Supported (native/stable) |
| ❌ | Not supported |
| ◐ partial | Partial / bridged / requires runtime |
| ❓ unknown | Could not confirm from official docs |
| `v1` | Agent Plugins 1.0 portable |
| `custom` | Tool-specific custom format |
| — | None / not applicable |

## Capability × Target

| Capability | Claude Code | Cursor | OpenCode | Gemini CLI | GitHub Copilot CLI | GitHub Copilot Repository | Pi Coding Agent | Windsurf | OpenAI Codex | Muse Code | Agent Plugins (Portable) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Agent Skills | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ◐ partial | ✅ | ✅ | ✅ |
| Agent Plugins | `v1` | `v1` | `custom` | `custom` | `v1` | — | `custom` | — | `v1` | `custom` | `v1` |
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

## Build Commands

| Target | `build` | `diff` | `release` | Maturity | Aliases |
|--------|---------|--------|-----------|----------|---------|
| Claude Code (`claude-code`) | ✅ | ✅ | ✅ | stable | — |
| Cursor (`cursor`) | ✅ | ✅ | ✅ | stable | — |
| OpenCode (`opencode`) | ✅ | ✅ | ✅ | stable | — |
| Gemini CLI (`gemini-cli`) | ✅ | ❌ | ✅ | stable | `gemini` |
| GitHub Copilot CLI (`copilot-cli`) | ✅ | ❌ | ✅ | stable | `copilot` |
| GitHub Copilot Repository (`copilot-repository`) | ✅ | ❌ | ✅ | stable | — |
| Pi Coding Agent (`pi`) | ✅ | ❌ | ✅ | stable | — |
| Windsurf (`windsurf`) | ✅ | ❌ | ✅ | limited | — |
| OpenAI Codex (`codex`) | ✅ | ❌ | ✅ | experimental | — |
| Muse Code (`muse-code`) | ✅ | ❌ | ✅ | stable | `muse` |
| Agent Plugins (Portable) (`agent-plugins`) | ✅ | ✅ | ✅ | stable | — |

## Per-Target Details

### Claude Code (`claude-code`)

- **Adapter:** `agent_toolkit.compiler.targets.claude_code.ClaudeCodeAdapter`
- **Aliases:** —
- **Commands:** build=✅ diff=✅ release=✅
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

