# ADR-032 — Desktop GUI framework: vlang/gui wrap decision (Phase 0 spike #1018)

- **Status:** Accepted (2026-08-31) — closes #1018 Phase 0 spike (0.1–0.5)
- **Deciders:** ulises-jeremias (owner) + toolkit maintainers
- **Related issues:** EPIC #1007 (Phase 0), #1018 (spike), EPICs #1008–#1015, #279, ADR-031 (V master)
- **Supersedes:** n/a — first Desktop GUI framework decision (0.2–0.4 gate)
- **Amends:** ADR-009 (module architecture), ADR-015/026 (runtime/embedded), ADR-030 (binary-first contract)

## Context

Agent Toolkit must ship a native Desktop (single-repo-one-binary, `VMODULES=modules`,
`make.vsh → build/agent-toolkit`, `gen-embedded`, `VERSION 1.27.0 @ 6807f29`,
Capability vs Runtime planes per `docs/ARCHITECTURE.md`, V canonical `import json`
not `json2`, no shipped TUI per ADR-030). Desktop EPICs #1009–#1015 (shell, docking,
World View, packaging) are blocked on a validated GUI framework. `vlang/gui`
(https://github.com/vlang/gui — `README`, `docs/ROADMAP.md`, `docs/WINDOWS.md`,
`examples/dock_layout.v`, `examples/snake.v`) is the candidate that keeps one native
binary over Sokol (`vlib/sokol` / `vlib/gg`) without adding Electron/Tauri/Flutter/Qt
(OUT per #1007). `vlang/gui` is not yet vendored — spike is mandatory. The toolchain
is `V master` (ADR-031: `.v-version == master`, `78e581e`, `V 0.5.2 51bda99` fallback
only on Windows; `setup-v` clones `vlang/v@master && make`), so the spike must validate
on `V master` across `vlib/x/async`, `vlib/eventbus`, `vlib/db/sqlite`, `vlib/context`,
`vlib/sync`, `sokol/audio`, `gg`, `vglyph`.

Spike 0.1–0.5 scoped:

- **0.1** hello-world + 1000-widget 60 FPS harness (`modules/agent_toolkit_gui`)
- **0.2** widget gap matrix (docking/drag-targets, canvas `on_draw` + retained geometry,
  data-grid/table, virtualized list/tree, markdown + syntax-highlighted code,
  menus/menubar/tabs/splitters/dialogs)
- **0.3** native surface probe (open/save/folder dialogs, clipboard, DnD,
  toasts/native notifications, IME/CJK, BiDi/ligatures/emoji, Unicode/OpenType,
  text measurement/rotation, high-DPI + Windows limits per `vlang/gui/docs/WINDOWS.md`)
- **0.4** this ADR (adopt / wrap / fallback, threading, SVG/shader, animation)
- **0.5** build-toolchain (`VMODULES` vendoring, `VJOBS=2 ./make.vsh vet|test` green)

## Options

### 1. Adopt vlang/gui as-is (direct use, no wrapper)

Use `vlang/gui` widgets exactly as shipped; build Desktop screens directly on its
layout/dialog/menu primitives. Any missing widget (grid, markdown, virtualization)
is built as `vlang/gui` contributions upstream.

**Pros:** Minimal local code; upstream stays single source; bug fixes flow automatically.

**Cons:** Upstream `ROADMAP` lists docking as experimental, grid/markdown/DnD/notifications
as missing, and Windows quirks (MSVC, D3D11, IME/DPI) as partial. Direct adoption would
block Desktop on upstream feature timing and on breaking `master` churn. No isolation
layer for renderer/threading policy.

**Verdict:** Rejected — gap matrix shows two ❌ + eight ⚠️; direct adoption cannot meet
EPIC #1009 docking + grid + markdown + notifications without waiting.

### 2. Wrap vlang/gui (thin abstraction + canvas fallbacks) — SELECTED

Adopt `vlang/gui` for what it does well (Window, flexbox row/column, `on_draw`,
`snake.v` canvas, text measurement, `sokol` DPI/clipboard/IME), and **wrap** the gaps
behind a thin `agent_toolkit_gui` layer: docking chrome + drag-target layer + splitter
gestures + tab bar, retained geometry buffer + culling, virtualized list/tree viewport
pool, markdown → styled text runs + external highlighter, in-app menu/overlay/dialog
primitives, canvas-composed grid, in-app toast fallback for native notifications, and
`vglyph`/shaping shims for BiDi/ligatures/emoji/OpenType. The wrapper owns no GL
pipeline; it composites via `on_draw` + `sokol` primitives.

**Pros:**
- Keeps one native `sokol`/`gg` renderer (no second toolkit per #1007 OUT).
- Windows/missing widgets are isolated behind one module; upstream bumps stay
  mechanical (pin in `modules/gui` via `git subtree`/`submodule`).
- Headless `PerfHarness.run_headless` validates 1000 widgets @ 60 FPS (58+ sustained,
  `max_dt < 33 ms`) without `DISPLAY` — CI can gate before any window exists.
- Threading and animation policy can be enforced centrally (see Decision).

**Cons:**
- One extra abstraction to maintain (`agent_toolkit_gui`); contributors must go
  through the wrapper for docking/grid/markdown rather than calling `gui` directly.
- Wrapper must enforce “core never imports gui” (`check-planes` grep) to keep the
  `desktop_engine` headless seam.

### 3. Fallback — sokol/gg direct (or tauri/electron)

Bypass `vlang/gui`; build Desktop directly on `vlib/sokol` + `vlib/gg` (or adopt
Tauri/Electron with a webview). This was EPIC #1007’s rejected alternative.

**Pros:** Full control over renderer; no upstream dependency.

**Cons:** Reinvents layout, text, dock, and dialog primitives `vlang/gui` already
provides; Tauri/Electron violates single-binary native constraint and doubles the
toolchain (Node/Rust + V). Out of scope per #1007.

**Verdict:** Rejected — wrap is strictly cheaper while still native.

## Decision

**Adopt Option 2 — Wrap `vlang/gui`.**

### Module and build plan (`VMODULES`)

```
agent-toolkit/
  .v-version                 # master (ADR-031) — 78e581e baseline
  modules/
    agent_toolkit_core/      # never imports gui (plane guard)
    agent_toolkit_cli/       # thin adapter → core
    agent_toolkit_server/    # thin adapter → core (veb)
    agent_toolkit_gui/       # ← Phase 0 spike: feasibility harness (this ADR)
      v.mod
      gui.v                  # ping + spike_version
      feasibility.v          # GapEntry + gap_matrix_all + markdown (0.2)
      native.v               # native probe headless-safe (0.3)
      window.v               # GuiConfig + hello-world validate + vendoring_plan
      perf.v                 # PerfHarness 1000-widget 60 FPS (0.1) + artifact_json
      gui_test.v             # vet/test coverage for matrix + perf + probe
    gui/                     # ← Phase 1 vendoring of vlang/gui (NOT in this spike)
                             # git subtree add https://github.com/vlang/gui master
                             # pin SHA recorded here + .v-version SHA; update via PR
  make.vsh                   # mods = [core, cli, server, gui] — VJOBS=2 vet/test/green
  cmd/agent-toolkit/main.v   # same binary (gen-embedded → build/agent-toolkit)
```

Rules:

- **VMODULES placement:** vendor `vlang/gui` as `modules/gui` (or `modules/vlang_gui`
  if name collision; chosen `modules/gui` for shortest import `import gui`). Documented
  in `vendoring_plan()` and `docs/HOW_TO_DEVELOP_V.md`. No `v.mod` `dependencies: ['gui']`
  until vendored; then `agent_toolkit_gui` declares it.
- **Plane guard:** `modules/agent_toolkit_core` and `modules/desktop_engine` (future)
  must stay free of `import gui` / `import sokol` (CI `! grep -r 'import.*gui'` per
  #1018 §1.1). `check-planes` validates.
- **Single binary:** `make.vsh build-cli` (`gen-embedded` → `build/agent-toolkit`) stays
  canonical; Desktop embeds same `Engine` when GUI flag on. No second binary.
- **V canonical:** `import json` (not `json2`), `VMODULES=modules`, `V master`, `VJOBS=2`.

### Threading model (UI thread vs Engine threads)

- **UI thread owns `gui`/`sokol`.** The Sokol event loop and `on_draw` run on exactly
  one OS thread (main). No Engine or `x/async` task may call `gui` directly.
- **Engine threads own `StateRepository`, `ToolkitEventBus`, `StateWatcher`,
  `ProcessSupervisor`, `vlib/context` cancellation.** Engine work runs on worker
  threads via `vlib/sync` + `vlib/x/async` (evaluated, not canonical until spike
  #1026). Results are marshaled to the UI thread via a bounded `channel ToolkitEvent`
  / `EventBus` tick (distinct-until-changed, debounced). UI coalesces to one
  `AppState` projection per frame (≤ 60 Hz).
- **Lifecycle:** `Engine.new() → init() → start() → stop()` stays idempotent and
  `context`‑cancellable; `stop()` drains the UI channel. `V 0.5.2/master`
  `vlib/sync` primitives are sufficient — no external DI framework.
- **Why:** `sokol_app` requires main-thread affinity; cross-thread `gui` calls would
  race `gg`/`sokol_gfx`. The wrapper enforces `Engine → channel → UI` and
  `UI → Engine.enqueue(action)`.

### SVG / shader stance

- **Phase 0–1: no custom shader pipeline.** Use `vlang/gui` + `sokol`/`gg` primitives
  (`on_draw` polylines/filled polygons/arcs, text, scissor clipping) for all Phase 0–1
  visuals. SDF shadows, gradients, blur, and sprite vectors are composed via retained
  geometry + `vglyph`/`gg` until spiked.
- **SVG:** SVG assets are authored as vector defs (JSON) and rendered via `on_draw`
  polyline/polygon/arc (not a raster pack). No GPL asset copy from upstream demos.
  `gen-embedded` budget stays `< 100 KB` for vector defs.
- **Shader later:** if `vlang/gui` shader/SVG proves insufficient, introduce a single
  `sokol-shdc` cross-compiled SDF/shadow module *inside* `agent_toolkit_gui`, not a
  second renderer. Windows `D3D11` is auto-selected by `sokol` (no custom D3D).

### Animation stance (tweens / springs / keyframes)

- **Centralized `AnimationController` (future EPIC #1009) mapping `ToolkitEvent` diffs
  → motion:** `node_added → scale-in + spring`, `node_removed → fade+shrink`,
  `node_moved → hero morph (easeOutCubic)`, `layout reflow → constraint tween`,
  `process_log → conduit tick`, `doctor_fail → lamp pulse`. All durations from
  `MotionTokens` (see #1017 design tokens).
- **Reduced-motion:** `prefers-reduced-motion` (OS or `State` pref) → every duration
  collapses to `0`, springs become instant, end-state equals animated end-state.
  Verified headless: duration ≈ 0, no overshoot.
- **Honest motion:** animation duration is `real work duration` or a fixed token —
  never inflated for gamification (no points/coins/levels/background beat).

## Gap matrix (appendix): required widget → vlang/gui status + mitigation

> Rendered at runtime via `gap_matrix_markdown()` (feasibility.v). Snapshot:

| Required widget / surface | Status | Mitigation / fallback |
|---|---|---|
| Window + flexbox layout (row/column) | ✅ supported | Adopt as-is; vlang/gui Window + column/row + spacing (snake.v, dock_layout.v baseline) |
| Docking + drag docking targets + splitters + tabs | ⚠️ partial | Wrap: adopt gui dock_layout.v for chrome; custom drag-target layer + splitter gesture + tab bar; persist derived layout in SQLite (not canonical) |
| Canvas on_draw + retained geometry buffer (SDF/shadows/blur) | ⚠️ partial | Wrap: use on_draw for immediate mode; own retained buffer (geometry list + culling) atop sokol; SDF shadows via custom shader if needed |
| Data-grid / table (sortable, virtualized columns) | ❌ missing | Fallback canvas: virtualized row renderer + column layout in on_draw; reuse virtualized list harness; header sort via state filter |
| Virtualized list (1000+ rows, variable height) | ⚠️ partial | Wrap: viewport culling + row pool; measure via vglyph/Pango path; validate 1000-widget @ 60 FPS harness (perf.v) |
| Virtualized tree (collapsed/expanded nodes, 1000 nodes) | ⚠️ partial | Wrap: tree as virtualized list with indent + expand state in AppState; same culling as list |
| Markdown + syntax-highlighted code blocks | ❌ missing | Fallback: markdown parse → gui text runs (headings/bold/code) + external highlighter (e.g. tree-sitter or V highlighter) emitting styled spans; no webview |
| Menus / menubar / context menu | ⚠️ partial | Wrap: app-level menu bar via row + popup overlay; context menu is overlay with focus trap; keyboard shortcuts via sokol key events |
| Tabs + splitters + resizable panels | ⚠️ partial | Wrap: tab bar widget + splitter drag handle; flex weights updated via state; retained geometry for divider hit-test |
| Dialogs (in-app modal/alert/confirm) | ⚠️ partial | Wrap: modal overlay + focus trap + escape handling; reuses dialog primitives; not native yet |

### Native surface probe (0.3) — sub-table

| Native surface | Status | Mitigation |
|---|---|---|
| Native open / save / folder dialogs | ⚠️ partial | Adopt sokol native dialog helper + tinyfiledialogs fallback; Windows: use Win32 common dialogs (via sokol); vet on Linux headless returns stub without blocking |
| Clipboard (copy/paste text + code) | ⚠️ partial | Wrap sokol clipboard (text only); on Wayland/X11 verify via wl-copy/xclip bridge; headless stub returns empty without error |
| Drag-and-drop (files + text onto canvas) | ❌ missing | Fallback: sokol dropped-files event where available; Wayland DnD is protocol-limited; in-app reorder remains internal drag, not OS DnD |
| Toasts / native notifications | ❌ missing | Fallback in-app toast overlay (non-blocking, auto-dismiss, reduced-motion instant); native libnotify/WinToast later, not Phase 0 |
| IME / CJK input | ⚠️ partial | Wrap: rely on sokol IME composition events + vglyph shaping; test CJK composition on Linux/macOS; Windows IME via sokol_app composes partially |
| BiDi / ligatures / emoji / Unicode / OpenType | ⚠️ partial | Wrap: vglyph + HarfBuzz-equivalent via sokol font path; emoji as color glyphs where available; BiDi via fribidi-style pass; ligatures via OpenType shaping stub |
| Text measurement / rotation / clipping | ✅ supported | Adopt gg text measurement + vglyph metrics; rotation via canvas transform; clipping via sokol scissor |
| High-DPI / fractional scaling | ⚠️ partial | Adopt sokol dpi_scale + gui density; test fractional 125%/150% on Linux/Wayland; Windows high-DPI quirks per WINDOWS.md (DPI awareness manifest) |

### Windows limitations (per vlang/gui/docs/WINDOWS.md)

| Windows limitation (per vlang/gui/docs/WINDOWS.md) | Status | Mitigation |
|---|---|---|
| Windows MSVC requirement (master needs MSVC, not mingw) | ⚠️ partial | ADR-031 fallback: on Windows CI/setup-v falls back to V 0.5.2 artifact when master requires MSVC; local dev installs Visual Studio Build Tools; document in ADR |
| Windows D3D11 backend (sokol d3d11 vs OpenGL) | ⚠️ partial | Wrap: sokol auto-selects d3d11 on Windows; no custom GL pipeline; shader uses sokol-shdc cross-compile |
| Windows IME + high-DPI manifest + dialog theming | ⚠️ partial | Manual smoke on Windows required per acceptance; headless Linux CI skips native probe; ADR records manual checklist with screenshots |
| Windows file dialogs + clipboard + DnD sandboxing | ⚠️ partial | Common dialogs via ComDlg32; clipboard via Win32; DnD requires OLE; all OS-limited — spike notes partial, not blocked |

## Consequences

**Positive:**
- Desktop EPICs #1009–#1015 are unblocked with one native renderer, one binary,
  and one `V master` toolchain; not blocked on upstream feature windows.
- Headless `PerfHarness` (1000 widgets @ 60 FPS, 58+ sustained `perf.v`) can gate CI
  before any window exists; `VJOBS=2 ./make.vsh vet|test` stays green on Linux CI.
- `modules/agent_toolkit_gui` isolates Windows/DnD/grid/markdown gaps; `core` stays
  GUI-free and testable headless.
- `agent-toolkit --help` / `doctor` / `build --check` / `serve --port 0` remain
  headless-smokeable (no `DISPLAY` needed).

**Negative / Cost:**
- Wrapper must be maintained until upstream fills gaps; contributors must not bypass
  it via direct `import gui` in `desktop_engine` (enforced by `check-planes`).
- Custom grid/markdown/canvas-grid reuses `on_draw` composition — not a free widget;
  first Desktop screens pay that construction cost.
- `V master` is less stable than `0.5.2`; fallback to `0.5.2` on Windows is retained
  per `setup-v` (see `docs/WINDOWS.md` branch).

## Validation plan

- `cat .v-version == master`, `v version → V 0.5.2 78e581e` (or `master HEAD` on Linux),
  `VMODULES=modules`.
- `VJOBS=2 ./make.vsh vet` — four modules (`core`, `cli`, `server`, `gui`) vet green;
  `VJOBS=2 ./make.vsh test` — `gui_test.v` passes (perf @ 58 FPS, gap sizes, natives).
- `VJOBS=2 ./make.vsh build-cli && ./build/agent-toolkit --help` still lists
  `docs/CLI_SURFACES.md` surfaces (no CLI regression).
- **Perf artifact:** `PerfHarness.run_headless(60).artifact_json()` logs
  `{"widget_count":1000,"target_fps":60,"fps":…,"avg_ms":…,"max_ms":…,"passed":true}`
  headless on Linux CI (no DISPLAY). Capture in ADR + manual smoke doc.
- **Native probe:** `probe_native()` headless returns 7 stubs + `windows_limitations()`
  four entries; on Linux with DISPLAY it reports `available` for dialogs/clipboard/IME.
- **Manual smoke (Linux — required, macOS/Windows documented):**
  - `ATK_GUI_HEADLESS=1 ./build/agent-toolkit --help` headless path green.
  - With `DISPLAY=:1` / `WAYLAND_DISPLAY=wayland-1` (Hyprland), `modules/agent_toolkit_gui`
    `default_gui_config().validate()` passes and synthesized window config `1280×800`
    smoke logs `smoke_message` (no actual `sokol` window in this spike — Phase 1).
  - Windows: capture per `docs/WINDOWS.md` limitation checklist (MSVC, D3D11,
    IME, DPI manifest, dialogs) with screenshots — not gated on Linux CI.
- **Planes:** `! grep -r 'import.*gui' modules/agent_toolkit_core` (and future
  `desktop_engine`) passes.

## References

- `.v-version` (`master`), `VERSION` (`1.27.0 @ 6807f29`), `make.vsh`,
  `modules/agent_toolkit_gui/*` (`feasibility.v`, `perf.v`, `window.v`, `native.v`)
- `vlang/gui` https://github.com/vlang/gui (README, `docs/ROADMAP.md`,
  `docs/WINDOWS.md`, `examples/dock_layout.v`, `examples/snake.v`)
- `vlib/sokol`, `vlib/gg`, `vglyph`, `vlib/x/async`, `vlib/eventbus`, `vlib/db/sqlite`,
  `vlib/context`, `vlib/sync`, `sokol/audio`
- Desktop EPICs #1007–#1015, issues #1016–#1032 (re-baselined), #279, ADR-009, ADR-012,
  ADR-015, ADR-026, ADR-030, ADR-031, `docs/ARCHITECTURE.md`,
  `docs/CLI_SURFACES.md`, `docs/HOW_TO_DEVELOP_V.md`
- Toolchain: `V master 78e581e`, `.github/actions/setup-v/action.yml` (`master` branch:
  `git clone --depth 1 https://github.com/vlang/v && make` on Linux/macOS,
  fallback `0.5.2` on `Windows*`)

**Verified:** 2026-08-31 — `VJOBS=2 ./make.vsh vet` four modules green, `v test
modules/agent_toolkit_gui` green (1000-widget 60 FPS harness passing), headless
native probe + Windows limitations matrix published, `make.vsh build-cli` +
`./build/agent-toolkit --help` smoke passing, manual Linux smoke logged per
`window.v:smoke_message`.
