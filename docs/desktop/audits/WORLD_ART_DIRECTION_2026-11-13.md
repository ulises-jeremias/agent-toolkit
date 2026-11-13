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

## Civic facade slice — packaged Electron critique

The next authored PXL pass replaces the generic Archive, Workshop and Operations
silhouettes with a stone records hall and catalog tower, a sawtooth-roof forge
with a waterwheel, and a map porch with an offset clock tower. Previews were
corrected after the first Workshop pass clipped the wheel and crowded its doors.
The revised assets are generated from the governed PXL sources; `check:world`
confirms all 201 generated sprites are current, and the focused World suite passes
72/72 tests.

Packaged Electron captures were opened at 1024×640, 1440×900 and 1920×1080.
At 1024×640, the three facades remain recognizable and the waterwheel is visible.
At 1920×1080, material and silhouette details read cleanly. At 1440×900, the
village occupies too little of the available map canvas and leaves excessive
empty surround; this remains a composition defect. The earlier impression that
the Dusk capture showed Meadow was incorrect: the opened Dusk capture is darker,
with warm point lights, but the scene still leans olive and its light sources do
not yet share one coherent treatment.

Private captures are under
`/home/ulisesjcf/.ai-workspace/.audit-private/world-civic-iteration-1/`.
This slice is not visual sign-off: map scale/composition, canal shape,
tree repetition, project-house variety and native-window-manager review remain open.

## Responsive overview camera — packaged Electron critique

The previous default camera followed the player avatar and used width breakpoints
that did not consider the actual map bounds. The 1440×900 overview stayed small;
the 1920×1080 player view could crop the full semantic village. The renderer now
opens in `fit` mode, computes the largest whole-CSS-pixel tile size that fits the
actual room, and keeps walking an explicit action. Intermediate tile scales (40
and 56 CSS pixels) let the 28×13 village fill roughly 90% of the World region at
1440 and 1920 without fractional blur or clipping. A packaged Electron capture
test now asserts the complete world fits its region at each viewport.

All six packaged captures passed and were opened: Meadow/Dusk at 1024×640,
1440×900 and 1920×1080. At 1440 and 1920 the village is larger and centered; at
1024 it remains legible and fits. This fixes the camera crop/scale defect only.
The scene still reads as a sprite showcase rather than a composed valley: a
rectangular terrain boundary, straight creek, repeated canopy clusters,
isolated front-facing buildings, and large vertical margins remain. The later
ground pass reduces small marks; see the next section. Private captures are under
`/home/ulisesjcf/.ai-workspace/.audit-private/world-fit-overview-v2/`.

## Vegetation density and ground detail — iterations 4–5

The first vegetation pass removed every mark from grass and reduced flowers and
path flecks. Its six packaged captures revealed broad square tone bands more
clearly. That version was rejected. Iteration 5 restores only a short, muted
two-pixel grass blade per tile, keeps the broad base tone uniform, groups
flowers in smaller glades, and removes most gravel flecks from paths. Flower
tiles now show two small stems instead of a dense scatter, and featured glades
use four authored plant groups.

The rebuilt Linux unpacked Electron app passed the six-view World capture at
1024×640, 1440×900 and 1920×1080 in Meadow and Dusk. I opened all six images.
The terrain is calmer, the village paths read more clearly, and flower color no
longer competes across the whole lawn. The square scene edge remains, the canal
still reads as a straight divider, trees still repeat dense rounded crowns, and
the houses remain isolated front-facing cutouts. These captures verify
rendering in packaged Electron only; they do not earn visual sign-off. Private
captures:
`/home/ulisesjcf/.ai-workspace/.audit-private/world-art-iteration-5/`.
The unpacked Electron executable SHA-256 is
`234e177afdc9ee053d6798ae1fd8ada6e535f5c8425d25ff17c92aac571a7d2d`.

Local validation on the dirty source worktree passed the focused World/model
tests (76 tests), full Desktop test command, TypeScript checks, ESLint, generated
PXL asset determinism (201 sprites), `build:all`, `dist:dir`, and the packaged
six-view Electron capture. The package stages the existing 1.49.0 backend from
rescue commit `0c730540`; it is not a fresh build from the pinned V toolchain.
The exact source head remains `8a8037ac` plus uncommitted art changes until a
reviewed commit is pushed.

Capture artifacts are kept outside the repository under
`/home/ulisesjcf/.ai-workspace/.audit-private/world-art-iteration-{1,2,3,4,5}/`.
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
