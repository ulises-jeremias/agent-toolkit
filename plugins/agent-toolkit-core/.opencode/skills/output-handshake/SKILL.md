---
name: output-handshake
description: >-
  WHAT — Default gate for any deliverable: confirm where the final artifact will be stored and that a human will review, before writing PRDs, TRDs, ADRs, or PR bodies. Repository paths, wikis, and ticket tools differ by engagement; never assume a single location.
---

# Output handshake (WHAT)

**Use first** when producing a **final** version of any deliverable that will leave the chat session: PRD, TRD, ADR, work item, planning notes, workflow/validation summary, project assessment, assessment scorecard, evidence map, meeting minutes, decision log, agreement, incident report, spike, or PR/MR body.

## Default behavior (always)

1. **Destination** — Ask explicitly: *where should the final content live?* (Examples: a path in `docs/`, a file in a repo, a page in a documentation tool, a task/Doc description, paste-only, or a combination.) Do **not** default to a location without the user (or the engagement pack) saying so.
2. **Review** — State that a **human** must review before the artifact is considered approved; the assistant does not substitute for that review.
3. Then proceed with the relevant skill (**`prd`**, **`trd`**, **`adr`**, **`work-item`**, **`planning`**, **`development-workflow`**, **`project-assessment`**, **`project-assessment-evidence`**, **`technical-unit-assessment`**, **`management-unit-assessment`**, **`meeting-minutes`**, **`decision-log`**, **`agreement`**, **`incident`**, **`spike`**, **`pr-fallback`** + forge workflow, etc.).

## Boundaries

- This skill does not contain org templates; those stay in the specific artifact skills and their `references/default-template.md` files.

## See also

- `workflow-generic-project` — delivery gates
- `assistant` — discover existing `docs/`, PR templates, `AGENTS.md`
