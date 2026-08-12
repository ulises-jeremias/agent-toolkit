# ADR-0004: Capability Provider Abstraction — WHAT vs HOW per Target

**Status:** Accepted (2026-08-12) — implements #386, pilots for #393/#368

**Deciders:** ulises-jeremias (owner) + toolkit maintainers

**Related:** #386 (provider abstraction), #393 (integration hardening), #368 (providers epic), #364 (trust tiers), #387 (inventory/doctor — deferred wiring), PR #410 (scaffold closed), PR #4xx (this)

---

## Context

Integrations are hard-wired to single backends (Linear via `mcp/registry/linear.yaml` → `mcp.linear.app/mcp`, Slack via `slack-cli`, Figma via `mcp.figma.com/mcp`). Capability intent and access mechanism are conflated — the registry records one provider per integration and skills hard-wire one `HOW`, so per-target strongest-backend selection is impossible and Workstation vs Toolkit cannot evolve independently.

Forces:

- **Per-target reality:** Official Linear MCP is OAuth + `streamable_http` (remote, no env) best for team workspaces; a PAT-based community MCP (`@ibraheem4/linear-mcp`, `stdio`) is better for solo/single-workspace; the GraphQL API (`https://api.linear.app/graphql`) is the only path for `deleteIssue` but is `admin` privilege. Slack chat automation prefers `mcp-server-slack` (Socket Mode, `stdio`, low latency) while app scaffolding prefers `slack-cli` (OAuth, admin, `Apache-2.0`). Figma read-only design context prefers `mcp.figma.com/mcp` (remote, `streamable_http`, OAuth) while writes require the Figma plugin API (local, needs approval). The stale heuristic `official plugin > official MCP > official CLI > community MCP > custom` is a starting point, not law.
- **WHAT stability vs HOW churn:** Verbs/entities (`list, get, create, update, comment` on `issue, project`) are stable across years; transports, auth, package names, and target coverage change quarterly. Mixing them forces churn in the same file.
- **Harness boundary:** Toolkit ships `skills/integrations/*.md` (portable) and `mcp/registry/*.yaml` (agent wiring). Pushing tool-specific backend paths into skills leaks harness concerns (ADR-0003: products own installation, packs docs-only).
- **Security separation:** Source trust (who vouches — `official` Linear vs `community` `@ibraheem4` vs `first-party` skill) and runtime privilege (what it can do — `read-only` Figma MCP vs `admin` Slack CLI) are orthogonal. Official source does NOT imply safe privilege; read-only community can be safer than admin official.

Without a decision, per-target selection must be hand-maintained in `compiler/target_registry.py` forks, and #393 cannot harden Jira/Confluence/Notion/Sentry against per-target divergence.

## Options Considered

### Option A: Universal backend ranking in code (REJECTED — the #386 Proposed Approach §4 heuristic)

Hard-wire `official plugin > official MCP > official CLI > community MCP > custom` and generate per-target backend by ranking.

**Pros:**
- Simple `max(rank)` selection.
- Appears conceptually clean.

**Cons:**
- Wrong in practice: Figma MCP (`read-only`) outranks Figma plugin API (`read-write` + approval) for read-only tasks; Slack `slack-cli` (`admin`) outranks `mcp-server-slack` for `slack create`. No single order satisfies all verbs.
- Hidden coupling: ranking policy lives in compiler, not declaration; adding a target requires code change.
- Encourages over-privilege (always pick highest-ranked, even if `admin`).

### Option B: Minimal WHAT vs HOW registry, per-capability contextual evaluation (SELECTED)

Separate:

```
CAPABILITY INTENT (WHAT)  — verbs[] + entities[] — stable, in providers/providers.yaml `what`
        ↓ per-target mapping
ACCESS MECHANISM (HOW[])  — {id, mechanism, targets[], package, repository, license, transport,
                              provenance, version_policy,
                              auth: {type, env[], scopes[]},
                              read[], write[], destructive[],
                              permissions: {source_trust, runtime_privilege, requires_approval},
                              runtime: {local_vs_remote, sandbox, latency, context_overhead, offline},
                              availability: {maintenance, cross_agent[], native_ux}}
        ↓ evaluation
CONTEXTUAL CHOICE — evaluation.notes records why no universal ranking; per-verb choice
                     (e.g., Linear OAuth MCP for team vs PAT MCP for solo vs API for delete)
        ↓ security reporting (distinct)
SOURCE TRUST vs RUNTIME PRIVILEGE — reported separately in `security` + `permissions` (reuses
                                     existing `scripts/audit-capability.py` + `mcp/registry/*.yaml`
                                     `security`/`approval` surfaces, no new framework)
```

Machine-readable registry at `providers/providers.yaml` validated by `schemas/provider.schema.json`; human-readable per-HOW evaluation at `docs/providers/provider-matrix.md` (dated 2026-08-12) with sources.

**Pros:**
- No universal law — selection is per-verb, per-target, per-privilege; evaluation notes make tradeoffs reviewable.
- Minimal genuinely-common fields surfaced as recurring after 3 pilots (Linear, Slack, Figma); other fields stay pilot-specific.
- Reuses existing trust/approval surfaces; `skill_fallback` keeps skills portable (delegate, don't wire backend paths).
- `inventory`/`build --check` wiring deferred to Phase 2 without blocking pilots (ADR-0001 provenance remains authoritative for supply-chain; provider is semantic routing).

**Cons:**
- Requires per-capability `evaluation.notes` maintenance; ranking not automated (acceptable — 3 pilots prove manual contextual choice scales to #393).

## Decision

Adopt **Option B**:

1. **Registry:** `providers/providers.yaml` (`version: 1`, `providers: {linear, slack, figma}`) with `what`, `how[]`, `evaluation`, `security` as above. Schema at `schemas/provider.schema.json` (requires `what.verbs`, `how[].id/mechanism/targets/provenance/read/write`, `permissions.source_trust/runtime_privilege`, `auth`, `runtime`, `availability`). Validation in tests via `jsonschema Draft202012Validator`; `ruff`/`pytest` gated.
2. **Pilots:** Linear (4 HOWs: official MCP `https://mcp.linear.app/mcp` OAuth, community MCP `@ibraheem4/linear-mcp` PAT, GraphQL API, `skills/integrations/linear` fallback), Slack (4: `mcp-server-slack` Socket, `slack-cli` `docs.slack.dev/tools/slack-cli` Apache-2.0, Web API, skill fallback), Figma (4: `mcp.figma.com/mcp` OAuth, REST `api.figma.com/v1`, plugin API, `skills/design/figma` fallback). Each evaluated on package/repository/license/transport/auth/read/write/destructive/permissions/runtime/availability/cross-agent/native UX.
3. **Matrix:** `docs/providers/provider-matrix.md` dated `2026-08-12` with Summary + per-HOW tables + distinct `Source trust vs Runtime privilege` section. Sources cited: Linear MCP (`mcp.linear.app/mcp`, `https://linear.app/docs/mcp`), Slack (`mcp-server-slack` + `docs.slack.dev/tools/slack-cli` + `docs.slack.dev/ai/mcp-server`), Figma (`mcp.figma.com/mcp`, `https://www.figma.com/developers/mcp`), plus `mcp/registry/*.yaml`.
4. **No law:** Must NOT encode `official plugin > MCP > CLI` as invariant; every doc asserts `No universal plugin > MCP > CLI ranking — contextual per-capability, per-target`.
5. **Security distinct:** Report `source_trust` and `runtime_privilege` separately; reuse `security`/`approval` from existing toolkit; never conflate highly-trusted source with safe privilege.
6. **Phase 2 deferred:** `agent-toolkit inventory` per-provider display and `build --check` per-target validation to follow #393 integration audits; current PR proves model, not compiler wiring.

## Consequences

- Positive: #386 acceptance criteria satisfied without compiler coupling; #393 can audit Jira/Confluence/Notion/Sentry with same WHAT/HOW template; Workstation products can select `what` without pinning `how`.
- Negative: `inventory`/`doctor` still single-backend until Phase 2; mitigated by matrix + registry as interim truth.
- Migration: New SaaS integrations add `providers/<id>.yaml` entry via same schema; no `mcp/registry/*.yaml` breakage — registry is additive.

## Alternatives Rejected Detail

See Option A above; also rejected extending `mcp/registry/*.yaml` in place (retains single-backend assumption) and making `caps/providers/*.yaml` per-tool (duplicates WHAT).
