---
name: clickup-cli
description: ClickUp CLI for managing tasks, sprints, comments, statuses, and Docs. Use when the user needs to interact with ClickUp — creating/editing tasks, checking sprint status, adding comments, linking PRs, managing Docs and pages, or searching tasks. Prefer this CLI over raw API calls.
---

# ClickUp CLI (`clickup`)

Use the `clickup` CLI instead of raw ClickUp API calls. Handles authentication, git integration,
fuzzy status matching, and custom fields automatically.

## When to use

- Create, edit, view, or search ClickUp tasks
- Check sprint status or recent tasks
- Add comments, link PRs/branches, or manage statuses
- Task IDs: `CU-abc123` or `86abc123`

## Out of scope

- Does NOT replace project management decisions — confirm scope with user first
- Does NOT push code or create PRs — delegate to **`github-cli-workflow`**

## Authentication

```bash
clickup auth login    # store API token
clickup auth status   # verify
```

Config: `~/.config/clickup/config.yml`. Supports per-directory defaults.

## Key rules

1. **Always `--current`** for sprint lists — IDs change every sprint, never hardcode them
2. **Fill ALL fields** when creating tasks (name, description, status, priority, assignee, tags, due-date)
3. **Check `clickup tag list`** before using tags — reuse existing ones
4. **Naming:** `[Work Type] Context — Action (Platform/Scope)` — see `references/task-management.md`
5. **Bulk ops:** pass multiple IDs as positional args; for subtasks view parent with `--json` first

## Quick commands

```bash
clickup task view                     # auto-detects from git branch
clickup task search "query"
clickup task recent --sprint
clickup task create --current --name "[Bug] Auth — Fix X (API)" --priority 2
clickup task edit CU-abc123 --status "in progress"
clickup status list                   # check valid statuses before setting
clickup sprint current
clickup inbox
```

## Common flags

| Flag | Description |
|------|-------------|
| `--json` | JSON output |
| `--jq <expr>` | Filter with jq |
| `--raw`, `-r` | Raw strings with `--jq` |

## References

- `references/task-management.md` — full task view/search/create/edit, naming conventions, multi-list, checklists, git integration
- `references/time-tracking.md` — log, list, timesheet commands
- `references/docs-management.md` — Docs and Pages management

## Other commands

```bash
clickup member list
clickup space list && clickup space select
clickup folder list && clickup folder select
clickup list list --folder 12345 && clickup list select
clickup chat send <channel-id> "message"
```
