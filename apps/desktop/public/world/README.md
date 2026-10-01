# World assets (Cozy Pixel World)

Every PNG in this directory is **original pixel art generated in-repo** by
[`../../scripts/gen-world-assets.mjs`](../../scripts/gen-world-assets.mjs):

```bash
node scripts/gen-world-assets.mjs          # regenerate
node scripts/gen-world-assets.mjs --check  # verify freshness (CI)
```

- Source grid: 16×16 px per tile; buildings/objects at integer multiples.
- Animated sprites pack frames horizontally (frame width = manifest `w`).
- `manifest.json` lists every sprite with source size and frame count.
- License: original Agent Toolkit artwork, same license as the repository.
  No third-party or copyrighted game art is included or derived.

Feature code never references these filenames directly — sprites resolve
through semantic theme keys in `src/features/world/theme/` (ADR-034,
ADR-035).
