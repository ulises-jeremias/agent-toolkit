# Confluence Operations Safeguards

This document outlines safety guidelines for Confluence operations, helping prevent accidental data loss and ensuring smooth recovery from errors.

---

## Risk Levels

Operations are classified by their potential impact:

| Risk Level | Symbol | Description | Examples |
|------------|--------|-------------|----------|
| **CRITICAL** | :warning::warning::warning: | Irreversible, affects multiple items | Delete space, bulk delete pages |
| **HIGH** | :warning::warning: | Destructive, single item | Delete page, remove permissions |
| **MEDIUM** | :warning: | Modifiable, may cause issues | Update page, change permissions |
| **LOW** | - | Read-only or easily reversible | Get page, list spaces, add label |

---

## Operation Risk Matrix

| Skill | Operation | Risk | Recovery |
|-------|-----------|------|----------|
| **confluence-page** | Create page | - | Delete if needed |
| | Update page | :warning: | Restore from version history |
| | Delete page | :warning::warning: | Restore from trash (30 days) |
| | Copy page | - | Delete copy if needed |
| | Move page | :warning: | Move back to original location |
| **confluence-space** | Create space | - | Delete if needed |
| | Update space | :warning: | Revert settings manually |
| | Delete space | :warning::warning::warning: | **NOT RECOVERABLE** - all content lost |
| **confluence-permission** | Add permission | - | Remove permission |
| | Remove permission | :warning::warning: | Re-add permission manually |
| | Restrict page | :warning: | Remove restriction |
| **confluence-comment** | Add comment | - | Delete comment |
| | Delete comment | :warning: | **NOT RECOVERABLE** |
| **confluence-attachment** | Upload file | - | Delete attachment |
| | Delete attachment | :warning::warning: | Restore from trash (re-upload only if purged) |
| **confluence-label** | Add label | - | Remove label |
| | Remove label | - | Re-add label |
| **confluence-property** | Set property | - | Update or delete property |
| | Delete property | :warning: | Re-create property |

---

## Pre-Operation Checklists

### Before Deleting Content

1. **Verify the target** - Confirm page/space ID or title
2. **Check dependencies** - Are other pages linking to this?
3. **Backup if needed** - Export page content first
4. **Confirm permissions** - Do you have delete access?
5. **Consider alternatives** - Archive instead of delete?

### Before Bulk Operations

1. **Start small** - Test with 1-2 items first
2. **Use search preview** - Run CQL query to see affected items
3. **Document the scope** - Note which items will be affected
4. **Have a rollback plan** - Know how to undo changes
5. **Consider timing** - Avoid peak usage hours

### Before Permission Changes

1. **Document current state** - Note existing permissions
2. **Understand inheritance** - Space vs page permissions
3. **Test with one user** - Verify access works as expected
4. **Have admin backup** - Ensure someone can fix issues

---

## Recovery Procedures

### Deleted Pages

Confluence pages go to the **Trash** and can be restored for 30 days:

1. Navigate to Space Settings > Content Tools > Trash
2. Find the deleted page
3. Click "Restore"

**Via API:**
```bash
# List trashed content
confluence-as search cql "type=page AND status=trashed"

# Note: Restoration requires manual action in UI
```

### Deleted Spaces

:warning::warning::warning: **Space deletion is PERMANENT**

There is no recovery option for deleted spaces. Before deleting:
- Export all space content
- Move important pages to another space
- Verify with stakeholders

### Incorrect Permissions

If users lose access:

1. **Space Admin** can restore permissions via Space Settings
2. **Site Admin** can access via Confluence Administration
3. Use `confluence-as permission space get` to audit current state

### Corrupted Content

If page content is corrupted:

1. **Version History** - Restore from previous version
   ```bash
   confluence-as page versions 12345
   confluence-as page restore 12345 --version 5
   ```

2. **Export/Import** - If version history is also corrupted

---

## Common Error Patterns

| Error Code | Meaning | Resolution |
|------------|---------|------------|
| **401** | Authentication failed | Check API token, verify email |
| **403** | Permission denied | Request access from space admin |
| **404** | Resource not found | Verify ID/key, check if deleted |
| **409** | Conflict (concurrent edit) | Refresh and retry |
| **429** | Rate limited | Wait 60 seconds, retry |
| **5xx** | Server error | Wait and retry, check Confluence status |

### Permission Error Diagnosis

When encountering 403 errors:

1. **Check space permissions**:
   ```bash
   confluence-as permission space get SPACE-KEY
   ```

2. **Check page restrictions**:
   ```bash
   confluence-as permission page get 12345
   ```

3. **Verify user access**:
   - Is the user in the required group?
   - Is there an explicit restriction on the page?
   - Are inherited permissions blocked?

---

## Skill-Specific Safeguards

### confluence-page

**Destructive Operations:**
- `confluence-as page delete` - Moves to trash, recoverable for 30 days (unless `--permanent` is used)
- `confluence-as page update` - Creates version history entry

**Safe Practices:**
- Always get page content before updating
- Use `--output json` to preserve structure
- Consider using `--dry-run` with `bulk` commands to preview changes

### confluence-space

**Destructive Operations:**
- `confluence-as space delete` - :warning::warning::warning: PERMANENT, no recovery

**Safe Practices:**
- Export space before deletion
- Let the confirmation prompt run; never pass `--force` casually
- Double-check space key matches intended target

### confluence-permission

**Destructive Operations:**
- `confluence-as permission space remove` / `confluence-as permission page remove` - Can lock out users
- `confluence-as permission page add` - Restrictions can hide content from users

**Safe Practices:**
- Document current permissions before changes
- Test with a single user first
- Ensure at least one admin retains access

### confluence-attachment

**Destructive Operations:**
- `confluence-as attachment delete` - Moves to trash by default (recoverable); `--purge` permanently deletes an already-trashed attachment (two-step: delete, then delete `--purge`)

**Safe Practices:**
- Download attachment before deleting
- Use `confluence-as attachment list` to verify target
- Consider versioning instead of deletion

---

## Error Response Templates

When operations fail, provide clear guidance:

### Authentication Error (401)
```
Authentication failed. Please check:
1. API token is valid (https://id.atlassian.com/manage-profile/security/api-tokens)
2. Email matches your Atlassian account
3. Site URL is correct (https://your-site.atlassian.net)
```

### Permission Error (403)
```
Permission denied for this operation.
- Space: {space_key}
- Required: {required_permission}
- Your access: {current_access}

Contact your space administrator to request access.
```

### Not Found Error (404)
```
Resource not found: {resource_type} {resource_id}
Possible causes:
1. The {resource_type} has been deleted
2. The ID/key is incorrect
3. You don't have permission to view it
```

---

## Best Practices Summary

### Before Operations
- Verify target resources exist
- Check your permission level
- Backup important data
- Test with non-production content first

### During Operations
- Monitor for errors
- Keep logs of changes
- Pause if unexpected results occur

### After Operations
- Verify expected outcomes
- Update documentation
- Notify affected users if needed

---

## Emergency Contacts

If you encounter critical issues:

1. **Confluence Status**: https://status.atlassian.com
2. **Support**: https://support.atlassian.com
3. **Community**: https://community.atlassian.com

---

<!-- PERMISSIONS
permissions:
  cli: confluence-as
  operations:
    # Safe - Read-only operations (page/space/search reads)
    - pattern: "confluence-as page get *"
      risk: safe
    - pattern: "confluence-as page versions *"
      risk: safe
    - pattern: "confluence-as hierarchy children *"
      risk: safe
    - pattern: "confluence-as hierarchy ancestors *"
      risk: safe
    - pattern: "confluence-as space get *"
      risk: safe
    - pattern: "confluence-as space list *"
      risk: safe
    - pattern: "confluence-as search cql *"
      risk: safe
    - pattern: "confluence-as permission space get *"
      risk: safe
    - pattern: "confluence-as permission page get *"
      risk: safe
    - pattern: "confluence-as comment list *"
      risk: safe
    - pattern: "confluence-as attachment list *"
      risk: safe
    - pattern: "confluence-as attachment download *"
      risk: safe
    - pattern: "confluence-as label list *"
      risk: safe
    - pattern: "confluence-as property get *"
      risk: safe
    - pattern: "confluence-as property list *"
      risk: safe

    # Caution - Modifiable but easily reversible (create/update/labels)
    - pattern: "confluence-as page create *"
      risk: caution
    - pattern: "confluence-as page update *"
      risk: caution
    - pattern: "confluence-as page copy *"
      risk: caution
    - pattern: "confluence-as page move *"
      risk: caution
    - pattern: "confluence-as page restore *"
      risk: caution
    - pattern: "confluence-as space create *"
      risk: caution
    - pattern: "confluence-as space update *"
      risk: caution
    - pattern: "confluence-as permission space add *"
      risk: caution
    - pattern: "confluence-as permission page add *"
      risk: caution
    - pattern: "confluence-as comment add *"
      risk: caution
    - pattern: "confluence-as comment update *"
      risk: caution
    - pattern: "confluence-as attachment upload *"
      risk: caution
    - pattern: "confluence-as label add *"
      risk: caution
    - pattern: "confluence-as label remove *"
      risk: caution
    - pattern: "confluence-as bulk label *"
      risk: caution
    - pattern: "confluence-as property set *"
      risk: caution
    - pattern: "confluence-as property delete *"
      risk: caution

    # Warning - Destructive but potentially recoverable (page/comment deletes)
    - pattern: "confluence-as page delete *"
      risk: warning
    - pattern: "confluence-as comment delete *"
      risk: warning
    - pattern: "confluence-as attachment delete *"
      risk: warning
    - pattern: "confluence-as permission space remove *"
      risk: warning
    - pattern: "confluence-as permission page remove *"
      risk: warning
    - pattern: "confluence-as bulk update *"
      risk: warning
    - pattern: "confluence-as bulk move *"
      risk: warning
    # bulk permission edits read RESTRICTIONS: --add-group/--add-user on a page
    # with no existing restrictions locks out every user not on the list
    - pattern: "confluence-as bulk permission *"
      risk: warning

    # Danger - IRREVERSIBLE or mass-destructive operations
    - pattern: "confluence-as space delete *"
      risk: danger
    # page delete --permanent bypasses trash and cannot be recovered. The flag can
    # appear anywhere on the command line; the pattern below only matches the
    # flag-last form — treat ANY `page delete` invocation containing --permanent
    # as danger, overriding the generic `page delete` warning pattern above.
    - pattern: "confluence-as page delete * --permanent*"
      risk: danger
    # bulk delete sends pages to trash (recoverable ~30 days), but restoration is
    # manual per page — the risk matrix above classifies it CRITICAL
    - pattern: "confluence-as bulk delete *"
      risk: danger
-->
