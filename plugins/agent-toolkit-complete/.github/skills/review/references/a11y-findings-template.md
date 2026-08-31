# Accessibility Findings Template (WCAG 2.2 AA)

**Product:** [name]  **Screen:** [url/route]  **Period:** [dates]  **Tool versions:** axe [x], lighthouse [y], playwright-cli [z]

## Evidence captured (rendered, required)

| Artifact | Viewport | Theme | Zoom | Link |
|----------|----------|-------|------|------|
| a11y tree (snapshot) | desktop 1440 | light | 100% | [link] |
| screenshot | mobile 390 | light | 200% | [link] |
| screenshot | desktop 1440 | dark | 100% | [link] |
| computed styles (contrast) | — | — | — | [link] |

## Findings

### Blocking (AA failure, task blocked)

1. **[Area] Title**
   - **Mode:** Automatically detectable / Browser-assisted / Manual
   - **SC:** 1.4.3 Contrast (Minimum) — or blank if judgment required
   - **Observation:** [element `file:line`, screenshot region, a11y tree node, axe rule `color-contrast`]
   - **Impact:** [screen-reader / keyboard / low-vision / motor / cognitive — who blocked]
   - **Severity:** Blocking  **Effort:** S/M/L  **Confidence:** High/Med/Low
   - **Evidence:** [axe json, lighthouse, screenshot anchor]
   - **Affected:** [screens/components]
   - **Recommended fix:** [code example + token link, e.g. `color: var(--text-primary)` meets 4.5:1]

### Major / Minor

Same fields, severity Major/Minor.

### Not assessed — human judgment required

| Gate | Why not assessed | What would enable |
|------|------------------|-------------------|
| alt meaning | no screen-reader run | provide NVDA recording |
| reading order | no video | provide screen-reader video |

## Coverage summary

| Area | Automatically detectable | Browser-assisted | Manual | Result |
|------|--------------------------|------------------|--------|--------|
| contrast | axe fail? | computed styles + screenshot | — | pass/fail |
| keyboard | — | Tab trace | human + NVDA |  |

## Missing evidence register

| Need | Location if exists | Owner |
|------|--------------------|-------|
|  |  |  |

## Output handshake

- **Destination:** [repo/docs/URL]
- **Reviewer:** [who approves]
- **Confirmed:** [date]
