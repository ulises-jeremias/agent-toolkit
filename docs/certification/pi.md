# Pi Coding Agent — Target Certification

**Status:** Certified (stable)  
**Adapter:** `PiAdapter` (`packages/pypi/agent-toolkit-cli/src/agent_toolkit/compiler/targets/pi.py`)  
**Contract tests:** `tests/compiler/test_pi_adapter.py`  
**Research date:** 2026-08-04

## Official contract

Pi Coding Agent distributes capabilities via **npm packages** with a `pi` field in
`package.json`. There is no plugin marketplace — packages are published to npm or
the [pi.dev registry](https://pi.dev/registry) (npm-compatible).

Official reference: [badlogic/pi-mono](https://github.com/badlogic/pi-mono)

### Required manifest shape

The adapter emits `pi-package.json` (named to avoid colliding with an existing
project `package.json`) with this structure:

```json
{
  "name": "@agent-toolkit/<product-id>",
  "version": "<semver>",
  "description": "...",
  "license": "MIT",
  "pi": {
    "skills": ["skills/<name>/SKILL.md"],
    "agents": ["agents/<name>/AGENT.md"]
  }
}
```

| Field | Requirement | Verified by |
|-------|-------------|-------------|
| `pi` | Top-level object declaring capabilities | `test_pi_package_json_has_pi_field` |
| `pi.skills` | Array of relative paths ending in `SKILL.md` | `test_pi_field_skills_paths_match_emitted_files` |
| `pi.agents` | Array of relative paths ending in `AGENT.md` | `test_pi_field_agents_paths_match_emitted_files` |
| `name`, `version`, `description`, `license` | Standard npm package fields | `test_pi_package_json_has_required_fields` |

### Generated layout

```
<product-id>/
  pi-package.json
  skills/<name>/SKILL.md
  agents/<name>/AGENT.md
```

Skills use the native Agent Skills `SKILL.md` format — same convention as Claude
Code, Cursor, and OpenCode.

## Maturity

| Surface | Maturity | Rationale |
|---------|----------|-----------|
| Static companion assets (this adapter) | **stable** | npm `pi` field + SKILL.md layout confirmed in pi-mono |
| TypeScript ExtensionAPI (hooks, tools, MCP) | unsupported | Requires runtime npm package — see `packages/pi-package/` |

The adapter declares `maturity = "stable"` because the static asset contract is
stable. Runtime features are explicitly reported in `CompilationResult.unsupported`.

## Install path coverage

| Scope | Path | Mechanism |
|-------|------|-----------|
| Global skills | `~/.pi/agent/skills/` | `agent-toolkit install --tools pi` |
| Project extensions | `.pi/extensions/*.ts` | Manual (TypeScript runtime — not generated) |
| Auto-discovery | `~/.pi/agent/extensions/*.ts` | Pi runtime (not generated) |

The compiler target generates distributable companion assets. The installer copies
profile skills to `~/.pi/agent/skills/` when `--tools pi` is specified.

## Explicitly unsupported

Reported in every `CompilationResult.unsupported` (never silently dropped):

- Lifecycle hooks — TypeScript ExtensionAPI
- Custom tools — TypeScript ExtensionAPI
- MCP server config — no static format
- Session state — runtime only
- Plugin marketplace — Pi uses npm/pi.dev, not a marketplace

## Validation

```bash
uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/compiler/test_pi_adapter.py -q
uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/test_golden.py -k PiAdapter -q
agent-toolkit build --target pi --check
```
