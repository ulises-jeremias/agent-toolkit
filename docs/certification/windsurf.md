# Windsurf / Devin Desktop — Target Certification

**Status:** Certified (stable)  
**Adapter:** `WindsurfAdapter` (`packages/pypi/agent-toolkit-cli/src/agent_toolkit/compiler/targets/windsurf.py`)  
**Contract tests:** `tests/compiler/test_windsurf_adapter.py`  
**ADR:** [ADR-002 — Windsurf Customization Bundle](../adrs/ADR-002-windsurf-bundle.md)  
**Research date:** 2026-08-04

## Official contract

Windsurf and Devin Desktop **do not have a plugin marketplace**. From official
documentation:

> "You cannot install extensions through any marketplace on Devin Desktop."

This adapter therefore generates a **customization bundle** — static project files
discovered automatically when a workspace is opened. It is **not** a plugin.

Official reference: [docs.windsurf.com](https://docs.windsurf.com)

### Package type

| Label | Value | Meaning |
|-------|-------|---------|
| `package_type` | `customization-bundle` | Project-scoped static files — **not** `plugin` |
| `maturity` | `stable` | Bundle layout confirmed; no marketplace to gate on |

Contract tests assert `package_type == "customization-bundle"` and
`package_type != "plugin"`.

### Generated layout

```
<product-id>/
  AGENTS.md              # directory-scoped instructions (auto-discovered)
  rules/<name>.mdc       # always-on behavioral constraints
  skills/<name>/SKILL.md # on-demand procedures
```

| Artifact | Semantic role (ADR-002) | Verified by |
|----------|------------------------|-------------|
| `AGENTS.md` | Project context + skill/agent index | `test_agents_md_generated` |
| `rules/*.mdc` | Behavioral constraints (`alwaysApply: true`) | `test_rules_mdc_generated`, `test_rules_have_frontmatter` |
| `skills/*/SKILL.md` | On-demand procedures | `test_skills_generated` |
| `memories/` | **NOT generated** — personal per-user state | `test_no_memories_generated` |
| `plugin.json` / `.windsurf-plugin/` | **NOT generated** — no marketplace | `test_no_plugin_manifest_generated` |

### Semantic contract (ADR-002)

```
Rules    = always-on behavioral constraints  → rules/<name>.mdc
Skills   = on-demand procedures              → skills/<name>/SKILL.md
Memories = personal user state               → deliberately excluded
```

Mixing these surfaces (e.g. emitting memories as distributable artifacts) would
violate the semantic contract and override individual user configurations.

## Install path coverage

| Scope | Path | Mechanism |
|-------|------|-----------|
| Global rules | `~/.codeium/windsurf/rules/` or `~/.windsurf/rules/` | `agent-toolkit install --tools windsurf` |
| Project bundle | `<repo>/AGENTS.md`, `rules/`, `skills/` | `agent-toolkit build --target windsurf` + commit |

Detection checks for `windsurf` binary or `~/.codeium/windsurf` / `~/.windsurf`
directories before offering windsurf in auto-detect.

## Explicitly unsupported

Reported in every `CompilationResult.unsupported`:

- Lifecycle hooks — no official Windsurf extension format
- MCP configuration — no official static MCP format (manual setup only)
- Memories — intentionally excluded (personal state)
- Plugin manifest — no marketplace exists

## Validation

```bash
uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/compiler/test_windsurf_adapter.py -q
uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/test_golden.py -k WindsurfAdapter -q
agent-toolkit build --target windsurf --check
```
