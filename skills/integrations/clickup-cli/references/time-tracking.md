# ClickUp CLI — Time Tracking Reference

```bash
# Log time
clickup task time log --duration 2h
clickup task time log 86abc123 --duration 1h30m --description "Auth flow"
clickup task time log --duration 45m --date 2026-01-15
clickup task time log --duration 3h --billable
clickup task time log 86abc123 --duration 2h --assignee 54874661

# Bulk log from file
clickup task time log --from-file entries.json
```

JSON format:

```json
[
  {"task_id": "86abc123", "duration": "2h", "date": "2026-03-15",
   "description": "Feature work", "assignee": "54874661"},
  {"task_id": "86abc456", "duration": "1h30m", "date": "2026-03-15"}
]
```

```bash
# List time entries
clickup task time list
clickup task time list 86abc123 --json

# Timesheet (date range → timesheet mode)
clickup task time list --start-date 2026-02-01 --end-date 2026-02-28
clickup task time list --start-date 2026-02-01 --end-date 2026-02-28 --assignee 54695018
clickup task time list --start-date 2026-03-01 --end-date 2026-03-31 --assignee id1,id2,id3
clickup task time list --start-date 2026-02-01 --end-date 2026-02-28 --assignee all

# Include tags in output (for CapEx auditing)
clickup task time list --start-date 2026-03-01 --end-date 2026-03-31 --include-tags --json
```
