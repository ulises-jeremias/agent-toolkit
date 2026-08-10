---
name: cloud-design-patterns
description: 'Cloud design patterns + AWS Well-Architected 6 pillars, MCP vs prompts,
  AWS optional per #384.'
upstream:
  repository: aws/aws-well-architected
  path: skills/cloud/cloud-design-patterns
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
- cloud-design-patterns
---
# cloud-design-patterns

Cloud design patterns + AWS Well-Architected 6 pillars, MCP vs prompts, AWS optional per #384.

> Scaffold PR per #384 — validates validate-skills + validate-upstream.
