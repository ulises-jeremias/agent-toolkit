---
name: video-analysis
description: Evidence-backed video understanding — ffprobe metadata, scene-cut detection, silence detection, frame extraction, speech transcription with timestamps, and a source index an editor can trust. Use before any edit decision; never invent timestamps or scene content.
origin:
  type: first-party
triggers:
  - analyze video
  - transcribe
  - scene detection
  - find highlights
  - video metadata
  - subtitles from speech
---

# Video Analysis

Everything you report must point at measured evidence: a probe value, a
detected boundary, a transcript segment with real start/end times, or an
extracted frame you actually looked at.

## Pipeline

1. **Metadata** — `ffprobe -show_streams -show_format` (or Kdenlive MCP
   `probe_media`): duration, resolution, codecs, fps, audio channels.
2. **Scene index** — PySceneDetect (`scenedetect`) when installed; else
   FFmpeg `select='gt(scene,0.4)'` scene scores. Record cuts as
   `(start, end, evidence)` rows in `analysis/scene-index.json`.
3. **Silence** — FFmpeg `silencedetect` for pause/dead-air mapping.
4. **Frames** — extract one representative frame per scene
   (`ffmpeg -ss <t> -frames:v 1`) into `analysis/frames/` for visual review.
5. **Speech** — faster-whisper (word timings; WhisperX when diarization is
   required) only when the model is already present or the user approves
   the download. Output SRT/VTT + JSON segments under `analysis/`.
6. **Moments** — combine transcript statements, scene boundaries and
   silence gaps into candidate ranges; each candidate cites its evidence.

## Rules

- No transcription tool installed → no subtitles. Report the gap; never
  fabricate speech or timings.
- Vision-model scene descriptions are labelled as model output with the
  frame they describe; measured facts stay separate.
- Keep analysis artifacts inside the project (`analysis/`); sources stay
  untouched. Analysis is cacheable and resumable per source file.
- Large models (Whisper large, diarization) need explicit approval and a
  resource check (VRAM/RAM/disk) before download or execution.
