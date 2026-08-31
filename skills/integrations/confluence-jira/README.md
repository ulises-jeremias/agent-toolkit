# Confluence-JIRA Skill

Cross-product integration between Confluence and JIRA, enabling seamless linking and embedding of issues in documentation.

## Features

- Embed JIRA issues in Confluence pages using macros
- Extract and list JIRA issues referenced in pages
- Link Confluence pages to JIRA issues
- Create JIRA issues from Confluence page content
- Sync and refresh JIRA macro content

## Commands

All operations use the `confluence-as jira` command group from the
[`confluence-as`](https://pypi.org/project/confluence-as/) CLI
(`pip install "confluence-as>=1.1.1"`).

### 1. jira embed

Embed JIRA issues in a Confluence page using JIRA macros.

**Usage:**
```bash
# Embed issues via JQL query
confluence-as jira embed 12345 --jql "project = PROJ AND status = Open"

# Embed specific issues
confluence-as jira embed 12345 --issues PROJ-123,PROJ-456

# Replace page content with macro
confluence-as jira embed 12345 --jql "project = PROJ" --mode replace

# With custom columns
confluence-as jira embed 12345 --jql "status = Open" --columns key,summary,status,assignee
```

**Options:**
- `--jql`: JQL query to filter issues
- `--issues`: Comma-separated list of issue keys
- `--mode`: `append` (default) or `replace`
- `--server-id`: JIRA server ID (optional)
- `--columns`: Columns to display in macro
- `--max-results`: Maximum issues to display (default: 20)

### 2. jira linked

Extract and list JIRA issues linked to a Confluence page.

**Usage:**
```bash
# Get all JIRA issues mentioned in a page
confluence-as jira linked 12345

# JSON output
confluence-as jira linked 12345 --output json
```

**What it extracts:**
- JQL queries from JIRA issues macros
- Issue keys mentioned in content (PROJ-123 format)
- `JIRA-LINK` markers added by `jira link`

### 3. jira link

Link a Confluence page to a JIRA issue.

**Usage:**
```bash
# Create link
confluence-as jira link 12345 PROJ-123 --jira-url https://jira.example.com

# With relationship type
confluence-as jira link 12345 PROJ-123 --jira-url https://jira.example.com --relationship "documents"

# Skip if already exists
confluence-as jira link 12345 PROJ-123 --jira-url https://jira.example.com --skip-if-exists
```

**Relationship types** (free text, default `relates to`; reported in the
command output, e.g. `documents`, `mentions`, `references`, `implements`).

**Behavior:** the link is recorded by appending an HTML comment marker to the
Confluence page body (see [Page-Side Link Markers](#page-side-link-markers)).
It updates the page (requires page write permission) and makes no JIRA-side
change.

### 4. jira create-from-page

Create a JIRA issue from Confluence page content.

**Usage:**
```bash
# Create a task from page
confluence-as jira create-from-page 12345 --project PROJ --type Task

# Create a bug with priority
confluence-as jira create-from-page 12345 --project PROJ --type Bug --priority High

# Assign to user
confluence-as jira create-from-page 12345 --project PROJ --type Story --assignee username
```

**Required environment variables** (or pass `--jira-url`, `--jira-email`,
`--jira-token` options):
```bash
export JIRA_URL="https://jira.example.com"
export JIRA_EMAIL="your-email@example.com"
export JIRA_API_TOKEN="your-jira-token"
```

### 5. jira sync-macro

Refresh or update JIRA macro content in a Confluence page.

**Usage:**
```bash
# Trigger page update to refresh macros
confluence-as jira sync-macro 12345

# Update JQL in all macros
confluence-as jira sync-macro 12345 --update-jql "project = PROJ AND status = Open"

# Update specific macro
confluence-as jira sync-macro 12345 --update-jql "status = Done" --macro-index 0
```

## Architecture

### JIRA Macros

This skill uses Confluence's native JIRA macros in XHTML storage format:

**Single Issue Macro:**
```xml
<ac:structured-macro ac:name="jira" ac:schema-version="1">
    <ac:parameter ac:name="key">PROJ-123</ac:parameter>
</ac:structured-macro>
```

**Multiple Issues (JQL) Macro:**
```xml
<ac:structured-macro ac:name="jira" ac:schema-version="1">
    <ac:parameter ac:name="jqlQuery">project = PROJ AND status = Open</ac:parameter>
    <ac:parameter ac:name="maximumIssues">20</ac:parameter>
</ac:structured-macro>
```

### Page-Side Link Markers

The `jira link` command records the relationship by appending an HTML comment
marker to the Confluence page's storage body:

```xml
<!-- JIRA-LINK: PROJ-123 -->
```

- The page is updated with a new version (requires page write permission)
- No JIRA-side change is made; nothing appears in JIRA
- `jira linked` detects these markers alongside JIRA macros and issue keys in text
- `--skip-if-exists` checks the page's metadata properties before adding a marker

## Testing

### Unit and Live Tests

Tests for the JIRA integration commands live in the
[`confluence-as`](https://github.com/grandcamel/confluence-as) library:

```bash
cd /path/to/confluence-as

# CLI unit tests
pytest tests/test_cli.py -v

# Live JIRA integration tests (require Confluence credentials)
pytest tests/live/test_jira_live.py tests/live/test_jira_macros_live.py \
    tests/live/test_jira_links_live.py tests/live/test_jira_roadmap_live.py --live -v
```

### Test Coverage

- Macro creation and validation
- JQL query building and validation
- Issue key extraction and regex patterns
- Link marker creation and detection
- Content update modes (append/replace)

## Common Use Cases

### 1. Track Related Issues in Documentation

```bash
# Embed all open issues for a project
confluence-as jira embed 12345 --jql "project = PROJ AND status != Done"
```

### 2. Document-Issue Relationships

```bash
# Record a page-side link to an issue
confluence-as jira link 12345 PROJ-123 --jira-url https://jira.example.com --relationship "documents"
```

### 3. Issue Audit

```bash
# Find all JIRA references in a page
confluence-as jira linked 12345 --output json
```

### 4. Issue from Requirements

```bash
# Create task from requirements page
confluence-as jira create-from-page 12345 --project PROJ --type Task --priority Medium
```

### 5. Update Issue Filters

```bash
# Update JQL to show completed items
confluence-as jira sync-macro 12345 --update-jql "project = PROJ AND status = Done"
```

## Error Handling

All commands use the shared error handling framework:

- **ValidationError**: Invalid inputs (issue keys, JQL, etc.)
- **AuthenticationError**: Invalid credentials
- **PermissionError**: Insufficient permissions
- **NotFoundError**: Page or issue not found
- **RateLimitError**: API rate limit exceeded

Errors are reported with clear messages and suggestions.

## Best Practices

1. **Use JQL for Dynamic Content**: Prefer JQL queries over static issue lists for automatic updates
2. **Set Reasonable Limits**: Use `--max-results` to prevent macro performance issues
3. **Check Existing Links**: Use `--skip-if-exists` to avoid duplicate link markers
4. **Validate JQL First**: Test JQL queries in JIRA before embedding
5. **Macro Refresh**: Confluence auto-refreshes macros, but use `confluence-as jira sync-macro` if needed

## Integration with Other Skills

- **confluence-page**: Use page CRUD operations before/after embedding issues
- **confluence-search**: Find pages with specific JIRA references
- **confluence-analytics**: Track engagement with issue-linked pages

## API Compatibility

- Uses the Confluence v2 pages API with the XHTML storage representation (required for macros)
- Issue creation calls the JIRA REST API v3 (`/rest/api/3/issue`)
- The `--skip-if-exists` link check reads v1 content metadata (`/rest/api/content/{id}`)

## Limitations

- JIRA macro rendering requires Confluence-JIRA application link to be configured
- Issue creation requires separate JIRA API credentials
- Some JIRA fields may require project-specific configuration
- `jira link` records the link in the Confluence page only; no remote link is created on the JIRA side

## Future Enhancements

Potential additions:
- Bulk issue creation from page hierarchy
- Issue import/sync capabilities
- Advanced macro parameter customization
- JIRA webhook integration for automatic updates
