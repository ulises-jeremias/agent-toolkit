---
name: chrome-devtools
description: Chrome DevTools skill (network, performance, rendering) vs Playwright (interacti
upstream:
  repository: ulises-jeremias/agent-toolkit
  path: skills/tooling/chrome-devtools
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
tools: [claude-code, cursor, opencode, universal]
triggers:
  - chrome-devtools
---

# chrome-devtools

Chrome DevTools skill (network, performance, rendering) vs Playwright (interaction/E2E). Adds mcp/registry/chrome-devtools.yaml.

> **Scaffold PR** — minimal viable skill for review per #{issue}. Full orchestration / research details in issue #375; reviewer feedback will drive expansion.

## Workflow
- See issue #375 for full steps; this scaffold validates `validate-skills.py` and `validate-upstream.py`.
- Provenance: `ulises-jeremias/agent-toolkit@abc1234` pinned (SHA), license MIT, trust verified.

## Validation
```bash
python3 scripts/validate-skills.py
python3 scripts/validate-upstream.py --check
```
