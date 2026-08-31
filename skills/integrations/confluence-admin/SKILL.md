---
name: confluence-admin
description: 'Confluence administration including users, groups, space settings, and permission diagnostics.
  Use when managing user access, group membership, viewing space configuration, or checking permissions.

  '
triggers:
- admin
- administration
- user management
- group management
- space settings
- configure
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-admin
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

# Confluence Admin Skill

Administration tools for Confluence Cloud covering user management, group management, space settings, and permission diagnostics.

---

## PRIMARY USE CASE

**This skill handles Confluence administration tasks.** Use for:
- User search and information
- Group management and membership
- Space settings and configuration
- Permission diagnostics

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| Space settings/configuration | - |
| User/group management | - |
| Permission diagnostics | - |
| View templates | - |
| Page content CRUD | `confluence-page` |
| Single page permissions | `confluence-permission` |
| Search content | `confluence-search` |
| Create pages from templates | `confluence-template` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| List users/groups | - | Read-only |
| View settings | - | Read-only |
| View templates | - | Read-only |
| Check permissions | - | Read-only |
| Update space settings | ⚠️ | Affects space behavior |
| Create groups | ⚠️ | Can be deleted |
| Modify group membership | ⚠️⚠️ | Affects access |
| Delete groups | ⚠️⚠️ | Affects access |

---

## What This Skill Does

**4 Major Administration Areas:**

| Area | Commands | Key Operations |
|------|----------|----------------|
| **User Management** | 3 | Search, view details, list groups |
| **Group Management** | 7 | Create, delete, manage membership |
| **Space Administration** | 3 | View settings, update, permissions |
| **Templates & Permissions** | 3 | List templates, check permissions |

---

## When to Use This Skill

Reach for this skill when you need to:

**User Management:**
- Search for users by name or email
- View user details
- Check user's group memberships

**Group Management:**
- Create and delete groups
- Add/remove users from groups
- View group membership

**Space Administration:**
- View space settings
- Update space description
- View space permissions

**Permission Diagnostics:**
- Check what permissions you have on a space
- Diagnose access issues

---

## Quick Start

```bash
# List all groups
confluence-as admin group list

# Search for users
confluence-as admin user search "john"

# View space settings
confluence-as admin space settings DOCS

# List templates in a space
confluence-as admin template list --space DOCS
```

---

## Available Commands

All commands support `--help` for full documentation.

### User Management

```bash
# Search users
confluence-as admin user search "name or email"
confluence-as admin user search "john" --include-groups
confluence-as admin user search "john" --limit 50

# Get user details
confluence-as admin user get ACCOUNT_ID

# List user's groups
confluence-as admin user groups ACCOUNT_ID
```

**Options for `user search`:**
- `--include-groups` - Include group membership in results
- `--limit, -l` - Maximum results (default: 25)
- `--output, -o` - Output format: text or json

### Group Management

```bash
# List all groups
confluence-as admin group list
confluence-as admin group list --limit 100

# Get group details
confluence-as admin group get "group-name"

# List group members
confluence-as admin group members "group-name"
confluence-as admin group members "group-name" --limit 100

# Create group
confluence-as admin group create "new-group-name"

# Delete group
confluence-as admin group delete "group-name" --confirm

# Add user to group
confluence-as admin group add-user "group-name" --user "user@email.com"

# Remove user from group
confluence-as admin group remove-user "group-name" --user "user@email.com" --confirm
```

**Options for `group list`:**
- `--limit, -l` - Maximum results (default: 50)
- `--output, -o` - Output format: text or json

**Options for `group members`:**
- `--limit, -l` - Maximum results (default: 50)
- `--output, -o` - Output format: text or json

### Space Administration

```bash
# View space settings
confluence-as admin space settings SPACEKEY

# Update space description
confluence-as admin space update SPACEKEY --description "New description"

# Update space name
confluence-as admin space update SPACEKEY --name "New name"

# View space permissions
confluence-as admin space permissions SPACEKEY
```

### Templates

```bash
# List templates
confluence-as admin template list
confluence-as admin template list --space DOCS
confluence-as admin template list --limit 100

# Get template details
confluence-as admin template get TEMPLATE_ID
```

**Options for `template list`:**
- `--space, -s` - Filter by space key
- `--limit, -l` - Maximum results (default: 50)
- `--output, -o` - Output format: text or json

### Permission Diagnostics

```bash
# Check what permissions you have on a space
confluence-as admin permissions check --space DOCS

# Show only permissions you're missing
confluence-as admin permissions check --space DOCS --only-missing
```

Results are derived from the space's permission grants combined with your identity and group memberships. Each operation reports Yes, No, or Unknown (Unknown when grants cannot be read or a grant's principal type cannot be resolved).

---

## Common Patterns

### JSON Output for Scripting

```bash
confluence-as admin group list --output json
confluence-as admin user search "john" --output json
confluence-as admin template list --output json
```

The global `-o/--output` flag placed before the subcommand sets the default output format for all subcommands (an explicit subcommand flag wins):

```bash
confluence-as -o json admin group list
```

---

## Permission Requirements

| Operation | Required Permission |
|-----------|---------------------|
| View settings | Space View |
| Update space | Space Admin |
| View templates | Space View |
| User/Group (read) | Browse Users |
| User/Group (write) | Site Admin |

---

## Common Errors

| Error | Solution |
|-------|----------|
| 403 Forbidden | Verify you have Space Admin or Site Admin permission |
| 404 Not Found | Check space key, template ID, or user ID |
| 409 Conflict | Resource exists - choose different name |
| 400 Bad Request | Validate input format (see command --help) |

---

## Troubleshooting

### Diagnose Permission Issues

```bash
# Check what permissions you have on a space
confluence-as admin permissions check --space DOCS

# Show only permissions you're missing
confluence-as admin permissions check --space DOCS --only-missing

# See who has access via groups
confluence-as admin space permissions DOCS

# Check your group memberships
confluence-as admin user groups YOUR_ACCOUNT_ID
```

### Verify User Access

```bash
# Find user by email
confluence-as admin user search "user@email.com"

# Check their groups
confluence-as admin user groups ACCOUNT_ID
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Any API or validation error (auth, permission, not found, rate limit, conflict, server) |
| 2 | Malformed command line (unknown flag, missing argument) |
| 130 | Cancelled (Ctrl+C) |

All API failures exit 1; the error message on stderr states the specific
cause (authentication, permission, not found, etc.).

---

## Related Skills

| Skill | Use Case |
|-------|----------|
| **confluence-space** | Create/delete spaces |
| **confluence-page** | Page CRUD |
| **confluence-permission** | Single-page permissions |
| **confluence-bulk** | Bulk operations |
| **confluence-template** | Create pages from templates |
| **confluence-ops** | Cache management |

---

## Best Practices

### Group Management Workflow

1. Create role-based groups (viewers, editors, admins)
2. Add users to appropriate groups: `confluence-as admin group add-user ...`
3. Verify membership: `confluence-as admin group members ...`

### Permission Diagnostics Workflow

1. Check your permissions: `confluence-as admin permissions check --space DOCS`
2. Review space permissions: `confluence-as admin space permissions DOCS`
3. Verify group membership: `confluence-as admin user groups ACCOUNT_ID`
