# Hornero Valley visual direction — 2026-11-13

## The product

Agent Toolkit is a serious, local-first developer workspace. Focus remains the
daily work surface; the World is an optional, semantic map of real projects,
capabilities, operations and sessions. The art must carry personality without
making technical state harder to read.

## Direction

Build Hornero Valley as a foothill settlement shaped by a creek and shared
craft. Its visual identity is warm adobe, kiln brick, dark timber, restrained
olive foliage and clear river teal. Architecture should feel built from
specific materials, with separate wings, porches, chimneys, eaves, footings,
gardens and believable entrances. Each civic building gets a memorable
silhouette and one legible functional detail.

The signature landmark is the public library: a broad reading room joined to
an asymmetrical adobe oven tower, with a glazed book gallery, deep veranda and
stone approach. Workshop gets a waterwheel and sawtooth roof. Operations gets
a clock cupola and map porch. Project houses vary in footprint and roofline,
not palette alone.

## Tokens

| Role | Color |
| --- | --- |
| Pine ink / deepest shadow | #2b3030 |
| Aged plaster | #f1dfb8 |
| Kiln terracotta | #bd6747 |
| Meadow sage | #789367 |
| Deep leaf / timber shade | #3e5e49 |
| Creek teal | #478b88 |
| Lantern honey | #e7b663 |

Body and interface text use IBM Plex Sans. Dense technical values use IBM Plex
Mono. Silkscreen remains a small accent for short world labels, never for
conversation, settings or dense information.

## Composition and behavior

- Use a consistent three-quarter, tile-ground perspective with upper-left
  daylight and cast shadows falling down-right.
- Let the creek bend and narrow at crossings. Trails should widen into small
  civic yards and soften into garden paths near homes.
- Give grove trees distinct branch structures and canopy silhouettes. Use
  material marks only where their cause is clear; remove generic speckle.
- Dusk shares the same authored geometry. Cool ambient shade and warm lamps
  communicate time without grey recolor tiles or rectangular lighting patches.
- Keep canonical semantic targets, keyboard access, focus, labels and
  session-backed activity independent of decorative art.
- Fit the useful map at compact sizes. The art must remain crisp at integer
  scales and never make the World mandatory for ordinary work.

## First implementation slice

The first slice changes the shared palette, reauthors the grove-tree
silhouettes and replaces the simple Library façade with a larger authored
landmark. A second slice varies meadow ground tone across broad, subtle moisture
regions to address the flat lawn without adding speckle. It is a prototype for
critique, not sign-off. Capture the actual Electron World at 1024×640, 1440×900
and 1920×1080 in Meadow and Dusk. Inspect the previews and screenshots before
extending the dimensions and language to the remaining buildings.

## Capture critique, iteration 1–3

Iteration 1 passed six packaged Electron captures (Meadow/Dusk × three sizes).
The Library became identifiable by its tower and book gallery. The broader scene
still looked like a flat lawn; the canal remained visually straight and the
grove read as repeated round clumps.

The first ground-tone prototype used strong differences between environmental
bands. Its six packaged captures exposed conspicuous rectangular patches. That
prototype was rejected. Iteration 3 reduced the ground variation to one close
sage shade and limited it to two spatial bands. Its six packaged captures no
longer show the high-contrast rectangular patches, while preserving the subdued
overall palette. This is a local improvement, not a claim that the World is
beautiful or complete. A third-party visual review, further terrain/canal work,
less repetitive trees and distinctive civic/project façades remain required.

Capture artifacts are kept outside the repository under
`/home/ulisesjcf/.ai-workspace/.audit-private/world-art-iteration-{1,2,3}/`.
The successful packaged runs used Electron's headless Ozone mode because the
host could not create an Xvfb lock under its `/tmp` write quota. They prove the
packaged renderer path at the requested viewport sizes, not native window
manager behavior.

## Known failed direction

The 2026-11-12 isolated Dusk grass swap made grass grey-blue while trees and
buildings stayed bright. It was discarded. Do not reintroduce that tile palette
swap; solve the lighting at the scene/material level after the shared palette
and authored terrain are coherent.

## Visual sign-off

This direction is not accepted as finished until a real-app review covers the
World overview, multiple projects, Library, Operations, Workshop, a project
exterior and interior, Focus, terminal/diff, onboarding, Settings, empty and
error states. Record defects from each capture and revise until buildings no
longer read as beginner box-house sprites and all production surfaces retain
professional text hierarchy.
