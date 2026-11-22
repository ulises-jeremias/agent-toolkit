---
name: media-qa
description: Objective verification for media deliverables — codec/resolution/duration checks, loudness, black/freeze frames, A/V sync, subtitle sanity, native-project reopen tests and source-preservation proofs. Use before any delivery claim.
origin:
  type: first-party
triggers:
  - verify render
  - media qa
  - check export
  - validate video
  - qa report
---

# Media QA

A render exiting 0 is not a pass. Every check below produces a measured
value that goes into `qa/report.md` (and the project manifest).

## Video checks

- `ffprobe`: video/audio codecs, width×height, fps, duration vs timeline
  expectation (≤0.2 s drift), audio presence and sample rate.
- Black/freeze: `blackdetect` and `freezedetect` filters; sample frames at
  scene midpoints and confirm non-black, expected content.
- Titles/captions: frames at title in/out points show/hide correctly.
- A/V sync: compare audio and video stream durations; spot-check a known
  event (speech onset vs visible action) when narration exists.

## Audio checks

- Integrated loudness and true peak vs the stated target (`loudnorm`
  measurement pass); clipping scan (`astats` peak level).
- Silence where speech is expected is a failure, not a style choice.

## Project checks

- Native projects reopen without repair prompts: Kdenlive
  `inspect_project`, Blender headless open, `.rpp`/`.xcf`/`.kra` parse/open.
- Sources unchanged: checksums (or size+mtime) of every input before/after.
- No output overwrote an existing file; partial/failed renders are labelled
  partial and never presented as finals.

## Negative cases (must be exercised, not just described)

Missing input file · output path already exists · path outside allowed
roots · unsupported codec/profile · interrupted render · tool not
installed. Each must fail loudly with an actionable message.

## Reporting

Separate **unit-tested**, **integration-tested**, **host-tested**,
**GUI-tested** and **not yet verified**. Missing evidence is reported as
missing — never converted into success.
