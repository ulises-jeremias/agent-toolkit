# Error Handling Patterns

This document describes the error handling strategy used across Confluence Assistant Skills.

---

## Built-in Retry Logic

The `ConfluenceClient` automatically retries failed requests for transient errors:

| Attempt | Delay | Retries On |
|---------|-------|------------|
| 1 | 0s | - |
| 2 | 0s | 429, 500, 502, 503, 504 |
| 3 | ~4s | 429, 500, 502, 503, 504 |
| 4 | ~8s | 429, 500, 502, 503, 504 |

**Timeline**: Initial request + 3 retries with exponential backoff (factor 2.0,
plus up to 0.3s jitter). A `Retry-After` header from the server overrides the
computed delay.

---

## Error Classification

| Category | HTTP Codes | Retry? | User Action |
|----------|------------|--------|-------------|
| **Validation** | 400 | No | Fix input, retry |
| **Authentication** | 401 | No | Check credentials |
| **Permission** | 403 | No | Request access |
| **Not Found** | 404 | No | Verify resource exists |
| **Conflict** | 409 | No | Refresh, resolve conflict |
| **Rate Limit** | 429 | Yes | Auto-retry with backoff |
| **Server Error** | 5xx | Yes | Auto-retry with backoff |

---

## Named Error Handling Patterns

### 1. Fail Fast

**When to use**: Validation errors, missing required inputs, authentication failures.

**Behavior**: Stop immediately, report clear error message.

```python
from confluence_as import ValidationError

def get_page(page_id: str):
    if not page_id:
        raise ValidationError("Page ID is required")
    if not page_id.isdigit():
        raise ValidationError(f"Invalid page ID: {page_id} (must be numeric)")

    # Proceed with API call
```

**Example output**:
```
Error: Page ID is required
```

### 2. Fallback Strategy

**When to use**: When an alternative approach exists.

**Behavior**: Try primary method, fall back to alternative on failure.

```python
def get_page_content(page_id: str, format: str = "adf"):
    try:
        # Try v2 API first (ADF format)
        return client.get(f"/api/v2/pages/{page_id}?body-format=atlas_doc_format")
    except NotFoundError:
        raise  # Don't fallback for not found
    except ConfluenceError:
        # Fall back to v1 API (XHTML format)
        return client.get(f"/rest/api/content/{page_id}?expand=body.storage")
```

**Example output**:
```
Note: Using legacy API format (v1) as fallback
Retrieved page: My Page Title
```

### 3. Graceful Degradation

**When to use**: Bulk operations, partial success scenarios.

**Behavior**: Continue despite individual failures, report summary.

```python
def add_labels_to_pages(page_ids: list, labels: list):
    results = {"success": [], "failed": []}

    for page_id in page_ids:
        try:
            add_labels(page_id, labels)
            results["success"].append(page_id)
        except PermissionError as e:
            results["failed"].append({"page_id": page_id, "error": str(e)})
        except NotFoundError as e:
            results["failed"].append({"page_id": page_id, "error": str(e)})

    return results
```

**Example output**:
```
Labeled 8/10 pages successfully
Failed:
  - Page 12345: Permission denied
  - Page 67890: Page not found
```

---

## Exception Hierarchy

All exceptions inherit from `ConfluenceError`:

```
ConfluenceError (base)
├── ValidationError      # 400 - Bad input
├── AuthenticationError  # 401 - Invalid credentials
├── PermissionError      # 403 - Access denied
├── NotFoundError        # 404 - Resource missing
├── ConflictError        # 409 - Concurrent edit
├── RateLimitError       # 429 - Too many requests
└── ServerError          # 5xx - Server issues
```

---

## Using @handle_errors Decorator

The `@handle_errors` decorator provides consistent error handling:

```python
from confluence_as import handle_errors, get_confluence_client

@handle_errors
def main(argv=None):
    parser = argparse.ArgumentParser()
    args = parser.parse_args(argv)

    client = get_confluence_client()
    result = client.get(f"/api/v2/pages/{args.page_id}")

    print(f"Page: {result['title']}")

if __name__ == "__main__":
    main()
```

**Decorator behavior**:
- Catches `ConfluenceError` subclasses
- Prints user-friendly error message
- Exits 1 for all API errors (130 on Ctrl+C); malformed command lines exit 2 via argument parsing
- Prints a stack trace for unexpected (non-API) errors

---

## Recovery Procedures

### Authentication Errors (401)

1. Verify API token is current:
   - Go to https://id.atlassian.com/manage-profile/security/api-tokens
   - Revoke and recreate if needed

2. Check environment variables:
   ```bash
   echo $CONFLUENCE_SITE_URL
   echo $CONFLUENCE_EMAIL
   # Don't echo the token!
   ```

3. Test with a simple request:
   ```bash
   confluence-as space list --output json
   ```

### Permission Errors (403)

1. Identify required permission level
2. Check current permissions:
   ```bash
   confluence-as permission space get SPACE-KEY
   ```
3. Request access from space administrator
4. Verify group membership if using group permissions

### Rate Limit Errors (429)

1. **Wait**: Auto-retry handles most cases
2. **Reduce concurrency**: Lower parallel request count
3. **Add delays**: Space out bulk operations
4. **Check quotas**: Contact Atlassian for limits

### Server Errors (5xx)

1. **Check status**: https://status.atlassian.com
2. **Wait and retry**: Usually transient
3. **Report issue**: If persistent, contact support

---

## Best Practices

1. **Validate early**: Check inputs before API calls
2. **Log appropriately**: Debug info for troubleshooting
3. **Be specific**: Clear error messages with context
4. **Provide guidance**: Tell users how to fix issues
5. **Handle partial failure**: Report what succeeded and failed
