# V remaining target emitters

**Issue:** [#552](https://github.com/ulises-jeremias/agent-toolkit/issues/552)

Completes non-Tier-1 compiler families in V:

| Target | Surface |
|--------|---------|
| `copilot-cli` / `copilot` | root `plugin.json`, `skills/`, `agents/*.agent.md` |
| `copilot-repository` | `.github/copilot-instructions.md`, skills/agents |
| `windsurf` | `AGENTS.md`, `rules/*.mdc`, `skills/` |
| `pi` | `pi-package.json`, skills/agents |
| `gemini-cli` / `gemini` | `gemini-extension.json`, `commands.toml`, skills, `context/` |
| `muse-code` / `muse` | `skills/`, `agents/` |
| `codex` | `.codex-plugin/plugin.json` (experimental), skills/agents |
| `agent-plugins` | Agent Plugins 1.0 root `plugin.json` (+ skills); MCP registry deferred |

Hooks/MCP registries remain reported in `unsupported` where Python also deferred them. Wired into `compile_target` / `build --check`.
