---
name: audio-production
description: Audio inspection, loudness, cleanup and DAW workflows — FFmpeg loudnorm/volumedetect for measurable processing, REAPER (via MCP) for real sessions, OBS for capture. Preserves originals and native .rpp projects; never enables recording or microphones silently.
origin:
  type: first-party
tools:
  - reaper
  - obs
triggers:
  - audio production
  - loudness
  - reaper
  - voiceover
  - normalize audio
  - record screen
  - obs
---

# Audio Production

## Measurable processing (FFmpeg, no MCP required)

1. **Inspect**: `ffprobe` streams + `volumedetect` (mean/max volume).
2. **Loudness**: two-pass `loudnorm` (EBU R128). Measure first with
   `print_format=json`, then apply; report input/output LUFS and true peak.
   Targets: −16 LUFS (podcast/online voice), −14 LUFS (YouTube), or the
   brief's target — state which one you used.
3. **Cleanup**: `afftdn`/`anlmdn` denoise, `highpass`, `acompressor`,
   `alimiter` — one bounded change at a time, A/B by measurement.
4. Write processed files next to (never over) the originals; verify the
   numeric difference before claiming improvement.

## DAW sessions (REAPER)

`danishaft/reaper-mcp` (MIT, 172 tools, ReaScript bridge) drives a real
REAPER session: tracks, items, FX parameters, renders. REAPER is
proprietary — explicit opt-in only, licensing respected. The `.rpp` file
is the editable deliverable; work on a copy and never overwrite the user's
session or templates. Personal hardware routing (interfaces, monitoring)
stays in local configuration, never in shared defaults.

## Capture (OBS)

`aaronckj/obs-studio-mcp` (MIT) talks to obs-websocket v5; every mutating
tool supports `dry_run=true` — preview first. **Never** start recording,
streaming or microphone capture without an explicit user action for that
session. On Wayland, screen capture goes through the portal; report portal
or PipeWire failures instead of working around them with elevated capture.

## Sync with video

Align narration/music to the timeline in Kdenlive (`video-editing`), then
verify sync in `media-qa` (audio/video durations, offset checks). Music
beds get volume automation/fades, not hard cuts under speech.
