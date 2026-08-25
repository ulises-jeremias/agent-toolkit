# Agent Taxonomy — Canonical Holistic Roster

> Authority: `capabilities/skills/registry.yaml` (`schemas/skill-capability-registry.schema.json` — 11 `holistic_owner` values, 85 skills, no orphans) + `docs/SKILL_ROUTING.md` + `skills/core/assistant/references/ORCHESTRATION.md`.
> Validate with `python3 scripts/validate-skill-capability.py --check`, `./scripts/validate-agents.vsh`, `./scripts/generate-catalogs.vsh --check`.

This document is the **final canonical holistic roster** for #864. It classifies all 18 agents present at `main@561595b` + `designer` (#863) and documents the daily holistic set humans should remember. **Optimize for cognitive simplicity, role clarity, useful context isolation, and independent verification — not fewest agents, not one-per-skill** (see #864 / mission brief).

---

## 1. Holistic roster (11 roles) — daily set

The 11 roles below are the **only holistic owners** in the skill registry. Every skill has exactly one `holistic_owner` from this set. Holistic agents are long-lived, own contextual routing among related skills, and delegate to `SKILL.md` workflows — they do not inline HOW procedures.

| # | Holistic agent | Persona dir | Tier | Responsibility (one sentence) | Skill domains primary-owned | Key skills (examples) | Collaborators (hand off when) | Validation |
|---|---------------|-------------|------|-------------------------------|----------------------------|-----------------------|-------------------------------|------------|
| 1 | **assistant** | `agents/assistant` | **Orchestrator** | Session bootstrap, intent → context → delegation → synthesis; conflict resolution across toolkit vs project overlay | `core` (assistant, dev-companion, onboarding, output-handshake, pr-fallback, workspace, workspace-knowledge-sync) + discovery | `core/assistant`, `core/dev-companion`, `core/output-handshake`, `tooling/inventory`, `delivery/workflow-client-bootstrap` | Everyone — routes to 10 holistic roles per `ORCHESTRATION.md` | Repo inspection order (README→docs→AGENTS→CONTRIBUTING→CI→configs); cites `file:line` sources; delegates HOW to specialist skills |
| 2 | **planner** | `agents/planner` | Holistic | Decomposition, PRD/TRD framing, work items, estimation, risk & capacity — before any code | `delivery` (11: planning, epic, work-item, prd, agreement, development-workflow, workflow-generic-project, project-assessment router, management-unit-assessment) | `delivery/planning`, `delivery/prd`, `delivery/work-item`, `delivery/project-assessment` | `architect` (C4/TRD), `researcher` (spike/evidence), `reviewer` (`blast-radius`) | Tasks S/M/L, DoD, ordered commits, blast-radius for risky steps |
| 3 | **architect** | `agents/architect` | Holistic | System design, tradeoffs, C4, diagrams, ADRs/TRDs, cloud patterns, blast-radius collaboration | `architecture` (2) + `cloud` (2) + `delivery` (adr, decision-log, trd, technical-unit-assessment) + `tooling/mermaid` | `architecture/c4-model`, `architecture/architecture-diagram`, `delivery/adr`, `delivery/trd`, `cloud/cloud-design-patterns`, `delivery/technical-unit-assessment` | `security-engineer` (threat model), `reviewer` (blast-radius), `platform-engineer` (infra) | Options 2–3 with tradeoffs, risks, next steps; ADRs per cross-team decisions |
| 4 | **designer** | `agents/designer` | Holistic | Visual direction, UX, Figma, design system, accessibility — **contextual routing** among 11 design-adjacent skills | `design` (10) + `accessibility/review` | `design/frontend-design`, `design/frontend-design-review`, `design/web-design-guidelines`, `design/design-assessment`, `design/design-improvement`, `design/figma*` (4), `accessibility/review` | `implementer` (implements direction), `qa-engineer` (browser evidence), `researcher` (evidence map) | Five-scenario self-test (must pass), rendered screenshot before "good", reuse `project-assessment-evidence` map |
| 5 | **implementer** | `agents/implementer` | Holistic | Feature/bug/refactoring delivery, build/test loop, task scaffolding, docs generation — behavior-preserving commits | `delivery/task` + `ops/docs-generator` | `delivery/task`, `ops/docs-generator` | `planner` (receives task), `reviewer` (craft), `qa-engineer` (verification), `security-engineer` (auth handling), `platform-engineer` (CI), `data-engineer` (data checks) | Red-green-refactor, commands run + outcome, tests before/after refactor |
| 6 | **reviewer** | `agents/reviewer` | Holistic | **Independent** quality/craft, change-safety, anti-slop (code + prose) — the verification boundary distinct from implementation | `quality` (blast-radius, deep-review, deslop, unslop) | `quality/blast-radius`, `quality/deep-review`, `quality/deslop`, `quality/unslop` | `implementer` (reviews build), `qa-engineer` (behavioral proof), `security-engineer` (vuln handoff), `architect` (design handoff) | `file:line` severity-ranked, fix snippets, never self-approves own implementation |
| 7 | **qa-engineer** | `agents/qa-engineer` | Holistic | Behavioral verification, lint gates, browser automation, E2E strategy, bug triage/incident decision | `quality/megalinter*` (4) + `tooling/playwright-cli`, `tooling/chrome-devtools` + `delivery/bug` | `quality/megalinter-check`, `tooling/playwright-cli`, `tooling/chrome-devtools`, `delivery/bug` | `implementer` (verifies output), `reviewer` (craft), `security-engineer` (SARIF), `platform-engineer` (CI) | Gates exit 0, screenshots/traces, `getByRole`-first, no `waitForTimeout()` |
| 8 | **security-engineer** | `agents/security-engineer` | Holistic | App + agentic hardening, threat modeling, supply-chain/MCP audit, CodeQL/SARIF — OWASP-mapped, severity-ranked | `agentic-security/*` (4) + `quality/codeql` | `agentic-security/threat-modeling`, `agentic-security/mcp-audit`, `agentic-security/supply-chain-audit`, `agentic-security/owasp-agentic-review`, `quality/codeql` | `architect` (threat-model), `reviewer` (craft handoff), `platform-engineer` (MCP runtime), `qa-engineer` (SARIF gate) | `file:line` + OWASP ID + CVE + impact×likelihood + mitigation + residual risk; static audit only |
| 9 | **platform-engineer** | `agents/platform-engineer` | Holistic | CI/CD, GitHub/GitLab PR lifecycle, merge conflicts, worktrees, integrations, loops/swarm, triage, LLM cost, CLI ergonomics | `forge/*` (7) + `integrations/*` (5) + `loops/loop-runner` + `ops/swarm*` + `ops/triage`, `ops/llm-cost-advisor` + `tooling/cli-for-agents`, `tooling/herdr` + `core/project`, `delivery/incident` (22 total) | `forge/gh-fix-ci`, `forge/github-cli-workflow`, `integrations/mcp`, `ops/swarm`, `ops/triage`, `tooling/cli-for-agents` | `implementer` (unblocks delivery), `qa-engineer` (gates), `security-engineer` (MCP surface), `architect` (infra patterns) | `gh`/`glab`/`swarm` invocations + summarized outcome, `${ENV_VAR}` secrets, allowlist/deny + human gates |
| 10 | **researcher** | `agents/researcher` | Holistic | Spike findings, single evidence-intake framework, framework/docs exploration, inventory — evidence before synthesis | `delivery/spike`, `delivery/project-assessment-evidence` | `delivery/spike`, `delivery/project-assessment-evidence` (feeds planner/architect/designer assessments) | `planner` (feeds breakdown), `architect` (feeds C4/TRD), `designer` (feeds design-assessment), `data-engineer` (data evidence) | Evidence map (source/location/freshness/confidence), `Not assessed` without evidence, time-boxed |
| 11 | **data-engineer** | `agents/data-engineer` | Holistic (conditional, justified) | dbt/Snowflake read-only validation per repo docs, notebook scaffolding — **justified**: 3 skills share distinct CLIs (`dbt`/`snow`/templates), credentials, warehouse safety, and "no mutation without approval" constraints other roles do not share; non-data repos never invoke | `data/*` (2) + `tooling/jupyter-notebook` | `data/dbt-validation`, `data/snowflake-validation`, `tooling/jupyter-notebook` | `architect` (data modeling/assessment), `qa-engineer` (gates), `reviewer` (craft), `platform-engineer` (CI), `researcher` (data evidence) | Repo-documented commands only (`make parse` > `dbt parse`), read-only unless explicitly approved, `Not assessed` when creds missing |

**Why `data-engineer` stays:** alternative ("fold under architect/qa-engineer") would overload those roles with warehouse credentials, `dbt_project.yml`/`models/` semantics, and mutation-safety distinct from app verification. Three skills plus notebook scaffolding justify isolation; repos without a data stack simply never route to this role. See `capabilities/skills/registry.yaml` `holistic_owner: data-engineer` and `tooling/jupyter-notebook` + `data/*` boundary notes.

**Why 11, not fewer or more:** fewer loses independent verification boundaries (review ≠ QA ≠ security, craft ≠ design); more (one-per-skill/language) explodes taxonomy. Eleven maps to skill registry owners exactly — the single source of truth.

---

## 2. Agent tiering — orchestrator / holistic / specialist

| Tier | Meaning | Members | Invocation | Context isolation |
|------|---------|---------|------------|-------------------|
| **Orchestrator** | Default entry; meta-generator; routes to holistic roles | `assistant` (default), `client-workflow-bootstrap` (meta-generator) | `@assistant` (implicit) + natural triggers; `@client-workflow-bootstrap` for onboarding packs | Broad: repo discovery + `ORCHESTRATION.md` + registry |
| **Holistic** | Owns contextual routing among a coherent skill group; delegates to `SKILL.md` workflows; collaborators via handoff | 11 above | `@planner`, `@architect`, `@designer`, `@implementer`, `@reviewer`, `@qa-engineer`, `@security-engineer`, `@platform-engineer`, `@researcher`, `@data-engineer` (+ `@assistant` doubles as orchestrator) | Focused: domain skills + evidence map; cross-domain via explicit delegate |
| **Specialist** | Opt-in narrow expertises that justify dedicated prompting (high-severity review, typed analysis, E2E craft, etc.) | Legacy agents below that remain as specialist personas (see §3) | `@code-reviewer`, `@security-reviewer`, `@agentic-security-reviewer`, `@typescript-reviewer`, `@database-reviewer`, `@performance-optimizer`, `@e2e-runner`, `@tdd-guide`, `@refactor-cleaner`, `@build-error-resolver`, `@tech-assistant`, plus merged docs patterns | Very narrow: single checklist/technique; invoked by a holistic owner when `specialist_justified: true` in registry |

**Rule:** specialists are **opt-in**; shared capabilities are the default (§ "Specialist agents" in `capabilities/skills/registry.yaml` — `specialist_justified: true` only for high-severity/review/research skills). Never delete prompt knowledge — move it (see §3).

---

## 3. Migration map — every previous agent, where it goes

All 18 personas present at `main@561595b` + `designer` (#863) have a classified destination. Deferred specialist details (prompt refactors, `HOW_TO_ADD_AGENT` format updates) belong to **#865**; this taxonomy decides direction now.

| # | Previous agent (`agents/<id>`) | Decision | Rationale | Where prompt knowledge moves | Registry link |
|---|--------------------------------|----------|-----------|------------------------------|---------------|
| 1 | `agentic-security-reviewer` | **KEEP AS SPECIALIST** | Agentic threat surface (prompt injection, tool poisoning, excessive agency, MCP/supply-chain) requires narrow checklist backed by `agentic-security/*` skills. Holistic owner `security-engineer` delegates when `specialist_justified: true`. Never delete knowledge — preserve OWASP LLM01-10 + AGNT01-06 checklist. | `agents/agentic-security-reviewer/AGENT.md` retained; `security-engineer` delegates via `specialist_agents: [agentic-security-reviewer]` on `mcp-audit`, `supply-chain-audit`, `owasp-agentic-review`, `threat-modeling` | `capabilities/skills/registry.yaml` `holistic_owner: security-engineer` + `specialist_agents: [agentic-security-reviewer]` |
| 2 | `architect` | **KEEP AS HOLISTIC** | System design/C4/cloud/delivery ADR-TRD are a coherent daily role distinct from planning, reviewing, and platform. Nine skills justify isolation. | `agents/architect/AGENT.md` — expanded with holistic ownership table and collaborators (§4) | `holistic_owner: architect` (9 skills) |
| 3 | `assistant` | **KEEP AS ORCHESTRATOR** | Default entry; repo discovery; conflict resolution; delegates to 10 holistic roles per `ORCHESTRATION.md`. Not a domain specialist. | `agents/assistant/AGENT.md` — updated delegation map to new 11 roles | `core/*` + `tooling/inventory` under `assistant` |
| 4 | `build-error-resolver` | **KEEP AS SPECIALIST** → deferred to #865 | Build/type/lint/CI error root-cause specialist. Holistic `platform-engineer` owns `gh-fix-ci` platform flow and delegates error-specific knowledge. Keep prompt knowledge under specialist so platform swarms can invoke narrowly. | `agents/build-error-resolver/AGENT.md` retained; `platform-engineer` delegates via `forge/gh-fix-ci` `specialist_agents: [build-error-resolver]` + `tooling/cli-for-agents` | `holistic_owner: platform-engineer` (22 skills) |
| 5 | `client-workflow-bootstrap` | **KEEP AS ORCHESTRATOR** (meta-generator) | Onboards client delivery context into `~/.ai-workspace` packs/knowledge — not a daily delivery role. Meta-generates a `<client>-workflow` + `<client>-dev-companion` skill pair. Distinct from `planner`/`assistant`. | `agents/client-workflow-bootstrap/AGENT.md` retained as orchestrator; skill `delivery/workflow-client-bootstrap` already owned by `assistant` | `holistic_owner: assistant` — orchestrator tier, not holistic daily |
| 6 | `code-reviewer` | **KEEP AS SPECIALIST** (backs `reviewer` + `qa-engineer` + `architect`) | Quality/maintainability craft is now holistic `reviewer`; `code-reviewer` is the narrow persona that `reviewer`/`qa-engineer`/`designer` invoke for deep craft when `specialist_justified: true`. Preserve delegation table (`blast-radius`, `unslop`, `deslop`, `megalinter-check`, `deep-review`). | `agents/code-reviewer/AGENT.md` retained; `reviewer` delegates via `quality/blast-radius`, `quality/deep-review`, etc. `specialist_agents: [code-reviewer]` | `holistic_owner: reviewer` (4) + `qa-engineer`/`designer`/... `specialist_agents: [code-reviewer]` |
| 7 | `database-reviewer` | **KEEP AS SPECIALIST** → deferred to #865 | Postgres/schema/query/migration expertise. No broad holistic data-review skill set — best modeled as specialist under `reviewer`/`architect` (craft + deep-review + `technical-unit-assessment`) until data-depth justifies promotion. Knowledge preserved; routing to `architect`/`reviewer` for now. | `agents/database-reviewer/AGENT.md` retained; future #865 decides CONVERT-TO-SKILL vs keep | No dedicated `holistic_owner`; `data-engineer` is pipeline validation, not schema review |
| 8 | `designer` | **KEEP AS HOLISTIC** (new in #863) | Eleven design-adjacent skills would fragment if split — single contextual router is essential (five-scenario test). Do not replace with specialists. | `agents/designer/AGENT.md` — canonical design routing (§5) | `holistic_owner: designer` (11) |
| 9 | `docs-lookup` | **MERGE INTO HOLISTIC (`researcher`)** → deferred shape to #865 | Documentation/API research is re-owned by `researcher` (`spike` + `project-assessment-evidence`). Do not keep as standalone persona — framework lookup is a research sub-skill, and docs discovery is evidence intake. Prompt knowledge (local docs → codebase → synthesis with source refs) merges into `researcher`. Keep file only until #865 removes alias — do not delete silently. | Knowledge → `agents/researcher/AGENT.md`; skill routing stays via `delivery/spike` + `project-assessment-evidence` | `holistic_owner: researcher` / `implementer` routing |
| 10 | `e2e-runner` | **KEEP AS SPECIALIST** (backs `qa-engineer`) | Playwright E2E authoring craft (selector priority, POM, flake avoidance). Holistic `qa-engineer` owns gates (`playwright-cli`, `chrome-devtools`) and delegates deep authoring. | `agents/e2e-runner/AGENT.md` retained; `qa-engineer` via `tooling/playwright-cli` + `tooling/chrome-devtools` `specialist_agents: [e2e-runner]` | `holistic_owner: qa-engineer` (7) |
| 11 | `performance-optimizer` | **KEEP AS SPECIALIST** → deferred to #865 | Profiling/bottleneck analysis across frontend/backend/db/algorithm. Cross-cutting — backs `reviewer`/`architect` via `deep-review` + `technical-unit-assessment`. Preserve metric→bottleneck→fix→verify loop; defer CONVERT-TO-SKILL decision to #865. | `agents/performance-optimizer/AGENT.md` retained | Consumer will be `architect`/`reviewer` deep paths |
| 12 | `planner` | **KEEP AS HOLISTIC** | Delivery decomposition/estimation/capacity is daily work distinct from architecture, implementation, and verification. Eleven planning/delivery skills justify isolation. | `agents/planner/AGENT.md` — expanded with owner table | `holistic_owner: planner` (11) |
| 13 | `refactor-cleaner` | **KEEP AS SPECIALIST** (backs `reviewer`) | Dead-code/duplication/simplification without behavior change — narrow technique invoked by `reviewer` via `quality/deslop`. Holistic `implementer` owns behavior-preserving delivery; `reviewer` owns craft verification. | `agents/refactor-cleaner/AGENT.md` retained; `reviewer` via `quality/deslop` `specialist_agents: [refactor-cleaner]` | `holistic_owner: reviewer` |
| 14 | `reference-lookup` | **MERGE INTO HOLISTIC (`researcher`)** → deferred shape to #865 | Toolkit public-examples pattern search is a docs/research sub-skill. Merge into `researcher` alongside `docs-lookup` — single evidence intake + pattern synthesis. Preserve API-fetch → summarize → adapt flow in researcher. | Knowledge → `agents/researcher/AGENT.md`; remove standalone persona in #865 after knowledge move verified | `delivery/spike` evidence phase |
| 15 | `security-reviewer` | **KEEP AS SPECIALIST** (backs `security-engineer`) | App-code vuln audit (OWASP Web: SQLi/XSS/IDOR, auth, data exposure). Complements `agentic-security-reviewer` under holistic `security-engineer`. Preserve OWASP Top 10 checklist + severity rubric. | `agents/security-reviewer/AGENT.md` retained; `security-engineer` via `agentic-security/owasp-agentic-review`, `quality/codeql` `specialist_agents: [security-reviewer]` | `holistic_owner: security-engineer` (5) |
| 16 | `tdd-guide` | **KEEP AS SPECIALIST** (backs `implementer`) | TDD red-green-refactor cycle is a technique, not a daily holistic role. Holistic `implementer` owns delivery and delegates TDD when task warrants. Preserve AAA pattern + test design principles in specialist. | `agents/tdd-guide/AGENT.md` retained; `implementer` via `delivery/task` + `delivery/development-workflow` | `holistic_owner: implementer` shared capability |
| 17 | `tech-assistant` | **KEEP AS SPECIALIST** (backs `platform-engineer`) | Workstation/infra procedural specialist. Holistic `platform-engineer` owns triage/loops/swarm/platform; delegates tech-ops detail. Prior content minimal — expand in #865 or merge, but classify now as specialist. | `agents/tech-assistant/AGENT.md` retained; `platform-engineer` via `ops/triage` `specialist_agents: [tech-assistant]` (+ `tooling/inventory`) | `holistic_owner: platform-engineer` (22) |
| 18 | `typescript-reviewer` | **KEEP AS SPECIALIST** → deferred to #865 | Type safety/TS patterns specialist. Language-specific — not a holistic role. Backs `reviewer` via `deep-review`/`deslop` when stack is TS. Preserve strict/utility-types/generic constraints guidance. | `agents/typescript-reviewer/AGENT.md` retained; future #865 decides CONVERT-TO-SKILL shape | Consumer: `reviewer` + `qa-engineer` TS paths |

**No obsolete deletions in this taxonomy pass.** Every file stays on disk through #865 where specialist→skill conversion is evaluated with evidence (never silently delete prompt knowledge — move it). Counts post-#864: `18` (main) + `designer` (1 from #863) already on this branch = `18` prior + `7` new holistic (`implementer`, `reviewer`, `qa-engineer`, `security-engineer`, `platform-engineer`, `researcher`, `data-engineer`) = **25 personas**. Specialist review in #865 may reduce further only after knowledge moves verified.

---

## 4. Holistic agent sheets — responsibility, skill domains, delegates, collaborators, validation

### assistant — orchestrator

- **Responsibility:** Session bootstrap, repo discovery, intent classification, proportional delegation to one holistic agent (or orchestrated pair) and synthesis.
- **Skill domains:** `core` orchestration + discovery (`core/assistant`, `core/dev-companion`, `core/workspace`, `tooling/inventory`, `core/output-handshake`, `core/onboarding`). Output gate before any artifact.
- **Delegates:** Routes per `skills/core/assistant/references/ORCHESTRATION.md` and this doc §5. Always picks one workflow driver (e.g. `dev-companion` + `workflow-generic-project` for generic delivery) and uses HOW skills for CLI ops — never inlines procedures.
- **Collaborators:** All 10 holistic roles + `client-workflow-bootstrap` meta-generator. Escalates cross-cutting tradeoffs with `planner`/`architect` + human gate.
- **Validation:** Cites `file:line` sources (AGENTS.md, README, CI), checks `catalogs/*`, runs `./scripts/validate-*.vsh` / `build --check` where feasible.

### planner

- **Responsibility:** Break complex work into ordered, independently committable tasks with AC, sizing, risks, and capacity before code.
- **Domains:** `delivery` planning/delivery (11).
- **Delegates:** `delivery/planning` + `delivery/project-assessment` router + `delivery/work-item` hierarchy + `quality/blast-radius` for risk assessment.
- **Collaborators:** `architect` (C4/TRD/ADR), `researcher` (spike/evidence), `implementer` (hands off task), `reviewer` (blast-radius collaboration).
- **Validation:** S/M/L/XL sizing, DoD, open questions, rollback strategy.

### architect

- **Responsibility:** System design, pattern selection, C4 levels, cloud design/WAR, TRD/ADR — explicit tradeoffs, not cleverness.
- **Domains:** `architecture` + `cloud` + `delivery` ADR/TRD/decision-log/technical-assessment + `tooling/mermaid`.
- **Delegates:** `architecture/c4-model`, `architecture/architecture-diagram`, `cloud/cloud-design-patterns`, `cloud/aws-well-architected-review`, `delivery/adr`, `delivery/trd`, `tooling/mermaid`, `quality/blast-radius`.
- **Collaborators:** `security-engineer` (STRIDE), `platform-engineer` (infra/runtime), `planner` (epic/TRD), `reviewer` (change-safety).
- **Validation:** 2–3 options, recommendation, risks, next steps; simple over clever.

### designer

- **Responsibility (§5):** Contextual selection among 11 design-adjacent skills — never mechanically chain all five design skills on one ticket.
- **Domains:** `design` (10) + `accessibility/review`.
- **Delegates:** Exactly one primary per task among `frontend-design` vs `frontend-design-review` vs `web-design-guidelines` vs `design-assessment` vs `design-improvement` vs `figma*` vs `accessibility/review`.
- **Collaborators:** `implementer` (`figma-implement-design`), `qa-engineer` (`playwright-cli`/`chrome-devtools`), `researcher` (evidence map).
- **Validation:** Five-scenario self-test, rendered evidence before "good", reuses `project-assessment-evidence` map, `output-handshake` before artifact.

### implementer

- **Responsibility:** Deliver features/bugs/refactorings with behavior preservation and build/test loop evidence.
- **Domains:** `delivery/task` + `ops/docs-generator` (shared capability, `specialist_justified: false`).
- **Delegates:** `delivery/task`, `ops/docs-generator`, `quality/deslop` (via reviewer), `quality/blast-radius` (via architect), `forge/gh-fix-ci` (via platform).
- **Collaborators:** `planner`, `architect`, `reviewer`, `qa-engineer`, `security-engineer`, `platform-engineer`, `designer`, `data-engineer`.
- **Validation:** Commands run + outcome; tests before/after refactor; no raw `any` / bare suppressions.

### reviewer

- **Responsibility:** Independent craft/change-safety verification — the boundary that prevents self-approval.
- **Domains:** `quality` (blast-radius, deep-review, deslop, unslop).
- **Delegates:** One per pass among the four; pairs with specialist `code-reviewer`/`refactor-cleaner`/`typescript-reviewer` when justified.
- **Collaborators:** `implementer` (verifies), `qa-engineer` (behavioral boundary), `security-engineer` (vuln handoff), `architect` (design handoff), `designer` (UI handoff).
- **Validation:** `file:line` findings with fix code for Critical/Warning.

### qa-engineer

- **Responsibility:** Prove behavior with evidence — gates + browser — before ship.
- **Domains:** `delivery/bug` + `quality/megalinter*` + `tooling/playwright-cli`, `tooling/chrome-devtools` (complementary, not duplicates).
- **Delegates:** One primary gate per pass; optionally pair Playwright + Chrome DevTools only when network/perf evidence needed alongside deterministic E2E; delegates deep authoring to `e2e-runner`.
- **Collaborators:** `implementer`, `reviewer`, `security-engineer`, `platform-engineer`, `designer`, `data-engineer`.
- **Validation:** Gate exit 0, screenshot/trace, reproduction steps, incident classification.

### security-engineer

- **Responsibility:** App + agentic hardening, evidence-cited, severity-ranked, with residual risk.
- **Domains:** `agentic-security/*` + `quality/codeql`.
- **Delegates:** `threat-modeling` → `mcp-audit` / `supply-chain-audit` → `owasp-agentic-review` → `codeql` sequenced, not chained mechanically.
- **Collaborators:** `architect` (threat modeling), `reviewer` (craft), `platform-engineer` (MCP runtime), `qa-engineer` (SARIF gate).
- **Validation:** OWASP ID + CVE + impact×likelihood + mitigation; static inspection only for MCP; no auto-reject of NOASSERTION without license review.

### platform-engineer

- **Responsibility:** CI/CD, forge PR lifecycle, worktrees, integrations, loops/swarm, triage, cost — the runtime fabric.
- **Domains:** 22 skills (forge 7, integrations 5, loops/swarm, triage, cli-for-agents, project, incident).
- **Delegates:** One lane per task (CI vs PR/MR vs worktrees vs MCP vs loops/swarm vs incident); swarm/loop composition explicit.
- **Collaborators:** `implementer`, `qa-engineer`, `reviewer`, `security-engineer`, `architect`, `planner`.
- **Validation:** `gh`/`glab`/`swarm` invocations + summarized outcome; `${ENV_VAR}` secrets; allowlist/deny + human gates.

### researcher

- **Responsibility:** Time-boxed discovery + single evidence-intake map that all assessments reuse (no second framework).
- **Domains:** `delivery/spike`, `delivery/project-assessment-evidence` (2).
- **Delegates:** `spike` or `project-assessment-evidence`; consumers are `project-assessment` (`planner`), `technical-unit-assessment` (`architect`), `management-unit-assessment` (`planner`), `design-assessment` (`designer`).
- **Collaborators:** All assessment owners + `data-engineer` (data evidence) + `implementer` (strategy consumer).
- **Validation:** `file:line`/`URL` citations; `Not assessed` without evidence; freshness/confidence tracked.

### data-engineer

- **Responsibility:** Repo-documented dbt/Snowflake read-only validation + notebook scaffolding (see sheet in §1 for platform-engineer format).
- **Domains:** `data/dbt-validation`, `data/snowflake-validation`, `tooling/jupyter-notebook` (3).
- **Delegates:** One of the three per ticket — contextually, not mechanically.
- **Collaborators:** `architect`, `qa-engineer`, `reviewer`, `platform-engineer`, `researcher`.
- **Validation:** `make parse` > `dbt parse`; capture actionable error lines; `Not assessed` when creds missing.

---

## 5. Assistant routing map — proportional delegation examples

`@assistant` is the **only** orchestrator humans invoke by default. It reads `skills/core/assistant/references/ORCHESTRATION.md` + this doc + `capabilities/skills/registry.yaml` and picks the minimum viable delegation. These examples are normative — 20 task simulations in §6 must route through them.

| Scenario (scale) | Assistant hears | Primary holistic delegate | Additional delegate only if | Skills invoked | Verification handoff |
|------------------|----------------|---------------------------|----------------------------|----------------|---------------------|
| **Tiny change** — typo fix in `README.md` | "Fix typo 'teh' in `README.md:42`" | `@implementer` (or directly via `implementer` is optional — assistant may handle via `tooling/cli-for-agents` guidance if trivial) → hands to `reviewer` for quick pass | No cross-system impact | `ops/docs-generator` or `quality/unslop` if prose-heavy | `reviewer` (`unslop` diff-scoped) — no QA/security/infra |
| **UI feature** — new checkout flow (design system exists) | "Add a new checkout flow for the design system; need visual review before release" | `@designer` (contextual) → `implementer` implements | Theme/responsive concerns emerge → `qa-engineer` (`playwright-cli`) for browser evidence | `design/frontend-design-review` (not `frontend-design` — system exists); `design/design-improvement` only after assessment | `designer` → `reviewer` (craft) → `qa-engineer` (browser gate) → `security-engineer` only if auth/payment |
| **Cross-system** — split service, add queue | "Split the billing service, add event queue, assess blast radius" | `@architect` + `@planner` jointly | `platform-engineer` for queue infra; `security-engineer` for trust boundaries | `architecture/c4-model` → `delivery/trd` → `quality/blast-radius` | `architect` gates design → `implementer` builds → `reviewer` → `qa-engineer` + `security-engineer` (STRIDE) |
| **Security-sensitive** — expose new API + handle PII | "Add public webhook endpoint that receives PII — auth, injection, supply-chain check" | `@security-engineer` (early) + `@architect` (threat model) + `@implementer` | Third-party SDK before adoption → `supply-chain-audit` | `agentic-security/threat-modeling` → `agentic-security/owasp-agentic-review` → `quality/codeql` → `tooling/cli-for-agents` for webhook ergonomics | `security-engineer` owns sign-off; never self-approved by `implementer`; `qa-engineer` for E2E of auth paths |

**Anti-patterns the assistant never performs:**

- Mechanically chaining all design skills on one ticket — `designer` picks **one** primary among assessment/review/guidelines plus at most one Figma skill and optionally `accessibility/review`.
- Running all four MegaLinter skills plus both browser skills per ticket — `qa-engineer` picks one gate contextually.
- Invoking a specialist without holistic routing — specialists are `specialist_agents` delegations when `specialist_justified: true`, not keyword triggers.

---

## 6. Twenty simulated routing tasks — ambiguous boundaries, expected route, rationale

Each task lists **primary owner** (holistic), **skill**, and why the nearby alternative was **not** chosen (contraindication / `overlap` per registry). All 20 must pass review if ambiguous — no mechanical chaining.

| # | Task | Primary → Skill | Delegates / pairings | Why not the alternative (contraindication) |
|---|------|----------------|---------------------|-------------------------------------------|
| 1 | Add new Prisma model and migration for `orders` with zero-downtime pattern | `@architect` → `delivery/trd` (+ `architecture/c4-model` if boundary change) | `reviewer` (`database-reviewer` specialist for schema review), `qa-engineer` (migration verification) | Not `@database-reviewer` alone — schema design is architecture; `@reviewer` handles craft, `@data-engineer` is pipeline validation, not schema review |
| 2 | Fix TypeScript `strict` errors after `tsc` bump — 12 files failing | `@implementer` → `delivery/task` + build loop | `platform-engineer` (`build-error-resolver`) for diagnosis; `reviewer` (`typescript-reviewer` specialist) only if craft depth | Not `@typescript-reviewer` as driver — holistic delivery owns fix; specialist is opt-in deep review, not error-resolution ownership |
| 3 | Greenfield landing page for jazz festival — distinctive palette, no design system | `@designer` → `design/frontend-design` | `implementer` (`figma-implement-design`) if Figma → code needed | Not `frontend-design-review` — nothing to review yet; not `design-assessment` — no evidence map yet; take one aesthetic risk |
| 4 | Audit `src/components/LoginForm.tsx` against Vercel WIG (`file:line` findings) | `@designer` → `design/web-design-guidelines` | `reviewer` only if craft deep-review requested separately | Not `design-assessment` — ask is `file:line` best-practice audit, not holistic UX diagnosis with evidence map |
| 5 | Evidence-based UX/UI diagnosis across 6 screens (Figma, Storybook, 200% zoom reports) | `@designer` → `design/design-assessment` (+ `researcher` `project-assessment-evidence` if no map yet) | `qa-engineer` (`playwright-cli` for rendered evidence); `accessibility/review` within assessment A11Y phase | Not `frontend-design-review` — holistic diagnosis requires `project-assessment-evidence` framework, vision-required, `Not assessed` without evidence |
| 6 | Fix Blocking findings from design-assessment and prove with screenshots | `@designer` → `design/design-improvement` | `qa-engineer` (`playwright-cli`/`chrome-devtools`) for rendered evidence; `implementer` implements within tokens | Not new `design-assessment` — consume existing scorecard; do not invent findings |
| 7 | "Review this PR's checkout flow for design-system compliance" (PR-gated) | `@designer` → `design/frontend-design-review` | `reviewer` (`code-reviewer` + `deslop`/`unslop`) for craft after design pass; optionally `accessibility/review` | Not backend/API — `frontend-design-review` is frontend/UI only; backend → `reviewer` instead |
| 8 | Translate Figma node `https://figma.com/...?node-id=1-2` into React+Tailwind 1:1 | `@designer` → `design/figma` → `design/figma-implement-design` | `implementer` owns merge; `qa-engineer` verifies render | Not `figma-create-design-system-rules` — intent is node→code, not rule authoring; follow `get_design_context`→`get_screenshot`→implement→validate |
| 9 | Threat model a new webhook that receives PII and writes to queue | `@security-engineer` → `agentic-security/threat-modeling` (+ `architect` C4) | `security-engineer` `owasp-agentic-review` follows; `platform-engineer` for queue infra | Not `security-reviewer` alone — agentic/STRIDE + trust boundaries are holistic `security-engineer`/`architect`; app-only review (XSS/SQLi) insufficient |
| 10 | Before adopting a third-party skill pack from npm, audit provenance/pins/licenses | `@security-engineer` → `agentic-security/supply-chain-audit` | `quality/codeql` if code scanning needed; `architect` if system placement tradeoffs | Not `mcp-audit` — supply chain is broader than MCP config/impl; static Grep/Read + `audit-capability.vsh` in checkout/CI |
| 11 | CI red — failing GitHub Actions on PR, needs log triage + minimal fix | `@platform-engineer` → `forge/gh-fix-ci` (+ `build-error-resolver`) | `implementer` applies fix; `qa-engineer` re-verifies gate | Not `@build-error-resolver` as driver — CI lifecycle is `platform-engineer`; error knowledge is specialist |
| 12 | Draft incident after production outage — detection/impact/timeline/RCA/follow-ups | `@platform-engineer` → `delivery/incident` | `qa-engineer` (`delivery/bug` escalation input); `security-engineer` if security-sensitive | Not `delivery/bug` alone — bug is triage + escalation decision; incident is post-impact RCA and is platform-owned |
| 13 | Plan a greenfield feature touching 3 repos — estimate, risks, task breakdown | `@planner` → `delivery/planning` → `delivery/work-item` hierarchy | `architect` (`quality/blast-radius`, `delivery/trd`), `researcher` (`delivery/spike` if unknowns) | Not `delivery/task` as driver — `task` is single technical task template; `planning` is estimation + capacity before breakdown |
| 14 | Time-boxed investigation: should we use BullMQ or SQS for a queue? Tradeoffs | `@researcher` → `delivery/spike` | `architect` (`cloud/cloud-design-patterns`) for vendor mapping; `planner` for breakdown | Not `@architect` as driver — spike is evidence-backed research (time-boxed, risks/open questions) before design decision; architect consumes spike |
| 15 | Data team: validate dbt models after PR — `dbt parse`/`compile`, selective `dbt test` | `@data-engineer` → `data/dbt-validation` | `qa-engineer` lint gate only for mixed stacks; `reviewer` for SQL/model craft | Not `@qa-engineer` alone — dbt toolchain/creds/warehouse safety is `data-engineer`; not `@architect` — modeling assessment is different from validation |
| 16 | Scaffold a new experiment notebook for model evaluation | `@data-engineer` → `tooling/jupyter-notebook` | `researcher` if evidence intake includes data; `implementer` for doc generation | Not raw notebook JSON — bundled templates + `new_notebook.py`; not `qa-engineer` — not behavioral proof |
| 17 | Run E2E suite for checkout — author missing tests with POM, fix flakes | `@qa-engineer` → `tooling/playwright-cli` (+ `e2e-runner` specialist) | `platform-engineer` if CI selects E2E runner; `reviewer` for craft of E2E code | Not `data-engineer` or `designer` — E2E is verification owned by `qa-engineer`; specialist authoring is `e2e-runner` |
| 18 | Accessibility audit with WCAG 2.2 AA SC mapping before release | `@designer` (or via `@qa-engineer` handoff) → `accessibility/review` | `design/design-improvement` for fix→capture→re-review; `qa-engineer` (`chrome-devtools`) for browser evidence | Not `frontend-design-review` alone — curated WCAG 2.2 AA with mode (auto/browser-assisted/manual) and SC-mapped fixes is `accessibility/review`; never claim full AA from auto checks |
| 19 | Multi-PR contribution strategy — "what should I work on today?" | `@platform-engineer` → `forge/gh-contribution-planner` | `planner` if sequencing spans epics; `researcher` if reference patterns needed | Not `planner` alone — contribution planner mines GH-logged-in user's repos + recent contributions (GH-specific); `planner` is delivery-generic |
| 20 | Clean AI tells from PR body and diff-scoped code slop before merge | `@reviewer` → `quality/unslop` → `quality/deslop` | `planner` if decision-log needed; `implementer` applies slop fixes pre-merge | Not full-repo rewrite — `deslop` is diff-scoped; `unslop` is prose/docs; separate from `megalinter*` (independent static gates, not slop) |

**Routing principle applied to all 20:** pick **one primary holistic owner and one primary skill**; add a second only when explicitly requested (Figma + implementation, threat-model + owasp-review) or when complementary evidence requires (`design-assessment` + `project-assessment-evidence`, `playwright-cli` + `chrome-devtools`). Never mechanically chain all skills in a domain.

---

## 7. Target routing — harnesses vs native specialization

Per `capabilities/targets/registry.yaml` and `docs/TARGET_CAPABILITY_MATRIX.md`: all targets support Agent Skills; native custom agents/subagents vary (Claude/Cursor full, others partial). Where a target natively supports `Explore`/subagents:

- `researcher` maps exploration intent to target-native `Explore` / sub-agent parallelism when beneficial (e.g., codebase-wide lookups), but always produces the same `file:line`-cited evidence required by `delivery/spike` / `project-assessment-evidence`.
- Swarms (`ops/swarm*`) are platform-owned (`platform-engineer`) and runner-agnostic (OpenCode primary, Claude/Codex/Cursor/Copilot/skeleton adapters) — taxonomy does not bind to a single harness.

Never route around holistic ownership to reach a target-native shortcut — holistic responsibility and `capabilities/skills/registry.yaml` remain authoritative; native delegation is an implementation detail of `researcher`/`platform-engineer`, not a routing decision.

---

## 8. Specialist tier — detailed decisions deferred to #865

#864 decides **holistic** taxonomy and classification; #865 finalizes specialist shapes. Unless noted below, all specialists stay on disk through #865 with their current `AGENT.md` intact so no prompt knowledge is lost. Deferred questions for #865:

- `database-reviewer`, `performance-optimizer`, `typescript-reviewer`: keep as specialist vs convert to skill (`quality/deep-review` / `ops/docs-generator` patterns) — evaluate repo evidence (language-specific triggers, review checklist length, reuse rate).
- `docs-lookup` + `reference-lookup`: remove alias after knowledge merge into `researcher` verified (file count drops from 25 → 23; catalog regenerates).
- `build-error-resolver`, `tdd-guide`, `refactor-cleaner`, `e2e-runner`, `agentic-security-reviewer`, `security-reviewer`, `tech-assistant`: confirm each remains `KEEP AS SPECIALIST` (with `HOW_TO_ADD_AGENT` references update) or justify conversion — present `specialist_justified` per registry.
- `client-workflow-bootstrap`: confirm orchestrator vs specialist-orchestrator naming (current description already says "orchestrator" — may add `orchestrator` label in `capabilities/skills/registry.yaml` if schema extended).

Every specialist file must be touched by #865 (edit, convert, or explicitly re-affirm) — none treated as no-op.

---

## 9. Files changed by #864 and validation checklist

**New:**
- `agents/implementer/AGENT.md`, `agents/reviewer/AGENT.md`, `agents/qa-engineer/AGENT.md`, `agents/security-engineer/AGENT.md`, `agents/platform-engineer/AGENT.md`, `agents/researcher/AGENT.md`, `agents/data-engineer/AGENT.md` — 7 holistic agents
- `docs/AGENT_TAXONOMY.md` (this file) — migration map + routing self-tests

**Updated:**
- `agents/assistant/AGENT.md` — delegation map to new 11 roles (not 14 legacy)
- `agents/planner/AGENT.md`, `agents/architect/AGENT.md` — holistic ownership tables + collaborators + registry citation (expanded per taxonomy)
- `README.md` — Agent Personas: holistic roster table with responsibility/skill columns + specialist sidebar + taxonomy link
- `docs/ARCHITECTURE.md` — Repository Structure live-count `+` Holistic Taxonomy summary
- `skills/core/assistant/references/ORCHESTRATION.md` — header referencing `docs/AGENT_TAXONOMY.md`
- `catalogs/agent-catalog.yaml` — regenerated (18 → 25)
- `distributions/products.yaml` — updated description/membership note for `agent-toolkit-agents` (count deferred — still 17 on disk until #865 merges specialists — but doc updated)

**Unchanged (deferred to #865):** `agents/build-error-resolver`, `agents/client-workflow-bootstrap`, `agents/code-reviewer`, `agents/database-reviewer`, `agents/docs-lookup`, `agents/e2e-runner`, `agents/performance-optimizer`, `agents/refactor-cleaner`, `agents/reference-lookup`, `agents/security-reviewer`, `agents/tdd-guide`, `agents/tech-assistant`, `agents/typescript-reviewer`, `agents/agentic-security-reviewer`.

**Validation (all must exit 0):**
```bash
./scripts/validate-agents.vsh
python3 scripts/validate-skill-capability.py --check   # 85 skills, no orphans, design routing still passes
./scripts/generate-catalogs.vsh --check                  # catalogs synced
./make.vsh build-cli && AGENT_TOOLKIT_ROOT="$PWD" ./build/agent-toolkit build --check
# optional pytest (needs uv sync):
uv sync --project packages/pypi/agent-toolkit-cli --all-extras && uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/test_skill_capability_registry.py -v
```
