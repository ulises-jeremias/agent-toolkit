---
name: a11y-audit
description: 'Accessibility pack from mgifford + Vercel + Playwright per #377.'
upstream:
  repository: mgifford/accessibility-skills
  path: skills/accessibility/a11y-audit
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
- a11y-audit
---
# a11y-audit

Accessibility pack from mgifford + Vercel + Playwright per #377.

> Scaffold PR per #377 — validates validate-skills + validate-upstream; full implementation per issue.
