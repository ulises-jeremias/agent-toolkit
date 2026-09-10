# S4 Implementation Handoff — Shared Action & Entity Registry

> **ARCHIVED (2026-09-10).** Frozen 2026-09-07 snapshot; S4 is complete and
> #1119 is closed (slices S4A–S4D merged as #1159–#1162). Superseded by the
> merged S4 / standalone / Visual-Convergence work — current state lives in
> #1118, [TRUTH_LEDGER.md](TRUTH_LEDGER.md) and
> [WORKFLOW_COVERAGE.md](WORKFLOW_COVERAGE.md). Preserved for history only;
> do not start new S4 work from this handoff.

You are taking over Agent Toolkit Desktop to implement **S4 (#1119) — the
shared typed action & entity registry**. This handoff was produced at the end
of the S7 truth-audit + design-contract reconciliation phase. Verify all
state before acting; do not trust it blindly.

## 1. Starting point

- Repository: `ulises-jeremias/agent-toolkit`
  (`/home/ulisesjcf/.ai-workspace/repos/agent-toolkit`).
- Main at handoff preparation: `741d7b46` (design contract merge), with
  `fix/setup-v-cache` (#1154) being merged on top — **fetch and use the fresh
  canonical main**; the first post-merge Validate run populates the new
  pinned-V build cache.
- S7 truth audit is complete (S7A–S7E: #1144, #1146, #1147, #1148, #1149;
  fixture recapture #1150; S7F docs #1152). Every Desktop Engine value comes
  from authoritative evidence or is explicitly unknown/unavailable
  (`docs/desktop/TRUTH_LEDGER.md`, enforced by `modules/desktop_engine/*_truth_test.v`).
- Governing contracts (read before coding):
  - `AGENTS.md` — execution contract + canonical document map (refactored by
    #1145; links every doc below).
  - `docs/desktop/PRODUCT_VISION.md`, `UX_ARCHITECTURE.md` (§Shared action and
    entity model is the governing architecture for S4), `DESIGN.md` (visual
    grammar; palette/forms follow §10/§11), `WORKFLOW_COVERAGE.md`
    ("Dead/split action discovery" blocker), `VISUAL_QA.md` (evidence loop),
    `TRUTH_LEDGER.md`.

## 2. Current palette architecture (what exists today)

> **Updated 2026-09-07 (S4A–S4C):** the two-authority state below is resolved.
> The typed registry (`modules/desktop/palette/registry.v` + `actions.v`) is
> the **sole** palette/search authority; `palette_items()`, the duplicate
> scorer and the legacy activation arms were deleted. Contextual typed
> actions with preview/confirmation landed in S4B. Application-level actions
> (appearance, honest-unavailable Update, receipt-based Uninstall) live under
> one app entity. Critical-workflow reachability is gated by
> `cmd/agent-toolkit-desktop/registry_reachability_test.v` inside Required
> CI (`./make.vsh test`). Remaining slices: S4D (truthful undo + recent
> actions only). The original snapshot is preserved below for history.

Two authorities coexist:

1. **Static production list** — `palette_items()` in
   `cmd/agent-toolkit-desktop/main.v` (~line 1611): hardcoded
   `PaletteItem{id, label, desc, key}` rows — navigation entries plus
   **CLI-command entries with fixed flags** (e.g. `"Install — full: agent-toolkit
   install --tools claude-code,cursor --force"`, `"Update"`, `"Uninstall"`,
   `"mcp_health"`, `"loop_run"`, `"swarm_start"`, `"memory"`). Its own comment
   (main.v ~7624) calls the numbers hardcoded/historical. A private fuzzy
   scorer (`palette_best_score`, main.v ~1697) mirrors the module's scorer.
2. **Typed module (not wired to production)** —
   `modules/desktop/palette/palette.v`: `PaletteAction` struct,
   `PaletteViewModel.build_actions()` already enumerates Engine catalogs
   (nav routes, skills, agents, products, targets…) with fuzzy scoring
   (`action_best_score`), a virtualized list, and `execute_selected()` via
   `nav.Router`. Tested by `modules/desktop/palette/palette_test.v`. The
   production shell (main.v) does not import it — the production palette UI
   renders the static list instead.

Entity results in the typed module currently open their destination panel;
they do not deep-link or carry per-entity actions. That is part of what S4
adds.

## 3. Duplicate authority that must be migrated (incrementally)

Per #1119's migration plan (do NOT big-bang `main.v`):

1. Wire the typed registry as the production palette's data source (keep the
   current interaction/UX; swap the data source).
2. Migrate navigation + entity entries first (Engine catalogs already feed
   `build_actions()`).
3. Replace each hardcoded CLI-command entry with its typed Engine action:
   install → `engine.install_with_options` (S7B: real files + real receipts),
   target enable → `engine.set_target_enabled`, MCP enable →
   `engine.upsert_mcp_provider`/`mcp_toggle` (packaged template),
   doctor repair → `engine.doctor_fix` (+ `doctor_fix_preview` dry-run),
   loop run → `engine.run_loop`, swarm launch → `engine.swarm_launch`
   (records `requested`), update → stays honest-unavailable (no real feed
   reader), memory → memory operations, uninstall/diff → core seams as
   available; anything without a typed seam stays out of the registry until
   one exists (never shell out to the CLI).
4. Delete `palette_items()` + `palette_best_score` once nothing consumes them.
5. Extend `modules/desktop/palette/palette.v` rather than creating a third
   implementation.

## 4. Likely S4 slices (suggested PR decomposition)

- **S4A — Registry core**: single typed registry source (Engine catalogs +
  config + runtime + evidence), availability with reason, entity identity
  (type + canonical id + workspace context + display metadata), wired into the
  production palette as its data source. Navigation + catalog entities migrate
  first; static list demoted.
- **S4B — Contextual actions + typed arguments**: per-entity actions with
  typed arguments (selection/scope/target/tool), validation, dry-run preview
  where the Engine supports it (`install_with_options{dry_run}`,
  `doctor_fix_preview`, MCP upsert diff), execution result + recovery info.
- **S4C — CLI-command migration + retirement**: migrate the remaining static
  entries to typed actions; delete `palette_items()`/`palette_best_score`;
  coverage script evolves to task coverage.
- **S4D — Undo/recent actions (only where truthful)**: config toggles record
  prior value for real undo; destructive/irreversible actions require explicit
  confirmation with preview; recent actions recorded from real executions.

Keep every slice independently shippable with its own green Required CI.

## 5. Relevant tests and gates

- `modules/desktop/palette/palette_test.v` — extend for registry semantics
  (availability-with-reason, entity identity, argument validation).
- New registry test file (e.g. `modules/desktop_engine/registry_truth_test.v`
  or a desktop-module test): fresh engine → catalog entries + navigation only,
  no fabricated rows; executed actions produce real state (receipt/config/
  runtime) per the S7 gates.
- Existing truth gates that must stay green:
  `evidence_truth_test.v`, `targets_truth_test.v`, `git_truth_test.v`,
  `loops_agents_truth_test.v`, `engine_truth_test.v` — these lock the
  semantics your actions will invoke (install writes real receipts; enabling
  MCP uses packaged templates; doctor fixes are real repairs; updates are
  honest-unavailable).
- `scripts/gui-coverage.py` — evolve from CLI-row parity to task/workflow
  coverage of the registry's critical workflows.
- Full gates: `./make.vsh test`, production desktop build
  (`VJOBS=2 VMODULES="$PWD/modules" v -d gg_text_buff_size=4096 -o
  build/agent-toolkit-desktop-native cmd/agent-toolkit-desktop`), clean-machine
  headless boot, Golden UI (fixtures current as of #1150; recapture only for
  intentional visual change with the drift map documented).

## 6. Known risks

- **`main.v` is ~10.5k lines** — the palette draw/hit-test code near
  `palette_items()` is entangled with panel rendering; extract carefully,
  one migration at a time, keeping geometry shared between draw and hit-test.
- **Truth regressions are release blockers** — any registry result that is
  fabricated-but-plausible violates the S7 contract and the S7 gates will
  (and must) fail. When in doubt, render unavailable with a reason.
- **The static list contains entries with no truthful backing** (e.g.
  "Update — agent-toolkit update"): migrate them to honest-unavailable or
  omit them; do not carry them into the registry as fake actions.
- **CI infrastructure note**: pinned V (master @ c0e47bf) cold rebuilds are
  non-deterministic upstream (vc/tcc moving HEADs); #1154 added a build cache
  + retry to `.github/actions/setup-v`. If a cold rebuild fails persistently,
  bump the pinned commit AND the cache key together (both literals live in
  the action). Hermetic bootstrap reproducibility is tracked separately in
  #1158.
- **Golden fixtures** reflect the current UI; intentional visual changes to
  the palette must include a drift map and recapture (policy in
  `VISUAL_QA.md`), never a silent fixture update.

## 7. Immediate first steps

1. Fetch fresh main; confirm the pinned-V cache behavior is stable
   (#1154 merged; Validate green on the two most recent main runs).
2. Read `UX_ARCHITECTURE.md` §Shared action and entity model, `DESIGN.md`
   §10–11, and #1119's rewritten body.
3. Start S4A from a fresh branch off canonical main; keep PRs focused;
   Required CI green before any merge; no direct pushes to main.
