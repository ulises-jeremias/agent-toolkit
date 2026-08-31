---
name: confluence-page
description: Manage Confluence pages and blog posts - create, read, update, delete, copy, move, and version
  control. ALWAYS use when user wants to work with page content, create pages, update pages, or manage
  page versions.
triggers:
- create page
- get page
- read page
- update page
- edit page
- delete page
- remove page
- blog post
- blogpost
- create blog
- copy page
- duplicate page
- move page
- relocate page
- page version
- version history
- restore version
- revert page
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-page
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

# Confluence Page Skill

Manage Confluence pages and blog posts through natural language commands.

---

## ⚠️ PRIMARY USE CASE

**This is the core skill for all page and blog post operations.** Use this skill whenever you need to:
- Create, read, update, or delete pages
- Create or manage blog posts
- Copy or move pages between spaces
- Access or restore version history

---

## When to Use This Skill

| Trigger | Example |
|---------|---------|
| Page CRUD | "Create a page", "Get page 12345", "Update the page", "Delete this page" |
| Blog posts | "Create a blog post", "Get blog 67890" |
| Copy/Move | "Copy page to ARCHIVE", "Move page under parent 12345" |
| Versions | "Show version history", "Restore to version 5" |
| Content from files | "Create page from markdown file", "Update page from content.md" |

---

## When NOT to Use This Skill

| Operation | Use Instead |
|-----------|-------------|
| Search for pages | `confluence-search` |
| Add comments to pages | `confluence-comment` |
| Upload attachments | `confluence-attachment` |
| Add/remove labels | `confluence-label` |
| Set page restrictions | `confluence-permission` |
| View page analytics | `confluence-analytics` |
| Watch/unwatch pages | `confluence-watch` |
| Navigate page hierarchy | `confluence-hierarchy` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| Get page | - | Read-only |
| Create page | - | Easily deletable |
| Update page | ⚠️ | Creates version history, reversible |
| Copy page | - | Creates new page |
| Move page | ⚠️ | Can be moved back |
| Delete page | ⚠️⚠️ | Goes to trash, recoverable for 30 days |
| Permanent delete | ⚠️⚠️⚠️ | **IRREVERSIBLE** |

---

## Overview

This skill handles all CRUD operations for Confluence pages and blog posts, including:
- Creating new pages and blog posts
- Reading page content and metadata
- Updating page content, title, and status
- Deleting pages (trash or permanent)
- Copying and moving pages
- Version history and restoration

## CLI Commands

**Output format tip:** A global `-o/--output` flag placed before the subcommand (e.g. `confluence-as -o json page get 12345`) sets the default output format for all subcommands; an explicit subcommand-level `--output` wins.

### confluence-as page create

Create a new Confluence page.

**Usage:**
```bash
# Create a simple page
confluence-as page create --space DOCS --title "My New Page" --body "Page content here"

# Create with parent page
confluence-as page create --space DOCS --title "Child Page" --parent 12345 --body "Content"

# Create from Markdown file
confluence-as page create --space DOCS --title "From Markdown" --file content.md

# Create as draft
confluence-as page create --space DOCS --title "Draft Page" --body "WIP" --status draft
```

**Arguments:**
- `--space, -s` - Space key (required)
- `--title, -t` - Page title (required)
- `--body, -b` - Page body content as storage-format XHTML (or plain text). Markdown passed via `--body` is NOT converted and renders as literal text; use `--file` with a `.md` file for Markdown.
- `--file, -f` - Read body from file (files with a `.md`/`.markdown` extension are converted from Markdown)
- `--parent, -p` - Parent page ID
- `--status` - Page status: current (default) or draft
- `--output, -o` - Output format: text or json

### confluence-as page get

Retrieve a page's content and metadata.

**Usage:**
```bash
# Get by page ID
confluence-as page get 12345

# Get with full body content
confluence-as page get 12345 --body

# Get specific body format
confluence-as page get 12345 --body --format markdown

# JSON output
confluence-as page get 12345 --output json
```

**Arguments:**
- `page_id` - Page ID (required)
- `--body` - Include body content
- `--format` - Body format: storage (default), view, or markdown
- `--output, -o` - Output format: text or json

### confluence-as page update

Update an existing page.

**Usage:**
```bash
# Update title
confluence-as page update 12345 --title "New Title"

# Update body
confluence-as page update 12345 --body "New content"

# Update from file
confluence-as page update 12345 --file updated-content.md

# Update with version message
confluence-as page update 12345 --body "Updated" --message "Fixed typos"

# Change status
confluence-as page update 12345 --status draft
```

**Arguments:**
- `page_id` - Page ID (required)
- `--title, -t` - New title
- `--body, -b` - New body content (storage-format XHTML or plain text; Markdown is not converted - use `--file` with a `.md` file)
- `--file, -f` - Read body from file (`.md`/`.markdown` files are converted from Markdown)
- `--message, -m` - Version message
- `--status` - New status: current or draft
- `--output, -o` - Output format

### confluence-as page delete

Delete a page (move to trash or permanent delete).

**Usage:**
```bash
# Move to trash (default)
confluence-as page delete 12345

# Permanent delete
confluence-as page delete 12345 --permanent

# Force without confirmation
confluence-as page delete 12345 --force
```

**Arguments:**
- `page_id` - Page ID (required)
- `--permanent` - Permanently delete (cannot be recovered)
- `--force, -f` - Skip confirmation prompt

### confluence-as page blog create

Create a new blog post.

**Usage:**
```bash
confluence-as page blog create --space BLOG --title "My Blog Post" --body "Blog content"

# From Markdown
confluence-as page blog create --space BLOG --title "From MD" --file post.md
```

**Arguments:**
- `--space, -s` - Space key (required)
- `--title, -t` - Blog post title (required)
- `--body, -b` - Blog post content (storage-format XHTML or plain text; Markdown is not converted - use `--file` with a `.md` file)
- `--file, -f` - Read body from file (`.md`/`.markdown` files are converted from Markdown)
- `--status` - Blog post status: current or draft
- `--output, -o` - Output format

### confluence-as page blog get

Retrieve a blog post.

**Usage:**
```bash
confluence-as page blog get 67890 --body
```

**Arguments:**
- `blogpost_id` - Blog post ID (required)
- `--body` - Include body content
- `--format` - Body format
- `--output, -o` - Output format

### confluence-as page copy

Copy a page to a new location.

**Usage:**
```bash
# Copy to same space
confluence-as page copy 12345 --title "Page Copy"

# Copy to different space
confluence-as page copy 12345 --title "Page Copy" --space NEWSPACE

# Copy with children
confluence-as page copy 12345 --title "Page Copy" --include-children
```

**Arguments:**
- `page_id` - Source page ID (required)
- `--title, -t` - New page title (default: "Copy of [original]")
- `--space, -s` - Target space key
- `--parent, -p` - Target parent page ID
- `--include-children` - Copy child pages recursively
- `--output, -o` - Output format

### confluence-as page move

Move a page to a new location.

**Usage:**
```bash
# Move to new parent
confluence-as page move 12345 --parent 67890

# Move to different space
confluence-as page move 12345 --space NEWSPACE

# Move to space root
confluence-as page move 12345 --space NEWSPACE --root
```

**Arguments:**
- `page_id` - Page ID to move (required)
- `--space, -s` - Target space key
- `--parent, -p` - Target parent page ID
- `--root` - Move to space root (no parent)
- `--output, -o` - Output format

### confluence-as page versions

Get version history for a page.

**Usage:**
```bash
# List all versions
confluence-as page versions 12345

# Limit results
confluence-as page versions 12345 --limit 10

# Show version details
confluence-as page versions 12345 --detailed
```

**Arguments:**
- `page_id` - Page ID (required)
- `--limit, -l` - Maximum versions to return (default: 25)
- `--detailed` - Show full version details
- `--output, -o` - Output format

### confluence-as page restore

Restore a page to a previous version.

**Usage:**
```bash
# Restore to version 5
confluence-as page restore 12345 --version 5

# With version message
confluence-as page restore 12345 --version 5 --message "Restoring to known good state"
```

**Arguments:**
- `page_id` - Page ID (required)
- `--version, -v` - Version number to restore (required)
- `--message, -m` - Version message for the restoration

## Examples

### Natural Language Triggers

- "Create a new page called 'Meeting Notes' in the DOCS space"
- "Get the content of page 12345"
- "Update page 12345 with this content: [content]"
- "Delete the page with ID 12345"
- "Create a blog post titled 'Sprint Review' in TEAM space"
- "Copy page 12345 to the ARCHIVE space"
- "Move page 12345 under parent page 67890"
- "Show me the version history for page 12345"
- "Restore page 12345 to version 3"

### Common Workflows

**Create a page from natural language:**
```
User: Create a page called "API Documentation" in DOCS space with content explaining our REST API
```

---

## Common Pitfalls

### 1. Page ID vs Page Title
- **Problem**: Trying to use page title when page ID is required
- **Solution**: Use `confluence-as search cql "title = 'Page Name'"` to find the page ID first

### 2. Version Conflicts
- **Problem**: Update fails due to concurrent edits (409 Conflict)
- **Solution**: Get the latest version, merge changes, retry update

### 3. Missing Parent Page
- **Problem**: Creating a child page with invalid parent ID
- **Solution**: Verify parent exists with `confluence-as page get PARENT_ID`

### 4. Content Format Mismatch
- **Problem**: Body content not rendering correctly
- **Solution**: Use `--file` with Markdown, or ensure proper storage format (XHTML)

### 5. Space Key Format
- **Problem**: Space key not found or rejected
- **Solution**: Keys must start with a letter and contain only letters, numbers, and underscores; the CLI uppercases lowercase input automatically (`docs` becomes `DOCS`)

### 6. Permanent Delete Recovery
- **Problem**: Accidentally used `--permanent` flag
- **Solution**: **No recovery possible** - always use trash (default) first

### 7. Blog Post Update/Delete
- **Problem**: Trying to update or delete a blog post using page commands
- **Solution**: Blog posts currently only support `create` and `get` operations via CLI. Update/delete must be done via Confluence UI.

---

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| **404 Not Found** | Page ID doesn't exist or was deleted | Verify page ID, check trash |
| **403 Forbidden** | No permission to access/modify page | Request space access, check restrictions |
| **409 Conflict** | Concurrent edit detected | Refresh page, merge changes, retry |
| **400 Bad Request** | Invalid content format or parameters | Check body format, verify arguments |
| **413 Content Too Large** | Page body exceeds size limit | Split content across multiple pages |

**Note:** Confluence reports a missing create-page permission as HTTP 404. `confluence-as page create` detects this case and reports it as a permission error instead of "not found".

### Recovery from Errors

**Deleted page recovery:**
```bash
# Pages go to trash by default (recoverable for 30 days)
# Use Confluence UI: Space Settings > Content Tools > Trash > Restore
```

**Version recovery:**
```bash
# Check version history
confluence-as page versions 12345

# Restore previous version
confluence-as page restore 12345 --version 5
```

**Permission issues:**
```bash
# Check page restrictions
confluence-as permission page get 12345

# Check space permissions
confluence-as permission space get SPACE_KEY
```
