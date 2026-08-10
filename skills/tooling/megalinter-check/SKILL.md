---
name: megalinter-check
description: MegaLinter setup/check/fix + subagents watcher/runner/fixer, AGPL-3.0
  external pinned, L1/L2 mapping.
upstream:
  repository: oxsecurity/megalinter
  path: skills/tooling/megalinter-check
  ref: abc1234def5678abc1234def5678abc1234def56
  license: AGPL-3.0
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
- megalinter-check
---
# megalinter-check

MegaLinter setup/check/fix + subagents watcher/runner/fixer, AGPL-3.0 external pinned, L1/L2 mapping.

> Scaffold PR per #382 — validates validate-skills + validate-upstream; full implementation per issue.
