# OpenAI Codex — Target Certification

**Status:** Experimental (bounded support)  
**Adapter:** `CodexAdapter` (`packages/agent-toolkit-cli/src/agent_toolkit/compiler/targets/codex.py`)  
**Contract tests:** `tests/compiler/test_codex_adapter.py`  
**Research date:** 2026-08-04

## Strategy: keep experimental until contract stabilizes

The Codex plugin marketplace launched March 2026. As of the research date
(2026-08-04):

- Self-serve marketplace submission is **"coming soon"**
- The plugin API surface is still evolving
- Hooks and MCP are **unknown-blocked** (not confirmed in official docs)

**Do not change `maturity` to `stable`** until OpenAI publishes a stable plugin
contract and open marketplace submission.

## Official contract

Official references:

- [OpenAI Codex developers](https://developers.openai.com/codex)
- [Agent Skills spec](https://agentskills.io) — skills use native `SKILL.md`

### Manifest path

Codex uses a distinct manifest directory (not Claude Code or Cursor):

```
<product-id>/
  .codex-plugin/plugin.json   ← Codex-specific (NOT .claude-plugin/)
  skills/<name>/SKILL.md
  agents/<name>/AGENT.md
```

| Path | Must NOT exist | Verified by |
|------|----------------|-------------|
| `.codex-plugin/plugin.json` | — | `test_plugin_json_at_codex_path` |
| `.claude-plugin/plugin.json` | Yes | `test_plugin_json_not_at_claude_path` |
| `.cursor-plugin/plugin.json` | Yes | `test_plugin_json_not_at_cursor_path` |

### Maturity labeling

| Location | Required value | Verified by |
|----------|---------------|-------------|
| `CodexAdapter.maturity` | `"experimental"` | `test_adapter_maturity_is_experimental` |
| `plugin.json` → `maturity` | `"experimental"` | `test_maturity_is_experimental` |
| `CompilationResult.warnings` | mentions experimental | `test_experimental_warning_in_result` |

This dual labeling (adapter class + emitted manifest) prevents false stable claims
in both build metadata and distributable artifacts.

### Agent Skills alignment

Skills and agents follow the Agent Skills convention:

- Skills: `skills/<name>/SKILL.md` (on-demand procedures)
- Agents: `agents/<name>/AGENT.md` (personas)

Progressive disclosure `references/` subdirectories are copied alongside skills,
matching the pattern used by Claude Code and Cursor adapters.

## Safety constraints

Forbidden manifest fields (never emitted, validated at build time):

- `skipDangerousModePermissionPrompt`
- `autoAcceptPermissions`
- `disablePermissionPrompts`
- `allowUnsafeCode`

Private hostnames (`.local`, RFC1918 IPs) are rejected by `validate_plugin_json()`.

## Explicitly unsupported / unknown-blocked

| Capability | Status | Reported in |
|------------|--------|-------------|
| Lifecycle hooks | unknown-blocked | `result.unsupported` |
| MCP integration | unknown-blocked | `result.unsupported` |

## Marketplace warning

Generated artifacts **must not** be submitted to the Codex marketplace without
explicit authorization from OpenAI. Use this adapter for local development and
structure validation only until self-serve submission opens.

## Validation

```bash
uv run pytest tests/compiler/test_codex_adapter.py -q
uv run pytest tests/test_golden.py -k CodexAdapter -q
agent-toolkit build --target codex --check
```
