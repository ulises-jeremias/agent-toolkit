---
name: creative-studio
description: Orchestrate an AI-managed creative production across real applications (Kdenlive, Blender, GIMP/Krita/Inkscape, OBS, REAPER, FFmpeg) — discover what is actually available, pick the right tool per step, preserve editable projects, and verify every output. Use for trailers, tutorials, demos, shorts and any multi-application media request.
origin:
  type: first-party
tools:
  - kdenlive
  - blender
  - gimp
  - krita
  - inkscape
  - obs
  - reaper
  - comfyui
triggers:
  - creative studio
  - make a trailer
  - edit this video
  - produce a video
  - multimedia production
  - AI video editing
---

# Creative Studio — orchestration

You coordinate real creative applications through MCP servers and local
tools. You never reimplement a video editor, DAW or graphics engine, and you
never flatten work that should stay editable.

## First: discover, don't assume

1. Run the Kdenlive MCP `diagnose_environment` tool (or `kdenlive-mcp
   diagnose`) and check `ffmpeg`/`ffprobe`/`melt`/`blender` on PATH.
2. Classify each integration honestly: `available`,
   `installed-not-configured`, `configured-unavailable`, `unsupported`,
   `experimental`, `ready-verified`, `failed`, `interrupted`.
3. Degrade gracefully: a missing Blender never blocks a tutorial edit; a
   missing transcription model means "no subtitles yet", not invented ones.

## Project model (create before editing)

```
<project>/
  project.json        # manifest: sources, operations, artifacts, provenance
  sources/            # references only — originals are never modified
  analysis/           # probe output, transcripts, scene index, thumbnails
  edit/               # native projects (.kdenlive, .blend, .xcf, .kra, .rpp)
  assets/             # generated graphics/audio (editable sources + exports)
  preview/            # preview renders
  export/             # final deliveries
  qa/                 # verification reports
```

Follow XDG for caches (`$XDG_CACHE_HOME`) and never assume a home layout.
Every path is validated (symlinks resolved, no traversal outside the
project or the MCP allowed roots). After each operation, append to
`project.json`: source used, tool, parameters, result, artifacts created,
which artifacts stay editable, and how to recover. A new session must be
able to reopen `project.json` and continue.

## Orchestration loop

1. **Inspect** sources (`video-analysis`): metadata, scenes, speech, silence.
2. **Plan** a storyboard from real timestamps only. Show it when the edit is
   long, destructive or materially changes the request.
3. **Build** the native project (`video-editing`, `motion-graphics`,
   `image-editing`, `audio-production` as needed).
4. **Preview** at low cost; inspect with measurable checks (`media-qa`).
5. **Revise** iteratively — never regenerate the whole project for a local fix.
6. **Export** finals, verify them, and write the delivery report.

## Routing

| Need | Skill | Primary tool |
|------|-------|--------------|
| Understand footage | `video-analysis` | ffprobe, PySceneDetect, faster-whisper |
| Cut/assemble video | `video-editing` | Kdenlive MCP |
| Titles, logo animation, 3D | `motion-graphics` | Blender (headless or Lab MCP) |
| Thumbnails, compositing, SVG | `image-editing` | GIMP/Krita/Inkscape MCP |
| Voice, music, loudness, DAW | `audio-production` | FFmpeg, REAPER MCP |
| Launch/promo video from a website | `content-production` → `design/brag` | Hyperframes via brag |
| Verify any output | `media-qa` | ffprobe + objective checks |

A single agent can run a simple workflow end to end. Specialist agents
(`creative-director`, `video-editor`, `motion-designer`, `audio-engineer`,
`visual-designer`, `media-qa-reviewer`) are an enhancement, not a requirement.

## Hard rules

- Source media is read-only. Outputs never overwrite an existing file.
- No invented timestamps, scenes, subtitles or progress values.
- High-risk execution (Blender Python, arbitrary scripts) needs explicit
  authorization and a bounded project directory.
- Never auto-enable recording, streaming, microphone, paid services or
  large model downloads.
- Report per-tool status truthfully; "not verified" is a valid answer.
