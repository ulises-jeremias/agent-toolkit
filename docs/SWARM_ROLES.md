# Swarm Role Alignment — Runtime Roles vs Canonical Agent Taxonomy (#870)

> **Authority:** `agents/*/AGENT.md` (18 personas: 11 holistic + 2 orchestrators + 6 specialists) + `docs/AGENT_TAXONOMY.md` + `docs/SWARM_RECIPES.md` + `capabilities/skills/registry.yaml` (holistic_owner SSOT).
> Validate with `python3 -m pytest tests/test_swarm_alignment.py -v`.

This document defines the **only** mapping between swarm **runtime roles** (ephemeral, per-run responsibilities in a swarm recipe) and the **canonical agent taxonomy** (holistic/specialist personas from #864/#865). Swarm roles do NOT create a parallel taxonomy — they resolve against the canonical `agents/` roster via persona selection.

## 1. Vocabulary — never conflate

| Concept | Lives in | What it is | Example |
|---------|----------|------------|---------|
| **Persona** (`agents/<name>/AGENT.md`) | `agents/` + `capabilities/skills/registry.yaml` | Intellectual specialization, owns `holistic_owner` skills, daily-facing name humans remember | `reviewer` (holistic), `code-reviewer` (specialist backing `reviewer`) |
| **Runtime role** | `docs/SWARM_RECIPES.md` recipe `spec.roles.<role>` | Ephemeral responsibility in a swarm run — owns a worktree/branch, receives handoffs, has a policy/budget | `integrator` (runtime gate) |
| **Skill** | `skills/<domain>/<name>/SKILL.md` | Procedural capability loaded inline by a persona (MCP, forge, design, etc.) | `quality/blast-radius` |
| **Model profile** | `docs/SWARM_MODELS_AND_COSTS.md` | Which LLM the runner uses for a role's task class | `review`, `hardening`, `qa` |

## 2. Mapping — every swarm runtime role → canonical persona/specialist

Recipes `pair`/`team`/`full` define only these roles (see `docs/SWARM_RECIPES.md`). Each role's `persona:` field points to the canonical name — there is no competing selector.

| Swarm role | Recipe(s) | Canonical persona | Kind | Activation | Responsibility |
|---|---|---|---|---|---|
| `planner` | `team`, `full` | `planner` | holistic | Conditional — `team`/`full` only, lazy | Decomposition, PRD/TRD framing, work-item breakdown, estimation, risk & capacity — produces `task-contract.md` |
| `implementer` | `pair`, `team`, `full` | `implementer` | holistic | Always (eager) | Feature/bug/refactor delivery, build/test loop — behavior-preserving, hands SHA to `reviewer` |
| `reviewer` | `pair`, `team` | `reviewer` (backed by `code-reviewer` when `specialist_justified: true`) | holistic (+ specialist opt-in) | Always | Independent craft / change-safety verification (`quality/blast-radius`, `deep-review`/`deslop`/`unslop`); never self-approves |
| `integrator` | `pair`, `team`, `full` | **Runtime responsibility** — not a permanent daily persona; typically `architect` acting as integrator (`policy: integrator`, `receive_mode: batch`) | `architect` persona in integrator policy | Conditional — batch gate after `reviewer` (pair) or `architect` (team/full) | Final merge/approval gate, human approval required (`allow_direct_base_merge: false`) — reuses `architect` design sense, not a new taxonomy entry |
| `architect` | `team`, `full` | `architect` | holistic | Conditional — `team`/`full` | System design, TRD/C4 tradeoffs, `quality/blast-radius` collaboration |
| `refactorer` | `full` | `reviewer` via `quality/deslop` + `reviewer/references/REFACTOR_CHECKLIST.md` (archived `refactor-cleaner` #865) | holistic inline (not specialist dispatch) | Conditional — `full` only | Diff-scoped cleanup post-implementer, before `architect` gate |
| `hardener` | `full` | **Conditional specialist selection** per risk (exactly one): `security-reviewer` (still specialist, OWASP Top 10) **or** `reviewer` via `quality/deep-review` + one of `reviewer/references/{TYPESCRIPT,DATABASE,PERFORMANCE}_CHECKLIST.md` (archived specialists loaded inline) — see note | specialist / holistic inline | Conditional — `full` only, selected only if `hardening` risk present | Risk-based hardening pass (security / schema / perf / types) |
| `qa` | `full` | `qa-engineer` (backed by `e2e-runner` when browser/E2E warranted) | holistic (+ specialist opt-in) | Conditional — `full` only | Behavioral verification, lint gates (`megalinter*`), browser automation (`playwright-cli`/`chrome-devtools`), bug triage/incident decision, smoke/E2E |
| `designer` | `full` (optional) | `designer` | holistic | Optional — when UI surface in scope | Visual/UX routing among 11 design skills (`frontend-design*`, `figma*`, `accessibility/review`), contextual |

**Hardener note (post-#865):** 4 archived specialists (`typescript-reviewer` → `TYPESCRIPT_CHECKLIST.md`, `database-reviewer` → `DATABASE_CHECKLIST.md`, `performance-optimizer` → `PERFORMANCE_CHECKLIST.md`, plus `refactor-cleaner` now under `refactorer`) are **not** agents — holistic `reviewer` loads the reference inline during `deep-review`/`deslop`. Only `security-reviewer` remains a specialist. See `docs/AGENT_TAXONOMY.md` §3/§8 and `docs/SWARM_RECIPES.md` hardener line.

**Integrator note:** `integrator` is intentionally NOT promoted to a holistic persona — it is a runtime merge/approval responsibility executed by `architect` in `policy: integrator` + `receive_mode: batch` mode (single branch integration + human gate). This avoids terminology competition with the canonical `architect` while preserving the distinct permission/gate.

## 3. Recipe → roles tables (canonical persona per slot)

### pair (default — bugs, features, refactors)

| Role | Persona | Policy | Model profile |
|------|---------|--------|---------------|
| `implementer` | `implementer` | `writer` | `coding` |
| `reviewer` | `reviewer` (`code-reviewer` opt-in) | `reviewer-writer` | `review` |
| `integrator` | `architect` in integrator policy | `integrator` | `architecture` |

### team (medium features, schema, API)

| Role | Persona | Policy | Model profile |
|------|---------|--------|---------------|
| `planner` | `planner` | `read-only` | `planning` |
| `implementer` | `implementer` | `writer` | `coding` |
| `reviewer` | `reviewer` | `reviewer-writer` | `review` |
| `architect` (also `integrator`) | `architect` | `integrator` (batch) | `architecture` |

### full (security-sensitive, releases, migrations)

| Role | Persona | Policy | Model profile |
|------|---------|--------|---------------|
| `planner` | `planner` | `read-only` | `planning` |
| `implementer` | `implementer` | `writer` | `coding` |
| `refactorer` | `reviewer` inline | `writer` | `review` |
| `architect` (integrator) | `architect` | `integrator` (batch) | `architecture` |
| `hardener` | conditional (see §2) | `writer` | `hardening` |
| `qa` | `qa-engineer` (`e2e-runner` opt-in) | `writer` | `qa` |
| `designer` | `designer` (optional) | `writer` | `design` |

## 4. Invariants

1. **No parallel taxonomy:** every `spec.roles.<role>.persona` must be a canonical `agents/<name>/AGENT.md` name (or integrator mapped to `architect`). Tests assert this.
2. **Holistic ownership preserved:** swarm persona selection resolves via the same relationship metadata as direct `@mention` — no separate lookup table.
3. **Integrator/hardener/refactorer are not holistic:** they are runtime responsibilities. Do not add them to `agents/` or `holistic_owner`.
4. **Independent boundaries:** `review`/`qa`/`security`/`architecture` critique remain distinct from `implementer` (no self-approval).
5. **Conditional + lazy + elastic:** `planner`/`architect`/`designer` conditional by recipe; `hardener` conditional by risk; all roles lazy-start (only `planner` or `implementer` eager); `pair → team → full` promotion preserves run ID/artifacts/budget.

Related: `docs/AGENT_TAXONOMY.md` (11 holistic, 2 orchestrators, 6 specialists) · `docs/SWARM_RECIPES.md` · `docs/SWARM_ARCHITECTURE.md` · `docs/ARCHITECTURE.md` (Planes & Holistic taxonomy) · `skills/core/assistant/references/ORCHESTRATION.md` · `capabilities/skills/registry.yaml`
