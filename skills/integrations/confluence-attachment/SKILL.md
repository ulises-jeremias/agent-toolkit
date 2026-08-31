---
name: confluence-attachment
description: Manage file attachments - upload, download, list, and delete attachments. ALWAYS use when
  user wants to work with files on pages.
triggers:
- attach
- attachment
- upload file
- download file
- upload attachment
- download attachment
- file
- files
origin:
  type: upstream
upstream:
  repository: grandcamel/Confluence-Assistant-Skills
  path: skills/confluence-attachment
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

# Confluence Attachment Skill

Manage file attachments on Confluence pages.

---

## ⚠️ PRIMARY USE CASE

**This skill manages files attached to Confluence pages.** Use for:
- Uploading files to pages
- Downloading attachments
- Listing files on a page
- Deleting attachments

---

## When to Use / When NOT to Use

| Use This Skill | Use Instead |
|----------------|-------------|
| Upload/download files | - |
| List page attachments | - |
| Delete attachments | - |
| Create/edit pages | `confluence-page` |
| Search for content | `confluence-search` |

---

## Risk Levels

| Operation | Risk | Notes |
|-----------|------|-------|
| List/download | - | Read-only |
| Upload | - | Can be deleted |
| Update | ⚠️ | Replaces existing file |
| Delete | ⚠️ | Moves to trash (recoverable) |
| Delete `--purge` | ⚠️⚠️ | **Permanent** - only works on an already-trashed attachment |

---

## CLI Commands

### confluence-as attachment upload
Upload a file to a page.

**Usage:**
```bash
confluence-as attachment upload PAGE_ID FILE_PATH
confluence-as attachment upload 12345 report.pdf
confluence-as attachment upload 12345 image.png --comment "Screenshot"
confluence-as attachment upload 12345 data.csv --output json
```

**Options:**
- `--comment` - Comment describing the attachment
- `--output, -o` - Output format: `text` (default) or `json`

### confluence-as attachment download
Download an attachment.

**Usage:**
```bash
confluence-as attachment download ATTACHMENT_ID --output ./downloads/
confluence-as attachment download att123456 --output myfile.pdf
confluence-as attachment download 12345 --all --output ./downloads/  # Download all from page
```

**Options:**
- `--output, -o` - Output file or directory (default: current directory)
- `--all, -a` - Download all attachments from a page (the ID argument is a page ID)

### confluence-as attachment list
List attachments on a page.

**Usage:**
```bash
confluence-as attachment list 12345
confluence-as attachment list 12345 --output json
confluence-as attachment list 12345 --output table
confluence-as attachment list 12345 --media-type application/pdf
confluence-as attachment list 12345 --limit 50
```

**Options:**
- `--output, -o` - Output format: `text`, `json`, or `table`
- `--media-type, -m` - Filter by media type (e.g., `application/pdf`)
- `--limit, -l` - Maximum number of results (default 25, max 250)

### confluence-as attachment delete
Remove an attachment. By default the attachment is moved to **trash** (recoverable). `--purge` permanently deletes an attachment that is **already in trash** — it does not work as a one-step permanent delete on a live attachment.

**Usage:**
```bash
confluence-as attachment delete ATTACHMENT_ID           # move to trash (recoverable)
confluence-as attachment delete ATTACHMENT_ID --force   # skip confirmation prompt

# Permanent deletion is a two-step process:
confluence-as attachment delete ATTACHMENT_ID           # 1. move to trash
confluence-as attachment delete ATTACHMENT_ID --purge   # 2. purge the trashed attachment
```

**Options:**
- `--force`, `-f` - Skip confirmation prompt
- `--purge` - Permanently delete an attachment that is already in trash (delete first, then delete again with `--purge`)

### confluence-as attachment update
Replace an attachment file.

**Usage:**
```bash
confluence-as attachment update ATTACHMENT_ID FILE_PATH
confluence-as attachment update att123456 new_version.pdf
confluence-as attachment update att123456 updated.docx --comment "Updated content"
confluence-as attachment update att123456 report.pdf --output json
```

**Options:**
- `--comment` - Comment describing the update
- `--output, -o` - Output format: `text` (default) or `json`
