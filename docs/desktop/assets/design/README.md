# Desktop design references

Status: **CURRENT GUIDE** — updated 2026-09-30 for the semantic-world home.

These images are **directional visual references**, not implementation
screenshots and not sources of product/runtime truth.

## Semantic world (2026-09-30)

| File | Role |
|---|---|
| [`asset-sheet-cozy-world.jpg`](asset-sheet-cozy-world.jpg) | Tilesets, building archetypes (project house, library, archive, operations, terminal hub, toolsmith…), UI chrome, badges, logos. **Directional atlas — do not ship as a runtime sprite sheet.** |
| [`semantic-world-product-board.jpg`](semantic-world-product-board.jpg) | Product IA board: `/world` campus of project houses + shared places; interiors; Library/Office/Operations/Memory/Terminal as inspectors. |
| [`semantic-world-ui-board.jpg`](semantic-world-ui-board.jpg) | UI destinations board (same IA; denser mock surfaces). |

**Production sprites** (original Paper Co. pixel buildings, archetype-inspired — not JPG crops) live at:

`apps/desktop/public/world/`

Wired through `cozyTopdownTheme.facades` → `ThemeAsset.kind = 'sprite'` in `WorldEntityMap`.

**How to evolve the asset sheet into more sprites**

1. Author or slice individual sprites into `apps/desktop/public/world/` (transparent PNG, nearest-neighbor).
2. Map slices to **façade ids** / semantic keys in
   [`apps/desktop/src/features/world/theme/cozyTopdown.ts`](../../../apps/desktop/src/features/world/theme/cozyTopdown.ts)
   — never hardcode filenames inside feature code.
3. **Characters / ambient animals** on the sheet are art vocabulary only.
   Production characters appear only for proven jobs/runs (ADR-034). Do not
   spawn decorative NPCs, walking agents, or invented “busy” states from
   these frames.
4. Building archetypes: cottage / studio / workshop / lab (projects);
   library, archive, operations HQ, files shed, terminal hub, settings booth,
   attention stamp (commons). CSS craft remains the fallback when a façade
   sprite is missing.

## Historical Paper Co. boards (still binding for inspector craft)

- [`concept-board.jpg`](concept-board.jpg) — Paper Co. overview, Hornero,
  terminal contrast, palette.
- [`office.jpg`](office.jpg) — Office destination craft (attention inspector;
  not the product home).
- [`library.jpg`](library.jpg) — Library destination craft.
- [`operations.jpg`](operations.jpg) — Operations destination craft.
- [`onboarding.jpg`](onboarding.jpg) — first-run craft language.

Concept boards and Office remain strong anchors for **inspector** materials.
The 2026-09-30 world boards supersede Office-as-spatial-home. Fictional
metrics, statuses, navigation labels (“Market”, “Guild Hall”, fake agent
counts) must not override `PRODUCT_VISION.md`, `SEMANTIC_WORLD.md`,
ADR-034, Engine truth, or accessibility.

Do not copy copyrighted game or third-party product assets when implementing
this direction. Production pixel art must be original or appropriately licensed.
