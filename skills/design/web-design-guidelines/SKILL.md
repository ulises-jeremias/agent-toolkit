---
name: web-design-guidelines
description: Review UI code for Web Interface Guidelines compliance. Use when asked to "review my UI",
  "check accessibility", "audit design", "review UX", or "check my site against best practices".
metadata:
  author: vercel
  version: 1.0.0
  argument-hint: <file-or-pattern>
origin:
  type: upstream
sources:
- id: wrapper
  role: wrapper
  repository: vercel-labs/agent-skills
  path: skills/web-design-guidelines
  ref: ba46938889d4e58635362fb8f618e1178ac3ec46
  license: NOASSERTION
  version: ba46938
- id: rules
  role: rules
  repository: vercel-labs/web-interface-guidelines
  path: command.md
  ref: e3d624baaf29dc1fc645aff3e38f03e564d2d6b1
  license: MIT
  version: e3d624b
trust:
  tier: experimental
  reviewed_at: '2026-08-24'
  reviewed_by: ulises-jeremias
maintenance:
  status: active
  last_activity: '2026-07-24'
  last_checked: '2026-08-24'
distribution:
  mode: vendored
  redistribution_allowed: false
security:
  scripts: false
  shell: false
  network: true
  mcp: []
  hooks: []
  dangerous_permissions: []
  cve_policy: not-applicable
updates:
  strategy: pull-request
  cadence: weekly
---

# Web Interface Guidelines

Review files for compliance with Web Interface Guidelines.

## How It Works

1. Fetch the latest guidelines from the source URL below
2. Read the specified files (or prompt user for files/pattern)
3. Check against all rules in the fetched guidelines
4. Output findings in the terse `file:line` format

## Guidelines Source

Fetch fresh guidelines before each review:

```
https://raw.githubusercontent.com/vercel-labs/web-interface-guidelines/main/command.md
```

Use WebFetch to retrieve the latest rules. The fetched content contains all the rules and output format instructions.

## Usage

When a user provides a file or pattern argument:
1. Fetch guidelines from the source URL above
2. Read the specified files
3. Apply all rules from the fetched guidelines
4. Output findings using the format specified in the guidelines

If no files specified, ask the user which files to review.
