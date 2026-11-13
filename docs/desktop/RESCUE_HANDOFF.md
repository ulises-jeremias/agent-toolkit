# Agent Toolkit Desktop rescue — execution handoff for GPT-6-Luna

Updated: 2026-11-13 (packaged Desktop suite and World iteration 7).
Requested by the owner to
preserve the complete mission and continue with GPT-6-Luna without repeating
expensive discovery.

**The rescue is NOT complete.** This file is an execution checkpoint, not an
acceptance report. Continue implementing and validating the product. The owner
explicitly rejected stopping at an audit, roadmap, prototype, screenshots, or
merged PR count.

## 1. Mission and authority

Become the integration owner of Agent Toolkit Desktop and deliver a beautiful,
coherent, local-first coding-agent application that can replace the owner's
usual coding-agent app for real work.

The owner authorized radical UI/architecture replacement, ordinary engineering
decisions, bounded delegation, focused PRs, compatible merges and closing
superseded work with a reason. Preserve user data, credentials, security,
authorship, Git history, reproducibility, useful CLI capabilities and migration
paths. Do not publish a broken release, bypass branch protection or weaken
checks. Escalate only real external blockers, irreversible data risks or
security-sensitive actions outside existing authorization.

Conversation: match the owner (latest request is Spanish). Repository artifacts,
commits, issues and PRs: English. Use existing AGENTS.md and scoped instructions.
The original mission remains in the conversation; this file covers its execution
requirements and current state.

## 2. Start here: exact workspaces and preserved work

Main integration worktree:

```text
/home/ulisesjcf/.ai-workspace/worktrees/desktop-owner
branch: rescue/codex-product-integration
HEAD: latest integration checkpoint, ahead of origin/main; not pushed
```

The integration edits described below are committed on this branch. Keep this
integration worktree intact; it is not the same branch as the pushed follow-up PR.

| Location / branch | State and handling |
| --- | --- |
| `repos/agent-toolkit`, `chore/release-v1.47.5` | Old checkout, unrelated dirty release/version/plugin files and `.claude/`. Preserve; do not use as current product source. |
| `worktrees/rescue`, `rescue/shell-v2`, `0c730540` | Existing PR #1780; replacement shell, onboarding, Focus, Projects/Context and new Valley. Preserved in integration branch. |
| `worktrees/desktop-owner`, `rescue/codex-product-integration` | Started from canonical main `3e08b51e`; local merge `dbbbcb57` preserves rescue commits. Protocol fix cherry-picked as `8a753ec5`. Rescue checkpoints are pushed to this branch; latest documented checkpoint is `aa67c8eb`. |
| `worktrees/desktop-followup`, `rescue/desktop-continuity-focus` | Pushed draft PR #1783, current head `4b769c0f`; includes continuity/runtime follow-up, Focus-first navigation, semantic World, original civic facades, responsive fitted overview camera, and reduced ground/flower/path noise. It is not merged into the integration worktree. |
| `worktrees/codex-protocol`, `rescue/codex-protocol`, `2b8de6d6` | Reviewed protocol fix; already cherry-picked as `8a753ec5`. Do not apply twice. |
| `worktrees/workspace-continuity`, `rescue/workspace-continuity` | Uncommitted partial implementation by subagent; NOT reviewed, tested or integrated. See critical persistence flaw below. |
| `.claude/worktrees/agent-a8c96dfe4dfec7e8d`, `rescue/valley-art` | Existing art work; preserve. Do not infer an active agent from the worktree. |
| Old PXL/web/a11y/history worktrees | Inspect PR relationships before any cleanup. No cleanup was authorized as part of this handoff. |

All paths above are relative to `/home/ulisesjcf/.ai-workspace` unless absolute.
Run `git worktree list` again to detect changes after this snapshot.

### Committed integration edits (not yet accepted as shipped)

- `electron/focus/service.ts`: registers Codex adapter; rejects overlapping
  messages when the adapter cannot accept input during a running turn, including
  the race after two callers await one startup. Rejected messages are not journaled.
- `electron/focus/adapter.ts`: `acceptsInputWhileRunning` session capability.
- `electron/focus/claude.ts`: capability true; forced disposal immediately kills
  the process group. A future kill timer cannot be relied on after Electron exits.
- `electron/focus/providers.ts` and `src/types/focus.d.ts`: optional
  `sendWhileRunning` UI capability, false by default; true for supported Claude.
- `src/features/focus/Conversation.tsx`: retains drafting but disables send while
  a provider cannot accept another message; explains the wait/stop choice.
- `src/features/focus/NewSession.tsx`: recovery copy includes Claude and Codex.
- `src/features/focus/NewSession.tsx`: synchronously rejects overlapping submissions
  before React renders the disabled state; a regression proves two Ctrl+Enter presses
  while creation is pending produce one thread/send sequence.
- `electron/terminal.ts`: catches unsolicited refresh failure on host disconnect
  and retries on next list, eliminating the identified unhandled rejection path.
- `electron/focus/focus.test.ts`: concurrent-send regression proving no phantom
  user message and no second provider send.
- `docs/desktop/audits/`: new sanitized forensic and reference reports.
- This handoff document.

Do not describe these as shipped. The built `dist` predates some of these edits.

### Partial continuity worktree

Dirty files: `src/shell/Shell.tsx`, `home.ts`, `useSessionContext.ts`;
untracked `NavigationContinuity.tsx`, `NavigationContinuity.test.tsx`,
`navigationMemory.ts`.

Intent: Focus as default destination, per-workspace last route restoration,
backend harness as workspace authority, validated internal route/query scope.
The implementation uses `localStorage`: **do not integrate that persistence
approach unchanged**. See priority P0 below. Preserve/reuse the useful validation
and workspace reconciliation logic after review.

### Delegation status

The forensic and reference research finished. The Codex protocol implementation
finished and was integrated. Later continuity and provider-sign-in tasks hit the
host's model usage limit. No agents should be assumed to remain working.
Provider sign-in reached a source-based design only; no sign-in worktree was
present in the final worktree inventory. Recheck before starting it.

## 3. Verified evidence — read these, do not repeat the audit

- [Independent Muse forensic audit](audits/MUSE_SESSION_2026-11-12.md).
- [Pinned reference source/license research](audits/REFERENCES_2026-11-12.md).
- Existing [rescue record](RESCUE.md), [ADR-044](../adrs/ADR-044-desktop-session-runtime.md).
- [Runtime architecture audit](audits/RUNTIME_2026-11-12.md). Its facts are summarized below; the original temporary copy also remains at `/tmp/desktop-runtime-audit.md`.

Muse session `01a1c6ee-e6b9-7aa2-bcbd-07fb9e2b3822` was recovered using supported
redacted export. Private export:
`/home/ulisesjcf/.ai-workspace/.audit-private/muse-audit.json` (~173 MiB).
Original root log:
`~/.local/share/muse/sessions/2026/11/10/<session-id>/session.jsonl`.
Root and 36 retained child logs were inspected; 77,766 export events, 20 turns,
22 accepted spawns, three workflows. 4,780 omitted live-only markers do not mean
missing durable history. Do not print or commit the export/private transcripts.

Important findings:

1. Discovery warned that productive Focus had to precede World work, but the
   session pursued art first. Later real-provider trials disproved earlier
   claims that all executable work was done.
2. PXL/code/release work was real; it did not establish daily-driver usability.
3. A child accidentally pushed to main due to upstream push configuration;
   branch protection prevented force restoration, and a revert preserved recovery.
   Inspect push config and use explicit branch refspecs.
4. OpenCode coding was quota-blocked; later Codex success did not resolve that
   provider-specific gate.
5. Target session ends at Nov 12 05:45 UTC. #1773/#1774 merged afterward;
   #1780 is later work, not part of that session.
6. #1780's body is stale: its latest commits already render the new village and
   wire Projects/Context despite prose saying otherwise.
7. Existing RESCUE.md attributes process loss to memory pressure more strongly
   than the independent log evidence supports. Correct it to observed process
   loss unless separate causal evidence is supplied.

Reference clones are under `.audit-private/references/` (t3code, agent-office,
munder-difflin, pixel-agents). All source roots are MIT; Munder art has separate
LimeZu terms. Do not copy reference art. Transfer native structured sessions,
request-bound approvals, bounded replay, persistent terminal ownership and
verified session-to-character identity. Source research is complete; hands-on
reference-app UX comparison is not.

## 4. Architecture decision to carry forward

Continue **option B / hybrid**: replacement coherent frontend over useful V domain
APIs and Electron provider/PTY infrastructure, as ADR-044 already establishes.
Retain React/Electron unless actual measured behavior justifies further replacement.

- Option A (only in-place patching): useful for reusable domain views, insufficient
  as the overall UX strategy.
- Option B (new coherent frontend over validated contracts): selected; preserves
  data/security and gives the fastest integrated coding journey.
- Option C (full reconstruction including backend): no verified benefit currently
  outweighs migration/security/packaging cost. Reconsider only with concrete evidence.

V owns projects/Git/catalog/install/people/context/memory/jobs/loops. Electron main
owns structured provider processes, event journals and narrow IPC; the sandboxed
renderer projects those states. Keep one authoritative history per Focus thread:
`<workspace>/.agent-toolkit/focus/threads/<id>/{thread.json,events.jsonl}`.
Preserve journal no-follow/symlink protections from #1779 and existing IDs.

Structured Focus stops when Desktop closes; history persists and provider resume
may continue later. Detached ordinary PTYs have a different lifetime. Explain this
honestly. Never label a declared Person or installed binary as an active agent.

## 5. Immediate priorities (next work session)

### P0 — Reliable restart and workspace identity

- [x] Replace origin-bound persistence with an Electron-owned typed preference store:
  onboarding completion, appearance and a validated per-workspace destination are
  atomically stored under userData. The ephemeral renderer origin is no longer the
  source of truth.
- [x] Make Focus the new-workspace home. Preserve explicit deep links, make backend
  harness identity authoritative, clear project/thread scope from stale workspace
  URLs, and never persist PTY selection in route memory.
- [x] Reproduce a full close/reopen with the same Electron profile; packaged app
  reopened the same completed Claude thread and workspace from userData/journal.
- [x] Verify that renderer-server.ts
  listens on port `0`, producing a different origin on each launch. Onboarding
  completion and theme previously used localStorage, while the origin varies. The
  source-level risk is confirmed; a packaged restart check remains open.
- [x] Reconcile a deleted thread explicitly: Focus reports that the saved session
  is unavailable and offers “Return to sessions” instead of silently showing a new
  composer. Deleted/moved projects still need a recovery pass.
- [ ] Verify PTY lifecycle separately. The acceptance package restored a detached
  terminal registry session, expected for ordinary PTYs, but route memory does not
  persist a PTY selection.
- [x] Make Focus the normal work entry; World remains optional navigation, not a gate.

### P0 — Finish and verify the real Focus runtime

- [x] Review current dirty edits and run focused tests/type checking.
- [x] Retain `8a753ec5`: thread/turn filtering, request-bound approval ownership,
  stale turn/start protection, visible unsupported requests, explicit user reviewer,
  failed-interrupt reporting and immediate forced process-group stop.
- [x] Review high-impact #1780 Focus findings: stale overlapping thread-list reloads now
  carry a generation guard; pending approval no longer steals focus to `Allow once`;
  composer drafts are held per thread across session navigation; and indented Markdown
  headings cannot trap the parser without advancing; and native Dialog closes still notify
  their owner when focus cannot safely return into a parent modal. Regressions are covered in
  `src/data/focus.test.ts`, `src/features/focus/Conversation.test.tsx`,
  `src/features/focus/Markdown.test.tsx`, and `src/ui/ui.test.tsx`. Remaining #1780 review
  items still need triage.
- [x] Add bounded 30-second Codex app-server request deadlines; clear pending timers
  on response, close, and disposal; surface timeout errors; and stop an unresponsive
  process after a failed handshake or turn/start request. Fake-server tests cover
  initialize timeout, turn/start timeout, forced disposal cleanup. The packaged Codex
  adapter also completed a separate real task with approval, tool failure recovery, and
  independent test verification (see the live acceptance record). Broader protocol parity
  remains open.
- [x] Keep Codex token usage honest: official app-server schema separates `last`
  and thread-cumulative `total`, and Codex describes `last` as active context size.
  Focus aggregates provider usage as per-turn spend, so Codex usage is now reported
  unavailable (`null`) until turn deltas can be derived safely. Regression coverage
  confirms neither context nor thread totals are mislabeled. Sources:
  [generated schema](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/json/v2/ThreadTokenUsageUpdatedNotification.json),
  [Codex TUI usage semantics](https://github.com/openai/codex/blob/main/codex-rs/tui/src/token_usage.rs).
- [x] Verify the installed Codex app-server 0.167.2 schema and enforce approval scope:
  only advertise/accept `acceptForSession` when listed in `availableDecisions`, check
  decisions again in the main process, refuse a prompt when Focus cannot represent its
  required one-shot allow/deny choices, and retain `networkApprovalContext`, additional
  permissions, policy amendments, `grantRoot`, and the raw choices in the inspectable
  event. Fake protocol regressions cover advertised, limited, and unsupported choices.
  This is protocol/schema verification plus local tests, not a live approval test after
  the code change; keep the real-provider approval gate below open.
- [x] Guard Focus new-session creation synchronously against repeated Ctrl+Enter
  submissions while provider thread creation is pending. A deferred-create component
  regression asserts one thread and one send; the disabled button alone was insufficient
  because React state updates occur after the event handler begins.
- [ ] Implement interactive questions/new permissions RPCs if needed for normal
  work. Current behavior explicitly refuses unsupported requests with an error notice;
  that is honest but not complete functionality.
- [ ] Verify streaming partial output, tool outputs, completion, errors, approval,
  deny, interrupt, resume, model/permission changes, and child-agent events live.
- [ ] Keep parent and native child sessions distinct; child completion cannot close
  the parent turn or pollute its journal.
- [ ] Ensure cancellation/shutdown leaves no provider or descendant mutating files.
- [ ] Evaluate redaction at display/export boundaries: clipping is not secret
  masking. Do not corrupt provider inputs or publish private journals/screenshots.

### P0 — Packaged Linux acceptance

- [ ] Build backend with the repository's exact pinned V/VC/TCC toolchain (see
  commands below). The private Linux amd64 toolchain inputs are pinned and verified
  (`v=c0e47bf2`, `vc=9f82f2e3`, `tcc=d6e7ac1b`). Cold bootstrap via the repository's
  exact `make local=1 -j1`, under the required 2 GiB / zero-swap scope, was OOM-killed
  while compiling V2. The toolkit backend was not built with this toolchain; keep this
  gate open. Retain the private clone at `.audit-private/tmp/desktop-v-pinned/` for a
  future bounded attempt; do not increase the resource cap silently.
- [x] Rebuild renderer/main, stage the existing backend binary from rescue commit
  `0c730540`, and package `dist:dir` for Linux x64. No V source changes exist between
  that binary's source commit and this integration branch. This is a packaging
  smoke artifact, not acceptance of a newly compiled backend.
- [x] Launch the exact unpacked package and verify UI/backend with the same profile
  across a close/reopen. It returned to the completed Focus thread, provider discovery,
  project, transcript, approval/tool events, and diff.
- [x] Use isolated Electron userData/profile and disposable Git repositories. Keep
  real provider authentication separate; no credentials or private provider traces were
  copied into fixtures.
- [ ] Drive the complete 13-step journey in section 9 from the UI. Workspace creation
  was through onboarding; the existing repo was initially registered by CLI, so UI
  registration/native picker remains open. The headless test process cannot access the
  user session display: DISPLAY=:1 is absent, while DISPLAY=:0 requires the SDDM-owned
  Xauthority cookie. Do not change desktop login permissions to force this test. Other live
  Focus, terminal, diff, restart, history, and World-context steps have been exercised.
- [x] Record sanitized partial live acceptance with app hash, source commit, provider/OS
  versions, tests, screenshots, and remaining gates in
  [LIVE_ACCEPTANCE_2026-11-12.md](audits/LIVE_ACCEPTANCE_2026-11-12.md).
- [ ] If quota/auth prevents a task, record the real limitation, continue independent
  work and leave that provider gate open. Do not replace live evidence with mocks.

### P1 — In-app provider sign-in (planned, not implemented)

Existing TerminalPane can support an embedded login dialog, but PtyHostCore writes
all output to `pty-<id>.log`. Login output can include device codes/browser URLs.
Do not simply launch auth through the ordinary persistent terminal.

- [ ] Add explicit ephemeral PTY mode through types/protocol/service/host.
- [ ] Do not journal ephemeral output or put auth sessions in the persistent registry.
  Keep only the in-memory display needed for interaction; discard on close.
- [ ] Terminate auth session on dialog dismissal/app shutdown; do not adopt it as an
  ordinary surviving terminal on restart.
- [ ] Main-process fixed provider allowlist resolves installed binaries and args:
  Claude `auth login`, Codex `login`. Renderer sends a provider ID, not a command.
- [ ] Implement reusable embedded `ProviderSignIn` dialog with real terminal,
  cancellation, keyboard focus and error states.
- [ ] Integrate into onboarding and Focus NewSession without requiring an external TUI.
- [ ] Refresh provider account status after completion/manual check; exit code zero
  alone does not establish authentication. Preserve explicit user initiation.
- [ ] Test no secret-bearing output/registry persistence and forced auth cleanup.

## 6. Complete product backlog — all mission domains

### Shell, onboarding and projects

- [ ] Review current rescue shell at all required sizes; eliminate confusing duplicate
  navigation, excessive chrome and internal/auditor-facing language.
- [ ] Workspace/project/session identity must remain visible and consistent across routes.
- [ ] First-run create/reuse workspace, link existing external repository, discover/sign
  in provider and begin a task must be obvious and recoverable.
- [ ] Verify existing-data path and safe rollback; never migrate by overwriting user files.
- [ ] Project registration/switching, repository status, files, Git history and contextual
  actions must use canonical APIs and valid selections after refresh/filter/switch.
- [ ] Fix missing/deleted repository, unavailable backend, slow startup and retry states.
  Missing saved Focus threads now have an explicit recovery message; other cases remain.
- [ ] Support compact windows and keyboard/mouse/trackpad without hidden critical actions.

### Focus — central user experience

- [ ] Review conversation density/readability, Markdown/code, selection/copy and scroll
  anchoring. Reading earlier output must not be interrupted by new deltas.
- [ ] Composer retains draft on failure/navigation as appropriate; no phantom accepted
  messages or claims that notes are queued when the protocol cannot queue them.
- [ ] Provider/model selection is discovered and capability-driven; unknown/unsupported
  states stay explicit. Do not expose a selector that does nothing.
- [ ] Tool calls expandable/inspectable with real status and output, useful errors,
  approvals/questions and safe intervention.
- [ ] Project changes/files beside conversation; actual diff paths and actions work.
- [ ] Real terminal in current repository, usable selection/resize/keyboard, continuity
  across routes and reliable shutdown/recovery.
- [ ] Durable history and honest resume behavior after crash/close/provider loss.
- [ ] Review accessibility of approval focus (avoid stealing unrelated user input),
  dialogs, live announcements and Stop/Escape precedence.

### People, agents, Library, context and memory

- [ ] Distinguish reusable Person, agent definition, provider installation, real session,
  task run and native subagent in names and interactions.
- [ ] People CRUD/archive/restore/start/restart works and never implies fake runtime life.
- [ ] Library search with good descriptions, detail preview, installed/catalog distinction,
  target compatibility, scope selection, preview-before-install and truthful receipts.
- [ ] Skills, agent definitions, MCP and tools are discoverable without overwhelming users.
- [ ] Context packs, project knowledge and durable memory can be inspected, edited and
  controlled; show what is included and where it belongs. No hidden automation claims.
- [ ] Validate settings, workspace changes, error/empty/loading/disconnected states.

### Operations and workflows

- [ ] Real workflows, jobs/delegations, approvals, failures, recovery and execution history
  share the product's vocabulary and selected workspace/project.
- [ ] No fabricated dashboard metrics or decorative activity. Unknown is an honest state.
- [ ] Review existing swarm/task implementations; preserve working capabilities, remove
  obsolete duplicate abstractions only after mapping data and migration requirements.
- [ ] Attention indicators lead directly to the real intervention and clear when resolved.

### World and original visual identity

Use `skills/design/pxl-pixel-art/SKILL.md` and its referenced governance before editing
art. Read current DESIGN/VISUAL_QA/SEMANTIC_WORLD and challenge old decisions against
actual screenshots. No reference project's proprietary art is permitted.

- [x] Critique the actual new Valley, not just the earlier 201-sprite set. A fresh
  packaged Electron capture exposed a fixed-initial-height scale, compact horizontal
  clipping and a Meadow/Dusk renderer that always selected `sky_day.png`. Responsive
  measurement, width-constrained scene composition, scene-edge clipping, Dusk sky,
  restrained environmental lamps and honest activity-lit buildings are implemented.
  Real captures were opened for Meadow/Dusk at 1024×640, 1440×900 and 1920×1080;
  the compact horizontal scrollbar is gone and Dusk is visibly distinct. The World
  still needs broader layout/art critique.
- [ ] Cozy original pixel world with coherent perspective, light, depth, composition,
  recognizable project buildings and meaningful Library/Archive/Workshop/Operations.
- [x] Begin original art re-authoring with a restrained Hornero Valley palette,
  six 64×64 authored tree silhouettes and a distinctive 64×64 adobe Library with
  an attached kiln/archive tower and readable book gallery. The first PXL preview
  was integrated and inspected in the packaged Electron World. This is one
  implementation/capture iteration, not art sign-off; screenshot critique still
  finds a visually straight canal, dense repetitive foliage, and civic/project
  façades that still need distinct compositions.
- [ ] Professional readable technical typography; pixel display type used sparingly.
- [ ] Real session-backed characters only. Decorative animals/weather never imply work.
- [ ] World is optional spatial context, not a compulsory avatar-walking interface.
- [ ] Every real action has normal navigation/keyboard access and shares canonical state.
- [ ] Preserve project/session context entering/leaving World/interiors.
- [ ] Restrained animations, reduced motion, efficient rendering and useful empty state.
- [ ] Continue capture → open → critique → fix → recapture iterations before visual sign-off.
  One source-Electron iteration now covers all ten destinations in Meadow and Dusk at
  1024×640, 1440×900 and 1920×1080, including a real Git diff, terminal, jobs, People
  dialogs and Focus's honest unauthenticated empty state. All 60 destination captures
  plus two People-dialog captures were generated and opened via contact sheets and
  representative full-resolution review. Repeat after keyboard/compact-window review;
  onboarding, interiors, conversation/tool/approval, error/loading/disconnected states
  and another art iteration remain open. Large World captures still have substantial
  vertical negative space.
- [x] After art iteration 1, regenerated all 201 governed PXL assets and built a new
  Linux x64 unpacked package from the current renderer/main source, staging the
  source-compatible backend from rescue commit `0c730540`. The packaged Electron
  capture suite passed World in Meadow and Dusk at 1024×640, 1440×900 and 1920×1080
  using Electron's `--ozone-platform=headless` test mode; screenshots are private at
  `/home/ulisesjcf/.ai-workspace/.audit-private/world-art-iteration-1/`. This proves
  packaged rendering and responsive capture, not a window-manager/native-display
  acceptance pass. Xvfb could not create its lock in `/tmp` due the host's quota;
  the session-owned display was not accessed.
- [x] Art iteration 2 exposed and rejected conspicuous rectangular ground-tone patches.
  A third, subtler prototype limits the palette shift to a close sage shade. It passed
  six more packaged Electron World captures at the same Meadow/Dusk viewports; opened
  screenshots show no high-contrast rectangular patches. Private captures are in
  `/home/ulisesjcf/.ai-workspace/.audit-private/world-art-iteration-{2,3}/`. The scene
  remains visually incomplete and requires further terrain, foliage and architecture
  passes.
- [x] Latest art verification: the full Desktop suite passed on the third prototype
  (80 Vitest files / 608 tests plus 45 Node runtime tests); TypeScript type-check,
  ESLint, `check:world` (201 deterministic sprites), `build:all`, and `dist:dir`
  completed. The terrain/model focused suite passed (55 tests). Packaged Electron
  capture runs passed six viewports for each of the three art iterations. The build
  continues to report the existing 670.97 kB main renderer chunk warning. Independent
  art review and owner visual sign-off remain open.
- [x] Re-authored and reviewed Archive, Workshop and Operations PXL facades in
  packaged Electron. The compact 1024×640 and large 1920×1080 captures read well;
  the 1440×900 map composition leaves excessive empty surround. An earlier
  review incorrectly said the Dusk screenshot retained Meadow colors; checkpoint
  11 records that correction. Source generation, 72 World tests, all 608 Vitest + 45
  Node spike tests, type-check, lint and build pass on exact commit `c07fdcc6`.
  Its hosted exact-head checks are still pending; see checkpoint 11.
- [x] Replaced player-follow as the initial World mode with a fitted semantic
  overview. Camera zoom is selected from actual room/map bounds, with additional
  nearest-neighbor tile-size steps; packaged Electron E2E verifies the map fits
  and occupies at least 80% of viewport width at all six Meadow/Dusk viewports.
  Exact local validation is recorded at checkpoint 12; hosted checks for
  `8a8037ac` are still running. This improves framing, not the underlying art.
- [x] Calm map-scale terrain marks with a fifth PXL art iteration: muted
  two-pixel grass blades, smaller flower tiles and glades, and fewer path flecks.
  The all-flat prototype exposed square tone bands and was rejected. Opened six
  packaged Electron screenshots in Meadow and Dusk at the three required sizes.
  Full Desktop test command passed (609 Vitest + 45 Node tests), as did type-check,
  ESLint, 201-sprite determinism, `dist:dir` and packaged capture. The square
  scene boundary, straight creek, repetitive tree crowns and front-facing houses
  remain defects. See checkpoint 13 and the product-worktree visual audit.
- [ ] Reject generic SaaS card grids, PaperCo aesthetics, random clutter, illegible pixel
  text, disconnected palettes and needless configuration.

### Multi-provider and advanced work

- [x] Prove Claude and Codex independently with separate bounded live tasks in
  separate disposable repositories; acceptance evidence is in
  [LIVE_ACCEPTANCE_2026-11-12.md](audits/LIVE_ACCEPTANCE_2026-11-12.md).
- [ ] Expand provider parity evidence for approval variants, interruption/resume,
  errors, model changes, and native child behavior. No Codex success is inferred
  from the Claude task.
- [ ] Tighten OpenCode auth parsing: successful nonempty `auth list` output alone is
  insufficient proof. Detect actual account/provider state.
- [ ] Add OpenCode structured adapter only after verifying current installed protocol,
  permissions, cancel, resume and authentication. Keep unsupported state until then.
- [ ] Verify delegations/native children, capacity/error recovery and workflow semantics
  without inventing extra sources of truth.
- [ ] Research other installed current agent interfaces where it helps; use primary
  source/protocol evidence. Do not add a dependency solely because a reference uses it.

## 7. GitHub and integration backlog

Observed canonical main: `3e08b51e` (refresh before acting).
Existing mission: [#1775](https://github.com/ulises-jeremias/agent-toolkit/issues/1775),
parent [#1667](https://github.com/ulises-jeremias/agent-toolkit/issues/1667).
**Do not create a duplicate mission.** Update #1775 with verified slice evidence.

- [ ] Refresh #1667, Gates #1668–1676, linked acceptance/docs and current open
  PRs. A fresh check on 2026-11-12 found #1782 no longer running: its `gates`
  and packaged Electron jobs failed; independent Python/CLI validation jobs
  shown on that PR passed.
- [x] #1773 external repo linking and #1774 true first-run are merged; preserve them.
- [x] #1776 Claude runtime and #1779 journal hardening are merged; preserve them.
- [x] Correct #1780's stale description: it now reflects that Valley is rendered,
  distinguishes its unwired Codex prototype from the later provider work, and records
  the latest failing test names and run links. Keep this base PR distinct from the
  focused downstream fixes.
- [ ] Complete independent source-level review of #1780 against current contracts and
  architecture; inspect remaining review threads/CI before integration. Do not infer
  acceptance from the updated description.
- [ ] Review outstanding review threads/CI, not merely reported pass counts.
- [x] Push the continuity/runtime slice as draft [#1783](https://github.com/ulises-jeremias/agent-toolkit/pull/1783),
  stacked on [#1782](https://github.com/ulises-jeremias/agent-toolkit/pull/1782), which
  is itself stacked on #1781 and #1780; post verified acceptance status to
  [#1775](https://github.com/ulises-jeremias/agent-toolkit/issues/1775).
  #1780/#1781/#1782 have failing Desktop gates; this draft remains unmerged pending
  a healthy, reviewed base. The draft now includes the art iteration and ground-tone
  refinement at `bbbf483f0172a2faf62d03f382eccea92d510bfb`. At 01:09 UTC on Nov 13,
  exact-head Validate (43342634909), packaged Electron with fresh HOME
  (43342634883), Desktop `gates` (43342634915), and web `quality` (43342634953)
  were pending; Danger was skipped.
  The prior Validate/Release/clean-machine runs reference older heads and do not
  validate this commit. Do not report pending or in-progress
  checks as passing. The local
  changed-area checks are recorded below. #1782 corrects stale
  shell smoke assertions
  (empty-state headings and the six-place rail) and disambiguates a project row from
  its toast. The failing desktop run is specifically four packaged Electron journeys,
  not those renderer smoke assertions: context pack navigation targeted Projects
  instead of Library's Context tab; two Git changes tests assumed an obsolete review
  dialog and selected a nested generic section; workspace switching linked a folder
  that was not a Git repo and then confused the linked-project toast with its row.
  The standalone project-link journey passes. These cases are corrected in this
  branch and reproduced locally with Electron + the real backend. Run IDs:
  desktop 43298967157; packaged 43298966315. The packaged job's failures match these
  stale journeys; re-run hosted CI on the corrected branch before drawing a new result.
  Do not waive these failures or merge the stacked series.
- [ ] #1771 ImgBot was open; inspect deterministic-art drift before merging or closing.
- [ ] Preserve author commits through cherry-pick/rebase. Never replace them with one
  newly authored aggregate commit or force-push away independent work.
- [ ] Independent review of integrated changes before committing remaining work/pushing.
- [ ] Use explicit refspec, e.g. `git push origin HEAD:refs/heads/<topic>`.
- [ ] Required checks and review obligations must pass before merge; no security bypass.
- [ ] Verify main after merge. Merged code is not acceptance and does not justify closing
  outcome gates. Release only with proper authorization and verified artifacts.
- [ ] Reconcile ADRs, current product docs, workflows.yaml and daily-driver evidence so
  fixture/component coverage cannot masquerade as live installed-app acceptance.

## 8. Environment and commands that matter

Workspace protocol was run: context, memory inject, todo. Read workspace/repo AGENTS
again if starting a new session; use `workdir`, not `cd &&`.

### Temp storage and display

`/tmp` reported free space but failed writes with quota error. Chromium produced
`ERR_INSUFFICIENT_RESOURCES`, blank UI and one renderer crash. Moving TMPDIR to the
home filesystem resolved loading. Do not delete other sessions' temporary files.

Use a private directory under:
`/home/ulisesjcf/.ai-workspace/.audit-private/tmp`.

No usable display was reachable at the inherited DISPLAY/Wayland variables. A
local Xvfb package was downloaded from the configured Arch mirror, its detached
signature verified with the system pacman keyring, and extracted without installing
system packages. Binary:
`.audit-private/xvfb/usr/bin/Xvfb`.

Launch it via a managed exec session:

```sh
/home/ulisesjcf/.ai-workspace/.audit-private/xvfb/usr/bin/Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp
```

The temporary Xvfb process was stopped after this handoff; restart it before GUI work.

Then use `DISPLAY=:99`, `TMPDIR=<private home temp directory>`, and Electron
`--ozone-platform=x11 --disable-gpu` when this host needs them. Record test-only
flags; do not bake them into production to hide a real defect.

### V backend

Before every local V invocation: `pgrep -a -x v`; wait for other V processes.
One command at a time, `VJOBS=1`, 2 GiB memory cap, zero swap via systemd-run.
On GitHub-hosted CI use V directly with low VJOBS, no systemd-run.

The attempt with `/usr/local/bin/v` FAILED in `generate-embedded-data.vsh` with
misleading argument-count errors around `mut &files`. Do not patch product source
for this before selecting the correct compiler. Repo `.v-version` says `master`;
CI pins V/VC/TCC in `.github/actions/setup-v/action.yml` (V c0e47bf2...).
`/home/ulisesjcf/vlang-master/v` exists and is the documented candidate; verify its
revision. Ensure both the vsh shebang PATH and VBIN use that toolchain.

```sh
systemd-run --user --scope -p MemoryMax=2G -p MemorySwapMax=0 \
  env VJOBS=1 TMPDIR=/home/ulisesjcf/.ai-workspace/.audit-private/tmp \
  PATH=/home/ulisesjcf/vlang-master:/usr/local/bin:/usr/bin:/bin \
  VBIN=/home/ulisesjcf/vlang-master/v ./make.vsh build-cli
```

No new backend binary was produced by the failed attempt. The exploratory app
used `worktrees/rescue/build/agent-toolkit`; do not confuse that with a fresh,
provenance-verified integration build.

### Desktop validation/package

Dependencies already installed with frozen pnpm lockfile in integration tree.
No legacy-peer-deps or override workarounds. Use package scripts and the narrow
commands appropriate to the next change:

```sh
pnpm --filter agent-toolkit-desktop type-check
# Run from apps/desktop for a genuinely focused Vitest run:
pnpm exec vitest run electron/focus electron/terminal.test.ts src/features/focus/Conversation.test.tsx
pnpm --filter agent-toolkit-desktop lint
pnpm --filter agent-toolkit-desktop build:all
pnpm --filter agent-toolkit-desktop dist:dir
```

`pnpm test -- <file>` previously ran the entire Vitest suite because the package
script chains another test runner; use `pnpm exec vitest run <paths>` for filtering.

Packaged E2E supports `ATK_E2E_APP_PATH` and `ATK_E2E_BACKEND_BIN`; its default
fixture creates a temporary HOME and therefore intentionally lacks real user
provider credentials. Design live acceptance to keep clean app state while using
auth through the user's provider configuration without copying secrets.

Exploratory runner: `.audit-private/inspect-desktop.cjs`. It is a local diagnostic,
not a final acceptance harness. It uses a temporary HOME, initializes workspace
with CLI, reloads the page and captures onboarding. Therefore it does NOT prove
UI first-run workspace creation or real-provider acceptance.

## 9. Mandatory installed-app acceptance (partial; live journey still open)

Use a disposable repository; record exact executable/hash, source commit plus dirty
state, backend version, provider version, OS, profile and sanitized evidence.

1. [x] Open packaged Linux Desktop with clean isolated Electron user profile.
2. [x] Create workspace through onboarding UI.
3. [ ] Register existing Git repository through UI (including outside workspace root); the native directory picker remains un-driven in headless mode.
4. [x] Discover real authenticated Claude and Codex providers; auth and quota are treated separately.
5. [x] Start real Claude and Codex coding tasks in disposable repositories.
6. [x] Observe messages, structured tool calls, approvals, failures and process completion.
7. [x] Inspect actual generated file changes and diffs independently and in Focus.
8. [x] Use real terminal in project (real `/usr/bin/zsh`, verified cwd and Git status).
9. [x] Intervene safely: reviewed and approved two scoped Claude tool requests
   (“Allow once”), then verified resulting files and passing tests. A live cancel/deny
   during mutation remains an additional test.
10. [x] Close and reopen the same installed app/profile.
11. [x] The task completed before close; reopening restored completed durable history.
    Provider continuation of an in-flight thread was not claimed or needed here.
12. [x] Return to the same project and thread history; transcript/event sequence remained
    available and the actual diff opened in the inspector.
13. [x] Navigate to World, see the registered project and truthful “0 sessions working”
    state, then return to Focus and select the same thread with full transcript. Selecting
    it from the Focus list is currently required; World → Focus does not reselect it.

Cover 1024×640, 1440×900, 1920×1080; Meadow and Dusk; additional meaningful compact
layout. Capture and OPEN screenshots of onboarding, World/interiors, Focus,
conversation/tools/approval, terminal, Git diff, Library, People, Operations,
Settings, dialogs, errors, empty/loading/disconnected states.

Verify keyboard, visible focus, modal/text/terminal/global shortcut precedence,
focus restoration, screen-reader semantics, contrast, reduced motion and truthful
live-region announcements. Automated a11y is not a screen-reader pass. Measure
startup responsiveness, rendering cost and idle/background activity. Test packaged
macOS/Windows when environments are available; otherwise mark those gates open.

## 10. Validation truth at this checkpoint

- Before the final dirty edits: type-check and renderer/main build passed.
- Earlier broad suite: 75 files / 581 tests passed BUT one unhandled rejection
  (`pty host connection closed`) made the run fail. The identified unsolicited
  refresh now has a catch; do not call the old run green.
- Codex protocol subagent: five subprocess tests passed; code reviewed/cherry-picked.
- Codex RPC deadline implementation: 8 Codex protocol tests pass, including timeout
  and disposal cases. A new Linux x64 package including these changes was used for a
  separate real Codex task and is identified by the current acceptance record hash.
- Latest focused run initially: 41 passed / two Conversation failures due to a
  partial test provider lacking capabilities. Optional capability access was fixed.
- Subsequent type-check found new test missing required projectName; corrected to null.
- Current integration state: TypeScript checks PASS; full Desktop `pnpm test` PASS
  (78 Vitest files / 597 tests plus 45 Node runtime tests); focused changed-area run
  PASS (6 files / 52 tests); `git diff --check` passes; updated `pnpm build:all`
  passes. Vite still reports a large 670.60 kB main chunk. Tests need
  `TMPDIR=/home/ulisesjcf/.ai-workspace/.audit-private/tmp` because host `/tmp` writes
  fail with quota errors.
- Latest usage-accounting slice: focused Codex protocol suite passes (9 tests).
  Type-check and `git diff --check` pass after removing the now-unused parser.
- Latest stacked-flow fixes: the Electron fixture now marks onboarding complete
  through the authoritative Electron preference bridge; tests no longer seed a
  renderer-origin localStorage key. Local Electron + real backend passes:
  `full-journey.spec.ts` (1), both `project-changes.spec.ts` cases (2), and
  `workspace-switch.spec.ts` (1), run in two passes while refining strict selectors.
  Renderer smoke passes all 7 cases, including Focus default for unknown routes,
  six-place compact rail, and the corrected heading-free destination flow. Focus
  contract tests pass 12/12; keyboard/a11y Electron checks pass 3/3 after fixing
  the test's sequential-focus reset for Focus home autofocus; TypeScript and lint
  pass after all related changes.
- Electron Builder produced and launched the current Linux x64 package at
  `/home/ulisesjcf/.ai-workspace/.audit-private/package-codex/linux-unpacked`, including
  updated renderer/main, Electron 44.11.0, and backend 1.49.0 staged from rescue commit
  `0c730540`. Payload hashes and runtime details are in
  [LIVE_ACCEPTANCE_2026-11-12.md](audits/LIVE_ACCEPTANCE_2026-11-12.md).
- An exact pinned toolchain clone was prepared at `.audit-private/vlang-pinned` (V
  c0e47bf25, VC 9f82f2e3, Linux AMD64 TCC d6e7ac1b). No exact backend binary was
  produced: GNU cc bootstrap exceeded the required 2 GiB cap, TCC failed an atomic
  fence symbol link, and Clang reached the cap and stalled on I/O. Keep the cap and
  zero-swap requirement; retry only when a viable compiler/build route is available.
  Existing packaged backend is source-compatible at commit `0c730540`, but provenance
  is not a fresh build from the integration tree.
- Earlier focused run: four files / 43 tests passed before the navigation and
  preference changes; those changes are covered by the current full suite.
- First successful actual Electron screenshot was opened:
  `.audit-private/app-S7t4Fw/initial.png` (1440×900, onboarding).
  UI loaded with TMPDIR workaround, but backend still showed starting at capture.
  This is startup visual evidence only, not complete onboarding/provider acceptance.
- Packaged Linux app has now completed a bounded real Claude task, actual terminal/diff
  inspection, same-profile restart/history restoration, and World→Focus return; details
  and exact limitations are documented in the linked live acceptance record. The full
  journey remains open because the UI repository picker was not driven and the
  in-flight cancel/deny case remains open.
- The package also completed a separate real Codex task with approval and independent
  test verification. OpenCode remains unsupported; broad provider feature parity is open.
- Packaged Linux Electron E2E run against the previously built package completed 7/7: full
  context/Person/swarm/recovery journey, skip link, reduced motion, keyboard shortcut/Escape,
  both Git change journeys (commit and partial staging), and workspace switching. Command
  used `ATK_E2E_APP_PATH` and `ATK_E2E_BACKEND_BIN` from `package-codex/linux-unpacked`; this
  is package acceptance for those paths, not a build from the latest `d813ad30` test head.
- Actual source-Electron captures of all ten destinations have now been opened in
  Meadow and Dusk at 1024×640, 1440×900, and 1920×1080. Files are private local review
  evidence under `.audit-private/desktop-visual-matrix/`; they are not committed. The
  capture tour includes a real per-file Git diff and a real local terminal/jobs. It
  does not authenticate a provider: Focus is honestly shown in its signed-out state;
  live Claude/Codex tasks are recorded separately in the acceptance report. This capture
  pass is on PR #1783, not yet on this integration branch. Onboarding, interiors,
  conversation/tool/approval, error/loading/disconnected states, compact interaction,
  performance, screen-reader/accessibility, and macOS/Windows packaged acceptance remain
  open.
- Continuation after this checkpoint: PR #1783 commit `8f070792` moves Focus ahead
  of World in the destination rail, routes World to the semantic `WorldView`, replaces
  the visible multi-radial Dusk overlay with one even blue-hour gradient, and updates
  Electron capture assertions to wait for a real Library entity in the semantic map.
  A generated transparent illustration set was inspected against the PXL previews
  and the running map, then rejected: its 2.5D shading and red edge fringe
  conflict with the authored pixel-art system. They were not copied into the product.
  Local `type-check`, `build:all`, full Desktop lint, real Electron World capture
  (Meadow/Dusk at 1024×640, 1440×900, 1920×1080) and keyboard/reduced-motion E2E
  pass. The screenshots were opened. The village still needs authored PXL façade and
  composition work; Dusk still reads too green in the grass surround, so this is not
  a visual sign-off. Private images are under
  `.audit-private/world-focustop-final/` and must not be committed.
- Next continuation: commit `76d7957e` refines the Library source in
  `apps/desktop/scripts/world-art-pxl/landmarks.px.js`. A real Electron capture
  revealed that the former 48×72 Library overlapped the Workspace; the new
  48×64 glasshouse fits its 4×4 semantic lot. `pnpm check:world` confirms all 201
  generated assets match their PXL sources. Local type-check, `build:all`, full
  Desktop lint, 75 focused World tests, renderer smoke 7/7, keyboard/reduced-motion
  Electron E2E 2/2, and six-size/theme real-backend World capture pass. Opened
  representative captures at 1920×1080 Meadow and 1024×640 Dusk. The next PXL
  target is the rest of the civic façades/composition; the Workspace plaque still
  crowds the Library roof at compact zoom, and Dusk ground remains too green.
  Exact-head CI is pending in runs 43329202858/43329202388/43329202205.
- Draft follow-up [PR #1783](https://github.com/ulises-jeremias/agent-toolkit/pull/1783)
  is pushed as `rescue/desktop-continuity-focus`, stacked on #1782's
  `fix/desktop-shell-smoke-navigation-20261112` branch (which carries #1781 and #1780).
  The owner-authored commits from #1781 and #1782 are preserved in branch history;
  PR base is retargeted to #1782. The acceptance update is posted to
  [mission #1775](https://github.com/ulises-jeremias/agent-toolkit/issues/1775#issuecomment-6840100227).
  Packaged Linux E2E passes 7/7 for the listed paths against the existing package
  described above. Earlier Electron keyboard/a11y checks passed 3/3, including the skip
  link, reduced motion, and Escape precedence; the current 76d7957e head reran keyboard
  traversal and reduced motion 2/2. Use the live checks on draft PR #1783 for the
  current exact branch head; earlier CI runs do not cover the newest navigation/World
  slice. On `76d7957e`, the earlier head `8f070792` had one renderer smoke failure
  because that assertion still expected the removed `Workspace village` role. The
  assertion is corrected and passes locally; verify this exact-head hosted run.
  Keep the draft unmerged until required checks for that head finish and the stacked base
  is healthy. This PR stays
  draft and unmerged while base PRs have failing required Desktop checks. No release
  was created.
- Compact World critique on `76d7957e` found the persistent Workspace plaque
  collided with the Library façade at 1024×640. A one-row Library relocation
  was prototyped and rejected because it broke civic footpath connectivity and
  expanded the compact camera. Commit `eafe6bfb` instead removes the Workspace
  hall's idle plaque (its identity remains in the persistent app header) while
  retaining the plaque on hover/selection. The World view test locks this rule.
  On this exact commit, 72 World model/view tests pass; six-size/theme
  source-Electron capture passes against a real backend; compact Dusk and large
  Meadow captures were opened; keyboard-only and reduced-motion Electron checks
  pass 2/2; `build:all`, lint, type-check, and `check:world` pass. Local captures
  are under `.audit-private/world-label-iteration/`. Dusk grass remains too green
  and the broader village composition remains below sign-off quality. Exact
  The follow-on `eafe6bfb` eliminated the plaque from idle Workspace signage while
  keeping header identity and interactive nameplates. Commit `e57cebdd` enforces
  Codex approval scope; `6d675afc` prevents duplicate Focus thread creation on fast
  repeated submission. On exact head `6d675afc`, local Desktop validation passes:
  `build:all`, full lint, type-check, `check:world` (201 sprites), 608/608 Vitest
  tests, and 45/45 Node spike tests. Vitest and PXL generation need
  `TMPDIR=/home/ulisesjcf/.ai-workspace/.audit-private/tmp` on this host because
  `/tmp` writes fail with `UNKNOWN: unknown error, write`; the same commands pass
  with that private temporary directory. Exact-head CI runs are desktop gates
  `43336712549`, clean-machine acceptance `43336712625`, and web quality
  `43336712580`, with quality passed and the other two pending at the latest check
  (00:32 UTC Nov 13). Do not treat earlier-head green checks as verification for
  `6d675afc`.

  A new integrated Dusk grass recolor was captured in the real Electron app at
  compact and large sizes, then rejected: cool grey-blue grass clashed with the
  unchanged vivid trees and warm facades and made the village less coherent. That
  iteration was fully discarded; no generated variants remain in the product tree.
  Private comparison captures are under `.audit-private/world-dusk-terrain-v2/`.
  The older Dusk scene still reads too green, so the art problem remains open.
  PR #1783 remains draft and unmerged.

## 11. Continuation checkpoint — civic PXL facades

Commit `c07fdcc6c280e704ce45a962d55d2e13f86e3752` on product branch
`rescue/desktop-continuity-focus` re-authors Archive as a stone records hall,
Workshop as a sawtooth forge with waterwheel, and Operations as a map porch with
offset clock tower. It is pushed to draft PR #1783. Packaged Electron screenshots
at the old camera scale are under
`/home/ulisesjcf/.ai-workspace/.audit-private/world-civic-iteration-1/`.

Correction: the old screenshot named `dusk-1920x1080-world.png` is a darker Dusk
grade with warm point lights; my earlier claim that it retained Meadow was wrong.
The new six-view capture below independently confirms Meadow and Dusk state.
Dusk's olive value and inconsistent light-source treatment still need art work.

## 12. Continuation checkpoint — overview camera and actual viewport fit

The product worktree has camera/UX commit `8a8037ac` after `c07fdcc6`, pushed to
draft PR #1783. The
World opens in fit mode so the semantic settlement is visible first; walking is
explicit. Responsive camera zoom derives from actual map and viewport dimensions.
Whole-CSS-pixel tile sizes 24/40/56/72 were added to the nearest-neighbor zoom
ladder so the village fills 1440/1920 regions more effectively without fractional
blur. Packaged capture E2E asserts that map bounds fit inside the visible region.

The new Linux x64 package passed `dist:dir`; packaged Electron capture passed
Meadow/Dusk at 1024×640, 1440×900 and 1920×1080. All six captures were opened.
At 1440 the map uses about 90% of available width; at 1920, about 92%, with no
map clipping. Dusk is visibly darker with warm localized lights. The scene still
has a rectangular terrain edge, straight creek, clumpy repeated trees, confetti
ground texture, isolated front-facing buildings, and excessive vertical empty
area. This is camera progress, not art sign-off. Private images are under
`/home/ulisesjcf/.ai-workspace/.audit-private/world-fit-overview-v2/`.

Exact local checks on this slice: 609/609 Vitest, 45/45 Node spike tests,
type-check, lint, `build:all`/`dist:dir`, and six-viewport packaged Electron
capture pass. One initial lint run found formatting in the capture assertion;
after correcting it, ESLint passed. The Dusk correction and camera critique are
recorded in `docs/desktop/audits/WORLD_ART_DIRECTION_2026-11-13.md` on the product
worktree. The exact-head checks for `8a8037ac` have started; the first poll shows
Vercel deployment pending, and the GitHub workflow checks have not yet appeared.
Poll by PR head before any merge or acceptance claim. Remote results for
`c07fdcc6` do not validate this slice.

Next: wait for exact-head checks. The next art pass should address landscape roots: organic creek edge,
intentional road/plaza network, reduced confetti, distinct tree silhouettes, and
foreground/background depth. Do not begin by multiplying sprite count; the world
still misses the required professional art direction. Focus/provider acceptance,
onboarding, accessibility, cross-platform and native-window gates remain open.

## 13. Continuation checkpoint — calmer ground and current exact-head checks

Product commit `4b769c0f` follows `8a8037ac` on
`rescue/desktop-continuity-focus` and is pushed to draft PR #1783. It reduces
dense per-tile grass and flower marks, groups glades, and removes most path
flecks. Iteration 4's fully flat grass showed strong square tone blocks and was
rejected. Iteration 5 uses one muted two-pixel blade per tile. I opened packaged
Electron captures at Meadow/Dusk × 1024×640, 1440×900 and 1920×1080. The terrain
is calmer and paths read more clearly. The square scene boundary remains; the
creek remains straight; tree crowns remain repetitive; buildings remain isolated
front-facing cutouts. This is not art sign-off.

The unpacked Electron executable SHA-256 is
`234e177afdc9ee053d6798ae1fd8ada6e535f5c8425d25ff17c92aac571a7d2d`. Package
stages the existing backend 1.49.0 from rescue commit `0c730540`; a backend build
from the repository's pinned V toolchain remains open. On the product source
worktree, the full Desktop test command passed (609 Vitest + 45 Node spike tests),
as did TypeScript checks, ESLint, `check:world` (201 deterministic sprites),
`dist:dir`, and packaged six-view capture. Source and critique details are in
`docs/desktop/audits/WORLD_ART_DIRECTION_2026-11-13.md`.

At the first exact-head poll for `4b769c0f`, Desktop gates run 43348812525,
packaged Electron fresh-HOME 43348812558, web quality 43348812498, and Vercel
deployment are pending. Danger JS and Vercel Agent Review are skipped; Vercel
Preview Comments passes. Keep #1783 draft and unmerged until exact-head checks
and the stacked base are healthy. Older results do not validate this commit.

Next: continue one integrated user-facing slice. Focus provider interaction/parity
or World composition both remain open. The next slice selected is Codex's blocking
`item/tool/requestUserInput` flow, which currently receives an explicit refusal.
Support must be scoped to the active turn and must never persist submitted answers,
especially values marked secret. If continuing art later, remove the rectangular
scene edge, bend the creek into organic banks, and compose distinct tree groups.
The installed-app acceptance, UI-first repo registration, accessibility,
native-window and cross-platform gates also remain open.

## 14. Continuation checkpoint — Codex interactive questions in Focus

On `rescue/desktop-continuity-focus`, a new Focus slice adds blocking
`item/tool/requestUserInput` handling. It validates exact active thread/turn,
question IDs and bounded question/option sizes, rejects malformed, non-blocking,
stale and overlapping requests, and refuses late or cross-question answers.
The response follows Codex's app-server shape. Option answers use the displayed
label, freeform values use `user_note: …`, and `isOther` offers “None of the
above” plus optional notes. Interrupt and shutdown cancel the outstanding RPC.

Questions and request resolutions are durable; submitted values never enter the
Focus journal. Secret fields render as password inputs and use the same
no-persistence path. The shell now distinguishes a tool approval (`Needs your
answer`) from a provider question (`Question for you`); both remain visible as
real attention in Projects, the rail and World. Existing histories are
versionless JSONL, so this adds event types without rewriting earlier data.

Protocol verification is intentionally explicit: the installed Codex is
`codex-cli 0.167.2`; `codex login status` reports ChatGPT login. I generated
both stable and `--experimental` TypeScript bindings from that exact binary, and
neither includes this method. Therefore no real-provider request could be
produced by the installed CLI; the protocol path is covered with a scripted
app-server fixture and follows the current [Codex TUI answer contract](https://github.com/openai/codex/blob/main/codex-rs/tui/src/bottom_pane/request_user_input/mod.rs).
Do not claim this method is live-verified until an installed provider emits it.

Initial source verification on this slice: 613/613 Vitest tests and 45/45 Node spike
tests passed, as did type-check, ESLint, `build:all`, `dist:dir`, and a packaged
Electron screenshot tour of all ten destinations in Meadow/Dusk at
1024×640, 1440×900 and 1920×1080 (60 screenshots, opened for Focus, Library and
Operations critique). Captures are private under
`/home/ulisesjcf/.ai-workspace/.audit-private/codex-input-packaged-captures/`.
The full packaged Electron suite is being rerun with the fixture's documented
`--ozone-platform=headless` setting after an initial attempt could not connect
to the absent Wayland display. The first attempt against `/usr/bin/agent-toolkit`
exposed `/api/v1/projects/:id/git/log` as 404 even though that binary also reports
1.49.0; do not infer API compatibility from version alone. Rebuilt the current
renderer/main package staging the already-built backend from rescue commit
`0c730540`. Backend SHA-256 is
`a74f1cc8117a0e40372d4364d0c1fd5bd481b6e12c7f7378bb608495dd14a3d2`; package
`app.asar` SHA-256 is
`de3ab211c2f8a37738d6432c76cb53dfecfcda8d07345f1ef5b4c5e4218af71d` after
the Library preview synchronization fix; the packaged Electron E2E below ran
against this rebuilt `app.asar`.
The backend binary was verified to implement the Git history route and the
isolated project-changes E2E passes with this package. These hashes identify the
current package; recompute them after any rebuild. No backend was compiled from
the pinned V toolchain: local builds under the required 2 GiB/zero-swap cap were
OOM-killed, including the direct CLI attempt. Do not raise the cap or represent
the staged binary as a pinned-toolchain build.

That initial packaged run did not finish and its interim counters were not an
acceptance result. Later exact-source reruns corrected the stale `Workspace
village` locator and added native-first-run route settling. See checkpoint 15
for completed 614-test unit, 45-test spike and packaged Electron evidence.

Keep PR #1783 draft and unmerged while the exact-head checks and its stacked
base are reviewed. Installed-provider user-input, native-window interaction,
onboarding, accessibility, and cross-platform acceptance remain open.

## 15. Continuation checkpoint — packaged rerun and rejected terrain palette

The active `desktop-followup` worktree was rebuilt after regenerating its
governed PXL atlas. A six-screen Meadow/Dusk × 1024×640, 1440×900, 1920×1080
capture ran from the packaged Linux Electron application with the real staged
1.49.0 backend (`capture.spec.ts`, `ATK_CAPTURE_WORLD_ONLY=1`). All six captures
were opened. This experiment tested six discrete moisture-band grass colors;
it made the existing rectangular terrain blocks more obvious, and Meadow/Dusk
still shared identical block geometry. I rejected the direction and restored
the prior 201-sprite PXL source/generated atlas. Do not cherry-pick or restore
the discarded iteration-6 palette. Critique and private image locations are in
`docs/desktop/audits/WORLD_ART_DIRECTION_2026-11-13.md` (source worktree) and
`/home/ulisesjcf/.ai-workspace/.audit-private/world-art-iteration-6/`.

The package was rebuilt after reverting the experiment and then rebuilt with a
durable appearance initialization fix. Current `app.asar` SHA-256 is
`edf0f4c2530c02640c596b73264da3e7154d256f1ee8e453c4cc84abe08d19a9`; Linux
unpacked Electron executable remains
`234e177afdc9ee053d6798ae1fd8ada6e535f5c8425d25ff17c92aac571a7d2d`. The staged
backend remains rescue commit `0c730540`, SHA-256
`a74f1cc8117a0e40372d4364d0c1fd5bd481b6e12c7f7378bb608495dd14a3d2`. This is
not a fresh pinned-V build and does not prove other platforms.

Latest source checks in `desktop-followup` after the interactive-question,
dialog and theme changes: ESLint, renderer and Electron TypeScript checks,
614/614 Vitest tests, 45/45 Node spike tests, deterministic 201-sprite PXL
check, and `git diff --check` passed. Packaged `desktop.spec.ts` passed 33/33;
its clean-profile Library test waits for Electron backend/theme route
initialization and temporarily closes the primary app because Electron's
single-instance lock otherwise misroutes the second profile. Packaged
Meadow/Dusk World capture passed 1/1, all six screenshots at all required sizes
were opened, and their significant visual defects remain documented in the
art-direction audit. Private current screenshots are under
`/home/ulisesjcf/.ai-workspace/.audit-private/world-art-iteration-7/`.

The packaged reload test uncovered that `initAppearance()` applied a module
snapshot taken before the async Electron preference read. It now recomputes
after preferences initialize. The rebuilt package passes the real reload test:
the Dusk preference persists in Electron storage and `data-theme` remains Dusk
after reload. The standalone desktop test file passes 33/33 after this fix.

The reviewed source is split into these local commits on
`rescue/desktop-continuity-focus`: `07a59f49` handles provider questions in
Focus; `bc8c0f5f` fixes appearance persistence and controlled dialog state;
`4354b479` strengthens packaged navigation/persistence tests; `cc6ffbb8`
records the rejected terrain iteration. These four commits are pushed to
`rescue/desktop-continuity-focus` and included in open draft PR #1783, whose
base is `fix/desktop-shell-smoke-navigation-20261112`. The PR is not merged;
recheck base integration and exact-head checks before changing that state.
The World art work remains explicitly unaccepted; the visual issue is real and
not external.

The PXL status remains **not accepted**. Iteration 7 confirms current Meadow/Dusk
theme behavior, but still shows the square terrain slab, nearly vertical creek,
repeated canopy and isolated front-facing homes. Current critique is in
`docs/desktop/audits/WORLD_ART_DIRECTION_2026-11-13.md`; iteration 6's discrete
grass bands were rejected because they increased rectangular blocks. The next
art action is to prototype a
continuous terrain composition without selecting one of six flat tile colors:
first inspect `src/features/world/model/terrain.ts` and map-boundary/rendering
contracts, then make a small reversible prototype that removes the hard square
edge and gives the creek a clearly legible meander while preserving semantic
entity hit targets. Capture the actual packaged Electron app at all three
viewports in both themes, open every capture, and reject the prototype if it
still reads as tile blocks, a straight divider, or a sprite showcase. Continue
tree/building work only after that composition iteration demonstrates a real
improvement. Keep Focus as the product priority and do not spend another long
art-only sequence ahead of the live-provider and reopen/recovery acceptance.

### Immediate resume sequence for Luna

1. Re-run packaged `desktop.spec.ts` only if code changes or a new failure
   justifies it; the current exact package passed 33/33. Retain the explicit
   distinction between the fixture-generated Codex request and a request
   emitted by the installed authenticated provider.
2. Push the four reviewed commits with an explicit branch refspec after checking
   that the remote branch has not moved; keep PR #1783 draft and unmerged.
3. Recheck PR #1783's stacked base and exact-head checks. Keep it draft and do
   not merge while failing checks or base integration remain unresolved.
4. Continue the mandatory acceptance list above in priority order: installed
   clean-profile onboarding and UI repo registration, real provider work,
   tool/output/diff/terminal, safe cancel, close/reopen/history, World context;
   then accessibility/native-window/cross-platform and remaining domains.
5. The installed-Codex live acceptance is now recorded below. One terrain
   prototype was captured at all six required sizes/themes and rejected: the
   renderer still shows a hard rectangular slab because its lighting overlay
   spans all of `.mapWorld` and decorations are not clipped to the generated
   shore. The prototype and its geometry-only test were reverted. Do not repeat
   this attempt or prioritize more terrain work ahead of Focus, CI and restart
   acceptance; use the iteration-8 captures as critique evidence.
6. Keep this handoff synchronized after each verified slice. The rescue remains
   open until the owner's daily-driver success scenario passes in a packaged
   application and the World is visually accepted.

## 16. How Luna should execute efficiently

1. Read this file, git status/diff, then only the source needed for the first P0 slice.
2. Do not re-export Muse, re-clone references or repeat broad audits without a reason.
3. Preserve dirty work and partial worktrees. Review before merging/cherry-picking.
4. Finish the packaged Electron suite and exact-head checks for this Focus slice;
   then test against a Codex release whose generated bindings actually expose
   `item/tool/requestUserInput`. Keep the live-provider gate open until then.
5. Fix one integrated user journey at a time; do not let more artwork precede working
   Focus/restart acceptance again.
6. Keep changes reviewable, tests meaningful and evidence truthful. Re-run only when
   code changes/failures/new risks justify it.
7. Update this checklist and a short evidence entry after each slice, including the
   next exact action. Never mark a checkbox done from another agent's assertion alone.
8. Use bounded subagents only if useful and available; the active owner integrates
   and personally verifies results. Usage limits are not product completion.
9. Do not ask again for ordinary architectural/engineering permissions already granted.
10. The final success question is whether the owner can comfortably complete real
    development work in Desktop and enjoy it. Until that is demonstrated, keep the
    mission and relevant acceptance gates open.

## 17. Continuation checkpoint — installed Codex packaged acceptance

The authenticated installed Codex provider was exercised from the packaged Linux
Electron application using the actual user Codex configuration via `CODEX_HOME`;
credentials were not copied into the clean Desktop profile or repository. The
optional `e2e/electron/codex-live-acceptance.spec.ts` creates and removes its own
scratch HOME, workspace, profile, and disposable Git repository. It links that
repository through the Projects UI, starts a real Codex task, checks the exact
provider-produced file contents and Focus tool receipt, checks the untracked
file's actual diff before staging, runs a command in a real embedded Bash PTY,
safely interrupts a deliberately waiting provider turn, closes and
reopens Electron against the same profile, and navigates between Focus and the
project's World interior. Final packaged execution passed (1/1, about 1m36s).

The provider resume result is variable. A prior live run showed Focus's truthful
message that Codex could not resume its saved remote conversation; another
actual rerun resumed successfully and returned the file's exact contents. The
acceptance asserts either the exact recovered answer or the explicit
unavailable-resume message, while always checking that the original completed
turn and its output survive relaunch. Do not describe resume as guaranteed.
This opt-in test (`ATK_LIVE_CODEX_ACCEPTANCE=1`) requires an authenticated Codex
configuration. Set `SHELL=/bin/bash` for the clean profile on this host: the
user's interactive Zsh startup script launches a first-run interactive prompt
that consumes typed PTY input. The test and fixture change were reviewed,
committed as `930a936a`, and pushed to PR #1783. Its current exact-head checks
were superseded by the follow-up commit; keep the PR draft and unmerged.

The live test exposed that untracked files showed “No textual diff.” This has
now been fixed in `project_git_diff_typed`: unstaged paths absent from the Git
index use `git diff --no-index` against the empty tree, accept Git's expected
exit status only when there is no stderr, and retain repository-relative path
validation. Missing files fail honestly. The test covers a filename containing
spaces. The installed-provider acceptance now selects the new file before
staging and verifies its actual added line in the Changes view. The focused V
module test passes, a debug CLI backend compiled under the 2 GiB/zero-swap limit,
and the packaged Electron UI test passed 1/1 against that new backend. The full
34-test packaged Electron suite also passed against it. The local
`-prod` CLI attempt did not fit the memory cap (cc1 was terminated while
assembling embedded resources); CI's pinned build remains the production build
gate.

Source ESLint, renderer/Electron TypeScript checks, `git diff --check`, Vitest
(614/614), Node spikes (45/45), and the live packaged provider test (1/1) all
pass. The focused V module test (including the untracked filename with spaces),
integrated packaged UI test (1/1), and complete packaged Electron suite (34/34)
pass against the new debug backend. Endpoint and E2E coverage were reviewed and
committed as `72a727fb`, pushed to PR #1783; recheck its exact-head checks as
they finish. The official `-prod` local build did not fit the strict 2 GiB
scope while assembling embedded resources; the successful local backend is a
debug build. CI's pinned production build remains a merge gate. The
real-provider and resume behavior are evidenced for Codex only. Codex
interactive user-input is still protocol-fixture-tested, not emitted by the
installed provider. The remaining world art rejection and overall daily-driver
signoff are unchanged.


## 18. Continuation checkpoint — terrain prototype rejected, PR checks pending

The next visual experiment changed `paintTerrain` to omit cells beyond a
rounded/noisy shoreline, widened and bent the creek, and blocked movement beyond
the generated land footprint. Its focused model test passed 56/56, and a rebuilt
packaged Electron capture tour passed at 1024×640, 1440×900 and 1920×1080 in
Meadow and Dusk. All six iteration-8 captures were opened and inspected at
`/home/ulisesjcf/.ai-workspace/.audit-private/world-art-iteration-8/`. The
visual result was rejected: the meadow still reads as a rectangular map slab;
Dusk makes the rectangle even stronger. The CSS `.mapWorld::after` overlay
spans the complete rectangular map, and ambient decorations are not clipped to
the new shoreline. The geometry-only assertions did not catch that UX failure.

The prototype source and its test are reverted and are not part of PR #1783.
Do not cherry-pick or reconstruct that diff. This is a documented rejected
experiment, not a change to the product or a visual sign-off. The local package
was built with the successful debug backend; the Linux Electron executable
SHA-256 is `234e177afdc9ee053d6798ae1fd8ada6e535f5c8425d25ff17c92aac571a7d2d`.
The screenshots remain private and contain no credentials.

At the same checkpoint, PR #1783 is OPEN and draft, head
`72a727fb74a6235f717d460c7431d888ad035649`, based on
`fix/desktop-shell-smoke-navigation-20261112`, with GitHub `UNSTABLE`. Forty
eight checks passed, nine were still in progress (including clean-profile
packaged Electron acceptance and additional platform builds/linkage). Recheck
the current exact-head state before changing the PR. Keep it unmerged while
checks or base integration are unresolved. The opt-in real authenticated Codex
acceptance and untracked-diff fix remain the last reviewed code changes; their
results are documented in checkpoint 17.

### Immediate next actions for Luna

1. Recheck PR #1783's current checks and base/merge state; do not rerun the full
   suite unless a code change or failed job justifies it.
2. Review any failed or newly completed CI jobs and fix actual failures on the
   feature branch. Keep the PR draft.
3. Close the remaining packaged-provider evidence gap: verify user-input /
   approval behavior against installed provider protocol bindings; current live
   Codex evidence is not proof that Codex emits every approval event.
4. Continue the mandatory clean-profile onboarding, safe restart/recovery,
   accessibility, native-window and cross-platform gates. The app-wide daily
   driver acceptance remains open.
5. Defer another terrain implementation until the full-map overlay and
   decoration clipping have a concrete design that can be judged in packaged
   Electron. Do not count rounded model geometry as visual completion.
6. Keep this file current with exact head hashes, test evidence, and rejected
   directions. The mission is not complete until the owner can do comfortable
   real development work in the packaged app and accepts the World visually.
