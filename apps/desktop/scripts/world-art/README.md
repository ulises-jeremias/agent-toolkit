# Original world facades

These eight transparent facade PNGs are original Agent Toolkit Desktop art. They were generated for this repository from the team's design references, then cut into semantic sprites, snapped to a 32-colour palette, and reduced with nearest-neighbour sampling for crisp integer scaling. The source PNGs are intentionally checked in here so asset generation and review do not depend on a network service or image editor.

`node scripts/gen-world-assets.mjs` copies these selected facades into `public/world/` and records their dimensions, source path, and SHA-256 in `public/world/manifest.json`. `node scripts/gen-world-assets.mjs --check` verifies the shipped files against those sources. All other terrain, interior, character, and prop art continues to come from the deterministic code generator.

The facades correspond to the workspace hall, three project-home variants, Library, Operations, Memory Archive, and Terminal Station. Their real-world meanings and actions remain defined by the semantic world model; artwork does not introduce new runtime state.
