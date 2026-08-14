# GitHub Copilot CLI and repository surface certification

**Issue:** [#89](https://github.com/ulises-jeremias/agent-toolkit/issues/89)  
**Target IDs:** `copilot-cli`, `copilot-repository`  
**Audited:** 2026-08-05 against [Copilot CLI plugin reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-plugin-reference) and [customizing Copilot](https://docs.github.com/en/copilot/customizing-copilot)

## Official contract (summary)

### Copilot CLI plugin (`copilot plugin install`)

| Surface | Official location | Format |
|---------|-------------------|--------|
| Manifest | **Root** `plugin.json` | Not `.copilot-plugin/` (unlike Claude/Cursor) |
| Skills | `skills/<name>/SKILL.md` | Agent Skills spec |
| Agents | `agents/<name>.agent.md` | `.agent.md` extension (not `AGENT.md`) |
| Hooks | `hooks.json` | Cross-platform Bash + PowerShell handlers |

### Repository customization (committed to project)

| Surface | Official location | Format |
|---------|-------------------|--------|
| Instructions | `.github/copilot-instructions.md` | Global repo instructions |
| Agents | `.github/agents/<name>.agent.md` | Agent personas |
| Skills | `.github/skills/<name>/SKILL.md` | On-demand skills |

## Current adapter behavior

| Surface | Adapter | Status |
|---------|---------|--------|
| CLI `plugin.json` | `CopilotCLIAdapter` | **Certified** — root-level manifest with `skills`/`agents` paths |
| CLI agents | `CopilotCLIAdapter` | **Certified** — `.agent.md` naming |
| CLI skills | `CopilotCLIAdapter` | **Certified** |
| Repo instructions | `CopilotRepositoryAdapter` | **Certified** |
| Repo agents/skills | `CopilotRepositoryAdapter` | **Certified** under `.github/` |
| Hooks | Both adapters | **Not implemented** — reported unsupported |
| MCP | Both adapters | **unknown-blocked** — not confirmed in official docs |

## Gaps (documented, not hidden)

1. Hooks require canonical hook model with Bash + PowerShell handlers (#16).
2. MCP support for Copilot CLI/repository surfaces is not confirmed from official documentation.
3. Profile install copies `copilot-instructions.md` to a user-specified project path only — not a global home-directory overwrite.

## Validation

```bash
v run make.vsh build-cli
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --target copilot-cli --check
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --target copilot-repository --check
uv sync --project packages/pypi/agent-toolkit-cli --all-extras
uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/compiler/test_copilot_adapter.py -q
```

## References

- `packages/pypi/agent-toolkit-cli/src/agent_toolkit/compiler/targets/copilot.py`
- `profiles/copilot/copilot-instructions.md`
- `docs/TARGETS.md`
