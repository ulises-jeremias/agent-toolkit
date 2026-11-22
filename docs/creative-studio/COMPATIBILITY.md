# Creative Studio — compatibility (evidence-backed)

Last updated: 2026-11-22. States follow ADR-046. "Verified" means executed
on the evaluation host (HorneroOS/Arch, RTX 3060); anything else is
source-inspected only.

## Integrations

| Integration | App versions (host) | Status | Evidence |
|-------------|---------------------|--------|----------|
| Kdenlive MCP (`mcp-kdenlive` @ 9abcf94) | Kdenlive 26.08.3, MLT 7.42.0, FFmpeg n9.1 | ready-verified | diagnose=ready; upstream vertical-short demo: editable .kdenlive + 1080×1920 H.264/AAC render, all objective checks pass |
| FFmpeg loudnorm/volumedetect | FFmpeg n9.1 | ready-verified | fixture −21.05 → −15.95 LUFS (target −16), originals unchanged |
| Blender headless (`-b --python`) | Blender 5.3.0 (EEVEE id `BLENDER_EEVEE`) | ready-verified | animated scene saved as .blend, still rendered, file reopened |
| Blender Lab MCP @ dbbf836 | Blender 5.3.0 | experimental | source-inspected; high-risk Python execution gate; not yet run |
| GIMP MCP @ f25a74a | GIMP 3.2.8 | experimental | source-inspected; not yet run |
| KritaPilot @ 8a72d0b | Krita 6.0.4.1 (upstream tested 5.3.4) | experimental | source-inspected; version gap; not yet run |
| Inkscape MCP @ 1b99ff8 | Inkscape 1.4.4 | experimental | source-inspected; not yet run |
| OBS MCP (aaronckj) @ 599b382 | OBS 33.0.1 (obs-websocket v5) | experimental | source-inspected; dry_run supported; not yet run |
| REAPER MCP @ b4c0487 | REAPER installed (proprietary, opt-in) | experimental | source-inspected; not yet run |
| ComfyUI MCP @ 105dca2 | ComfyUI not installed | unsupported (locally) | beta upstream; install is opt-in, no auto model downloads |
| faster-whisper / PySceneDetect | not installed | installed-not-configured path documented | install on demand with explicit approval |

## Agent clients

| Client | Status | Notes |
|--------|--------|-------|
| Muse | ready-verified (Kdenlive MCP via stdio driver) | This session drove the server over stdio (tools/list + demo client) |
| Claude Code / Codex / OpenCode | experimental | Upstream kdenlive-mcp client matrix reports passes; re-verify per client before claiming |
| Veasel | experimental | Consumes Agent Plugins + MCP natively; Creative Studio package validation pending (Phase G) |
| Cursor / others | not yet verified | Standard stdio MCP expected; no claim made |

## Platforms

Linux is the verified platform (Kdenlive MCP is Linux-only upstream).
macOS/Windows: skills degrade to FFmpeg/Blender-headless paths; no claim
beyond that until tested.
