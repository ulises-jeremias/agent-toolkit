---
name: doctor-extended
description: 'Doctor/inventory provenance/pack/MCP/CLI/env checks per #387 (isolated
  HOME).'
upstream:
  repository: ulises-jeremias/agent-toolkit
  path: skills/tooling/doctor-extended
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
- doctor-extended
---
# doctor-extended

Doctor/inventory provenance/pack/MCP/CLI/env checks per #387 (isolated HOME).

> Scaffold PR per #387 — validates validate-skills + validate-upstream.
