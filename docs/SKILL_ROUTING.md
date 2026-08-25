# Skill Routing

> Authority: `capabilities/skills/registry.yaml` (machine-readable, validated by `schemas/skill-capability-registry.schema.json`).
> Validate with `python3 scripts/validate-skill-capability.py --check` and `python3 scripts/generate-skill-routing.py --check`.
> Generated human-readable matrix: `docs/SKILL_ROUTING.md` — do not hand-edit counts; counts derive from the registry and `catalogs/skill-catalog.yaml`.

All 85 skills are owned. No orphans: every skill has exactly one `holistic_owner` (11 roles) and zero-or-more `secondary_owners` / `specialist_agents`. Specialists are opt-in; shared capabilities are the default.

## Holistic owner taxonomy (11 roles)

| Owner | Conceptual role | Typical specialist agent | Domains primary-owned |
|-------|-----------------|--------------------------|-----------------------|
| `assistant` | Orchestrator, session bootstrap, workspace | `assistant` | `core` (assistant, dev-companion, onboarding, output-handshake, pr-fallback, workspace, workspace-knowledge-sync) |
| `planner` | Delivery planning, roadmap, risk, breakdown | `planner` | `delivery` (planning, epic, work-item, project-assessment router, workflow-generic-project) |
| `architect` | System design, tradeoffs, C4, diagrams, ADRs/TRDs | `architect` | `architecture` (c4-model, architecture-diagram), `delivery` (adr, decision-log, trd, technical-unit-assessment), `cloud` |
| `designer` | Visual direction, UX, Figma, a11y, design system | `designer` (new) | `design` (10 skills), `accessibility` (review) |
| `implementer` | Code delivery, scaffolding, docs generation | — (shared) | `delivery` (task), `ops` (docs-generator) |
| `reviewer` | Quality, craft, anti-slop, change-safety | `code-reviewer`, `refactor-cleaner` | `quality` (blast-radius, deep-review, deslop, unslop) |
| `qa-engineer` | Lint gates, browser validation, test infra | `e2e-runner`, `code-reviewer` | `quality` (megalinter*), `tooling` (playwright-cli, chrome-devtools) |
| `security-engineer` | Hardening, threat, supply-chain, scanning | `agentic-security-reviewer`, `security-reviewer` | `agentic-security` (4), `quality` (codeql) |
| `platform-engineer` | Forge, integrations, loops, swarm, triage | `build-error-resolver`, `tech-assistant` | `forge` (7), `integrations` (5), `loops`, `ops` (swarm*, triage, llm-cost-advisor) |
| `data-engineer` | Data checks, notebooks | — | `data` (dbt-validation, snowflake-validation), `tooling` (jupyter-notebook) |
| `researcher` | Spike, evidence intake, inventory | `planner` (spike) | `delivery` (spike, project-assessment-evidence) |

See `capabilities/skills/registry.yaml` for the full per-skill `holistic_owner`, `secondary_owners`, `specialist_agents`, `specialist_justified`, `role`, and `context_cost`.

## Design domain — explicit routing (do not run mechanically)

Selection must remain **contextual**. The `designer` agent owns this decision; do not chain all design skills. Pick one primary driver per task.

| Scenario | Route to | Why this one |
|----------|----------|--------------|
| New visual direction / creative frontend (greenfield or intentional reshaping) | `design/frontend-design` | Creates distinctive palette, typography, layout, and a signature element grounded in the product subject. Takes one justifiable aesthetic risk. Not for auditing existing UI. |
| Existing frontend quality/design review (PR, component, flow, theme) | `design/frontend-design-review` | Procedural review against three pillars (Frictionless Insight-to-Action, Quality Craft, Trustworthy Building), design-system compliance, variants/states, and blocking/major/minor output. Not for backend/API. |
| Concrete web-interface best-practice audit (forms, focus, animation, WAI subset) | `design/web-design-guidelines` | Frozen WIG rulebook fetched from `vercel-labs/web-interface-guidelines`. Terse `file:line` findings. Use when the ask is "best-practice audit" not holistic UX diagnosis. |
| Evidence-based holistic UX/UI diagnosis (visual, UX friction, a11y, responsive, system compliance, distinctiveness, perf) | `design/design-assessment` | Delegated by `project-assessment` via single evidence framework (`project-assessment-evidence`). Vision-required, severity×confidence, Not-assessed-without-evidence. Reuse evidence map — do not re-ask. |
| Iterative browser-grounded remediation (implement → run → capture → re-review) | `design/design-improvement` | Consumes `design-assessment` or `frontend-design-review` findings, triages safe vs ambiguous changes, implements within existing design-system tokens, requires rendered evidence (screenshot via `playwright-cli`/`chrome-devtools`) before "good". Iterate until Blocking cleared. |
| Figma-driven work | `design/figma` → specialized Figma skill | `figma` is the entry router. Then: `figma-implement-design` (node → production code 1:1), `figma-code-connect-components` (Code Connect mappings, needs published components + Enterprise plan), `figma-create-design-system-rules` (author `AGENTS.md` rules from codebase patterns), `figma-create-new-file` (new blank file via `whoami`/`planKey`). For canvas writes (Plugin API) use the opt-in `figma-use` pack. |
| Accessibility-sensitive UI (needs WCAG 2.2 AA, SC mapping, mode-aware findings) | `accessibility/review` | Curated WCAG 2.2 AA gates with mode (automatically detectable / browser-assisted / manual-human-judgment), SC mapping, and fix code. Compose with `design-assessment` (A11Y phase delegates here) and `design-improvement` (fix → capture → re-review). Never claim full AA from automated checks alone. |

**Anti-pattern — do not mechanically chain:**

> ❌ `design-assessment` → `frontend-design-review` → `web-design-guidelines` → `frontend-design` → `design-improvement` on every ticket.

Mechanically running all five design skills on every task inflates context cost and duplicates evidence. The `designer` agent must **choose contextually**: typically one of (assessment **or** review **or** guidelines) plus at most one Figma skill and optionally `accessibility/review`. `design-improvement` only after an assessment exists.

### Figma routing subtree (under `design/figma`)

```
User intent: translate node → code        → figma-implement-design
           code-connect mapping           → figma-code-connect-components
           author reusable rules         → figma-create-design-system-rules
           new blank file/FigJam         → figma-create-new-file
           canvas Plugin API writes      → figma-use (opt-in pack, not this registry)
           full screen from code/desc    → figma-generate-design (opt-in pack)
```

## Full skill ownership snapshot (85 skills)

Generated from `capabilities/skills/registry.yaml`. Counts must match `catalogs/skill-catalog.yaml` and `skills/*/*/SKILL.md` on disk; CI fails on drift.

| Skill | Owner | Role | Cost | Specialist justified |
|-------|-------|------|------|-----------------------|
| `accessibility/review` | designer | review | medium | no |
| `agentic-security/mcp-audit` | security-engineer | validation | low | yes |
| `agentic-security/owasp-agentic-review` | security-engineer | review | medium | yes |
| `agentic-security/supply-chain-audit` | security-engineer | validation | low | yes |
| `agentic-security/threat-modeling` | security-engineer | research | medium | yes |
| `architecture/architecture-diagram` | architect | creation | medium | no |
| `architecture/c4-model` | architect | research | low | no |
| `cloud/aws-well-architected-review` | architect | review | medium | yes |
| `cloud/cloud-design-patterns` | architect | research | low | no |
| `core/assistant` | assistant | ops | low | no |
| `core/dev-companion` | assistant | ops | low | no |
| `core/onboarding` | assistant | ops | low | no |
| `core/output-handshake` | assistant | ops | low | no |
| `core/pr-fallback` | assistant | ops | low | no |
| `core/project` | platform-engineer | ops | low | no |
| `core/workspace` | assistant | ops | low | no |
| `core/workspace-knowledge-sync` | assistant | ops | low | no |
| `data/dbt-validation` | data-engineer | validation | medium | no |
| `data/snowflake-validation` | data-engineer | validation | medium | no |
| `delivery/adr` | architect | creation | low | no |
| `delivery/agreement` | planner | creation | low | no |
| `delivery/bug` | qa-engineer | creation | low | no |
| `delivery/decision-log` | architect | creation | low | no |
| `delivery/development-workflow` | planner | ops | low | no |
| `delivery/epic` | planner | creation | low | no |
| `delivery/incident` | platform-engineer | creation | medium | no |
| `delivery/management-unit-assessment` | planner | review | medium | no |
| `delivery/meeting-minutes` | planner | creation | low | no |
| `delivery/planning` | planner | research | low | yes |
| `delivery/prd` | planner | creation | medium | no |
| `delivery/project-assessment` | planner | research | medium | yes |
| `delivery/project-assessment-evidence` | researcher | research | low | no |
| `delivery/spike` | researcher | research | low | no |
| `delivery/task` | implementer | creation | low | no |
| `delivery/technical-unit-assessment` | architect | review | medium | yes |
| `delivery/trd` | architect | creation | medium | no |
| `delivery/user-story` | planner | creation | low | no |
| `delivery/work-item` | planner | creation | low | no |
| `delivery/workflow-client-bootstrap` | assistant | ops | low | no |
| `delivery/workflow-generic-project` | planner | ops | low | no |
| `design/design-assessment` | designer | review | high | yes |
| `design/design-improvement` | designer | creation | high | no |
| `design/figma` | designer | ops | medium | no |
| `design/figma-code-connect-components` | designer | ops | low | no |
| `design/figma-create-design-system-rules` | designer | creation | low | no |
| `design/figma-create-new-file` | designer | creation | low | no |
| `design/figma-implement-design` | designer | creation | high | no |
| `design/frontend-design` | designer | creation | high | no |
| `design/frontend-design-review` | designer | review | medium | yes |
| `design/web-design-guidelines` | designer | review | medium | no |
| `forge/fix-merge-conflicts` | platform-engineer | ops | low | no |
| `forge/gh-address-comments` | platform-engineer | ops | low | no |
| `forge/gh-contribution-planner` | platform-engineer | research | medium | no |
| `forge/gh-fix-ci` | platform-engineer | validation | medium | no |
| `forge/github-cli-workflow` | platform-engineer | ops | low | no |
| `forge/gitlab-cli-workflow` | platform-engineer | ops | low | no |
| `forge/worktree` | platform-engineer | ops | low | no |
| `integrations/clickup-cli` | platform-engineer | ops | low | no |
| `integrations/linear` | platform-engineer | ops | low | no |
| `integrations/mcp` | platform-engineer | ops | low | no |
| `integrations/slack-assistant` | platform-engineer | ops | low | no |
| `integrations/slack-cli` | platform-engineer | ops | low | no |
| `loops/loop-runner` | platform-engineer | ops | low | no |
| `ops/docs-generator` | implementer | creation | low | no |
| `ops/llm-cost-advisor` | platform-engineer | research | low | no |
| `ops/swarm` | platform-engineer | ops | medium | no |
| `ops/swarm-handoff` | platform-engineer | ops | low | no |
| `ops/swarm-observer` | platform-engineer | ops | low | no |
| `ops/triage` | platform-engineer | ops | low | no |
| `quality/blast-radius` | reviewer | research | medium | yes |
| `quality/codeql` | security-engineer | validation | medium | no |
| `quality/deep-review` | reviewer | review | high | yes |
| `quality/deslop` | reviewer | review | low | no |
| `quality/megalinter` | qa-engineer | ops | medium | no |
| `quality/megalinter-check` | qa-engineer | validation | medium | no |
| `quality/megalinter-fix` | qa-engineer | validation | medium | no |
| `quality/megalinter-setup` | qa-engineer | ops | low | no |
| `quality/unslop` | reviewer | review | low | no |
| `tooling/chrome-devtools` | qa-engineer | validation | medium | no |
| `tooling/cli-for-agents` | platform-engineer | review | low | no |
| `tooling/herdr` | platform-engineer | ops | low | no |
| `tooling/inventory` | assistant | research | low | no |
| `tooling/jupyter-notebook` | data-engineer | creation | low | no |
| `tooling/mermaid` | architect | creation | low | no |
| `tooling/playwright-cli` | qa-engineer | validation | medium | no |

**Validation:** `python3 scripts/validate-skill-capability.py` checks that every `skills/*/*/SKILL.md` on disk appears in the registry with matching `count`, `domain`, `origin`, and that every registry entry has a non-empty `holistic_owner` (no orphans), required `triggers`, `overlap`/`complementary`/`prerequisites`/`follow_ups` arrays, and that upstream skills carry `upstream` metadata. It also cross-checks `docs/SKILL_ROUTING.md` routing table coverage and `agents/designer` existence.

## Relationship to other docs

| Doc | Purpose | Generated? |
|-----|---------|------------|
| `capabilities/skills/registry.yaml` | Machine-readable SoT for ownership, routing, triggers, costs, specialists | Hand-curated, schema-validated |
| `docs/SKILL_ROUTING.md` (this file) | Human-readable routing + ownership snapshot + design routing contract | Hand-maintained snapshot, CI checks counts |
| `docs/SKILL_PRODUCT_MATRIX.md` | Which product ships which skill (from `distributions/products.yaml`) | Generated by `scripts/generate-skill-matrix.vsh` |
| `docs/TARGET_CAPABILITY_MATRIX.md` | Which target supports which harness capability | Generated by `scripts/generate-target-matrix.py` |
| `catalogs/skill-catalog.yaml` | Skill ids, descriptions, stability (from `SKILL.md`) | Generated by `scripts/generate-catalogs.vsh` |
| `skills/core/assistant/references/ORCHESTRATION.md` | Orchestrator domain → skill routing (hand-edited) | Hand-edited, complements this doc |
| `agents/designer/AGENT.md` | Designer agent that encodes design routing contextual selection | Hand-edited, validated by `scripts/validate-agents.vsh` |

## How to route (for agents and humans)

1. Start at `core/assistant` (orchestrator) → read `ORCHESTRATION.md` + this doc + `tooling/inventory` if needed.
2. For design work, delegate to `designer` agent — it owns the contextual choice among `frontend-design` vs `frontend-design-review` vs `web-design-guidelines` vs `design-assessment` vs `design-improvement` vs Figma family vs `accessibility/review`.
3. Never select by keyword alone — confirm triggers against the registry and check `contraindications` and `overlap` notes to avoid mechanical chaining.
4. After routing, follow the target skill's `SKILL.md` (phases, gates, `output-handshake`) and record evidence per `project-assessment-evidence`.

## See also

- `capabilities/skills/registry.yaml` — SoT (validated by `schemas/skill-capability-registry.schema.json`)
- `schemas/skill-capability-registry.schema.json` — JSON schema (11 holistic owners, 5 roles, upstream gate)
- `agents/designer/AGENT.md` — Designer agent with design routing logic and five-scenario tests
- `skills/core/assistant/references/ORCHESTRATION.md` — Orchestrator routing table (design section mirrors this doc)
- `scripts/validate-skill-capability.py` — CI drift/orphan checker (`--check`)
- `tests/test_skill_capability_registry.py` — pytest coverage for 85 skills, no orphans, design routing
