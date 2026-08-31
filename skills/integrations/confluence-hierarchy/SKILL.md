---
name: confluence-hierarchy
description: Navigate and manage Confluence page hierarchies, ancestors, descendants, and trees. ALWAYS
  use for parent/child relationships and page tree navigation.
triggers:
- hierarchy
- ancestor
- parent
- child
- children
- descendant
- tree
- breadcrumb
- navigation
- reorder
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-hierarchy
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

# Confluence Hierarchy Skill

---

## ⚠️ PRIMARY USE CASE

**This skill navigates page relationships.** Use for:
- Finding parent/ancestor pages
- Listing child/descendant pages
- Viewing page tree structure
- Reordering child pages

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| Get parent/ancestors | - |
| List children | - |
| View page tree | - |
| Move pages | `confluence-page` |
| Create pages | `confluence-page` |
| Search pages | `confluence-search` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| Get ancestors/children | - | Read-only |
| View tree | - | Read-only |
| Reorder pages | - | Preview only - calculates and displays proposed order, applies no changes |

---

## Overview

This skill provides operations for navigating and managing page hierarchies in Confluence, including getting ancestors, children, descendants, and full page trees.

## CLI Commands

### confluence-as hierarchy ancestors

Get all ancestor pages for a given page (parent, grandparent, etc.).

**Usage:**
```bash
confluence-as hierarchy ancestors PAGE_ID
confluence-as hierarchy ancestors PAGE_ID --breadcrumb
confluence-as hierarchy ancestors PAGE_ID --output json
```

**Options:**
- `--breadcrumb` - Display as breadcrumb path (Root > Parent > Current)
- `--output` - Output format: text (default) or json

**Examples:**
- Get ancestors: `confluence-as hierarchy ancestors 12345`
- Show breadcrumb: `confluence-as hierarchy ancestors 12345 --breadcrumb`

### confluence-as hierarchy children

Get direct child pages of a parent page (one level down only).

**Usage:**
```bash
confluence-as hierarchy children PAGE_ID
confluence-as hierarchy children PAGE_ID --limit 50
confluence-as hierarchy children PAGE_ID --sort title
```

**Options:**
- `--limit` - Maximum number of children to retrieve (default: 25, max: 250)
- `--sort` - Sort by: title, id, or created
- `--output` - Output format: text (default) or json

**Examples:**
- Get children: `confluence-as hierarchy children 12345`
- Sort by title: `confluence-as hierarchy children 12345 --sort title`

### confluence-as hierarchy descendants

Get all descendant pages recursively (children, grandchildren, etc.).

**Usage:**
```bash
confluence-as hierarchy descendants PAGE_ID
confluence-as hierarchy descendants PAGE_ID --max-depth 2
confluence-as hierarchy descendants PAGE_ID --limit 200
confluence-as hierarchy descendants PAGE_ID --output json
```

**Options:**
- `--max-depth` - Maximum depth to traverse (default: unlimited)
- `--limit` - Maximum number of descendants to retrieve (default: 100, max: 500)
- `--output` - Output format: text (default) or json

**Examples:**
- Get all descendants: `confluence-as hierarchy descendants 12345`
- Limit depth: `confluence-as hierarchy descendants 12345 --max-depth 2`

### confluence-as hierarchy tree

Get full hierarchical tree structure with nested children.

**Usage:**
```bash
confluence-as hierarchy tree PAGE_ID
confluence-as hierarchy tree PAGE_ID --max-depth 3
confluence-as hierarchy tree PAGE_ID --stats
```

**Options:**
- `--max-depth` - Maximum depth to traverse (default: unlimited)
- `--stats` - Show tree statistics (total pages, max depth, leaf pages)
- `--output` - Output format: text (default) or json

**Examples:**
- Get page tree: `confluence-as hierarchy tree 12345`
- With statistics: `confluence-as hierarchy tree 12345 --stats`

### confluence-as hierarchy reorder

Calculate and display proposed child page order. This command helps plan reordering operations.

**Usage:**
```bash
confluence-as hierarchy reorder PARENT_ID
confluence-as hierarchy reorder PARENT_ID "id1,id2,id3"
confluence-as hierarchy reorder PARENT_ID --reverse
```

**Arguments:**
- `order` - (Optional) Comma-separated child page IDs in desired order (must be quoted)

**Options:**
- `--reverse` - Sort children reverse-alphabetically by title (children are sorted alphabetically first, then reversed; only applies when no explicit order argument is given)
- `--output, -o` - Output format: text (default) or json

**Examples:**
- Sort alphabetically: `confluence-as hierarchy reorder 12345`
- Specify custom order: `confluence-as hierarchy reorder 12345 "200,201,202"`
- Reverse-alphabetical order: `confluence-as hierarchy reorder 12345 --reverse`

**IMPORTANT:** This command only CALCULATES and DISPLAYS the proposed new order - it does NOT apply changes to Confluence. To actually reorder pages, you must use the Confluence UI (drag and drop in the page tree).

## Natural Language Examples

These phrases will trigger this skill:

- "Show me the ancestors of page 12345"
- "Get the breadcrumb path for page 12345"
- "List all children of page 12345"
- "Get all descendants of page 12345 up to depth 3"
- "Show me the page tree for 12345"
- "Reorder the children of page 12345"
- "What is the hierarchy for page 12345?"
- "Show the navigation path to page 12345"

## API Endpoints Used

- `GET /api/v2/pages/{id}/ancestors` - Get page ancestors
- `GET /api/v2/pages/{id}/children` - Get direct children
- `GET /api/v2/pages/{id}/descendants` - Get all descendants
- `GET /api/v2/pages/{id}` - Get page information

## Common Patterns

### Building Breadcrumbs

```bash
confluence-as hierarchy ancestors 12345 --breadcrumb
# Output: Space Root > Section > Subsection > Current Page
```

### Visualizing Page Structure

```bash
confluence-as hierarchy tree 12345 --stats
# Shows hierarchical tree with statistics
```

### Finding All Pages Below

```bash
confluence-as hierarchy descendants 12345 --output json > descendants.json
# Export all descendants to JSON
```

### Limiting Traversal Depth

```bash
confluence-as hierarchy descendants 12345 --max-depth 2
# Only get children and grandchildren
```

## Notes

- Depth is tracked starting from 1 for direct children
- Tree operations can be resource-intensive for large hierarchies
- Use `--max-depth` to limit traversal when needed
- The reorder command only previews the proposed order; apply changes via the Confluence UI
