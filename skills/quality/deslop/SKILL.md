---
name: deslop
description: Remove AI-generated code slop and clean up code style
origin:
  type: upstream
upstream:
  repository: cursor/plugins
  path: cursor-team-kit/skills/deslop
  ref: b21ab167c8d6aad6e4d91bc0de429eedd49665ed
  license: MIT
  version: b21ab16
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
  network: false
  mcp: []
  hooks: []
  dangerous_permissions: []
  cve_policy: not-applicable
updates:
  strategy: pull-request
  cadence: weekly
---

# Remove AI code slop

Check the diff against main and remove AI-generated slop introduced in the branch.

## Focus Areas

- Extra comments that are unnecessary or inconsistent with local style
- Defensive checks or try/catch blocks that are abnormal for trusted code paths
- Casts to `any` used only to bypass type issues
- Deeply nested code that should be simplified with early returns
- Other patterns inconsistent with the file and surrounding codebase

## Guardrails

- Keep behavior unchanged unless fixing a clear bug.
- Prefer minimal, focused edits over broad rewrites.
- Keep the final summary concise (1-3 sentences).
