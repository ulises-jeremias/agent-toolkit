# Original world art

The transparent facade and tree PNGs here are original Agent Toolkit Desktop
art. The facades use the team's design references without copying their
buildings or layouts. The Operations observatory was generated specifically
for this project; its prompt is recorded in `prompts/landmark-operations.md`.
It was reduced to a 64×64 source sprite with nearest-neighbour sampling and a
hard alpha edge for crisp integer scaling. The six tree silhouettes are an
original transparent atlas in `tree-atlas-2026-10-07.png`, individually
cropped to a shared 48×48 footprint with nearest-neighbour sampling. This
preserves the atlas's distinct oak, flowering, autumn, rune-lit, pine, and
willow silhouettes while keeping display scaling crisp. The source atlas,
selected crop PNGs, and generation prompt are checked in so review and
generation do not depend on a network service or image editor.

`node scripts/gen-world-assets.mjs` copies these selected sources into
`public/world/` and records their dimensions, source path, and SHA-256 in
`public/world/manifest.json`. `node scripts/gen-world-assets.mjs --check`
verifies the shipped files against those sources. All other terrain, interior,
character, and prop art continues to come from the deterministic code
generator.

The facades correspond to the workspace hall, three project-home variants,
Library, Operations, Memory Archive, and Terminal Station. Operations uses a
distinct observatory roof and bell tower; Library, Archive, Terminal and the
workspace hall keep their separate semantic roles. The trees provide leafy,
rune-lit, blossom, autumn, pine, and creek-bank willow silhouettes.
Their meanings and all world actions remain defined by the semantic world
model; artwork does not introduce new runtime state.
