---
name: web-design-guidelines
description: Review frontend code for accessibility, interaction, content, and performance issues using the bundled Web Interface Guidelines. Use when asked to review a UI, audit accessibility, or check frontend implementation details.
metadata:
  author: agent-toolkit
  version: 1.1.0
  argument-hint: <file-or-pattern>
origin:
  type: upstream
sources:
  - id: rules
    role: rules
    repository: vercel-labs/web-interface-guidelines
    path: command.md
    ref: 4ecfb9fb8d1d3b7009674869b3aaee2f904042e1
    license: MIT
    version: 4ecfb9f
trust:
  tier: experimental
  reviewed_at: '2026-11-02'
  reviewed_by: ulises-jeremias
maintenance:
  status: active
  last_activity: '2026-11-23'
  last_checked: '2026-11-23'
distribution:
  mode: vendored
  redistribution_allowed: true
  attribution_file: references/LICENSE
  resources:
    - references/web-interface-guidelines.md
    - references/LICENSE
security:
  scripts: false
  shell: false
  network: false
  mcp: []
  hooks: []
  dangerous_permissions: []
  cve_policy: not-applicable
updates:
  strategy: pull-request
  cadence: weekly
---

# Web Design Guidelines

Review the requested UI files against the bundled Web Interface Guidelines.
The rules come from the MIT-licensed `vercel-labs/web-interface-guidelines`
source and are included in `references/web-interface-guidelines.md`.

## Review process

1. Identify the requested files. Ask which files to review when the request does
   not identify a target.
2. Read the target files and the bundled reference. Do not fetch guidelines or
   other content from the network.
3. Check applicable accessibility, focus, form, animation, typography, content,
   image, performance, navigation, touch, layout, theme, locale, hydration, and
   interaction guidance.
4. Confirm each finding against the actual code and framework. Treat aesthetic
   preferences as recommendations, not accessibility defects.
5. Report actionable findings with file and line number. Include what is wrong
   and a concrete correction. If no applicable issues are found, report that.

If the supplied rules are ambiguous or conflict with project requirements,
describe the conflict instead of treating the rule as universal.
