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
  ref: 7c180d9044c9ae2b442b567aad4e42a28dd5ed62
  license: NOASSERTION
- id: rules
  role: rules
  repository: vercel-labs/web-interface-guidelines
  path: command.md
  ref: 4e799d45c17aec1498c269287a83b9dba22b966b
  license: MIT
trust:
  tier: reviewed
  reviewed_at: '2026-08-14'
  reviewed_by: ulises-jeremias
  reviewed_provenance: sha256:7d970b261fd8cad352748cca39be76eab44e0174c528117cc5772899a6fe08c2
maintenance:
  status: active
  last_activity: '2026-07-24'
  last_checked: '2026-08-14'
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
