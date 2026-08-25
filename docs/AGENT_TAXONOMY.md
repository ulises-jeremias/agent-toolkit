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
| **Specialist** | Opt-in narrow expertises that justify dedicated prompting (independent verification, noisy output, disjoint surface, large context) | 6 specialists retained per #865 (7 archived to references) — see §3 final map | `@code-reviewer` (backs `reviewer`), `@security-reviewer` + `@agentic-security-reviewer` (backs `security-engineer`), `@e2e-runner` (backs `qa-engineer`), `@tdd-guide` (backs `implementer`), `@build-error-resolver` (backs `platform-engineer`) | Very narrow: single checklist/technique; invoked by a holistic owner when `specialist_justified: true` in registry or task explicitly warrants; 7 archived → `reviewer/references/*`, `researcher/references/LOOKUP_GUIDE.md`, `platform-engineer/references/WORKSTATION_OPS.md` |

**Rule:** specialists are **opt-in**; shared capabilities are the default (§ "Specialist agents" in `capabilities/skills/registry.yaml` — `specialist_justified: true` only for high-severity/review/research skills). Never delete prompt knowledge — move it (see §3).

---

## 3. Migration map — final decisions for #865 (agent-vs-skill rule applied)

> **Agent-vs-skill rule (#865):** **Keep as agent** if benefits from separate context, independence, parallelism, focused lifecycle, unique permissions, different model profile, large/noisy output, or explicit handoff; **convert to skill/reference** if procedural guidance, checklist, or narrow capability loaded inline. Relevant chains preserved: `Assistant → Implementer → TDD Guide`, `Assistant → QA Engineer → E2E Runner`, `Assistant → Security Engineer → Agentic Security Reviewer`, `Assistant → Platform Engineer → Build Error Resolver`.

All 25 agentes present at `main@e526858` (11 holistic + orchestrator + 13 specialists) now have final #865 decisions. No prompt knowledge deleted — converted specialists moved to `references/*.md` with provenance. Every retained specialist has caller, skills used, and handoff documented in its `AGENT.md` (§ Caller / skills / handoff) and cited rule clause (see §8).

| # | Previous agent (`agents/<id>`) | Decision (#865 final) | Cited rule clause | Where prompt knowledge now lives | Caller → Skills → Handoff | Registry link |
|---|--------------------------------|------------------------|-------------------|---------------------------------|---------------------------|---------------|
| 1 | `agentic-security-reviewer` | **KEEP AS SPECIALIST** | Disjoint agentic threat surface + focused lifecycle + explicit handoff (agentic LM01-10+AGNT01-06 vs appsec) | `agents/agentic-security-reviewer/AGENT.md` — § Agent vs skill rule + Caller/handoff + Delegation table | `security-engineer` → `agentic-security/mcp-audit`, `supply-chain-audit`, `owasp-agentic-review`, `threat-modeling` → returns OWASP-mapped findings to `security-engineer` | `holistic_owner: security-engineer` + `specialist_agents: [agentic-security-reviewer]` |
| 2 | `architect` | **KEEP AS HOLISTIC** | 9 skills, distinct daily design role | `agents/architect/AGENT.md` — holistic ownership table | — | `holistic_owner: architect` (9 skills) — now references `reviewer/references/DATABASE_CHECKLIST.md`/`PERFORMANCE_CHECKLIST.md` inline where storage/perf in scope |
| 3 | `assistant` | **KEEP AS ORCHESTRATOR** | Default entry, repo discovery, delegates to 11 holistic | `agents/assistant/AGENT.md` — updated specialist list + 20 self-tests | Everyone via `ORCHESTRATION.md` | `core/*` + `tooling/inventory` under `assistant` |
| 4 | `build-error-resolver` | **KEEP AS SPECIALIST** | Large diagnostic context + separate context + noisy logs | `agents/build-error-resolver/AGENT.md` — § Agent vs skill rule + Caller/handoff + Output format | `platform-engineer` → `forge/gh-fix-ci` + `tooling/cli-for-agents` → minimal fix to `platform-engineer`/`implementer`; `qa-engineer` re-verifies | `holistic_owner: platform-engineer` + `specialist_agents: [build-error-resolver]` |
| 5 | `client-workflow-bootstrap` | **KEEP AS ORCHESTRATOR** (meta-generator) | Focused lifecycle + output isolation + different model profile + explicit handoff | `agents/client-workflow-bootstrap/AGENT.md` — § Agent vs skill rule + Caller/handoff + Output format + Delegation; now `tools: Read,Grep,Glob,Bash,Write,Edit` | User/workspace-init → `delivery/workflow-client-bootstrap`, `forge/github-cli-workflow`, `core/workspace-knowledge-sync` → draft PR | `holistic_owner: assistant` — orchestrator tier, not holistic daily |
| 6 | `code-reviewer` | **KEEP AS SPECIALIST** (backs `reviewer` + `qa-engineer` + `architect`) | Independent verification boundary + large cross-file context | `agents/code-reviewer/AGENT.md` — § Agent vs skill rule + Caller/handoff | `reviewer` → `quality/blast-radius`, `quality/deep-review`, `quality/deslop`, `quality/unslop`; also `qa-engineer`/`designer`/`architect` → findings to `reviewer` | `holistic_owner: reviewer` (4) + `specialist_agents: [code-reviewer]` |
| 7 | `database-reviewer` | **CONVERT TO REFERENCE** → archived | Procedural checklist, narrow capability loaded inline — no separate context/parallel/noisy-output; holistic `reviewer` + `quality/deep-review` + inline `references/*.md` suffices | `agents/reviewer/references/DATABASE_CHECKLIST.md` — migrated from `agents/database-reviewer/AGENT.md` (provenance + usage + caller/handoff); `reviewer` + `architect` load inline | `reviewer` via `quality/deep-review`/`blast-radius` or `architect` via `delivery/technical-unit-assessment` → schema/migration/explain plan; handoff to `data-engineer`/`qa-engineer`/`implementer` | `data-engineer` is pipeline validation, not schema review — no dedicated `holistic_owner`; checklist is `reviewer` reference |
| 8 | `designer` | **KEEP AS HOLISTIC** | 11 skills, single contextual router essential | `agents/designer/AGENT.md` | — | `holistic_owner: designer` (11) |
| 9 | `docs-lookup` | **MERGE INTO HOLISTIC (`researcher`)** → archived | Procedural lookup, narrow capability loaded inline — `researcher` + `delivery/spike`/`project-assessment-evidence` covers it | `agents/researcher/references/LOOKUP_GUIDE.md` (consolidated with `reference-lookup`) — provenance + workflow; `researcher` subsumes | `researcher` → `delivery/spike` / `delivery/project-assessment-evidence` (no delegate agent) | `holistic_owner: researcher` — no standalone agent |
| 10 | `e2e-runner` | **KEEP AS SPECIALIST** (backs `qa-engineer`) | Large/noisy browser output + parallelism + isolation | `agents/e2e-runner/AGENT.md` — § Agent vs skill rule + Caller/handoff + Output format | `qa-engineer` → `tooling/playwright-cli` + `tooling/chrome-devtools` → specs to `qa-engineer` | `holistic_owner: qa-engineer` + `specialist_agents: [e2e-runner]` |
| 11 | `performance-optimizer` | **CONVERT TO REFERENCE** → archived | Procedural profiling checklist (measure→bottleneck→fix→verify), loadable inline — no separate context/parallel/noisy-output; holistic `reviewer`/`architect` covers | `agents/reviewer/references/PERFORMANCE_CHECKLIST.md` — migrated from `agents/performance-optimizer/AGENT.md` (provenance + workflow); `reviewer` + `architect` load inline | `reviewer` via `quality/deep-review`/`blast-radius` or `architect` via `delivery/technical-unit-assessment` → metric/perf fix; handoff to `qa-engineer`/`implementer` with re-measurement | `reviewer`/`architect` deep paths — reference, not agent |
| 12 | `planner` | **KEEP AS HOLISTIC** | Decomposition/estimation/capacity daily work | `agents/planner/AGENT.md` | — | `holistic_owner: planner` (11) |
| 13 | `refactor-cleaner` | **CONVERT TO REFERENCE** → archived | Procedural checklist (dead code / duplication / naming / Rule of Three), narrow capability loaded inline — holistic `reviewer` via `quality/deslop` + `implementer` behavior-preservation + inline `references/*.md` covers it | `agents/reviewer/references/REFACTOR_CHECKLIST.md` — migrated from `agents/refactor-cleaner/AGENT.md` (provenance + hard rules); `reviewer` + `implementer` load inline | `reviewer` via `quality/deslop` (diff-scoped) or `implementer` → applies `REFACTOR_CHECKLIST.md` inline; handoff via `qa-engineer` gates | `holistic_owner: reviewer` — reference, not agent |
| 14 | `reference-lookup` | **MERGE INTO HOLISTIC (`researcher`)** → archived | Procedural pattern-search (public-examples API fetch → summarize → adapt), narrow capability loaded inline — `researcher` subsumes | `agents/researcher/references/LOOKUP_GUIDE.md` (consolidated with `docs-lookup`) — provenance + workflow; `researcher` subsumes | `researcher` → `delivery/spike` evidence phase | `delivery/spike` evidence phase — no delegate agent |
| 15 | `security-reviewer` | **KEEP AS SPECIALIST** (backs `security-engineer`) | Independent verification boundary + disjoint app-code surface (OWASP Top 10) | `agents/security-reviewer/AGENT.md` — § Agent vs skill rule + Caller/handoff + Delegation | `security-engineer` → `agentic-security/owasp-agentic-review`, `quality/codeql` → findings to `security-engineer` | `holistic_owner: security-engineer` + `specialist_agents: [security-reviewer]` |
| 16 | `tdd-guide` | **KEEP AS SPECIALIST** (backs `implementer`) | Separate context + focused lifecycle + explicit handoff + different model profile (discipline enforcement needs isolation) | `agents/tdd-guide/AGENT.md` — § Agent vs skill rule + Caller/handoff + Output format + Delegation | `implementer` → `delivery/development-workflow`, `delivery/task` → red→green→refactor to `implementer`; handoff to `reviewer`/`qa-engineer` | `holistic_owner: implementer` shared capability — specialist is opt-in technique |
| 17 | `tech-assistant` | **CONVERT TO REFERENCE** → archived | Stub — procedural, narrow capability loaded inline; holistic `platform-engineer` via `ops/triage` + `tooling/inventory` + `core/workspace` covers it; no separate context/parallel/noisy-output justification | `agents/platform-engineer/references/WORKSTATION_OPS.md` — migrated from `agents/tech-assistant/AGENT.md` stub (provenance + checklist) | `platform-engineer` directly drives `ops/triage`/`tooling/inventory`/`core/workspace` without delegate agent | `holistic_owner: platform-engineer` — now reference, no `specialist_agents` |
| 18 | `typescript-reviewer` | **CONVERT TO REFERENCE** → archived | Procedural checklist, narrow TS capability loaded inline — holistic `reviewer` + `quality/deep-review` covers it; no separate context/parallel/noisy-output | `agents/reviewer/references/TYPESCRIPT_CHECKLIST.md` — migrated from `agents/typescript-reviewer/AGENT.md` (provenance + utility-types/narrowing) | `reviewer` via `quality/deep-review`/`deslop` or `qa-engineer` → TS types/generics/narrowing; handoff to `implementer`/`platform-engineer` | `reviewer` — reference, not agent |

**Final counts for #865:** 25 → **18 personas** on disk (11 holistic + 2 orchestrators (`assistant`, `client-workflow-bootstrap`) + 6 specialists (`code-reviewer`, `agentic-security-reviewer`, `security-reviewer`, `e2e-runner`, `tdd-guide`, `build-error-resolver`) + data-engineer/designer/planner/architect/implementer/reviewer/qa-engineer/security-engineer/platform-engineer/researcher). 7 archived → `references/` with provenance; catalogs regenerated.

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
- **Delegates:** One per pass among the four; specialist `code-reviewer` when `specialist_justified: true`; procedural checklists are `references/*.md` loaded inline during `deep-review`/`deslop` (not agents): `references/TYPESCRIPT_CHECKLIST.md`, `references/DATABASE_CHECKLIST.md`, `references/PERFORMANCE_CHECKLIST.md`, `references/REFACTOR_CHECKLIST.md` (archived #865 per agent-vs-skill rule).
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
- **Domains:** 22 skills (forge 7, integrations 5, loops/swarm, triage, cli-for-agents, project, incident) + `references/WORKSTATION_OPS.md` (archived `tech-assistant` #865 — procedural workstation guidance loaded inline, not agent).
- **Delegates:** One lane per task (CI vs PR/MR vs worktrees vs MCP vs loops/swarm vs incident); swarm/loop composition explicit. Only `build-error-resolver` remains as specialist; workstation ops is `references/WORKSTATION_OPS.md`.
- **Collaborators:** `implementer`, `qa-engineer`, `reviewer`, `security-engineer`, `architect`, `planner`.
- **Validation:** `gh`/`glab`/`swarm` invocations + summarized outcome; `${ENV_VAR}` secrets; allowlist/deny + human gates.

### researcher

- **Responsibility:** Time-boxed discovery + single evidence-intake map that all assessments reuse (no second framework).
- **Domains:** `delivery/spike`, `delivery/project-assessment-evidence` (2) + `references/LOOKUP_GUIDE.md` (consolidated `docs-lookup`/`reference-lookup`, archived #865 — procedural lookup loaded inline, not agents).
- **Delegates:** `spike` or `project-assessment-evidence`; consumers are `project-assessment` (`planner`), `technical-unit-assessment` (`architect`), `management-unit-assessment` (`planner`), `design-assessment` (`designer`). Lookup guidance is `references/LOOKUP_GUIDE.md` (not specialist dispatch).
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
| 1 | Add new Prisma model and migration for `orders` with zero-downtime pattern | `@architect` → `delivery/trd` (+ `architecture/c4-model` if boundary change) | `reviewer` via `quality/deep-review` + `references/DATABASE_CHECKLIST.md` (archived `database-reviewer` #865), `qa-engineer` (migration verification) | Not standalone `@database-reviewer` — archived as `reviewer/references/DATABASE_CHECKLIST.md`; schema design is architecture; `@reviewer` loads checklist inline, `@data-engineer` is pipeline validation not schema review |
| 2 | Fix TypeScript `strict` errors after `tsc` bump — 12 files failing | `@implementer` → `delivery/task` + build loop | `platform-engineer` (`build-error-resolver`) for diagnosis; `reviewer` via `quality/deep-review` + `references/TYPESCRIPT_CHECKLIST.md` (archived `typescript-reviewer` #865) only if craft depth | Not standalone `@typescript-reviewer` — archived as `reviewer/references/TYPESCRIPT_CHECKLIST.md`; holistic delivery owns fix; opt-in deep review via holistic `reviewer` inline checklist |
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

## 8. Specialist tier — final decisions for #865 (agent-vs-skill rule)

#864 decided holistic taxonomy and classification; #865 finalizes specialist shapes. Every specialist was evaluated against the rule: **keep as agent** if benefits from separate context, independence, parallelism, focused lifecycle, unique permissions, different model profile, large/noisy output, or explicit handoff; **convert to reference/skill** if procedural guidance, checklist, or narrow capability loaded inline.

| Specialist | Decision | Cited clause | Caller → Skills → Handoff |
|---|---|---|---|
| `tdd-guide` | **KEEP AS SPECIALIST** | Separate context + focused lifecycle + explicit handoff + different model profile (discipline enforcement needs isolation; prevents implementer skipping red) | `implementer` → `delivery/development-workflow`, `delivery/task` → red→green→refactor to `implementer`; chain `Assistant → Implementer → TDD Guide` |
| `e2e-runner` | **KEEP AS SPECIALIST** | Large/noisy output + parallelism + isolation (browser logs/traces) | `qa-engineer` → `tooling/playwright-cli`, `tooling/chrome-devtools` → specs to `qa-engineer`; chain `Assistant → QA → E2E` |
| `build-error-resolver` | **KEEP AS SPECIALIST** | Large diagnostic context + separate context (compiler logs/type graphs) | `platform-engineer` → `forge/gh-fix-ci`, `tooling/cli-for-agents` → minimal fix to `platform-engineer`/`implementer`; `qa-engineer` re-verifies |
| `agentic-security-reviewer` | **KEEP AS SPECIALIST** | Disjoint agentic threat surface (LLM01-10+AGNT01-06) + explicit handoff vs appsec | `security-engineer` → `agentic-security/mcp-audit`, `supply-chain-audit`, `owasp-agentic-review`, `threat-modeling` → OWASP-mapped findings to `security-engineer`; chain `Assistant → Security → Agentic` |
| `security-reviewer` | **KEEP AS SPECIALIST** | Independent verification + disjoint app-code surface (OWASP Top 10) | `security-engineer` → `agentic-security/owasp-agentic-review`, `quality/codeql` → findings to `security-engineer` |
| `code-reviewer` | **KEEP AS SPECIALIST** | Independent verification boundary + large cross-file context | `reviewer` → `quality/blast-radius`/`deep-review`/`deslop`/`unslop`; also `qa-engineer`/`designer`/`architect` → findings to `reviewer` |
| `performance-optimizer` | **CONVERT TO REFERENCE** | Procedural profiling checklist (measure→bottleneck→fix→verify), loadable inline | `reviewer` via `quality/deep-review`/`blast-radius` or `architect` via `delivery/technical-unit-assessment` → `reviewer/references/PERFORMANCE_CHECKLIST.md` inline |
| `database-reviewer` | **CONVERT TO REFERENCE** | Procedural schema/query/migration checklist, narrow capability | `reviewer` via `quality/deep-review` or `architect` via `delivery/technical-unit-assessment` → `reviewer/references/DATABASE_CHECKLIST.md` inline |
| `typescript-reviewer` | **CONVERT TO REFERENCE** | Procedural checklist (strict/utility-types/generic/narrowing), no separate context | `reviewer` via `quality/deep-review`/`deslop` or `qa-engineer` → `reviewer/references/TYPESCRIPT_CHECKLIST.md` inline |
| `refactor-cleaner` | **CONVERT TO REFERENCE** | Procedural checklist (dead code/duplication/naming/Rule of Three), narrow capability | `reviewer` via `quality/deslop` or `implementer` → `reviewer/references/REFACTOR_CHECKLIST.md` inline |
| `docs-lookup` + `reference-lookup` | **MERGE → `researcher` reference** | Procedural lookup (local docs → codebase; public-examples API → adapt), narrow capability | `researcher` → `delivery/spike`/`project-assessment-evidence` + `researcher/references/LOOKUP_GUIDE.md` inline — no delegate agent |
| `tech-assistant` | **CONVERT TO REFERENCE** | Stub, narrow procedural, no separate context | `platform-engineer` → `ops/triage`/`tooling/inventory` directly; `platform-engineer/references/WORKSTATION_OPS.md` inline |
| `client-workflow-bootstrap` | **KEEP AS ORCHESTRATOR** | Focused lifecycle + output isolation + different model profile (`Write`/`Edit`) | User/workspace-init → `delivery/workflow-client-bootstrap`, `forge/github-cli-workflow` → draft PR |

Every retained specialist has documented caller, skills used, and handoff in its `AGENT.md` (§ Caller / skills / handoff, § Delegate to skills, § Output format). No prompt knowledge deleted — 7 archived → `references/*.md` with provenance. No specialist is a required manual entry point for day-to-day use — holistic owners cover daily invocation.

---

## 9. Files changed by #864 + #865 and validation checklist

**#864 New:**
- `agents/implementer/AGENT.md`, `agents/reviewer/AGENT.md`, `agents/qa-engineer/AGENT.md`, `agents/security-engineer/AGENT.md`, `agents/platform-engineer/AGENT.md`, `agents/researcher/AGENT.md`, `agents/data-engineer/AGENT.md` — 7 holistic agents
- `docs/AGENT_TAXONOMY.md` (this file) — migration map + routing self-tests

**#864 Updated:**
- `agents/assistant/AGENT.md` — delegation map to new 11 roles (not 14 legacy)
- `agents/planner/AGENT.md`, `agents/architect/AGENT.md` — holistic ownership tables + collaborators + registry citation (expanded per taxonomy)
- `README.md` — Agent Personas: holistic roster table with responsibility/skill columns + specialist sidebar + taxonomy link
- `docs/ARCHITECTURE.md` — Repository Structure live-count `+` Holistic Taxonomy summary
- `skills/core/assistant/references/ORCHESTRATION.md` — header referencing `docs/AGENT_TAXONOMY.md`
- `catalogs/agent-catalog.yaml` — regenerated (18 → 25 → 18 post-865)
- `distributions/products.yaml` — updated description/membership note for `agent-toolkit-agents`

**#865 New (references with provenance — no prompt knowledge deleted):**
- `agents/reviewer/references/TYPESCRIPT_CHECKLIST.md` — from `typescript-reviewer`
- `agents/reviewer/references/DATABASE_CHECKLIST.md` — from `database-reviewer`
- `agents/reviewer/references/PERFORMANCE_CHECKLIST.md` — from `performance-optimizer`
- `agents/reviewer/references/REFACTOR_CHECKLIST.md` — from `refactor-cleaner`
- `agents/researcher/references/LOOKUP_GUIDE.md` — consolidated `docs-lookup` + `reference-lookup`
- `agents/platform-engineer/references/WORKSTATION_OPS.md` — from `tech-assistant` stub

**#865 Updated (every specialist file touched — re-affirmed or converted):**
- `agents/tdd-guide/AGENT.md`, `agents/e2e-runner/AGENT.md`, `agents/build-error-resolver/AGENT.md`, `agents/agentic-security-reviewer/AGENT.md`, `agents/security-reviewer/AGENT.md`, `agents/code-reviewer/AGENT.md` — tightened: added § Agent vs skill rule (cited clause), Caller/skills/handoff, Output format, Delegate tables, References
- `agents/client-workflow-bootstrap/AGENT.md` — confirmed orchestrator meta-generator; added § Agent vs skill rule + Caller/handoff + Output format
- `agents/reviewer/AGENT.md`, `agents/researcher/AGENT.md`, `agents/platform-engineer/AGENT.md`, `agents/implementer/AGENT.md`, `agents/qa-engineer/AGENT.md`, `agents/architect/AGENT.md` — wired inline `references/*.md` delegation and archived-agent notes
- `agents/assistant/AGENT.md`, `docs/SKILL_ROUTING.md`, `skills/core/assistant/references/ORCHESTRATION.md`, `README.md`, `docs/ARCHITECTURE.md`, `docs/HOW_TO_ADD_AGENT.md` — updated taxonomy tables/routing to 18 personas + 7 archived references
- `capabilities/skills/registry.yaml` — cleared `specialist_agents: [docs-lookup]`, `[tech-assistant]`, `[refactor-cleaner]` where archived; contraindications now point to inline references
- `catalogs/agent-catalog.yaml` — regenerated (25 → 18) + `distributions/products.yaml` — membership trimmed from 25 → 18
- `modules/agent_toolkit_core/embedded_data.v` — regenerated (1425 files)

**#865 Removed (after knowledge moved with verification):**
- `agents/typescript-reviewer/`, `agents/database-reviewer/`, `agents/performance-optimizer/`, `agents/refactor-cleaner/`, `agents/docs-lookup/`, `agents/reference-lookup/`, `agents/tech-assistant/` — each archived as `references/*.md` above

**Validation (all must exit 0):**
```bash
./scripts/validate-agents.vsh
python3 scripts/validate-skill-capability.py --check   # 85 skills, no orphans, design routing still passes
./scripts/generate-catalogs.vsh --check                  # catalogs synced (now 18 agents)
./scripts/generate-embedded-data.vsh                     # 1425 files embedded
./make.vsh build-cli && AGENT_TOOLKIT_ROOT="$PWD" ./build/agent-toolkit build --check
# on branch feat/865-specialist-taxonomy: expect build --check DRIFT for modified agents (regenerate committed plugins/ via AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build)
# optional pytest (needs uv sync):
uv sync --project packages/pypi/agent-toolkit-cli --all-extras && uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/test_skill_capability_registry.py -v
```
