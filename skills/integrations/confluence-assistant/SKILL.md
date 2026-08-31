---
name: confluence-assistant
description: Central hub for Confluence operations - routes requests to specialized skills. ALWAYS use
  when user mentions confluence, wiki, or Atlassian wiki operations.
triggers:
- confluence
- wiki
- atlassian wiki
- confluence cloud
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-assistant
  ref: d5e1ccacd1836b2b33b2507e83d56880bec8cc92
  license: MIT
  version: d5e1cca
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

# Confluence Assistant

The central hub skill that routes Confluence requests to specialized skills.

## When to Use This Skill

Use this skill when you need to work with Confluence and are unsure which specific skill to use. This hub will intelligently route your request to the appropriate specialized skill based on keywords in your request.

**Note**: Trigger keywords are case-insensitive.

---

## Quick Reference

| Operation | Primary Skill | Risk Level |
|-----------|---------------|------------|
| Get/list pages | confluence-page | - |
| Create page | confluence-page | - |
| Update page | confluence-page | :warning: |
| Delete page | confluence-page | :warning::warning: |
| Copy/move page | confluence-page | :warning: |
| List spaces | confluence-space | - |
| Create space | confluence-space | - |
| Delete space | confluence-space | :warning::warning::warning: |
| Search content | confluence-search | - |
| Export search results | confluence-search | - |
| Add comment | confluence-comment | - |
| Delete comment | confluence-comment | :warning: |
| Upload attachment | confluence-attachment | - |
| Delete attachment | confluence-attachment | :warning::warning: |
| Add label | confluence-label | - |
| Remove label | confluence-label | - |
| Set permission | confluence-permission | :warning::warning: |
| Remove permission | confluence-permission | :warning::warning: |
| View analytics | confluence-analytics | - |
| Bulk label/move/delete | confluence-bulk | :warning::warning: |
| Cache management | confluence-ops | - |
| Admin operations | confluence-admin | :warning::warning: |

**Risk Levels**: - (safe) | :warning: (reversible) | :warning::warning: (destructive) | :warning::warning::warning: (irreversible)

---

## Explicit Routing Rules

### Rule 1: Explicit Skill Mention Wins
If the user explicitly names a skill, route directly to it.
- "Use confluence-search to find pages" → `confluence-search`
- "I need confluence-page skill" → `confluence-page`

### Rule 2: Entity Signals
Presence of identifiers suggests specific skills:
- **Page ID** (numeric) → likely `confluence-page`, `confluence-comment`, `confluence-attachment`
- **Space key** (uppercase) → likely `confluence-space`, `confluence-search`
- **CQL query** → `confluence-search`

### Rule 3: Operation Keywords
Match verbs to skill domains:
- Create/update/delete/copy/move page → `confluence-page`
- Search/find/query/export → `confluence-search`
- Comment/reply/resolve → `confluence-comment`
- Upload/download/attach → `confluence-attachment`

### Rule 4: Quantity Signals
Large-scale operations require bulk handling:
- Operations on 10+ items → `confluence-bulk`
- Bulk label operations → `confluence-bulk`
- Bulk delete/move → `confluence-bulk`
- "all pages in space" → `confluence-bulk`

### Rule 5: Ambiguous Requests
When intent is unclear, ask for clarification rather than guessing.

---

## Negative Triggers (What Each Skill Does NOT Handle)

| Skill | Does NOT Handle |
|-------|-----------------|
| `confluence-page` | Space-level operations, search queries, permissions, comments |
| `confluence-space` | Individual page content, page CRUD, comments, attachments |
| `confluence-search` | Content creation, content modification, permission changes |
| `confluence-comment` | Page content updates, attachments, labels |
| `confluence-attachment` | Page content, comments, permissions |
| `confluence-label` | Page content, search queries, permissions |
| `confluence-template` | Direct page CRUD, search, permissions |
| `confluence-property` | Page content (body), comments, permissions |
| `confluence-permission` | Page content, search, comments |
| `confluence-analytics` | Content modification (read-only skill) |
| `confluence-watch` | Content modification, permissions |
| `confluence-hierarchy` | Page content, permissions, search |
| `confluence-jira` | Pure Confluence operations (cross-product only) |
| `confluence-bulk` | Single-item operations, read-only queries |
| `confluence-ops` | Content operations, permissions, search |
| `confluence-admin` | Page content CRUD, search queries |

---

## Context Awareness

### Pronoun Resolution
When users say "it", "this", "that", refer to the most recently mentioned resource:
- "Get page 12345" → "Update it" = Update page 12345
- "Search in DOCS space" → "Export those results" = Export DOCS search

### Space Scope
Operations default to the current space context when established:
- "List pages in DOCS" → subsequent "create a page" assumes DOCS space

### Context Expiration
Context clears when:
- User explicitly changes topic
- New space or page is explicitly mentioned
- Session restarts

---

## Disambiguation Examples

### Example 1: Ambiguous Target
```
User: "Show me the page"
→ Ambiguous: Which page?
→ Ask: "Which page would you like to see? Please provide the page ID or title."
```

### Example 2: Missing Operation
```
User: "Page 12345"
→ Ambiguous: What operation?
→ Ask: "What would you like to do with page 12345? (get, update, delete, etc.)"
```

### Example 3: Skill Overlap
```
User: "Find the comments"
→ Ambiguous: Search for pages with comments, or list comments on a page?
→ Ask: "Would you like to search for pages containing comments, or list comments on a specific page?"
```

### Example 4: Destructive Operation Confirmation
```
User: "Delete all pages in ARCHIVE"
→ Destructive operation detected
→ Ask: "This will delete all pages in ARCHIVE space. Are you sure? Please confirm with 'yes' to proceed."
```

---

## Common Workflows

### Workflow 1: Create and Configure a New Page
1. `confluence-page` - Create the page with content
2. `confluence-label` - Add relevant labels
3. `confluence-permission` - Set page restrictions if needed

### Workflow 2: Content Audit
1. `confluence-search` - Find pages matching criteria
2. `confluence-analytics` - Check view counts and activity
3. `confluence-label` - Tag pages based on audit findings

### Workflow 3: Space Migration
1. `confluence-search` - Find all pages in source space
2. `confluence-page` - Copy pages to destination space
3. `confluence-attachment` - Verify attachments transferred
4. `confluence-hierarchy` - Confirm parent-child relationships

### Workflow 4: Documentation Review
1. `confluence-search` - Find pages by label (e.g., "needs-review")
2. `confluence-comment` - Add review comments
3. `confluence-label` - Update labels (remove "needs-review", add "reviewed")

---

## Overview

This skill acts as the main entry point for Confluence operations, intelligently routing requests to the appropriate specialized skill based on the user's intent.

## Available Skills

| Skill | Purpose | Triggers |
|-------|---------|----------|
| `confluence-page` | Page/blog CRUD | create page, update page, delete page, get page, copy, move, version, restore, blog post |
| `confluence-space` | Space management | create space, list spaces, get space, space settings, space content, delete space |
| `confluence-search` | CQL queries | search, find pages, find content, CQL, query, saved search, export |
| `confluence-comment` | Comments | comment, comments, add comment, reply, inline, resolve, footer comment |
| `confluence-attachment` | File attachments | attach, upload, download, file attachment |
| `confluence-label` | Content labeling | label, labels, tag, add label |
| `confluence-template` | Page templates | template, templates, blueprint, create from template |
| `confluence-property` | Content properties | property, properties, metadata, custom data, content property |
| `confluence-permission` | Access control | permission, permissions, restrict, access, security |
| `confluence-analytics` | Content analytics | analytics, views, statistics, watchers, contributors, page views, most viewed |
| `confluence-watch` | Notifications | watch, unwatch, notify, follow |
| `confluence-hierarchy` | Content tree | parent, children, tree, ancestors, hierarchy, breadcrumb, reorder |
| `confluence-jira` | JIRA integration | jira, jira macro, jira issues, embed issue, link jira |
| `confluence-bulk` | Bulk operations | bulk, batch, multiple pages, mass update, bulk delete, bulk label |
| `confluence-ops` | Operations/cache | cache, cache status, cache clear, performance, rate limit, health check |
| `confluence-admin` | Administration | admin, user management, group management, template management, space settings |

## Routing Logic

The assistant uses keyword matching to route requests:

### Page Operations
- Keywords: `page`, `blog`, `create`, `update`, `delete`, `copy`, `move`, `version`, `read`, `get`, `edit`, `remove`, `duplicate`, `relocate`, `revert`, `restore`
- Routes to: `confluence-page`

### Space Operations
- Keywords: `space`, `spaces`, `create space`, `list space`, `get space`, `show spaces`, `update space`, `edit space`, `delete space`, `remove space`, `space settings`, `space content`, `space pages`
- Routes to: `confluence-space`

### Search Operations
- Keywords: `search`, `find`, `query`, `CQL`, `export`, `find content`, `saved search`, `search by label`
- Routes to: `confluence-search`

### Comment Operations
- Keywords: `comment`, `comments`, `reply`, `inline`, `resolve`, `footer comment`, `get comments`, `update comment`, `delete comment`
- Routes to: `confluence-comment`

### Attachment Operations
- Keywords: `attach`, `upload`, `download`, `file`, `attachment`, `attachments`
- Routes to: `confluence-attachment`

### Label Operations
- Keywords: `label`, `labels`, `tag`, `tags`
- Routes to: `confluence-label`

### Template Operations
- Keywords: `template`, `templates`, `blueprint`, `from template`, `page template`, `list templates`, `update template`, `create from template`
- Routes to: `confluence-template`

### Property Operations
- Keywords: `property`, `properties`, `metadata`, `custom data`, `content property`, `page property`, `set property`, `get property`, `delete property`, `list properties`
- Routes to: `confluence-property`

### Permission Operations
- Keywords: `permission`, `permissions`, `restrict`, `access`, `security`
- Routes to: `confluence-permission`

### Analytics Operations
- Keywords: `analytics`, `views`, `statistics`, `popular`, `watchers`, `contributors`, `page views`, `space analytics`, `most viewed`, `most popular`, `who is watching`, `content analytics`
- Routes to: `confluence-analytics`

### Watch Operations
- Keywords: `watch`, `unwatch`, `notify`, `follow`, `notifications`
- Routes to: `confluence-watch`

### Hierarchy Operations
- Keywords: `parent`, `children`, `child`, `tree`, `ancestor`, `descendant`, `hierarchy`, `breadcrumb`, `navigation`, `reorder`
- Routes to: `confluence-hierarchy`

### JIRA Operations
- Keywords: `jira`, `issue`, `embed jira`, `jira macro`, `jira issues`, `link jira`
- Routes to: `confluence-jira`

### Bulk Operations
- Keywords: `bulk`, `batch`, `multiple pages`, `mass`, `all pages`, `many pages`, `bulk delete`, `bulk label`, `bulk move`, `bulk update`
- Routes to: `confluence-bulk`

### Operations/Cache
- Keywords: `cache`, `cache status`, `cache clear`, `cache warm`, `performance`, `rate limit`, `health check`, `diagnostics`, `troubleshoot`
- Routes to: `confluence-ops`

### Administration
- Keywords: `admin`, `administration`, `user management`, `group management`, `groups`, `users`, `site settings`, `space settings`, `configure`, `setup`
- Routes to: `confluence-admin`

## Configuration

### Authentication Setup

1. Get an API token from https://id.atlassian.com/manage-profile/security/api-tokens

2. Set environment variables:
```bash
export CONFLUENCE_SITE_URL="https://your-site.atlassian.net"
export CONFLUENCE_EMAIL="your-email@company.com"
export CONFLUENCE_API_TOKEN="your-api-token"
```

3. Or create `.claude/settings.local.json`:
```json
{
  "confluence": {
    "url": "https://your-site.atlassian.net",
    "email": "your-email@company.com",
    "api_token": "your-api-token"
  }
}
```

## Example Commands

### Page Operations
- "Create a new page called 'Meeting Notes' in DOCS space"
- "Update page 12345 with new content"
- "Delete page 12345"
- "Copy page 12345 to ARCHIVE space"

### Space Operations
- "List all spaces"
- "Create a new space for the Engineering team"
- "Show me the contents of DOCS space"

### Search Operations
- "Search for pages about API documentation"
- "Find all pages with label 'approved'"
- "Export all pages in KB space to CSV"

### Comment Operations
- "Add a comment to page 12345"
- "Show me comments on page 12345"
- "Resolve the inline comment"

### Attachment Operations
- "Upload report.pdf to page 12345"
- "Download all attachments from page 12345"
- "List attachments on page 12345"

### Label Operations
- "Add label 'approved' to page 12345"
- "Find all pages with label 'documentation'"
- "Remove label 'draft' from page 12345"

### Hierarchy Operations
- "Show me the child pages of 12345"
- "Get the parent pages of 67890"
- "Display the page tree for DOCS space"

### Template Operations
- "List all templates in DOCS space"
- "Create a page from the 'Meeting Notes' template"
- "Show available blueprints"
- "Update the 'Project Kickoff' template"

### Property Operations
- "Set property 'status' to 'approved' on page 12345"
- "Get all properties from page 12345"
- "List properties on page 12345"
- "Delete the 'draft' property from page 12345"

### Analytics Operations
- "Show me the view count for page 12345"
- "Who has viewed page 12345?"
- "What are the most viewed pages in DOCS space?"
- "Show watchers and contributors for page 12345"

### Watch Operations
- "Watch page 12345"
- "Unwatch page 12345"
- "Who is watching page 12345?"
- "Follow space DOCS"

### JIRA Integration Operations
- "Embed JIRA issue PROJ-123 in page 12345"
- "Show JIRA issues linked to page 12345"
- "Add a JIRA macro for project PROJ to the page"
- "Link page 12345 to JIRA issue DEV-456"

### Bulk Operations
- "Bulk delete all pages in ARCHIVE space with dry-run"
- "Add label 'approved' to all pages in DOCS space"
- "Move all pages with label 'old' to ARCHIVE space"
- "Bulk update permissions on pages in INTERNAL"

### Operations/Cache
- "Check cache status"
- "Clear the cache"
- "Warm the cache for DOCS space"
- "Run a health check on Confluence connectivity"
- "Check rate limit status"

### Administration Operations
- "List all groups"
- "Search for user john@example.com"
- "Add user to engineering group"
- "View space settings for DOCS"
- "Create a new template"

## API Reference

This skill uses the Confluence Cloud REST API:

- **v2 API** (primary): `/api/v2/*`
  - Pages, Spaces, Blog Posts, Comments, Attachments, Labels

- **v1 API** (legacy/fallback): `/rest/api/*`
  - Search (CQL), Content Properties, Space Settings

Documentation: https://developer.atlassian.com/cloud/confluence/rest/v2/intro/

## Error Handling

The assistant provides clear error messages for common issues:

- **401 Unauthorized**: Check your API token and email
- **403 Forbidden**: You don't have permission for this operation
- **404 Not Found**: The resource doesn't exist
- **429 Rate Limited**: Wait before retrying
- **5xx Server Error**: Confluence server issue

## Getting Help

- Use `/help` for general Claude Code help
- Check `CLAUDE.md` for project documentation
- See skill-specific SKILL.md files for detailed usage
