# Confluence Watch API Reference

## Overview

The Watch API allows users to follow content and receive notifications. This reference covers the v1 REST API endpoints used for watching functionality.

## Authentication

All endpoints require HTTP Basic Authentication:
- Username: Confluence account email
- Password: API token from https://id.atlassian.com/manage-profile/security/api-tokens

## Base URL

```
https://{your-site}.atlassian.net/wiki
```

## Endpoints

### Watch Content

**POST** `/rest/api/user/watch/content/{contentId}`

Start watching a page, blog post, or other content.

**Path Parameters:**
- `contentId` (string, required) - The ID of the content to watch

**Response:**
- Status: 200 OK (even if already watching)
- Body: Empty or minimal success indicator

**Example:**
```bash
curl -X POST \
  -u email@example.com:api_token \
  https://your-site.atlassian.net/wiki/rest/api/user/watch/content/123456
```

### Unwatch Content

**DELETE** `/rest/api/user/watch/content/{contentId}`

Stop watching a page, blog post, or other content.

**Path Parameters:**
- `contentId` (string, required) - The ID of the content to unwatch

**Response:**
- Status: 200 OK or 204 No Content (even if not watching)
- Body: Empty

**Example:**
```bash
curl -X DELETE \
  -u email@example.com:api_token \
  https://your-site.atlassian.net/wiki/rest/api/user/watch/content/123456
```

### Watch Space

**POST** `/rest/api/user/watch/space/{spaceKey}`

Start watching a space to receive notifications for new content.

**Path Parameters:**
- `spaceKey` (string, required) - The key of the space to watch

**Response:**
- Status: 200 OK
- Body: Empty or minimal success indicator

**Example:**
```bash
curl -X POST \
  -u email@example.com:api_token \
  https://your-site.atlassian.net/wiki/rest/api/user/watch/space/DOCS
```

### Unwatch Space

**DELETE** `/rest/api/user/watch/space/{spaceKey}`

Stop watching a space.

**Path Parameters:**
- `spaceKey` (string, required) - The key of the space to unwatch

**Response:**
- Status: 200 OK or 204 No Content
- Body: Empty

**Example:**
```bash
curl -X DELETE \
  -u email@example.com:api_token \
  https://your-site.atlassian.net/wiki/rest/api/user/watch/space/DOCS
```

### Get Watchers

**GET** `/rest/api/content/{contentId}/notification/created`

Get the list of users watching a specific piece of content.

**Path Parameters:**
- `contentId` (string, required) - The ID of the content

**Response:**
- Status: 200 OK
- Body: Watchers list

**Response Schema:**
```json
{
  "results": [
    {
      "type": "known",
      "accountId": "user-account-id",
      "email": "user@example.com",
      "displayName": "User Name",
      "publicName": "User Name"
    }
  ],
  "start": 0,
  "limit": 200,
  "size": 1
}
```

**Example:**
```bash
curl -X GET \
  -u email@example.com:api_token \
  https://your-site.atlassian.net/wiki/rest/api/content/123456/notification/created
```

### Get Current User

**GET** `/rest/api/user/current`

Get information about the currently authenticated user.

**Response:**
- Status: 200 OK
- Body: User information

**Response Schema:**
```json
{
  "type": "known",
  "accountId": "user-account-id",
  "accountType": "atlassian",
  "email": "user@example.com",
  "displayName": "User Name",
  "publicName": "User Name",
  "profilePicture": {
    "path": "/wiki/...",
    "width": 48,
    "height": 48,
    "isDefault": false
  },
  "operations": null
}
```

**Example:**
```bash
curl -X GET \
  -u email@example.com:api_token \
  https://your-site.atlassian.net/wiki/rest/api/user/current
```

## Error Responses

### 400 Bad Request
Invalid input (e.g., malformed content ID)

```json
{
  "statusCode": 400,
  "message": "Invalid content id"
}
```

### 401 Unauthorized
Invalid or missing authentication credentials

```json
{
  "statusCode": 401,
  "message": "Unauthorized"
}
```

### 403 Forbidden
User doesn't have permission to view or watch the content

```json
{
  "statusCode": 403,
  "message": "You do not have permission to view this content"
}
```

### 404 Not Found
Content or space doesn't exist

```json
{
  "statusCode": 404,
  "message": "Content not found"
}
```

### 429 Too Many Requests
Rate limit exceeded

```json
{
  "statusCode": 429,
  "message": "Rate limit exceeded"
}
```

Response includes `Retry-After` header with seconds to wait.

## Best Practices

### Idempotency
- Watching already-watched content succeeds (200 OK)
- Unwatching non-watched content succeeds (200 OK or 204 No Content)
- Safe to call repeatedly without checking status first

### Checking Watch Status
To check if a user is watching content:
1. Get current user's accountId via `/rest/api/user/current`
2. Get watchers list via `/rest/api/content/{id}/notification/created`
3. Check if accountId is in the watchers list

There is no direct "am I watching?" endpoint.

### Rate Limiting
- Confluence Cloud has rate limits (typically 10 requests/second)
- Watch endpoints count towards the limit
- Use bulk operations where possible
- Implement exponential backoff on 429 responses

### Notification Types

**Page/Blog Post Watching:**
- Content updates (edits)
- Comments added
- Attachments added
- Page moved or deleted

**Space Watching:**
- New pages created
- New blog posts created
- New top-level content in the space

**Not Included:**
- Existing page updates (must watch individual pages)
- Comment replies (unless watching the page)
- Space metadata changes

## Permissions

Users can only:
- Watch content they can view
- See watchers of content they can view
- Unwatch their own watches
- Cannot see or manage other users' watches

Admins have no special privileges for the watch API.

## Legacy APIs

### V1 Legacy (Deprecated but Still Used)

The endpoints documented above are from the v1 REST API, which is still the primary API for watch functionality as of 2024. The v2 API does not yet have comprehensive watch support.

### Future Migration

Atlassian is working on v2 API equivalents. Check the official docs for updates:
https://developer.atlassian.com/cloud/confluence/rest/v2/intro/

## Related APIs

### Content Properties
Custom metadata can be stored on watched content:
- `GET /rest/api/content/{id}/property`
- `POST /rest/api/content/{id}/property`

### User API
Get user information:
- `GET /rest/api/user` - Get user by key or username
- `GET /rest/api/user/current` - Get current user
- `GET /rest/api/user/memberof` - Get user's groups

### Search API
Find watched content using CQL:
```
watcher = currentUser()
```

## Testing

### Manual Testing
1. Watch a page via API
2. Verify in Confluence UI: User Menu → Settings → Email → Watched Pages
3. Update the page
4. Check for email notification

### Integration Testing
- Create test page
- Watch via API
- Get watchers list
- Verify current user is in list
- Unwatch via API
- Verify current user not in list
- Clean up test page

## References

- [Confluence REST API v1 Documentation](https://developer.atlassian.com/cloud/confluence/rest/v1/intro/)
- [Atlassian Cloud API Tokens](https://id.atlassian.com/manage-profile/security/api-tokens)
- [Confluence Cloud Rate Limits](https://developer.atlassian.com/cloud/confluence/rate-limiting/)
