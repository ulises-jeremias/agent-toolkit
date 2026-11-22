---
name: video-editing
description: Intelligent nonlinear video editing with Kdenlive through MCP — build and refine real editable .kdenlive projects (tracks, cuts, trims, crossfades, titles, subtitles, narration, music), render with validation, and preserve the source project. Use whenever an editable timeline is required, not just a flattened export.
origin:
  type: first-party
tools:
  - kdenlive
triggers:
  - edit video
  - kdenlive
  - cut footage
  - make a trailer
  - video timeline
  - add subtitles
---

# Video Editing — Kdenlive MCP

Primary integration: `mhbxyz/kdenlive-mcp` (PyPI package **`mcp-kdenlive`**,
command `kdenlive-mcp`), evaluated at revision
`9abcf9474a434f2e00a9c458f0ff70c92fbc16d8` — see
`docs/creative-studio/UPSTREAM_EVALUATION.md`. Requires Linux, Kdenlive,
MLT (`melt`) and FFmpeg installed from the distribution.

## Setup and safety

1. `kdenlive-mcp diagnose` must say `ready`; otherwise report what is
   missing instead of editing blind.
2. Set `KDENLIVE_MCP_ALLOWED_ROOTS` to the project directory only. The
   server refuses files outside it — do not work around that.
3. The server writes a timestamped `.backup-*.kdenlive` before each edit;
   keep them until the delivery is verified.

## Workflow

1. **Probe** every source first (`probe_media`): duration, resolution,
   codecs, frame rate. Clip ranges must use real source timestamps/frames.
2. **Create** the project from a representative source (`create_project`,
   explicit profile when the delivery is vertical/short-form).
3. **Build** the timeline: `add_media_to_bin` → `insert_clip` per shot on
   the right tracks (video/audio pairs, cutaways with `audio_track=null`,
   music on its own audio track).
4. **Refine**: `trim_clip`, `split_clip`, `move_clip`, `add_mix`
   (crossfades), `add_effect`, `set_clip_volume`, `set_clip_fades`.
5. **Titles/subtitles**: `add_title` on a dedicated track;
   `import_subtitles` only from a real transcript (see `video-analysis`).
6. **Mark** decisions with `add_marker` so a human can review the edit.
7. **Render**: `render_project` for short outputs, `start_render` +
   `get_render_job` for long ones; `cancel_render_job` stops a background
   render. Report the server's stream/duration validation verbatim.
8. **Verify** with `media-qa`, then reopen-check the `.kdenlive` file
   (`inspect_project`) before claiming success.

## Rules

- The `.kdenlive` project is a deliverable, not a by-product. Never replace
  this workflow with FFmpeg concatenation when an editable timeline was asked for.
- Never overwrite an existing export; version outputs (`v1`, `v2`, …).
- Prefer small iterative edits over rebuilding the project.
- If Kdenlive is unavailable, say so and offer an FFmpeg-only fallback
  labelled as flattened (no editable project) — never silently.
