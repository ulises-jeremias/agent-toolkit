---
name: confluence-permission
description: Manage space and page permissions and restrictions. ALWAYS use when user wants to control
  access, set restrictions, or manage who can view/edit content.
triggers:
- permission
- permissions
- restrict
- access
- security
- who can view
- who can edit
- lock page
- restrict access
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-permission
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

# Confluence Permission Skill

Manage space and page permissions and restrictions.

---

## ⚠️ PRIMARY USE CASE

**This skill controls who can access Confluence content.** Use this skill for:
- Setting space-level permissions (who can view/edit a space)
- Adding page restrictions (limit access to specific users/groups)
- Auditing current permissions and restrictions

**⚠️⚠️ WARNING**: Permission changes can lock users out of content. Always document current permissions before making changes.

---

## When to Use This Skill

| Trigger | Example |
|---------|---------|
| View permissions | "Who can access DOCS space?", "Show page restrictions" |
| Add permissions | "Give engineering-team read access to DOCS" |
| Remove permissions | "Remove John's access to page 12345" |
| Restrict pages | "Lock this page to admins only" |
| Audit access | "List all permissions for TEAMSPACE" |

---

## When NOT to Use This Skill

| Operation | Use Instead |
|-----------|-------------|
| Create/edit pages | `confluence-page` |
| Search for content | `confluence-search` |
| Manage space settings | `confluence-space` |
| View who's watching | `confluence-watch` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| Get permissions | - | Read-only |
| Add permission | ⚠️ | Grants access, can be removed |
| Remove permission | ⚠️⚠️ | **Can lock users out** |
| Add page restriction | ⚠️⚠️ | **Can hide content from users** |
| Remove all restrictions | ⚠️ | Opens page to all space members |

---

## Overview

This skill provides comprehensive permission management for Confluence:
- **Space Permissions**: Control who can access and administer entire spaces
- **Page Restrictions**: Limit read/edit access to specific pages

Note: Due to API limitations, this skill uses a hybrid approach:
- v2 API for reading space permissions
- v1 API for modifying space permissions and managing page restrictions

## CLI Commands

### confluence-as permission space get
Retrieve the list of permissions assigned to a space.

**Usage:**
```bash
confluence-as permission space get SPACE_KEY
confluence-as permission space get DOCS --output json
```

**Output:** Lists all users and groups with their assigned operations (read, write, administer, etc.)

**Note:** Use `--output json` to see permission IDs, which are required for removing specific permissions with `confluence-as permission space remove --permission-id`.

### confluence-as permission space add
Grant a permission to a user or group for a space.

**Usage:**
```bash
confluence-as permission space add SPACE_KEY --user ACCOUNT_ID --operation read
confluence-as permission space add DOCS --group confluence-users --operation create
confluence-as permission space add TEST --user 557058:12345678-abcd-1234-efgh-123456789abc --operation administer
confluence-as permission space add DOCS --group editors --operation create --target page
```

**Options:**
- `--user` - User account ID (plain ID, no prefix)
- `--group` - Group name
- `--operation` - Permission operation (required)
- `--target` - Target type (default: `space`)

**Valid Operations:**
- `read` - View content
- `create` - Create content
- `delete` - Delete content
- `administer` - Manage space
- `archive` - Archive content
- `restrict_content` - Set content restrictions
- `export` - Export content

**Valid Targets:**
- `space` - Space-level permission (default)
- `page` - Page-level permission
- `blogpost` - Blog post permission
- `comment` - Comment permission
- `attachment` - Attachment permission

### confluence-as permission space remove
Revoke a permission from a user or group for a space.

**Usage:**
```bash
# Method 1: Remove by permission ID (preferred)
confluence-as permission space remove SPACE_KEY --permission-id 12345
confluence-as permission space remove DOCS -p 67890

# Method 2: Remove by user/group + operation (finds and removes matching permissions)
confluence-as permission space remove SPACE_KEY --user ACCOUNT_ID --operation read
confluence-as permission space remove DOCS --group confluence-users --operation create
```

**Options:**
- `--permission-id`, `-p` - Permission ID to remove (primary method)
- `--user` - User account ID (requires `--operation`)
- `--group` - Group name (requires `--operation`)
- `--operation` - Operation to match (REQUIRED when using `--user` or `--group`)

**Note:** Use `confluence-as permission space get` to find permission IDs.

### confluence-as permission page get
List restrictions on a page (who can read/edit).

**Usage:**
```bash
confluence-as permission page get PAGE_ID
confluence-as permission page get 123456 --output json
```

**Output:** Shows read and update restrictions with users and groups

### confluence-as permission page add
Add a restriction to limit page access.

**Usage:**
```bash
confluence-as permission page add PAGE_ID --operation read --user ACCOUNT_ID
confluence-as permission page add 123456 --operation update --group confluence-users
confluence-as permission page add 123456 --operation read --user 557058:12345678-abcd-1234-efgh-123456789abc
```

**Options:**
- `--user` - User account ID (plain ID, no prefix)
- `--group` - Group name
- `--operation` - Restriction type (required): `read` or `update`

**Restriction Types:**
- `read` - Who can view the page
- `update` - Who can edit the page

### confluence-as permission page remove
Remove a restriction from a page.

**Usage:**
```bash
confluence-as permission page remove PAGE_ID --operation read --user ACCOUNT_ID
confluence-as permission page remove 123456 --operation update --group confluence-users
confluence-as permission page remove 123456 --operation read --all
```

**Options:**
- `--user` - User account ID to remove from restriction
- `--group` - Group name to remove from restriction
- `--operation` - Restriction type (required): `read` or `update`
- `--all` - Remove all restrictions of this type

Use `--all` to remove all restrictions of a type (makes page accessible to all space members).

## Examples

### Restrict a confidential page
```bash
# Get current restrictions
confluence-as permission page get 123456

# Add read restriction to specific users (use account IDs)
confluence-as permission page add 123456 --operation read --user 557058:john-account-id
confluence-as permission page add 123456 --operation read --user 557058:jane-account-id

# Add edit restriction to admins group
confluence-as permission page add 123456 --operation update --group confluence-administrators
```

### Grant space access to a team
```bash
# Add read permission for the team
confluence-as permission space add TEAMSPACE --group engineering-team --operation read

# Add create permission for contributors (to create pages)
confluence-as permission space add TEAMSPACE --group engineering-leads --operation create --target page

# Verify permissions
confluence-as permission space get TEAMSPACE
```

### Remove all restrictions from a page
```bash
# Remove all read restrictions (make viewable to all space members)
confluence-as permission page remove 123456 --operation read --all

# Remove all update restrictions (make editable to all space members)
confluence-as permission page remove 123456 --operation update --all
```

## Important Notes

### API Limitations
- Space permission management via API may be restricted by Confluence administrators
- Inherited page restrictions are not shown in API responses (CONFCLOUD-71108)
- Admin keys cannot bypass restrictions when using the API

### Permission Hierarchy
- Space permissions apply to all content in the space
- Page restrictions override space permissions (more restrictive)
- Removing all page restrictions makes it follow space permissions

### Best Practices
- Always verify changes with `get` commands
- Use groups instead of individual users when possible
- Document permission changes in page history or space description
- Test with a non-admin account to verify restrictions work

---

## Common Pitfalls

### 1. Locking Yourself Out
- **Problem**: Removing your own access to a page/space
- **Solution**: Always ensure at least one admin retains access before changes

### 2. Inherited Restrictions Not Visible
- **Problem**: Page appears accessible but users can't view it
- **Solution**: Check parent page restrictions (API doesn't show inherited)

### 3. User vs Account ID
- **Problem**: `--user` not finding the person
- **Solution**: Use the plain account ID (e.g., `557058:12345678-abcd-1234-efgh-123456789abc`), no prefix needed

### 4. Group Name Mismatch
- **Problem**: Group not found when adding permissions
- **Solution**: Group names are case-sensitive, verify exact name in Confluence admin

### 5. Space Admin Override
- **Problem**: Page restrictions being bypassed
- **Solution**: Space admins can always access content - this is by design

### 6. API Restrictions
- **Problem**: Permission changes fail silently
- **Solution**: Some permission operations require Confluence admin privileges

---

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| **403 Forbidden** | Insufficient privileges to modify permissions | Request space admin access |
| **404 Not Found** | User, group, or resource doesn't exist | Verify user email, group name, page ID |
| **400 Bad Request** | Invalid operation or subject type | Check operation name, use correct subject type |
| **409 Conflict** | Permission already exists or conflicts | Check current permissions first |

### Recovery from Permission Errors

**Locked out of page:**
```bash
# Space admin can remove restrictions via UI or API
confluence-as permission page remove PAGE_ID --operation read --all
confluence-as permission page remove PAGE_ID --operation update --all
```

**Accidentally removed space access:**
```bash
# Confluence admin can restore via Confluence Admin > Space Permissions
# Or re-add the permission:
confluence-as permission space add SPACE_KEY --group GROUP_NAME --operation read
```

**Audit trail:**
- Space permission changes are logged in Confluence audit log
- Page restriction changes appear in page history
