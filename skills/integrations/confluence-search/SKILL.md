---
name: confluence-search
description: Search Confluence using CQL queries, validate syntax, export results, and manage search history.
  ALWAYS use when user wants to find, search, or query for content.
triggers:
- search confluence
- find pages
- search pages
- CQL
- query confluence
- export search
- search results
- find content
- search by label
- saved search
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-search
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

# Confluence Search Skill

Search Confluence content using CQL (Confluence Query Language).

---

## ⚠️ PRIMARY USE CASE

**This skill finds content across Confluence.** Use this skill for:
- Searching pages by text, title, or labels
- Building CQL queries for complex searches
- Exporting search results to CSV/JSON
- Finding content by date, creator, or space

**This is a read-only skill** - it cannot create, modify, or delete content.

---

## When to Use This Skill

| Trigger | Example |
|---------|---------|
| Text search | "Find pages about API documentation" |
| Label search | "Find all pages with label 'approved'" |
| Space search | "Search for content in DOCS space" |
| Date-based | "Find pages modified this week" |
| Export | "Export all pages in KB space to CSV" |
| CQL query | "Run CQL: space = DOCS AND type = page" |

---

## When NOT to Use This Skill

| Operation | Use Instead |
|-----------|-------------|
| Create/edit pages | `confluence-page` |
| Add/remove labels | `confluence-label` |
| Manage permissions | `confluence-permission` |
| View page hierarchy | `confluence-hierarchy` |

---

## Risk Levels

All operations are **read-only** with no risk:

| Operation | Risk | Notes |
|-----------|------|-------|
| Search content | - | Read-only |
| Validate CQL | - | Read-only |
| Export results | - | Creates local file only |
| View history | - | Local history only |

---

## Overview

This skill provides powerful search capabilities:
- Execute CQL queries
- Validate CQL syntax
- Get field and value suggestions
- Interactive query builder
- Export results to CSV/JSON
- Streaming export for large result sets
- Query history management

## CQL Query Patterns

### Basic Queries

```cql
# Find pages in a space
space = "DOCS" AND type = page

# Find by label
label = "documentation"

# Text search
text ~ "API documentation"

# By creator
creator = "john.doe@company.com"
creator = currentUser()

# By date
created >= "2024-01-01"
lastModified > startOfMonth()
```

### Advanced Queries

```cql
# Multiple spaces
space in ("DOCS", "KB", "DEV") AND type = page

# Exclude labels
label = "approved" AND label != "draft"

# Date ranges
lastModified >= "2024-01-01" AND lastModified < "2024-02-01"

# Ancestor (child pages)
ancestor = 12345

# Combined with ordering
space = "DOCS" AND label = "api" ORDER BY lastModified DESC

# Attachments in a space
type = attachment AND space = "DOCS"

# Blog posts by date
type = blogpost AND created >= startOfYear()
```

### CQL Fields Reference

| Field | Description | Example |
|-------|-------------|---------|
| space | Space key | `space = "DOCS"` |
| title | Page title | `title ~ "API"` |
| text | Full text search | `text ~ "configuration"` |
| type | Content type | `type = page` |
| label | Content label | `label = "docs"` |
| creator | Content creator | `creator = currentUser()` |
| contributor | Any contributor | `contributor = "email"` |
| created | Creation date | `created >= "2024-01-01"` |
| lastModified | Last modified date | `lastModified > startOfWeek()` |
| parent | Parent page ID | `parent = 12345` |
| ancestor | Ancestor page ID | `ancestor = 12345` |
| id | Content ID | `id = 12345` |

## CLI Commands

**Output format tip:** A global `-o/--output` flag placed before the subcommand (e.g. `confluence-as -o json search cql "..."`) sets the default output format for all subcommands; an explicit subcommand-level `--output` wins. Note that for `search export` and `search stream-export`, the subcommand-level `-o/--output` is the output **file path**, not the format - use `--format` there.

### confluence-as search cql

Execute CQL queries against Confluence.

**Usage:**
```bash
# Simple text search
confluence-as search cql "text ~ 'API documentation'"

# Search with space filter
confluence-as search cql "space = 'DOCS' AND type = page"

# With limit
confluence-as search cql "label = 'approved'" --limit 50

# Show excerpts
confluence-as search cql "text ~ 'config'" --show-excerpts
```

**Arguments:**
- `cql` - CQL query string (required)
- `--limit, -l` - Maximum results (default: 25)
- `--show-excerpts` - Show content excerpts
- `--show-labels` - Show content labels
- `--show-ancestors` - Show ancestor pages
- `--output, -o` - Output format: text or json

### confluence-as search validate

Validate CQL query syntax.

**Usage:**
```bash
confluence-as search validate "space = 'DOCS' AND type = page"
confluence-as search validate "invalid query (("
```

**Arguments:**
- `cql` - CQL query to validate (required)

### confluence-as search suggest

Get CQL field and value suggestions.

**Usage:**
```bash
# Get field suggestions
confluence-as search suggest --fields

# Get values for a field
confluence-as search suggest --field space
confluence-as search suggest --field type

# Get operators and functions
confluence-as search suggest --operators
confluence-as search suggest --functions
```

**Arguments:**
- `--fields` - List all available CQL fields
- `--field NAME` - Get values for a specific field
- `--operators` - List all CQL operators
- `--functions` - List all CQL functions
- `--output, -o` - Output format: text or json

### confluence-as search interactive

Interactive CQL query builder.

**Usage:**
```bash
confluence-as search interactive
confluence-as search interactive --space DOCS
confluence-as search interactive --type page --execute
```

**Arguments:**
- `--space` - Pre-filter by space
- `--type` - Pre-filter by content type: page, blogpost, comment, or attachment
- `--limit, -l` - Maximum results (default: 25)
- `--execute` - Execute query after building

### confluence-as search export

Export search results to file.

**Usage:**
```bash
# Export to CSV
confluence-as search export "space = 'DOCS'" --format csv --output results.csv

# Export to JSON
confluence-as search export "label = 'api'" --format json --output results.json

# Select columns
confluence-as search export "type = page" --columns id,title,space,created --output pages.csv
```

**Arguments:**
- `cql` - CQL query (required)
- `--format, -f` - Output format: csv or json (default: csv)
- `--output, -o` - Output file path (required)
- `--columns` - Columns to include (comma-separated)
- `--limit, -l` - Maximum results

### confluence-as search stream-export

Export large result sets with checkpoints.

**Usage:**
```bash
# Full export with progress
confluence-as search stream-export "space = 'DOCS'" --output docs.csv

# Resume from checkpoint
confluence-as search stream-export "space = 'DOCS'" --output docs.csv --resume

# Custom batch size
confluence-as search stream-export "type = page" --output pages.csv --batch-size 50
```

**Arguments:**
- `cql` - CQL query (required)
- `--output, -o` - Output file path (required)
- `--format, -f` - Output format: csv or json (inferred from extension if not specified)
- `--columns` - Columns to include (comma-separated)
- `--batch-size` - Records per batch (default: 100)
- `--resume` - Resume from last checkpoint

### confluence-as search history

Manage local query history.

**Usage:**
```bash
# List recent queries
confluence-as search history list
confluence-as search history list --limit 10

# Search history
confluence-as search history search "space = DOCS"

# Show specific query by index
confluence-as search history show 5

# Clear history
confluence-as search history clear

# Export history to file
confluence-as search history export history.csv
confluence-as search history export history.json --format json

# Cleanup old entries
confluence-as search history cleanup --days 30
```

**Subcommands:**
- `list` - List recent queries (--limit default: 20, --output)
- `search KEYWORD` - Search history for queries containing keyword
- `show INDEX` - Show specific query by index
- `clear` - Clear all query history
- `export FILE` - Export history to file (--format: csv or json)
- `cleanup` - Remove old entries (--days default: 90)

### confluence-as search content

Simple text search (no CQL knowledge required).

**Usage:**
```bash
confluence-as search content "meeting notes"
confluence-as search content "meeting notes" --space DOCS
confluence-as search content "API documentation" --type page
```

**Arguments:**
- `query` - Search text (required)
- `--space` - Limit to space
- `--type` - Content type: page or blogpost. Omit the flag to search all types. (The CLI also accepts `all`, but that injects the literal `type = all` into the CQL, which the server rejects - do not use it.)
- `--limit, -l` - Maximum results
- `--output, -o` - Output format

## Examples

### Natural Language Triggers

- "Search for pages about API documentation"
- "Find all pages with label 'approved' in DOCS space"
- "Search for content created this month"
- "Export all pages in KB space to CSV"
- "Find pages modified by me today"

---

## Common Pitfalls

### 1. CQL Syntax Errors
- **Problem**: Query fails with syntax error
- **Solution**: Use `confluence-as search validate "query"` to check syntax first

### 2. Quoting Issues
- **Problem**: Values with spaces not matching
- **Solution**: Use double quotes: `space = "My Space"` or single quotes: `label = 'my-label'`

### 3. Case Sensitivity
- **Problem**: Search not finding expected results
- **Solution**: Text search (`~`) is case-insensitive, but `=` is exact match

### 4. Date Format
- **Problem**: Date queries failing
- **Solution**: Use `YYYY-MM-DD` format or functions like `startOfWeek()`, `now("-7d")`

### 5. Large Result Sets
- **Problem**: Export timing out or running slow
- **Solution**: Use `stream-export` for large datasets, add `--batch-size` option

### 6. Empty Results
- **Problem**: Search returns nothing when content exists
- **Solution**: Check space permissions, verify space key is correct, try broader query

---

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| **400 Bad Request** | Invalid CQL syntax | Use `confluence-as search validate` to check query |
| **403 Forbidden** | No permission to search space | Request space access |
| **408 Timeout** | Query too complex or large result set | Simplify query, use pagination |

### CQL Troubleshooting

**Validate query before running:**
```bash
confluence-as search validate "space = 'DOCS' AND type = page"
```

**Build query interactively:**
```bash
confluence-as search interactive --space DOCS
```

**Check available fields:**
```bash
confluence-as search suggest --fields
confluence-as search suggest --field space
```

**Common CQL fixes:**
```cql
# Wrong: unquoted space with spaces
space = My Space

# Right: quoted space name
space = "My Space"

# Wrong: wrong date format
created > 01-15-2025

# Right: correct date format
created > "2025-01-15"

# Wrong: invalid operator for text
text = "exact match"

# Right: use contains operator
text ~ "search text"
```
