---
name: owasp-agentic-review
description: OWASP agentic review checklist + agentic-security-reviewer persona (separate
  from security-reviewer).
upstream:
  repository: github/awesome-copilot
  path: skills/agentic-security/owasp-agentic-review
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
- owasp-agentic-review
---
# owasp-agentic-review

OWASP agentic review checklist + agentic-security-reviewer persona (separate from security-reviewer).

> Scaffold PR per #380 — validates validate-skills + validate-upstream; full implementation per issue.
