# OpenCode target certification

**Issue:** [#88](https://github.com/ulises-jeremias/agent-toolkit/issues/88)  
**Target ID:** `opencode`  
**Audited:** 2026-08-05 against [OpenCode docs](https://opencode.ai/docs) and [plugins](https://opencode.ai/docs/plugins/)

## Official contract (summary)

| Surface | Official location | Format |
|---------|-------------------|--------|
| Skills | `.opencode/skills/<name>/SKILL.md` | Agent Skills spec |
| Agents | `.opencode/agents/<name>/AGENT.md` | Agent persona definitions |
| Config | `opencode.json` (project or `~/.config/opencode/`) | JSON schema; provider URLs are user-specific |
| Runtime plugin | npm/Bun TypeScript package | Hooks, custom tools, MCP, interception |

**Security contract:** Public `opencode.json` must not contain provider `baseURL` values, private hostnames (`.local`), or RFC1918 IPs. Users configure providers in their own home config.

## Current adapter behavior

| Capability | Adapter status | Notes |
|------------|----------------|-------|
| Static skills/agents | **Certified** | Emits `.opencode/skills/` and `.opencode/agents/` |
| `opencode.json` (compile) | **Certified safe** | Schema-only template; no provider block |
| Profile install | **Certified safe** | `profiles/opencode/opencode.json` sanitized; scanned in CI |
| TypeScript runtime plugin | **Not implemented** | Requires `packages/opencode-plugin/` (issue #10) |
| Hooks / MCP / custom tools | **Not implemented** | Require TypeScript runtime plugin |

## Gaps (documented, not hidden)

1. **TypeScript plugin:** Lifecycle hooks, MCP wiring, and tool policy enforcement need a Bun/npm plugin exporting OpenCode's plugin API — out of scope for static companion assets.
2. **Agent tool frontmatter:** `allowed_tools` / `denied_tools` IR fields are not yet populated from frontmatter (COMP-013); adapters cannot enforce tool policy until loader work lands.

## Validation

```bash
uv sync --group dev
uv run pytest tests/compiler/test_opencode_adapter.py tests/test_install_opencode_profile.py tests/security/test_secret_redaction.py -q
uv run agent-toolkit build --target opencode --check
```

## References

- `distributions/targets/opencode.yaml`
- `packages/agent-toolkit-cli/src/agent_toolkit/compiler/targets/opencode.py`
- `profiles/opencode/opencode.json`
