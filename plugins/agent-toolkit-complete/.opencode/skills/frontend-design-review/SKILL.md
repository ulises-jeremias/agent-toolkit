---
name: frontend-design-review
description: >
  Review and create distinctive, production-grade frontend interfaces with high design
  quality and design system compliance. Evaluates using three pillars: frictionless
  insight-to-action, quality craft, and trustworthy building.
origin:
  type: upstream
upstream:
  repository: microsoft/skills
  path: .github/skills/frontend-design-review
  ref: e58528db9a006528a5fb0a2c029790fa6a9a7c0e
  license: MIT
  version: e58528d
trust:
  tier: reviewed
  reviewed_at: '2026-08-11'
  reviewed_by: ulises-jeremias
  reviewed_provenance: sha256:5394cd7cf5d9c56acd77c251da40cb603795ac5e5b4d817578991d12d57d2be7
maintenance:
  status: active
  last_activity: '2026-08-11'
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
  cve_policy: not-applicable
---

# Frontend Design Review

> **Frozen vendored snapshot** of `microsoft/skills` `.github/skills/frontend-design-review` at `e58528d` (commit `e58528db9a006528a5fb0a2c029790fa6a9a7c0e`, MIT) per ADR-0001 declaration→lock→vendored→surfaces. All references are local `references/` — no runtime network fetch. See `capabilities/upstream.lock` `design/frontend-design-review` and `docs/UPSTREAM.md`.

Review UI implementations against design quality standards and your design system **OR** create distinctive, production-grade frontend interfaces from scratch.

## Two Modes

### Mode 1: Design Review
Evaluate existing UI for design system compliance, three quality pillars (Frictionless, Quality Craft, Trustworthy), accessibility, and code quality.

### Mode 2: Creative Frontend Design
Create distinctive interfaces that avoid generic "AI slop" aesthetics, have clear conceptual direction, and execute with precision.

---

## Creative Frontend Design

Before coding, commit to an aesthetic direction:
- **Purpose**: What problem does this solve? Who uses it?
- **Tone**: minimal, maximalist, retro-futuristic, organic, luxury, playful, editorial, brutalist, art deco, soft/pastel, industrial, etc.
- **Constraints**: Framework, performance, accessibility requirements.
- **Differentiation**: What makes this distinctive and context-appropriate?

### Aesthetics Guidelines

- **Typography**: Distinctive fonts that elevate aesthetics. Pair a display font with a refined body font. Avoid Inter, Roboto, Arial, Space Grotesk.
- **Color & Theme**: Cohesive palette with CSS variables. Dominant colors + sharp accents > timid, evenly-distributed palettes.
- **Motion**: CSS-only preferred. One well-orchestrated page load with staggered reveals > scattered micro-interactions.
- **Spatial Composition**: Asymmetry, overlap, diagonal flow, grid-breaking elements, generous negative space OR controlled density.
- **Backgrounds**: Gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, grain overlays.

**AVOID**: Overused fonts, cliched color schemes, predictable layouts, cookie-cutter design without context-specific character.

Match implementation complexity to vision. Maximalist = elaborate code. Minimalist = restraint and precision.

---

## Design Review

### Design System Workflow

**Before implementing:**
1. Review component in your Storybook / component library for API and usage
2. Use Figma Dev Mode to get exact specs (spacing, tokens, properties)
3. Implement using design system components + design tokens

**During review:**
1. Compare implementation to Figma design
2. Verify design tokens are used (not hardcoded values)
3. Check all variants/states are implemented correctly
4. Flag deviations (needs design approval)

**If component doesn't exist:**
1. Check if existing component can be adapted
2. Reach out to design for new component creation
3. Document exception and rationale in code

### Review Process

1. Identify user task
2. Check design system for matching patterns
3. Evaluate aesthetic direction
4. Identify scope (component, feature, or flow)
5. Evaluate each pillar
6. Score and prioritize issues (blocking/major/minor)
7. Provide recommendations with design system examples

### Core Principles

- **Task completion**: Minimum clicks. Every screen answers "What can I do?" and "What happens next?"
- **Action hierarchy**: 1-2 primary actions per view. Progressive disclosure for secondary.
- **Onboarding**: Explain features on introduction. Smart defaults over configuration.
- **Navigation**: Clear entry/exit points. Back/cancel always available. Breadcrumbs for deep flows.

---

## Quality Pillars

### 1. Frictionless Insight to Action

**Evaluate:** Task completable in ≤3 interactions? Primary action obvious and singular?

**Red flags:** Excessive clicks, multiple competing primary buttons, buried actions, dead ends.

### 2. Quality is Craft

**Evaluate:**
- Design system compliance: matches Figma specs, uses design tokens
- Aesthetic direction: distinctive typography, cohesive colors, intentional motion
- Accessibility: Grade C minimum (WCAG 2.1 A), Grade B ideal (WCAG 2.1 AA)

**Red flags:** Generic AI aesthetics, hardcoded values, implementation doesn't match Figma, broken reflow, missing focus indicators.

### 3. Trustworthy Building

**Evaluate:**
- AI transparency: disclaimer on AI-generated content
- Error transparency: actionable error messages

**Red flags:** Missing AI disclaimers, opaque errors without guidance.

---

## Review Output Format

See [references/review-output-format.md](references/review-output-format.md) for the full review template.

## Review Type Modifiers

See [references/review-type-modifiers.md](references/review-type-modifiers.md) for context-specific review focus areas (PR, Creative, Design, Accessibility).

## Quick Checklist

See [references/quick-checklist.md](references/quick-checklist.md) for the pre-approval checklist covering design system compliance, aesthetic quality, frictionless, quality craft, and trustworthy pillars.

## Pattern Examples

See [references/pattern-examples.md](references/pattern-examples.md) for good/bad examples of creative frontend and design system review work.

---

## Acknowledgments

Creative frontend principles inspired by [Anthropic's frontend-design skill](https://github.com/anthropics/skills/tree/main/skills/frontend-design). Design review principles and quality pillar framework created by [@Quirinevwm](https://github.com/Quirinevwm) for systematic UI evaluation.


---

## Toolkit integration

### Delegation — visual critique vs project health

| Concern | Owner skill | What it does | When to use |
|---------|-------------|--------------|-------------|
| Project health (tech/mgmt) | `technical-unit-assessment` + `project-assessment-evidence` | Evidence-based 1–5 scoring of repo/platform/infra units; no visual judgment | Repo health, CI, security posture |
| Design orchestration | `design-assessment` (planned #373, per ADR-0002 Option A) | Orchestrates discovery→inspect→capture→visual/UX/a11y/responsive/DS/AI-slop/perf→findings→roadmap; reuses evidence semantics; fans out to reviewers | Full product design audit |
| Procedural visual critique | **`frontend-design-review`** (this skill) | Checklist evaluation of hierarchy, design-system compliance, three pillars (frictionless / quality craft / trustworthy), a11y, responsive, polish, AI-slop — outputs severity-ranked findings with citations | PR review, component review, creative frontend kickoff |
| Distinctive visual direction | `frontend-design` | Studio-lead aesthetic choice, palette/type/layout thesis | New UI creation with intentional style |

**This skill does not score project health.** For project health use `technical-unit-assessment`. For full design product audit, `design-assessment` will delegate to this skill for the procedural visual pass, alongside `web-design-guidelines` (Web Interface Guidelines rules) and browser/accessibility/Figma reviewers.

### Evidence-cited findings — no fake scores

- Never emit numeric scores (e.g. `72/100`) without observable evidence. Use **severity bands** `Blocking / Major / Minor` with `confidence` and `evidence` per finding, reusing `project-assessment-evidence` semantics where applicable.
- Every issue must cite: **observation** (what you saw — screenshot region, code line, token mismatch), **impact** (user/task consequence), **effort**, and **recommended fix** with design-system link or token reference.
- Mark indicators as **Not assessed** when screenshot/code unavailable rather than inventing a rating. Vision harness unavailable → text-only heuristic review with lower confidence, explicitly flagged.

### Wiring to `design-assessment` (planned)

This skill is a **delegate of `design-assessment`**. The orchestrator (see #373) will call it during the `VISUAL REVIEW` phase, passing captured screens/states (Playwright) and design-system manifest (Figma tokens / Storybook / Tailwind). It runs in parallel with `accessibility` / `web-design-guidelines` reviewers where the harness supports subagents, otherwise sequentially. Future `design-assessment` will document the full routing.

### Provenance

- Upstream: `microsoft/skills` `.github/skills/frontend-design-review` + `references/*` at `e58528db9a006528a5fb0a2c029790fa6a9a7c0e` (MIT), `LICENSE` vendored here as `LICENSE`.
- Lock: `capabilities/upstream.lock` `design/frontend-design-review` `provenance_digest` (commit + content_checksum + license), `trust.reviewed_provenance` binding.
- References vendored: `references/review-output-format.md`, `references/review-type-modifiers.md`, `references/quick-checklist.md`, `references/pattern-examples.md` — byte-identical to upstream at pinned commit.
- Update: `pull-request` per `resolved_at`; never fetch `main` at runtime.

