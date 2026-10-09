# Original world art

The transparent facade and tree PNGs here are original Agent Toolkit Desktop
art. They use broad cozy-game art direction without copying recognizable
buildings, maps, characters, or UI. Six project homes and seven shared
landmarks were generated as an original pixel-art atlas, separated into
individual transparent sprites, sampled with nearest-neighbour scaling,
reduced to a restrained palette, and given hard alpha edges for crisp integer
scaling. The project homes use 48×64 source pixels with a 3×3
walkable ground footprint; roofs and eaves intentionally overhang that lot.
Separate landmark sprites give the workspace hall, Library, Operations
observatory, Memory Archive, Terminal Station, Workshop, and Attention place
distinct silhouettes and warm window light.
The empty-project invitation is an original leafy timber sign with a glowing
plus rune and abstract project tokens (64×50 source pixels); it is a real
clickable project-directory action, not a decorative notice board.
The six tree silhouettes are an original transparent atlas in
`tree-atlas-2026-10-07.png`, individually cropped to a shared 48×48 footprint
with nearest-neighbour sampling and a hard alpha threshold. This preserves
the distinct oak, flowering, autumn, rune-lit, pine, and willow silhouettes.
The individual source PNGs and tree atlas are checked in so validation does
not depend on a network service or image editor.

`node scripts/gen-world-assets.mjs` copies these selected sources into
`public/world/` and records their dimensions, source path, and SHA-256 in
`public/world/manifest.json`. `node scripts/gen-world-assets.mjs --check`
verifies the shipped files against those sources. All other terrain, interior,
character, and prop art continues to come from the deterministic code
generator.

The facades correspond to the workspace hall, six project-home variants,
Library, Operations observatory, Memory Archive, Terminal Station, Workshop,
Attention, and the empty-project invitation. Library, Archive, Terminal,
Operations, and the workspace hall keep separate semantic roles. The trees
provide leafy, rune-lit, blossom, autumn, pine, and creek-bank willow
silhouettes.
Their meanings and all world actions remain defined by the semantic world
model; artwork does not introduce new runtime state.
