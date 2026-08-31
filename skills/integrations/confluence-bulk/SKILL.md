---
name: confluence-bulk
description: Bulk operations for 50+ pages - updates, moves, deletions, labels, and permissions. Use when
  updating multiple pages simultaneously (dry-run preview included), needing rollback safety, or coordinating
  team changes. Handles partial failures gracefully.
triggers:
- bulk
- multiple pages
- batch
- mass update
- bulk delete
- bulk label
- bulk move
- all pages in space
- many pages
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-bulk
  ref: 9cd07b2070b9aa0f4c6a15690306101727efe94a
  license: MIT
  version: 9cd07b2
trust:
  tier: experimental
  reviewed_at: '2026-08-31'
  reviewed_by: ulises-jeremias
maintenance:
  status: active
  last_checked: '2026-08-31'
distribution:
  mode: vendored
  redistribution_allowed: true
  attribution_file: LICENSE
security:
  scripts: false
  shell: false
  network: true
  mcp: false
  hooks: false
---

# Confluence Bulk Skill

Bulk operations for Confluence content management at scale - updates, moves, deletions, labels, and read restrictions.

---

## ⚠️ PRIMARY USE CASE

**This skill performs bulk operations on multiple pages.** Use for:
- Updating multiple pages simultaneously
- Bulk labeling/unlabeling content
- Moving many pages between spaces
- Bulk read-restriction changes (page view access)
- Mass deletion with dry-run preview

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| Update 10+ pages | - |
| Bulk label operations | - |
| Move pages between spaces | - |
| Bulk delete with preview | - |
| Single page operations | `confluence-page` |
| Search for pages | `confluence-search` |
| Single label add/remove | `confluence-label` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| Bulk label add | ⚠️ | Can be undone |
| Bulk label remove | ⚠️ | Can be undone |
| Bulk update | ⚠️⚠️ | Modifies content |
| Bulk move | ⚠️⚠️ | Changes hierarchy |
| Bulk permission (read restrictions) | ⚠️⚠️ | Can lock out users not on the restriction list |
| Bulk delete | ⚠️⚠️⚠️ | **DESTRUCTIVE** - pages go to trash (restorable ~30 days, manually per page); use dry-run first |

**Always use `--dry-run` for destructive operations!**

---

## When to Use This Skill

Use this skill when you need to:
- Update **multiple pages** with the same change
- Add or remove **labels from many pages** at once
- **Move pages** between spaces or under different parents
- **Delete multiple pages** with preview capability
- Manage **read restrictions on many pages** simultaneously
- Execute operations with **dry-run preview** before making changes
- Handle **partial failures** gracefully with progress tracking

**Scale guidance:**
- 5-10 pages: Run directly, no special options needed
- 50-100 pages: Use `--dry-run` first, then execute
- 500+ pages: Consider off-peak hours; use `--batch-size` for label add operations

---

## Quick Start

```bash
# Preview before making changes
confluence-as bulk label add --cql "space = DOCS AND type = page" --labels "approved" --dry-run

# Execute the labeling
confluence-as bulk label add --cql "space = DOCS AND type = page" --labels "approved"

# Bulk delete with preview
confluence-as bulk delete --cql "space = ARCHIVE AND created < '2023-01-01'" --dry-run
```

---

## CLI Commands

| Command | Purpose | Risk | Example |
|---------|---------|------|---------|
| `confluence-as bulk label add` | Add labels to pages | ⚠️ | `--cql "..." --labels "tag1,tag2"` |
| `confluence-as bulk label remove` | Remove labels from pages | ⚠️ | `--cql "..." --labels "old-tag"` |
| `confluence-as bulk update` | Update page properties | ⚠️⚠️ | `--cql "..." --title-prefix "[Archive]" --title-suffix " (Old)"` |
| `confluence-as bulk move` | Move pages to new location | ⚠️⚠️ | `--cql "..." --target-space NEWSPACE` |
| `confluence-as bulk delete` | **Delete pages (moves them to trash)** | ⚠️⚠️⚠️ | `--cql "..." --dry-run` |
| `confluence-as bulk permission` | Manage page read restrictions | ⚠️⚠️ | `--cql "..." --add-group GROUP` / `--remove-group GROUP` / `--add-user USERID` / `--remove-user USERID` |

---

## Common Options

All commands support these options, except `--batch-size`, which only `bulk label add` accepts:

| Option | Purpose | When to Use |
|--------|---------|-------------|
| `--dry-run` | Preview changes | **Always** use for ⚠️⚠️+ operations |
| `--yes` / `-y` | Skip confirmation | Scripted automation |
| `--max-pages N` | Limit scope (default: 100) | Testing, large operations |
| `--batch-size N` | Control batching (**`bulk label add` only**, default: 50) | 500+ pages or rate limits |
| `--output json` | JSON output | Scripting, pipelines |

The global `-o/--output` flag placed before the subcommand (e.g. `confluence-as -o json bulk update ...`) sets the default output format for all subcommands; an explicit subcommand-level `--output` wins.

---

## Examples

### Bulk Label Operations

```bash
# Add labels to all pages in a space
confluence-as bulk label add --cql "space = DOCS AND type = page" --labels "documentation"

# Add multiple labels
confluence-as bulk label add --cql "space = DOCS AND label = 'api'" --labels "reviewed,approved"

# Remove labels
confluence-as bulk label remove --cql "space = ARCHIVE" --labels "active,current"

# Preview first
confluence-as bulk label add --cql "space = DOCS" --labels "new-tag" --dry-run
```

### Bulk Move Operations

```bash
# Move pages to different space
confluence-as bulk move --cql "space = OLD AND type = page" --target-space NEW --dry-run

# Move under specific parent
confluence-as bulk move --cql "label = 'archive-ready'" --target-parent 12345 --dry-run

# Execute after preview
confluence-as bulk move --cql "space = OLD" --target-space NEW --yes
```

### Bulk Delete (DESTRUCTIVE)

```bash
# ALWAYS preview first with dry-run
confluence-as bulk delete --cql "space = CLEANUP AND type = page" --dry-run

# Delete old content
confluence-as bulk delete --cql "space = ARCHIVE AND lastModified < '2022-01-01'" --dry-run

# Execute deletion (after confirming dry-run output)
confluence-as bulk delete --cql "space = CLEANUP" --yes

# Limit scope for safety
confluence-as bulk delete --cql "space = CLEANUP" --max-pages 50 --dry-run
```

**Safety features:**
- `--dry-run` shows exactly what will be deleted before making changes
- Confirmation required by default
- Default `--max-pages 100` prevents accidental mass deletion
- Per-page error tracking with summary of failures

**Recovery:** Deleted pages go to the space trash and can be restored for ~30 days. Restoration is manual and per-page in the Confluence UI, so recovering a large bulk deletion is still painful — always dry-run first.

### Bulk Read-Restriction Changes

`bulk permission` manages page **read restrictions** (who may view a page), not general page permissions.

> **⚠️ Lockout warning:** `--add-group` / `--add-user` on a page with **no existing read restrictions** creates a restriction list — every user NOT on that list immediately loses view access to the page. Always `--dry-run` first and confirm the matched pages are actually meant to be restricted.

```bash
# Restrict pages to a group (adds a read restriction)
confluence-as bulk permission --cql "space = INTERNAL" --add-group "engineering" --dry-run

# Remove a group from the read-restriction list
confluence-as bulk permission --cql "space = INTERNAL" --remove-group "contractors" --dry-run

# Restrict pages to a user (adds a read restriction)
confluence-as bulk permission --cql "label = 'team-docs'" --add-user "user123" --dry-run

# Remove a user from the read-restriction list
confluence-as bulk permission --cql "label = 'sensitive'" --remove-user "contractor123" --dry-run
```

**Restriction options:**
- `--add-group GROUP` - Add a group to the page's read-restriction list
- `--remove-group GROUP` - Remove a group from the read-restriction list
- `--add-user USERID` - Add a user (account ID) to the read-restriction list
- `--remove-user USERID` - Remove a user from the read-restriction list

---

## Parameter Tuning Guide

**How many pages?**

| Page Count | Recommended Setup |
|------------|-------------------|
| <50 | Defaults are fine |
| 50-500 | `--dry-run` first, then execute |
| 500-1,000 | Use `--batch-size 100` for label add; run off-peak for other commands |
| 1,000+ | Use `--batch-size 50` for label add; run off-peak for other commands |

**Getting rate limit (429) errors?**
- For label add: Reduce batch size with `--batch-size 25`
- For other commands: Run during off-peak hours, use `--max-pages` to limit scope

**Note:** `--max-pages` is capped at 1000 for label add/remove and at 500 for update, move, delete, and permission. For larger jobs, narrow the CQL and run in batches.

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Command completed (per-page failures, if any, are reported in the summary output) |
| 1 | Validation or API error |
| 2 | Malformed command line (unknown flag, missing argument) |
| 130 | Cancelled by user (Ctrl+C) |

**Note:** A run where individual pages fail still exits 0 — check the success/failed counts (or the `failed`/`failures` fields in JSON output) to detect partial failures.

---

## Troubleshooting

| Error | Solution |
|-------|----------|
| `No pages found` | Verify CQL query returns results |
| `Permission denied` | Check space/page permissions |
| `Rate limit (429)` | For `bulk label add`: reduce `--batch-size`. Other commands: run off-peak, lower `--max-pages` |
| `Invalid CQL` | Test CQL in Confluence search first |
| `Page locked` | Page may be being edited; retry later |

---

## Related Skills

- **confluence-page**: Single-page operations
- **confluence-label**: Individual label management
- **confluence-search**: Find pages with CQL queries
- **confluence-permission**: Single-page permission changes
