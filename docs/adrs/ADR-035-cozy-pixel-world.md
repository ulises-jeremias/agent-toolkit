# ADR-035 — Desktop visual reset: Cozy Pixel World replaces Paper Co.

- **Status:** Accepted (2026-09-30) — branch `feat/cozy-pixel-world`
- **Deciders:** ulises-jeremias (owner)
- **Amends:** ADR-034 (semantic world), DESIGN.md (visual contract),
  PRODUCT_VISION.md (identity section), ELECTRON_DESIGN_SYSTEM.md (tokens,
  typography, chrome)
- **Supersedes (visual authority only):** the Paper Co. design language
  (paper/manila/brass/Fraunces/editorial filing-cabinet chrome) and all
  documents that declared it binding. Those documents are updated in the
  same change; git history preserves them.
- **Does not change:** ADR-027/028/030 (V backend authority, security,
  binary-first), ADR-033 (Electron presentation), ADR-034 (semantic world
  pipeline, truth rules), the domain model, routes, or any product capability.

## Context

The semantic world (ADR-034) landed on top of the Paper Co. design language:
paper-cream canvases, manila folder panels, Fraunces editorial typography,
brass accents, filing/ledger motifs. Reviewing the running product, the
combination reads as **a dashboard decorated with pixel art**, not a world.
The world sits inside a manila card; the inspectors look like an unrelated
editorial SaaS tool; the buildings were CSS-drawn placeholders.

Owner decision (2026-09-30): the Paper Co. visual direction is deprecated.
The product should present as **a beautiful, cozy top-down pixel world that
happens to be an extremely capable developer workstation** — closer in mood
to a polished 16/32-bit top-down game world than to a productivity dashboard,
while keeping every truth, accessibility, and capability contract.

### What is deprecated (visual language only)

- Paper Co. as a named design language and any instruction to preserve it.
- Paper/manila/ledger/filing-cabinet aesthetics; warm editorial SaaS chrome.
- Fraunces-led editorial typography.
- Stamps, receipts-as-identity, filing tabs as product identity.
- The historical concept boards under `docs/desktop/assets/design/` as
  visual authority (they remain in git history as references).

### What survives untouched (product contracts)

- Truth before animation; no fabricated activity, agents, metrics, or
  progress. Idle worlds stay calm; characters exist only for proven runtime
  rows (ADR-034 remains binding).
- Semantic world pipeline: `DOMAIN STATE → SEMANTIC MODEL → LAYOUT → THEME
  PACK → RENDERER`.
- V = domain authority; React renders envelopes (ADR-033).
- Accessibility, keyboard-first operation, reduced motion, non-color status,
  list fallbacks for every spatial entity.
- Real PTY terminal (xterm.js + node-pty), command palette, direct
  navigation — this is a workstation, not a game controller.
- Destinations and routes; inspectors keep doing dense professional work.
- Original or appropriately-licensed art only. No copyrighted game assets,
  maps, characters, or UI from Zelda / Pokémon / Stardew Valley / Animal
  Crossing / Earthbound / Munder Difflin / Agent Office / Pixel Agents.

## Decision

1. **One visual contract: Cozy Pixel World.**
   The world is the screen. `/world` reads primarily as a real top-down
   pixel world that visually dominates the home experience; chrome is
   minimal; the world itself is the primary information architecture.
2. **The UI belongs to the same world.** Inspectors, dialogs, tables and
   the shell use one game-menu system — deep framed panels, hard borders,
   square corners, compact chips — not unrelated web cards.
3. **Executable contract:** `apps/desktop/src/design/tokens.css` (palette,
   typography, geometry), `apps/desktop/src/features/world/theme/` (semantic
   theme packs), and `apps/desktop/public/world/` (original generated pixel
   assets, see `apps/desktop/scripts/gen-world-assets.mjs`) are the value
   authorities. DESIGN.md defines intent and semantic use.
4. **Renderer:** keep the DOM tile/sprite renderer of ADR-034 with an
   integer-scaled camera and a canvas terrain layer. No game engine
   (Phaser/Pixi) is introduced; no evidence justifies one for a truthful
   tile projection inside the React shell.
5. **Pixel grammar:** 16×16 source tiles, integer display scaling
   (2×/3×/4×), `image-rendering: pixelated`, consistent top-left light,
   limited per-material ramps, no anti-aliased scaling, no blurred shadows
   inside world art. Details live in DESIGN.md §Pixel-art grammar.
6. **Theme ids:** `meadow` (light, default), `dusk` (deliberate dark),
   `system` (resolves to one of the two). The default world theme pack is
   `cozy-valley`. The ids `paper` / `ink` are retired.
7. **Typography:** pixel display type (Silkscreen, OFL) for world labels,
   destination titles and menu chrome; a neutral readable sans for dense
   body/tables; a real monospace for terminal/logs. Pixel type never
   replaces body text or terminal text.
8. **Semantics stay load-bearing.** Project = building; shared concepts =
   distinct landmarks; characters = proven runtime rows only; ambient life
   (water, leaves, fireflies, birds, butterflies) is environmental and never
   implies agent activity. See SEMANTIC_WORLD.md.

## Consequences

- Every current-authority document is updated in this change so no living
  contract instructs agents to preserve Paper Co.
- Existing world PNG assets are replaced by a single coherent, procedurally
  authored original set with a committed generator script (repeatable,
  auditable, license-clean). Mediocre assets are not preserved because they
  exist.
- Tests that pinned Paper Co. visuals (theme ids, CSS class names, capture
  theme names) are updated deliberately; domain/truth tests are preserved.
- The screenshot evidence matrix is regenerated under the new language
  (`docs/desktop/assets/electron/foundations/`, themes `meadow` / `dusk`).
- Future themes (cyberpunk, space, …) remain architecture slots only —
  deliver one excellent cozy world first.

## References

- [DESIGN.md](../desktop/DESIGN.md) — governing visual contract
- [SEMANTIC_WORLD.md](../desktop/SEMANTIC_WORLD.md) — spatial product contract
- [ELECTRON_DESIGN_SYSTEM.md](../desktop/ELECTRON_DESIGN_SYSTEM.md) —
  Electron implementation reference
- [ADR-033](ADR-033-electron-desktop.md), [ADR-034](ADR-034-semantic-world.md)
- Superseded visual history: git history of `docs/desktop/DESIGN.md` and
  `docs/desktop/assets/design/` concept boards
