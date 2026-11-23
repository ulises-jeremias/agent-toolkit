# Creative Studio — compatibility (evidence-backed)

Last updated: 2026-11-23. States follow ADR-046. "Verified" means executed
on the evaluation host (HorneroOS/Arch, RTX 3060); anything else is
source-inspected only. Statuses: `ready-verified`, `verified with
limitations`, `experimental`, `unavailable`, `incompatible (suspected)`,
`deferred`.

## Integrations

| Integration | App versions (host) | Status | Evidence |
|-------------|---------------------|--------|----------|
| Kdenlive MCP (`mcp-kdenlive`, PyPI 0.3.0; source @ 9abcf94) | Kdenlive 26.08.3, MLT 7.42.0, FFmpeg n9.1 | ready-verified | diagnose=ready; editable .kdenlive projects + validated renders (vertical short, cross-app production, subtitle import); sources unchanged; projects reopen |
| FFmpeg loudnorm/volumedetect | FFmpeg n9.1 | ready-verified | fixture −21.05 → −15.95 LUFS (target −16), originals unchanged; committed pytest |
| Transcription (faster-whisper `small`, CPU int8) | faster-whisper 1.2.1, model `small` (464 MB, user-approved download) | ready-verified | JFK speech fixture transcribed exactly with word timestamps; SRT imported into Kdenlive (sidecar .ass, 1 event verified) and rendered (11.008 s, validation ok). Note: PyAV ≥15 breaks faster-whisper 1.2.1 audio decode — decode via ffmpeg to 16 kHz WAV first |
| Blender headless (`-b --python`) | Blender 5.3.0 (EEVEE id `BLENDER_EEVEE`) | ready-verified | animated scene + title card saved as .blend, rendered, reopened |
| Inkscape MCP (`inkscape-mcp` 2.0.0, headless) | Inkscape 1.4.4 | ready-verified (headless) | diagnostics pass; info/validate/objects on a real SVG; convert → PNG 400×200 verified; source SVG unchanged. Live D-Bus mode not run |
| Blender Lab MCP @ dbbf836 | Blender 5.3.0 | experimental | source-inspected; high-risk Python execution gate; interactive session not yet run |
| GIMP MCP @ f25a74a | GIMP 3.2.8 | experimental (not yet verified) | plug-in installed into an isolated HOME; needs a graphical GIMP session (or Xvfb, absent on host) for its socket server — not run to avoid touching the user's live desktop |
| KritaPilot @ 8a72d0b | Krita 6.0.4.1 (upstream tested 5.3.4) | incompatible (suspected) | major-version gap vs upstream-tested Krita; not loaded — do not force; needs upstream Krita 6 evidence first |
| OBS MCP (aaronckj) @ 599b382 | OBS 33.0.1 (obs-websocket v5) | experimental (not yet verified) | source-inspected; dry_run supported; needs a running OBS with explicit user-started session |
| REAPER MCP @ b4c0487 | REAPER installed (proprietary, opt-in) | experimental (not yet verified) | source-inspected; needs running REAPER + ReaScript bridge; only disposable projects may be used |
| ComfyUI MCP @ 105dca2 | ComfyUI not installed | deferred | beta upstream; optional; no automatic model downloads |
| PySceneDetect | not installed | deferred | small CPU-only install; add on demand for scene indexes at scale |

## Agent clients

| Client | Status | Notes |
|--------|--------|-------|
| Muse | ready-verified (Kdenlive + Inkscape MCP via stdio drivers) | Full edit/render/subtitle flows executed from this client |
| Veasel (dev build of `fix/skill-frontmatter-compat`) | verified with limitations | Plugin link discovers 8 creative skills + kdenlive MCP after the frontmatter fix (veasel-labs/veasel#798); configured MCP initializes and its tools load; session trust + per-call approval API verified. Full agent-driven edit **not** completed: local 8B models (qwen3:8b, llama3.1:8b via Ollama) did not reliably invoke MCP tools (calls emitted as text / delegation loops). Needs a tool-capable model (maintainer's configured provider key was not reachable from the test process). Bubblewrap sandbox also hides `$HOME`-installed MCP servers and the workspace — veasel-labs/veasel#799 |
| Claude Code / Codex / OpenCode | experimental | Upstream kdenlive-mcp client matrix reports passes; re-verify per client before claiming |
| Cursor / others | not yet verified | Standard stdio MCP expected; no claim made |

## Platforms

Linux is the verified platform (Kdenlive MCP is Linux-only upstream).
macOS/Windows: skills degrade to FFmpeg/Blender-headless paths; no claim
beyond that until tested.
