# Flagship: first HorneroOS product video (prepared, not yet produced)

Status: **prepared workflow + capture plan**. The synthetic cross-application
pipeline is proven (Blender title + loudnorm music + Kdenlive timeline +
verified render, 2026-11-22 evaluation). The cinematic video itself needs
real HorneroOS footage that does not exist yet — this document is the exact
recording and production plan. Nothing here invents scenes or features.

## Target

60–90 s, 1080p (16:9 master) + 1080×1920 short cut, YouTube-ready
(H.264/AAC, −14 LUFS, captions), editable `.kdenlive` master project.

## Footage to record (OBS, explicit start, Wayland portal)

Record at native resolution, 60 fps capture → 30 fps timeline, lossless-ish
(`obs` MKV, then remux). One take per scene, 10–20 s handles each side:

| # | Scene | Must show (real behaviour only) |
|---|-------|----------------------------------|
| 1 | Cold boot → greeter → desktop | Actual boot/login on the target machine |
| 2 | Desktop tour | Shell, launcher, workspaces, a theme switch |
| 3 | Control Center | One real settings change and its visible effect |
| 4 | Terminal + horneroctl | `horneroctl studio doctor`, one real studio job |
| 5 | Studio moment | Kdenlive or Blender actually opening a project |
| 6 | Companion (optional) | Only if present and working on the machine |
| 7 | Installer (VM only) | Disposable VM per HorneroOS/qa procedures — never the host |

Also capture: 30 s of clean desktop ambience (no action) for transitions,
and narration takes (quiet room, close mic) once the script is locked.

## Production workflow (Creative Studio skills)

1. `creative_project.py init` + `add-source` for every take (sources are
   referenced, never modified).
2. `creative/video-analysis`: probe, scene index, silence map; transcribe
   narration only after an approved faster-whisper install (word timings →
   real subtitles; no transcript = no captions claim).
3. Storyboard from measured timestamps; human review gate before the edit.
4. `creative/motion-graphics`: Blender intro/outro from official HorneroOS
   brand assets (from the HorneroOS repos — never regenerated look-alikes);
   `.blend` preserved.
5. `creative/video-editing`: assemble in Kdenlive via MCP; titles on a
   dedicated track; narration A1, music A2 with fades.
6. `creative/audio-production`: narration cleanup + loudnorm −14 LUFS.
7. `creative/image-editing`: thumbnail (layered source + export).
8. `creative/media-qa`: full objective gate + visual review of sampled
   frames; reopen every native project.
9. Deliverables: `.kdenlive` + `.blend` + thumbnail source, final MP4s,
   subtitles (if transcribed), `project.json` manifest, QA report,
   reproduction notes.

## Not complete until

The files above exist, are verified, and a human has watched the final
render end-to-end for pacing, claim accuracy and brand consistency.
