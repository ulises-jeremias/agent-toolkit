# ADR-0003: Pack Semantics — Products Own Installation, Solution Packs Remain Docs-Only

**Status:** Accepted (2026-08-11) — clarifies ADR-006, unblocks #390

**Deciders:** toolkit maintainers

**Related:** ADR-006 (Packs docs-only), #390 (pack curation), #338, `docs/CONCEPTS.md` § Packs, `distributions/products.yaml`, `packs/README.md`

---

## Context

ADR-006 settled that `packs/<name>/` are **docs-only workflow templates** (README + config.yaml) not loaded by `agent-toolkit build`; `distributions/products.yaml` is the sole compiler input for `plugins/` (products → targets). `docs/CONCEPTS.md` now distinguishes three pack nouns: solution packs (repo, docs-only), workspace packs (`packs/*.yaml` in a harness workspace, `workspace load`), loop `--pack` overrides (`loop run --pack`).

Roadmap issue #390 then proposes `install --pack` and compiler-wired packs (`design-engineering`, `agentic-security`, `code-quality`, `architecture`) that would bundle skills for one-command install, contradicting ADR-006. #390 also asks: *What is a pack?* docs grouping vs installation preset vs capability bundle vs workspace overlay vs product composition, and *Product vs Pack vs Profile vs Workspace* responsibilities. Meanwhile `docs/PRODUCT_CURATION.md` already governs product membership (`core`/`forge`/`complete`/`agents`), and `agentic-workstation#200` expects thin workstation consumption via products, not packs.

Without a decision, contributors will either (a) silently wire packs into the compiler, creating a second composition layer, or (b) leave `install --pack` as dead docs, blocking workstation product selection.

## Options Considered

### Option A: Wire packs into compiler (REJECTED for now)

Make `packs/<name>/pack.yaml` validated against `schemas/pack.schema.json`, loaded by `agent-toolkit build`, emitted to `inventory` and `context-budget`, installable via `install --pack`.

**Pros:** One-command pack install.

**Cons:** Duplicates products as composition layer; every pack becomes a product variant; trust inheritance (pack max source risk) must be enforced; `products.yaml` vs `pack.yaml` confusion; requires compiler change (`loader.py` + `build.py` + adapter), `validate-packs.py`, migration for 3 existing packs; premature before community validates pack granularity.

### Option B: Keep solution packs docs-only, products own installation (SELECTED)

Reaffirm ADR-006: `packs/` remain **docs-only workflow templates**. Installation presets remain **products** (`distributions/products.yaml`) and future **presets** (planned `agent-toolkit.yaml` project-level, not Packs). The desired `install --pack design-engineering` is therefore `install --product` (or future `install --preset`) — not a pack compiler change. Packs document *which* products/skills/loops to combine for an outcome; products *ship* the composition.

**Pros:**
- No second composition layer; single authoritative `products.yaml` → `plugins/` pipeline.
- Preserves vendor-neutral trust: `plugins/` stays first-party-only; packs cannot silently auto-enable experimental shell skills.
- Low-ceremony: packs evolve as docs without blocking compiler; workstation can still compose products per team (see `agentic-workstation` `products` selection).
- Explicit noun separation: solution pack (docs), workspace pack (harness context), loop pack (runtime overrides), product (shipped plugin), profile (deprecated), preset (future project-level).

**Cons:**
- `install --pack` as written in #390 remains unavailable — teams copy pack README guidance or set `agent-toolkit.yaml` product list manually (acceptable; Wave 5 could add `pack install` as docs-only helper that writes `agent-toolkit.yaml`, not compiler).

### Option C: Rename and split (CONSIDERED, DEFERRED)

Introduce `presets/` for installation presets, keep `packs/` docs-only, deprecate `install --pack` terminology entirely.

**Pros:** Clear noun.

**Cons:** Churn for 3 existing packs, docs, and CLI help for limited gain now; can be revisited if community demands `preset` as distinct artifact.

## Decision

Adopt **Option B**. Reaffirm ADR-006 and extend with explicit responsibilities:

| Artifact | Location | Loaded by | Purpose | Trust |
|---|---|---|---|---|
| **Canonical content** | `skills/`, `agents/`, `loops/` | — | Source-of-truth definitions | Per-skill `origin`/`trust` |
| **Products** | `distributions/products.yaml` | `agent-toolkit build` → `plugins/` | Shipped marketplace plugins (core/forge/complete/agents) | Product inherits max member risk |
| **Solution Packs** | `packs/<name>/` | **Not loaded** (docs-only) | Workflow template for a team setup (README + config.yaml advisory) | Docs-only, no install |
| **Workspace Packs** | `packs/*.yaml` (harness workspace) | `workspace load` | Per-client context bundle | Local |
| **Loop Packs** | `packs/*.yaml` (workspace) | `loop run --pack` | Runtime loop override | Local |
| **Profiles** | `profiles/` | Deprecated fallback | Legacy install layouts | Deprecated |
| **Presets** | *(planned)* `agent-toolkit.yaml` | Future | Project-level product selection | Future |

- `install --pack` is **not** a compiler feature. To ship a pack's composition, promote its member skills to a product in `distributions/products.yaml` (see `docs/PRODUCT_CURATION.md` small-PR rule) or document the product list in the pack README. A future `pack install` helper may generate `agent-toolkit.yaml` from a pack's advisory `skills:` list, but it will not teach the compiler to ingest `packs/`.

- Pack trust: a pack's advisory `skills:` list inherits max source risk/permission of its members; a `reviewed` pack must not list `community`/`experimental` shell/network skills without explicit warning in the pack README.

## Consequences

- #390 will curate packs as **docs-only** (update `packs/<name>/README.md` + `config.yaml` advisory `skills:`/`agents:` + workflow narrative), not as `pack.yaml` compiler artifacts. Inventory/context-budget will continue to surface product membership; pack membership remains docs reference until a future `preset` ADR.

- `docs/CONCEPTS.md` table already correct; no schema change.

- Workstation #200 continues to consume `products` (not packs) for provisioning; no `install --pack` wiring in toolkit until a dedicated `presets` ADR.

## References

- `docs/adrs/ADR-006-packs-docs-only.md`, `docs/CONCEPTS.md` § Packs, `packs/README.md`, `distributions/products.yaml`, `docs/PRODUCT_CURATION.md`
- #390, #338, #396
