---
name: review
description: WCAG 2.2 AA curated accessibility review — distinguishes automatically detectable, browser-assisted, and manual/human-judgment findings with evidence citations and SC mapping. Composes with design-assessment/design-improvement/frontend-design-review.
origin:
  type: first-party
---

# Accessibility Review (WCAG 2.2 AA)

Curated, composable accessibility review anchored to **WCAG 2.2 AA** (W3C TR https://www.w3.org/TR/WCAG22/). Use when the user asks for an accessibility audit, a11y review, WCAG check, or inclusive-design feedback.

**Curated, not wholesale vendored:** This skill distills WCAG 2.2 AA into actionable gates optimized for agent context — it does **not** vendor the entire `mgifford/accessibility-skills` prompt library. Upstream research decisions are recorded in references/research.md (ADOPT/REJECT per candidate). See also `web-design-guidelines` (WAI subset) and browser a11y tree via `playwright-cli`/`chrome-devtools`.

> **Do not claim full WCAG compliance from automated checks alone.** Automated = ~30–40% of AA; browser-assisted + manual judgment is required. Every finding must declare its detection mode and confidence.

## Modes — visible to agent

| Mode | What it catches | How | Confidence when passing |
|------|-----------------|-----|--------------------------|
| **Automatically detectable** | Missing alt, missing label, invalid ARIA, duplicate id, heading skip, empty link/button, missing lang, form missing `for`/`id`, table missing headers | Static analysis: `axe`/`lighthouse` via MegaLinter, `playwright-cli` snapshot a11y tree, ESLint jsx-a11y, `validate-manifests` style lint | High for *failure* (if no alt, fail); Low for *pass* (absence of error ≠ compliant) |
| **Browser-assisted** | Contrast ratio, focus visibility/order, keyboard trap, zoom/reflow at 200%/320px, touch target size, reduced-motion, dynamic status announcements, responsive a11y, focus management in SPAs | Rendered evidence: `playwright-cli` screenshots at breakpoints/themes, `chrome-devtools` a11y tree + computed styles + `performance` + `list_console_messages`, `take_screenshot` at light/dark/high-contrast, keyboard trace | Medium–High when rendered evidence captured; Low if text-only heuristic |
| **Manual / human judgment required** | Meaningful alt text, heading *meaning*, landmark *correctness*, logical reading order, error message *helpfulness*, status message *appropriateness*, media alternatives *quality*, cognitive load, plain language, consistent navigation *intent* | Human review + screenshot/video + screen-reader run (NVDA/JAWS/Narrator) + user testing | High only after human screen-reader judgment; otherwise mark **Not assessed — human judgment required** with what would enable assessment |

Every finding must cite **mode + evidence + WCAG SC (when mapped)** and downgrade confidence when using a weaker mode than ideal.

## Coverage (evidence-backed, mapped to WCAG 2.2 AA where applicable)

| Area | Checklist (gate before pass) | Example SC mapping — do not fabricate beyond listed |
|------|------------------------------|------------------------------------------------------|
| Semantic HTML | Correct element (`<nav>`, `<main>`, `<button>` not `<div onclick>`) | 1.3.1 Info and Relationships, 4.1.1 Parsing, 4.1.2 Name/Role/Value |
| Headings / landmarks | One `h1`, no level skip, landmarks (`banner, navigation, main, contentinfo`) present and not duplicated without label | 1.3.1, 2.4.1 Bypass Blocks, 2.4.6 Headings/Labels |
| Keyboard navigation | All functionality via keyboard, no trap, logical order, `Tab`/`Shift+Tab` reaches every interactive control | 2.1.1 Keyboard, 2.1.2 No Keyboard Trap, 2.4.3 Focus Order, 2.4.7 Focus Visible |
| Focus visibility / order | Visible focus indicator (contrast ≥3:1), order matches visual/DOM, `focus-visible` not removed without replacement | 2.4.7 Focus Visible, 2.4.3 Focus Order |
| ARIA correctness | No redundant role, `aria-*` only when native insufficient, `aria-live` for dynamic status, valid `aria-labelledby` | 4.1.2 Name/Role/Value, 4.1.3 Status Messages |
| Forms | `label` `for`/`id` or `aria-label`, required/invalid conveyed, error messages programmatically linked via `aria-describedby`/`aria-invalid` | 1.3.1, 3.3.1 Error Identification, 3.3.2 Labels or Instructions, 4.1.2 |
| Labels | Visible label matches accessible name, no `aria-label` that contradicts visible text | 2.5.3 Label in Name |
| Errors | Error identification, description, and suggestion where possible; focus moves to error summary | 3.3.1, 3.3.3 Error Suggestion |
| Contrast | Text ≥4.5:1 (≥3:1 large), UI components/borders ≥3:1, verified in light/dark/high-contrast | 1.4.3 Contrast (Minimum), 1.4.11 Non-text Contrast |
| Zoom / reflow | 200% zoom + 320px width without horizontal scroll or hidden content, responsive a11y not broken | 1.4.4 Resize Text, 1.4.10 Reflow |
| Responsive behavior | Touch targets ≥24×24 CSS px (AA), ≥44×44 preferred (AAA, note as enhanced), spacing preserved at breakpoints | 2.5.8 Target Size (Minimum) |
| Reduced motion | Respects `prefers-reduced-motion`, no autoplay beyond 5s without pause | 2.2.2 Pause/Stop/Hide, 2.3.3 Animation from Interactions |
| Screen-reader considerations | Alt text quality (not just presence), heading/landmark announcements, live region for dynamic content, reading order matches visual | 1.1.1 Non-text Content, 1.3.2 Meaningful Sequence, 4.1.3 |
| Dynamic content / status | Status messages via `role=status`/`aria-live` without stealing focus | 4.1.3 Status Messages |
| Media alternatives | Captions, transcripts, audio descriptions where applicable — flag as **Not assessed** if media present without evidence | 1.2.2 Captions (Prerecorded), 1.2.3 Audio Description |

**Do not fabricate WCAG mappings.** If unsure, leave SC blank and note *judgment required*. Mappings above are representative gates, not exhaustive AA. Reference: https://www.w3.org/TR/WCAG22/ (2023-10-05, W3C Recommendation, `WAI-WCAG22-20231005`).

## Workflow — compose, don't duplicate

```
CAPTURE (playwright-cli / chrome-devtools, rendered) → AUTOMATIC scan (axe/lighthouse via MegaLinter) → BROWSER-ASSISTED checks (contrast, focus, zoom/320px, a11y tree) → MANUAL gates (meaning, reading order, error helpfulness) → FINDINGS (mode+SC+evidence) → REMEDIATION
```

### Steps

1. **Capture rendered evidence** (required): `playwright-cli` `snapshot` + a11y tree, screenshots at desktop/mobile 320px + 200% zoom + light/dark/high-contrast, keyboard trace; optionally `chrome-devtools` `take_snapshot` + `list_console_messages`. Text-only heuristic is **Low confidence** + missing-evidence register.
2. **Automatic scan:** run `axe`/`lighthouse` (via `MegaLinter` a11y linters) or `eslint-plugin-jsx-a11y` on sampled files — record tool, version, and flags as evidence. Do not treat *pass* as compliant; treat *failure* as `Blocking/Major`.
3. **Browser-assisted checks:** verify contrast via computed styles + screenshot, focus order via `Tab` sequence, zoom/reflow at 200%/320px without loss, touch targets, `prefers-reduced-motion`. Cite viewport/theme/screenshot anchor.
4. **Manual/human gates:** evaluate alt *meaning*, heading *meaning*, landmark *correctness*, error *helpfulness*, media *quality* — mark **Not assessed — human judgment required** unless a screen-reader run (NVDA/JAWS/Narrator) is available; record what would enable assessment (recording, run).
5. **Findings:** per-finding record (see below). Map to WCAG SC where confident; otherwise note *no mapping fabricated*. Distinguish mode automatically vs browser-assisted vs manual.

### Integration with design engineering

- `design-assessment` A11Y phase **delegates** to this skill for deep a11y (parallel with `visual-reviewer` / `browser-perf-reviewer`); shares evidence map as authority.
- `design-improvement` consumes findings (Blocking/Major/Minor + mode + SC + evidence) and re-verifies via `playwright-cli`/`chrome-devtools` capture + re-review loop (`fix → capture → re-review` until Blocking cleared).
- `frontend-design-review` covers a11y at checklist depth (Grade C AA? Grade B ideal); this skill is the deeper SC-mapped pass.
- `MegaLinter` (when available) catches `automatically detectable` failures in CI; browser-assisted + manual remain human-evaluated.
- `browser tooling` distinction: `playwright-cli` for deterministic capture + `snapshot` a11y tree; `chrome-devtools` for `browser.accessibility` + computed styles + `browser.performance` where needed.

## Findings — reuse evidence model

Reuse `observation / impact / severity / effort / confidence / evidence / screens / recommended fix` + `1–5 scale 3=Defined, Not assessed, High/Med/Low, output-handshake` from `project-assessment-evidence` / `technical-unit-assessment`. No `72/100` synthetic scores.

Per finding:

- **Observation:** what you saw (element, `file:line`, screenshot region, a11y tree node, tool output)
- **Mode:** Automatically detectable / Browser-assisted / Manual
- **WCAG SC:** e.g. `1.4.3 Contrast (Minimum)` — or blank with reason if judgment required
- **Impact:** user blocked / degraded (screen-reader, keyboard-only, low vision, motor, cognitive)
- **Severity:** Blocking (AA failure, task blocked) / Major (degraded, needs fix) / Minor (refinement)
- **Effort:** S/M/L
- **Confidence:** High/Med/Low — downgrade if using weaker mode than ideal (e.g., text-only heuristic = Low) or if manual gate without screen-reader run
- **Evidence:** link to axe/json, lighthouse, screenshot, a11y tree, recording
- **Affected:** screens/components
- **Recommended fix:** code example + token/design-system link (not generic advice)
- **Evidence quality:** Direct / Indirect / Stale / Missing (from evidence map)

See `references/a11y-checklist.md` for gate-by-gate checklist (mode + SC + tool) and `references/a11y-findings-template.md` for report template.

## Delegation table

| Need | Skill |
|------|-------|
| Design-unit orchestration (A11Y phase) | `design-assessment` (delegates here) |
| Improvement loop (fix → capture → re-review) | `design-improvement` |
| Quick visual a11y pass (Grade C/B) | `frontend-design-review` (a11y modifier) |
| WIG a11y rules (focus/forms/motion subset) | `web-design-guidelines` |
| Deterministic capture + snapshot a11y tree | `playwright-cli` |
| Runtime a11y tree / computed styles / contrast | `chrome-devtools` |
| Linter gate for automatically detectable | `MegaLinter` (axe, jsx-a11y) where available |
| Output gate | `output-handshake` |

## Security & compatibility

- Observe-only, no secrets. Screenshots must not capture PII; redact.
- Portable; browser optional with degraded confidence.
- Media alternatives flagged as **Not assessed** without evidence — do not claim compliance.

## References

- `references/research.md` — upstream curation (mgifford/accessibility-skills, podo/design-agent-skills radar, WCAG 2.2) with ADOPT/REJECT + license/maintenance/date
- `references/a11y-checklist.md` — curated gate checklist (mode + SC + tool)
- `references/a11y-findings-template.md` — findings report template (mode + SC mapping)
- `W3C WCAG 2.2` — https://www.w3.org/TR/WCAG22/ (normative, 2023-10-05)
- `web-design-guidelines` (WAI subset) + `playwright-cli` / `chrome-devtools` + `MegaLinter`

