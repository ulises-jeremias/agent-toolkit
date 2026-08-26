---

name: confluence-jira
description: JIRA integration - embed issues, create links between products. ALWAYS use when user wants to connect Confluence and JIRA.
triggers:
  - jira
  - embed issue
  - link jira
  - jira macro
  - jira issues
  - jira link
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-jira
  ref: 403eac8ad8a0812e6d41ed70cbc0fdf2ff4b7542
  license: MIT
trust:
  tier: reviewed
  reviewed_at: '2026-08-26'
  reviewed_by: ulises-jeremias
  reviewed_provenance: sha256:856bee6a92047948f10c645670c4a7fc3de52662398bac49fc7ce27efbd25b7d
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

# Confluence JIRA Skill

Cross-product JIRA integration for Confluence.

---

## ⚠️ PRIMARY USE CASE

**This skill connects Confluence and JIRA.** Use for:
- Embedding JIRA issues in pages
- Creating JIRA macros
- Linking pages to issues
- Displaying issue lists via JQL

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| Embed JIRA issues | - |
| Add JIRA macro | - |
| Link to JIRA | - |
| Create JIRA issues | Use JIRA directly |
| Edit page content | `confluence-page` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| Embed issues | ⚠️ | Modifies page content |
| Add JIRA macro | ⚠️ | Modifies page content |
| Link to JIRA | ⚠️ | Modifies page content (adds a link marker, creating a new page version) |

---

## Overview

Cross-product JIRA integration for embedding JIRA issues in Confluence pages, recording links to JIRA issues on Confluence pages (one-way: the JIRA issue itself is not modified), and managing JIRA macros.

## CLI Commands

All commands use the `confluence-as` binary. The global `-o/--output` flag placed before the subcommand (e.g. `confluence-as -o json jira linked 12345`) sets the default output format for all subcommands; an explicit subcommand-level `--output` wins.

### confluence-as jira embed
Embed JIRA issues in a page using JQL query or specific issue keys.

**Usage:**
```bash
# Embed issues matching a JQL query
confluence-as jira embed 12345 --jql "project = PROJ AND status = Open"

# Embed specific issues by key
confluence-as jira embed 12345 --issues PROJ-123,PROJ-456

# Replace page content with JIRA macro (instead of append)
confluence-as jira embed 12345 --jql "project = PROJ" --mode replace

# Customize columns and limit results
confluence-as jira embed 12345 --jql "assignee = currentUser()" --columns key,summary,status --max-results 50

# With specific JIRA server
confluence-as jira embed 12345 --jql "project = PROJ" --server-id abc123

# JSON output
confluence-as jira embed 12345 --issues PROJ-123 --output json
```

**Options:**
- `--jql`: JQL query to filter issues (either --jql or --issues must be provided)
- `--issues`: Comma-separated list of issue keys. If both `--jql` and `--issues` are provided, `--jql` takes precedence and `--issues` is silently ignored.
- `--mode`: How to add the macro: `append` (default) or `replace`
- `--server-id`: JIRA server ID (optional)
- `--columns`: Columns to display (comma-separated)
- `--max-results`: Maximum number of issues (default: 20)
- `--output`: Output format (`text` or `json`)

### confluence-as jira linked
List JIRA issues linked to a page.

**Usage:**
```bash
confluence-as jira linked 12345
confluence-as jira linked 12345 --output json
```

**Options:**
- `--output`: Output format (`text` or `json`)

### confluence-as jira create-from-page
Create a JIRA issue from Confluence page content. Uses page title as summary and extracted text as description.

**Usage:**
```bash
# Basic usage (requires JIRA env vars: JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN)
confluence-as jira create-from-page 12345 --project PROJ --type Task

# With priority and assignee
confluence-as jira create-from-page 12345 --project PROJ --type Bug --priority High --assignee jsmith

# With explicit JIRA credentials
confluence-as jira create-from-page 12345 --project PROJ --type Story \
  --jira-url https://jira.example.com \
  --jira-email user@example.com \
  --jira-token your-api-token

# JSON output
confluence-as jira create-from-page 12345 --project PROJ --type Task --output json
```

**Options:**
- `--project`, `-p`: JIRA project key (required)
- `--type`, `-t`: Issue type (default: Task). Common values include: Task, Story, Bug, Epic, Subtask, Improvement, New Feature. Any valid issue type for your JIRA project is accepted.
- `--priority`: Priority level (e.g., High, Medium, Low)
- `--assignee`: Assignee username/account ID
- `--jira-url`: JIRA base URL (or set JIRA_URL env var)
- `--jira-email`: JIRA email (or set JIRA_EMAIL env var)
- `--jira-token`: JIRA API token (or set JIRA_API_TOKEN env var)
- `--output`: Output format (`text` or `json`)

### confluence-as jira link
Link a Confluence page to a JIRA issue. The link is recorded on the Confluence page only; the JIRA issue itself is not modified.

**Implementation Note:** Links are tracked using HTML comment markers in the page content (e.g., `<!-- JIRA-LINK: PROJ-123 -->`). The `--skip-if-exists` option checks the page's metadata properties for an existing reference to the issue key before adding a link.

**Usage:**
```bash
# Basic link (jira-url is required)
confluence-as jira link 12345 PROJ-123 --jira-url https://jira.example.com

# With custom relationship type
confluence-as jira link 12345 PROJ-123 --jira-url https://jira.example.com --relationship documents

# Skip if link already exists
confluence-as jira link 12345 PROJ-123 --jira-url https://jira.example.com --skip-if-exists

# JSON output
confluence-as jira link 12345 PROJ-123 --jira-url https://jira.example.com --output json
```

**Options:**
- `--jira-url`: Base JIRA URL (required, e.g., https://jira.example.com)
- `--relationship`: Relationship type (default: "relates to"). Common values include: relates to, documents, mentions, references, implements. Any string value is accepted. Note: This is descriptive metadata reported in the command output; it is not stored on the page and does not affect how Confluence or JIRA process the link itself.
- `--skip-if-exists`: Skip if link already exists
- `--output`: Output format (`text` or `json`)

### confluence-as jira sync-macro
Refresh or update JIRA macros on a page. Can force a page update to trigger macro refresh or update JQL queries in existing macros.

**Usage:**
```bash
# Force page update to refresh all JIRA macros
confluence-as jira sync-macro 12345

# Update JQL in all JIRA macros on the page
confluence-as jira sync-macro 12345 --update-jql "project = PROJ AND status = Open"

# Update JQL in a specific macro by index (0-based)
confluence-as jira sync-macro 12345 --update-jql "status = Done" --macro-index 0

# JSON output
confluence-as jira sync-macro 12345 --output json
```

**Options:**
- `--update-jql`: New JQL query to set in macros
- `--macro-index`: Index of macro to update (0-based). If not specified, updates all macros
- `--output`: Output format (`text` or `json`)
