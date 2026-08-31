---
name: confluence-ops
description: Cache management, API diagnostics, and operational utilities. Use when optimizing performance,
  managing cache, diagnosing API issues, or troubleshooting Confluence connectivity.
triggers:
- cache
- cache status
- cache clear
- cache warm
- api diagnostics
- performance
- rate limit
- troubleshoot
- connectivity
- health check
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-ops
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

# Confluence Operations Skill

Cache management, API diagnostics, and operational utilities for Confluence Assistant.

---

## ⚠️ PRIMARY USE CASE

**This skill manages operational aspects of Confluence integration.** Use for:
- Inspecting and clearing the cache directory
- Diagnosing API connectivity issues
- Troubleshooting rate limits

> **Cache reality check:** current `confluence-as` releases never **write** response data to the cache directory (`~/.confluence-skills/cache`). The `cache-*` commands manage/inspect that directory, but it stays empty unless something else populates it: `cache-warm` issues API requests and discards the responses (`cache-status` still shows 0 entries afterwards), and each CLI invocation builds a fresh HTTP session, so warming does not speed anything up. `CONFLUENCE_CACHE_ENABLED` only changes the Enabled/Disabled label in `cache-status` output.

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| Check cache status | - |
| Clear/warm cache | - |
| Diagnose API issues | - |
| Check rate limits | - |
| Manage pages | `confluence-page` |
| Search content | `confluence-search` |
| Manage spaces | `confluence-space` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| Cache status | - | Read-only |
| API diagnostics | - | Read-only |
| Cache warm | - | Issues read-only API requests; does not add cache entries |
| Cache clear | ⚠️ | Deletes files from the cache directory |

---

## When to Use This Skill

Use this skill when you need to:

- **Inspect the cache directory**: Check its size and entry counts by category
- **Clear cache data**: Remove stale or sensitive files from the cache directory
- **Exercise read endpoints**: `cache-warm` fetches space metadata (useful as a connectivity smoke test; responses are not stored)
- **Diagnose API issues**: Test connectivity and identify problems
- **Check rate limits**: Monitor API quota usage

**Trigger conditions:**
- Setting up new Confluence instance
- Troubleshooting 429 rate limit errors
- Cleaning up the cache directory (e.g. removing sensitive data left by older releases or other tools)

---

## Quick Start

```bash
# Inspect the cache directory
confluence-as ops cache-status

# Delete all files in the cache directory
confluence-as ops cache-clear --force

# Fetch space metadata (responses are not stored - see cache reality check)
confluence-as ops cache-warm --spaces

# Test API connectivity
confluence-as ops health-check

# Full API diagnostics
confluence-as ops api-diagnostics
```

---

## CLI Commands

| Command | Purpose | Risk |
|---------|---------|------|
| `confluence-as ops cache-status` | Display cache directory statistics | - |
| `confluence-as ops cache-clear` | Delete files from the cache directory | ⚠️ |
| `confluence-as ops cache-warm` | Fetch metadata (responses are not stored) | - |
| `confluence-as ops health-check` | Test API connectivity | - |
| `confluence-as ops rate-limit-status` | Check rate limit usage | - |
| `confluence-as ops api-diagnostics` | Diagnose API issues | - |

The global `-o/--output` flag placed before the subcommand (e.g. `confluence-as -o json ops cache-status`) sets the default output format for all subcommands; an explicit subcommand-level `--output` wins.

---

## Common Tasks

### Check Cache Status

```bash
# Basic status
confluence-as ops cache-status

# Output as JSON
confluence-as ops cache-status --output json

# Verbose output with entry details
confluence-as ops cache-status --verbose
```

**Output example** (current releases never write to the cache directory, so entry counts are normally 0):
```
Cache Status
============================================================

Status:         Enabled
Cache Dir:      /Users/you/.confluence-skills/cache
Dir Exists:     Yes
Total Entries:  0
Total Size:     0.0 B
✓ Cache status retrieved
```

The `Status` line reflects only the `CONFLUENCE_CACHE_ENABLED` environment variable; it is a display label, not a functional toggle. If the directory contains files (placed there by older releases or other tools), a `By Category` breakdown and oldest/newest entry timestamps are also shown.

### Warm the Cache

`cache-warm` issues read-only API requests for the selected metadata and reports what it fetched. The responses are **discarded, not cached** - `cache-status` shows 0 entries afterwards, and because each CLI invocation builds a fresh HTTP session, warming does not speed up later commands. Treat it as a connectivity/permissions smoke test for the spaces endpoints.

```bash
# Fetch space list
confluence-as ops cache-warm --spaces

# Fetch specific space metadata
confluence-as ops cache-warm --space DOCS

# Fetch all available metadata
confluence-as ops cache-warm --all --verbose

# JSON output for scripting
confluence-as ops cache-warm --spaces --output json
```

### Clear Cache

```bash
# Clear all cache (with confirmation)
confluence-as ops cache-clear

# Clear all cache (skip confirmation)
confluence-as ops cache-clear --force

# Clear only page cache
confluence-as ops cache-clear --category pages --force

# Preview what would be cleared
confluence-as ops cache-clear --dry-run

# Clear keys whose filename contains a substring (NOT a glob - "DOCS-*" would match nothing)
confluence-as ops cache-clear --pattern "DOCS" --category pages --force

# Clear entries older than N days
confluence-as ops cache-clear --older-than 7 --force

# JSON output for scripting
confluence-as ops cache-clear --force --output json
```

### API Diagnostics

```bash
# Full health check
confluence-as ops health-check

# Test specific endpoint
confluence-as ops health-check --endpoint "/api/v2/spaces"

# Verbose output with timing
confluence-as ops health-check --verbose

# JSON output for scripting
confluence-as ops health-check --output json
```

**Output example:**
```
Confluence Health Check
============================================================

Site URL:       https://your-site.atlassian.net
Status:         + Connected
API Version:    v2
Response Time:  234ms

Endpoint Tests:
  [+] /api/v2/spaces            156ms
  [+] /api/v2/pages             189ms
  [+] /rest/api/search          312ms

Authentication: + Valid
User:           your-email@example.com
✓ Health check complete
```

### Rate Limit Status

```bash
# Check current rate limit status
confluence-as ops rate-limit-status

# JSON output
confluence-as ops rate-limit-status --output json
```

**Output example:**
```
Rate Limit Status
============================================================

Status:         + OK

→ Rate limit information:
  - Confluence Cloud has rate limits of ~100-500 requests/minute
  - Use --batch-size option in bulk operations to stay within limits
  - 429 errors indicate rate limit exceeded - wait and retry
✓ Rate limit status retrieved
```

Note: rate limit headers may not be exposed in all Atlassian tiers; if a request hits a 429, the status is reported as `Rate Limited`.

---

## Cache Categories

When the cache directory contains files, they are organized into category subdirectories (e.g. `spaces`, `pages`, `users`). Use `cache-status` to see which categories exist and `cache-clear --category NAME` to clear a single category. Since current releases never populate the directory, expect no categories on a fresh install.

---

## Configuration

The cache directory managed by these commands is `~/.confluence-skills/cache/`. Current releases never write response data to it (see the cache reality check above).

Environment variables:
- `CONFLUENCE_CACHE_DIR` - Custom cache directory
- `CONFLUENCE_CACHE_ENABLED` - Only changes the Enabled/Disabled label shown by `cache-status` (default: true); it does not enable or disable any caching behavior

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error (validation, API, cache, or connectivity failure) |
| 2 | Malformed command line (unknown flag, missing argument) |
| 130 | Cancelled by user (Ctrl+C) |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Slow API responses | Check `health-check --verbose` timings; response caching is not available in current releases |
| 429 Rate limit | Wait for reset, reduce request frequency |
| Connection timeout | Check `health-check`, verify credentials |
| Stale or unwanted files in cache directory | Run `cache-clear --force` |

---

## Related Skills

- **confluence-bulk**: Bulk operations
- **confluence-search**: Search queries
- **confluence-admin**: Administrative operations
