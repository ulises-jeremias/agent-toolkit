# ADR-042: PXL as the Desktop pixel-art asset pipeline

- Status: Accepted (mission #1741, visual replacement authorized by product owner)
- Date: 2026-11-10
- Related: ADR-034 (semantic world), ADR-035 (cozy pixel world), #1673, #1741

## Context

The Desktop world art was produced by a monolithic procedural generator
(`apps/desktop/scripts/gen-world-assets.mjs`, ~2,300 lines) plus checked-in
source PNGs. The product owner judged the result not good enough and
authorized a complete visual replacement. Agent Toolkit now vendors the
PXL pixel-art DSL (`design/pxl-pixel-art`, crsolver/claude-pxl @ 21fee41,
MIT) as a governed upstream capability (PR #1742).

## Decision

1. All new world art is authored as PXL sources in
   `apps/desktop/scripts/world-art-pxl/*.px.js` with one shared palette
   (`palette.px.js`), rendered by the pinned vendored renderer.
2. `apps/desktop/scripts/gen-world-assets-pxl.mjs` is the pipeline entry:
   deterministic build, `--check` byte-compare, per-sprite manifest with
   `{file,w,h,frames,source,sha256}`, upscaled previews for review.
3. Semantic contracts are unchanged: sprite ids, the manifest format
   consumed by `WorldEntityMap`, entity ids/hrefs and `buildWorld` truth
   gating stay stable (ADR-034). Only the art and its generation change.
4. Migration is staged (pipeline → world replacement → legacy deletion).
   The legacy generator skips PXL-owned sprites and merges their manifest
   entries during the transition; it is deleted in the final stage, not
   kept as a parallel system.
5. No Phaser/Pixi or other game engine; the existing Canvas/DOM renderer
   and React/Electron interaction layer remain (ADR-034/035).
6. PXL is a build-time authoring tool only. Packaged Desktop use needs no
   network and no remote image service.

## Security

`.px.js` art files are trusted executable code: the upstream loader
evaluates them with host-realm access (proven escape, no timeout). Only
reviewed in-repo sources are built, in CI and locally. Untrusted art is
never built or served automatically.

## Consequences

- Art becomes editable, reviewable source with reproducible output and
  sprite galleries, replacing opaque procedural painters.
- One interim release carries both generators; the deletion is scheduled
  in mission #1741 PR E and tracked there, not left open-ended.
- Dusk remains an authored lighting variant of the same world (ADR-035),
  produced from the shared palette, not a filter.
