---
name: threat-modeling
description: 'Threat-modeling STRIDE + agentic threats, assets/trust boundaries/data
  flows, risk-ranked mitigations per #381.'
upstream:
  repository: github/awesome-copilot
  path: skills/agentic-security/threat-modeling
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
- threat-modeling
---
# threat-modeling

Threat-modeling STRIDE + agentic threats, assets/trust boundaries/data flows, risk-ranked mitigations per #381.

> Scaffold PR per #381 — validates validate-skills + validate-upstream.
