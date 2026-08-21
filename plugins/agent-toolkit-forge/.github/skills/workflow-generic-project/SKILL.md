---
name: workflow-generic-project
description: 'WHAT — Generic client delivery: Jira or ClickUp, full repo context, human gates, English
  traceability on tickets, draft PR via delegated forge skills. Use workspace packs for client/account
  overlays.'
origin:
  type: first-party
---
# Workflow — Generic Project (WHAT)

**All skill instructions, ticket comments, and PR text must be in English.**

This workflow supports client delivery phases and gates. Apply any client/account constraints by loading the appropriate workspace pack first.

## Mode selection (mandatory)

- Use **this skill** for client delivery phases and gates.
- If the task is in a specific client/account context, load the corresponding workspace pack overlay first.
- If unclear → **ask** which engagement context to use before proceeding.

## Delegation (HOW lives in tool skills)

| Need | Delegate to |
| --- | --- |
| ClickUp tasks, comments, status | **clickup-cli** |
| Jira issue ops, comments, dev links | External **jira-*** skills (e.g. via **jira-assistant** router; CLI: `jira-as`) per repo docs |
| Confluence pages, search | External **confluence-*** skills (e.g. via **confluence-assistant** router; CLI: `confluence-as`) per repo docs |
| Planning and estimation | **planning** |
| Default development workflow / validation fallback | **development-workflow** |
| Work item structure and templates | **work-item**, **epic**, **user-story**, **task**, **bug**, **incident** |
| Meetings, decisions, agreements, spikes | **meeting-minutes**, **decision-log**, **agreement**, **spike** |
| Project assessments, evidence maps, technical/management unit scorecards | **project-assessment**, **project-assessment-evidence**, **technical-unit-assessment**, **management-unit-assessment** |
| PRD / TRD / ADR structure (templates) | **prd**, **trd**, **adr** (WHAT; see local template references inside each skill) |
| Where to save a deliverable + human review | **output-handshake** (WHAT; always before final deliverables and PR/MR text) |
| Default PR body when the repo has no template | **pr-fallback** (WHAT) then **github-cli-workflow** (HOW) |
| Draft PR on GitHub after push | **github-cli-workflow** |
| Draft MR on GitLab after push | **gitlab-cli-workflow** |
| Repository discovery and conflicts | **assistant** |

Do **not** paste forge or ticket CLI sequences here; open the tool skill and follow it.

## Principles

1. **Context:** Pull Jira, ClickUp, Confluence, and linked docs the task references; treat them as source of truth with the codebase (**assistant** inspection order).
2. **Repo standards:** Follow `AGENTS.md`, CONTRIBUTING, PR templates, and documented Docker or devcontainer flows.
3. **Human in the loop:** Confirm understanding and plan **before** substantial implementation; get explicit approval **before** finalizing PR text; escalate when context is missing.
4. **Validation first:** Align on acceptance criteria and approach before deep implementation.
5. **Traceability:** Add concise English comments on the **original** ticket for plan approval, meaningful milestones, and PR link—no duplicate full PR bodies in tickets.

## Phases (gates)

1. **Intake:** Identify ticket IDs and engagement context; retrieve linked docs via appropriate skills.
2. **Discovery:** Analyze repo per **assistant**; note CI, templates, dev environments.
3. **Plan:** Written plan → **stop for user approval.** No implementation until approved.
4. **Plan traceability:** After plan approval, post a short ticket comment (delegate comment mechanism to **clickup-cli**, **jira-*** or **confluence-*** as applicable).
5. **Implement:** Work in logical commits per repo conventions; self-review.
6. **Push and draft PR/MR:** Push branch, then invoke **github-cli-workflow** or **gitlab-cli-workflow** for a **draft**; confirm title/body with the user.
7. **Close loop:** Post final short ticket comment with PR link (via same ticket skills as above).

## Branch naming (intent)

Prefer **`<short-username>/<WORK_ITEM_ID>-<short-slug>`** (lowercase). Resolve username per repo or user preference; base branch per repo default (**main**, **develop**, etc.).

## Session override

If the user requests **local-only** work: skip push/PR automation; note limitations in ticket updates if still posting.

## Safety

- Never commit secrets; no force-push to shared defaults unless the user explicitly requests recovery steps.

## Checklist

- [ ] Engagement context (if any) confirmed
- [ ] Work item + doc context retrieved
- [ ] Plan approved before code; ticket comment after plan approval
- [ ] Repo standards (template, devcontainer) respected
- [ ] Draft PR/MR via **github-cli-workflow** or **gitlab-cli-workflow** (or documented fallback)
- [ ] Final traceability comment with PR link when applicable
