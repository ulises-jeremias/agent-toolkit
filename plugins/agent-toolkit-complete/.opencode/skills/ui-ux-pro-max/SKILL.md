---
name: ui-ux-pro-max
description: "UI/UX design intelligence. 67 styles, 96 palettes, 57 font pairings, 25 charts, 13 stacks (React, Next.js, Vue, Svelte, SwiftUI, React Native, Flutter, Tailwind, shadcn/ui). Actions: plan, build, create, design, implement, review, fix, improve, optimize, enhance, refactor, check UI/UX code. Projects: website, landing page, dashboard, admin panel, e-commerce, SaaS, portfolio, blog, mobile app, .html, .tsx, .vue, .svelte. Elements: button, modal, navbar, sidebar, card, table, form, chart. Styles: glassmorphism, claymorphism, minimalism, brutalism, neumorphism, bento grid, dark mode, responsive, skeuomorphism, flat design. Topics: color palette, accessibility, animation, layout, typography, font pairing, spacing, hover, shadow, gradient. Integrations: shadcn/ui MCP for component search and examples."
---

# UI/UX Pro Max

Comprehensive design intelligence for web and mobile. Searchable database of 67 styles, 96
palettes, 57 font pairings, 99 UX guidelines, and 25 chart types across 13 technology stacks.

## When to use

Design new UI components or pages, choose palettes/typography, review code for UX issues,
build landing pages/dashboards, implement accessibility requirements.

## Out of scope

- Does NOT make business/content decisions — ask user for product direction
- Does NOT handle Figma MCP operations — use **`figma`** for that

## Workflow

**Step 1 — Always start with `--design-system`:**

```bash
SCRIPT="$HOME/.local/share/agent-toolkit/skills/ui-ux-pro-max/scripts/search.py"
python3 "$SCRIPT" "<product_type> <industry> <keywords>" --design-system [-p "Project Name"]
```

Returns: pattern, style, colors, typography, effects, anti-patterns.

**Step 2 — Persist (optional, Master + Overrides pattern):**

```bash
python3 "$SCRIPT" "<query>" --design-system --persist -p "Project Name"
# Creates design-system/MASTER.md and design-system/pages/<page>.md overrides
```

**Step 3 — Targeted searches as needed:**

```bash
python3 "$SCRIPT" "<keyword>" --domain <domain>          # specific domain
python3 "$SCRIPT" "<keyword>" --stack html-tailwind       # stack guidelines
```

Default stack: `html-tailwind`. See `references/search-reference.md` for all domains and stacks.

## Critical UX rules (CRITICAL priority — always check)

- **Accessibility:** 4.5:1 contrast ratio, visible focus rings, alt text, aria-labels, keyboard nav
- **Touch targets:** minimum 44×44px; use click/tap for primary interactions
- **No emoji icons:** use SVG (Heroicons, Lucide, Simple Icons)
- **cursor-pointer** on all clickable/hoverable elements
- **Smooth transitions:** 150–300ms for micro-interactions

## References

- `references/ui-rules.md` — professional UI rules (icons, light/dark contrast, layout)
- `references/pre-delivery-checklist.md` — checklist before delivering any UI code
- `references/search-reference.md` — available domains, stacks, and UX rule priority table
