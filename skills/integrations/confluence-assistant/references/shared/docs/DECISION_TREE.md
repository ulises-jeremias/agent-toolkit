# Skill Selection Decision Tree

Use this guide to determine which skill handles a given user request.

---

## Quick Decision Flow

```
User Request
    │
    ├─ Explicit skill mentioned? ──────────────────────────> Route to that skill
    │
    ├─ Contains page ID or page title?
    │   ├─ CRUD operation (create/update/delete)? ─────────> confluence-page
    │   ├─ Permission/restriction operation? ──────────────> confluence-permission
    │   ├─ Comment operation? ─────────────────────────────> confluence-comment
    │   ├─ Attachment operation? ──────────────────────────> confluence-attachment
    │   ├─ Label operation? ───────────────────────────────> confluence-label
    │   ├─ Property/metadata operation? ───────────────────> confluence-property
    │   ├─ Watch/notification operation? ──────────────────> confluence-watch
    │   ├─ Analytics/views operation? ─────────────────────> confluence-analytics
    │   └─ Parent/child/tree operation? ───────────────────> confluence-hierarchy
    │
    ├─ Contains space key only?
    │   ├─ Space CRUD operation? ──────────────────────────> confluence-space
    │   ├─ Space permission operation? ────────────────────> confluence-permission
    │   └─ Search within space? ───────────────────────────> confluence-search
    │
    ├─ Search/find/query operation?
    │   ├─ CQL query provided? ────────────────────────────> confluence-search
    │   ├─ Find by label? ─────────────────────────────────> confluence-search
    │   └─ Text search? ───────────────────────────────────> confluence-search
    │
    ├─ Template operation?
    │   ├─ Create from template? ──────────────────────────> confluence-template
    │   ├─ List/manage templates? ─────────────────────────> confluence-template
    │   └─ Blueprint operation? ───────────────────────────> confluence-template
    │
    ├─ JIRA-related operation?
    │   ├─ Embed JIRA issue? ──────────────────────────────> confluence-jira
    │   ├─ Link to JIRA? ──────────────────────────────────> confluence-jira
    │   └─ JIRA macro? ────────────────────────────────────> confluence-jira
    │
    └─ Ambiguous? ─────────────────────────────────────────> Ask for clarification
```

---

## Keyword-Based Routing

| Keywords | Primary Skill | Secondary |
|----------|---------------|-----------|
| page, blog, create, update, delete, copy, move | confluence-page | - |
| space, spaces, list spaces | confluence-space | - |
| search, find, query, CQL, export | confluence-search | - |
| comment, reply, inline, resolve | confluence-comment | - |
| attach, upload, download, file | confluence-attachment | - |
| label, tag, labels | confluence-label | confluence-search |
| template, blueprint | confluence-template | - |
| property, metadata, custom data | confluence-property | - |
| permission, restrict, access | confluence-permission | - |
| analytics, views, statistics, watchers | confluence-analytics | - |
| watch, unwatch, notify, follow | confluence-watch | - |
| parent, child, tree, hierarchy, ancestors | confluence-hierarchy | - |
| jira, issue, embed jira | confluence-jira | - |

---

## Ambiguous Request Patterns

### Pattern 1: "Show me the page"
**Problem**: Which page?
**Resolution**: Ask for page ID, title, or space context.

### Pattern 2: "Update the content"
**Problem**: What content? Page, space, comment?
**Resolution**: Ask for specific resource type and identifier.

### Pattern 3: "Add to the page"
**Problem**: Add what? Comment, label, attachment?
**Resolution**: Ask what type of content to add.

### Pattern 4: "Search for X in Confluence"
**Problem**: Could be text search or CQL query.
**Resolution**: Default to text search, offer CQL if complex.

### Pattern 5: "Who can see this?"
**Problem**: Space permissions or page restrictions?
**Resolution**: Ask for page ID or space key.

---

## Entity Signal Priority

When multiple signals are present, use this priority:

1. **Explicit skill name** - Always wins
2. **Operation verb** - create, delete, search, etc.
3. **Resource type** - page, space, comment, etc.
4. **Entity identifier** - page ID, space key

**Example**:
```
"Delete the comment on page 12345"
         │               │
         │               └── Page ID present, but...
         └── "comment" + "delete" = confluence-comment skill
```

---

## Multi-Skill Workflows

Some operations require multiple skills in sequence:

### Create Page with Labels and Restrictions
1. `confluence-page` - Create the page
2. `confluence-label` - Add labels
3. `confluence-permission` - Set restrictions

### Content Migration
1. `confluence-search` - Find source content
2. `confluence-page` - Copy pages to new space
3. `confluence-attachment` - Move attachments

### Space Setup
1. `confluence-space` - Create new space
2. `confluence-permission` - Set space permissions
3. `confluence-template` - Configure space templates

---

## When to Ask for Clarification

Ask the user when:

1. **No clear operation verb** - "The page" (what about it?)
2. **Missing identifier** - "Delete it" (delete what?)
3. **Conflicting signals** - "Search the comment" (search or comment skill?)
4. **Destructive operation** - "Remove everything" (confirm scope)
5. **Multiple valid interpretations** - Could reasonably be 2+ skills
