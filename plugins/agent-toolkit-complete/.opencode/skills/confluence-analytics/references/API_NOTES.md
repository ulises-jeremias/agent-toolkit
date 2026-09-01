# Confluence Analytics API Notes

## Overview

Confluence Cloud has significantly more limited analytics capabilities compared to Server/Data Center editions. There is no dedicated analytics API endpoint that provides view counts, visitor statistics, or detailed engagement metrics.

## Available Analytics Data

### 1. Page History (v1 API)

**Endpoint:** `GET /rest/api/content/{id}`

**Expand parameters:**
- `version` - Current version number and modification date
- `history` - Creation date, creator
- `history.contributors.publishers` - List of users who have edited the page

**Example:**
```bash
GET /rest/api/content/12345?expand=version,history,history.contributors.publishers
```

**Response includes:**
- Version number (edit count)
- Last modified date/time
- Last modified by user
- Created date/time
- Created by user
- List of all contributors (editors)

**Note:** This gives us:
- Number of edits (version number)
- Who has contributed
- When it was last touched

But NOT:
- View count
- Unique visitors
- Page engagement metrics

### 2. CQL Search (v1 API)

**Endpoint:** `GET /rest/api/search`

**CQL Ordering Options:**
- `ORDER BY created DESC` - Recently created (new content)
- `ORDER BY lastModified DESC` - Recently updated (active content)
- `ORDER BY title` - Alphabetical

**Example queries:**
```cql
# Recent activity in space
space=DOCS AND type=page ORDER BY lastModified DESC

# New content this month
space=DOCS AND created >= "2024-01-01" ORDER BY created DESC

# Featured content
label=featured ORDER BY lastModified DESC
```

**Use for:**
- Finding recently active content (proxy for "popular")
- Identifying content with specific labels
- Date-based filtering

### 3. Watchers API (v1 API)

**Endpoint:** `GET /rest/api/content/{id}/notification/child-created`

**Purpose:** Get users who are watching a page (will be notified of child page creation)

**Alternative endpoints:**
- `/rest/api/content/{id}/notification/created` - (may not work in Cloud)
- `/rest/api/user/watch/content/{id}` - (deprecated)

**Limitations:**
- May be disabled on some Confluence Cloud instances
- Only shows watchers, not viewers
- API availability varies by instance configuration

### 4. Space Statistics

**No direct endpoint** - must aggregate via search:

```
1. Search all content in space: space=DOCS
2. Iterate through results
3. Aggregate:
   - Total count
   - Count by type (page/blogpost)
   - Count by creator
   - Date ranges
```

## What We Can't Get

### View Counts
Confluence Cloud does not expose:
- Number of views/visits
- Unique visitor count
- Page popularity scores
- Time spent on page

### Engagement Metrics
Not available:
- Likes/reactions count (Cloud removed likes)
- Comments count (must fetch separately)
- Shares (no sharing in Cloud)
- Exports/prints

### Time-Based Analytics
Not available:
- Views over time graphs
- Traffic trends
- Peak usage times
- User session data

## Workarounds

### Proxy Metrics for "Popularity"

1. **Recent Modification**
   - Assumption: Frequently updated = actively used
   - CQL: `ORDER BY lastModified DESC`

2. **Contributor Count**
   - Assumption: Many contributors = important page
   - Expand: `history.contributors.publishers`

3. **Labels**
   - Manual curation: Tag important pages with "featured" or "popular"
   - CQL: `label=featured`

4. **Version Number**
   - Higher version = more edits = more activity
   - Field: `version.number`

5. **Watchers**
   - More watchers = more interested users
   - API: `/notification/child-created`

### Alternative Solutions

1. **Atlassian Analytics (Separate Product)**
   - Premium add-on
   - Provides real analytics
   - Not accessible via REST API

2. **Third-Party Apps**
   - Marketplace apps may provide analytics
   - Often have their own APIs
   - Not covered in this implementation

3. **Export and Analyze**
   - Export content metadata
   - Analyze patterns externally
   - Track changes over time

## Best Practices

### For Page Analytics
- Use version history to show activity
- Display contributors to show collaboration
- Show creation/modification dates for recency

### For Space Analytics
- Aggregate content counts
- Show top contributors
- Display recent activity
- Filter by date ranges for trends

### For Popular Content
- Sort by modification date (recent = active)
- Sort by creation date (new content)
- Use labels for manual curation
- Combine multiple signals

## API Rate Limits

Confluence Cloud rate limits:
- Typically: 5 requests/second per user
- Burst: Higher for short periods
- Large spaces: May need pagination and throttling

**Recommendations:**
- Use pagination (limit=25 or 50)
- Add delays for large operations
- Cache results when possible
- Use CQL to pre-filter

## References

- [Confluence Cloud REST API v1](https://developer.atlassian.com/cloud/confluence/rest/v1/intro/)
- [CQL Syntax](https://developer.atlassian.com/cloud/confluence/advanced-searching-using-cql/)
- [Content Properties](https://developer.atlassian.com/cloud/confluence/content-properties/)
- [Rate Limiting](https://developer.atlassian.com/cloud/confluence/rate-limiting/)

## Version History

This document reflects the Confluence Cloud REST API as of January 2025. Analytics capabilities may change with future updates.
