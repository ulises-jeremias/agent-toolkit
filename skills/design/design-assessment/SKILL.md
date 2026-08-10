---
name: design-assessment
description: Design-assessment orchestrator evidence-based scorecard Visual/Hierarchy/UX/A11y/Responsive/Design-system/AI-slop/Perf.
upstream:
  repository: ulises-jeremias/agent-toolkit
  path: skills/design/design-assessment
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
- design-assessment
---
# design-assessment

Design-assessment orchestrator evidence-based scorecard Visual/Hierarchy/UX/A11y/Responsive/Design-system/AI-slop/Perf.

> Scaffold PR per #373 — validates validate-skills + validate-upstream; full implementation per issue.
