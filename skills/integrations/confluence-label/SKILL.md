---
name: confluence-label
description: Manage content labels - add, remove, and search by labels. ALWAYS use when user wants to
  tag, label, or categorize content.
triggers:
- label
- tag
- add label
- remove label
- labels
- categorize
- tag page
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-label
  ref: 796796686f22aa9e55da9fffa31a2863873d23f1
  license: MIT
  version: '7967966'
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

# Confluence Label Skill

Manage labels on Confluence content.

---

## ⚠️ PRIMARY USE CASE

**This skill manages labels (tags) on Confluence content.** Use for:
- Adding labels to pages
- Removing labels
- Finding content by label
- Viewing popular labels

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| Add/remove labels | - |
| Find by label | `confluence-search` (for complex queries) |
| List page labels | - |
| Create/edit pages | `confluence-page` |
| Set permissions | `confluence-permission` |

---

## Risk Levels

All operations are **low risk** and easily reversible:

| Operation | Risk | Notes |
|-----------|------|-------|
| List labels | - | Read-only |
| Add label | - | Can be removed |
| Remove label | - | Can be re-added |
| Search by label | - | Read-only |

---

## CLI Commands

### confluence-as label add
Add one or more labels to content.

**Usage:**
```bash
confluence-as label add PAGE_ID LABEL [LABEL ...]
confluence-as label add 12345 documentation --output json
```

**Options:**
- `--output, -o` - Output format: text or json

**Examples:**
```bash
confluence-as label add 12345 documentation
confluence-as label add 12345 doc approved v2
```

### confluence-as label remove
Remove a label from content.

**Usage:**
```bash
confluence-as label remove PAGE_ID LABEL
confluence-as label remove 12345 draft --output json
```

**Options:**
- `--output, -o` - Output format: text or json

**Examples:**
```bash
confluence-as label remove 12345 draft
```

### confluence-as label list
List labels on content.

**Usage:**
```bash
confluence-as label list 12345
confluence-as label list 12345 --output json
```

**Options:**
- `--output, -o` - Output format: text or json

### confluence-as label search
Find content by label.

**Usage:**
```bash
confluence-as label search documentation
confluence-as label search approved --space DOCS
confluence-as label search api-docs --type page --limit 50
```

**Options:**
- `--space, -s` - Limit to specific space
- `--type` - Content type filter: page or blogpost
- `--limit, -l` - Maximum results (default: 25)
- `--output, -o` - Output format: text or json

### confluence-as label popular
List most used labels.

**Usage:**
```bash
confluence-as label popular --space DOCS
confluence-as label popular --limit 20
confluence-as label popular --output json
```

**Options:**
- `--space, -s` - Limit to specific space
- `--limit, -l` - Maximum labels to return (default: 25)
- `--output, -o` - Output format: text or json
