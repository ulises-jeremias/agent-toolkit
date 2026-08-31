---
name: confluence-comment
description: Manage comments on Confluence pages - add, get, update, delete, and resolve comments. ALWAYS
  use for feedback, discussions, and inline annotations.
triggers:
- comment
- comments
- add comment
- get comments
- update comment
- delete comment
- inline comment
- resolve comment
- footer comment
- reply
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-comment
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

# Confluence Comment Skill

---

## ⚠️ PRIMARY USE CASE

**This skill manages comments on Confluence pages.** Use for:
- Adding footer comments (end of page)
- Adding inline comments (within content)
- Replying to existing comments
- Resolving/unresolving footer comments (inline comments are not supported by `resolve`)

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| Add/edit comments | - |
| Reply to comments | - |
| Resolve footer comments | - |
| Edit page content | `confluence-page` |
| Search comments | `confluence-search` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| List comments | - | Read-only |
| Add comment | - | Can be deleted |
| Update comment | ⚠️ | Overwrites original |
| Delete comment | ⚠️ | **No recovery** |

---

## Overview

This skill provides comprehensive comment management for Confluence pages, supporting both footer comments and inline comments. Use it to add feedback, manage discussions, and track comment resolution.

## CLI Commands

**Output format tip:** A global `-o/--output` flag placed before the subcommand (e.g. `confluence-as -o json comment list 12345`) sets the default output format for all subcommands; an explicit subcommand-level `--output` wins.

### confluence-as comment add

Add a footer comment to a Confluence page.

**Usage:**
```bash
confluence-as comment add PAGE_ID "Comment text"
confluence-as comment add PAGE_ID --file comment.txt
```

**Arguments:**
- `page_id` - Page ID to add comment to
- `body` - Comment body text (optional if using --file)

**Options:**
- `--file`, `-f` - Read comment body from file (alternative to body argument)
- `--output`, `-o` - Output format (text or json)

**Note:** Either `body` argument or `--file` option is required, but not both.

### confluence-as comment list

Retrieve footer comments on a Confluence page. Returns at most `--limit` comments (default: 25, max: 250) and silently truncates at that limit - pass a higher `--limit` on pages with many comments.

**Usage:**
```bash
confluence-as comment list PAGE_ID
confluence-as comment list PAGE_ID --limit 10
confluence-as comment list PAGE_ID --sort created
confluence-as comment list PAGE_ID --output json
```

**Arguments:**
- `page_id` - Page ID to get comments from

**Options:**
- `--limit`, `-l` - Maximum number of comments to retrieve (default: 25, max: 250); results beyond the limit are silently dropped
- `--sort`, `-s` - Sort order: created or -created (default: -created for newest first)
- `--output`, `-o` - Output format (text or json)

### confluence-as comment update

Update an existing comment's body.

**Usage:**
```bash
confluence-as comment update COMMENT_ID "Updated text"
confluence-as comment update COMMENT_ID --file updated.txt
```

**Arguments:**
- `comment_id` - Comment ID to update
- `body` - Updated comment body (or use --file)

**Options:**
- `--file`, `-f` - Read updated body from file
- `--output`, `-o` - Output format (text or json)

### confluence-as comment delete

Delete a comment from a Confluence page.

**Usage:**
```bash
confluence-as comment delete COMMENT_ID
confluence-as comment delete COMMENT_ID --force
```

**Arguments:**
- `comment_id` - Comment ID to delete

**Options:**
- `--force`, `-f` - Skip confirmation prompt

### confluence-as comment add-inline

Add an inline comment to specific text in a Confluence page.

**Usage:**
```bash
confluence-as comment add-inline PAGE_ID "selected text" "Comment about this text"
```

**Arguments:**
- `page_id` - Page ID to add inline comment to
- `selection` - Text selection to attach comment to
- `body` - Comment body text

**Options:**
- `--output`, `-o` - Output format (text or json)

**Note:** The text selection must match existing text in the page content.

### confluence-as comment resolve

Mark a **footer** comment as resolved or reopen it.

**Footer comments only:** this command calls the `/api/v2/footer-comments/{id}` endpoints exclusively, so passing an inline comment ID fails with 404 Not Found. Resolving inline comments is not supported by the CLI; use the Confluence UI instead.

**Usage:**
```bash
confluence-as comment resolve COMMENT_ID --resolve
confluence-as comment resolve COMMENT_ID --unresolve
```

**Arguments:**
- `comment_id` - Footer comment ID to resolve/unresolve (inline comment IDs return 404)

**Options:**
- `--resolve`, `-r` - Mark comment as resolved
- `--unresolve`, `-u` - Mark comment as unresolved/open
- `--output`, `-o` - Output format (text or json)

**Note:** One of --resolve or --unresolve is required; if both are given, the last one wins.

## Examples

### Natural Language Triggers

**Adding Comments:**
- "Add a comment to page 12345 saying 'Great work!'"
- "Comment on page 67890 with the content from feedback.txt"
- "Leave a comment on the API docs page"

**Getting Comments:**
- "Show me all comments on page 12345"
- "Get the comments from the release notes"
- "List comments on page 67890, newest first"

**Updating Comments:**
- "Update comment 999 to say 'Revised feedback'"
- "Edit comment 888 with the text from file.txt"
- "Change my comment on that page"

**Deleting Comments:**
- "Delete comment 777"
- "Remove comment 666 without confirmation"
- "Delete my comment from that page"

**Inline Comments:**
- "Add inline comment to page 12345 on the text 'important section' saying 'Needs clarification'"
- "Comment on specific text in the documentation"

**Resolving Comments:**
- "Resolve comment 555"
- "Mark comment 444 as resolved"
- "Reopen comment 333"
- "Unresolve comment 222"

## API Endpoints Used

This skill uses the Confluence v2 REST API:

- **Footer Comments:**
  - `POST /api/v2/footer-comments` - Add comment (pageId in request body)
  - `GET /api/v2/pages/{id}/footer-comments` - Get comments on a page
  - `GET /api/v2/footer-comments/{id}` - Get specific comment
  - `PUT /api/v2/footer-comments/{id}` - Update comment body or resolution status (used by `update` and `resolve`)
  - `DELETE /api/v2/footer-comments/{id}` - Delete comment

- **Inline Comments:**
  - `POST /api/v2/inline-comments` - Add inline comment (pageId in request body); this is the only inline-comment endpoint the CLI uses - resolving inline comments is not supported

## Error Handling

All commands include proper error handling for:
- **404 Not Found** - Page or comment doesn't exist
- **403 Forbidden** - No permission to add/edit/delete comments
- **409 Conflict** - Version mismatch on updates
- **400 Bad Request** - Invalid input (empty body, invalid selection)

## Notes

- Comments support HTML storage format for rich text
- Inline comments require exact text matches in page content
- Comment IDs are numeric strings (same validation as page IDs)
- Resolution status is tracked separately from comment body (resolve/unresolve applies to footer comments only)
- Deletion requires confirmation unless --force is used
