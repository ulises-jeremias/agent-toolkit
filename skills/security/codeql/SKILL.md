---
name: codeql
description: CodeQL skill setup/config/query packs/SARIF/PR feedback complementary
  to MegaLinter.
upstream:
  repository: github/awesome-copilot
  path: skills/security/codeql
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
- codeql
---
# codeql

CodeQL skill setup/config/query packs/SARIF/PR feedback complementary to MegaLinter.

> Scaffold PR per #383 — validates validate-skills + validate-upstream; full implementation per issue.
