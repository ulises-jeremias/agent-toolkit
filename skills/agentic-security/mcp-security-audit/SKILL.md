---
name: mcp-security-audit
description: 'MCP security audit covering config secrets/OAuth/pins and impl injection/SSRF/poisoning
  per #379. Single skill with two '
upstream:
  repository: github/awesome-copilot
  path: skills/agentic-security/mcp-security-audit
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
- mcp-security-audit
---
# mcp-security-audit

MCP security audit covering config secrets/OAuth/pins and impl injection/SSRF/poisoning per #379. Single skill with two modes.

> Scaffold PR per #379 — validates validate-skills + validate-upstream; full implementation per issue.
