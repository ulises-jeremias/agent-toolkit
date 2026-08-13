# Claude Code target certification

**Issue:** [#86](https://github.com/ulises-jeremias/agent-toolkit/issues/86)  
**Target ID:** `claude-code`  
**Audited:** 2026-08-05 against [Claude Code plugins](https://code.claude.com/docs/en/plugins) and [hooks](https://code.claude.com/docs/en/hooks)

## Official contract (summary)

| Surface | Official location | Format |
|---------|-------------------|--------|
| Plugin manifest | `<plugin>/.claude-plugin/plugin.json` | JSON (name, version, description, author) |
| Skills | `<plugin>/skills/<name>/SKILL.md` | Agent Skills spec |
| Agents | `<plugin>/agents/<name>/AGENT.md` | Markdown + YAML frontmatter |
| Hooks | `<plugin>/hooks/hooks.json` | Event → command mapping |
| MCP | `<plugin>/.mcp.json` or project root | MCP server definitions |
| User settings | `~/.claude/settings.json` | User-owned; plugins enable via marketplace |

**Security contract:** `~/.claude/settings.json` is user-owned. Public distributions must not overwrite it. Plugin-specific settings belong in the plugin bundle or marketplace install flow only (`plugin_settings_scope: plugin-local`).

## Current adapter behavior

| Capability | Adapter status | Notes |
|------------|----------------|-------|
| Plugin manifest | **Certified** | Emits `.claude-plugin/plugin.json` |
| Skills | **Certified** | Emits `skills/<name>/SKILL.md` + references |
| Agents | **Certified** | Emits `agents/<name>/AGENT.md` |
| Hooks | **Not implemented** | Reported in `result.unsupported` |
| MCP (`.mcp.json`) | **Not implemented** | Reported in `result.unsupported` |
| Profile install | **Certified safe** | `agent-toolkit install` skips `~/.claude/settings.json` |

## Gaps (documented, not hidden)

1. Hooks and MCP registries exist in the repo but are not wired into `ClaudeCodeAdapter.compile()` yet (issue #16 / MCP registry work).
2. `profiles/claude-code/settings.json` is a **reference only** — never copied to the user home directory.

## Validation

```bash
make build-cli
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --target claude-code --check
uv sync --project packages/pypi/agent-toolkit-cli --all-extras
uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/compiler/test_claude_code_adapter.py tests/test_install_claude_settings.py -q
```

## References

- `distributions/targets/claude-code.yaml`
- `packages/pypi/agent-toolkit-cli/src/agent_toolkit/compiler/targets/claude_code.py`
- `packages/pypi/agent-toolkit-cli/src/agent_toolkit/cli/install.py` (`_install_claude_code`)
