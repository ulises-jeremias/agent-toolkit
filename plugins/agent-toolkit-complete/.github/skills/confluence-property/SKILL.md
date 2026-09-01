---

name: confluence-property
description: Manage content properties (custom metadata) on Confluence pages and blog posts. ALWAYS use for custom metadata, key-value data, or application-specific fields.
triggers:
  - property
  - properties
  - metadata
  - custom data
  - content property
  - page property
  - set property
  - get property
  - delete property
  - list properties
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-property
  ref: 403eac8ad8a0812e6d41ed70cbc0fdf2ff4b7542
  license: MIT
trust:
  tier: reviewed
  reviewed_at: '2026-08-26'
  reviewed_by: ulises-jeremias
  reviewed_provenance: sha256:b7806d6a7006b60c46ae6a17e3e689a09a700ae6d402e254934b3c56a58cd0c8
maintenance:
  status: active
  last_checked: '2026-08-26'
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

# Confluence Property Skill

---

## ⚠️ PRIMARY USE CASE

**This skill manages custom metadata on pages.** Use for:
- Storing custom key-value data on pages
- Tracking workflow state (review status, approval)
- Integration metadata for external systems
- Structured data for automation

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| Get/set custom metadata | - |
| Store structured data | - |
| Edit page content | `confluence-page` |
| Add labels/tags | `confluence-label` |
| Set permissions | `confluence-permission` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| Get properties | - | Read-only |
| Set property | - | Can be overwritten |
| Delete property | ⚠️ | Data loss |

---

## Overview

Manages content properties on Confluence pages. Content properties are custom metadata stored as key-value pairs attached to a page. They are useful for storing application-specific data, configuration, or custom fields.

**Use Cases:**
- Store custom metadata on pages (e.g., review status, approval date)
- Implement custom workflows with property-based state tracking
- Store configuration data for external integrations
- Tag content with structured data for automated processing

## CLI Commands

All commands use the `confluence-as` binary. The global `-o/--output` flag placed before the subcommand (e.g. `confluence-as -o json property get 12345`) sets the default output format for all subcommands; an explicit subcommand-level `--output` wins.

### confluence-as property get
Retrieve content properties from a page.

**Usage:**
```bash
# Get all properties on a page
confluence-as property get 12345

# Get specific property by key
confluence-as property get 12345 --key my-property

# Get with expanded version info
confluence-as property get 12345 --expand version

# Output as JSON
confluence-as property get 12345 --output json
```

**Options:**
- `page_id` - Page ID (required)
- `--key, -k` - Specific property key to retrieve
- `--expand` - Comma-separated fields to expand (e.g., version)
- `--output, -o` - Output format: text or json

### confluence-as property set
Create or update a content property.

**Usage:**
```bash
# Set simple string value
confluence-as property set 12345 my-property --value "text value"

# Set from JSON file
confluence-as property set 12345 config --file config.json

# Set complex JSON value
confluence-as property set 12345 data --value '{"enabled": true, "count": 42}'

# Update existing property (auto-increments version)
confluence-as property set 12345 my-property --value "updated" --update
```

**Options:**
- `page_id` - Page ID (required)
- `key` - Property key (required)
- `--value, -v` - Property value (string or JSON)
- `--file, -f` - Read value from JSON file
- `--update` - Update existing property (fetches current version)
- `--version` - Explicit version number for update
- `--output, -o` - Output format: text or json

**Value Types:**
Properties can store:
- Simple strings: `"text"`
- Numbers: `42`
- Booleans: `true`/`false`
- Complex JSON objects: `{"key": "value", "array": [1, 2, 3]}`

### confluence-as property delete
Delete a content property.

**Usage:**
```bash
# Delete property (with confirmation prompt)
confluence-as property delete 12345 my-property

# Force delete without confirmation
confluence-as property delete 12345 my-property --force
```

**Options:**
- `page_id` - Page ID (required)
- `key` - Property key to delete (required)
- `--force` - Delete without confirmation
- `--output, -o` - Output format: text or json

### confluence-as property list
List and filter content properties.

**Usage:**
```bash
# List all properties
confluence-as property list 12345

# Filter by key prefix
confluence-as property list 12345 --prefix app.

# Filter by regex pattern
confluence-as property list 12345 --pattern "config.*"

# Sort by version
confluence-as property list 12345 --sort version

# Show detailed version info
confluence-as property list 12345 --expand version --verbose

# JSON output
confluence-as property list 12345 --output json
```

**Options:**
- `page_id` - Page ID (required)
- `--prefix` - Filter by key prefix
- `--pattern` - Filter by regex pattern
- `--sort` - Sort by: key or version (default: key)
- `--expand` - Comma-separated fields to expand
- `--verbose, -v` - Show detailed information
- `--output, -o` - Output format: text or json

**Note:** This command retrieves up to 100 properties maximum.

## API Reference

Uses Confluence REST API v2 page-property endpoints:

- **List/get properties**: `GET /api/v2/pages/{page_id}/properties`
- **Create property**: `POST /api/v2/pages/{page_id}/properties`
- **Update property**: `PUT /api/v2/pages/{page_id}/properties/{property_id}`
- **Delete property**: `DELETE /api/v2/pages/{page_id}/properties/{property_id}`

## Examples

### Store Review Status

```bash
# Set review status
confluence-as property set 98765 review-status --value '{"status": "approved", "date": "2024-01-15", "reviewer": "john@example.com"}'

# Get review status
confluence-as property get 98765 --key review-status

# Update review status
confluence-as property set 98765 review-status --value '{"status": "published", "date": "2024-01-20"}' --update
```

### Configuration Management

```bash
# Store config from file
confluence-as property set 12345 app-config --file config.json

# List all config properties
confluence-as property list 12345 --prefix app-

# Get specific config
confluence-as property get 12345 --key app-config
```

### Workflow State Tracking

```bash
# Initialize workflow state
confluence-as property set 12345 workflow --value '{"stage": "draft", "assignee": "alice@example.com"}'

# Update to next stage
confluence-as property set 12345 workflow --value '{"stage": "review", "assignee": "bob@example.com"}' --update

# List all workflow properties
confluence-as property list 12345 --pattern "workflow.*" --verbose
```

### Cleanup Old Properties

```bash
# List all properties
confluence-as property list 12345

# Delete specific property
confluence-as property delete 12345 old-property --force

# Delete with confirmation
confluence-as property delete 12345 temp-data
```

## Property Versioning

Properties support versioning for conflict detection:

1. **Create**: Initial version is 1
2. **Update**: Increment version number
3. **Conflict**: 409 error if version is out of sync

**Auto-version update:**
```bash
confluence-as property set 12345 my-prop --value "new value" --update
```

This automatically fetches the current version and increments it.

## Common Property Patterns

### Namespace Your Keys

Use prefixes to organize properties:
- `app.config.*` - Application configuration
- `workflow.*` - Workflow state
- `review.*` - Review metadata
- `integration.*` - External integration data

### Store Timestamps

```json
{
  "created": "2024-01-15T10:30:00Z",
  "modified": "2024-01-20T14:45:00Z",
  "reviewed": "2024-01-18T16:20:00Z"
}
```

### Track Multi-Stage Workflows

```json
{
  "stage": "review",
  "stages": ["draft", "review", "approved", "published"],
  "current_assignee": "reviewer@example.com",
  "history": [
    {"stage": "draft", "user": "author@example.com", "date": "2024-01-15"},
    {"stage": "review", "user": "reviewer@example.com", "date": "2024-01-20"}
  ]
}
```

### Store Arrays and Complex Data

```json
{
  "tags": ["important", "needs-update", "customer-facing"],
  "approvers": [
    {"name": "Alice", "email": "alice@example.com", "approved": true},
    {"name": "Bob", "email": "bob@example.com", "approved": false}
  ],
  "metrics": {
    "views": 1234,
    "likes": 56,
    "shares": 12
  }
}
```

## Error Handling

All commands handle common errors:

- **404 Not Found**: Content or property doesn't exist
- **403 Permission Denied**: Insufficient permissions
- **409 Conflict**: Version conflict on update
- **400 Validation Error**: Invalid input

Errors are printed to stderr with details and a troubleshooting hint; commands exit non-zero on failure.

## Integration Tips

### Use with Automation

```bash
# Get property value in scripts
VALUE=$(confluence-as property get 12345 --key status --output json | jq -r '.value.status')

# Conditional updates
if [ "$VALUE" == "draft" ]; then
  confluence-as property set 12345 status --value '{"status": "review"}' --update
fi
```

### Bulk Operations

```bash
# Update properties on multiple pages
for PAGE_ID in 111 222 333; do
  confluence-as property set $PAGE_ID deploy-status --value '{"deployed": true}' --update
done
```

### Property-Based Search

Properties are indexed and searchable via CQL:

```bash
# Find pages with specific property
confluence-as search cql "content.property[my-property].value = 'test'"
```

## Notes

- Properties are content-specific (not inherited by child pages)
- Property keys are case-sensitive
- Values can be any valid JSON data type
- Maximum property size depends on Confluence instance limits
- Properties are not included in page exports by default
- Use version numbers to prevent concurrent update conflicts
