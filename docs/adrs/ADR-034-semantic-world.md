# ADR-034 — Desktop: Semantic spatial world as primary home

- **Status:** Accepted (2026-09-30) — branch `feat/semantic-world`
- **Deciders:** ulises-jeremias (owner); architecture authority for Desktop spatial UX
- **Amends:** ADR-033 (Electron presentation)
- **Amended by:** [ADR-035](ADR-035-cozy-pixel-world.md) (visual language:
  Cozy Pixel World replaces the Paper Co. policy referenced below; semantic
  pipeline and truth rules here remain binding)
- **Supersedes (spatial presentation):** Office-as-default-home; historical
  Workshop vector world in [WORLD_VIEW.md](../desktop/WORLD_VIEW.md) as
  production authority (motion/truth contracts from that doc remain binding)
- **Companion:** [SEMANTIC_WORLD.md](../desktop/SEMANTIC_WORLD.md)

## Context

Agent Toolkit Desktop already has a professional Paper Co. shell
(destinations, command palette, terminal dock, inspectors) over
`agent-toolkit serve`. The prior spatial metaphor (Office floor / Workshop)
either stayed dashboard-first or risked decorative game UI. The product need
is a **semantic spatial world**: every place, object, and character maps to a
real Agent Toolkit concept, while inspectors and keyboard remain the fast path.

Constraints from governing docs and this track:

- Domain truth stays in V; React is not a second backend.
- Canonical runtime row is `Agent + Run + Session + Job` — no TypeScript `Worker`.
- No fake NPCs, fake activity, or copied Stardew/Zelda/Munder/Agent Office art.
- Empty/calm world is valid; critical state is not color/motion-only.
- Never slow real execution for animation.

## Options

### 1. Keep Office dashboard as home; Floor Map optional decoration

- Pros: lowest churn with in-flight Office PR.
- Cons: spatial metaphor never becomes the product explanation; world stays a
  side panel people ignore.
- Rejected: maintainer made the semantic world the primary product goal.

### 2. Full game engine (Phaser / Pixi) as the app shell

- Pros: rich sprites, camera, tilemaps.
- Cons: large dependency surface, easy to invent game loops that fight React
  inspectors and Electron power budgets; high risk of "game before tool".
- Rejected for v1: overkill for a truthful tile/sprite map inside an existing
  React shell.

### 3. Pure Canvas/WebGL world replacing destinations

- Pros: one draw surface.
- Cons: re-fights accessibility, text, dialogs, xterm; contradicts ADR-033's
  reason for Electron.
- Rejected: inspectors, palette, and terminal must stay first-class React.

### 4. Hybrid semantic world (chosen)

- Semantic model + deterministic layout + theme pack + small renderer.
- Default home is `/world` (also `/`).
- Other destinations remain reachable (nav, palette, place click →
  `href()`), acting as inspectors/workstations opened from places — not
  competing homes.
- Renderer for the vertical slice: **DOM/CSS tile + sprite layer** (nearest-
  neighbor pixel art) with a structured list fallback. Canvas/Pixi may be
  added later behind the same theme contract if profiling demands it; they
  are not required to ship truth.

## Decision

1. **Pipeline (hard):**
   `DOMAIN STATE → SEMANTIC WORLD MODEL → LAYOUT → THEME/ASSET PACK → RENDERER`
2. **Vocabulary and theme keys** live in
   [SEMANTIC_WORLD.md](../desktop/SEMANTIC_WORLD.md). Features never hardcode
   cottage asset filenames; they resolve semantic keys through a theme pack.
3. **World is the default home.** Route `/world`; `/` redirects there.
   Office remains an attention inspector destination until journeys prove
   otherwise — it is no longer the product home.
4. **Characters** appear only for proven runtime rows (jobs / swarm runs /
   sessions with real backend evidence). Catalog agents may appear as places
   or objects, not as wandering NPCs.
5. **World events** map only existing `GET /api/v1/events` kinds
   (`backend.*`, `job.*`, `loop.*`, `swarm.changed`, `memory.changed`,
   `install.*`). Unknown or idle states render honestly — never invent
   `agent.thinking`.
6. **Performance:** no runaway `requestAnimationFrame`; pause when the
   document is hidden; honor `prefers-reduced-motion` and Settings Reduced.
7. **Extension points** for unavailable capabilities are labeled unavailable
   (or omitted), never filled with fake rooms of data.

## Consequences

- Other Desktop feature agents align to the vocabulary and theme contract
  before inventing rooms, sprites, or worker types.
- Office / Operations / Library / Terminal PRs keep delivering inspectors;
  World composes them via navigation, not by rewriting those surfaces.
- A second theme (cyberpunk, space, …) is an architecture slot only — ship
  one excellent cozy top-down default now.
- Typed project list names are still CLI-envelope text today; the model may
  use a tested transitional parser of that known format until V returns
  structured project rows. That parser is not a second backend.

## References

- [SEMANTIC_WORLD.md](../desktop/SEMANTIC_WORLD.md)
- [DESIGN.md](../desktop/DESIGN.md)
- [WORKSTATION_REFERENCE_ANALYSIS.md](../desktop/WORKSTATION_REFERENCE_ANALYSIS.md)
- [ADR-033](ADR-033-electron-desktop.md)
- OpenAPI `ApiEvent` kinds on `GET /api/v1/events`
