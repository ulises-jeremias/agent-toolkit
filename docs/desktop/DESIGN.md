# Agent Toolkit Desktop Design Contract

**Status: CURRENT CONTRACT** — governing visual and interaction design
direction for Agent Toolkit Desktop. **Visual reset adopted 2026-09-30**
([ADR-035](../adrs/ADR-035-cozy-pixel-world.md)): the **Cozy Pixel World**
language is the single visual contract. The previous Paper Co. language is
deprecated and survives only in git history.

This document defines how Agent Toolkit Desktop should look, feel, and present
information. It complements [PRODUCT_VISION.md](PRODUCT_VISION.md),
[UX_ARCHITECTURE.md](UX_ARCHITECTURE.md), [USER_JOURNEYS.md](USER_JOURNEYS.md),
[workflows.yaml](workflows.yaml), [VISUAL_QA.md](VISUAL_QA.md), and
[SEMANTIC_WORLD.md](SEMANTIC_WORLD.md). It is not an executable token file and
it does not override Engine truth, accessibility, or platform constraints.

The goal is simple:

> A real developer workstation presented as a **beautiful, cozy top-down
> pixel world**. The world is the screen. The menus feel like the world.
> Nothing on screen lies.

## 0. North Star

Agent Toolkit Desktop should feel like opening a polished classic top-down
pixel game — and then discovering it is an extremely capable developer
workstation. Broad mood references: lush 16/32-bit top-down villages and
valleys (SNES/GBA era readability), cozy simulation-game warmth, classic JRPG
menu character. These are **mood references only**: never copy copyrighted
assets, maps, characters, or UI.

Target qualities: cozy, colorful, lush, playful, handcrafted, nostalgic, warm,
slightly magical, calm, alive, extremely readable.

Reject: corporate chrome, editorial beige SaaS, glassmorphism, Material UI,
generic AI dashboards, modern rounded-card webapps, faux paper/ledger/filing
aesthetics, office-themed identity, pixel stickers on generic panels.

The **Cozy Pixel World** contract has three inseparable halves:

1. **The world is the screen.** `/world` is the home and reads immediately as
   a real top-down pixel world: terrain, paths, water, trees, lamps, and
   project buildings composed like a game map — not a dashboard with pixel
   decoration. Chrome is minimal; the world dominates the window.
2. **The UI belongs to the world.** Menus, inspectors, dialogs, tables and
   the shell use one classic game-menu system: deep framed panels, hard
   borders, square pixel-cut corners, flat colors, hard shadows, compact
   status chips, pixel display type for titles, readable sans for dense data.
3. **Nothing lies.** Every place, object, and character is a projection of
   real domain state. Ambient life (water, leaves, fireflies, birds,
   butterflies, glowing windows) is environmental atmosphere and never
   implies agent activity. See [SEMANTIC_WORLD.md](SEMANTIC_WORLD.md) and
   [ADR-034](../adrs/ADR-034-semantic-world.md).

Ask of any visible change:

- Would this look at home in an indie pixel-game showcase?
- Would a developer still find it efficient after eight hours?
- Is it coherent with the rest of the world (one art direction)?
- Does it still read like a generic dashboard? Then it is not done.

## 1. Design hierarchy

When design goals conflict, use this order:

> **Clarity → Control → Feedback → Discoverability → Personality → Decoration**

Personality is important. It never outranks understanding, safety, input
focus, or operational truth.

### Core principles

- **World first.** The map explains the product; menus and inspectors do the
  work. Neither half ships without the other matching its quality bar.
- **Truth before animation.** Visual activity represents real catalog,
  configuration, runtime, or evidence state. Empty and calm are valid.
- **Conventional interaction, distinctive presentation.** Direct navigation,
  command palette, keyboard, and real terminal stay mandatory. No walking
  required to be productive.
- **Handcrafted coherence.** One art direction, one light direction, one
  pixel grid, one menu system. No stylistic soup.
- **Calm density.** Dense developer information inside compact, readable
  game-menu panels. No giant rounded cards, no billboard whitespace.
- **Gentle magic.** Lanterns, glowing windows, fireflies, rune-like tech
  accents are atmosphere. This is not a fantasy RPG; there is no invented
  lore, no XP, no quests.
- **Standalone identity.** The design carries a subtle Hornero/nature
  signature (a bird, warm South-American valley light) but never depends on
  sibling repositories.

## 2. Identity: the valley

The home is a small valley settlement. Each real project is a building with a
readable silhouette; shared concepts are distinct landmarks (hall, library,
records house, workshop, terminal station, depot, notice post). Paths, a
creek, bridges, trees, flowers, lamps and signs compose the settlement like a
game map. At idle the world stays alive through harmless ambient life —
water, leaves, fireflies, a hornero bird — and stays honest: no idle world
ever invents workers.

### Hornero signature

The hornero (the South-American ovenbird that builds clay houses) is the
quiet signature of the product: a small bird occasionally perched near the
hall, a nest motif on the workspace hall, warm valley light. It is a
signature, not a mascot crowd, and never an agent character. Do not rename
Agent Toolkit; do not plaster logos across the UI.

## 3. What the product must not become

- generic AI SaaS or purple/indigo AI gradients;
- glassmorphism, card soup, giant rounded cards, billboard whitespace;
- a VS Code clone or generic admin dashboard;
- the deprecated Paper Co. language (paper/manila/ledger/fraunces/editorial);
- a medieval fantasy RPG, wizard simulator, dungeon crawler, or MMORPG;
- fake gamification: XP, levels, achievements, quests, loot;
- decorative fake workers; "thinking"/"coding" states without runtime
  evidence;
- arbitrary pixel-art stickers on otherwise generic UI;
- meaningless ambient motion, or ambient motion that reads as agent activity;
- heavy skeuomorphism that hides basic actions;
- pixel fonts for body text, dense tables, or terminal;
- status communicated only by color;
- fabricated activity, progress, health, compatibility, cost, receipt, or
  provenance.

## 4. Visual truth model

Beautiful lies are worse than boring truth. The UI distinguishes four kinds of
truth:

1. **Catalog truth** — what Agent Toolkit actually provides or supports.
2. **Configuration truth** — what this user/workspace has actually enabled.
3. **Runtime truth** — what is happening right now.
4. **Evidence truth** — what receipts, provenance, and measurements prove.

A landmark may exist while its concept is empty; runtime emptiness never means
the catalog is empty; ambient environment motion never implies runtime
activity. The world truth rules in
[SEMANTIC_WORLD.md §9](SEMANTIC_WORLD.md) are binding.

## 5. Themes and color

Executable tokens (`apps/desktop/src/design/tokens.css`) are the value
authority; this section defines intent. Two appearances, one world.

- **Meadow** (`data-theme='meadow'`, default) — bright valley daylight:
  lush greens, warm dirt, clear water, colorful roofs. Menus are deep
  indigo-spruce with ivory text and gold/teal accents.
- **Dusk** (`data-theme='dusk'`) — deliberate dark evening: deeper grass,
  navy creek, glowing windows and lanterns. Not a mechanical inversion.
- **System** — resolves to Meadow or Dusk from `prefers-color-scheme`.

### Palette (directional anchors; code tokens are canonical)

| Group | Roles | Anchor hexes |
|---|---|---|
| Meadow grass | base / dark / light / tuft | `#5FB454` `#4E9C43` `#72C264` `#8AD478` |
| Foliage | tree / deep / highlight | `#3E7D3A` `#2F6230` `#58A34E` |
| Earth | dirt / edge / sand | `#C9A066` `#A87F4C` `#E7D7A8` |
| Stone | slab / dark / pebble | `#9AA0A8` `#767C85` `#C6CBCF` |
| Water | deep / mid / light / foam | `#2E7FA3` `#3FA7D6` `#7CD0EC` `#E3F6FC` |
| Wood | beam / plank / dark | `#8A5A32` `#B07B4A` `#5E3D22` |
| Plaster / brick | wall / brick | `#F2E6C9` `#B5654A` |
| Roofs | terracotta / slate / teal / rust / moss / straw | `#C65D3B` `#4E6E8E` `#3E8E8A` `#A63D2F` `#5E8C4A` `#D9A648` |
| Magic & tech glow | cyan / lavender / gold / emerald | `#5FE3D0` `#B7A6F0` `#FFD97A` `#4ED49A` |
| Flowers | poppy / daisy / lavender | `#E4574C` `#F2EFE3` `#B7A6F0` |
| Menu (Meadow) | panel / raised / sunken | `#262B45` `#2F3552` `#1D2136` |
| Menu (Dusk) | panel / raised / sunken | `#1B1E30` `#232742` `#141624` |
| Menu text | primary / muted | `#F3EDDA` `#B9B4CE` |
| Accents | gold / teal / rose | `#F0BD5E` `#5FD3C6` `#E46A5C` |
| Status | ok / warn / err / info / idle | `#58C98B` `#F2C14E` `#E4574C` `#5AB0F2` `#9A93A8` |

Status always pairs color with text and/or shape; see §11. The palette must
stay colorful — a washed-out beige world is a regression by definition.

## 6. Typography

Three roles, no more:

| Role | Family | Use |
|---|---|---|
| **Display** | Silkscreen (OFL, 400/700) — bundled via `@fontsource/silkscreen` | Destination titles, panel titles, buttons, HUD labels, world plaques, numeric chips. Integer pixel sizes (8–16px equivalents). |
| **UI body** | IBM Plex Sans (400/500/600) | Dense tables, forms, paragraphs, descriptions. Never pixelated. |
| **Mono** | IBM Plex Mono (400/500) | Terminal, logs, commands, paths, IDs, hashes. |

Fraunces and editorial serif hierarchy are retired with Paper Co. Pixel type
is a display voice: it never replaces readable body text, dense tables, or
terminal output.

## 7. Pixel-art grammar

All world art shares one craft system. The generator
(`apps/desktop/scripts/gen-world-assets.mjs`) and the theme packs are the
executable form of these rules.

### Grid and rendering

- **Source grid: 16×16 px per tile.** All terrain tiles, decor and entity
  sprites are authored at integer multiples of 16 px source.
- **Integer display scaling only:** zoom steps 2×/3×/4× (32/48/64 CSS px per
  tile). Fit-to-world picks the largest integer zoom that fits; never render
  fractional zoom.
- `image-rendering: pixelated` everywhere; integer world-pixel coordinates;
  no anti-aliased sprite scaling; no CSS gradients inside world assets; no
  blurred shadows.
- Terrain renders to a single canvas (nearest-neighbor, no smoothing);
  entities and ambient sprites are positioned DOM elements sharing the same
  world-pixel geometry so hit-testing and drawing never diverge.
- The camera pans (drag / arrows) and zooms (buttons / wheel steps) in whole
  pixels; Home resets to fit; focusing an entity centers it.

### Craft rules

- One light direction (top-left); contact shadows fall bottom-right as hard
  offset pixels, never blurred.
- Consistent 1-px darker outline treatment on silhouettes; limited ramps
  (≤5 steps per material); no stray hues outside the palette ramps.
- Consistent top-down projection: ground-plane objects sit on tile feet;
  buildings are roof-first readable with visible doors on the south face.
- Animated sprites use 2-frame strips with `steps()` timing; water and glow
  cycle slowly. Motion respects reduced motion (freeze, not remove) and
  pauses when the document is hidden.
- Never mix asset resolutions, vector icons, or foreign sprite packs into
  the world.

### Asset classes

- **Terrain** — grass variants, dirt road, plaza stone, sand, water
  (2-frame), shore foam, bridge planks.
- **Nature/decor** — trees (round, pine), bushes, flowers, rocks, reeds,
  fences, lamps, signs, stumps, mushrooms, lily pads, garden plots, nest.
- **Buildings** — workspace hall, records house (memory), library, workshop
  (operations), terminal station, depot (files), notice post (attention),
  settings post; project houses in one family with 6 variants: cottage,
  studio, workshop, tower, cabin, brick.
- **Furniture (interiors)** — plank floor, walls, door mat, rug, plant,
  terminal desk (glowing screen), bookshelf, memory cabinet, tools bench,
  map board, crates.
- **Characters** — small readable apprentice figures for proven runtime rows
  only: working (2-frame tool bob), blocked (red marker bubble), idle (only
  when a runtime row exists). Satchel/hat variants by stable hash.
- **Ambient life** — butterflies, fireflies (dusk), water shimmer, the
  hornero bird. Always small, always clearly environmental, never clickable
  as if they were agents.

### Asset licensing

Production artwork is **original and generated in-repo**
(`apps/desktop/scripts/gen-world-assets.mjs`) or appropriately licensed with
recorded attribution. Never import copyrighted assets from Zelda, Pokémon,
Stardew Valley, Animal Crossing, Earthbound, Munder Difflin, Agent Office, or
Pixel Agents.

## 8. Application shell

The shell is a minimal game HUD, not a dashboard frame:

- **Top HUD bar** (single slim row): hornero mark + product name; chunky
  destination buttons (World first); live connection lamp; workspace chip;
  command-palette affordance (Ctrl/Cmd+K).
- **Context strip**: session context (workspace / agent / run) as compact
  fields — a real productivity rail, kept slim.
- **Terminal dock**: persistent xterm host below content; dark, crisp,
  pixel-framed tabs; unchanged real PTY behavior.
- **Content surface**: `/world` fills it edge-to-edge (world is the screen);
  inspectors compose it with game-menu panels.

Pixel art decorates and contextualizes the shell but never replaces standard
affordances: buttons, tabs, fields, tables, scrollbars, selection, focus,
resize handles.

Primary destinations (unchanged; see
[UX_ARCHITECTURE.md](UX_ARCHITECTURE.md)): World (home), Office (attention),
Library, Operations, Workspace, Insights, Terminal, Settings.

## 9. World and Office

**World** is the flagship spatial surface and the home
([ADR-034](../adrs/ADR-034-semantic-world.md)): it must answer at a glance,
without forcing a walk — which workspace is active, which projects exist,
whether shared memory/knowledge exists, which jobs have characters (proven
only), and how to reach terminal, workspace, library, or operations in one
click or via Ctrl/Cmd+K.

**Office** is the attention inspector: failures, blocked work, self-check
problems, backend down — a game-menu board, not a second home.

The composition contract for the world map:

- deterministic layout from sorted real inputs (same input → same map);
- composed like a game world: plaza and hall, landmark ring or lane, winding
  roads, a creek with bridges, forest edges, gardens, scattered flowers and
  lamps;
- scales from 1 to 20+ projects without becoming an empty void or a parking
  lot — map size buckets, district lanes, never random scatter;
- tooltips show name, concept, state, and the action; clicks open the
  existing destination via `href()`; a structured list mirrors everything.

## 10. Screen-specific design intent

### Onboarding

A warm welcome sign at the edge of the valley, in the same pixel menu
language. Explain the next choice before technical vocabulary. Ends naturally
in the world. No invented agents, no fake liveliness.

### World

The most expressive surface. Authored sprites, composed terrain, ambient
life, semantic labels. The structured list remains one gesture away.

### Office

Attention board in the game-menu system: failures first, each with a link to
the subject. Dense, calm, honest.

### Library

A cozy catalog room: shelf-toned framing, search/filter/compatibility truth.
No invented install counts, ratings, or marketplace badges — absence stays
honest absence.

### Operations

The workshop board: real job table (status, command, started, duration,
exit), loops, swarms, doctor. Selected row reads clearly; progress only when
measured — never decorative bars.

Loop templates must be added to the active workspace before they can run. The
add dialog previews the destination and refuses overwrites; Run once starts a
real backend job. The report shows definition budgets, run history, audit and
cost evidence, including an explicit unavailable state when accounting is not
recorded. [Loop report screenshots](assets/electron/loops/) show the compact,
large and completed-run states.

### Workspace

The most technical destination: files, project context, git state when
available, memory/context. Still inside the menu system; environmental detail
recedes.

### Insights

Editorial-analytical in menu dress: conventional labeled charts, evidence-
backed numbers, honest emptiness.

### Settings

Calm and utilitarian game-menu forms. Theme previews may show the world;
ordinary preferences stay plain.

### Terminal

Flagship surface; intentional contrast: dark screen, highly legible mono
text, restrained accent, obvious focus, real PTY behavior. No fake CRT, no
scanlines, no pixelated terminal text.

## 11. Components and material

Shared primitives live in `apps/desktop/src/ui/` (see
[ELECTRON_DESIGN_SYSTEM.md](ELECTRON_DESIGN_SYSTEM.md)); do not build a
speculative widget framework. The game-menu material:

- **Panel** — deep menu surface, 2px solid border, pixel-cut corners
  (2px notches), hard offset shadow (`3px 3px 0`), compact padding.
- **Section header** — Silkscreen title with a gold tick; short muted
  description in body font.
- **Buttons** — chunky chips: 2px border, hard shadow, pressed-state offset;
  `primary` (gold), `secondary`, `ghost`, `danger` (rose).
- **Chips / status** — compact square chips; status combines color, shape and
  lowercase status text (the backend's words).
- **Tables** — dense rows, hairline rules, hover lift, selected row marker;
  headers in small Silkscreen caps.
- **Fields** — flat sunken wells, visible focus ring (gold), mono variant
  for commands/paths.

Component states remain: `default · hover · focused · pressed · selected ·
disabled · loading · success · warning · error`. Status is never color alone.

## 12. Spacing and geometry

4px rhythm (`--space-*`); `--target-min` ≥ 32px (WCAG 2.2 minimum is 24px).
One computed geometry drives drawing, hover, hit testing, focus, and tooltips
in both the world renderer and the menu system. Pixel alignment never
justifies tiny targets. Content max width for dense destinations
(`--page-max`); the world ignores it — the world is the screen.

## 13. Iconography

Three classes, kept distinct:

1. **Functional glyphs** — chevrons, close, search, filter: simple authored
   pixel glyphs in the display voice; never emoji.
2. **Product/domain sprites** — semantic theme keys via theme packs (world
   places/objects/characters).
3. **Environmental sprites** — nature, furniture, ambient life.

A destructive action remains unmistakably destructive inside the pixel theme.

## 14. Motion

Motion communicates or delights honestly:

- **State motion** — real transitions: a job character appearing/working/
  blocked, a lamp change, a receipt arriving.
- **Ambient motion** — water, glows, leaves, fireflies, butterflies, the
  hornero. Slow, subtle, clearly environmental. Never implies work.
- **Interaction motion** — short panel/drawer transitions, pressed buttons,
  focus ring. Fast (≤200ms) or none.

Forbidden: random walking agents, busy loops without matching backend state,
permanent pulsing, decorative motion because a screen feels quiet.
`prefers-reduced-motion` and Settings "Reduced" freeze non-essential motion;
state updates still apply instantly. Ambient animation pauses on
`document.hidden`.

## 15. Responsive behavior

The world must feel right from 1024×640 to 2560×1440 (see
[VISUAL_QA.md](VISUAL_QA.md)):

- the camera fits or pans; HUD compresses to icons+labels; context strip
  wraps;
- inspectors reflow to drawers/tabs; dense tables scroll; primary actions
  never clip; text never shrinks to illegibility;
- integer zoom only — never fractional scaling that blurs pixel art;
- test 100/125/150/200% scaling; pixel assets stay crisp.

## 16. Accessibility and localization

- visible gold focus ring; full keyboard operation (world included: list
  fallback, focusable entities, Enter activates, arrows pan, Escape backs
  out);
- contrast meets theVISUAL_QA gate in both Meadow and Dusk; status is
  color + text/shape;
- reduced motion freezes ambient animation;
- long translations and RTL geometry-checked in the menu system;
- important information never exists only in environmental signage;
- do not claim unverified assistive-tech or WCAG conformance; follow
  [VISUAL_QA.md](VISUAL_QA.md).

## 17. Content and voice

Calm, capable, builder-oriented, warm, concise. Direct action language;
consequences before internals; human task vocabulary before CLI vocabulary;
lightly playful copy only in low-risk spaces. No corporate AI hype, no fake
enthusiasm, no RPG vocabulary, no constant bird jokes. Errors and destructive
actions stay direct and precise.

## 18. Design references

The historical concept boards in `assets/design/` (Paper Co. era) are
**deprecated visual references** kept for provenance only; they hold no
authority. The current references are:

- this document and [SEMANTIC_WORLD.md](SEMANTIC_WORLD.md);
- the executable system: `src/design/tokens.css`,
  `src/features/world/theme/`, `public/world/` + its generator;
- reviewed screenshots in `assets/electron/foundations/` (Meadow/Dusk matrix).

## 19. Validation

Major visual changes follow:

> build → run → navigate → capture → **open the screenshot** → critique →
> fix → recapture

Goldens answer "did pixels change?". Design review answers "are these the
right pixels?". Both matter; do not update goldens to hide a regression.
Review against this document, [PRODUCT_VISION.md](PRODUCT_VISION.md),
[UX_ARCHITECTURE.md](UX_ARCHITECTURE.md), [VISUAL_QA.md](VISUAL_QA.md), the
executable tokens, and the actual running app at multiple sizes.

## 20. Change policy

Update this document when changing a durable visual rule: theme philosophy;
palette; typography roles; pixel-art grid/rendering rules; shell presentation;
world/interior spatial philosophy (also update
[SEMANTIC_WORLD.md](SEMANTIC_WORLD.md) / ADR-034/035); component grammar;
motion philosophy; asset taxonomy/licensing. Not for one bug fix or a local
spacing correction. Architecturally significant technical decisions still
require ADRs.
