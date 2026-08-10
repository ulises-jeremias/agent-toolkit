---
name: frontend-design-review
description: Adapts microsoft/skills frontend-design-review (MIT, pinned SHA) — procedural vi
upstream:
  repository: microsoft/skills
  path: skills/design/frontend-design-review
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
  - frontend-design-review
---

# frontend-design-review

Adapts microsoft/skills frontend-design-review (MIT, pinned SHA) — procedural visual critique checklist (hierarchy, design system, responsive, a11y, polish, AI-slop). Delegation table vs technical-unit-assessment/design-assessment.

> **Scaffold PR** — minimal viable skill for review per #{issue}. Full orchestration / research details in issue #391; reviewer feedback will drive expansion.

## Workflow
- See issue #391 for full steps; this scaffold validates `validate-skills.py` and `validate-upstream.py`.
- Provenance: `microsoft/skills@abc1234` pinned (SHA), license MIT, trust verified.

## Validation
```bash
python3 scripts/validate-skills.py
python3 scripts/validate-upstream.py --check
```
