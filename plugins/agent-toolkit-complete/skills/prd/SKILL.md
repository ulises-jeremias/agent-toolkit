---
name: prd
description: >-
  WHAT — Draft and review a Product Requirements Document (PRD) using the template. Business-level requirements, acceptance criteria, and traceability. Does not replace the product owner. English for tickets, PRs, and client-facing text unless the user asks otherwise.
---

# PRD — Product Requirements (WHAT)

**Template:** `references/default-template.md` — local reference, kept up to date with the standard structure.

## Default guardrails (before any final content)

1. Apply **`output-handshake`**: confirm **where** the final PRD will be stored (path, Doc page, task, paste-only, etc.) and that a **human** will review. Engagements may store PRDs in different places; do not assume.
2. Then follow the steps below.

## When to use

- A feature or product increment needs a **shared agreement** on scope, users, and acceptance.
- The team must **trace** work from PRD → implementation → tests.
- An engagement uses an **Operations**-style doc hub with linked requirements documents.

## Instructions

1. **Open the PRD template** (`references/default-template.md`) and keep section headings **aligned** with it: Objective, User flow / Personas, Entities & use cases, Acceptance criteria, Edge cases, Integrations, Timeline, Approvals.
2. For **discovery** in an existing repository, delegate repository inspection to **`assistant`**; cite `AGENTS.md` and test/lint commands from the project.
3. **Acceptance criteria** must be testable and in **English** for work items/PRs (match `workflow-generic-project`).
4. Link **stakeholder approval** to your engagement process (task lists, doc pages, or client sign-off). Do not invent sign-off if not agreed.
5. For **ticket updates**, use the appropriate tool (`clickup-cli`, `jira-*`, etc.) to post a short plan comment or attach links — do not paste the full document into a task; link the Doc or page when possible.

## What not to do

- Do not copy the full text of an external template into this skill; use `references/default-template.md` as the local canonical reference.
- Do not skip **edge cases** or **integrations** when the PRD is meant for handoff to a TRD.

## References

- `output-handshake` — destination and review (required first for final output)
- `references/default-template.md` — local PRD template
- `references/example-unified-api.md` — PRD example for an API strategy initiative
- `workflow-generic-project` — delivery phases and ticket traceability
- `trd` — next step for technical design from an approved PRD
- `planning` — estimation and capacity before commitment
- `epic`, `user-story`, `task` — downstream breakdown
- `clickup-cli`, `jira-*` — ticket / comment operations (per engagement)
