# Platform Targets

agent-toolkit supports 9 AI coding platforms. Each target receives
the strongest integration it actually supports.

## Capability values

- `native` — officially supported, stable
- `native-experimental` — official but beta/preview
- `generated` — compiled from canonical into target format
- `bridged` — works through an adapter
- `unsupported` — not supported by this platform
- `unknown-blocked` — could not confirm from official docs

## Targets

### Claude Code (claude-code)

**Type:** plugin  
**Install:** `/plugin marketplace add ulises-jeremias/agent-toolkit`  
**Skills:** native | **Agents:** native | **Hooks:** pending #16 | **MCP:** pending #15

### Cursor IDE/CLI (cursor)

**Type:** plugin  
**Install:** Dashboard → Plugins → import `ulises-jeremias/agent-toolkit`  
**Skills:** native | **Agents:** native | **Rules:** separate profile surface  
**Note:** Cursor IDE and Cursor CLI both read from the same plugin bundle.

### GitHub Copilot CLI (copilot-cli)

**Type:** plugin (root-level `plugin.json`)  
**Install:** `copilot plugin install NAME@MARKETPLACE`  
**Skills:** native | **Agents:** `.agent.md` format | **Hooks:** pending #16

### GitHub Copilot Repository (copilot-repository)

**Type:** repository-customization  
**Files:** `.github/copilot-instructions.md`, `.github/agents/*.agent.md`, `.github/skills/`  
**Note:** Separate from Copilot CLI — must be configured independently.

### Gemini CLI (gemini-cli)

**Type:** extension (`gemini-extension.json`)  
**Install:** `gemini extensions add ulises-jeremias/agent-toolkit-gemini`  
**Skills → TOML commands** | **MCP:** pending #15 | **Hooks:** pending #16

### OpenCode (opencode)

**Type:** companion-assets (NOT a plugin — no marketplace)  
**Files:** `.opencode/skills/`, `.opencode/agents/`, `opencode.json`  
**Runtime plugin** (hooks, tools, MCP) requires TypeScript extension.

### Pi Coding Agent (pi)

**Type:** companion-assets  
**Files:** `pi-package.json`, `skills/`, `agents/`  
**Runtime features** (hooks, MCP, tools) require TypeScript extension.

### Windsurf/Devin (windsurf)

**Type:** customization-bundle (NOT a plugin — no marketplace)  
**Files:** `AGENTS.md`, `rules/*.mdc`, `skills/`  
**Memories are never generated** — personal per-user state only.

> From official docs: "You cannot install extensions through any marketplace on Devin Desktop."

### OpenAI Codex (codex) ⚠️ Experimental

**Type:** plugin (`.codex-plugin/plugin.json`)  
**Marketplace:** launched March 2026 — experimental  
**Skills:** native | **Agents:** native | **Hooks/MCP:** unknown-blocked

## Build commands

```bash
agent-toolkit build --target claude-code --check
agent-toolkit build --target cursor --product agent-toolkit-core
agent-toolkit build --target all  # all targets
agent-toolkit diff --target cursor  # what would change
```
