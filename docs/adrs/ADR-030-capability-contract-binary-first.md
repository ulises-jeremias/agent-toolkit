# ADR-030 — Capability contract over presentation parity (binary-first consolidation)

- **Status:** Accepted (2026-08-25)
- **Supersedes:** [ADR-029](ADR-029-surface-parity-ssot.md)
- **Related issues:** #830 (epic), #837 (TUI), #838 (Web SPA), #472/#473/#494

## Context

ADR-029 established `cli-contract.yaml` as the SSOT driving four surfaces — CLI,
API, TUI, Web — with the implicit goal that "every capability exists on every
surface". Shipping and maintaining four presentation surfaces with mandatory
functional parity made Agent Toolkit try to be a CLI product, a TUI product and
a Web-application product at the same time. The TUI (v1.20–v1.22) and the Web
dashboard SPA duplicated human workflows the CLI already owns, while the parts
that are genuinely differentiated — a reusable core, a first-class CLI and a
first-class programmatic API — were under-invested relative to their value.

## Decision

Agent Toolkit is a binary-first platform whose product is:

1. **Core** — reusable domain/runtime behavior (`agent_toolkit_core`). Business
   logic lives here and nowhere else; surfaces are adapters.
2. **CLI** — the primary *human* interface. Complete, scriptable, offline-first.
   It never becomes an HTTP client of the server (`CLI ─┬─ Core`, never
   `CLI → HTTP → Server → Core`).
3. **Serve** — the primary *programmatic/headless* interface
   (`agent-toolkit serve`): capability discovery, read/execution APIs, jobs,
   OpenAPI, selfcheck. It is a thin adapter over the same core.
4. **Capability contract** — `docs/compatibility/cli-contract.yaml` remains the
   single source of truth, but its semantics change from *presentation parity*
   to *capability description*: what exists, its inputs/outputs/side effects,
   scopes and confirmation requirements — not which buttons each UI must have.

Consequences of the semantic shift:

- **Capability ≠ presentation.** A capability can exist without a given UI
  exposing it. External clients (IDEs, dashboards, scripts, future GUI/TUIs)
  are *consumers* of Core/API and own their own presentation. They may expose
  subsets or compose capabilities freely.
- **Capability ≠ permission.** Scopes/policy (ADR-028) decide who may invoke;
  the capability model describes, policy restricts.
- Contract entries may declare `api: false` for human/CLI-only meta
  capabilities (`completion`, `serve`) that intentionally have no HTTP surface.
- Parity gates now enforce **capability ↔ programmatic-API** coherence:
  contract command ⇒ OpenAPI operation ⇒ registered server route, plus
  generated-artifact freshness. They no longer assert TUI/Web coverage.
- The **TUI is retired** as a supported surface: implementation removed in
  v1.23.0 (git history preserves it); `agent-toolkit tui` prints a removal
  notice pointing to the CLI and API. A future TUI would be an external
  consumer of Core/API, not repo-owned presentation.
- The **Web application is retired**: `web/index.html` is reduced to a minimal
  static server status page (health/version/links). No dashboard, no domain
  workflows, no frontend toolchain. `web_nav.json` generation removed.

## Generated artifacts (after this ADR)

| Artifact | Consumer |
|---|---|
| `docs/surface/openapi.json` | programmatic consumers; embedded by server |
| `docs/surface/cli-help.md` | docs/reference |

Removed: `tui_registry.v`, `web_nav.json`.

## Alternatives considered

- Keep TUI/Web with parity obligations — rejected: triples maintenance surface
  for presentation value the CLI already delivers.
- Extract TUI to a new repository now — rejected: no evidence of demand; git
  history suffices until a real consumer appears.
- Split Core into a separate library/binary — rejected: premature physical
  separation; the two-plane boundary is documented instead (#279 stays open).

## Consequences

+ Maintenance surface shrinks: one human UX (CLI) + one programmatic UX (API).
+ Contract semantics match reality: no more "missing UI action == missing
  capability" false alarms.
+ Server attack surface simplifies (no browser mutation workflows).
− `agent-toolkit tui` users must migrate to CLI/serve (documented removal).
− Web dashboard users must use the API directly or build a consumer.
