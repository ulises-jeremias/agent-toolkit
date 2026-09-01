# Confluence Permission API Endpoints Reference

## Overview

This document details the Confluence API endpoints used by the permission skill scripts.

## API Version Strategy

Due to API maturity, this skill uses a hybrid approach:
- **v2 API**: For reading space permissions (when available)
- **v1 API**: For modifying permissions and managing page restrictions

## Space Permissions

### GET Space Permissions (v2 API)

**Endpoint:** `GET /api/v2/spaces/{id}/permissions`

**Description:** Returns space permission assignments for a specific space.

**Required Scopes:**
- OAuth: `read:space.permission:confluence`
- Connect: `READ`

**Response:**
```json
{
  "results": [
    {
      "principal": {
        "type": "user|group",
        "id": "account-id-or-group-id"
      },
      "operation": {
        "key": "read|write|administer|...",
        "target": "space"
      }
    }
  ],
  "_links": {}
}
```

**Limitations:**
- Read-only in v2 API
- Cannot add or remove permissions via v2
- Apps cannot access this resource (including user impersonation)

### Add Space Permission (v1 API)

**Endpoint:** `POST /rest/api/space/{key}/permission`

**Description:** Adds a permission to a space.

**Request Body:**
```json
{
  "subject": {
    "type": "user|group",
    "identifier": {
      "user": {"results": [{"username": "user@example.com"}], "size": 1},
      "group": {"results": [{"name": "groupname"}], "size": 1}
    }
  },
  "operation": {
    "key": "read|write|administer|...",
    "target": "space"
  }
}
```

**Valid Operations:**
- `read` - View space content
- `write` - Create and edit content
- `create` - Create pages
- `delete` - Delete content
- `export` - Export content
- `administer` - Manage space
- `setpermissions` - Modify permissions
- `createattachment` - Add attachments

**Limitations:**
- May be restricted by Confluence instance settings
- Requires admin permissions in most cases

### Remove Space Permission (v1 API)

**Endpoint:** `DELETE /rest/api/space/{key}/permission/{id}`

**Description:** Removes a permission from a space.

**Process:**
1. First, GET existing permissions to find the permission ID
2. Then, DELETE using the found ID

## Page Restrictions

### GET Page Restrictions (v1 API)

**Endpoint:** `GET /rest/api/content/{id}/restriction`

**Description:** Returns the restrictions on a page.

**Query Parameters:**
- `expand`: `restrictions.user,restrictions.group` (recommended)

**Response:**
```json
{
  "read": {
    "operation": "read",
    "restrictions": {
      "user": {
        "results": [
          {
            "type": "known",
            "username": "user@example.com",
            "userKey": "user-key",
            "accountId": "account-id"
          }
        ],
        "size": 1
      },
      "group": {
        "results": [
          {
            "type": "group",
            "name": "groupname",
            "id": "group-id"
          }
        ],
        "size": 1
      }
    }
  },
  "update": {
    "operation": "update",
    "restrictions": {...}
  }
}
```

**Limitations:**
- Only shows direct restrictions, not inherited ones
- Feature request CONFCLOUD-71108 tracks inherited restrictions support

### Add/Update Page Restrictions (v1 API)

**Endpoint:** `PUT /rest/api/content/{id}/restriction`

**Description:** Updates restrictions on a page.

**Request Body:**
```json
[
  {
    "operation": "read|update",
    "restrictions": {
      "user": [
        {"type": "known", "username": "user@example.com"}
      ],
      "group": [
        {"type": "group", "name": "groupname"}
      ]
    }
  }
]
```

**Process:**
1. GET current restrictions
2. Modify the restrictions array (add/remove principals)
3. PUT the updated restrictions back

**Notes:**
- This is a full replace operation, not a patch
- Must include all existing restrictions plus new ones
- To remove a restriction, omit it from the array
- Empty arrays remove all restrictions of that type

## Principal Formats

### User Principals

**By Email:**
```json
{"username": "user@example.com"}
```

**By Account ID:**
```json
{"accountId": "account-id-12345"}
```

**By Username (legacy):**
```json
{"username": "jdoe"}
```

### Group Principals

**By Name:**
```json
{"name": "confluence-users"}
```

**By ID:**
```json
{"id": "group-id-67890"}
```

## Error Responses

### 400 Bad Request
Invalid input (malformed JSON, invalid operation type, etc.)

### 401 Unauthorized
Authentication failed (invalid credentials)

### 403 Forbidden
User lacks permission to perform the operation

### 404 Not Found
Space or page does not exist

### 429 Rate Limit Exceeded
Too many requests (wait and retry)

## Best Practices

### When to Use v1 vs v2

**Use v2 API when:**
- Reading space permissions
- You need the latest API features
- Pagination support is important

**Use v1 API when:**
- Modifying space permissions
- Managing page restrictions
- v2 doesn't support the operation yet

### Rate Limiting

- Effective February 2, 2026: New points-based rate limits
- Each API call consumes points based on complexity
- Per-tenant limits based on edition (Standard/Premium/Enterprise)
- Implement exponential backoff for 429 responses

### Security Considerations

- Always validate user permissions before showing sensitive data
- Use groups instead of individual users when possible
- Log all permission changes for audit purposes
- Test permission changes with a non-admin account

## References

- [Confluence Cloud REST API v2 - Space Permissions](https://developer.atlassian.com/cloud/confluence/rest/v2/api-group-space-permissions/)
- [Confluence Cloud REST API - Rate Limiting](https://developer.atlassian.com/cloud/confluence/rate-limiting/)
- [CONFCLOUD-71108: List inherited page restrictions](https://jira.atlassian.com/browse/CONFCLOUD-71108)
