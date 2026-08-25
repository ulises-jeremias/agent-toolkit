# Orchestration — Domain → Skill Routing

Hand-maintained routing table for the **assistant** orchestrator and **dev-companion** delegation.
For machine-readable routing, triggers, owners, and overlap, read `capabilities/skills/registry.yaml`
(validated by `schemas/skill-capability-registry.schema.json` and `docs/SKILL_ROUTING.md`); `catalogs/skill-catalog.yaml`
remains the generated id→description index. For canonical holistic roster + migration map + proportional routing examples, read `docs/AGENT_TAXONOMY.md` (#864).

**Rule:** **WHAT** skills (workflows, companion framing) define phases and gates; **HOW** skills
(forge, tooling, integrations) own CLI/API procedures — do not inline HOW steps inside WHAT skills.

**Design routing rule (#863):** The **designer** agent owns contextual selection among the 10 `design/*`
plus `accessibility/review` skills. Do not mechanically chain all design skills on one task — pick one
primary driver per task (see Design section and `docs/SKILL_ROUTING.md`).

**Holistic taxonomy rule (#864):** 11 holistic owners (`assistant`, `planner`, `architect`, `designer`, `implementer`, `reviewer`, `qa-engineer`, `security-engineer`, `platform-engineer`, `researcher`, `data-engineer`) own every skill — `specialist_agents` are opt-in only when `specialist_justified: true`. See `docs/AGENT_TAXONOMY.md` §1–3 for migration map and §5–6 for proportional delegation examples and 20 routing self-tests.

---

## Core and session

| Domain | Skills | When to route |
|--------|--------|---------------|
| Orchestration | **assistant** (this skill) | Default entry; repo discovery; conflict resolution |
| Delivery companion | **dev-companion** | Client/account delivery framing; modes and gates |
| Workspace memory | **workspace-knowledge-sync** | Persist learnings/todos across sessions |
| Handoff | **output-handshake** | Where to save deliverables; human review gates |
| Onboarding | **onboarding** | New developer / toolkit setup |

---

## Delivery (WHAT)

| Domain | Skills | When to route |
|--------|--------|---------------|
| Generic client delivery | **workflow-generic-project** | Phased delivery without account-specific pack |
| Planning | **planning**, **development-workflow** | Feature planning, validation gates |
| Work items | **work-item**, **task**, **user-story**, **epic**, **bug**, **spike** | Ticket-shaped artifacts |
| Assessments | **project-assessment**, **technical-unit-assessment**, **management-unit-assessment** | Scorecards and evidence |
| Artifacts | **adr**, **prd**, **trd**, **decision-log**, **agreement**, **meeting-minutes**, **incident** | Structured docs |

**depends_on:** delivery workflows delegate CLI/ticket operations to forge and integrations skills.

---

## Forge (HOW)

| Domain | Skills | When to route |
|--------|--------|---------------|
| GitHub PR lifecycle | **github-cli-workflow**, **gh-address-comments**, **pr-fallback** | Push branch, draft PR, address review |
| GitLab MR lifecycle | **gitlab-cli-workflow** | GitLab equivalent |
| CI failures | **gh-fix-ci** | GitHub Actions log triage and fix planning |
| Merge conflicts | **fix-merge-conflicts** | Rebase/merge conflict resolution |
| Worktrees | **worktree** | Parallel branch work |
| Contribution planning | **gh-contribution-planner** | Multi-PR contribution strategy |

**depends_on:** **gh-fix-ci** pairs with **planning** before code changes; PR skills pair with **output-handshake**.

---

## Quality / craft

Reserved for anti-slop, static analysis, and deep review. Skills in this section ship in
**agent-toolkit-complete** and **agent-toolkit-craft** (not core).

| Domain | Skills | When to route |
|--------|--------|---------------|
| Prose / docs anti-slop | **unslop** | PR descriptions, comments, docs before final review |
| Diff-scoped code slop | **deslop** | Cleanup redundant code in changed hunks only |
| Change impact | **blast-radius** | Scope and risk before large refactors |
| Linters | **megalinter-check**, **megalinter-fix**, **megalinter-setup** | Repo-wide or configured lint gates |
| Security static analysis | **codeql** | CodeQL workflows and queries |
| Deep review | **deep-review** | Escalated review rubric (optional; pairs with **code-reviewer** agent) |

**depends_on:**

- **deslop** complements **unslop** (code vs prose); run **unslop** on user-facing text first.
- **blast-radius** may reference **unslop** for communication clarity on large changes.
- **megalinter-*** and **codeql** are independent static gates; do not substitute for **deslop**.

---

## Design (designer agent owns contextual routing — `docs/SKILL_ROUTING.md` + `agents/designer/AGENT.md`)

| Scenario | Route to |
|----------|----------|
| New visual direction / creative frontend (greenfield or intentional reshaping) | `design/frontend-design` |
| Existing frontend quality / design review (PR, component, flow, theme, design-system compliance) | `design/frontend-design-review` |
| Concrete web-interface best-practice audit (`file:line`, forms/focus/animation, Vercel WIG) | `design/web-design-guidelines` |
| Evidence-based holistic UX/UI diagnosis (visual, UX friction, a11y, responsive, system compliance, distinctiveness, perf) | `design/design-assessment` (+ `delivery/project-assessment-evidence` if no evidence map yet) |
| Iterative browser-grounded remediation (implement → run → capture → re-review until Blocking cleared) | `design/design-improvement` (consumes `design-assessment` findings; requires rendered evidence) |
| Figma-driven work | `design/figma` → `figma-implement-design` (node → code 1:1), `figma-code-connect-components` (Code Connect), `figma-create-design-system-rules` (`AGENTS.md` rules), `figma-create-new-file` (new file via `whoami`); canvas Plugin API → opt-in `figma-use` pack |
| Accessibility-sensitive UI (needs WCAG 2.2 AA, SC mapping, mode-aware findings) | `accessibility/review` |

**Anti-pattern — do not mechanically chain:** `design-assessment` → `frontend-design-review` → `web-design-guidelines` → `frontend-design` → `design-improvement` on every ticket. Typically one of (assessment **or** review **or** guidelines) plus at most one Figma skill and optionally `accessibility/review`; `design-improvement` only after an assessment exists. See `capabilities/skills/registry.yaml` for `overlap`/`contraindications` and `agents/designer/AGENT.md` five-scenario test.

---

## Tooling (HOW)

| Domain | Skills | When to route |
|--------|--------|---------------|
| CLI design for agents | **cli-for-agents** | Building or reviewing agent-facing CLIs |
| Browser automation | **playwright-cli** | Shell-driven browser tasks |
| E2E test specs | **e2e-runner** | Playwright test authoring (not **playwright-cli**) |
| Notebooks | **jupyter-notebook** | Jupyter scaffolding |
| Inventory | **inventory**, **herdr** | Repo/tool inventory, swarm herdr |

---

## Integrations (HOW)

| Domain | Skills | When to route |
|--------|--------|---------------|
| Slack | **slack-cli**, **slack-assistant** | App CLI vs workspace chat |
| Linear | **linear** | Linear MCP |
| ClickUp | **clickup-cli** | ClickUp tasks and docs |
| MCP setup | **mcp** | MCP server configuration patterns |

Jira and Confluence skills ship via external packs when installed.

---

## Ops

| Domain | Skills | When to route |
|--------|--------|---------------|
| Health | **triage** | Workstation/doctor diagnostics |
| Swarm | **swarm**, **swarm-handoff**, **swarm-observer** | Multi-agent tmux workflows |
| Cost | **llm-cost-advisor** | Model/cost guidance |
| Docs generation | **docs-generator** | Bulk doc generation |

---

## Agent taxonomy — holistic / orchestrator / specialist (#864)

`docs/AGENT_TAXONOMY.md` is canonical. Summary:

| Tier | Members | How `assistant` routes |
|------|---------|------------------------|
| Orchestrator | `assistant` (default entry), `client-workflow-bootstrap` (meta-generator → packs/knowledge) | Implicit — decide intent → pick one holistic |
| Holistic (daily, 11) | `assistant` (as orchestrator), `planner`, `architect`, `designer`, `implementer`, `reviewer`, `qa-engineer`, `security-engineer`, `platform-engineer`, `researcher`, `data-engineer` (conditional) | Proportional: tiny change → `implementer`→`reviewer`; UI feature → `designer`→`implementer`→`reviewer`+`qa-engineer`; cross-system → `architect`+`planner`→`blast-radius`; security-sensitive → `security-engineer` early + `architect` |
| Specialist (opt-in) | `code-reviewer`/`security-reviewer`/`agentic-security-reviewer`/`e2e-runner`/`tdd-guide`/`refactor-cleaner`/`build-error-resolver`/`tech-assistant` + deferred `database-reviewer`/`performance-optimizer`/`typescript-reviewer`/`docs-lookup`/`reference-lookup` | Only when `specialist_justified: true` in registry or task explicitly warrants narrow technique |

Never mechanically chain all skills in a domain — selection is contextual (see `docs/AGENT_TAXONOMY.md` §5–6).

## Agents vs skills

**Agents** (`@code-reviewer`, `@planner`, …) are personas invoked by @mention — not loaded via the
skill tool. Agents **delegate to skills** listed in their `AGENT.md` "Delegate to skills" section.

When routing: pick **one workflow driver** per task (**dev-companion** + **workflow-generic-project**
for generic delivery); use HOW skills for all CLI operations.
