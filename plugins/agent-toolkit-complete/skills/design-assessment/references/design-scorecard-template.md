# Design Assessment Scorecard Template

**Product:** [name]  **Period:** [dates]  **Assessor:** [name]  
**Purpose:** [baseline / periodic / due-diligence]  **Audience:** [who acts]  
**Evidence map:** [link to project-assessment-evidence artifact]  **Figma:** [link]  **Storybook:** [link]

> Uses 1–5 scale from `technical-unit-assessment` `references/indicator-groups.md` (3 = defined). Confidence High/Medium/Low/Not assessed. Never score without evidence — use Not assessed. Findings use Blocking/Major/Minor.

## Evidence summary (from evidence map)

| Source | Location | Freshness | Strength (Direct/Indirect/Stale/Missing) | Confidence | Indicators |
|--------|----------|-----------|------------------------------------------|------------|------------|
| Figma  | [link]   | [date]    | Direct                                   | High       | Visual identity, Consistency |
| Screenshots (Playwright) | [path] | [date] | Direct | High | Hierarchy, A11y, Responsive |
| WCAG report | [tool] | [date] | Indirect | Medium | A11y |
| Performance trace | [path] | [date] | Indirect | Medium | Performance (UI) |

## Design-unit scorecard (1–5, Not assessed if missing evidence)

| Indicator | Score | Confidence | Evidence | Notes |
|-----------|-------|------------|----------|-------|
| Visual identity / distinctiveness | 3 / Not assessed | High / Low | [Figma node, screenshot] | [why] |
| Hierarchy & layout |  |  |  |  |
| UX friction / interaction |  |  |  |  |
| Consistency |  |  |  |  |
| A11y |  |  |  | WCAG 2.2 A = 3 (Grade C), AA = 4 (Grade B) |
| Responsiveness |  |  |  |  |
| Design-system compliance |  |  |  |  |
| Performance (UI) |  |  |  |  |

**Overall:** [narrative, not averaged — explain weighting if combining]

## Findings (severity-ranked, evidence-cited)

### Blocking (must fix before merge/release)

1. **[Pillar/Indicator] Title**
   - **Observation:** [screen/region, file:line, token mismatch, screenshot anchor]
   - **Impact:** [user/task consequence]
   - **Effort:** S/M/L  **Severity:** Blocking  **Confidence:** High/Medium/Low
   - **Affected:** [screens/components]
   - **Recommended fix:** [design-system link, token, Figma node]
   - **Evidence:** [screenshot, Figma, WCAG run]

### Major (should fix)

1. ...

### Minor (consider)

1. ...

### Not assessed (missing evidence)

| Indicator | Reason | What would enable assessment |
|-----------|--------|------------------------------|
| [e.g. A11y — screen reader] | No recording / report | Provide NVDA/JAWS run |

## Missing evidence register

| Indicator | Evidence needed | Location if exists | Owner |
|-----------|-----------------|--------------------|-------|
|  |  |  |  |

## Roadmap

| Priority | Finding | Effort | Owner | Evidence link |
|----------|---------|--------|-------|---------------|
| Quick win |  | S |  |  |
| Next sprint |  | M |  |  |
| Needs design |  | L |  |  |

## Output handshake

- **Destination:** [path/URL where artifact lives]
- **Reviewer:** [who approves]
- **Confirmed:** [date]

