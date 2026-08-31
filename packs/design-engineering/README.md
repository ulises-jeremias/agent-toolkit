# Design-Engineering Pack — docs-only

Curated workflow for frontend/design-engineering per #390 and ADR-0003 (docs-only, not compiler-wired).

## Components
- **Skills:** frontend-design (vendored anthropics/skills f17010c), frontend-design-review (microsoft/skills e58528d), web-design-guidelines, design-assessment (delegated by project-assessment per ADR-0002), design-improvement, figma (via mcp.figma.com/mcp OAuth), figma-implement-design, chrome-devtools, playwright-cli, a11y/review, architecture/c4-model + tooling/mermaid (C4 via Mermaid per #385)
- **Agents:** architect, code-reviewer, design-assessment
- **Loops:** design-review (optional, disabled)

## Setup
```bash
cp packs/design-engineering/config.yaml ~/.ai-workspace/packs/design-engineering.yaml
```

## Workflow
project-assessment → design-assessment → figma → frontend-design → frontend-design-review + web-design-guidelines → design-improvement + a11y → chrome-devtools/playwright → mermaid/c4-model → ADR.

## Trust
Pack inherits max source risk: frontend-design (official, reviewed) + frontend-design-review (community, MIT) → trust_tier: community — do not auto-enable without review per §88.
