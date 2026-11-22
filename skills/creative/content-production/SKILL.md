---
name: content-production
description: Reusable content recipes — YouTube tutorials, product demos, release trailers, walkthroughs, short-form clips and thumbnails — composed from the creative skills, extending brag for launch videos instead of competing with it.
origin:
  type: first-party
triggers:
  - youtube tutorial
  - product demo video
  - release trailer
  - walkthrough video
  - short-form clip
  - content production
---

# Content Production

Recipes compose `creative-studio` skills; they add pacing, structure and
delivery checklists, not new tooling.

## Launch / promo video from a website or app

Delegate to **`design/brag`** (or `design/brag-slim`). It already turns a
project into a polished Hyperframes launch video. Do not build a second
launch-video pipeline. Use this skill only to add what brag does not do:
real screen recordings, voiceover production, or a Kdenlive re-edit.

## Tutorial / walkthrough (Kdenlive)

1. Script from verified behaviour only — record or capture the real UI
   (OBS, explicit start). Never invent features or screenshots.
2. `video-analysis` on the capture → chapters from real timestamps.
3. `video-editing`: hook (≤10 s) → steps with titles → recap; narration on
   A1, music bed −18 dB under speech, subtitles from the transcript.
4. `image-editing`: thumbnail (native layered source + export).
5. `media-qa` gate, then export (1080p master + platform variants).

## Release trailer (60–90 s)

Derive claims from the actual changelog/release and working software.
Storyboard first (`creative-director` when delegated), motion titles via
`motion-graphics`, edit in Kdenlive, loudness −14 LUFS, captions on.

## Short-form (vertical)

Reframe, don't letterbox: vertical profile, centre-crop or tracked crop,
burned captions from a real transcript, 1080×1920 export, first frame must
read as a thumbnail.

## Audio-only

`audio-production` end to end: cleanup → loudnorm → chapter markers →
export + loudness report.

## Delivery checklist (every recipe)

Editable native projects preserved · exports verified (`media-qa`) ·
subtitles real or explicitly absent · thumbnail source kept · manifest
and QA report written · no fabricated claims about the product.
