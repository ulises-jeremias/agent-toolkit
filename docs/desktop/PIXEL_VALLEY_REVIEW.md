# Pixel Valley recovery — review ledger

Status: **CURRENT REVIEW** — 2026-10-01, worktree `pixel-valley-recovery`
(branch `feat/pixel-valley-recovery`), build `agent-toolkit 1.40.0`.

This is the honest review of the recovered work after the `/tmp/opencode`
restart. Everything here was rebuilt, tested, and captured again on this host;
nothing is claimed from the vanished session.

## What was rebuilt

**Rendering (commit `fix(desktop): one camera scale…`).** The review of the
surviving world implementation found real defects: entity tiles followed a
fixed 48px tile while the terrain followed the live zoom, sprites stretched
to fill their footprint instead of keeping authored dimensions, a pointer
drag that started on an entity opened its inspector, zoom was not anchored,
and the two-frame CSS animation (`background-position-x: calc(var(--frames)
* -100%)`) shifted animated sprites off the visible area on alternate frames.
Fixes: shared camera math (`camera.ts`), integer zoom `[16, 32, 48, 64]` with
centered clamp, manifest-dimensioned sprites bottom-center anchored in the
semantic footprint, drag threshold + capture release + click suppression,
center-anchored zoom, animation suspension under hidden inspectors and
hidden tabs. All verified by unit tests and opened captures.

**Meadow contrast (commit `fix(desktop): Meadow canvas text contrast…`).**
Opened captures showed page headings (title/lede/eyebrow) unreadable in
Meadow: ivory text on the bright valley canvas. A canvas text ramp
(`text-canvas-primary/secondary/muted`, `accent-canvas`) measured ≥ 4.5:1 on
`#dcecd0` (11.2 / 8.3 / 4.9 / 5.1) replaced them; Dusk keeps the menu ramp.
`files.module.css` dropped the last Paper-era fallbacks
(`--ink-muted`/`--paper`/`--manila`/`--rule`/`--paper-raised`/`--ink-wash`)
onto the game-menu system. Evidence: opened PNGs below.

**Declarative workflow ledger.** `docs/desktop/workflows.yaml`
(`spec: agent-toolkit/desktop-workflows@1`) is the Electron per-journey
ledger, checked by `apps/desktop/src/workflowLedger.test.ts`. The native-V
matrix in `workflows.yaml` tracks current evidence; People CRUD/import/
Start/swarm-picker are explicitly `not-implemented` — schemas and file
authoring are not the user interface.

## Evidence (opened, critiqued, recaptured)

33 PNGs in `docs/desktop/assets/electron/pixel-valley-recovery/`: Meadow/Dusk
× 1024×640 / 1920×1080 × World/Office/Operations/Workspace/Library/Insights/
Terminal/Settings, plus `world-with-running-job.png` from a real GUI-started
job. Critiques acted on: Meadow heading contrast (fixed, recaptured),
Paper-era file panel (fixed, recaptured), world meta text on the chrome bar
(fixed). Dusk and Meadow both read as the intended game-menu language.

## Validation run on this host

- V master (`c0e47bf`) test suite: 34/34 files pass (`./make.vsh test`).
- Desktop unit: 282 passed (39 files); lint and type-check pass.
- E2E Electron (real V backend): 20 passed; renderer E2E: 6 passed;
  capture tour: 1 passed (33 PNGs); interior probe: 1 passed.
- `agent-toolkit build --check`: Tier-1 compile + plugin drift OK.
- `validate-skills.vsh` (105), `validate-agents.vsh` (18),
  `validate-loops.vsh` (10), `generate-catalogs.vsh --check`: all pass.
- World asset generator: 80 sprites fresh (`--check`).
- Clean-machine smoke: `release/linux-unpacked/agent-toolkit-desktop`
  launched with fresh `HOME`/`XDG_*` and `--ozone-platform=x11`
  `+ swiftshader` created the workspace through the GUI; bundled backend
  reports `agent-toolkit 1.40.0`.

## Known limitations (not shipped, not claimed)

- **People GUI journeys** (CRUD, import review, Start/session binding, swarm
  role picker) are not implemented — contracts only (ADR-036).
- MCP typed configuration, loop run/report, swarm run/watch, install
  preview/rollback, and palette reachability are ledger-blocked.
- HiDPI/scaling, OS accessibility tree, Arabic bidi and soak are unverified;
  no screen-reader or full WCAG claim.
- GPU launch on this host's Wayland needs `--ozone-platform=x11` (Vulkan
  incompatibility); first-run on Wayland stock flags is untested here.

## Provenance

All Desktop art is original, generator-owned (`apps/desktop/scripts/
gen-world-assets.mjs`); no third-party assets were imported from the
reference repositories. The four reference repositories were inspected
independently pre-restart for behavior classification only.
