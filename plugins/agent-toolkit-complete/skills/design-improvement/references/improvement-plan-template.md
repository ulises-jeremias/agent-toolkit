# Design Improvement Plan Template

**Product:** [name]  **Source assessment:** [link to design-assessment scorecard]  **Period:** [dates]
**Branch:** [feature branch]  **Running app:** [URL/port + command]  **Assessor:** [name]

> Reuses evidence model from `project-assessment-evidence` (observation/impact/severity/effort/confidence/evidence/screens/fix, 1–5 scale 3=Defined, Not assessed, output-handshake). Do not score without evidence.

## Findings intake (from assessment)

| # | Finding | Severity | Confidence | Evidence | Screen/Component | Recommended fix |
|---|---------|----------|------------|----------|------------------|-----------------|
| 1 | [title] | Blocking/Major/Minor | High/Med/Low | [scorecard link, screenshot] | [screen] | [Figma/token/WIG rule] |

### Triage: safe vs ambiguous

| Finding | Safe (mechanical) | Ambiguous (needs direction) | Decision |
|---------|-------------------|-----------------------------|----------|
| 1 | [e.g. contrast violation] |  | Implement directly → review |
| 2 |  | [e.g. hero hierarchy] | Propose variants → human select |

## Design direction (only where system gaps exist)

**Subject grounding:** [what in product's world motivates choices]
**Palette:** 4–6 named hex values
**Typography:** display / body / utility faces
**Layout concept + ASCII wireframe:**
```
[wireframe]
```
**Signature element:** [single memorable element]
**For existing apps:** tightening tokens/constraints vs replacement: [decision]

## Variants (only for ambiguous)

| Variant | Rationale | Resolves findings | Trade-off |
|---------|-----------|-------------------|-----------|
| A |  |  |  |
| B |  |  |  |

**Selection:** [A/B] — [why] — approved by [who] on [date] — evidence [link]

## Prioritization

Ranked by `severity × impact × effort` + confidence. Buckets:

| Priority | Finding | Effort | Confidence | Verification capture |
|----------|---------|--------|------------|----------------------|
| Quick win |  | S | High | screenshot viewport/theme |
| Next sprint |  | M |  |  |
| Needs design |  | L |  |  |

## Change plan

| Finding | Decision | Change (token/component/layout) | Files / tokens | Expected rendering |
|---------|----------|----------------------------------|----------------|--------------------|
| 1 | safe/ambiguous + direction | [e.g. spacing token s-400] | path:line | [what screenshot should show] |

## Implementation log

| Commit | Change | Finding | Evidence before | Evidence after |
|--------|--------|---------|-----------------|----------------|
| [sha] | [desc] | #1 | [screenshot before] | [screenshot after] |

## Rendered verification (required — code alone is not validation)

Record per captured state:

| Screen | Viewport | Theme | State | Screenshot | Review vs direction | Result |
|--------|----------|-------|-------|------------|---------------------|--------|
| home | desktop 1440 | light | default | [link] | [pass/fix] | Blocking cleared / Major remains |
| home | mobile 390 | light | default | [link] |  |  |

**Browser provider used:** `playwright-cli` (deterministic interaction + capture) / `chrome-devtools` (network/console/perf) / both. If degraded (no browser), mark `Low confidence — browser/vision unavailable` and list missing evidence.

### Review delegation

- Visual/hierarchy → `frontend-design-review` (three pillars)
- WIG rules → `web-design-guidelines`
- A11y deeper → `accessibility` + browser a11y tree + WCAG SC mapping
- Design-system divergence → `figma` Dev Mode compare
- Distinctiveness → `frontend-design` creative lens

## Re-review loop

Iterate `review → fix → re-capture` until Blocking cleared and no new Major introduced. For greenfield, until direction satisfied. Record:

| Iteration | Reviewer | Finding | Action | Re-capture link | Status |
|-----------|----------|---------|--------|-----------------|--------|
| 1 | frontend-design-review | #1 contrast | fix token | [link] | ✅ Blocking cleared |

## Missing evidence register

| Need | What would enable |
|------|-------------------|
| [e.g. mobile 390 screenshot] | `playwright-cli screenshot` at viewport |

## Output handshake

- **Destination:** [repo/docs/URL]
- **Reviewer:** [who approves]
- **Confirmed:** [date]
- **Follow-ups:** [tickets only after approval]

## Design-system evidence

Discovered tokens / Figma / Storybook:

| System | Location | Freshness | Strength | Notes |
|--------|----------|-----------|----------|-------|
| Tokens | [path/URL] | [date] | Direct |  |
| Figma | [file] | [date] | Direct |  |
| Storybook | [URL] | [date] | Indirect |  |

