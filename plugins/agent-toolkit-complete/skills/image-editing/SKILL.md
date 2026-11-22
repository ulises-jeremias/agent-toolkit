---
name: image-editing
description: Layer-aware image editing and design assets with GIMP, Krita and Inkscape through MCP — retouching, compositing, masks, thumbnails and SVG artwork with native editable sources (XCF/KRA/SVG) plus checked exports.
origin:
  type: first-party
tools:
  - gimp
  - krita
  - inkscape
triggers:
  - edit image
  - thumbnail
  - gimp
  - krita
  - inkscape
  - svg asset
  - compositing
---

# Image Editing

Evaluated integrations (see `docs/creative-studio/UPSTREAM_EVALUATION.md`;
none executed yet — report status honestly until verified):

- **GIMP:** `gimp-mcp/gimp-mcp` (GPL-3.0, 80 tools, GIMP 3.2.x).
- **Krita:** `jowinjohnchemban/kritapilot` (MIT, 98 tools; upstream tested
  on Krita 5.3.4 — check the installed version before promising support).
- **Inkscape:** `aravindev/inkscape_mcp` (MIT; headless mode needs no GUI,
  live mode drives a running Inkscape over D-Bus with undoable edits).

## Workflow

1. Open a **copy** of the source into `edit/`; originals stay untouched.
2. Prefer non-destructive work: duplicate layers, masks over erasing,
   adjustment/effect layers where the application supports them.
3. Save the native file (`.xcf`, `.kra`, `.svg`) as the deliverable source.
4. Export requested formats (PNG/JPEG/WebP/SVG/PDF) into `assets/` or
   `export/`; verify dimensions, colour space and file size.
5. For thumbnails, check legibility at the actual display size and keep
   text on its own layer so wording can change without a rebuild.

## Rules

- Never flatten the only copy; exports are derived, sources stay layered.
- Generated imagery (ComfyUI) is an input to editing, not a substitute for
  art direction; keep its workflow/prompt provenance in the manifest.
- If the application or MCP is unavailable, fall back to scripted
  `ffmpeg`/`magick` transforms only when labelled as such.
