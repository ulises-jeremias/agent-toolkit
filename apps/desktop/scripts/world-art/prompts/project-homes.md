# Project home atlas prompt

Create an original atlas of six individual cozy pixel-art project buildings for
Agent Toolkit Desktop, an enchanted top-down developer workspace. Use a
transparent background and a clean 3-by-2 sprite layout with generous gutters.
Keep every house on the same baseline and at a common readable scale. The six
silhouettes are: leafy teal-roof cottage, red-roof studio with skylight, forest
workshop with wooden awning, pale research house with a small glass dome, dark
green cabin with chimney and blue windows, and red-brick project house with a
small bell tower. Each should feel like a distinct neighborhood home, not a
civic landmark. Add tiny flowers and stepping stones, warm windows, a small
mint rune door ornament, top-left light, crisp outlines, hard pixel shadows,
and a colorful but restrained palette. No signs, words, logos, characters,
background, or UI. Use original shapes and avoid recognizable references.

The generated six-building atlas was separated into individual transparent
PNG sources, point-sampled to 48×64 source pixels, then manually reviewed in a
nearest-neighbor montage and in the running Electron world. The final sources
are kept in this directory; `gen-world-assets.mjs --check` verifies the
shipped copies and manifest hashes.
