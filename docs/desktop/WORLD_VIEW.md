# World View — Workshop Metaphor

> **EPIC #1013 — World View + game presentation** — Workshop vertical slice.
> `modules/desktop/world/` — `V 0.5.2`, `VMODULES=modules`, `import json`, single-repo-one-binary `1.27.0`, `make.vsh` + `gen-embedded`, `docs/ARCHITECTURE.md` planes.

## Why Workshop, not Office

`https://github.com/chaitanyagiri/munder-difflin` (The Office) is **UX inspiration only** — GPL-2.0.  
Desktop **must not** copy its layout, assets, characters, or sprite packs. Reference is limited to:

- learning that a spatial office metaphor can make system topology legible
- adopting the lesson that distinct zones (desk / conference / break-room) help users orient

**Workshop is toolkit-native** — a workbench, dock, and harness frame:

| Zone | Workshop element | Future station |
|------|------------------|----------------|
| Workbench | central canvas with harness frame | entity graph (repos/skills/agents/loops/jobs/handoffs) |
| Library alcove | north-east shelves | `catalogs/skill-catalog.yaml` (116 skills) + 18 agents + 7 packs |
| Diagnostics bench | south-west lamp/gauge bench | `agent-toolkit doctor` checks (tool/profile/digest/receipt/FHS) |
| Target rigs | south rig wall | `profile/*` (claude-code/cursor/opencode/pi/windsurf/cursor-plugins) |
| Swarm Room doorway | east doorway | `swarm_state/` handoffs, approvals, budget, trace |
| Activity wall | north journal wall | `ToolkitEvent` timeline (commit/loop tick/job log/handoff) |
| Dock harness | top frame + splitter chrome | `shell.DockLayout` (persisted derived) |

All zones are **derived projections** — `Engine.State` (canonical) → `StateWatcher` → `ToolkitEventBus` (typed, replay) → `AppState` → `WorldView` within one `EventBus→frame` tick. No second SQLite source of truth; derived SQLite only for UI expansion prefs per #1031.

## No Fake Gamification

Motion communicates **real work**:

- `node add/remove/move` = real `State` diff (`Engine.world_projection()` distinct-until-changed + debounce)
- `process_log` → conduit tick is real `ProcessSupervisor` streaming
- `doctor_fail` → lamp pulse is real `DoctorCheck.status`
- `handoff flight` → swarm room edge animation is real `swarm_changed` DAG

No `points`, `coins`, `level up`, `XP` economy — `grep -r "points|coins|level up|XP" modules/desktop/world` must be empty. Shelves fill proportionally to real catalog (587 lines → ~116 nodes). Rigs wear reflects receipt age/digest, not player stats. Audio is a **single chime** on `job done / install done / doctor fixed / handoff` only when user opts in (muted by default, `sokol/audio`); no background music (`grep -r "\.mp3|\.wav.*loop|background_music" modules/desktop/world/presentation` empty beyond one <20KB chime).

## Rendering Contract

`AppState` projection → `vlang/gui` Canvas `on_draw` **retained geometry buffer**:

- primitives: `polyline` / `filled-polygon` / `arc` + `text` (measurement/rotation/clipping via `desktop.theme.measure_text` → `vglyph`/`gg`/`Pango`/`HarfBuzz` path)
- mouse `hit_test` + cursor (`pointer`/`grab`/`default`) + floating tooltip overlay
- zoom/pan (wheel+drag), window resize does **not** black retained buffer (hash stable across frames)
- gradients/shadows/blur only where `vlang/gui` supports — no custom GL shim
- culling + LOD + clustering stub for 100+ nodes (full 1000+ stress in 6.5 follow-up)
- virtualized lists (1000+ rows, 5k events): viewport `visible_range` + row pool keeps draw calls bounded
- 60 FPS retained: `WorldPerfHarness` 100-node workshop sample `>=58 FPS` sustained; `agent_toolkit_gui.PerfHarness` 1000-widget `60 FPS` canonical harness
- `reduced-motion` collapses tweens/springs to instant (`MotionTokens.effective_duration → 0`), light/dark via design tokens #1017

## Plane Guard & Version

- `V 0.5.2` pinned (`.v-version`, `setup-v`), `import json` (not `json2` where contract requires)
- `vlang/gui` only in `desktop/` — plane guard `! grep -r "import.*gui" modules/desktop_engine` must pass
- `desktop` imports `agent_toolkit_core` via `desktop_engine`, never reverse (plane guard)
- `make.vsh` + `gen-embedded` verify embedded vector sprites (`assets/world/sprites.json`, <100KB headless stub) and `VERSION 1.27.0` channel

## References

- `https://github.com/vlang/gui/blob/main/examples/snake.v` (canonical game canvas `on_draw`)
- `https://github.com/chaitanyagiri/munder-difflin` — UX inspiration only, no assets/characters
- `https://github.com/qptorrent/qptorrent` — GUI + workers + SQLite + channels pattern for derived projections
- `docs/ARCHITECTURE.md` Capability vs Runtime planes, `docs/desktop/PACKAGING.md`, `docs/desktop/WINDOWS.md`, ROADMAP Canvas `[x] on_draw` ✅
