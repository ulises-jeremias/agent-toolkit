# ClickUp CLI — Docs & Pages Reference

> API limitation: Delete, archive, and restore for Docs/Pages are not available via the public v3 API.

## Docs

```bash
clickup doc list
clickup doc list --json
clickup doc list --parent-id 123456 --parent-type SPACE
clickup doc list --archived
clickup doc view <doc-id>
clickup doc view <doc-id> --json

# Create
clickup doc create --name "Project Runbook"
clickup doc create --name "Team Wiki" \
  --parent-id 123456 --parent-type SPACE --visibility PUBLIC
clickup doc create --name "Drafts" --create-page=false
```

## Pages

```bash
clickup doc page list <doc-id>
clickup doc page list <doc-id> --max-depth 0
clickup doc page view <doc-id> <page-id>
clickup doc page view <doc-id> <page-id> --content-format text/md

# Create
clickup doc page create <doc-id> --name "Introduction"
clickup doc page create <doc-id> --name "Setup Guide" \
  --content "# Setup\n\nFollow these steps..." --content-format text/md
clickup doc page create <doc-id> --name "Advanced Config" \
  --parent-page-id <parent-page-id>

# Edit (replace / append / prepend)
clickup doc page edit <doc-id> <page-id> --content "New content"
clickup doc page edit <doc-id> <page-id> \
  --content "## Release Notes\n\n- Fixed bug X" --content-edit-mode append
clickup doc page edit <doc-id> <page-id> --name "Updated Title"
```

## JSON-first agent patterns

```bash
clickup doc list --jq '.[].id'
clickup doc page list <doc-id> --jq '.pages[].id'

# Append release notes
clickup doc page edit <doc-id> <page-id> \
  --content "## v1.2.3\n\n- Fixed auth timeout" \
  --content-edit-mode append --content-format text/md

# Capture new doc ID
clickup doc create --name "Sprint Retro" --json | jq -r '.id'
```
