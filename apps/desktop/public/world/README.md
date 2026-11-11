# World assets (Hornero Valley — Pixel Renaissance)

Every PNG in this directory is **original pixel art authored in-repo** as
PXL sources in [`../../scripts/world-art-pxl/`](../../scripts/world-art-pxl/)
and rendered deterministically by
[`../../scripts/gen-world-assets-pxl.mjs`](../../scripts/gen-world-assets-pxl.mjs)
(the pinned vendored PXL renderer, `skills/design/pxl-pixel-art`):

```bash
node scripts/gen-world-assets-pxl.mjs          # regenerate
node scripts/gen-world-assets-pxl.mjs --check  # verify freshness (CI)
```

- Source grid: 16×16 px per tile; buildings/objects at integer multiples.
- Animated sprites pack frames horizontally (frame width = manifest `w`).
- `manifest.json` lists every sprite with source size, frame count and sha256.
- Upscaled review previews live in `scripts/world-art-pxl/preview/`.
- License: original Agent Toolkit artwork, same license as the repository.
  No third-party or copyrighted game art is included or derived.
- Security: `.px.js` sources are trusted executable code — only the
  reviewed in-repo sources are ever built (ADR-042).

Feature code never references these filenames directly — sprites resolve
through semantic theme keys in `src/features/world/theme/` (ADR-034,
ADR-042).
