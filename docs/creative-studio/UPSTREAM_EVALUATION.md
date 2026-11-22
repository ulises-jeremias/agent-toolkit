# Creative Studio — upstream integration evaluation

Evaluation date: 2026-11-22. Host: HorneroOS (Arch, kernel 7.3.5), RTX 3060,
Kdenlive 26.08.3, MLT 7.42.0, FFmpeg n9.1, Blender 5.3.0, GIMP 3.2.8,
Krita 6.0.4.1, OBS 33.0.1, REAPER (installed), Python 3.12/3.14.

Classifications: **Core** (first end-to-end workflow), **Recommended**,
**Optional**, **Experimental**, **Deferred/Rejected**. "Tested" means executed
on this host during this evaluation; everything else is source-inspected only
and must not be presented as verified.

## Video editing

### Core — `mhbxyz/kdenlive-mcp` (PyPI `mcp-kdenlive`)

- Revision `9abcf9474a434f2e00a9c458f0ff70c92fbc16d8` (2026-11-13), MIT,
  Python ≥3.11, Linux only, stdio transport.
- 37 tools: probe/inspect, project create/copy, bin/track/timeline edits,
  effects, mixes, titles, subtitles, markers, relink, foreground/background
  render with job status and cancellation.
- Safety: `KDENLIVE_MCP_ALLOWED_ROOTS` contains all writes; timestamped
  `.backup-*.kdenlive` copy before each edit; safe-XML parsing
  (`safexml.py`); read-only tools declare `readOnlyHint`.
- Compatibility (upstream matrix, cross-checked): Kdenlive 23.04–26.08 read/edit,
  `kdenlive --render` from 24.02, MLT 7.x, FFmpeg ≥6.
- **Tested on host:** `kdenlive-mcp diagnose` → ready (Kdenlive 26.08.3,
  melt 7.42.0, ffprobe n9.1). Upstream deterministic demo
  (`examples/demos/vertical_short`) produced an editable `.kdenlive` project
  plus `short.mp4` (H.264 1080×1920, AAC, 9.00 s), all objective checks
  passed (crop, title timing, grading, fade-out, duration). Source fixtures
  unchanged (md5 verified).
- Install: `pipx install mcp-kdenlive` or `uvx mcp-kdenlive`. Note: the PyPI
  name `kdenlive-mcp` is an unrelated project — use `mcp-kdenlive`.

### Experimental (deferred) — `AMMIROSOH/Kdenlive-mcp`

- Revision `b1ff6d5d0263c9074230b9a5d02a6a5d58d2386e` (2026-09-21),
  Apache-2.0, Node 22+/pnpm monorepo.
- Different model: a versioned JSON project is the source of truth and MLT is
  compiled from it; `.kdenlive`/OTIO are exports. Durable jobs, loudness and
  A/V-sync checks are strengths, but the native project is not the primary
  artifact, which conflicts with the editable-project requirement. Not
  executed in this evaluation; revisit if its OTIO path matures.

### Core (no MCP needed) — FFmpeg/ffprobe + MLT (`melt`)

- System packages, already required by Kdenlive MCP. Used directly for media
  inspection, loudness (EBU R128 `loudnorm`), frame extraction and exports.
- **Tested on host:** loudnorm pass moved a fixture from −21.05 LUFS to
  −15.95 LUFS (target −16), originals untouched.

### Optional — `rhkiswani/mcp-video`

- Revision `2ccee65deb9dbd607772cba222505ae12e0c00e3` (2026-04-18),
  Apache-2.0. 83 FFmpeg tools + Remotion scaffolding. Useful for
  non-Kdenlive batch transforms, but it produces flattened output only, so
  it never replaces the editable-project workflow. Not executed.

## Blender and 3D

### Recommended (high-risk class) — Blender Lab MCP

- `https://projects.blender.org/lab/blender_mcp` revision
  `dbbf836ad4b1025f14a2b3b504c43903f39e0b04` (2026-09-29), GPL-3.0.
  Official Blender Lab add-on + MCP server; tools auto-discovered from
  `mcp/blmcp/tools/`. Preferred first because it is the upstream-blessed path.
- **High risk:** Blender MCP can execute model-generated Python inside
  Blender. The Agent Toolkit `blender` registry entry therefore defaults to
  `approval: explicit`, loopback only, and the motion-graphics skill requires
  explicit authorization plus an allowed project directory. Not yet executed
  end-to-end in this evaluation (headless `bpy` render was tested instead).

### Optional — `ahujasid/mcp-for-blender`

- Revision `a5a8acf2c6ae44a73670e0caf34663f16456d645` (2026-11-18), MIT.
  Community add-on; nine tools centred on `execute_blender_code` (arbitrary
  Python in a live Blender). Same high-risk class. Documented as an
  alternative, not the default. Not executed.

### Core (no MCP needed) — Blender headless (`blender -b --python`)

- **Tested on host:** scripted scene (animated cube, material, camera, sun)
  saved as `.blend`, still rendered with EEVEE (`BLENDER_EEVEE` on 5.3),
  file reopened and verified. This is the deterministic fallback when no
  interactive Blender session is wanted.

## Image and illustration

### Recommended — `gimp-mcp/gimp-mcp`

- Revision `f25a74a5ced0586adb49d64692f4f465a391404c` (2026-11-21),
  GPL-3.0. 80 tools, targets GIMP 3.2.x (host has 3.2.8). Layer-aware,
  XCF-preserving. Not yet executed; first candidate for the image workflow.

### Recommended — `jowinjohnchemban/kritapilot` (Krita)

- Revision `8a72d0bb7e7d6a6f2da036161ea006bb6fbb189c` (2026-11-22), MIT.
  98 tools + 7 workflow prompts, tested upstream on Krita 5.3.4 (host has
  6.0.4.1 — compatibility unverified). Not executed.

### Optional — `SanSaSane/krita-mcp`

- Revision `edc458d5c1e8990454a9da5c616dbc3c8b55821f` (2026-10-23), CC0.
  31 operations, Krita 5.2+/5.3.3. Smaller surface; fallback if KritaPilot
  does not support Krita 6. Not executed.

### Recommended — `aravindev/inkscape_mcp`

- Revision `1b99ff8a2de0671d92ac09077f96acaf1d1a6dfc` (2026-11-09), MIT.
  Eight portmanteau tools; headless CLI mode needs no GUI, live mode drives
  a running Inkscape over D-Bus (1,000+ actions) with normal undo entries.
  SVG stays the editable source. Not executed.

## Recording and audio

### Recommended — `aaronckj/obs-studio-mcp`

- Revision `599b382d97ab554bc21951b725bef3faf3085779` (2026-07-28), MIT.
  obs-websocket v5 (built into OBS 28+; host has 33.0.1). Every mutating
  tool accepts `dry_run=true` — a strong safety property. Recording/streaming
  must still require explicit user action; never auto-enable. Not executed.

### Optional — `itznan/obs-mcp`

- Revision `86000d65ce434079ee91ace36a453864a2f438c0` (2026-10-27).
  156 tools (or 12 compound), TS + Python engines, event ring buffer,
  vision inspection. Broader than needed; larger context cost. Not executed.

### Recommended — `danishaft/reaper-mcp`

- Revision `b4c0487010ff5d5033ce37484da6a56b9c6a8f27` (2026-08-05), MIT.
  172 tools, Python server + ReaScript bridge, `uv tool install
  danishaft-reaper-mcp`. REAPER is proprietary and stays explicit opt-in
  (HorneroOS catalogue already treats it that way). `.rpp` projects remain
  the editable source. Not executed.

## Media processing and AI

### Optional (beta) — `Comfy-Org/comfy-mcp`

- Revision `105dca212a90a723d360f737f8f2a0f5b815e37f` (2026-11-19),
  dual-licensed. 42 tools shelling out to `comfy --where local`. Official
  org, beta status. GPU/VRAM-heavy: optional, never installed by default,
  no automatic model downloads. Not executed (ComfyUI not installed).

### Core-enabling libraries (install on demand, never by default)

| Tool | Role | Host status |
|------|------|-------------|
| faster-whisper / WhisperX | Transcription, word timing, diarization | Not installed — model download requires explicit approval |
| PySceneDetect | Scene-change detection | Not installed (small, CPU-only; first addition) |
| Auto-Editor | Silence-based rough cuts | Not installed |
| DeepFilterNet / Demucs | Speech cleanup / stem separation | Not installed (GPU) |
| OpenTimelineIO | Timeline interchange | Library only; adopt when a second editor needs it |
| Real-ESRGAN / RIFE | Upscale / interpolation | Deferred — specialized, GPU-heavy |
| Remotion | Programmatic video (React) | Deferred — `brag`/Hyperframes already covers launch videos |

### Evaluated and deferred

Natron, OpenToonz, Darktable and RawTherapee are already in the HorneroOS
Studio catalogue as applications, but none offers a maintained MCP or
scripting bridge comparable to the above; they remain manual-application
support only until that changes.

## Decision summary

| Capability | Adopt now | Class |
|------------|-----------|-------|
| Video editing | `mhbxyz/kdenlive-mcp` (`mcp-kdenlive`) | Core, tested |
| Media inspection/audio | FFmpeg/ffprobe/MLT directly | Core, tested |
| Motion/3D | Blender headless now; Blender Lab MCP next (high-risk gate) | Core tested / Recommended |
| Image | GIMP MCP, Inkscape MCP, KritaPilot | Recommended, untested |
| Recording | `aaronckj/obs-studio-mcp` (dry-run default) | Recommended, untested |
| DAW | `danishaft/reaper-mcp` (opt-in, proprietary app) | Recommended, untested |
| Generative image | ComfyUI MCP | Optional, untested |
| Transcription/scenes | faster-whisper, PySceneDetect on demand | Optional, not installed |
