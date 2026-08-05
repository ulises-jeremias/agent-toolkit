# Cursor target certification

**Issue:** [#87](https://github.com/ulises-jeremias/agent-toolkit/issues/87)  
**Target ID:** `cursor`  
**Audited:** 2026-08-05 against [Cursor docs](https://cursor.com/docs) and [rules](https://cursor.com/docs/context/rules)

## Official contract (summary)

| Surface | Official location | Format |
|---------|-------------------|--------|
| Plugin manifest | `<plugin>/.cursor-plugin/plugin.json` | JSON (shared schema with Claude Code plugins) |
| Skills | `<plugin>/skills/<name>/SKILL.md` | Agent Skills spec (on-demand procedures) |
| Agents | `<plugin>/agents/<name>/AGENT.md` | Agent persona definitions |
| Rules | `~/.cursor/rules/*.mdc` or `.cursor/rules/` | `.mdc` with YAML frontmatter (`description`, `alwaysApply`) |
| MCP | `~/.cursor/mcp.json` | User-configured; not bundled in plugin |
| Hooks | Cursor lifecycle events | Platform supports hooks; toolkit pending canonical hook model (#16) |

**Semantic distinction:** Rules are persistent session constraints; skills are on-demand procedures. The compiler emits skills/agents in the plugin bundle; rules ship via the separate `profiles/cursor/rules/` profile surface.

## Current adapter behavior

| Capability | Adapter status | Notes |
|------------|----------------|-------|
| Plugin manifest | **Certified** | Emits `.cursor-plugin/plugin.json` |
| Skills | **Certified** | Emits `skills/<name>/SKILL.md` |
| Agents | **Certified** | Emits `agents/<name>/AGENT.md` |
| Rules (`.mdc`) | **Profile surface** | Installed to `~/.cursor/rules/` via `agent-toolkit install`; not duplicated in plugin bundle |
| MCP | **Manual** | User configures `~/.cursor/mcp.json`; reported as unsupported in plugin compile |
| Hooks | **Not implemented** | Reported in `result.unsupported` |

## Gaps (documented, not hidden)

1. Plugin compile does not emit `.mdc` rules — by design (different semantic from skills).
2. MCP and hooks are not generated from canonical IR until registry/hook model lands.

## Validation

```bash
uv sync --group dev
uv run pytest tests/compiler/test_cursor_adapter.py tests/test_cursor_profile_rules.py -q
uv run agent-toolkit build --target cursor --check
```

## References

- `distributions/targets/cursor.yaml`
- `packages/agent-toolkit-cli/src/agent_toolkit/compiler/targets/cursor.py`
- `profiles/cursor/rules/*.mdc`
