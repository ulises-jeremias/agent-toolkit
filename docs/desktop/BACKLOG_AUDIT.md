# Desktop backlog audit

## Implementation update (2026-09-05)

Commit `18ac8e4` removes fabricated catalog padding, synthetic agent and
receipt rows, seeded Office tasks, mock terminal logs, mock job/swarm/approval
rows, and invented Insights spans, budgets, and CI results. Empty states now
render as unavailable or idle until the Engine reports real data. The full
desktop suite passes 26/26 tests; the native binary builds and was launched in
an isolated Xvfb session for screenshot review. The classifications below are
unchanged and still require shell, onboarding, workspace mutation, and
packaging work.

Read-only GitHub/repository audit, 2026-09-05, origin/main `85853decda84b9af70cee48889d00c22c543f79d`. No GitHub mutations. Static verification is distinguished from runtime acceptance: this audit did not run the app and no item is classified DONE solely from presence of code.

## Inventory and policy

40 open issues total; 39 matched desktop/GUI/terminal/onboarding references and all 39 were inventoried. Raw full issue bodies: `/tmp/atk-open-issues.json`, filtered `/tmp/atk-desktop-issues.json`. Recent PRs `/tmp/atk-prs.json`, runs `/tmp/atk-runs.json`, protection `/tmp/atk-main-protection.json`.

Main Validate, MegaLinter, Parity, CodeQL report success. Golden UI is non-blocking (`.github/workflows/validate.yml:866`) and is not in Required CI dependencies (`:1053`). Green main therefore does not establish golden success or visual QA. Protection requires only `Required CI`, strict=false; no required PR review config; admin enforcement false; force pushes and branch deletion disallowed. User mission still requires independent review and green real CI, regardless of permissive GitHub protection.

PRs #1135–#1138 are CLOSED rather than MERGED. Their commits are present via merge 85853de: ea4ffc3 Doctor, 35bc3e7 MCP, e340d65 golden, 6d0ae04 Swarm, 2adbd0c formatting. Cite commits rather than claiming those PRs were merged. Recent merged PRs: #1134 appearance, #1133 truth/navigation, #1126 theme, #1125 CI headroom, #1124 remove alternate renderer, #1123 workspace/navigation, #1122 terminal split, #1121 dead-session cards, #1120 real PTYs. Open PR #1132 is ImgBot image optimization; no active desktop implementation PR in returned recent inventory.

## Classification

Classifications are recommendations requiring relevant runtime proof before closure. SUPERSEDED refers to prescribed presentation, preserving underlying supported capability. Paths refer to audited main.

| Issue | Classification | Priority | Evidence and next scope |
|---|---|---|---|
| [#1131](https://github.com/ulises-jeremias/agent-toolkit/issues/1131) feat(desktop): responsive layout matrix — min sizes, narrow windows, HiDPI | STILL_VALID | P1 | Define supported size/scale states and real screenshot matrix; scripts/golden.sh:55 fixes capture to 1280x800, so no cross-size proof. |
| [#1130](https://github.com/ulises-jeremias/agent-toolkit/issues/1130) feat(desktop): clean-machine packaging validation — install and launch from release artifacts | STILL_VALID | P0 | Clean artifact launch remains unproven; docs/desktop/PACKAGING.md and packaging/linux launcher are not acceptance evidence. |
| [#1129](https://github.com/ulises-jeremias/agent-toolkit/issues/1129) feat(desktop): desktop-launch tool discovery and PATH transparency | STILL_VALID | P0 | Launcher PATH/tool discovery must be tested through real catalog and sparse environment; modules/pty/pty.v is current PTY backend. |
| [#1128](https://github.com/ulises-jeremias/agent-toolkit/issues/1128) feat(desktop): managed-workspace lifecycle — discover, open, switch, seed without destructive changes | NEEDS_REWRITE | P0 | Keep safe lifecycle; remove prescribed harness-shaped sample requirement. Current onboarding ViewModel uses harness_root (modules/desktop/onboarding/onboarding_viewmodel.v:88). |
| [#1127](https://github.com/ulises-jeremias/agent-toolkit/issues/1127) feat(desktop): zero-to-working first-run acceptance — install to useful env without terminal | NEEDS_REWRITE | P0 | Keep zero-terminal acceptance; do not prescribe old Detect/Pick/Install/Seed/Tour. Actual first-run copy is seven technical steps (main.v:2366). |
| [#1119](https://github.com/ulises-jeremias/agent-toolkit/issues/1119) feat(desktop): palette argument-builder forms + undo for destructive actions | NEEDS_REWRITE | P1 | Replace spec-table-next-to-main.v requirement with typed Engine-backed action/entity registry. Static production palette at main.v:1617 coexists with modules/desktop/palette/palette.v. |
| [#1118](https://github.com/ulises-jeremias/agent-toolkit/issues/1118) GUI master tracking — complete the Paper Co. experience (v1.31+) | NEEDS_REWRITE | P0 | Master omits older open work and treats issue closure/22 commands as product coverage. Theme/Doctor/MCP/Swarm descriptions are stale relative to 85853de. |
| [#1117](https://github.com/ulises-jeremias/agent-toolkit/issues/1117) feat(desktop): onboarding Capabilities/Targets steps + global keymap audit | NEEDS_REWRITE | P1 | Split onboarding user outcomes from keyboard event-precedence contract. Stamp grids and no-dead-space criterion do not establish usable onboarding. |
| [#1116](https://github.com/ulises-jeremias/agent-toolkit/issues/1116) feat(desktop): packaging — man page, app icon, install target, self-update | NEEDS_REWRITE | P1 | Separate Linux install outcome from optional self-update; overlaps #1057/#1063. Native backend and artifacts require current entrypoint cmd/agent-toolkit-desktop. |
| [#1115](https://github.com/ulises-jeremias/agent-toolkit/issues/1115) feat(desktop): a11y — reduced motion, focus rings, WCAG contrast gate | STILL_VALID | P1 | Focus/motion/contrast need honest native accessibility contract. No reduced_motion production matches in main.v; do not imply OS accessibility tree/WCAG conformance. |
| [#1114](https://github.com/ulises-jeremias/agent-toolkit/issues/1114) feat(desktop): Arabic shaping — evaluate pre-shaped HarfBuzz runs vs bidi-lite | STILL_VALID | P1 | Arabic shaping unresolved; main.v:1368 explicitly says harfbuzz-less isolated forms. Static pre-shaping alone cannot cover dynamic values. |
| [#1113](https://github.com/ulises-jeremias/agent-toolkit/issues/1113) feat(desktop): i18n — translate panel ledger bodies and empty states (4-lang) | NEEDS_REWRITE | P1 | Keep complete localization; remove instruction to keep receipt/provenance/TX jargon in user-facing primary copy. MCP drawer strings at main.v:4084–4111 remain English. |
| [#1112](https://github.com/ulises-jeremias/agent-toolkit/issues/1112) feat(desktop): perf budgets — frame-time p95 overlay, atlas headroom, 1h soak | STILL_VALID | P2 | Measured p95 and soak remain needed; issue historical 15-desks budget must be revised to actual task/data and terminal workloads. |
| [#1111](https://github.com/ulises-jeremias/agent-toolkit/issues/1111) feat(ci): golden-image regression job for the desktop GUI | PARTIALLY_DONE | P1 | e340d65 implements both-theme CI and tofu script. validate.yml:866 continue-on-error true; golden-ui absent from Required CI needs at :1053. Not a release gate yet. |
| [#1110](https://github.com/ulises-jeremias/agent-toolkit/issues/1110) feat(desktop): Insights — cost-over-time chart, budget rings, CSV/JSON export | NEEDS_REWRITE | P2 | Insights exists at main.v:6843; validate truth and useful questions before rings/charts/export. Do not force chart proliferation. |
| [#1109](https://github.com/ulises-jeremias/agent-toolkit/issues/1109) feat(desktop): Workspace — diff gutter, per-hunk staging, graph deep links | NEEDS_REWRITE | P2 | Workspace renderer main.v:6144 exists; lifecycle is higher priority than per-hunk staging. Preserve useful diffs/editor rather than becoming Git client. |
| [#1108](https://github.com/ulises-jeremias/agent-toolkit/issues/1108) feat(desktop): Doctor — per-check fix wiring + dry-run preview | PARTIALLY_DONE | P1 | ea4ffc3 adds dry-run/category fixes; main.v:4203 preview geometry/:4210 open/:4223 confirm; modules/desktop_engine/doctor_fix_test.v. Runtime recovery and what-changed proof still required. |
| [#1107](https://github.com/ulises-jeremias/agent-toolkit/issues/1107) feat(desktop): Targets — install progress, receipt drawers, rollback flow | PARTIALLY_DONE | P1 | Targets renderer main.v:4144 exists; receipt/rollback/progress workflow needs acceptance. Reframe as coding-tool integration with truthful indeterminate progress. |
| [#1106](https://github.com/ulises-jeremias/agent-toolkit/issues/1106) feat(desktop): MCP provider drawer — masked config preview + health probe | PARTIALLY_DONE | P1 | 35bc3e7 adds drawer/probe/masking; main.v:3894 geometry/:3926 open/:3937 masking; modules/desktop_engine/mcp_drawer_test.v. Runtime and secret/error-path review still needed. |
| [#1105](https://github.com/ulises-jeremias/agent-toolkit/issues/1105) feat(desktop): Agents — delegation graph mini-view + per-agent activity sparkline | NEEDS_REWRITE | P2 | Agents list main.v:3825 exists; graph/sparkline requirements are unvalidated presentation, replace with inspect role/current work/session actions. |
| [#1104](https://github.com/ulises-jeremias/agent-toolkit/issues/1104) feat(desktop): Skills master-detail + batch install | PARTIALLY_DONE | P1 | Skills list/bulk flow exists; master-detail and safe configurable install must align shared registry/inspector rather than prescribed 60/40 split. |
| [#1103](https://github.com/ulises-jeremias/agent-toolkit/issues/1103) feat(desktop): Jobs — per-job log drawer with follow mode | PARTIALLY_DONE | P1 | Jobs renderer main.v:4408 exists; real log follow/error/retry/cancel workflow acceptance remains. |
| [#1102](https://github.com/ulises-jeremias/agent-toolkit/issues/1102) feat(desktop): Loops — full burn-down chart + cron editor with next-runs preview | PARTIALLY_DONE | P1 | Loops renderer main.v:4746 exists; prioritize schedule editing/next runs/run history/failure over prescribed full burn-down chart. |
| [#1101](https://github.com/ulises-jeremias/agent-toolkit/issues/1101) feat(desktop): Swarm topology — interactive nodes (attach terminal) and edge artifacts | PARTIALLY_DONE | P1 | 6d0ae04 adds node attach and artifacts; main.v:5009 geometry/:5014 artifact/:5025 working_roles. Handoff-derived working roles need truth review; historical handoff is not proof of running agent. |
| [#1077](https://github.com/ulises-jeremias/agent-toolkit/issues/1077) feat(desktop): Terminal — Command Deck / World View integration for open terminal | NEEDS_REWRITE | P1 | Replace World-station/Command Deck specifics with universal discover/open/focus-session action. Existing PTY session manager shipped #1120. |
| [#1076](https://github.com/ulises-jeremias/agent-toolkit/issues/1076) feat(desktop): Terminal — Doctor terminal diagnostics | STILL_VALID | P1 | Keep session/binary health and guided recovery through Engine Doctor. modules/pty/pty.v and modules/ghostty/ghostty.v are current backend paths. |
| [#1074](https://github.com/ulises-jeremias/agent-toolkit/issues/1074) feat(desktop): Terminal — testing matrix (fake providers + platform smoke) | NEEDS_REWRITE | P1 | Discard obsolete external-provider shim matrix. Current PTY/Ghostty directories contain no test files; test spawn/write/resize/kill/isolation/reflow and supported platform smoke. |
| [#1073](https://github.com/ulises-jeremias/agent-toolkit/issues/1073) feat(desktop): Terminal — SessionBackend evaluation (tmux optional, EVALUATE) | NEEDS_REWRITE | P2 | Optional durable sessions may be evaluated later, native PTY remains baseline. Do not introduce mandatory tmux; shipped backend modules/pty/pty.v. |
| [#1066](https://github.com/ulises-jeremias/agent-toolkit/issues/1066) feat(desktop): Swarm Room — projection, handoffs, approvals, budget, trace inspector | NEEDS_REWRITE | P1 | Keep real swarm approvals/budgets/handoffs/session workflow, drop mandatory spatial room. #1101 only partial slice, current main.v:5067 renderer. |
| [#1065](https://github.com/ulises-jeremias/agent-toolkit/issues/1065) feat(desktop): World View — game presentation system (sprites, animation mapping, reduced motion, sokol/audio) | SUPERSEDED | P2 | Game-presentation/audio/sprite mandate conflicts with clarity-first mission. Transfer reduced motion to #1115 and responsive/DPI to #1131; no new ambient animation. |
| [#1064](https://github.com/ulises-jeremias/agent-toolkit/issues/1064) feat(desktop): World View — Target station (rig wall with real install animation) | SUPERSEDED | P2 | Rig-wall metaphor duplicates Targets integration workflow #1107. No evidence supports building a new station as operational prerequisite. |
| [#1063](https://github.com/ulises-jeremias/agent-toolkit/issues/1063) feat(desktop): auto-update — checksum, provenance, rollback, channel (7.4) | NEEDS_REWRITE | P2 | Retain checksum/provenance/rollback goals; reconcile optional update policy with installer/package manager ownership. modules/desktop_engine/update_service.v is current seam. |
| [#1062](https://github.com/ulises-jeremias/agent-toolkit/issues/1062) feat(desktop): World View — Diagnostics Lab station (doctor checks as bench instruments) | SUPERSEDED | P2 | Doctor bench-instrument metaphor duplicates #1108 recovery task; current main.v:4244 renderer already exposes checks. |
| [#1061](https://github.com/ulises-jeremias/agent-toolkit/issues/1061) feat(desktop): World View — Library station (skills/agents/packs spatial alcove) | SUPERSEDED | P2 | Library spatial alcove duplicates discover/inspect/install workflows #1104 and shared search/inspector. Keep optional map only if later user evidence warrants. |
| [#1060](https://github.com/ulises-jeremias/agent-toolkit/issues/1060) feat(desktop): Windows packaging — native deps, installer spike WiX/Inno/NSIS, WINDOWS.md (7.3 Windows) | NEEDS_REWRITE | P1 | Windows platform feasibility still matters; use actual gg/sokol + current PTY (POSIX) instead of old vlang/gui/version paths. docs/desktop/WINDOWS.md is existing canonical doc. |
| [#1059](https://github.com/ulises-jeremias/agent-toolkit/issues/1059) feat(desktop): macOS packaging — bundle, codesign, notarization, DMG (7.3 macOS) | NEEDS_REWRITE | P1 | macOS packaging remains valid; remove obsolete single binary/entrypoint/version assumptions; actual desktop cmd/agent-toolkit-desktop. Signing/release publishing remains separately authorized. |
| [#1057](https://github.com/ulises-jeremias/agent-toolkit/issues/1057) feat(desktop): Linux packaging — Desktop Entry, icon, XDG, AppImage (7.3 Linux) | NEEDS_REWRITE | P0 | Consolidate Linux man/icon/install with #1116; current packaging/linux/agent-toolkit-desktop.desktop exists. Verify installed assets and cwd independence before AppImage scope. |
| [#1055](https://github.com/ulises-jeremias/agent-toolkit/issues/1055) feat(desktop): native platform — menus/tray/file dialogs/clipboard/drag-drop/notifications (7.1) | NEEDS_REWRITE | P1 | Replace vlang/gui VGuiBackend framing with native gg backend seam. Clipboard present main.v:2038; modules/desktop/backend/backend.v exists. File/folder pickers high value to standalone lifecycle. |
| [#1030](https://github.com/ulises-jeremias/agent-toolkit/issues/1030) feat(desktop): activity — status, progress, background tasks surface | PARTIALLY_DONE | P1 | Per-panel status/toasts exist, global actual activity needs shared typed projection. main.v:4408/:4746/:5067 supply per-domain rendering; do not invent percentage/activity. |

## Recommended next steps

1. Replace master tracker with product outcomes and explicit evidence gaps; link durable mission/journey/coverage/QA documents. Retain all valid capability work even when presentation issues are superseded.
2. Resolve production truth before increasing panel depth; independently inspect synthetic activity and handoff-derived statuses.
3. Establish workflow coverage, shared focus/layout/action architecture, then standalone onboarding + safe workspace lifecycle + launcher tool discovery + packaged clean launch.
4. Close superseded spatial issues only with concrete mapping to continuing tasks (#1104/#1107/#1108/#1115/#1131), avoiding implied deletion of product capabilities.
5. Reconcile implemented Doctor/MCP/Swarm/golden items after running and viewing affected states; do not close based on commit summaries.
6. Rewrite terminal/native/packaging issues completely rather than appending another triage preface above obsolete implementation instructions.

## Implementation evidence — PR #1139 follow-up

The active desktop branch (`r2-office-shell`) has since removed fabricated production state and wired several controls to typed Engine operations. Evidence includes commits `c8908fd` (operational Office overview), `00bdf5f`/`0e66f47` (no synthetic git/provenance data), `030bc0d`/`b034242` (loop/job actions through Engine), `155a04c` (truthful empty Jobs), and `fbf62ff`/`cd4494e` (MCP health/probe semantics). Focused Engine tests and native builds pass; PR #1139 remains open/draft pending full CI and visual review.

The Targets panel now handles row toggles through `Desktop.engine_set_targets_bulk`, using the live Engine target catalog and reporting the resulting revision (`a1037bc`, `main.v` Targets click handling). This closes a dead-control gap while the broader install-progress/receipt workflow in #1107 remains partial.

A legacy spatial Library projection and standalone update helper were also made truthful: empty models now wait for Engine/catalog projection, detail previews report unavailable, and the default update feed has no fabricated release metadata (`14491c2`).

The desktop command palette no longer lists legacy rows without an execution path (`59de011`). Remaining rows either navigate to a real surface, invoke an implemented Engine-backed action, or report an explicit unavailable state.

Jobs no longer derives progress from elapsed duration or a synthetic queue percentage; only completed jobs render a completion bar until the Engine exposes a real progress value (`62e1379`).

Jobs Cancel and Retry controls now reflect lifecycle legality: Cancel is active only for queued/running jobs, while Retry is active only for failed/canceled/done jobs; click handling enforces the same guards (`main.v`, follow-up after `260b77f`).

Loop run-count and wall-clock tracks now render as configured limits rather than fabricated utilization; only token usage is filled from the Engine ledger (`main.v`, follow-up after `7aa3d5e`).

Doctor now disables the Fix All control when no non-passing check is fixable and reports an explicit all-clear message on attempted activation (`main.v`, follow-up after `2020819`).

Jobs hover/selection now uses the same live Engine catalog as rendering; the former four-record fallback is gone (`main.v`, follow-up after `de4e826`).

Swarm topology now labels nodes as recorded participants and draws static handoff edges; historical handoffs no longer appear as currently working roles or animated delivery (`main.v`, follow-up after `080af52`).

Office Running now reflects the Engine job catalog: it reports active operations when jobs are running and a truthful empty state otherwise (`main.v`, follow-up after `d61ee61`).

The inspector's compact per-desk Ghostty view is now explicitly an Engine log preview, with a truthful empty state and a clear path to open the real PTY terminal (`main.v`, follow-up after `d61ee61`).

`Engine.swarm_logs` now returns an empty list when no persisted log exists instead of synthesizing launch/handoff messages; Swarm activity remains event-backed (`swarm_service.v`, follow-up after `a6eb450`).

`Engine.loops_catalog` no longer injects ten template loops when no state/files exist; runtime coverage now creates a loop explicitly before exercising it, while discovered filesystem loops remain supported (`loops_service.v`, `runtime_plane_test.v`).

Discovered loops without execution history now keep `last_exit` empty instead of claiming `success`; completion is shown only after a recorded run (`loops_service.v`, follow-up after `d2f5f25`).

MCP catalog now discovers only packaged provider directories containing real config templates, using their actual paths for previews, provenance, probes, and toggle installation. Unknown providers return empty content instead of fabricated npx configuration (`mcp_service.v`, follow-up after `6da89e7`).

Doctor MCP repair previews now identify the packaged template that will be used, instead of promising an invented npx configuration. The actual repair calls the same Engine MCP toggle path (`targets_service.v`, follow-up after `01718e7`).

Pack catalog now enumerates `packs/*/config.yaml`, derives enabled skill counts from each config, and exposes persisted enabled state. It no longer advertises historical pack IDs or fixed counts that are absent from the current checkout (`products_service.v`, follow-up after `ec38149`).

Unknown MCP providers now produce an empty install preview, with no fabricated write, receipt, or provenance paths. This keeps dry-run UI truthful when an entity is stale or unavailable (`mcp_service.v`, follow-up after `b5ae380`).

MCP UI headers and footer now reference the actual packaged template path (`mcp/templates/<id>/config.template.json`) instead of the removed flat-file path (`main.v`, follow-up after `1b5fd68`).

Products/Packs now has functional pack chips: clicking a chip toggles the persisted Engine state and reports the revision. The prior UI implied toggles while only rendering an always-active membership check (`main.v`, follow-up after `39a888c`).

The Skills footer no longer embeds the historical `116` catalog count; it now renders the live Engine-derived total alongside the source path (`main.v`, follow-up after `92d1811`).

The optional Floor Map now projects discovered Engine agents through a Desktop catalog API. It no longer creates a fixed roster of historical personas when the catalog is empty; an empty catalog renders no desks (`window.v`, `main.v`, follow-up after `e184148`).

Floor Map rendering now resolves the discovered agent desks once per frame and reuses the result for the title and geometry, avoiding duplicate catalog scans and API-count increments (`main.v`, follow-up after `91dcf9f`).

`set_pack_enabled` now validates the pack against the discovered catalog before writing state, preventing stale or arbitrary IDs from creating phantom pack configuration (`products_service.v`, follow-up after `ffc7904`).

`update_product_membership` now validates product IDs against `distributions/products.yaml` before writing membership state, preventing phantom products in the Engine store (`products_service.v`, follow-up after `0ff1cd9`).

Skill removal now requires the ID to be currently installed; stale or unknown rows cannot create removal receipts or mutate counts (`skills_service.v`, follow-up after `a619c2e`).

Agent removal now checks persisted installation state before writing a removal receipt, preventing unknown or already-absent agents from creating phantom state (`agents_service.v`, follow-up after `beb0387`).

MCP removal now requires the provider to be enabled in persisted Engine state before writing removal metadata; unconfigured providers cannot produce phantom receipts (`mcp_service.v`, follow-up after `e2a58d4`).

Target enablement now validates IDs against the discovered Engine target catalog rather than a duplicated hardcoded list. Unknown targets cannot create persisted enablement state (`targets_service.v`, follow-up after `8ff0869`).

Onboarding bulk target/product mutations now validate IDs against the live Engine catalogs, removing the last duplicated target roster and preventing invalid product membership state (`onboarding_service.v`, follow-up after `4a69b52`).

Swarm launches no longer claim a fabricated 100-token allowance. Budget totals remain zero until supplied by authoritative recipe/config state, and missing persisted totals default to zero (`swarm_service.v`, follow-up after `6dff5a3`).

Partial Swarm inner-loop records now default to `pending`, with an unknown iteration limit of zero, rather than claiming an active running loop with two iterations. Active state is shown only when persisted by the runtime (`swarm_service.v`, follow-up after `b83ef4f`).

Swarm budget views now clamp remaining tokens at zero and explicitly say “budget not configured” when no authoritative limit exists, instead of showing a negative or fabricated allowance (`swarm_service.v`, follow-up after `bb3e15e`).

Loop history now contains only persisted run records. The former three synthetic runs were removed; records without a completion event are marked `started`, and auxiliary `/status` keys are not double-counted (`loops_service.v`, follow-up after `8c0e32a`).

Persisted loops missing a goal now expose an empty goal rather than synthesizing `Goal <name>` text; the UI can distinguish incomplete configuration from authored content (`loops_service.v`, follow-up after `d92ff90`).

`create_loop` now preserves an empty user goal instead of generating `Goal for <name>`. New loops therefore distinguish authored objectives from incomplete setup (`loops_service.v`, follow-up after `3a2f550`).

Loop catalog entries with missing budget metadata now expose zero/unknown limits instead of the historical 80,000-token, one-run, 900-second defaults. Explicit Engine-created or YAML-provided budgets remain intact (`loops_service.v`, follow-up after `d2754a8`).

Loop catalog entries missing cadence metadata now keep cadence/schedule empty; the catalog no longer implies a daily schedule. Explicit create-loop defaults and YAML cadence remain supported (`loops_service.v`, follow-up after `206922f`).

Persona bootstrap now verifies that at least two persona files actually exist before persisting `personas_bootstrapped=true`; persisted `persona_count` reflects the files present, and failed writes return an explicit incomplete error (`onboarding_service.v`, follow-up after `7ab8418`).

Onboarding now considers a workspace valid only when the minimum managed scaffold (`knowledge`, `repos`, `projects`, and `packs`) exists. A partial directory can no longer be reported as ready (`onboarding_service.v`, follow-up after `b8cfff9`).

Workspace scaffolding now persists `workspace_initialized` from the filesystem verification result instead of unconditionally asserting completion. This keeps onboarding state aligned with the actual scaffold (`onboarding_service.v`, follow-up after `1f5200a`).

`onboarding_complete` now verifies the selected or recent workspace scaffold before persisting completion. A wizard cannot report “ready” against a missing or partial workspace (`onboarding_service.v`, follow-up after `5553b64`).

Engine target entries now derive from the core emitter catalog, with human-readable names and evidence-based profile paths/provenance. The Desktop no longer relies on a stale seven-item target roster or invents paths for unsupported integrations (`targets_service.v`, follow-up after `f1d7eff`).

Doctor receipt checks and receipt JSON now iterate over the same Engine target catalog and leave provenance blank when no persisted source exists. Onboarding's starter target selection also takes the first real catalog entries instead of naming an obsolete `cli` target (`engine.v`, `targets_service.v`, `main.v`, follow-up after `af892ef`).

Doctor's skill audit now validates that the resolved catalog is non-empty instead of freezing health on the historical count of 116. Legacy skill receipts with no recorded product keep that field empty rather than claiming `agent-toolkit-core` (`engine.v`, `skills_service.v`, `targets_service.v`, follow-up after `6762579`).

Removed the unconnected `3847` footer number from the production shell. The footer no longer displays a synthetic metric with no Engine source (`cmd/agent-toolkit-desktop/main.v`, follow-up after `47b3b49`).

Removed the footer's hardcoded `60FPS` claim and frame counter. Performance instrumentation is no longer presented as user-facing product state (`cmd/agent-toolkit-desktop/main.v`, follow-up after `cff4c39`).

The command palette now augments navigation with target entities discovered from `Engine.targets()`. Searching a target opens the Targets panel with a truthful enabled/disabled status, so users can discover real integrations without another static roster (`cmd/agent-toolkit-desktop/main.v`, follow-up after `444d6dc`).

Palette entries that previously claimed to run `serve`, `doctor --fix`, or `install` now expose the actual behavior: Doctor and skill installation open their review surfaces, while the unavailable server control was removed. Localized labels match these actions (`cmd/agent-toolkit-desktop/main.v`, follow-up after `82908a1`).

The Skills header no longer claims a hardcoded `60 FPS` rate; it describes virtualization without asserting an unmeasured performance figure (`cmd/agent-toolkit-desktop/main.v`, follow-up after `e146ebf`).

Palette search now adds matching skills and agents from Engine catalogs (bounded to eight of each), with direct navigation to their panels and clear entity labels. Empty palette state remains lightweight; entity results appear only after a query (`cmd/agent-toolkit-desktop/main.v`, follow-up after `37ebee5`).

MCP, Doctor, receipt and toggle feedback no longer claims provenance was verified merely because a transaction completed. The UI now says provenance is shown when recorded, while verification remains tied to actual Engine diagnostics (`cmd/agent-toolkit-desktop/main.v`, follow-up after `b2043f3`).

Targets now render the Engine-provided display name and enabled state directly, while the preview uses the same snapshot. Technical IDs remain available to the action layer without being the primary user-facing label (`cmd/agent-toolkit-desktop/main.v`, follow-up after `b0f1650`).

Targets and Skills footers now use task language (“enable”, “review”, “apply”, “install/remove”) instead of exposing Engine method names, receipt filesystem paths, or catalog filenames. Technical detail remains available in diagnostics and inspector context (`cmd/agent-toolkit-desktop/main.v`, follow-up after `a71954b`).

Skill toggle feedback now distinguishes the committed receipt from optional provenance evidence; it no longer marks provenance as verified when the transaction only recorded installation state (`cmd/agent-toolkit-desktop/main.v`, follow-up after `f55d58d`).

Removed revision and API-call counters from Office and onboarding chrome. User-facing status now emphasizes live state and task counts; engine diagnostics remain available through the diagnostic surfaces (`cmd/agent-toolkit-desktop/main.v`, follow-up after `8656d21`).

Office's empty activity message now checks only jobs in the `running` lifecycle state. Completed or queued history cannot suppress the truthful “No agents are currently running” state (`cmd/agent-toolkit-desktop/main.v`, follow-up after `d2038a9`).

Targets now leads with the user question “Where will capabilities be available?” and uses “change recorded”, “no changes yet”, and “not enabled” in rows. This keeps receipts as an understandable change history while hiding implementation vocabulary from the primary workflow (`cmd/agent-toolkit-desktop/main.v`, follow-up after `e48aa58`).

MCP now leads with “Connect context and tools safely” rather than exposing the internal template path in its primary header. The path remains available in the detailed configuration footer and drawer (`cmd/agent-toolkit-desktop/main.v`, follow-up after `ba9df5a`).

Doctor's constrained-window and footer messages now give actionable review guidance and avoid claiming that all checks are English or that fallback data is absent. Copy reflects the actual localized, evidence-backed diagnostic surface (`cmd/agent-toolkit-desktop/main.v`, follow-up after `541928b`).

Jobs, Loops, and Swarms now use task-oriented headers and footers. Primary surfaces describe live work, budgets, handoffs, approvals, and recorded artifacts without requiring users to understand StateRepository, EventBus, or backend implementation names (`cmd/agent-toolkit-desktop/main.v`, follow-up after `b6155f1`).

Workspace file browsing and editing now use user-facing language (“workspace files”, “open a file from the tree”, and “staged flag”). Brokered filesystem implementation terms remain confined to code and diagnostics rather than the primary editor workflow (`cmd/agent-toolkit-desktop/main.v`, follow-up after `8738c01`).

The global action palette is now branded as Agent Toolkit’s “Search / Run” surface. Its navigation descriptions explain user outcomes for loops, swarms, and insights instead of exposing internal mailbox, backend, or telemetry terminology (`cmd/agent-toolkit-desktop/main.v`, follow-up after `ed39e3f`).
