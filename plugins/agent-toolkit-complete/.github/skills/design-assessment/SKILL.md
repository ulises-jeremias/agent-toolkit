---
name: design-assessment
description: WHAT - Evidence-based design-unit assessment orchestrated by project-assessment. Evaluates visual hierarchy, UX friction, interaction, a11y, responsiveness, design-system compliance, and distinctiveness with severity/confidence evidence citations. Reuses project-assessment-evidence semantics — no second framework.
origin:
  type: first-party
---

# Design Assessment (WHAT)

Assess a product's interface as a **design unit** delegated by `project-assessment`. Use this skill when the user asks for a design audit, visual review, UX assessment, accessibility evaluation, design-system compliance check, or distinctive-identity review.

**Router contract (ADR-0002 Option A):** `project-assessment` collects evidence via `project-assessment-evidence`, then delegates to this skill alongside `technical-unit-assessment` / `management-unit-assessment` when UI/design is in scope. This skill is also directly invokable for single-page or multi-screen UI audits. It **reuses** the single evidence framework — do not re-ask evidence already in the map.

## Default guardrails

1. Apply **`project-assessment-evidence`** before scoring. If calling via `project-assessment`, reuse its evidence map — do not duplicate intake questions.
2. Apply **`output-handshake`** before producing any final design assessment report, scorecard, or roadmap.
3. **Never assign a maturity score without evidence.** If evidence is missing, mark the indicator as **Not assessed** or score with **Low confidence** and state the assumption. Never emit fake precision like `72/100` — use rating bands + severity/confidence.
4. **Screenshots must not capture secrets.** Observe-only, L1. Redact private data. Keep sensitive details out of reusable artifacts.
5. **Generic-template risk (distinctiveness)** must be context-aware — `rounded cards = bad` is not a rule. Evaluate whether the aesthetic is distinctive for *this* product's subject and tone, not via a checklist.
6. **Vision fallback:** This skill is `vision-required` for full visual critique. If the harness cannot render screenshots/recordings, perform a text-only heuristic review (code, tokens, a11y attributes) and flag each finding with **Low confidence — vision unavailable**.

## Design-unit intake

Ask before scoring (or reuse from router evidence map):

- **Product & purpose:** product name, audience, single job the page/ flow does
- **Scope:** screens/flows/components in scope, Figma files / variables, Storybook, Tailwind/config, design-system entry points
- **Repositories & assets:** app repo(s), component library, token files, asset locations
- **Systems of record for design evidence:** Figma, Storybook, WCAG reports, performance reports, screenshots, recordings, product analytics, UX research
- **Assessment period & audience:** who will act on findings
- **Decision ownership:** who validates subjective visual judgments

Evidence sources already covered by `project-assessment-evidence` include: `design files, UX research, accessibility reports, performance reports, screenshots, recordings, product analytics` — ask where each lives instead of assuming.

## Orchestration workflow

```
UNDERSTAND PRODUCT → DISCOVER DESIGN SYSTEM → INSPECT APP → CAPTURE SCREENS/STATES
  → VISUAL REVIEW → UX REVIEW → A11Y → RESPONSIVE → DESIGN-SYSTEM CONSISTENCY
  → DISTINCTIVENESS → PERF → FIGMA COMPARE → PRIORITIZED FINDINGS → ROADMAP
```

### Phase 1 — Understand & Discover

1. **Understand product:** audience, job-to-be-done, tone, constraints (framework, performance, a11y target WCAG 2.2 AA). Ask the user if not in evidence map.
2. **Discover design system:** locate tokens (Figma variables, Style Dictionary, Tailwind config, CSS variables), component library (Storybook), Figma Dev Mode specs. Record freshness and owner per `project-assessment-evidence` quality rules (Direct/Indirect/Stale/Missing).

### Phase 2 — Inspect & Capture

3. **Inspect app:** verify app builds and routes enumerated in scope; enumerate states (empty, loading, error, dense, mobile).
4. **Capture screens/states:** use `playwright-cli` (or Chrome DevTools) to screenshot each screen/state at breakpoints (mobile, tablet, desktop). If capturing elsewhere, delegate to `browser` reviewer. Record capture metadata (viewport, theme, date) as evidence.

### Phase 3 — Parallel review (vision where possible)

Fan out where the harness supports subagents — shared evidence map is authority; sequential fallback is always valid:

| Reviewer | Delegates to | Focus |
|----------|--------------|-------|
| Visual / hierarchy | `frontend-design-review` | Layout, typography, color, motion, three pillars (Frictionless / Quality Craft / Trustworthy), design-system compliance vs Figma tokens |
| UX friction | `web-design-guidelines` + heuristic | Interaction path ≤3 steps, single primary action, progressive disclosure, onboarding |
| A11y | `accessibility` / `frontend-design-review` (a11y modifier) | Keyboard, screen reader, contrast (WCAG 2.2 A = Grade C, AA = Grade B), 200% zoom, light/dark/high-contrast |
| Responsive | `playwright-cli` + `frontend-design-review` | Reflow, token usage not hardcoded values, variants/states |
| Design-system consistency | `figma` / `figma-implement-design` + tokens | Token usage, spacing vs Figma Dev Mode, deviations with rationale |
| Distinctiveness | `frontend-design` + `frontend-design-review` (creative mode) | Aesthetic direction distinctive for this subject, avoids generic AI template |
| Performance (UI) | `playwright-cli` / Chrome DevTools | Load, reflow, motion cost (CSS-only preferred) — citation not synthetic score |

**Swarm mapping (advisory):** `design-assessment: a11y-reviewer || visual-reviewer || browser-perf-reviewer || design-system-reviewer` (shared evidence map). Sequential execution produces identical findings — only slower.

For each finding see **Scorecard & findings** below.

### Phase 4 — Figma compare

5. Compare implementation side-by-side with Figma using Dev Mode specs: spacing, typography, color, variants. Document deviations with link and whether design approval exists.

### Phase 5 — Findings & Roadmap

6. **Prioritize findings** by `severity × user impact × effort` with confidence. Separate confirmed vs assumed vs missing-evidence.
7. **Roadmap:** group by `quick win / next sprint / needs design`. Do not create tickets or update docs without explicit user approval — delegate ticket creation to the relevant ticket skill after approval.
8. **Output handshake** before final artifact.

## Scorecard & findings (no fake precision)

Use the 1–5 scale from `technical-unit-assessment` `references/indicator-groups.md` **only where an indicator has evidence**. Score 3 = defined/partially mature. Record confidence per score (High/Medium/Low/Not assessed) and evidence link. Do not average unrelated indicators without explaining weighting.

Prefer **severity bands** for actionable review output (from `frontend-design-review`):

- **Blocking** — must fix before merge/release (user task broken, WCAG failure, design-system violation)
- **Major** — should fix (measurable UX friction, generic aesthetic without direction)
- **Minor** — consider for refinement

### Design indicators (1–5, Not assessed if missing evidence)

| Indicator | What to observe (evidence) |
|-----------|----------------------------|
| Visual identity / distinctiveness | Typography pair, palette with CSS variables, spatial composition, motion; distinctive for *this* subject, not a template |
| Hierarchy & layout | Information structure, primary action per view, progressive disclosure, spacing vs tokens |
| UX friction / interaction | Task completion steps, navigation entry/exit, onboarding, error messages actionable |
| Consistency | Component reuse, token usage, variants/states match Figma |
| A11y | Contrast, keyboard, screen reader, ARIA, 200% zoom, theme testing |
| Responsiveness | Breakpoints, reflow, no hardcoded values |
| Design-system compliance | Matches Figma specs, no deviation without rationale |
| Performance (UI) | Motion orchestrated, not scattered; CSS-only preferred where possible |

### Per-finding record

Every finding must cite:

- **Observation** — what you saw (screen/region, code line `file:line`, token mismatch, screenshot anchor)
- **Impact** — user/task consequence
- **Effort** — S/M/L
- **Confidence** — High/Medium/Low (downgrade to Low if vision unavailable)
- **Affected screens / components**
- **Recommended fix** — design-system link or token reference or Figma link
- **Evidence** — link to screenshot, Figma node, WCAG run, Storybook entry
- **Severity** — Blocking / Major / Minor

See `references/design-scorecard-template.md` for the full template. Mark **Not assessed** when screenshot/code unavailable rather than inventing a rating.

## Delegation table

| Need | Skill |
|------|-------|
| Evidence intake (single framework) | `project-assessment-evidence` |
| Multi-unit routing (technical/mgmt/design) | `project-assessment` |
| Procedural visual critique (three pillars, checklist) | `frontend-design-review` (delegate of this skill — Visual Review phase) |
| Web Interface Guidelines rules (a11y, focus, forms, animation) | `web-design-guidelines` (frozen `references/web-interface-guidelines.md`) |
| Screenshot & browser states | `playwright-cli` / Chrome DevTools |
| Figma variables / Dev Mode compare | `figma` / `figma-implement-design` / `figma-create-design-system-rules` |
| Distinctive visual direction | `frontend-design` |
| Repository discovery | `assistant` |
| Final output gate | `output-handshake` |
| Parallel large-product review | `swarm` (optional; sequential fallback valid) |

## Security & compatibility

- No mutation; observe-only. Screenshots must not capture secrets — coordinate capture scope.
- Portable: no tool-specific paths (uses local `references/` and evidence map).
- Swarm optional; vision gracefully degrades to text-only heuristic with lower confidence.

## References

- `references/design-scorecard-template.md` — design-unit scorecard + findings template (this skill)
- `project-assessment` — router and scope (delegates to this skill)
- `project-assessment-evidence` — evidence map and source-by-source intake (single framework)
- `technical-unit-assessment` + `references/indicator-groups.md` — 1–5 scale, confidence, Not assessed, output-handshake contract
- `frontend-design-review` — pillar assessment and review-output format (delegate)
- `web-design-guidelines` — Web Interface Guidelines frozen reference
- `playwright-cli` / `figma` — capture and compare

