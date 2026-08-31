# ADR-029 — Surface-parity SSOT: cli-contract drives CLI, API, TUI and Web

- **Status:** Superseded by [ADR-030](ADR-030-capability-contract-binary-first.md) (2026-08-25)
- **Deciders:** maintainer
- **Related issues:** epic #830, #549 (contract), #472 (web), #473/#494 (tui)

> **Note:** ADR-030 retires the presentation-parity semantics below. The SSOT
> contract itself survives, re-scoped to capability description with
> programmatic-API parity only. Kept for historical context.

## Context

Goal: "CLI, Server, TUI, GUI can do everything". Hand-maintaining four surfaces guarantees drift. The repo already owns a machine-readable contract (`docs/compatibility/cli-contract.yaml`, #549) listing every command with flags, effects and tests.

## Decision

`cli-contract.yaml` is the **single source of truth** for all surfaces.

Codegen (`scripts/generate_surface.py`, Phase 0) emits:

| Artifact | Consumer |
|---|---|
| `docs/surface/openapi.json` | server router + web typed client |
| `docs/surface/cli-help.md` | help/completion wording |
| `modules/agent_toolkit_server/tui_registry.v` | TUI menus/actions |
| `docs/surface/web_nav.json` | GUI nav groups |

Rules encoded in codegen:
- route/method derived from command name + `effects.filesystem`
- `x-scope` derived from effect noun (ADR-028 policy)
- `x-confirm-required` for destructive set

**Parity gates**
1. `tests/test_surface_parity.py` — artifacts contain every contract command; scopes/confirm present.
2. `agent-toolkit serve selfcheck` — runtime route diff vs contract; Required CI after Phase 5.
3. TUI/Web compile against registries — missing action breaks build.

**Capability ≠ permission**: policy profiles decide *who* may call a scope; the capability always exists on every surface.

## Consequences

+ Adding a command once surfaces it everywhere automatically.
+ Docs/help/API cannot diverge.
− Contract YAML must stay accurate — mitigated by codegen failing on unknown fields and selfcheck.

## Validation plan

Covered by parity gates above; golden snapshot test of `openapi.json` to catch accidental schema changes.
