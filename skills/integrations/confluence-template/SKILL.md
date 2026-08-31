---
name: confluence-template
description: Work with page templates and blueprints. ALWAYS use when user wants to create standardized
  pages or manage templates.
triggers:
- template
- blueprint
- create from template
- page template
- list templates
- update template
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-template
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

# Confluence Template Skill

Work with Confluence page templates and blueprints.

---

## ⚠️ PRIMARY USE CASE

**This skill manages page templates.** Use for:
- Listing available templates
- Creating pages from templates
- Managing template content
- Working with blueprints

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| List templates | - |
| Create from template | - |
| Update template | - |
| Create page directly | `confluence-page` |
| Search templates | `confluence-search` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| List templates | - | Read-only |
| Get template | - | Read-only |
| Create from template | - | Creates new page |
| Update template | ⚠️ | Affects future pages |
| Delete template | ⚠️⚠️ | Cannot be recovered |

---

## Overview

Templates in Confluence allow you to standardize page creation. Blueprints are pre-built templates provided by Confluence or apps. This skill primarily uses the Confluence v1 REST API (`/rest/api/template/*`) for template management, while `create-from` uses the v2 API (`/api/v2/pages`) for page creation.

## CLI Commands

### confluence-as template list
List available page templates and blueprints in your Confluence instance.

**Usage:**
```bash
# List all templates
confluence-as template list

# Filter by space
confluence-as template list --space DOCS

# Filter by type (page or blogpost)
confluence-as template list --type page

# List blueprints instead of templates
confluence-as template list --blueprints

# JSON output
confluence-as template list --output json

# Limit results
confluence-as template list --limit 50
```

**Arguments:**
- `--space`, `-s`: Filter templates by space key
- `--type`, `-t`: Filter by template type (page or blogpost)
- `--blueprints`: List blueprints instead of templates
- `--output`, `-o`: Output format (text or json)
- `--limit`, `-l`: Maximum number of results (default: 100, max: 250)

### confluence-as template get
Retrieve detailed information about a specific template or blueprint.

**Usage:**
```bash
# Get template details
confluence-as template get tmpl-123

# Include body content
confluence-as template get tmpl-123 --body

# Convert body to Markdown
confluence-as template get tmpl-123 --body --format markdown

# Get blueprint details
confluence-as template get bp-456 --blueprint

# JSON output
confluence-as template get tmpl-123 --output json
```

**Arguments:**
- `template_id`: Template ID or blueprint ID
- `--body`: Include template body content
- `--format`: Body format (storage or markdown)
- `--blueprint`: Get blueprint instead of template
- `--output`, `-o`: Output format (text or json)

### confluence-as template create-from
Create a new Confluence page based on an existing template.

> **Known limitation:** `--blueprint` currently creates the page with an **empty body**. Blueprint content is not applied - the CLI never sends the blueprint ID to any API; it only records it in the command output. To get content into the page, pass `--content` or `--file`, or use `--template` instead.

**Usage:**
```bash
# Create page from template
confluence-as template create-from --template tmpl-123 --space DOCS --title "New Page"

# Create page with parent
confluence-as template create-from --template tmpl-123 --space DOCS --title "Page" --parent-id 12345

# Create from blueprint (page body will be EMPTY - see limitation note above)
confluence-as template create-from --blueprint bp-456 --space DOCS --title "Project Plan"

# Add labels
confluence-as template create-from --template tmpl-123 --space DOCS --title "Page" --labels "tag1,tag2"

# Override template content
confluence-as template create-from --template tmpl-123 --space DOCS --title "Page" --content "<p>Custom content</p>"

# Use content from file
confluence-as template create-from --template tmpl-123 --space DOCS --title "Page" --file content.md
```

**Arguments:**
- `--template`: Template ID to use
- `--blueprint`: Blueprint ID to use (alternative to --template). Currently produces an empty page body unless `--content`/`--file` is given - blueprint content is not applied
- `--space`: Space key for the new page (required)
- `--title`: Title for the new page (required)
- `--parent-id`: Parent page ID
- `--labels`: Comma-separated labels
- `--content`: Custom HTML/XHTML content
- `--file`: File with content (Markdown or HTML)
- `--output`, `-o`: Output format (text or json)

### confluence-as template create
Create a new page template in Confluence.

**Usage:**
```bash
# Create basic template (--content or --file is required)
confluence-as template create --name "Meeting Notes" --space DOCS --content "<h1>Meeting Notes</h1>"

# With description
confluence-as template create --name "Status Report" --space DOCS --description "Weekly status report" --content "<h1>Status Report</h1>"

# From HTML file
confluence-as template create --name "Template" --space DOCS --file template.html

# From Markdown file
confluence-as template create --name "Template" --space DOCS --file template.md

# With labels
confluence-as template create --name "Template" --space DOCS --file template.md --labels "template,meeting"

# Blogpost template
confluence-as template create --name "Blog Template" --space DOCS --content "<p>Blog post body</p>" --type blogpost

# Based on blueprint
confluence-as template create --name "Custom" --space DOCS --content "<p>Body</p>" --blueprint-id com.atlassian...
```

**Arguments:**
- `--name`: Template name (required)
- `--space`, `-s`: Space key (required)
- `--description`: Template description
- `--content`: Template body content (HTML/XHTML) - required if `--file` not provided
- `--file`: File with template content (Markdown or HTML) - required if `--content` not provided
- `--labels`: Comma-separated labels
- `--type`, `-t`: Template type - page or blogpost (default: page)
- `--blueprint-id`: Base on existing blueprint
- `--output`, `-o`: Output format (text or json)

Note: Either `--content` or `--file` must be provided to specify the template body.

### confluence-as template update
Update an existing page template.

**Usage:**
```bash
# Update name
confluence-as template update tmpl-123 --name "Updated Template"

# Update description
confluence-as template update tmpl-123 --description "New description"

# Update content from HTML file
confluence-as template update tmpl-123 --file updated.html

# Update from Markdown file
confluence-as template update tmpl-123 --file updated.md

# Update inline content
confluence-as template update tmpl-123 --content "<h1>Updated</h1>"

# Add labels
confluence-as template update tmpl-123 --add-labels "tag1,tag2"

# Remove labels
confluence-as template update tmpl-123 --remove-labels "old-tag"

# Multiple updates
confluence-as template update tmpl-123 --name "New Name" --description "New desc" --add-labels "new"
```

**Arguments:**
- `template_id`: Template ID to update (required)
- `--name`: New template name
- `--description`: New description
- `--content`: New body content (HTML/XHTML)
- `--file`: File with new content (Markdown or HTML)
- `--add-labels`: Comma-separated labels to add
- `--remove-labels`: Comma-separated labels to remove
- `--output`, `-o`: Output format (text or json)

Note: `--content` and `--file` are mutually exclusive.

## API Endpoints Used

This skill uses the Confluence REST API:

**v1 API (template management):**
- `GET /rest/api/template/page` - List page templates
- `GET /rest/api/content/blueprint/instance` - List blueprints
- `GET /rest/api/template/{templateId}` - Get template details
- `GET /rest/api/content/blueprint/instance/{templateId}` - Get blueprint details
- `POST /rest/api/template` - Create template
- `PUT /rest/api/template/{templateId}` - Update template

**v2 API (page creation):**
- `POST /api/v2/pages` - Create page from template (used by `create-from`)

## Examples

### Finding and Using Templates

```bash
# List all available templates
confluence-as template list

# Find templates in a specific space
confluence-as template list --space DOCS

# Get template details
confluence-as template get tmpl-123 --body --format markdown

# Create a page from that template
confluence-as template create-from --template tmpl-123 --space DOCS --title "My Meeting Notes"
```

### Creating Custom Templates

```bash
# Create a simple template (--content or --file is required)
confluence-as template create --name "Weekly Report" --space DOCS --description "Template for weekly status reports" --content "<h1>Weekly Report</h1>"

# Create from a Markdown file
confluence-as template create --name "Project Plan" --space DOCS --file project-template.md --labels "template,planning"
```

### Maintaining Templates

```bash
# Update template content from file
confluence-as template update tmpl-123 --file updated-template.md

# Add tags to categorize
confluence-as template update tmpl-123 --add-labels "engineering,documentation"

# Update name and description
confluence-as template update tmpl-123 --name "New Template Name" --description "Updated description"
```

## Tips

1. **Template IDs**: Template IDs are typically in the format `tmpl-123` or similar. Use `confluence-as template list` to find IDs.

2. **Markdown Support**: All scripts support Markdown input files, which are automatically converted to Confluence's storage format (XHTML).

3. **Blueprints vs Templates**: Blueprints are system-provided templates and typically cannot be modified. Note that `create-from --blueprint` currently produces an empty page (blueprint content is not applied); pass `--content` or `--file` to supply the body.

4. **Labels**: Use labels to organize and categorize templates for easier discovery.

5. **Preserving Content**: When updating templates, only the fields you specify are changed. Other fields are preserved.

6. **Parent Pages**: When creating pages from templates, you can specify a parent page to create a page hierarchy.

## Troubleshooting

**Template not found**: Verify the template ID with `confluence-as template list`. Template IDs are space-specific in some cases.

**Permission denied**: Ensure you have permission to create/modify templates in the specified space. Template management typically requires space admin permissions.

**Content format issues**: If template content doesn't render correctly, ensure HTML/XHTML is well-formed. Use Markdown files for easier authoring.
