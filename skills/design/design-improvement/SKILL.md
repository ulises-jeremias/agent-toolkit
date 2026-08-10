---
name: design-improvement
description: 'Design-improvement ASSESS to VARIANTS to IMPLEMENT to RUN to CAPTURE
  to REVIEW per #374.'
upstream:
  repository: ulises-jeremias/agent-toolkit
  path: skills/design/design-improvement
  ref: abc1234def5678abc1234def5678abc1234def56
  license: MIT
trust:
  tier: verified
distribution:
  mode: vendored
  redistribution_allowed: true
security:
  scripts: false
  shell: false
  network: false
  mcp: []
  hooks: []
  dangerous_permissions: []
requires: []
produces:
- report.md
tools:
- claude-code
- cursor
- opencode
- universal
triggers:
- design-improvement
---
# design-improvement

Design-improvement ASSESS to VARIANTS to IMPLEMENT to RUN to CAPTURE to REVIEW per #374.

> Scaffold PR per #374 — validates validate-skills + validate-upstream; full implementation per issue.
