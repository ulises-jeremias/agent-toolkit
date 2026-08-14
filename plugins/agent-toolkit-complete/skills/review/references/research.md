# Accessibility Upstream Research — 2026-08-11

## WCAG 2.2 AA (normative)

- **W3C TR:** https://www.w3.org/TR/WCAG22/ (W3C Recommendation 2023-10-05, `WAI-WCAG22-20231005`)
- **License:** W3C Document License (permissive, not software) — reference only, not vendored
- **Decision:** **ADOPT** as normative baseline for AA gates (contrast, keyboard, ARIA, reflow etc.). No vendoring — cite URLs and SC numbers; do not copy full spec. Freshness: normative, stable.

## mgifford/accessibility-skills

- **Repo:** https://github.com/mgifford/accessibility-skills (community, curated a11y prompts)
- **License:** CHECK — repo LICENSE file indicates MIT (verified 2026-08-11 via gh api → MIT, ~1.2k stars, active). Community prompts are large (~50k+ tokens if fully loaded).
- **Content tax:** Full skill prompt is ~30–40k tokens — too high for default context per #395.
- **Decision:** **REJECT wholesale vendoring** — context cost too high, overlaps with `web-design-guidelines` and WCAG gates already curated here. **ADOPT curated gates** distilled from it: semantic HTML, headings/landmarks, keyboard/focus, ARIA, forms/labels, contrast, zoom/reflow, reduced motion, dynamic status. Record rejection rationale: avoid monolithic prompt; prefer composable checklist with mode distinction + browser verification.

## podo/design-agent-skills (radar)

- **Repo/index:** community index of design agent skills including accessibility entries
- **License:** Mixed (community index, not a single license)
- **Decision:** **REFERENCE** as radar for discovery, not as vendored source. Useful to identify candidates (e.g., `accessible-components`) but not directly vendored.

## web-design-guidelines (Vercel)

- **Repo:** vercel-labs/web-interface-guidelines (MIT, vendored as `design/web-design-guidelines` via provenance lock `4e799d45c17aec...` )
- **Coverage:** Subset of WAI rules (focus, forms, animation, etc.)
- **Decision:** **ADOPT** as complementary WIG rules — this skill covers deeper SC mapping; `web-design-guidelines` handles WIG subset. No duplication — delegate to it for WIG checks.

## Browser tooling (axe / lighthouse / jsx-a11y via MegaLinter + playwright / chrome-devtools)

- **axe-core:** MIT, Deque — automatically detectable subset
- **lighthouse:** Apache-2.0 — performance + a11y categories
- **eslint-plugin-jsx-a11y:** MIT
- **playwright-cli:** first-party wrapper (CLI via npx), MIT (Playwright) — snapshot a11y tree, screenshots
- **chrome-devtools MCP:** Apache-2.0 (ChromeDevTools/chrome-devtools-mcp) — a11y tree, computed styles
- **Decision:** **ADOPT** via composition: automatically detectable via MegaLinter (axe/jsx-a11y), browser-assisted via `playwright-cli`/`chrome-devtools` capture. No vendoring of axe rules — delegate to linter/browser.

## Decision summary

| Candidate | License | Context cost | Maintenance | Decision | Rationale |
|-----------|---------|--------------|-------------|----------|-----------|
| WCAG 2.2 AA (W3C TR) | W3C Doc License | low (reference) | normative stable | **ADOPT** (reference, not vendored) | authoritative AA baseline |
| mgifford/accessibility-skills | MIT | high (~50k) | active community | **REJECT wholesale, ADOPT curated gates** | avoid monolith, optimize context |
| podo/design-agent-skills | mixed | — | index | **REFERENCE** | radar only |
| web-design-guidelines | MIT | low (vendored) | active | **ADOPT** (delegate) | WIG subset already vendored |
| axe / lighthouse / jsx-a11y | MIT/Apache | low via MegaLinter | active | **ADOPT** (via MegaLinter/browser) | automatic subset |

**Date:** 2026-08-11  **Reviewed by:** toolkit maintainers  **Next refresh:** check WCAG errata + mgifford releases quarterly; no webhook — staleness via `provenance updates` cadence.
