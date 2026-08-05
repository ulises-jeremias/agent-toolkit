# ClickUp CLI — Task Management Reference

## View & Search

```bash
clickup task view                          # auto-detects from git branch
clickup task view CU-abc123
clickup task view 86abc123 --json
clickup task view 86abc1 86abc2 86abc3 --json        # bulk, up to 10 parallel
clickup task view 86abc123 --recursive --json        # subtasks tree
clickup task search "login bug"
clickup task search "login bug" --exact
clickup task search "login bug" --assignee me
clickup task recent
clickup task recent --sprint
clickup task list --list-id 12345
clickup task list                          # uses configured default list
clickup task list --include-closed
```

**Navigating subtasks:** `--json` gives `subtasks[].id`, `start_date`, `due_date` inline.

## Task Naming Convention

Format: `[Work Type] Context — Action (Platform/Scope)`

| Component | Purpose | Examples |
|-----------|---------|----------|
| `[Work Type]` | Category | `[Bug]`, `[Feature]`, `[Refactor]`, `[Spike]`, `[Hotfix]`, `[Packdown]` |
| `Context` | Campaign or feature | `NT x THL`, `Auth v2` |
| `Action` | Imperative verb | `Fix timeout`, `Add SSO` |
| `(Platform)` | App or system | `(CamperMate)`, `(API)` |

Examples:

- `[Bug] Booking Flow — Fix timeout on slow connections (API)`
- `[Packdown] NT x THL — Remove CamperMate campaign landing page`
- `[Feature] Auth v2 — Add SSO support (CamperMate)`

Use `{Campaign}` placeholder for template tasks.

## Create & Edit

**Always fill ALL applicable fields. Always use `--current` not hardcoded sprint IDs.**

```bash
# Create with full details
clickup task create --current \
  --name "[Bug] Auth — Fix login timeout (API)" \
  --markdown-description "Users on 3G get timeout..." \
  --status "open" --priority 2 \
  --assignee 12345678 --tags "bug" --tags "auth" \
  --due-date 2026-03-01 --time-estimate 4h --points 3

# Create by list name
clickup task create --list-name "Sprint 89" --name "Fix bug" --status "open"

# Bulk create from JSON
clickup task create --current --from-file tasks.json
```

JSON format for `--from-file`:

```json
[
  {
    "name": "Design homepage",
    "description": "Create wireframes",
    "status": "open", "priority": 2,
    "due_date": "2026-03-15", "time_estimate": "4h",
    "tags": ["design"], "parent": "86abc123"
  }
]
```

```bash
# Edit
clickup task edit --status "in progress"
clickup task edit CU-abc123 --field "Environment=production"
clickup task edit --due-date 2026-03-01 --time-estimate 4h

# Bulk edit
clickup task edit 86abc1 86abc2 86abc3 --status "Closed"
clickup task edit 86abc1 86abc2 --add-tags "r&d"
clickup task edit CU-abc123 --remove-tags "fix"
clickup task edit CU-abc123 --clear-field "Environment"

# Tags — always check available first
clickup tag list

# Status management
clickup status set "in progress"
clickup status list
clickup status add "QA Review" --color "#7C4DFF"

# Delete
clickup task delete 86abc1 86abc2 86abc3 -y
```

**Bulk subtask workflow:** view parent with `--json` → extract `.subtasks[].id` → pass to `task edit`.

## Multi-List & Comments

```bash
clickup task list-add 86abc123 --list-id 901613544162
clickup task list-remove 86abc123 --list-id 901613544162

clickup comment add CU-abc123 "Looks good, @alice please review"
clickup comment list CU-abc123
clickup comment edit <comment-id> "Updated text"
```

## Git & GitHub Integration

```bash
clickup link pr                            # auto-detects branch
clickup link pr --task CU-abc123
clickup link pr 42 --task CU-abc123        # specific PR number
clickup link branch
clickup link commit
clickup link sync
```

## Checklists

```bash
clickup task checklist add <task-id> "Acceptance Criteria"
clickup task checklist item add <checklist-id> "Unit tests pass"
clickup task checklist item add <checklist-id> "Assigned item" --assignee 12345678
clickup task checklist item edit <checklist-id> <item-id> --assignee 12345678
```
