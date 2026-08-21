# Orchestration — Domain → Skill Routing

Hand-maintained routing table for the **assistant** orchestrator and **dev-companion** delegation.
For machine-readable triggers and `depends_on`, also read bundled `skill-catalog.yaml`.

**Rule:** **WHAT** skills (workflows, companion framing) define phases and gates; **HOW** skills
(forge, tooling, integrations) own CLI/API procedures — do not inline HOW steps inside WHAT skills.

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

## Design

| Domain | Skills | When to route |
|--------|--------|---------------|
| Figma | **figma**, **figma-implement-design**, **figma-code-connect-components** | Design-to-code, MCP |
| Visual design | **frontend-design**, **frontend-design-review** | UI aesthetics and review |
| Guidelines | **web-design-guidelines** | Vercel web interface guidelines |

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

## Agents vs skills

**Agents** (`@code-reviewer`, `@planner`, …) are personas invoked by @mention — not loaded via the
skill tool. Agents **delegate to skills** listed in their `AGENT.md` "Delegate to skills" section.

When routing: pick **one workflow driver** per task (**dev-companion** + **workflow-generic-project**
for generic delivery); use HOW skills for all CLI operations.
