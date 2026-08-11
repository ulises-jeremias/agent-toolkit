---
name: workflow-client-bootstrap
description: WHAT — Interactive interview to capture client delivery context and store it inside the user's
  ~/.ai-workspace (or similar) as packs + knowledge (no client skills). Use when onboarding a new client
  project or updating an existing workspace context.
origin:
  type: first-party
---
# Workflow Client Bootstrap

Use this skill to **create or update** a client-specific delivery context for any project.
It runs a structured interview and stores the result inside the user’s **workspace**
(`~/.ai-workspace`, `~/.ai-workspace`, or a workspace-like directory) as **packs + knowledge**
(not new skills).

**All generated files, PR text, and Jira/ClickUp comments must be in English.**

## When to use

- Onboarding a new client project that needs its own delivery workflow (beyond `workflow-generic-project`)
- Updating an existing workflow with new lifecycle states, repos, or guardrails
- Documenting a client's ticket lifecycle so future agent sessions can use correct status transitions

## Do not use when

- The project already has an up-to-date workflow skill and only a ticket or code change is needed
- The work fits entirely within `workflow-generic-project` without client-specific gates

## Interview process

Read `questions.yaml` (co-located with this skill) before starting. It defines multiple question groups.

| Group | Topics |
| --- | --- |
| **Identity** | Client name, slug, ticket system, docs platform, repo host |
| **Workflow** | Custom ticket statuses, done criteria, base branch, staging/QA gates |
| **Stack** | Repository list with roles, AGENTS.md presence, validation tools |
| **Conventions** | Branch naming, PR style, guardrails, Slack channel |

### Workspace root selection (mandatory)

Before asking client questions, resolve the workspace root directory:

1. Look for workspace-like directories (in order):
   - `~/.ai-workspace`
   - `~/.ai-workspace`
   - the current working directory if it looks like a workspace (has `packs/` and `knowledge/`)
   - other close matches (e.g. `~/*workspace*`) that contain both `packs/` and `knowledge/`
2. If exactly one plausible workspace is found, select it and print: `Using workspace: <path>`.
3. If multiple are found, present a numbered list and ask which one to use.
4. If none are found, explain the expected structure and ask the user for the path to use.

After selecting the path, clearly explain where answers will be stored (see **Storage explanation** below).

### Interview rules

1. Work through the groups **in order**: Identity → Workflow → Stack → Conventions.
2. Ask **all required questions**. Skip optional ones only if context already answers them.
3. Apply **conditional questions**: only ask `jira_project_key` if `ticket_system == jira`, etc.
4. After each group, briefly summarise what you collected and ask for corrections before moving on.
5. If the user shares a screenshot or diagram of the ticket workflow, extract statuses and transitions from it.
6. **Never generate files until the full interview is complete and the user has approved the summary.**

## Pre-generation summary (gate)

After the interview, present a structured summary:

```
Client:          <name>
Slug:            <slug>
Ticket system:   <system> (<key prefix if Jira>)
Docs platform:   <platform>
Repo host:       <host> / org: <org>
Base branch:     <branch>
Done status:     <status>
Has staging QA:  <yes/no>
Repos:           <list>
Validation:      <tools>
Branch naming:   <convention>
PR style:        <draft/direct>
Guardrails:      <list>

Files to generate:
  packs/clients/<slug>/pack.yaml
  knowledge/clients/<slug>/reference.md
  knowledge/clients/<slug>/workflow.md
  (optional) personas/clients/<slug>.md

Storage location: <workspace-root>/(paths above)
```

**Stop here and ask: "Does everything look correct? Shall I generate the files?"**
Do not proceed until the user explicitly confirms.

## File generation (workspace)

Generate files that follow the patterns below. Do **not** hardcode CLI commands inside the generated
SKILL.md — delegate those to the appropriate tool skills.

### Workspace outputs

Generate these files under the selected workspace root:

- `packs/clients/<slug>/pack.yaml`
- `knowledge/clients/<slug>/reference.md`
- `knowledge/clients/<slug>/workflow.md`
- (optional) `personas/clients/<slug>.md`

### Storage explanation (mandatory)

After selecting the workspace root, clearly explain:

- the chosen workspace directory path
- which exact files will be written (full paths)
- that this data is local to the workstation and only becomes shared if the workspace is committed/pushed
- how to load it later (e.g. via the workspace context loader, or by opening the pack/knowledge files)

## Post-generation steps

1. Write the files under the chosen workspace root.
2. If the workspace is a git repo and the user wants to share changes, create a commit there (English message) and open a PR as appropriate for that repo.
3. Otherwise, keep it local and provide the exact paths so the user can back it up or share it later.

## Updating an existing workflow

If the client already has a workflow skill:
1. Load the existing `SKILL.md` and `reference.md`.
2. Run only the interview groups relevant to what changed (ask the user which groups to revisit).
3. Show a diff summary before applying changes.
4. Follow the same commit/PR flow above.

## Delegation

| Need | Delegate to |
| --- | --- |
| Push branch and create draft PR | **github-cli-workflow** or **gitlab-cli-workflow** |
| Jira ticket operations | External **jira-*** skills |
| ClickUp ticket operations | **clickup-cli** |
| Repo discovery | **assistant** |

## Checklist

- [ ] All required interview questions answered
- [ ] Summary approved by user before file generation
- [ ] Generated files follow established patterns (use existing bundled skills as structure reference)
- [ ] `skill-catalog.yaml` updated with both new entries
- [ ] Agent wrappers created for Claude Code and opencode
- [ ] Commit and draft PR created; URL shared with user
