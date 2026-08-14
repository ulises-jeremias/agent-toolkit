---
name: design-improvement
description: WHAT - Browser-grounded iterative design improvement. Consumes design-assessment findings, defines direction, prioritizes safe vs ambiguous changes, implements within existing design system, runs app, captures rendered evidence via browser, reviews and iterates. Reuses evidence model — no new scoring framework.
origin:
  type: first-party
---

# Design Improvement (WHAT)

Close the loop from **assessment → implementation → rendered verification**. Use this skill when the user wants to act on `design-assessment` (or `frontend-design-review`) findings, improve an existing interface, or run a browser-grounded iteration loop.

**Composition, not duplication:** Orchestrates `design-assessment`, `frontend-design`, `frontend-design-review`, `web-design-guidelines`, `playwright-cli` / `chrome-devtools`, `figma` and accessibility — delegates work, does not copy their instructions.

## Default guardrails

1. **Consume assessment findings** — start from a `design-assessment` scorecard / `frontend-design-review` output (Blocking/Major/Minor + evidence links). If no assessment exists, offer to run `design-assessment` first; do not invent findings.
2. Reuse the single evidence model: `observation / impact / severity / effort / confidence / evidence / screens / recommended fix` plus 1–5 scale, `3 = Defined`, `Not assessed`, confidence `High/Medium/Low`, and `output-handshake` before final artifacts. Do not introduce `72/100` or other synthetic scores.
3. Do not assume code is good without **rendered evidence** (screenshot/recording via browser). Implement → run → capture → inspect → compare → iterate. Where browser/vision unavailable, use text-only heuristic and mark **Low confidence — browser/vision unavailable**.
4. Do not auto-push to default branch or create tickets/docs without explicit approval. L2 controlled mutations for code changes; app runs isolated (no prod).
5. Generic-AI lens is contextual, not a checklist — a pattern is not bad merely because AI often produces it; judge appropriateness for *this* product's subject and tone.

## Safe vs ambiguous changes

Triage before implementation:

| Safe / mechanical — low judgment, implement directly with review | Ambiguous / product-defining — requires human direction, propose then confirm |
|---|---|
| Spacing/token inconsistency, broken responsive reflow, contrast violation (WCAG failure), missing focus state, overflow/clipping, misaligned design-system token, dead/incorrect ARIA, duplicate primary action | Brand direction, major visual identity, information architecture / navigation model, product-specific interaction changes, large typography or palette direction, pricing/offer hierarchy |

If a finding is ambiguous, **propose direction + rationale + rendered preview** and pause for human selection; do not blindly redesign an established product.

## Design-system preservation (existing apps)

Before inventing aesthetics, discover and respect:

- Design tokens (Figma variables, Style Dictionary, Tailwind/theme config, CSS variables)
- Component library (Storybook), existing Figma libraries, typography/spacing/color scales
- Prior decision: `greenfield` (no system, you own direction via `frontend-design`) vs `improvement within system` (default for existing apps)

Prefer **improve within system** unless explicitly commissioned to redesign. When tightening the system, author tokens/constraints rather than scattering one-off overrides.

Anti-generic-AI objective (contextual): avoid unmotivated gradients, gratuitous glow, everything-in-cards, repetitive 3-col grids, generic SaaS hero, random oversized rounded rectangles, weak hierarchy, purposeless whitespace, arbitrary decorative complexity, identical dashboard compositions, generic purple/blue palettes — unless appropriate for the product.

## Lifecycle

```
ASSESS (design-assessment) → UNDERSTAND FINDINGS → DEFINE DIRECTION → PRIORITIZE → PLAN CHANGES
  → IMPLEMENT → RUN APPLICATION → CAPTURE RENDERED EVIDENCE → REVIEW → FIX → RE-REVIEW → HANDSHAKE
```

### 1. Understand findings

- Ingest assessment scorecard: Blocking/Major/Minor, evidence links, screenshots, Figma nodes.
- Cluster findings by screen/component and by safe vs ambiguous. Surface missing-evidence items as `Not assessed` with what would enable a decision.

### 2. Define design direction (only where system gaps exist)

If greenfield or system is missing/contradictory:

- Define direction as in `frontend-design`: palette as 4–6 named hex values, typefaces for display/body/utility, layout concept with ASCII wireframe, single signature element. State subject grounding — what in the product's world motivates each choice.
- For existing branded apps, direction is *tightening* (tokens, constraints, hierarchy rules) rather than replacement.

### 3. Propose variants → select with rationale

- Propose **2–3 variants** only for ambiguous decisions (e.g., two hierarchy treatments). For safe/mechanical fixes, one implementation is enough.
- Each variant: brief rationale, trade-off, and which finding(s) it resolves.
- Pause for human selection; record decision + evidence link.

### 4. Prioritize

Rank by `severity × user impact × effort` using assessment severity plus confidence. Suggested buckets: `quick win (S, Blocking)` → `next sprint (M, Major)` → `needs design (L, ambiguous)`. Respect user-approved priority; do not re-order against approval.

### 5. Plan changes

Produce a change plan mapped to evidence:

| Finding | Decision | Change | Files / tokens | Verification (browser capture) |
|---------|----------|--------|----------------|-------------------------------|
| [link] | [safe/ambiguous + direction] | [token, component, layout fix] | [path:line] | [screenshot/viewport/theme] |

Include Figma/token references and, where relevant, WCAG SC mapping for a11y fixes.

### 6. Implement

- Implement within the discovered system (tokens/CSS variables, not hardcoded values). Reuse design-system components; document any exception with rationale.
- Keep changes small and reviewable; one concern per commit where possible.

### 7. Run application

- Run per repo docs (`npm run dev`, `docker compose up`, etc.) in an isolated, non-prod context. Record URL/port and prerequisites as evidence. Do not assume success without seeing it run.

### 8. Capture rendered evidence

- Use `playwright-cli` (primary for deterministic interaction, locators, assertions, screenshots, traces, multi-tab) and/or Chrome DevTools / `chrome-devtools` skill when runtime diagnostics needed (network, console, performance, rendering, trace). See browser provider decision below.
- Capture at breakpoints (mobile/tablet/desktop), themes (light/dark), and relevant states (empty/loading/error/dense). Record viewport, theme, date and store artifacts alongside the change plan.
- **Required:** `screenshot` (or recording) for each changed screen/state before considering the change validated. Source code alone is not validation.

### 9. Review → fix → re-review

- Review captured output vs direction and vs findings: hierarchy, spacing vs tokens, typography, color, interaction, responsive reflow, a11y (contrast, focus, keyboard), design-system compliance, distinctiveness for this product.
- For each captured finding, delegate to the appropriate reviewer:
  - Visual/hierarchy → `frontend-design-review` (three pillars + output format)
  - WIG rules (a11y, focus, forms, motion) → `web-design-guidelines`
  - A11y deeper → `accessibility` capability (when available) + browser a11y tree
  - Design-system divergence → `figma` Dev Mode compare
  - Distinctiveness → `frontend-design` creative lens
- Cite observation with screenshot anchor (`file:line` for code, region for visual). Classify `Blocking/Major/Minor` + confidence, downgraded if browser/vision was degraded.
- Fix failures and re-capture. Iterate until Blocking cleared and no new Major introduced; for greenfield, iterate until direction is satisfied. Gate on human approval for ambiguous changes.

### 10. Handshake

Apply `output-handshake` before final report: ask where the artifact lives (repo/docs/URL), who reviews/approves, and confirm human review. Do not create follow-up tickets without approval; delegate to ticket skills after approval.

## Browser provider selection (conceptual capabilities)

Request capabilities, not brand names, where practical:

| Capability | Playwright (`playwright-cli` / `e2e-runner`) | Chrome DevTools (`chrome-devtools`) |
|------------|----------------------------------------------|-------------------------------------|
| `browser.interact` (click/fill/navigate) | ✅ deterministic locators, fixtures | limited |
| `browser.capture` (screenshot, trace, pdf) | ✅ screenshots, traces, `snapshot` | ✅ screenshots, rendering diagnostics |
| `browser.dom` + `browser.accessibility` tree | `snapshot` (accessibility-aware) | ✅ DOM, accessibility tree, computed styles |
| `browser.network` / `browser.console` / `browser.performance` | limited | ✅ network, console, performance, runtime |
| `browser.trace` / `browser.visual-compare` | trace via CLI | trace + rendering inspection |
| E2E validation (`browser.assert`) | ✅ assertions, `e2e-runner` specs | — |

**Rule:** Use `playwright-cli` for deterministic interaction + E2E validation + primary capture; use `chrome-devtools` for runtime debugging, network, performance, and rendering diagnostics. Either alone suffices for degraded mode; together they cover the full `implement → render → capture → inspect → compare → iterate` loop.

If neither provider is available (no browser), fall back to text-only heuristic (code, tokens, ARIA attributes) with **Low confidence** and explicit missing-evidence register.

## Quality dimensions to consider (evidence-backed, not scored in aggregate)

Visual hierarchy, layout, spacing, typography, color, interaction, responsive behavior, accessibility, consistency, design-system compliance, product appropriateness, distinctiveness, information density, navigation clarity, feedback/states, performance where UX-relevant.

## Delegation table

| Need | Skill |
|------|-------|
| Assessment findings (input) | `design-assessment` (scorecard + prioritized findings) |
| Single-screen procedural critique | `frontend-design-review` |
| WIG rules (a11y, focus, forms, motion) | `web-design-guidelines` |
| Deterministic interaction + primary capture + E2E | `playwright-cli` (`tooling/playwright-cli`) / `e2e-runner` |
| Runtime debugging (network/console/perf/rendering) | `chrome-devtools` (`tooling/chrome-devtools`, next issue) |
| Design-system compare / tokens | `figma` / `figma-implement-design` / `figma-create-design-system-rules` |
| Distinctive direction | `frontend-design` |
| Accessibility deeper | `accessibility` (curated, WCAG 2.2 AA) when available |
| Evidence intake (single framework) | `project-assessment-evidence` |
| Multi-unit routing | `project-assessment` |
| Output gate | `output-handshake` |
| Parallel variant generation / multi-screen review | `swarm` (optional, sequential valid) |

## Security & compatibility

- No mutation without approval; no default-branch push.
- `playwright-cli` runs a real browser — treat tool arguments as executable-ish; validate URLs/inputs (no SSRF via tool injection).
- Portable orchestration; browser/vision optional with degraded confidence.

## References

- `references/improvement-plan-template.md` — change-plan + capture + review loop template
- `design-assessment` + `references/design-scorecard-template.md` — inputs (1–5, confidence, Blocking/Major/Minor, evidence links)
- `frontend-design-review` + `references/review-output-format.md` — review output format
- `web-design-guidelines` + `references/web-interface-guidelines.md` — WIG rules
- `playwright-cli` — deterministic browser automation; `chrome-devtools` — runtime diagnostics (next skill)
- `project-assessment-evidence` / `technical-unit-assessment` — evidence model and scale
- `output-handshake` — destination + review gate

