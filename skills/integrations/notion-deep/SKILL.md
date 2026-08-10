---
name: notion-deep
description: 'Integrations audit Jira/Confluence/Notion/Sentry/Vercel per official
  plugin>MCP>CLI hierarchy per #393.'
upstream:
  repository: atlassian/mcp
  path: skills/integrations/notion-deep
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
- notion-deep
---
# notion-deep

Integrations audit Jira/Confluence/Notion/Sentry/Vercel per official plugin>MCP>CLI hierarchy per #393.

> Scaffold PR per #393 — validates validate-skills + validate-upstream.
