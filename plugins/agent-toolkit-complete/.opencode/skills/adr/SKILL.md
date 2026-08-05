---
name: adr
description: >-
  WHAT — Create and maintain Architecture Decision Records (ADRs) per the process. Covers when to write an ADR, required sections, review, and linking to epics/PRs. English for cross-team artifacts unless the user asks otherwise.
---

# ADR — Architecture Decisions (WHAT)

**Template:** `references/default-template.md` — local reference for ADR structure and workflow.

## Default guardrails (before any final content)

1. Apply **`output-handshake`**: confirm **where** the final ADR will be recorded and that a **human** will review.
2. Then follow the steps below.

## When to use

Use **`decision-log`** for lightweight product/project/operational decisions and **`agreement`** for explicit commitments or terms among parties. Use this ADR skill only for durable architecture or technical decisions.

- A change has **long-term** architectural, security, data-model, or cost impact.
- You need **options with pros/cons** and a **record** for future readers (and for supersession later).
- The project needs decisions linked to PRDs, TRDs, tasks, PRs, diagrams, or other supporting artifacts.

## Instructions

1. **Confirm the decision qualifies** (new service, tech selection, schema change, deployment change, etc.) per the "When to Create an ADR" criteria.
2. **Draft** using the six-part structure: Title & status, Context, Options, Decision, Consequences, References (link **PRD/TRD**, tasks, PRs, diagrams as applicable).
3. **Review** with the tech lead / peers as in the workflow; keep ADRs **short and actionable** (clarity over completeness).
4. **Link** the ADR to the relevant **epic or story** and to **PRs** in the forge (use **`github-cli-workflow` / `gitlab-cli-workflow`** for PR text when applicable).
5. If an ADR is **superseded**, **preserve history**: update status and point to the replacement document.

## What not to do

- Do not use an ADR for one-line fixes with no long-term effect (use a normal task or PR description).
- Do not paste the full org policy into this skill; keep a single **canonical** copy in the wiki.

## References

- `output-handshake` — destination and review
- `references/default-template.md` — ADR structure and workflow
- `references/example-001-graphql-adoption.md` — example ADR for a GraphQL migration decision
- `trd` — where technical design references decisions
- `decision-log` — lightweight decisions
- `agreement` — explicit commitments or terms
- `workflow-generic-project` — traceability and plan approval
- `clickup-cli`, `jira-*` — ticket and comment operations (per engagement)
