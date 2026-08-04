---
name: linear
description: Manage Linear issues, projects and cycles via the Linear MCP server. Use when the user wants to read, triage, create or update Linear tickets, plan a sprint, audit Linear documentation, or rebalance team workload.
---

# Linear

Structured workflow for managing Linear issues, projects and cycles through the
official Linear MCP server (`https://mcp.linear.app/mcp`, OAuth).

This skill assumes the MCP is wired into your AI tool. See
[`docs/MCP_TEMPLATES.md`](../../../../../../docs/MCP_TEMPLATES.md) and
`~/.local/share/agent-toolkit/mcp/linear/` for the managed template.

## When to use

- "Open a Linear ticket for X", "triage open bugs", "plan the next cycle".
- Sprint/cycle planning, retrospectives, documentation audits.
- Cross-project dependency review or workload rebalancing.
- Any natural-language request that maps onto Linear's MCP toolset.

## Prerequisites

1. Linear MCP server connected via OAuth in your AI tool of choice.
2. Workspace access to the relevant teams and projects.
3. agent-toolkit template available at `~/.local/share/agent-toolkit/mcp/linear/`
   (deployed by `chezmoi apply`).

## Setup (per AI tool)

The Linear MCP is a **streamable HTTP** endpoint with OAuth. Register it in
your AI tool of choice using the agent-toolkit template as reference:

| AI tool | Where to register |
|---------|-------------------|
| Claude Code | `~/.claude/mcp.json` (or via `claude mcp add`) |
| Cursor | `~/.cursor/mcp.json` |
| OpenCode | `~/.config/opencode/mcp.json` |
| Windsurf | `~/.codeium/windsurf/mcp_config.json` |

Copy `~/.local/share/agent-toolkit/mcp/linear/config.template.json` into the right
location and follow the OAuth prompt the first time you call a Linear tool.

> Windows / WSL note: if direct connections fail on Windows, run the MCP through
> WSL using `npx -y mcp-remote https://mcp.linear.app/sse --transport sse-only`
> as the command. The template includes a comment block with this fallback.

## Required workflow

**Follow the steps in order. Do not skip read-before-write.**

### Step 1 — Clarify scope

Confirm with the user:

- Team / project / cycle in scope.
- Goal (triage, planning, audit, rebalance, release planning).
- Filters that matter (priority, label, assignee, status).

### Step 2 — Pick the workflow and tools

Match the goal to a workflow (see "Practical workflows" below) and identify the
Linear MCP tools you will call. Confirm required identifiers (`issueId`,
`projectId`, `teamKey`) before invoking write actions.

### Step 3 — Execute in logical batches

1. **Read first** (`list_*`, `get_*`, `search_*`) to build context.
2. **Then write** (`create_*`, `update_*`, `create_comment`) with all required fields.
3. **For bulk operations**, explain the grouping logic before applying changes.

### Step 4 — Summarize and propose next actions

Surface remaining gaps, blockers, and follow-ups (extra issues, label changes,
re-assignments, follow-up comments).

## Available MCP tools

- **Issues**: `list_issues`, `get_issue`, `create_issue`, `update_issue`,
  `list_my_issues`, `list_issue_statuses`, `list_issue_labels`,
  `create_issue_label`
- **Projects & teams**: `list_projects`, `get_project`, `create_project`,
  `update_project`, `list_teams`, `get_team`, `list_users`
- **Docs & collaboration**: `list_documents`, `get_document`,
  `search_documentation`, `list_comments`, `create_comment`, `list_cycles`

## Practical workflows

- **Sprint planning** — review open issues for a team, pick top items by
  priority, create a new cycle with assignments.
- **Bug triage** — list critical/high bugs, rank by user impact, move top items
  to In Progress.
- **Documentation audit** — search docs (e.g. API auth), open labeled
  `documentation` issues for gaps with detailed fixes.
- **Workload balance** — group active issues by assignee, flag overloads,
  propose redistributions.
- **Release planning** — create a project (e.g. `v2.0 Release`) with milestones
  (feature freeze, beta, docs, launch) and generate issues with estimates.
- **Cross-project dependencies** — find all `blocked` issues, identify blockers,
  create linked issues if missing.
- **Status sweeps** — find your stale issues and add status comments based on
  current state/blockers.
- **Smart labeling** — analyze unlabeled issues, suggest/apply labels, create
  missing label categories.
- **Retrospectives** — report on the last completed cycle (completed vs pushed)
  and open discussion issues for recurring patterns.

## Boundaries

- All access is via the Linear MCP. **Do not** call the Linear REST/GraphQL API
  directly from this skill — that bypasses the auditable OAuth path.
- No bulk destructive actions without an explicit confirmation step from the user.
- Respect Linear API rate limits — batch reads, paginate, cache filters.

## Troubleshooting

- **Auth**: clear browser cookies, re-run OAuth, verify workspace permissions
  and that API access is enabled for your account.
- **Tool errors**: confirm your AI tool supports parallel tool calls; supply all
  required fields; split complex requests into smaller calls.
- **Missing data**: refresh the OAuth token, verify workspace access, check for
  archived projects, confirm correct team selection.
- **Performance**: respect rate limits — batch bulk ops, use specific filters,
  cache frequent queries.

## Validation

- `dots-doctor` lists the Linear MCP template under `mcp/linear/` once
  `chezmoi apply` has run.
- The first MCP tool call triggers the OAuth flow; from then on the AI tool
  caches the session.
