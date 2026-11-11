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

- 16px source tile; multi-tile sprites (houses 48×64, landmarks 48×72,
  trees 48×48); integer zoom only, `imageSmoothingEnabled=false`.
- One light direction (top-left), hard pixel shadows, 1px ink outline
  (`#2b2135`), limited color ramps per material, no anti-aliasing.
- Animation is restrained and environmental: 2-frame water, lamp flicker,
  ambient hornero/butterfly. Characters animate only with real session work.
- Every décor placement must read semantically (paths connect doors,
  lamps mark entrances, reeds mark water). No random scatter noise.

## Palette (source of truth: `scripts/world-art-pxl/palette.px.js`)

Shared `pal()` + `ramps()` for ink, plaster, wood, terracotta, slate,
leaf/grass greens, dirt, plaza stone, creek teal, flower accents, lamp
warmth and hood/cloak character colors. Meadow uses the palette as
authored; Dusk is a separately authored lighting pass in the world theme
(lit windows, lamp glow, water reflection), never a CSS inversion.

## Pipeline

```text
apps/desktop/scripts/world-art-pxl/*.px.js   (editable PXL sources)
  -> skills/design/pxl-pixel-art/bin/pxl.js  (vendored renderer, pinned 21fee41)
  -> apps/desktop/scripts/gen-world-assets-pxl.mjs
  -> public/world/<name>.png + scripts/world-art-pxl/pxl-manifest.json
  -> gen-world-assets.mjs merges entries into src/features/world/manifest.json
  -> WorldEntityMap / TerrainRenderer (manifest-driven, semantic ids stable)
```

- `node scripts/gen-world-assets-pxl.mjs` regenerates; `--check` rebuilds
  and byte-compares (deterministic, seeded rng only).
- `node scripts/gen-world-assets.mjs --check` remains the CI gate during
  migration; it skips PXL-owned sprites and merges their manifest entries.
- Previews for human review land in `scripts/world-art-pxl/preview/`.
- Security: `.px.js` is trusted executable code. CI builds only the
  reviewed in-repo sources; external art files are never built.

## Migration staging

1. PR B (this): pipeline + terrain/trees/houses/landmarks/characters core set.
2. PR C: new world composition/theme (Meadow + Dusk), interiors, player set;
   remaining legacy sprites migrated or retired.
3. PR E: delete `gen-world-assets.mjs` painters + `scripts/world-art/` PNG
   sources; `gen-world-assets-pxl.mjs` becomes sole manifest writer.

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
