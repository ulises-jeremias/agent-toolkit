# ADR-0002: Design-Assessment as a Design Unit Delegated by Project-Assessment

**Status:** Accepted (2026-08-11) — decides #396, unblocks #373

**Deciders:** toolkit maintainers

**Related:** #396 (assessment architecture), #373 (design-assessment), #365 (design-engineering epic), `project-assessment` / `project-assessment-evidence` / `technical-unit-assessment`, PR #426 (scaffold closed)

---

## Context

Toolkit has a coherent evidence-based assessment family:

- `project-assessment` — router: scope → `project-assessment-evidence` → delegate to `technical-unit-assessment` / `management-unit-assessment` → score → findings. Uses 1–5 maturity scale, score 3 = defined/partially mature, confidence High/Medium/Low/Not assessed, `output-handshake` gate, `Not assessed` for missing evidence.

- `project-assessment-evidence` — interactive intake: asks where each source lives (boards, repos, docs, dashboards, interviews), builds evidence map with source link, owner, freshness, strength (Direct/Indirect/Interview-only/Stale/Missing), confidence, and never scores.

- `technical-unit-assessment` — scores a technical unit (frontend/backend/infra/data/mobile/AI) after evidence intake, indicator groups + default template, delegates deep UI to `figma`.

`design-assessment` (#373) would evaluate visual hierarchy, layout, spacing, typography, color, interaction, responsiveness, accessibility, design-system compliance, product appropriateness, distinctiveness with evidence/confidence/severity, WCAG 2.2 AA mapping. Risk: duplicate evidence/confidence/scoring framework and unclear swarm parallelism.

Swarm recipes `pair`/`team`/`full` and Herdr/tmux backends exist but have no mapping for where parallel assessment helps (a11y || visual || browser) vs sequential.

## Options Considered

### Option A: project-assessment delegates to design-assessment as a design unit (SELECTED)

`project-assessment` intakes evidence, then delegates to `design-assessment` alongside `technical-unit-assessment` / `management-unit-assessment` when UI/design is in scope. `design-assessment` is a **design-unit assessment** (parallel to technical/management units), not a second router.

**Pros:**
- No second scoring framework — reuses `project-assessment-evidence` intake, `technical-unit-assessment` confidence/scale semantics, `output-handshake` gate.
- Clear routing: `project-assessment` `→ design-assessment` when UI depth needed; standalone `design-assessment` also callable for single-page audits.
- Swarm mapping natural: `design-assessment` fans out to `a11y-reviewer` || `visual-reviewer` || `browser-perf-reviewer` || `design-system-reviewer` with shared evidence map as authority; sequential fallback valid.

**Cons:**
- `design-assessment` must not re-ask evidence already collected by router — needs intake reuse contract.

### Option B: design-assessment extends technical-unit-assessment design dimension (REJECTED)

Embed design as a dimension inside `technical-unit-assessment` indicator groups.

**Pros:** Single skill.

**Cons:** Bloats technical-unit scope (infra/data/mobile vs design are distinct audiences), forces design evidence (Figma, screenshots, WCAG reports) into generic technical intake, loses standalone UI audit use case.

### Option C: design-assessment standalone with own evidence intake (REJECTED)

Independent intake + scoring.

**Pros:** Isolated.

**Cons:** Duplicate evidence map, second confidence/scoring model, diverges from `project-assessment-evidence` freshness/quality rules, violates reuse principle.

## Decision

Adopt **Option A**.

- `design-assessment` is a **design unit** delegated by `project-assessment` when design is in scope; also directly invokable. It **reuses** `project-assessment-evidence` intake (source types include `design files, UX research, accessibility reports, performance reports, screenshots, recordings, product analytics` already listed) and **reuses** `technical-unit-assessment` scoring semantics (1–5 scale, score 3 = defined, confidence tiers, `Not assessed` for missing evidence, `output-handshake` before report). No new scoring framework.

- Evidence model (sources, freshness, quality Direct/Indirect/Stale/Missing, confidence) is single-source from `project-assessment-evidence` `references/default-template.md`. `design-assessment` frontmatter must declare `requires: [figma, playwright]`? No — `requires` is advisory; actual evidence locations are asked interactively per `project-assessment-evidence` pattern.

- Swarm parallelism mapping (advisory, sequential fallback always valid):
  ```
  design-assessment: a11y-reviewer || visual-reviewer || browser-perf-reviewer || design-system-reviewer (shared evidence map)
  MegaLinter-fix: python-findings || markdown-findings || terraform-findings || security-findings (per-language fixtures)
  project-assessment: frontend-unit || backend-unit || infra-unit || design-unit (per-unit)
  ```
  Model/cost routing: `vision-required` capability metadata where needed; otherwise `reasoning-heavy` vs `cheap-parallel` maps to existing swarm model profiles `economy/balanced/quality`.

## Consequences

- `design-assessment` SKILL.md will state delegation contract, reuse evidence map, and scoring rules without duplicating indicator definitions.
- `project-assessment` router docs will list `design-assessment` as design-unit delegate (alongside technical/management) and note swarm fan-out as optional.
- No schema change; no new top-level pack/product needed for assessment.

## References

- `skills/delivery/project-assessment/SKILL.md`, `project-assessment-evidence/SKILL.md`, `technical-unit-assessment/SKILL.md`
- #396, #373, #365
