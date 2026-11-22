---
name: motion-graphics
description: Motion graphics and 3D with Blender — logo animations, title sequences, scene/camera/material work and validated renders that preserve the .blend source. Headless bpy for deterministic jobs; Blender Lab MCP for interactive sessions under an explicit high-risk gate.
origin:
  type: first-party
tools:
  - blender
triggers:
  - motion graphics
  - blender
  - logo animation
  - title sequence
  - 3d render
  - intro outro animation
---

# Motion Graphics — Blender

## Two execution modes

**Headless (default, deterministic):** `blender -b --python script.py`
under a bounded scope. Build/modify the scene, `save_as_mainfile` to
`edit/`, render stills or frames, then reopen the `.blend` to prove it is
not corrupt. Verified pattern on Blender 5.3 (EEVEE id `BLENDER_EEVEE`).

**Interactive (opt-in, high risk):** Blender Lab MCP
(`projects.blender.org/lab/blender_mcp`, GPL-3.0) or `ahujasid/mcp-for-blender`.
These can execute model-generated Python inside a live Blender. That is
arbitrary code execution: require explicit user authorization, keep the
listener on loopback, restrict writes to the project directory, and save a
copy of the `.blend` before the session.

## Workflow

1. Write the brief: duration, fps, resolution, style references, exact text.
2. Build the scene (objects, materials, camera, lights), keyframe the
   animation, save `edit/<name>.blend` **before** rendering.
3. Render a low-res preview; inspect frames visually (not just exit codes).
4. Iterate on the `.blend`; never bake the only copy into a video.
5. Final render to `preview/` or `export/`; validate with `media-qa`
   (resolution, duration, non-black frames, file reopens).

## Rules

- `.blend` is the source of truth and a deliverable.
- Reusable title/logo rigs are saved as separate `.blend` assets under
  `assets/` so projects can link/append them.
- Bound heavy renders (`systemd-run --user --scope` with memory caps on
  Linux) and check GPU/VRAM before starting; one high-VRAM job at a time.
- Do not claim MCP interactivity was used when only headless ran.
