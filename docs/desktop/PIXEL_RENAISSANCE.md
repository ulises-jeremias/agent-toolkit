# Pixel Renaissance — Art Direction & PXL Pipeline

Mission: [#1741](https://github.com/ulises-jeremias/agent-toolkit/issues/1741) ·
Semantic world: #1673 · Daily driver: #1667 · ADR: `docs/adrs/ADR-042-pxl-asset-pipeline.md`

## Identity

An original cozy valley for a developer workstation — **Hornero Valley**:
warm golden-hour light, terracotta and slate roofs over cream plaster and
timber, a teal creek threading the project district, lush but disciplined
greenery. It borrows the *warmth and readability* of classic cozy pixel
games, never their sprites, layouts or characters.

Signature: every project house carries a lit window and a small garden tied
to its façade variant; at Dusk the same windows and street lamps become the
light sources (authored lighting, not a recolor).

## Pixel discipline

- 16px source tile; multi-tile sprites (houses 48×64, most landmarks
  48×72, Library 48×64, trees 48×48); integer zoom only,
  `imageSmoothingEnabled=false`.
- One light direction (top-left), hard pixel shadows, 1px ink outline
  (`#2b2135`), limited color ramps per material, no anti-aliasing.
- Animation is restrained and environmental: 2-frame water, lamp flicker,
  ambient hornero/butterfly. Characters animate only with real session work.
- Every décor placement must read semantically (paths connect doors,
  lamps mark entrances, reeds mark water). No random scatter noise.

## Palette (source of truth: `scripts/world-art-pxl/palette.px.js`)

Shared `pal()` + `ramps()` for ink, plaster, wood, terracotta, slate,
leaf/grass greens, dirt, plaza stone, creek teal, flower accents, lamp
warmth and hood/cloak character colors. Meadow uses the palette as authored.
Dusk uses authored windows, lamp glow and water reflection under a restrained,
even blue-hour ground tint; it is not a CSS inversion. The grass surround still
reads too green in Dusk and remains an open art-direction issue.

## Pipeline

```text
apps/desktop/scripts/world-art-pxl/*.px.js   (editable PXL sources)
  -> skills/design/pxl-pixel-art/bin/pxl.js  (vendored renderer, pinned 21fee41)
  -> apps/desktop/scripts/gen-world-assets-pxl.mjs
  -> public/world/<name>.png + scripts/world-art-pxl/pxl-manifest.json
  -> src/features/world/manifest.json (sole writer: gen-world-assets-pxl.mjs)
  -> WorldEntityMap / TerrainRenderer (manifest-driven, semantic ids stable)
```

- `node scripts/gen-world-assets-pxl.mjs` regenerates; `--check` rebuilds
  and byte-compares (deterministic, seeded rng only).
- `node scripts/gen-world-assets-pxl.mjs --check` is the CI asset gate.
- Previews for human review land in `scripts/world-art-pxl/preview/`.
- Security: `.px.js` is trusted executable code. CI builds only the
  reviewed in-repo sources; external art files are never built.

## Migration staging

1. PR B (this): pipeline + terrain/trees/houses/landmarks/characters core set.
2. PR C: new world composition/theme (Meadow + Dusk), interiors, player set;
   remaining legacy sprites migrated or retired.
3. PR E (done): legacy `gen-world-assets.mjs` + `scripts/world-art/` PNG
   sources deleted; `gen-world-assets-pxl.mjs` is the sole manifest writer.

Semantic contracts (ids, hrefs, truth gating in `model/buildWorld.ts`) do
not change. See `SEMANTIC_WORLD.md`.

## Design-assessment pass (post-review, PR C follow-up)

Evidence: production bundle rendered in Chromium against the real V
backend (`/api/v1/version` 200; browser shell shows the honest offline
banner because backend CORS is Electron-bridge only — the packaged
Electron CI suite with fresh HOME is the real-shell evidence), sprite
previews, and CI Packaged Electron journeys.

Findings (severity per design-assessment):
- Major (fixed): east forest read as one solid mass → edge density
  8/31 → 6/31; amber canopies read as orange blobs → rust-dark canopy
  base for contrast.
- Major (fixed): Settings pavilion had no entrance → door added.
- Minor (accepted): Operations dishes read as plates at zoom 2; label
  chips can overlap façades at 1024×640 (pre-existing DOM label layout).
- Minor (accepted): People/Terminal empty states leave large canvas
  (pre-existing feature layout, honest states, not a Renaissance
  regression).
- Not assessed: real-provider session characters, screen-reader pass,
  WCAG conformance beyond static token contrast + jsx-a11y (never
  claimed from static tests).
## Desktop UI language (PR D)

The surrounding application speaks the same material language as the
valley: warm ink-plum menu chrome (derived from the PXL ink `#2b2135`),
cream ivory text, gold for primary actions, terracotta for the brand mark
and attention, hard pixel shadows and 2px carved panel frames. Dense
professional surfaces (terminal, diffs, forms, tables) stay in the IBM
Plex text faces at normal weights — pixel display type is reserved for
navigation, titles and plaques, never for technical text. Meadow and Dusk
share this chrome; Dusk deepens the canvas and warms the gold.

## Visual QA evidence (PRs B–E)

- Sprite level: every PXL build inspected at native + upscaled preview;
  two fix iterations (bridge/library/archive identity, shingle texture,
  grass density) driven by contact-sheet review.
- App level: production bundle rendered (Chromium, no backend — the
  honest offline state) and screens captured/reviewed: World Meadow at
  1024×640, 1440×900, 1920×1080; World Dusk at 1440×900; Library,
  People, Settings and the Ctrl+K command palette at 1440×900.
- Accessibility (WCAG 2.2 AA, curated `review` modes): jsx-a11y via
  `pnpm lint` (automatically detectable) clean; static token contrast
  for the new ink-plum ramp passes all claimed pairs (text 8.5–15.5:1,
  gold action 10.5:1, terracotta non-text 4.4:1); keyboard order, focus
  rings, World list fallback and reduced-motion paths are unchanged
  contracts covered by unit/E2E suites. Screen-reader pass and
  real-backend Electron captures remain human QA items — not assessed
  here, not claimed.
- Known polish backlog (tracked in #1741): forest density on the east
  bank, Dusk halo softening, flower-box detail on house-cottage.

## Continuing product rescue iteration — 2026-11-12

- Rebuilt the Library landmark from its trusted PXL source as a 48×64
  glasshouse with a broad book window, structural roof ribs and a separate
  entrance. The previous 48×72 sprite exceeded its four-tile semantic lot and
  visually collided with the Workspace building; the revised height now fits
  that lot. The PXL generator owns the PNG and both manifests.
- Ran the source Electron app with the real local backend at 1024×640,
  1440×900 and 1920×1080 in Meadow and Dusk. Opened the 1920×1080 Meadow and
  compact 1024×640 Dusk captures after the footprint correction. Screenshots
  remain private under `.audit-private/world-library-64px-final/`.
- Changed the navigation rail so Focus precedes the optional World. The
  renderer smoke test now verifies the semantic map role; the renderer suite
  passes 7/7, and packaged-shell keyboard/reduced-motion checks pass 2/2.
- This iteration is not visual acceptance. Dusk grass still reads too green;
  the Workspace label crowds the Library roof at compact scale; the remaining
  civic façades and overall valley composition still need PXL art direction and
  another capture/critique pass. Do not treat this note as sign-off.

## Finalization review (post-merge, from packaged captures)

Independent critique of the actual packaged application (CI
`electron-review-screenshots` artifact, backend commit `b861837` —
World Meadow 1280×800, World Dusk 1024×768, Library and Settings
1440×900), not isolated sprites:

- Composition/craft: coherent warm valley, distinct house silhouettes,
  readable semantic plaques, rich river/forest east bank; Settings and
  Library remain legible professional surfaces with honest empty
  states. No blocker or major defect found.
- Minor (owner's aesthetic call, not fixed unilaterally): Operations
  satellite dishes can read as plates at zoom 2; at 1024×768 Dusk the
  terrain stays daylight-green with window/lantern glow doing the
  evening work; Library/People empty states leave large empty canvas.
- Assistive-technology matrix: automatically detectable checks
  (jsx-a11y lint) clean; keyboard order/focus/reduced-motion contracts
  covered by the unit and packaged-Electron journeys; **screen reader
  (Orca/NVDA) not assessed** — no suitable environment was available,
  and full WCAG 2.2 AA conformance is not claimed from automated
  checks alone.
