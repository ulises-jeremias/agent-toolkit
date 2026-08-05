---
name: development-workflow
description: >-
  WHAT - Default development workflow, task lifecycle, DoR, DoD, validation, and evidence model when a project has no explicit override. Repository instructions still take precedence.
---

# Development Workflow Fallback (WHAT)

Use this skill when a project has no documented workflow override and you need the default expectations for delivery stages, validation, evidence, and traceability.

## Priority order

1. Repository `AGENTS.md`, CONTRIBUTING, PR templates, CI, and project docs.
2. Engagement pack or ticket-specific workflow.
3. This default workflow fallback.

## Default flow

Backlog -> Ready TODO/TODO -> In Progress -> Blocked (if needed) -> Ready for Review -> Ready for Acceptance -> Ready for QA -> Ready for Release -> Closed.

## Validation model

- Definition of Ready before starting development.
- Definition of Done before completion.
- Code review and CI validation.
- Evidence-based validation: tests, screenshots/recordings when relevant, comments, linked PRs, linked work items.
- Traceability from PRD to Task to PR to Deployment.

## References

- `references/default-workflow-checklist.md` - default lifecycle and validation checklist (use as-is or adapt per project)
- `pr-fallback` - default PR/MR body when a repo lacks templates
- `workflow-generic-project` - delivery gates
