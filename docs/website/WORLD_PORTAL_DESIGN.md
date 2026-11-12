# World Portal — Design Specification (Hornero Valley)

**Status:** Design specification for implementation (Agent D). Not implemented by this document.
**Mission:** [#1759](https://github.com/ulises-jeremias/agent-toolkit/issues/1759) · Website in `apps/web` (Astro, static)
**Baseline audited:** `origin/main` at `fda178e0` (`v1.49.0` prepared in `7bd44a7b`), 2026-11-11
**Authority:** [SEMANTIC_WORLD.md](../desktop/SEMANTIC_WORLD.md), [DESIGN.md](../desktop/DESIGN.md) §5–§7,
[PIXEL_RENAISSANCE.md](../desktop/PIXEL_RENAISSANCE.md), [VISUAL_QA.md](VISUAL_QA.md) (2026-10-11 journey)
**Rule for Agent D:** if this spec and `SEMANTIC_WORLD.md §9` / `DESIGN.md §3` disagree, the semantic/truth
contracts win. No fake live sessions, no invented metrics, no decorative NPCs/workers — ever.

---

## 0. Verdict on the current site (read this first)

The current site is a competent dark brochure wearing pixel type. It does **not** feel like entering
Hornero Valley. Agent D must fix, in priority order:

| # | Severity | Finding (evidence) | Required change |
| --- | --- | --- | --- |
| P0-1 | Blocker | **Cyberpunk City is retired but still promoted twice.** `apps/web/src/pages/index.astro:60-64` neon hero sign linking to `/world/`; `apps/web/src/pages/world.astro:127-159` full `.section--neon` ("Or move downtown: Cyberpunk City", "Start with the whole valley — or the neon city"); `apps/web/src/styles/global.css:860-935` (`.hero-sign--neon`, `.section--neon`, `.neon-sign`, `.neon-card`); unused `import cyberpunk … world-cyberpunk.png` at `world.astro:5`; asset `static/screenshots/world-cyberpunk.png`. Contradicts `SEMANTIC_WORLD.md:45` ("Cyberpunk / space / alternate themes now — REMOVE (defer)"). | Delete all of it (§10.1, §10.3). No replacement teaser, no "coming soon". |
| P0-2 | Blocker | **Silkscreen is the display face, not signage.** `global.css:212-222` sets `h1`/`h2` in `--pixel` (Silkscreen) at up to `5rem` with `letter-spacing:-0.075em`; also `.journey-stop h3`, `.quote-strip`, `.brand`, `.section-kicker`. Pixel glyphs at headline size with negative tracking are hard to read and contradict the mission ("Silkscreen only for signage") and `DESIGN.md:189-191`. | New type system §4: IBM Plex Sans display/body, Silkscreen only ≤ signage roles listed in §4.3. |
| P0-3 | Blocker | **The palette is a dark-teal monochrome, not the valley.** `global.css:1-25`: `--night #10252a` page background everywhere; cream `#eef5df` only ever *text*, never a surface; terracotta is one muted `--ember #dc8557` used almost nowhere; no golden-hour, plaster, dirt, or slate from `palette.px.js`. A visitor never crosses from dark chrome into a warm, lit place. | Daylight-first color system §3 (Meadow surfaces, Dusk only for proof frames/footer). |
| P1-1 | Major | **No semantic destinations.** Header (`SiteHeader.astro`) labels are generic SaaS: "Start here / The World / People / Swarms / Capabilities / Docs". None of Trailhead, Project district, Library, Guild Hall, Operations Hall, Workshop, Waystation, Town Square, Chronicles appears. `index.astro:87-134` semantic list uses abstract terms (PROJECT/CAPABILITIES/DURABLE CONTEXT…). | Destination map §5 applied to header, journey, `/world/`, footer. |
| P1-2 | Major | **The journey is scroll theatre.** `WorldJourney.astro` + `global.css:442-714`: sticky stage, five stops at `min-height:min(52vh,500px)` (62svh mobile), `aria-live="polite"` location churn, gradient progress bar, infinite `journey-firefly`/`twinkle` animations. It works (see `VISUAL_QA.md`) and links stay real — keep that skeleton, cut the theatre (§6, §8). | Keep sticky proof window + real links; remove progress-as-game-bar, reduce stop height, demote motion. |
| P1-3 | Major | **Only two breakpoints** (`900px`, `680px` in `global.css:1535-1818`; hero-only `1024px`). Nothing designed for 768, 1440, 1920; `--content:1160px` caps every width the same way. | Breakpoint/layout system §7 with explicit rules at 390/768/1024/1440/1920. |
| P1-4 | Major | **Hero art is labelled illustration but reads as fake product** until the small caption (`index.astro:52-55`). Good honesty, weak hierarchy. | Keep caption, move it above the fold line of the frame, never crop it out on mobile (§10.1). |
| P2-1 | Minor | Rotated sticker signs (`.hero-sign { transform: rotate(2deg) }`, `global.css:844-856`) and hard `8px 8px 0` shadows on every frame make the valley feel like a sticker book, not a place. | Signage becomes real signposts (§2.3); shadows reduce to §3.4 elevation rules. |
| P2-2 | Minor | `color-scheme: dark` + `#10252a` `theme-color` in `SiteLayout.astro` declares the whole portal dark. | `theme-color:#ffeec4`-family after §3 lands; declare `color-scheme: light` for portal surfaces, dark only inside proof frames. |

**What is already right and must not be regressed:** normal navigation always present (`SiteHeader.astro`,
mobile `<details>` nav), no-JS journey fallback, reduced-motion global block (`global.css:1819-1831`),
honest screenshot captions ("Illustration · not live product state", "Actual Desktop capture"),
no invented counts anywhere except the build-generated catalog count on `/capabilities/` and the real
GitHub Release lookup on `/download/` (both truthful, keep), skip link, `aria-current` handling.
`apps/web/tests/site.spec.ts` (11 Playwright/axe tests) is the regression floor — every change below
must keep it green or update it deliberately with the same coverage.

## 1. Design principles

1. **Entering, not browsing.** The first viewport is a threshold: warm valley light, a path, named
   places. Content pages are clearings off that path, not separate dark themes.
2. **The map is the information architecture** (`SEMANTIC_WORLD.md:15-18`). Every destination name on
   the website names a real Desktop place *and* links to a real route (§5). A name without a route is forbidden.
3. **Modern type, pixel signage.** Reading is IBM Plex Sans; Silkscreen is how the valley labels
   things — the way a carved wooden sign labels a trail (§4).
4. **Truth before atmosphere** (`SEMANTIC_WORLD.md:31,275-283`). Screenshots are labelled captures;
   nothing on the site implies a live session, online Person, count, or progress the build cannot prove.
5. **Normal navigation always wins.** Header, footer, in-page links and docs sidebar are complete
   without JS, scroll position, hover, or walking. The journey is an enhancement, never a gate (§6).
6. **One valley, no second theme.** Cyberpunk City is retired (P0-1). Do not add theme switchers,
   Dusk/Meadow toggles, or alternate palettes to the website.

## 2. The visual world

### 2.1 Scene composition (portal-wide)

- **Threshold (hero):** daylight Meadow. Warm cream sky/plaster field (`--cream-0`, §3) at top,
  grass band (`--grass-2 → --grass-3`) rising from the bottom third, the existing valley illustration
  (`static/site/valley-journey.webp`, 1536×1024, keep) presented as the view down the path — full-bleed
  inside a carved frame (§2.3), not cropped into a dashboard card. The hornero stays a small ambient
  signature in the art only (`PIXEL_RENAISSANCE.md:14-16`, `DESIGN.md:101-107`): never a mascot, logo
  crowd, or clickable character.
- **Districts as page sections:** each homepage section is a *place* with a signpost (§2.3), a ground
  tint from §3.2, and a path edge (2px dirt `--dirt-1` rule with 8px stone dashes) instead of the
  current generic `border-top: 1px solid var(--line)`.
- **Proof frames:** real Desktop captures (`static/screenshots/*.png`, `docs/desktop/assets/electron/**`)
  sit in Dusk-dark frames (`--ink-2` interior, §3) so the bright portal makes the product screenshots
  read as "looking into the real valley", exactly as `WorldJourney.astro:90-103` already frames them.
- **Footer as valley floor at dusk:** keep the hill/river/lamp composition (`SiteFooter.astro`,
  `global.css:1442-1524`) but recolor to §3 Dusk tokens; it is the one intentionally dark surface
  besides proof frames. Lamps static (no glow animation).

### 2.2 Materials (from `apps/desktop/scripts/world-art-pxl/palette.px.js`, canonical)

Cream plaster `#ffeec4/#eed9a8/#cfa96f`, wood `#a06a3f/#6b4429/#46301f`, terracotta
`#e08a5a/#c65f3d/#9e3f2f`, slate `#8a9bb3/#5b6d84/#354255`, grass `#8ed060/#55a83e/#2f7a38/#1d5228`,
dirt `#c08a4e/#7a4f2e`, plaza stone `#d8d0bc/#a89f8d/#6f6759`, creek teal `#6fe3d8/#2fa8b8/#1d6f8a/#123f57`,
lamp/gold `#fff0a8/#ffb84e/#ffd93e`, ink `#2b2135`. Web tokens in §3 are sampled from these; Agent D
must not invent hues outside this file plus `DESIGN.md §5` anchors.

### 2.3 Signage & frames (replaces `.pixel-frame` clip-path + rotated stickers)

- **Signpost:** inline-flex, wood background `--wood-2`, 2px `--ink-1` border, cream Silkscreen text
  (§4.3), a 6×6px terracotta nail dot left. No rotation, no neon, no glow. Used for: destination names,
  journey location label, screen captions, hero valley sign.
- **Carved frame:** 2px `--ink-1` border + inner 1px `rgb(43 33 53 / 25%)` offset line + shadow
  `6px 6px 0 rgb(43 33 53 / 18%)` on cream, `6px 6px 0 #071419`-equivalent (`--ink-2`) on Dusk frames.
  Delete the 8-point `clip-path` polygon (`global.css:246-255`): clipped corners break focus outlines.
- `image-rendering: pixelated` only on pixel art (hero illustration, world captures' pixel UI at
  integer-ish sizes, brand mark). Photographic/16:9 inspector captures keep `auto` (current
  `.journey-image` behavior).

## 3. Color system

### 3.1 Tokens (replace `:root` in `global.css:1-25`)

```css
:root {
  color-scheme: light;
  /* Ink & cream (text surfaces) */
  --ink-1:#2b2135;  /* PXL ink: display text, borders, signage text on light wood */
  --ink-2:#1d1626;  /* proof-frame interior, footer dusk base (derived: ink-1 darkened) */
  --cream-0:#fff6e0; /* page top / plaster highlight */
  --cream-1:#ffeec4; /* default page surface */
  --cream-2:#eed9a8; /* raised plaster, signpost text on ink */
  --cream-3:#cfa96f; /* plaster shade, hairlines on cream */
  /* Greens (the valley) */
  --grass-1:#8ed060; --grass-2:#55a83e; --grass-3:#2f7a38; --grass-4:#1d5228;
  /* Earth & roof */
  --dirt-1:#c08a4e; --dirt-2:#7a4f2e;
  --terra-1:#e08a5a; --terra-2:#c65f3d; --terra-3:#9e3f2f;
  --slate-1:#8a9bb3; --slate-2:#5b6d84; --slate-3:#354255;
  --stone-1:#d8d0bc; --stone-2:#a89f8d;
  /* Creek & lamp (accents only) */
  --creek-1:#6fe3d8; --creek-2:#2fa8b8; --creek-3:#1d6f8a; --creek-4:#123f57;
  --lamp-1:#fff0a8; --gold-1:#ffd93e; --gold-2:#ffb84e;
  --wood-1:#a06a3f; --wood-2:#6b4429; --wood-3:#46301f;
}
```

### 3.2 Usage rules (binding)

| Surface | Token | Text on it | Verified contrast (computed, WCAG formula) |
| --- | --- | --- | --- |
| Page (Meadow) | `--cream-1` | `--ink-1` body, `--grass-4` links/kickers | ink/cream-1 **13.33:1** |
| Raised plaster card | `--cream-0` | `--ink-1`; muted = `--wood-3` | ink/cream-0 **14.22:1**; wood-3/cream-0 **9.01:1** |
| Grass district band | `--grass-4` | `--cream-0` headings, `--cream-1` body | cream-0/grass-4 **8.52:1** |
| Primary button | `--gold-1` bg | `--ink-1` label | **11.12:1** |
| Secondary button | transparent on cream | `--grass-4` label + 2px `--grass-3` border | grass-4/cream-1 **7.98:1** |
| Terracotta accent (brand ticks, active sign nail, footer CTA band) | `--terra-2` | only `--cream-0` large/signage text, never body | cream-0 on terra-2 is < 4.5 for small text — signage ≥ §4.3 sizes only; verify in QA |
| Proof frame / footer (Dusk) | `--ink-2` / `--creek-4` | `--cream-1` text, `--gold-1` captions | cream on current `#10252a` measured family **12.71:1** (recompute for `--ink-2` in QA) |
| Focus outline | `--terra-3` on cream, `--gold-1` on dark | — | terra-3/cream-0 **6.09:1** (non-text ≥3:1 ✓) |

Rules: (a) green bands are *places*, max one per viewport section, never body-text background for
long prose — docs/prose stay on cream; (b) creek teal is for water/links-in-dark-frames only, never
a page background (that was the old `--night` failure); (c) no gradients except the hero sky
(`--cream-0 → --cream-1 → grass band`) and proof-frame vignette; no purple/indigo, no glassmorphism
(`DESIGN.md §3`); (d) status colors only with text labels, never color-alone (`SEMANTIC_WORLD.md:264`).

### 3.3 Dark surfaces

Only two: proof frames and footer. `SiteLayout.astro` `theme-color` becomes `#ffeec4`;
`color-scheme: light`. Docs code blocks keep a dark `--creek-4` background (current `.prose pre`
behavior, retokenized) — code is a "terminal window into the Workshop", not a page theme.

### 3.4 Elevation

Resting: `4px 4px 0 rgb(43 33 53 / 16%)`. Raised (sticky journey stage, mobile nav panel):
`8px 8px 0 rgb(43 33 53 / 20%)`. No blurred shadows on cream; blur allowed only inside proof frames.

## 4. Typography

**No new webfonts.** The site already self-hosts everything it needs via `@fontsource`
(`SiteLayout.astro:2-8`): IBM Plex Sans 400/500/600/700, IBM Plex Mono 400/600, Silkscreen 400.
Adding a display webfont (Fraunces is retired with Paper Co., `DESIGN.md:189`; any new serif/neo-grotesque
would be a download + identity change with no mission justification) is rejected. Modernity comes from
weight, size contrast and spacing in Plex Sans — the same family Desktop uses for professional surfaces
(`PIXEL_RENAISSANCE.md:93-95`).

### 4.1 Roles (replace `--pixel` headline usage in `global.css`)

```css
--display:"IBM Plex Sans",system-ui,sans-serif; /* 700, tight */
--body:"IBM Plex Sans",system-ui,sans-serif;    /* 400/500/600 */
--sign:"Silkscreen","IBM Plex Mono",monospace;  /* signage only, §4.3 */
--code:"IBM Plex Mono",ui-monospace,monospace;
```

### 4.2 Scale (fluid with `clamp`, min sizes are floors — Silkscreen never below 8px)

| Role | Spec | Use |
| --- | --- | --- |
| Display-1 (h1) | Plex Sans 700, `clamp(2.5rem,1.6rem+3.4vw,4.25rem)`, lh 1.04, ls `-0.03em`, `text-wrap:balance` | One per page, on cream or grass band |
| Display-2 (h2) | Plex Sans 700, `clamp(1.75rem,1.3rem+1.8vw,2.75rem)`, lh 1.12, ls `-0.025em` | Section titles |
| Display-3 (h3) | Plex Sans 600, `clamp(1.15rem,1.05rem+0.5vw,1.4rem)`, lh 1.25 | Card/place titles |
| Lede | Plex Sans 400, `clamp(1.06rem,1rem+0.4vw,1.3rem)`, lh 1.65, max 62ch | Under h1 only |
| Body | Plex Sans 400, `1rem/1.7`; 500 for lead-ins | Prose max 68ch (docs 78ch, current `.prose`) |
| Small / caption | Plex Sans 400, `0.85rem/1.55`, `--wood-3` on cream | Captions, footnotes |
| Code | Plex Mono 400/600, `0.9rem/1.7` | Commands, routes, keys — never Silkscreen |

Current violations to fix: `global.css:215` (h1 Silkscreen 5rem, ls −0.075em), `:220` (h2), `:697`
(journey h3), `:438` (quote-strip), all become the rows above. Body text stays Plex Sans (already correct).

### 4.3 Silkscreen — signage allowlist (exhaustive)

Silkscreen 400 only, uppercase, `letter-spacing:0.06em` (never negative), sizes 8–14px, on wood/ink/
terracotta sign surfaces or as cream text on grass-4/ink: (1) destination signposts (§5 names);
(2) journey location label + route numerals; (3) screen captions ("ACTUAL DESKTOP CAPTURE");
(4) eyebrow/kicker *only when rendered as a signpost component* — plain kickers become Plex Sans 600
11px uppercase ls 0.12em in `--terra-3`; (5) brand wordmark in header/footer (12px, current `.brand`);
(6) 404 sign ("THIS TRAIL ENDS HERE" is body copy — its sign may be Silkscreen). Everything else —
buttons, nav links, table text, counts, form labels — is Plex. Buttons: Plex Sans 600 0.95rem.

## 5. Semantic destination map (binding names → real routes)

Names come from the mission + `SEMANTIC_WORLD.md §3/§6`. Each row: signpost label (Silkscreen),
plain-language subtitle (Plex, always adjacent — signs never stand alone for a11y), route that exists
today in `apps/web/src/pages`. Agent D adds no new routes for this map; anchors must exist or be added
as `id`s on the target page.

| Signpost | What it is (Desktop truth) | Web route | Where it appears |
| --- | --- | --- | --- |
| **Trailhead** | Onboarding: install, workspace, first session (`SEMANTIC_WORLD` Workshop grounds) | `/start/` (+ written twin `/docs/getting-started/`) | Header #1, hero secondary CTA, footer |
| **Project District** | Registered project houses, east-bank neighborhood (`SEMANTIC_WORLD.md:93,122-123`) | `/world/` (landmarks section) + journey stop `#journey-project` → `/docs/desktop/` | Header (under World), journey, `/world/` |
| **Library** | Capability catalog: Skills, Agent Definitions, MCP, Loops (`capability.shelf`) | `/capabilities/` (reading room: `/docs/`) | Header, journey stop `library`, footer |
| **Guild Hall** | People roster: durable collaborators (`person.profile`) | `/people/` | Header, journey stop `people` |
| **Operations Hall** | Jobs, Loops, Swarms, approvals, Attention (`agent.working`, `swarm.table`) | `/swarms/` (docs: `/docs/swarms/`, `/docs/loops/`) | Header (replaces bare "Swarms"), journey stop `operations` |
| **Workshop** | Terminal, coding tools, CLI (`tool.terminal`, `tool.coding`) | `/docs/cli/` (prove it: `/docs/desktop/` terminal section) | `/world/` landmarks, Start steps, docs sidebar |
| **Waystation** | Download/install, release evidence (`ops.crate`) | `/download/` | Header CTA (replaces "Download ↗" label only — keep button style §3.2), hero primary CTA |
| **Town Square** | Community, source, issues, contributing | `/community/` (GitHub links therein) | Footer, homepage closing section |
| **Chronicles** | Release history from canonical `CHANGELOG.md` | `/changelog/` | Footer, `/download/` cross-link |

Header order (desktop): Trailhead · Project District (`/world/`) · Library · Guild Hall ·
Operations Hall · Docs (`/docs/`, plain label "Field Guide") · **[Waystation: Download Desktop]**.
Nine signposts in the header would crowd <1024px — Chronicles/Town Square/Workshop live in footer +
in-context (rule: header ≤ 7 items). Every destination also appears as a journey/section signpost on
`/` and `/world/` so the full map is learnable in one scroll.

## 6. Visitor journeys & interaction model

### 6.1 Three journeys (all completable with header alone)

1. **Newcomer (Trailhead path):** `/` hero → "Start the guide" → `/start/` 12 steps → `/download/`
   (Waystation) → `/docs/getting-started/`. Success = download link reached in ≤3 clicks from `/`.
2. **Evaluator (Valley tour):** `/` hero → WorldJourney stops (valley → project → people →
   operations → library, keep `WorldJourney.astro:8-64` scenes/links) → focused page
   (`/world/ /people/ /swarms/ /capabilities/`) → `/download/`. Each stop keeps its real
   `link/linkLabel`; rename labels to §5 signposts with Plex subtitles.
3. **Returning / reference (Field Guide):** any page → header "Field Guide" → `/docs/` groups
   (`docs-nav.mjs`: Start here / Use Agent Toolkit / Understand the model / Capabilities / Trust and
   build — keep, rename group headings to destination names where truthful) → `/docs/<slug>/` with
   sticky sidebar. Docs remain cream reading surfaces; no journey mechanics inside docs.

### 6.2 Interaction rules

- **Nothing requires JS, scroll, hover, or pointer precision.** Journey scene-switching stays
  progressive enhancement (current `WorldJourney.astro:151-259` IntersectionObserver/rAF scroll
  handler + anchor fallback; no-JS test in `site.spec.ts` must keep passing). Scroll is never
  captured/hijacked (`VISUAL_QA.md:19-20` — keep).
- **Sticky stage is a picture frame, not a HUD:** remove `.journey-progress` bar-as-progress
  (implies quantified progress the site cannot prove); replace with signpost location label +
  `02 / 05` Plex Mono counter (position in a list is factual, not a metric). Keep route nav
  (`<nav aria-label="Jump to a place in the workspace">`) with ≥44px targets on touch
  (current coarse-pointer rule `global.css:674-678` — keep, extend to all route links).
- **`aria-live`:** location label changes on scroll must not announce repeatedly — change
  `aria-live="polite"` (`WorldJourney.astro:106`) to `aria-hidden` visual + `aria-current="step"`
  on the route link as the accessible state (screen-reader users navigate the stops as articles).
- **Keyboard:** journey route links and stops in DOM order; `scroll-margin-top` ≥ sticky header +
  stage height at every breakpoint (§7); focus-visible = §3.2 outline, 3px, offset 4px (keep current).
- **Targets:** all nav/route/button targets ≥44×44px on coarse pointers, ≥36px desktop.

## 7. Responsive layout rules (390 / 768 / 1024 / 1440 / 1920)

Replace the 900/680-only system (`global.css:1535-1818`) with these breakpoints. `--content` becomes
fluid: `min(1240px, 100% - 2*gutter)`; gutters: 18px (≤680), 28px (681–1023), 40px (≥1024),
and at ≥1600 the valley hero art may breathe to 1440px wide while text stays ≤1240px.

| Width | Layout rules (binding) |
| --- | --- |
| **390** (mobile) | Single column. Header: brand + `<details>` nav (keep), menu panel lists all §5 destinations present in header + Download. Hero: Display-1 ≥2.4rem, art 4:3 crop with caption *above* frame bottom (never overlapped by signs — signposts stack below art). Journey: stage sticky top = header 68px, stage 16:9, stops `min-height:auto` with 48px path spacing (kill 62svh), route nav horizontal scroll with 44px targets. Semantic/destination grid 1 col. Docs sidebar = horizontal scroll chips (current behavior, keep). No horizontal scroll (`scrollWidth == innerWidth`, asserted in tests). |
| **768** (tablet) | Two-column begins: destination grid 2 col; scene-grid stacks copy→image (image 16:10). Journey: **non-sticky** stage above stops (sticky two-col starts at 1024 — at 768 the current 270px stop column is too narrow for Display-3+body). Header still `<details>` nav (desktop nav appears ≥1024). Page-hero art 16:9. |
| **1024** (laptop) | Desktop nav visible (≤7 items §5, 0.9rem Plex 500). Hero two-col (copy 0.9fr / art 1.1fr, current `global.css:961-1006` geometry — retokenize only). Journey two-col sticky stage (top 96px), stops ≥ `min(44vh,460px)`. Docs sidebar 250px sticky (current). Semantic grid 3 col. |
| **1440** (desktop) | `--content` 1240px centered. Hero art ≤1100px. Journey stage ≤ 760px wide, stops max 52ch. Type at top of clamp ranges. Capture/review reference width (existing `VISUAL_QA.md` + `site.spec.ts` 1440 tests). |
| **1920** (wide) | Content does **not** stretch: same 1240px column; extra width goes to valley margins — grass band + path edge extend full-bleed, hero illustration scales to 1440px max with cream sky filling sides. Journey stage stays ≤820px. No element > 1600px except full-bleed section backgrounds. Verify no orphaned sticky stage (stage+stops centered as one 1240px unit). |

Global: `min-width:320px` floor (current `global.css:36`, keep); images always with explicit
`width/height` or `aspect-ratio`; pixel art `image-rendering:pixelated`, captures `auto`.

## 8. Motion & reduced-motion rules

Current state: global kill-switch exists (`global.css:1819-1831`), journey has a partial block
(`:716-724`), but `twinkle` (hero stars, 4s infinite), `journey-firefly` (3s infinite), `hero-rise`
entrance cascade, landscape 950ms camera moves and image `steps()` wipes run by default.

Binding rules for Agent D:

1. **Ambient motion is environmental only** (`SEMANTIC_WORLD.md:42,213`): water/firefly/bird may
   move; nothing that looks like a worker, session, or progress may animate without real state —
   the website has no real state, so **no activity animation at all**.
2. Remove `twinkle` and `journey-firefly` infinite animations entirely (delete, don't gate).
   Static lamp dots may remain as *art inside the illustration only*.
3. Allowed motion (default): journey image cross-fade ≤300ms ease + landscape scale ≤600ms on
   scene change; button hover translateY(−1px) 120ms; hero entrance: single 400ms fade-rise on
   copy only (delete the 5-step cascade `global.css:797-813`). No parallax, no scroll-driven
   transforms beyond the existing nearest-stop selection.
4. `prefers-reduced-motion: reduce`: keep the global block; additionally journey stage must swap
   images with **no** clip/transform (opacity only, ≤1ms), sticky positioning remains (it is
   layout, not motion), `scroll-behavior:auto`. The `site.spec.ts` reduced-motion test
   (transitionDuration < 0.001 assertion) must still pass.
5. `document.hidden` / off-screen: no timers to pause is the goal — after (2) the only JS timer is
   the journey's 2500ms route-navigation guard; keep it, add nothing rAF-looping.
6. Focus never moves on scene change; scene change never scrolls the page.

## 9. Static art & imagery rules

- Keep: `static/site/valley-journey.webp` (hero + journey landscape), `og-card.jpg`,
  `static/screenshots/{world,project-interior,people,operations,library}.png`, Desktop electron
  captures referenced by `people/swarms/world.astro`. All are real captures or labelled
  illustration (keep the two caption strings verbatim in substance).
- Delete: `static/screenshots/world-cyberpunk.png` (and its unused import), `.neon-*` art direction.
  `world-dusk.png`/`world-walk.png` in `static/screenshots/`: do not promote as a website "theme" —
  Dusk may appear only as a labelled Desktop capture inside a proof frame if a page needs it.
- New art allowed only if generated by the PXL pipeline (`PIXEL_RENAISSANCE.md:37-53`,
  `gen-world-assets-pxl.mjs`) or the existing valley illustration family; no stock, no AI-neon,
  no copied game art (`DESIGN.md §7` licensing). Any new destination icon = PXL landmark sprite at
  integer scale, with a text signpost adjacent (icon never alone).
- Every `<img>`: descriptive `alt` for captures, `alt="" aria-hidden` for pure landscape layers
  (current `WorldJourney.astro:82-89` pattern — keep). Lazy-load below-fold scenes (current
  deferred `data-scene-src` pattern — keep).

## 10. Page-by-page change list for Agent D

Ordered by priority. File paths are the edit targets; do not add routes or webfonts.

### 10.1 `/` — `apps/web/src/pages/index.astro` + `WorldJourney.astro`

1. **Delete** the neon hero sign (`index.astro:60-64`, `.hero-sign--neon` CSS). The valley sign
   (`:56-59`) becomes a §2.3 signpost below the frame on mobile, overlapping bottom-left on ≥1024.
2. Hero on Meadow (§2.1): cream sky, grass band, Display-1 headline (same copy — it is good),
   primary CTA → Waystation `/download/` labelled "Download Desktop", secondary → Trailhead
   `/start/`, tertiary link (Plex, not button) → "Walk the Project District" `/world/`.
   Keep the honesty caption; restyle as signpost caption (§4.3-3) *inside* the frame bottom bar.
   Keep footnote "No pretend workers…" verbatim in substance.
3. Quote strip (`:69-71`): Silkscreen strip becomes a dirt-path divider with a Plex Sans 600
   uppercase line; no pixel type at strip size.
4. Journey: apply §6.2 (no progress bar, counter instead), §8 motion, signpost labels per §5
   (The workspace→"The Valley", Inside a project→"Project District", People→"Guild Hall",
   Operations→"Operations Hall", Library→"Library"; keep `id`/`data-scene` values unchanged so
   `site.spec.ts` journey tests stay valid, or update tests in the same PR).
5. Semantic list (`:87-134`): replace six abstract terms with §5 destination cards (signpost +
   Plex title + one-line truth + route link). This is the homepage destination index; every card links.
6. Closing banner: grass-4 band (§3.2), Town Square cross-link added (`/community/`).

### 10.2 `/world/` — `apps/web/src/pages/world.astro`

1. **Delete** the entire Cyberpunk section (`:127-159`), the unused `cyberpunk` import (`:5`),
   and closing copy "or the neon city" (`:163`). Closing banner becomes valley-only.
2. Landmarks grid (`:45-93`): rename to §5 signposts — PROJECT HOUSES→"Project District",
   LIBRARY→"Library", ARCHIVE→"Library · Archive annex" is wrong: Archive/Memory has **no web
   route**; render it as a place described on this page with link to `/docs/world/` (the semantic
   world guide), never as a fake destination. OPERATIONS→"Operations Hall" → `/swarms/`,
   TERMINAL STATION + WORKSHOP merge → "Workshop" → `/docs/cli/`.
3. Page-hero keeps the real `world.png` capture + caption; add a Dusk capture only if labelled
   as a Desktop appearance, inside a proof frame (see §9).

### 10.3 `global.css` — `apps/web/src/styles/global.css` (the big one)

1. Replace `:root` tokens (§3.1); delete `--night*`, `--pine*`, `--river*` names or alias them
   for one PR with a comment pointing here (prefer clean replace; the file is the only consumer).
2. Type: §4 everywhere (`h1/h2`, `.journey-stop h3`, `.quote-strip`, kickers, `.result-count`,
   `.capability-kind`, `.definition b`, `.community-links strong` — the last four become Plex 600
   small caps unless rendered as signposts).
3. Delete: `.hero-sign--neon`, `.section--neon`, `.neon-sign`, `.neon-card*`, `@keyframes twinkle`,
   `.journey-stage::after` firefly + `@keyframes journey-firefly`, `.pixel-frame` clip-path.
4. Breakpoints: implement §7 (390 base, 768, 1024, 1440 caps, 1920 margin rule); retire 900px
   breakpoint by folding its rules into 768/1024.
5. `color-scheme: light`; selection = `--gold-1` bg + `--ink-1` text; focus = §3.2.

### 10.4 Header / Footer / Layout

- `SiteHeader.astro`: §5 order/labels; nav links Plex Sans 500 0.92rem `--ink-1`, current =
  `--terra-3` underline 2px offset 6px (not cream-on-dark); header surface = `--cream-0` with
  2px `--dirt-1` bottom path edge; Download button = §3.2 primary. Mobile `<details>` panel on
  `--cream-0`, links ≥44px. Brand mark unchanged (pixel landmark, `pixelated`).
- `SiteFooter.astro`: Dusk valley floor (§2.1), footer nav gains Chronicles `/changelog/` and
  Town Square `/community/`; tagline unchanged. `SiteLayout.astro`: `theme-color #ffeec4`,
  fonts unchanged (do **not** add Silkscreen 700 — signage is 400 only).

### 10.5 Focused pages (retokenize + destination framing; copy largely stays)

| Page | Changes |
| --- | --- |
| `/start/` (`start.astro`) | Becomes **Trailhead**: signpost eyebrow, steps numbered with stone markers (Plex Mono numerals), each step's action link labelled with its destination signpost name. Definition rail (§4 type). No other structural change — the 12 steps are truthful, keep. |
| `/people/` (`people.astro`) | **Guild Hall** framing; captions stay; definition rail retyped; "LIVE SESSION" caption (signage) must keep the words "actual project · actual process" adjacent — presence honesty is the page's job. |
| `/swarms/` (`swarms.astro`) | **Operations Hall** framing; six-step semantic list retyped to §4 (number chips Plex Mono on stone, not Silkscreen); keep "A headless record is never presented as a live agent" line. |
| `/capabilities/` (`capabilities/index.astro`) | **Library**: search + generated count are real — keep both, retype count to Plex Mono; kind chips become stone/ink signage-style labels (§4.3-adjacent, Plex 600 — chips are UI, not signs); group h2s Display-3. |
| `/download/` (`download.astro`) | **Waystation**: release status/asset logic untouched (it is the site's model truth pattern: loading → ready/error, GitHub fallback, `<noscript>` — keep all); retype, platform tabs = Plex 600 with `--gold-1` current state; add Chronicles cross-link. |
| `/docs/` + `/docs/[slug]` (`docs-nav.mjs`) | **Library reading room / Field Guide**: cream prose (`.prose` retokenized, code stays dark §3.3); sidebar group headings → destination names only where the group truly maps (§6.1-3), otherwise keep current group names — do not rename "Trust and build". `docs-nav.mjs` data itself needs **no change** for this spec. |
| `/community/` (`community.astro`) | **Town Square**: link cards become plaster cards with wood signpost titles; external-link arrows kept. |
| `/changelog/` (`changelog.astro`) | **Chronicles**: page-hero retype only; rendered canonical changelog untouched. |
| `/404.astro` | Trail signpost ("THIS TRAIL ENDS HERE" as §4.3-6 sign), three existing links retyped; keep `noIndex`. |

### 10.6 Out of scope for Agent D (do not do)

No new routes, no theme toggle, no live data fetching beyond the existing `/download/` release
lookup, no analytics/metrics, no avatar/walk interaction on the website, no Desktop changes,
no new screenshots (reuse §9 inventory), no font additions/removals in `package.json`.

## 11. Acceptance & QA (extends `VISUAL_QA.md`, does not replace it)

From `apps/web/`: `pnpm check && pnpm lint && pnpm test && pnpm build && pnpm format:check`
plus `ATK_WEB_CAPTURE=1 pnpm test:visual` (existing commands, `VISUAL_QA.md:38-45`).

New/updated checks (add to `apps/web/tests/site.spec.ts`, keep all 11 existing tests' intent):

1. No page contains "Cyberpunk" (text or class) — assert on `/` and `/world/` HTML.
2. Computed `font-family` of `h1`/`h2` on `/`, `/world/`, `/people/` does not contain Silkscreen;
   at least one signpost element per destination page does.
3. Contrast: axe (existing serious/critical gate) on all primary routes incl. new cream surfaces
   at 390/768/1024/1440/1920; manually verify §3.2 pairs with a contrast checker and record
   numbers in `VISUAL_QA.md` (do not copy this spec's numbers as results).
4. Screenshots for human review at 390×844, 768×1024, 1024×768, 1440×900, 1920×1080 for `/`
   (hero + one journey stop) and `/world/`; reviewer checks: signs readable, no cropped captions,
   no horizontal scroll, sticky stage behaves per §7, content column capped at 1920.
5. Reduced-motion + no-JS journey tests pass unchanged; keyboard-only pass: header → journey
   route nav → stop links in order, visible focus at every stop.
6. Truth audit: grep the built site for session/metric claims — only `/capabilities/` build
   count and `/download/` live release data may present numbers as current state.

**Definition of done:** P0-1…P0-3 closed, §5 map visible in header + homepage index, §7 widths
reviewed with captures, `VISUAL_QA.md` updated with the new evidence (dated, with the capture
filenames), and the 11-test floor green. If a §3.2 contrast pair fails in real QA, adjust the
token within the `palette.px.js` ramp — never by adding a new hue.
