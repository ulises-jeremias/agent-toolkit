# A11y Curated Checklist — Gates (mode + SC + tool)

> Use as on-demand reference — do not load all gates into every agent context. Pick the gate that matches the finding.

| # | Gate | Mode | Tool / evidence | WCAG 2.2 SC (example, do not fabricate beyond) | Pass gate |
|---|------|------|-----------------|--------------------------------------------------|-----------|
| 1 | Semantic HTML: correct element | Automatic | axe/lighthouse, snapshot | 1.3.1, 4.1.2 | `<button>` not `<div onclick>` |
| 2 | Heading: h1 present, no skip, meaningful | Manual + Automatic (skip) | snapshot + human + axe heading-order | 1.3.1, 2.4.6 | one h1, sequential, meaningful text |
| 3 | Landmark: banner/nav/main/contentinfo not duplicated unlabeled | Manual + Automatic | snapshot + human | 1.3.1, 2.4.1 | landmarks present, labeled if duplicated |
| 4 | Keyboard: all functions reachable, no trap, logical Tab order | Browser-assisted | keyboard trace (`Tab` sequence) via playwright-cli | 2.1.1, 2.1.2, 2.4.3 | Tab reaches every control, no trap |
| 5 | Focus visible: indicator contrast ≥3:1, not removed | Browser-assisted | screenshot + computed styles (chrome-devtools) | 2.4.7, 2.4.3 | visible focus, order matches visual |
| 6 | ARIA: valid, no redundant role, `aria-live` for status | Automatic | axe, jsx-a11y | 4.1.2, 4.1.3 | valid ARIA, live for dynamic |
| 7 | Form label: `for`/`id` or `aria-label`, required/invalid linked | Automatic | axe | 1.3.1, 3.3.1, 3.3.2, 4.1.2 | label present, `aria-describedby` for errors |
| 8 | Label in name: visible label matches accessible name | Automatic + Manual (meaning) | axe + human | 2.5.3 | `aria-label` does not contradict visible |
| 9 | Error: identification + description + suggestion, focus to summary | Manual | human + screen-reader | 3.3.1, 3.3.3 | errors programmatically linked, helpful text |
| 10 | Contrast: text 4.5:1 (3:1 large), UI 3:1, light/dark/high-contrast | Browser-assisted | computed styles + screenshot | 1.4.3, 1.4.11 | ratios verified per theme |
| 11 | Zoom/reflow: 200% + 320px without loss/scroll | Browser-assisted | screenshot at zoom 200%, viewport 320 | 1.4.4, 1.4.10 | no horizontal scroll, content not hidden |
| 12 | Touch target: ≥24×24 px (AA), 44×44 preferred | Browser-assisted | computed layout | 2.5.8 | targets meet minimum |
| 13 | Reduced motion: respects `prefers-reduced-motion` | Browser-assisted | `prefers-reduced-motion` media query | 2.2.2, 2.3.3 | no autoplay >5s without pause |
| 14 | Alt meaning: alt text is *meaningful*, not just present | Manual | human + screen-reader (NVDA) | 1.1.1 | alt describes purpose, not just presence |
| 15 | Reading order: DOM order matches visual | Manual | human + screen-reader | 1.3.2 | logical sequence |
| 16 | Dynamic status: `role=status`/`aria-live` without focus steal | Browser-assisted + Manual | snapshot + human | 4.1.3 | live region announces, no focus steal |
| 17 | Media alternatives: captions/transcripts where applicable | Manual | human (flag Not assessed if media without evidence) | 1.2.2, 1.2.3 | captions present or flagged |

**Usage:** For each gate, record mode, SC, evidence (tool + screenshot/axe json), confidence. Do not claim AA pass from automatic alone — need browser-assisted + manual gates.
