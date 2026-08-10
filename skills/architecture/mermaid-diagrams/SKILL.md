---
name: mermaid-diagrams
description: 'Minimal diagramming Mermaid primary + C4 optional per #385, architecture
  pack.'
upstream:
  repository: mermaid-js/mermaid
  path: skills/architecture/mermaid-diagrams
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
- mermaid-diagrams
---
# mermaid-diagrams

Minimal diagramming Mermaid primary + C4 optional per #385, architecture pack.

> Scaffold PR per #385 — validates validate-skills + validate-upstream.
