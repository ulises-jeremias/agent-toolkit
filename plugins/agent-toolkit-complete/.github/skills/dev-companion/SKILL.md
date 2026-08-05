---
name: dev-companion
description: >-
  WHAT — Dev Companion (general): layered companion for client delivery; modes, gates,
  delegation to assistant and workflow-generic-project; no CLI matrices.
---

# Dev Companion (WHAT) — general layer (L2)

This skill is the **general** dev companion for work. It does **not** replace **`assistant`** (orchestrator); it **sits above** workflows and names **what to invoke next**.

**Language:** English for ticket comments, PR text, and user-facing outputs when this companion drives delivery work.

## Layering

| Layer | Skill | Role |
| --- | --- | --- |
| L1 | **assistant** | Repo inspection order, conflict resolution, fallback |
| **L2 (this skill)** | **dev-companion** | Companion framing: modes, gates, delegation for client work |
| L3 | **Workspace pack overlay** | Client/account-specific context loaded from `~/.ai-workspace/packs/` |

If engagement triggers match, load the appropriate **workspace pack overlay** first, then proceed with **workflow-generic-project**. Do not mix multiple workflow drivers on the same task.

## Mode selection

- **Default** for /client delivery: use **workflow-generic-project** for phased delivery.
- If the user mentions an engagement, ticket prefix, or repo context → load the matching pack from the workspace (overlay) and apply its boundaries/gates.
- If unclear → **ask** before applying L3.

## Delegation (HOW is in other skills)

| Need | Delegate to |
| --- | --- |
| Discovery, AGENTS conflict handling | **assistant** |
| Generic client delivery phases | **workflow-generic-project** |
| Planning / default workflow / validation | **planning** / **development-workflow** |
| Work items, incidents, meetings, decisions, agreements, spikes | **work-item**, **incident**, **meeting-minutes**, **decision-log**, **agreement**, **spike** |
| Project assessments, evidence maps, technical/management unit scorecards | **project-assessment**, **project-assessment-evidence**, **technical-unit-assessment**, **management-unit-assessment** |
| ClickUp | **clickup-cli** |
| Jira | External **jira-*** pack (**jira-assistant** router; CLI: `jira-as`) |
| Confluence | External **confluence-*** pack (**confluence-assistant** router; CLI: `confluence-as` or `confluence`) |
| Draft PR GitHub / GitLab | **github-cli-workflow** / **gitlab-cli-workflow** (for default body when the repo has no template: **pr-fallback** first) |
| Where to save deliverables + human review | **output-handshake** |
| UI depth | **ui-ux-pro-max** |
| Workstation health | **triage** |

Do **not** paste forge or ticket CLI sequences here.

## Operating modes

- **Interactive (default):** IDE session; user steers each step.
- **Queued job (optional):** only when a local runner is configured; see `~/.local/share//dev-companion/README.md` (installed from chezmoi) and **references/LOOP_GUARDRAILS.md**.

The queue worker is **mandatory infrastructure** (installed by workstation). The **workspace** (`~/ai-workspace`) is optional — it provides project-aware wrappers, job templates, and knowledge base integration. When both are present, the runner automatically enriches LLM prompts with workspace context (`projects.yaml`, `projects/`, `knowledge/todos/`).

### LLM policy gate (client engagements)

Before queueing background jobs for a client repo, confirm the active LLM policy with **`devcompanion llm-status`**. If the engagement requires a single AI account (e.g. only the customer's Anthropic key), the workstation/pack must set **`DOTS_WORKSTATION_DEVCOMPANION_LLM_ALLOWLIST`** and **`DOTS_WORKSTATION_DEVCOMPANION_LLM_STRICT=1`** so the runner fails closed instead of falling back to OpenCode. For Cursor/Copilot-only engagements, prefer **`run-once --no-llm`** (skeleton plan) plus IDE-driven execution. Full reference: **`docs/DEV_COMPANION_LLM.md`**.

## Checklist

- [ ] L3 not needed; if needed, user confirmed engagement context
- [ ] **assistant** discovery pass before large edits
- [ ] **workflow-generic-project** phases and gates when doing generic client delivery
- [ ] Tool skills used for all CLI operations
