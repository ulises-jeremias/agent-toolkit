---
name: figma-audit-placeholder
description: "Figma audit \u2014 research figma-use/generate-design/library payload/size/license,\
  \ decision ADOPT/REJECT."
upstream:
  repository: figma/mcp
  path: skills/design/figma-audit-placeholder
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
- figma-audit-placeholder
---
# figma-audit-placeholder

Figma audit — research figma-use/generate-design/library payload/size/license, decision ADOPT/REJECT.

> Scaffold PR per #376 — validates validate-skills + validate-upstream; full implementation per issue.
