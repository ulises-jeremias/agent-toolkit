# Agent Toolkit Desktop rescue — execution handoff for GPT-6-Luna

Updated: 2026-11-13 (CI-built package live acceptance; current GitHub/worktree state).
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

### Current continuation state — verified 2026-11-13

This block supersedes older point-in-time state tables and “next” notes below;
those checkpoints are retained as history, not as current instructions.

- `worktrees/desktop-owner`, branch `rescue/codex-product-integration`, is at
  `48cac41e` and pushed. This is the documentation/integration evidence branch,
  not `main` and not a merged product change.
- `worktrees/desktop-followup`, branch `rescue/desktop-continuity-focus`, is at
  `b9256066`; it is PR #1783, OPEN, draft, based on `main`, and has no review
  decision yet. Keep it draft while CI, architectural review and acceptance gaps
  remain.
- GitHub currently lists only #1783 and #1771 open. #1771 has a
  `CHANGES_REQUESTED` review for PXL preview drift and content-changing
  screenshots; keep it unmerged pending a corrected exact head and re-review.
- #1782 head `63b35901` is merged to `main` as `a63db4a5`; #1781 head
  `80765a86` is also included in `main`. Their historical worktree descriptions
  below are stale. `origin/main` currently resolves to `a63db4a5` in the latest
  verified fetch; query again before integration.
- Exact PR #1783 head `b9256066`: `gates`, clean-HOME packaged acceptance,
  desktop, CodeQL, quality, validation jobs shown so far, and Linux x64/ARM plus
  Windows packaging passed. macOS packaging/linkage/integration and macOS
  matrix validation were still pending at the latest poll; `Validate` workflow
  had been queued. Do not call the complete matrix green until every required
  check on this exact head concludes.
- A real Codex coding journey passed against the CI-produced Linux x64 AppImage
  for #1783, including its pinned-toolchain backend. Hashes and exact scope are
  in [LIVE_ACCEPTANCE_2026-11-12.md](audits/LIVE_ACCEPTANCE_2026-11-12.md) and
  checkpoint 54. This closes only the Linux packaged Codex journey slice.
- Latest live-provider CLI availability: Codex 0.168.0, Claude 2.1.323,
  OpenCode 2.2.7. Only Codex was re-proven in the CI-built package this turn.
- Latest tracked implementation branch worktree is clean; ignored QA artifacts
  and downloaded packages are under `.audit-private`. Preserve user-owned old
  worktrees; the current worktree inventory is in checkpoint 55.
- Next execution priority: finish exact-head CI/review, then work the substantive
  acceptance gaps recorded in checkpoints 51–54 (real OS picker/onboarding,
  screen reader, multi-platform live use, filesystem race/security, broader
  Focus/provider parity, and the World scene boundary/creek composition). Keep
  recording concrete implementation and packaged evidence here so GPT-6-Luna
  can resume without trusting stale snapshots.

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
| `worktrees/rescue`, local `rescue/shell-v2` at `0c730540` | Original PR #1780 checkout, now behind its updated remote PR branch. Do not push from this stale worktree. |
| `worktrees/desktop-pr1780-repair`, local `rescue/pr1780-gate-repair` at `01140c97` | Updated remote head for PR #1780 (`rescue/shell-v2`). Adds backported, authored test repairs; renderer smoke and affected source-Electron journeys pass locally. Hosted exact-head checks pending. |
| `worktrees/desktop-owner`, `rescue/codex-product-integration` | Started from canonical main `3e08b51e`; local merge `dbbbcb57` preserves rescue commits. Protocol fix cherry-picked as `8a753ec5`. Rescue checkpoints are pushed to this branch; latest documented checkpoint is `aa67c8eb`. |
| `worktrees/desktop-followup`, `rescue/desktop-continuity-focus` | Pushed draft PR #1783, current head `e4932317`; includes continuity/runtime follow-up, Focus-first navigation, semantic World, responsive fitted overview camera, authored civic/project facades, Dusk house lights, Focus blocker guidance, and two three-quarter project facades. It is not merged into the integration worktree. |
| `worktrees/desktop-smoke-repair`, `fix/desktop-shell-smoke-navigation-20261112` | PR #1782 updated to `36affaac` with authored journey repairs and a World-home route assertion for the current base implementation. Four affected Electron journeys and seven renderer smoke tests pass locally. Exact-head hosted checks are running; keep the stacked PR draft and unmerged. |
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
- [x] Verify PTY lifecycle separately. The real detached-host regression creates
  a shell in one client process, exits that process, reconnects from a second
  client without spawning another host, verifies the session and buffered output,
  and closes it. `electron/pty-host.test.ts` and `electron/terminal.test.ts`
  passed 13/13 on PR #1783. This confirms ordinary terminal survival and explicit
  closure; route memory still does not persist a PTY selection, and the app's
  shutdown policy intentionally detaches ordinary PTYs while stopping Focus turns.
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
- [ ] Finish interactive questions/new-permissions parity and live verification.
  Codex's blocking `item/tool/requestUserInput` is implemented with active-turn
  validation, secret-answer non-persistence and interruption cleanup; protocol
  fixture/component regressions pass. A real installed provider has not yet
  emitted this request repeatably, and other provider-specific permission RPCs
  may still be explicitly unsupported.
- [ ] Verify streaming partial output, tool outputs, completion, errors, approval,
  deny, interrupt, resume, model/permission changes, and child-agent events live.
- [ ] Keep parent and native child sessions distinct; child completion cannot close
  the parent turn or pollute its journal.
- [ ] Verify all provider cancellation/shutdown paths leave no descendant mutating
  files. Codex forced disposal now has a Linux process test that runs a descendant
  continuously writing a disposable file, kills the provider group and confirms
  both process exit and a stable file afterward. Claude, non-Linux packaged
  behavior and the user-facing cancel path still need acceptance evidence.
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

Latest #1782 continuation: the original failed run `43298967157` was inspected and
its four failures reproduced from the stale `Review project link` expectations,
wrong Context navigation target, and workspace fixture without Git initialization.
The focused repair commit `fed0a24c` from #1783 was cherry-picked to the #1782
branch as `8c75acb8`, preserving author identity. Its compatibility follow-up was
cherry-picked as `fe3e71f7`; a small follow-up in `d59a2fd2` uses runtime feature
detection so this older branch's E2E fixture type-checks both before and after the
Electron preference bridge lands. Exact branch build and ESLint pass, and all four
Electron journeys pass locally (2m30s) against Electron and the repository's
source-compatible 1.49.0 backend binary. Hosted checks for exact #1782 head
`d59a2fd27ba79db8b3d57041cc2c3218b1ffe9e3` are running; the previous red CI is
historical, and must not be described as fixed on GitHub until these new checks
finish successfully.

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

## 19. Continuation checkpoint — current Codex bindings and approval attempt

The machine's authenticated Codex CLI is now `codex-cli 0.168.0`. Generated its
TypeScript app-server bindings privately with
`codex app-server generate-ts --experimental`; the generated `ServerRequest`
union includes `item/tool/requestUserInput`, command and file-change approval,
and related v2 request types. These files are under
`/home/ulisesjcf/.ai-workspace/.audit-private/codex-0.168-bindings/` and were
not added to Git. This verifies that the current installed protocol describes
these request shapes; it does not prove a model turn emits them.

Updated the Codex adapter's stale source comment, which said the installed
0.167.2 bindings did not advertise user input, to distinguish the original
0.167.2 baseline from later protocol additions. The adapter behavior is
unchanged. Codex adapter tests pass 13/13, Desktop ESLint passes, and both
renderer and Electron TypeScript checks pass.

A live packaged attempt selected the strict `ask` permission mode and expected
the real Codex task's first file write to raise Focus's approval dialog. No
`Approval needed` dialog appeared within 120 seconds. The captured UI returned
to the new-session form with the task present in session history and Codex
reported signed in. This is inconclusive: the turn did not reach an observable
approval in this run, and the final page context did not show its conversation.
Do not claim real Codex approval coverage. The experimental test assertion was
reverted; it is not part of the branch. Its scratch profile was cleaned. The
previous live acceptance with `accept-edits` remains the successful provider
acceptance; protocol-fixture tests remain the evidence for approval/user-input
UI flows.

### Immediate follow-up

1. Recheck the current exact-head CI state for PR #1783 before pushing or
   replacing any checks.
2. Trace why an `ask`-mode live turn returned to the session composer without
   an observable approval. Open its session from the Focus history and inspect
   the durable journal/provider error before changing the adapter or tests.
3. Only add live approval assertions once a disposable Codex task reliably
   generates a request; otherwise retain the limitation explicitly.
4. Keep protocol shape evidence separate from observed provider behavior, and
   do not claim the live user-input request was emitted by Codex.

After updating the stale adapter comment, committed and pushed
`53d0c7b8b5d008a1eff7d9246573467f6f1a18bf` to the same PR branch. The PR is
still OPEN, draft, and based on `fix/desktop-shell-smoke-navigation-20261112`;
GitHub had not yet attached new exact-head checks at the time of this note, and
merge state remained `UNSTABLE`. The previous head's clean-profile packaged
acceptance and platform checks passed except for two packages still pending at
the moment the head was replaced. Treat only checks for `53d0c7b8` as current.

## 20. Continuation checkpoint — repeatable live run and one real approval

The packaged live Codex acceptance passes again (1/1, about 1m30s) with the
stable `accept-edits` setup. Tightened the two Focus composer locators to exact
accessible names because the real Changes pane also exposes a “Commit message”
textbox whose label contains “Message”. ESLint and both TypeScript checks pass.
This test still covers project linking, real provider-produced file/output and
untracked diff, real PTY input, safe interruption, reopen/history, honest
resume-or-unavailable behavior, and World-to-Focus state continuity.

During the Ask-mode experiment, one packaged Codex run did emit the real
`Approval needed` dialog. Clicking “Allow once” let Codex create the exact file;
the actual diff preview then passed. That run later exposed the ambiguous
composer selector described above. Subsequent Ask attempts did not reliably
reproduce the prompt: one provider turn declined the read-only write and the
explicit-command attempt did not produce a session row within its timeout.
The temporary Ask-mode assertions and prompt were reverted. Therefore a
provider-generated Codex approval is now **observed once**, but the harness does
not yet assert it repeatably. Keep this confidence level explicit.

Committed and pushed the exact-selector fix as
`a121229d82bbef37dd36a4b395d578da865f8e44` to PR #1783. It replaces the
`53d0c7b8` head and starts a new exact-head CI run; only checks on `a121229d`
count now. PR #1783 remains draft/open and unmerged. Recheck its new checks and
keep resolving base/merge state before integration.

## 21. Continuation checkpoint — stacked PR acceptance failures

GitHub's stack is `#1780` → `#1781` → `#1782` → `#1783`; do not treat
#1783's feature branch as independently mergeable into `main` yet. The lower
three historical heads currently report failed `Packaged Electron with fresh
HOME` and aggregate `gates` jobs. Exact failing job runs inspected:

- #1780: `43259175954` (fresh HOME), `43259175883` (gates).
- #1781: `43278716272` (fresh HOME), `43278716004` (gates).
- #1782: `43298966315` (fresh HOME), `43298967157` (gates).

For #1782, the failing Electron suite ran 58 tests successfully and failed 4
with three retries. In its then-current `project-changes.spec.ts` and
`workspace-switch.spec.ts`, the tests waited for an in-app “Review project
link” dialog after selecting the folder. The implementation's review step is
the native folder picker; the renderer links the selected folder directly and
shows a receipt. The later `project-link.spec.ts` already tests that actual
flow. The #1782 `full-journey.spec.ts` also failed to find its workspace pack
panel while the separate `workspace-packs.spec.ts` passed in the same run. This
looks like a stale/fragile stacked test set, but inspect the exact current-head
results before concluding it is only test drift.

The logs were downloaded privately to
`/home/ulisesjcf/.ai-workspace/.audit-private/pr1782-fresh-home.log` and the
Playwright report to `.audit-private/pr1782-artifacts/`. They are diagnostic
only and must not be committed. The latest #1783 head `a121229d` had 38 passing
checks and no failed check at the last query; its clean-profile Electron job,
`gates`, and several platform jobs were still running. That head includes the
updated direct-link project tests. Recheck exact-head CI first; do not spend
another full packaged run if GitHub already supplies the evidence.

### Next integration actions

1. Inspect the latest #1783 clean-profile job. If it fails, read its own report
   and fix that current failure rather than copying old #1782 conclusions.
2. Inspect #1780 and #1781 gate logs if their old failures still matter to the
   landing plan. Keep the PR stack intact until deciding whether to fix each
   base branch, rebase the stack, or supersede it with a reviewed integrated
   PR; do not force-merge red checks.
3. For any failure that reproduces at `a121229d`, fix the underlying behavior
   or update stale E2E expectations to match the actual deliberate GUI path,
   then verify the packaged test locally and on exact-head CI.
4. Keep GitHub issue #1775 and this handoff aligned with the chosen integration
   path. No lower PR has been merged as of this checkpoint.

Issue #1775 was updated with the verified packaged Codex run, the one-time real
Ask approval observation, current `a121229d` exact-head CI status, and the World
rejection: <https://github.com/ulises-jeremias/agent-toolkit/issues/1775#issuecomment-6845754830>.
The latest exact-head query still reports 40 passed, zero failed, and nine in
progress/queued (including clean-profile Electron and gates); PR state is OPEN,
draft, and `UNSTABLE`. Do not infer completion from the earlier green runs.

## 22. Continuation checkpoint — detached PTY lifecycle verified

Re-read the PTY shutdown contract and ran the existing process-boundary tests on
PR #1783. `electron/pty-host.test.ts` and `electron/terminal.test.ts` passed
13/13. The detached-host test creates an interactive session through a child
client process, lets that process exit, reconnects without allowing a second
host spawn, verifies the session and its buffered output, then explicitly closes
the PTY. This closes the separate ordinary-terminal-survival gate. It does not
mean Focus provider runs survive Desktop shutdown: those remain intentionally
stopped and durably journaled. There is also no saved PTY selection in route
memory; the registry restores sessions and the user selects one in the terminal
surface. No packaged app code changed in this verification.

The exact #1783 head `a121229d82bbef37dd36a4b395d578da865f8e44` remains OPEN,
draft, stacked on #1782 and UNSTABLE. At the latest recheck, the packaged fresh
HOME gate, Desktop `gates`, Linux/Windows/macOS packaging, platform linkage, and
some macOS validation jobs were still pending; no failures were reported.
Continue against the exact branch head, and do not merge until the stack's
required checks and base integration are healthy.

The Codex question-RPC and Focus controller regressions were rerun on that same
head: `electron/focus/codex.test.ts`, `electron/focus/focus.test.ts`, and
`src/features/focus/Conversation.test.tsx` passed 48/48. This verifies the
fixture-driven question path and its Focus presentation; it does not upgrade
the live-provider evidence beyond the one-time approval observation recorded
above.

## 23. Continuation checkpoint — Codex shutdown stops file-mutating descendants

Added a process-level regression for the Codex adapter's forced shutdown. Its
scripted app-server starts a shell descendant that continuously appends to a
disposable file. The test confirms the child runs, forces adapter disposal,
waits for the child process to stop, and verifies the file size remains stable.
On Linux, the new test plus the existing Codex and Focus service tests pass
42/42. `pnpm type-check` and the Desktop `pnpm lint` pass. The regression is
Linux-only because it checks `/proc` process state and POSIX process groups;
macOS/Windows packaged shutdown and Claude descendant cleanup remain open.
The product implementation was unchanged; this adds evidence for the existing
Codex process-group kill behavior. Commit
`22ebb06dd6783f402b7de78662513daa138ecb1b` was pushed to
`rescue/desktop-continuity-focus` and PR #1783. The next commit reauthored the
project cottage and expanded the visual tour to all six deterministic project
facades; see checkpoint 24 for exact evidence.

## 24. Continuation checkpoint — reauthored cottage and six-project packaged review

The latest art iteration reauthored the `house-cottage` PXL sprite as an
asymmetric river-quarter adobe cottage with a shaded side return, tiled roof
planes, porch canopy, recessed entry, shutters, lantern, masonry steps and
planted threshold. The generator regenerated the governed PNG and both manifests.
The opt-in packaged screenshot tour now registers six disposable Git repositories
whose deterministic project-name hashes select all six distinct project-house
facades in the same World capture; only `garden-api` contains the unique
`src/api.ts` change used by the existing diff-tour assertion.

Exact local validation on source commit `66586da4c27aaf2575c958e152f0213670e6834f`:

- World model/component tests: 151/151 passed.
- Prettier, renderer and Electron type-check, ESLint, 201-sprite deterministic
  generator check and `git diff --check` passed.
- `build:all` and Linux x64 `dist:dir` completed. It stages the existing
  source-compatible `1.49.0` backend binary from rescue commit `0c730540`; this
  does not close the separately pinned V toolchain/backend build gate.
- Packaged Electron capture passed in Meadow and Dusk at 1024x640, 1440x900 and
  1920x1080 against the six-project temporary workspace. Latest private images:
  `/home/ulisesjcf/.ai-workspace/.audit-private/world-house-cottage-final/`.
- Opened and critiqued the 1440x900 packaged capture. The new project cottage is
  visibly more dimensional and legible at overview scale. The overall composition
  remains too shallow for the available viewport height, tree crowns repeat, and
  the straight canal/front-facing civic facades still need further authored work.
  This is an incremental facade improvement, not World sign-off.

The next packaged capture exposed a layout-level contributor to the empty
vertical frame: project houses in the rear street were only five tiles behind
the front street. A reversible layout iteration increases this lane spacing to
seven tiles and updates each district's computed bounds. It keeps project lot
IDs/first-street positions stable while giving a 3-project roster 15 rows. The
1440x900 packaged capture now occupies more of the available height; the
1024x640 capture remains inside its viewport and preserves all six houses.
World capture passed at all six sizes/themes. Meadow/Dusk 1440x900 images were
opened and compared. The first review shows better vertical balance but does not
resolve the repeated tree crowns or straight canal. Local World tests remain
151/151; type-check, lint, deterministic PXL check, package build, and
`git diff --check` passed on this exact iteration.

Exact GitHub state after the latest push: PR #1783 is OPEN, draft, head
`5018d4a006a209e30e57f5202fc9ff560b49d8ce`, based on
`fix/desktop-shell-smoke-navigation-20261112`. Exact-head checks have started.
At the latest poll, the web-quality job, Vercel preview, and a group of Validate
jobs passed; `gates`, clean-HOME Electron, Release, package build, and remaining
platform checks were still pending. No exact-head failure was reported. Re-query
before acting; do not infer completion from checks on `66586da4` or earlier.
Keep it unmerged pending healthy exact-head checks, review, and the stacked base
PRs.

Next: review exact-head CI; continue a distinct-facade/environment composition
iteration and inspect its real packaged captures; then resume the unfinished
onboarding/repository-picker and provider-runtime acceptance gates. Keep the
mission active and update this handoff with evidence, not projected completion.

## 25. Continuation checkpoint — stacked Desktop gate repairs

Inspected #1782's failed Electron log `43298967157`: four journeys failed from
the outdated Context target, obsolete project-link dialog assumptions, generic
Changes selector and a workspace fixture without Git initialization. Cherry-picked
the existing repair commit `fed0a24c` with original authorship and its fixture
compatibility commits `a6112c49`/`d59a2fd2`. On this older branch the preference
bridge is feature-detected at runtime, so the shared E2E fixture works before and
after Electron-owned persistence arrives. On exact branch code, the four affected
journeys passed locally (full-journey, two Git-change journeys, workspace-switch),
as did `project-link`; renderer smoke passed 7/7. The initial exact-head #1782
run then revealed its Focus-home assertion was premature: #1782 still routes
unknown paths to World. Corrected it and pushed #1782 head
`36affaac17be6743eca6e6b18865c1ff0dd69609`. Its new hosted checks are running;
do not mark earlier CI failures fixed until the new `gates` and clean-HOME checks
pass.

The same test-only journey fixes were cherry-picked, preserving authorship, onto
PR #1780's branch in an isolated worktree. On #1780's current product contract,
unknown routes still land on World; that assertion was kept truthful here. Exact
updated PR #1780 head is `01140c9743f3e4d6a604f3e5476d7a5df876d7fc`. Local
renderer smoke passed 7/7; all five affected Electron journeys passed against
the source-compatible backend. Build and lint passed. Hosted checks are running;
the original #1780 failures remain historical until exact-head CI passes. The old
`worktrees/rescue` checkout remains at `0c730540` and is stale versus the remote;
publish future corrections from `worktrees/desktop-pr1780-repair` with explicit
refspecs.

This creates an intentional staged test contract: PR #1780/#1782 keep World as
home, while #1783's Focus-first change should update that route expectation only
after its product code is present. When #1782 moves forward, rebase/reconcile
#1783's test diff and rerun exact-head renderer and packaged Electron gates. Do
not merge red or pending stacked checks.

## 26. Continuation checkpoint — opening the World groves

The first reduced-anchor-count prototype barely changed the packaged image because the separate grove-membership mask still covered most of each region. That visual iteration was rejected rather than treated as evidence of improvement. The follow-up adjusts the grove lattice from 9 to 11 cells, reduces grove radii from 4–7 to 3–5 tiles, and lowers the preferred anchor count. This introduces larger clearings while retaining clustered tree groups. World model/component tests pass 151/151; type-check, lint, deterministic PXL check, and `git diff --check` pass. Linux x64 `dist:dir` succeeded, then the actual packaged Electron visual tour passed in Meadow and Dusk at 1024x640, 1440x900, and 1920x1080. I opened the 1440x900 and 1920x1080 captures: the canopy pattern is less continuous and the routes/landmarks read more clearly, but the broad rectangular terrain tint, canal geometry and some repeated tree silhouettes remain visible issues. This is one accepted iteration, not World sign-off. Private captures are under `/home/ulisesjcf/.ai-workspace/.audit-private/world-grove-refined/`.

Committed as `937f098b` (`fix(desktop): open clearings between World groves`) and pushed to PR #1783. Query this exact head and its required checks before assuming the change is integrated. At the last poll, #1780 head `01140c9743f3e4d6a604f3e5476d7a5df876d7fc` and #1782 head `36affaac17be6743eca6e6b18865c1ff0dd69609` had no failed checks, but their `gates`, packaged clean-HOME, and several platform jobs remained pending. Do not merge either while pending; re-query rather than relying on the prior poll. Continue the next World critique from the new packaged captures, then return to the unfinished onboarding/repository-picker and real-provider acceptance gates. Preserve the World sign-off as open.


## 27. Continuation checkpoint — exact-head CI queue recheck

After pushing `937f098b95311cdf6b87d49b32d514434430cc3e`, PR #1783 points to
that exact head and remains OPEN/draft. The source push updated the PR head, but
GitHub Actions has not created a run for this SHA: `gh run list` still shows
`5018d4a0` as the latest workflow SHA, and the exact commit's check-suite API
currently lists only Vercel completed plus Travis CI, AWS Amplify and third-party
checks queued. Treat this as external check scheduling, not as a green gate. The
previous successful #1783 `gates` result belongs to `5018d4a0`; it does not
validate the grove change. Re-query and, if it remains stuck, inspect repository
Actions status or ask the owner/maintainer to resolve the queue before merge.
Local tests and the full packaged visual tour for `937f098b` are recorded above.

Re-polled stack state: #1780 is OPEN, current head `01140c9743f3e4d6a604f3e5476d7a5df876d7fc`, not draft, merge state BLOCKED; #1782 is OPEN/draft, current head `36affaac17be6743eca6e6b18865c1ff0dd69609`, merge state UNSTABLE. Both still have required gates and clean-profile/package/platform checks pending, with no new failures in the latest filtered status poll. Do not merge.

This checkpoint supersedes older `Immediate next actions` that said to defer terrain work: the grove-density change was implemented and judged in real packaged captures, but the rectangular scene boundary, creek composition and repeated silhouettes remain unresolved. Keep the World open. The next substantial acceptance work still includes clean-profile onboarding, safe restart/recovery, accessibility, native-window/cross-platform coverage, and end-to-end daily-driver use. The mission remains active.


## 28. Continuation checkpoint — authored oak, viewport Dusk, and reconciled stack

Implemented and packaged another real-art iteration on `rescue/desktop-continuity-focus`. In the governed PXL source `apps/desktop/scripts/world-art-pxl/trees.px.js`, `tree-round` is now an asymmetric connected canopy with a shaded lee plane, sunward leaf planes, a visible fork, and consistent bark lighting. Regenerated the governed PNG and both manifests; `pnpm check:world` confirms all 201 sprites are deterministic and current. The PXL preview is tracked at `apps/desktop/scripts/world-art-pxl/preview/tree-round.png`. I opened that preview and the packaged screenshots: compared with the former five circular leaf clumps, the oak reads as a single wind-shaped crown with more canopy volume, but identical oak clones remain repetitive and the overall scene remains amateur-looking. Do not interpret the asset pass as meeting the attached quality bar.

The previous Dusk treatment tinted only the transformed map, producing an obvious gray rectangle pasted over a green viewport. Replaced it with an `aria-hidden` atmosphere element fixed to the map viewport, so the blue-hour tint spans both the map and the visible surrounding valley. A first packaged pass showed the correct seam-free coverage but was too weak; the stronger pass is visibly dusk while world plaques and camera controls remain readable. The overlay is an actual decorative DOM node rather than a pseudo-element: happy-dom incorrectly propagated `pointer-events:none` from a pseudo to the document root and broke unrelated clicks. After this correction the full focused World suite passed 151/151. CSS still needs native-window and keyboard-focus acceptance beyond the current renderer/Electron evidence.

Evidence for exact source tree at commit `120e5e91` before stack reconciliation:

- `pnpm type-check` and `pnpm lint` passed.
- `pnpm check:world` passed: 201 deterministic sprites.
- `pnpm dist:dir` packaged Linux x64 Electron with the existing source-compatible Toolkit backend 1.49.0. This does not prove a pinned-V backend build.
- The opt-in real packaged-Electron World tour passed Meadow/Dusk at 1024x640, 1440x900, and 1920x1080. Opened Dusk/Meadow 1440x900, Dusk 1024x640, and Meadow 1920x1080. Private captures: `/home/ulisesjcf/.ai-workspace/.audit-private/world-tree-dusk-pass/`.
- Renderer smoke passed 7/7, including the Focus-first unknown-route assertion.
- Five packaged Electron journeys passed 5/5 against the real backend: full journey, both Git-change journeys, direct project linking, and workspace switching. Runtime 2.8 minutes.
- An initial test run before replacing the Dusk pseudo-element failed 11 pointer interactions because happy-dom incorrectly attached pseudo-element pointer styles to `<html>`. This was a real test-environment regression in the attempted implementation, not ignored; replacing it with the actual overlay element made all 151 World tests pass.

The #1783 PR stack had advanced while this work was underway. The latest base is #1782 head `36affaac17be6743eca6e6b18865c1ff0dd69609`; its fixture and smoke changes conflicted with the older #1783 branch. The resolved changes preserve #1782's structural preference-bridge feature detection, retain #1783's real Focus-home contract, and preserve both branch histories through a merge commit. The resulting pushed #1783 head is `be0b58d1707b754daa69b2d64d9e6f3e8b47ec42`, based on `36affaac`; GitHub currently reports OPEN/draft, MERGEABLE, and UNSTABLE while CI is queued/running. Exact new workflow runs include Clean-machine Desktop Acceptance `43388661223` and Release `43388661277`; do not rely on prior `5018d4a0` success for the new head. Latest filtered checks for #1780 `01140c97` and #1782 `36affaac` still show macOS V/integration jobs pending and no failures. Do not merge the stack while required checks remain pending.

Next work: inspect all exact `be0b58d1` checks; continue replacing the toy-like civic/project silhouettes with authored architectural variety and better material/perspective; make the creek and outer terrain boundary feel organic in packaged Electron; review project interior, Focus, onboarding, Settings, terminal/diff, empty/error states at all requested sizes; then run clean-profile installed-app, accessibility, native-window, real-provider, restart/recovery and supported-platform acceptance. The owner’s attached quality bar explicitly rejects “good enough”; World and product visual sign-off remain open.

## 29. Continuation checkpoint — exact-head gates remain active

Re-queried PR #1783 after pushing merge commit `be0b58d1707b754daa69b2d64d9e6f3e8b47ec42` (base #1782 head `36affaac17be6743eca6e6b18865c1ff0dd69609`). PR remains OPEN/draft and GitHub reports MERGEABLE. Exact-head workflows are still running: Packaged Electron with fresh HOME, `gates`, Release, platform packaging, V CLI parity, and integrations have not completed. The web workflow and several platform-independent validation jobs succeeded; this is not a complete required-check result. Re-query exact SHA before merge or any completion claim.

A fresh visual critique of the previously captured actual Linux packaged Electron World at 1440x900 confirms better vertical occupancy and readable semantic labels, but the scene still reads as a board of sprites: oak crowns clone visibly, the canal remains rigid, and several façades have shallow/front-facing forms. Meadow/Dusk are not signed off. The latest capture iteration is the viewport-wide Dusk atmosphere plus connected, asymmetric oak source recorded in checkpoint 28; latest private captures are at `/home/ulisesjcf/.ai-workspace/.audit-private/world-tree-dusk-pass/`. Continue architecture, terrain, and foliage authoring only with packaged capture review at all requested sizes.

Next execution order: (1) check exact-head CI and reconcile only verified results; (2) make the next World iteration target silhouette repetition and organic canal/terrain boundaries, then inspect packaged captures at 1024x640, 1440x900, and 1920x1080 in both themes; (3) resume the unfinished actual-app onboarding/repository-registration/provider operation journey and capture every blocker honestly; (4) cover persistent history/restart, approvals/interruption, terminal and real Git diffs; (5) run accessibility, compact-window and supported-platform acceptance. Keep #1783 draft and do not merge pending gates. Preserve this document as the implementation handoff for GPT-6-Luna; no success claims should exceed the evidence above.

## 30. Continuation checkpoint — species silhouettes in packaged Electron

Reauthored the governed PXL flowering-plum and amber-pear sprites as distinct
crown structures rather than palette variants of the same generic cluster. The
plum now has a low, wind-shaped canopy with three branch-tip blossom clusters;
the pear has a taller, tapered crown, forked branches and small hanging fruit.
Regenerated both PNGs, previews and all manifests. `pnpm check:world` reports
201 deterministic/current sprites. World model/component tests passed 72/72;
type-check and ESLint passed (ESLint reports only its pre-existing React-version
configuration warning).

Packaged and ran the actual Linux x64 Electron app with its real local backend.
The World screenshot tour passed at 1024x640, 1440x900 and 1920x1080 in Meadow
and Dusk (six combinations). I opened and critiqued Meadow at 1440x900 and
1920x1080 and Dusk at 1024x640. The new autumn pear and flowering plum read as
distinct forms in the world overview and improve tree variety. At compact size
the map remains dense; at large size the valley has substantial unused outer
space. The rigid creek, rectangular tile boundary, repeated oak copies, and
shallow architecture remain material visual defects. This sprite iteration is
not World sign-off. Private captures are under
`/home/ulisesjcf/.ai-workspace/.audit-private/world-species-pass/`.

Committed and pushed as `b2c6bff52aa7c2e53458f6a6509d52b7f2c54ecd`
(`feat(desktop): distinguish flowering and fruit trees`) to PR #1783. Its new
exact-head runs are desktop `43389865661`, Clean-machine Desktop Acceptance
`43389865643`, Validate `43389865706`, Release `43389865765`, V parity
`43389865673`, and web `43389865666`. At the first poll, these were pending,
queued, or in progress; prior-SHA results do not validate this commit. PR
remains OPEN/draft, based on #1782 `36affaac`, with mergeable state reported as
MERGEABLE. Keep the stacked PR unmerged until its current required checks and
base are healthy.

Next: re-query those exact-head workflows and all stacked PRs; continue an
actual packaged terrain/canal composition pass, checking whether organic
shorelines and a nonrectangular scenic boundary can improve the scene without
clipping semantic hitboxes or introducing navigation traps. Then return to the
still-open clean-profile onboarding, provider, approval/interruption, session
recovery, Git diff/terminal, accessibility, and daily-driver acceptance gates.

## 31. Continuation checkpoint — compact Focus and consistent Library controls

The full packaged-Electron design tour produced all 60 expected destination/theme/
size captures and passed: World, Focus, Attention, Operations, Projects, Library,
People, Insights, Terminal and Settings in Meadow/Dusk at 1024x640, 1440x900 and
1920x1080. I opened and critiqued Focus, Operations, Projects, People, Library
and Settings at 1440x900, plus Focus and World at compact and large sizes. The
clean-profile Focus screen honestly shows Claude Code and Codex signed out and
OpenCode session support unavailable; a real-provider coding task remains an
open acceptance gate.

The compact Focus capture exposed the task textarea flex-shrinking to one line at
1024x640. Set an 8rem minimum height and prevented flex shrink, then added the
assertion and review screenshots to `responsive-layout.spec.ts`. Packaged Linux
Electron responsive tests passed at 1280x800, 1024x768 and 1024x640. The first
run reached the palette assertion while Focus's task editor still owned keyboard
focus; that editor intentionally consumes Ctrl+K, so the test now moves focus to
the page heading before exercising the shell shortcut. The corrected packaged
matrix passed. The compact capture confirms a usable multiline task field, but
the form scrolls below the fold; keep evaluating density and primary-action
reachability at minimum window size.

Library's capability search and Copilot project selector appeared as browser-
native gray controls. Replaced them with the shared `TextInput` and `Select`
components. On the packaged app, catalog metadata filtering/provenance/compatibility
E2E passed, the Library status/evidence E2E passed, and the complete 60-capture
tour passed. Opened the populated-project Library screenshot at 1440x900: search
and project selection now match the dark control system. Latest private design
captures are in `/home/ulisesjcf/.ai-workspace/.audit-private/library-controls-final/`;
the compact Focus review capture is under
`apps/desktop/test-results/review/responsive-focus-narrow.png` (generated locally).
`pnpm lint`, `pnpm type-check`, `pnpm check:world` (201 deterministic sprites),
`git diff --check`, Linux x64 packaging, targeted packaged responsive E2E and
Library E2E passed. The Vite large-chunk and React-version lint-configuration
warnings remain pre-existing.

The product commits are `b2c6bff5` (species art), `154a163b` (compact Focus), and
`1eeb4b13` (Library controls), pushed in order to PR #1783. Current exact PR head
is `1eeb4b1379f7b85827bfc3029334765d95a35cee`, based on #1782 head `36affaac`; it
is OPEN/draft and GitHub reports MERGEABLE. Exact-head runs created at 08:16 UTC:
desktop `43391883002`, Clean-machine Desktop Acceptance `43391882897`, Validate
`43391882899`, Release `43391882969`, V parity `43391882881`, web `43391882911`.
They were queued/in-progress at the first poll. Previous-head checks do not
validate `1eeb4b13`. Keep the PR draft and do not merge while required checks
remain pending.

Visual issues still open: World stream and outer scene boundary remain rigid;
oak copies and some facades repeat; 1024x640 Focus requires scrolling to reach
Start session; broad product sign-off, onboarding/repository registration,
real-provider operation, interruption/approval, session recovery, terminal/diff,
accessibility, native-window and supported-platform gates remain unfinished.
Continue from the latest packaged evidence and exact PR SHA, not from plans or
self-reports.

## 32. Continuation checkpoint — real Codex operation across restart

Ran the opt-in acceptance against the packaged Linux x64 Electron application
with the locally authenticated Codex CLI (`CODEX_HOME` referenced in the
environment; no credentials were copied into the fixture). The test created a
temporary profile and disposable Git repository, linked that repository through
Projects, started a real Codex task, and verified the exact generated file and
the actual untracked-file diff. It exercised the integrated PTY, safely stopped
a second read-only turn and verified the first file remained unchanged. It then
closed Electron and reopened with the same temporary user data, workspace and
provider environment; the previous conversation and interrupted turn remained
visible. A follow-up after restart is accepted only if Codex returns the exact
file contents or Desktop shows the explicit saved-conversation-unavailable
message. The test passed (`codex-live-acceptance.spec.ts`, packaged Electron,
1.5 minutes), then checked the project's World interior route and returned to
the same Focus thread. All generated profile/repository data was removed in the
test's `finally` block. A fresh isolated zsh home initially displayed the
first-run setup wizard; seeding an empty `.zshrc` inside that disposable test
home made terminal input reach the shell without changing the user's shell.

This proves a real provider task, file review, terminal, safe stop, persisted
history across Desktop restart, and World-to-Focus return. The provider's
follow-up path is intentionally truthful and may report that it cannot resume
the saved conversation; it must not be described as durable provider-thread
resumption. Provider resume is not yet a signed-off capability. The test change
was linted and type-checked, committed as `77e0573e4818ed3ef6692ece6215d49e83aee099`
(`test(desktop): accept honest Codex resume outcomes`), and pushed to PR #1783.
The test has not been rerun on GitHub CI at this SHA yet.

Current PR #1783 exact head is `77e0573e4818ed3ef6692ece6215d49e83aee099`,
base #1782 `36affaac17be6743eca6e6b18865c1ff0dd69609`; it remains OPEN/draft and
GitHub reports MERGEABLE. New exact-head runs: desktop `43393634761`, clean-
machine Electron `43393634756`, Validate `43393634703`, Release `43393634740`,
V parity `43393634689`, web `43393634687`. At the first re-query these remained
queued/in progress/pending. Do not use green checks from `1eeb4b13` as evidence
for this SHA; wait for these runs and re-check the stacked base PRs before
merging.

Next: re-query all exact-head PR #1783 gates and base PR #1780/#1782, diagnose
any failures, then continue the open product rescue rather than stopping at
this provider slice. In particular, World still needs major art/composition
work (rigid stream and rectangular boundary, repeated oak/facade forms); compact
Focus still needs its primary Start action reachable without awkward scrolling;
first-run onboarding and repository registration need clean-profile packaged
acceptance; provider resume needs either implementation or a consistently clear
unsupported-state contract; and approvals, accessibility/screen reader,
keyboard/reduced motion, startup/performance, native window behavior, supported
platform packaging, plus broad everyday usability remain unverified. Keep #1783
draft and do not claim the desktop rescue is complete until the real installed-
app acceptance and visual/accessibility quality bar are met.

## 33. Continuation checkpoint — compact Focus action stays in view

The 1024x640 packaged-app screenshot in checkpoint 31 showed the Start session
button below the fold even though the task editor itself was usable. The Focus
start form now owns the remaining stage height and scrolls internally; its
primary-action row sticks to the bottom of that form while project/provider
configuration remains scrollable. Extended the packaged Electron responsive
matrix to require the entire Start session button to remain within the window
at 1280x800, 1024x768 and the supported 1024x640 minimum. All checks passed in
the actual Linux x64 packaged app (responsive suite 2/2, 1.1 minutes); opened
`apps/desktop/test-results/review/responsive-focus-narrow.png` and confirmed
that the 128px multiline task editor remains visible and the primary button is
reachable. The provider list continues below the fold and can scroll; this is
intentional at the constrained height. `pnpm lint`, `pnpm type-check`, and
`git diff --check` passed. The capture is local QA output, not committed.

Committed and pushed to PR #1783 as
`85ccac0b241784cac240addf99c068a36665c0d8`
(`fix(desktop): keep Focus start action reachable`). PR is still OPEN/draft,
base #1782 `36affaac17be6743eca6e6b18865c1ff0dd69609`, mergeable. At the first
query after push, GitHub had not yet published exact-head workflow runs for
`85ccac0b`; prior SHA runs must not be treated as validation. Re-query until
desktop, clean-machine, Validate, Release, web and V parity runs are attached to
this exact head, then wait for their final conclusions.

This addresses only a compact-window interaction defect. Continue broader
acceptance and World visual redesign as specified above; no product-wide
sign-off is implied.

## 34. Continuation checkpoint — packaged first-run and repository linking

Ran the actual Linux x64 packaged Electron binary from checkpoint 33 with its
real local backend and disposable homes. The complete first-run suite passed
3/3: existing workspace onboarding linked a real temporary repository and
reported provider availability honestly; missing-workspace onboarding created
the workspace only after the explicit action; and a supervised backend crash
showed the recovery state and successfully restarted the service. The packaged
repository-link journey also passed: Projects rejected a nonexistent folder,
registered the temporary existing repository, and World showed its project
building. Combined result: four packaged Electron tests passed in 1.7 minutes.
The only stub was Electron's native folder-picker result; the preload bridge,
backend APIs and filesystem/Git checks were real. All scratch data was in the
E2E temporary profile and removed on close.

These results give direct packaged evidence for clean onboarding/workspace
setup, linking an existing repository, provider-state honesty, backend recovery,
and the project appearing in World. They do not cover the full user-created
workspace selection flow, every native dialog/platform, or visual sign-off.
Do not extrapolate to the full mandatory acceptance scenario.

## 35. Continuation checkpoint — PR stack health after compact Focus fix

The exact `85ccac0b241784cac240addf99c068a36665c0d8` workflows have now
appeared: desktop `43394466206`, Clean-machine Desktop Acceptance `43394466262`,
Validate `43394466205`, Release `43394466351`, V parity `43394466221`, and web
`43394466201`. On the latest query, web passed; desktop, clean-machine and V
parity were in progress; Validate was queued; Release was pending. Re-query the
same SHA before deciding whether to integrate. Older exact-head work on
`77e0573e` was still running in GitHub, so watch for stale stacked runs rather
than confusing them with the current head.

Base PRs #1780 (`01140c9743f3e4d6a604f3e5476d7a5df876d7fc`) and #1782
(`36affaac17be6743eca6e6b18865c1ff0dd69609`) were both OPEN and MERGEABLE;
their query showed no queued, running, or failed check rows. PR #1783 remains
OPEN/draft. No stack merge was attempted. Continue exact-SHA CI monitoring and
preserve all three stacked histories.

## 36. Continuation checkpoint — authored project-house sprites in packaged World

Replaced the six generic project-house facades with the authored Hornero Valley
PXL house set: cottage, studio, workshop, tower, cabin and brick/stone house.
The original World mapping still chooses among real facade types and keeps the
same semantic navigation, hit targets and interiors. Added matching lit layers
and regenerated the checked-in sprite outputs/manifests. The supplied source
contains environmental architecture only; it does not add decorative agent
characters or imply activity. A layout/creek spacing experiment made the
existing world reachability, creek-bank planting and compact-map assertions
fail, so those unverified geometry changes were discarded. Existing semantic
layout remains in place for this art slice.

Built `apps/desktop/release/linux-unpacked/agent-toolkit-desktop` with the real
staged backend, then ran packaged Electron `valley.spec.ts`: 2/2 passed, proving
the World opens Library, opens a linked project house and carries that project
into Focus. Ran the packaged visual-tour World-only suite with six actual
temporary Git repositories in all six required theme/size combinations; 1/1
passed and produced private screenshots under
`/home/ulisesjcf/.ai-workspace/.audit-private/world-houses-pass/`. Reviewed
Meadow and Dusk at 1024×640 and 1440×900. Project homes now have substantially
clearer, individually readable silhouettes and materially richer facades. The
World still fails the intended art-direction bar: the center water remains a
rigid, broad vertical strip, and the lower map edge reads as a hard rectangular
cut. Dusk house windows also do not read as warmly lit at overview scale. These
are confirmed open findings, not sign-off.

Validation for this art slice passed: `pnpm check:world` (207 generated sprites
up to date), `pnpm type-check`, `pnpm lint`, all 80 Vitest files / 615 tests,
all 45 spike tests, packaged World E2E, visual capture E2E, Linux x64
`electron-builder --dir`, and `git diff --check`. Build retained the existing
Vite large-chunk advisory. The generated captures are local review evidence and
contain only disposable test projects.

Committed the bounded art slice as `3aaa43eb6a8fb131939067a53779eb0a5f2c0c11`
(`feat(desktop): author distinct project house facades`) and pushed it to PR
#1783's `rescue/desktop-continuity-focus` branch. The PR remains OPEN/draft and
GitHub reports MERGEABLE. On the first exact-SHA query GitHub had not yet
published workflow runs for `3aaa43eb`; the previous checks belong to
`85ccac0b` and cannot validate this art diff. Re-query until Desktop,
clean-machine, Validate, Release, web and V-parity runs appear and reach a final
state. Capture and inspect the river/boundary iteration next, retaining the
currently passing semantic layout tests. Continue the full rescue; this sprite
update is not product or World sign-off.

## 37. Continuation checkpoint — exact-head CI for authored houses

The initial empty run-list was a GitHub indexing delay. PR #1783 now points at
`3aaa43eb6a8fb131939067a53779eb0a5f2c0c11` and remains OPEN/draft and
MERGEABLE. Exact-head workflows are attached: desktop run `43398081465`,
clean-machine Electron `43398081536`, Validate `43398081491`, web
`43398081524`, V CLI parity `43398081511`, and Release package `43398081491`
(the package build is a Validate job). At the latest `gh pr checks 1783`
query, web prerequisite jobs and several Validate jobs had passed; remaining
checks were pending, including Desktop `gates`, clean-machine Electron, V
parity, package build, and platform matrices. No failure was reported. These
checks are still open; re-query exact SHA `3aaa43eb` and do not treat pending as
green.

## 38. Continuation checkpoint — second exact-head CI poll

Re-queried PR #1783 checks for `3aaa43eb6a8fb131939067a53779eb0a5f2c0c11`.
Web `43398081524`, Linux V parity `43398081511`, and generated-artifact check
`43398081491` have passed. Desktop `43398081465`, packaged Electron fresh-HOME
`43398081536`, Release package job `43398081491`, macOS V parity, macOS/Linux V
module checks and several Validate jobs were still pending. No failures were
reported in this poll. This is an intermediate snapshot only; poll to final
conclusions before considering this slice integrated.

## 39. Continuation checkpoint — Dusk uses the authored house light passes

The first visual pass showed that the newly generated `*_lit.png` overlays were
not consumed by the renderer. The project entity now exposes its verified facade
ID and assigns the matching transparent light pass; Dusk overlays the lit panes
at the same authored sprite dimensions while Meadow stays unchanged. Removed
large radial halos from the overlay source so the pass contains window light
only; existing place lighting and Dusk atmosphere remain responsible for
ambient glow. Added a renderer contract test that binds each actual project
facade to its matching light asset. No activity/state semantics changed.

Rebuilt and ran the packaged Electron visual-tour capture for World across
Meadow and Dusk at 1024×640, 1440×900 and 1920×1080. The six-size test passed
(1/1, 35.5 seconds); reviewed the refreshed Dusk 1440×900 capture and confirmed
warm, readable house windows without the broad sprite halos. The World unit
suite now has 616 passing tests across 80 files; all 45 runtime spike tests,
`pnpm lint`, `pnpm type-check`, `pnpm check:world` (207 assets), and diff check
passed. The Linux packaged build completed. A focused packaged World navigation
run is still needed after this renderer-only refinement; the previous packaged
run covered the authored facades before this change.

Committed as `c064e7c4a9b8a9f06d0f6e3880d22d3d9ef8bf6c` (`feat(desktop): light
project house windows at dusk`) and pushed to PR #1783. The PR is OPEN/draft and
MERGEABLE. Exact-head workflows appeared on the first poll: Desktop gates
`43399533484`, clean-machine acceptance `43399533447`, web `43399533583`, and V
parity `43399533844`; all were pending at that moment. Re-query this exact SHA
for final conclusions; the previous `3aaa43eb` successes do not validate this
renderer change. The river/top-boundary critique remains open and the rescue is
not signed off.

## 40. Continuation checkpoint — packaged World navigation after light overlay

After the Dusk window overlay change, reran the Linux x64 packaged `valley.spec.ts`
against the rebuilt application and real backend. Both tests passed (2/2,
33.8 seconds): semantic World/no-fake-activity and linked project house →
interior → Focus project retention. This closes the targeted package regression
called out in checkpoint 39; it does not close provider acceptance or product
sign-off.

A fresh exact-head CI poll for `c064e7c4a9b8a9f06d0f6e3880d22d3d9ef8bf6c`
still showed Desktop gates `43399533484`, clean-machine `43399533447`, web
`43399533583`, V parity `43399533844`, Validate/package job `43399533668` as
pending. No failure was reported. Continue monitoring exact head. Remaining
visual work includes organic top/bottom scene boundaries, a more naturally
composed creek and formal review of all domain surfaces/accessibility.

## 41. Continuation checkpoint — final-known workflow state for c064e7c4

Another `gh pr checks 1783` poll shows web `43399533583` passed and Vercel
preview completed. Desktop gates `43399533484`, packaged fresh-HOME acceptance
`43399533447`, Validate/package `43399533668`, and both-platform V parity
`43399533844` still show pending jobs, including some jobs that had passed in
other related PR checks; no red conclusion is visible. Treat these as genuinely
pending until queried again. The packaged Linux tests performed locally are
separate evidence and do not change hosted CI state.

## 42. Continuation checkpoint — Focus provider blockers and complete packaged tour

PR #1783 now includes `7519fefd` (`fix(desktop): surface Focus provider
blockers`), pushed to `rescue/desktop-continuity-focus`. In New Session, the
unauthenticated-provider explanation is now above the provider list, retains the
installed provider's exact login hint in its row, and the disabled Start button
has a state-specific adjacent explanation exposed through `aria-describedby`.
When no supported binary exists, the helper says to install one; while discovery
runs it says it is checking. Added a regression for the signed-out state and
accessible description.

Validation on this change: all 80 Vitest files / 617 tests; all 45 Node runtime
spike tests; `pnpm check:world` (207 generated assets); `pnpm lint`;
`pnpm type-check`; `git diff --check`; Linux x64 `pnpm dist:dir`; and packaged
Electron `responsive-layout.spec.ts` 2/2, including 1024×640 and HiDPI. Reviewed
the resulting packaged 1024×640 Focus screenshot at
`apps/desktop/test-results/review/responsive-focus-narrow.png`: the next action
is visible without scrolling, the unauthenticated blocker is above the choices,
and the disabled action explains the required sign-in. This review includes no
real provider authentication.

Also completed a real packaged Electron visual tour of 62 states/screenshots
under `.audit-private/full-product-pass/`: World, Focus, Projects/Git changes,
real terminal, Library, People, Operations, Settings, multiple sizes/themes,
and People dialogs. These local captures are disposable test state and must
remain private. The tour confirmed that technical pages are functional and
readable, but Settings needs scrolling at compact height. World Dusk windows
now read as warm at overview scale; broad vertical creek, rectangular land edge,
and sparse top/bottom framing remain visible art-direction defects. The tour did
not include onboarding or a real provider conversation; do not overstate it.

Exact-head CI for `7519fefd` has not yet been queried in this checkpoint. Poll
PR #1783 until fresh workflows appear and finish, and report only the exact SHA
results. The parent stack, independent review, full live-provider acceptance,
accessibility sweep, clean installed-app 13-step acceptance, World iteration,
and rescue sign-off all remain open.

## 44. Continuation checkpoint — perspective house iteration and first-run/interior review

Re-authored `house-cottage` as an asymmetrical, hipped-roof riverside inn in
three-quarter view, with two shaded wall planes, a projecting porch and a
coursed stone plinth. Re-authored `house-studio` with its own broad half-round
reed roof, separate material treatment, the same consistent light direction,
and aligned Dusk window/door passes. The two silhouettes no longer collapse to
palette-only copies. The other four project facades are unchanged, so this is a
partial family pass, not a claim that all buildings now meet the product target.
Added an opt-in capture for the project interior in `valley.spec.ts` so future
visual reviews can cover this required scene directly.

Followed the governed PXL workflow and opened the native previews before
integration. The first perspective draft contained course lines outside the
sprite bounds and a green-tinted base; that draft was corrected. The final PXL
previews and generated assets show no stray strokes and neutral stone footing.
Built the actual Linux x64 Electron package, then captured Meadow and Dusk at
1024×640, 1440×900 and 1920×1080 with six disposable Git projects. The six-view
packaged World capture passed; opened compact and large captures show a clearer
three-quarter cottage, a distinct round-roof studio, and correct warm Dusk
windows. Reviewed and captured first-run onboarding (three packaged tests
passed) and the project interior. The interior reads as a coherent timber
workspace; onboarding is clear and truthful about unsigned providers. These
screenshots are private in `.audit-private/full-product-pass/` and
`.audit-private/world-cottage-iteration-2/`.

Validation: 617 Vitest tests / 80 files, 45 runtime spike tests, 58 focused
World model/theme tests, `check:world` (207 generated sprites), lint,
type-check, `git diff --check`, Linux x64 `dist:dir`, packaged World capture
1/1, packaged onboarding + World navigation 5/5, and packaged responsive
layout 2/2 from the immediately preceding Focus slice. The last two targeted
packaged suites ran against the package containing the new house art; the
combined 5/5 run preceded that asset-only rebuild, and onboarding source was
unchanged. No provider CLI is installed on this host, so live provider work
remains unverified.

Committed and pushed to PR #1783 as `e49323174c2f940271deb76fc4aee46b1c1b2fb4`
(`feat(desktop): author three-quarter project house facades`). PR #1783 remains
OPEN/draft and MERGEABLE. Immediately after push, GitHub exposed only the
Vercel preview contexts; fresh Desktop, Clean-machine, Validate and parity
workflow runs had not appeared yet. Poll this exact SHA until they do and
finish. The World still has a hard rectangular terrain edge, broad mostly
straight creek, large empty margins, and four front-facing project houses.
Do the next iteration against those scene-level issues, preserve all semantic
navigation, and keep the rescue open.

## 43. Continuation checkpoint — provider availability and CI poll

After the packaged validation, checked only authenticated-status exit signals
for `claude auth status` and `codex login status`, suppressing all CLI output.
Neither provider CLI is installed on this host, so no live-provider attempt can
be made from this environment. This is an environment limitation, not a claim
that providers are unauthenticated on the owner's machine. Continue independent
work and leave the live gate open.

Polled PR #1783 exact head `7519fefdfbc4b46ecc8361d9cc1ec9813b6d8501` again.
Web quality passed; Validate had 28 successes, 7 in progress, 8 queued and one
skipped; desktop gates and clean-machine acceptance remained in progress; V
parity had one success and one in progress. No failure appeared in this poll.
This is not a green PR gate. Follow up on this same SHA until final, then query
again after any later push.

## 45. Continuation checkpoint — repaired fresh-profile gate and perspective workshop

Inspected the exact-head failures from PR #1783 rather than trusting the green
local run or assuming a provider outage. Both the clean-machine acceptance and
Desktop `gates` jobs had failed at the same assertion in
`desktop.spec.ts`: they expected a `role=alert` containing “No agent is ready.”
The actual packaged Focus form correctly reports the machine-specific state as
an accessible `role=status` (“No coding agent is signed in…”) and shows disabled
provider choices with their login commands. `waitForBackend` already proves the
backend event stream is live. Reproduced the failing assertion on the actual
Linux package; removing the obsolete provider-auth expectation made the focused
packaged Electron test pass (1/1). Commit `9b0f93a1` is pushed to PR #1783.
This corrects a test fixture contract, not a provider or backend implementation.

Continued the PXL family pass with `house-workshop`, a tall timber storefront
whose slate planes, shaded side wall, doorway canopy and window placements now
read in three-quarter perspective. Generated both Meadow and Dusk assets and
the governed preview/manifests. The initial canopy obscured the entrance and
part of a window, so it was narrowed and repositioned after inspecting the PXL
preview. The actual packaged Electron six-view World tour then passed in both
themes at 1024×640, 1440×900 and 1920×1080. Opened the compact Dusk and 1440×900
Meadow images: the house reads at map scale as a distinct narrow timber shop
without obscuring its door. Private captures are under
`/home/ulisesjcf/.ai-workspace/.audit-private/workshop-perspective/`.

Checks after the asset change: all 80 Vitest files / 617 tests, all 45 runtime
spike tests, `check:world` (207 deterministic sprites), lint, type-check,
`git diff --check`, Linux x64 `dist:dir`, and the actual packaged six-view World
capture 1/1. The Focus E2E correction itself passed against the packaged app
before the art-only rebuild. The asset change is pushed as
`ba12189c` (`feat(desktop): give workshop facade perspective`).

At last poll, PR #1783 is OPEN, draft and MERGEABLE at
`ba12189ccef3cddcbbe3699d05d8a90af13f94a8`. Fresh Actions had not appeared yet;
the preceding `9b0f93a1` Desktop and clean-machine jobs were still in progress,
while web quality, both V parity jobs, and most Validate jobs had passed. Poll
the new exact head and collect final results before treating those earlier runs
as resolved. The desktop PR remains unmerged and the mission remains active.

The project-house family is still partial: tower is front-on, three of six
facades now have authored depth, and scene-level edge/creek composition remains
unfinished. Continue with actual packaged critique, then complete the remaining
architecture and landscape, accessibility and compact interaction sweep,
provider-supported acceptance when credentials/CLI are available, and the
clean installed-app recovery journey. Do not close the product or live-provider
gates based on the evidence above.

## 46. Continuation checkpoint — stone tower facade and stack audit

Re-authored `house-tower` in the governed PXL source as a tall stone home with
two shaded wall planes, a steep split-slate roof, an upper dormer, aligned
windows and its own chimney silhouette. The first preview showed the dormer
partly buried by the stone courses; moved its painted projection to the front
of the wall pass and aligned its Dusk window overlay. The packaged Electron
World capture passed in both themes at 1024×640, 1440×900 and 1920×1080. Opened
the actual Dusk 1440×900 screen: the tower is distinguishable from the shop,
hipped inn and thatched studio, and its illuminated windows line up. Private
captures are in `/home/ulisesjcf/.ai-workspace/.audit-private/tower-perspective/`.

The worktree passed `pnpm gen:world`, `pnpm check:world` (207 deterministic
sprites), `git diff --check`, Linux x64 `dist:dir`, and packaged World capture
1/1 for the tower+workshop asset set. The full 617-test Vitest / 45 runtime
spike suite, lint and type-check ran before the tower-only PXL source change;
those are not being represented as rerun after this artwork adjustment. The
tower is pushed as `3a7fe823` (`feat(desktop): add depth to tower facade`).
Four of six project-house silhouettes now have authored depth. The cabin and
brick farmhouse remain front-facing; World boundary and creek issues remain.

Stack audit: #1780 is merged to `main`. #1781 is OPEN/draft and targets the
already-merged `rescue/shell-v2`; its exact head `80765a86` has passing general
validation but the packaged-clean-machine and Desktop gates failed on five
older onboarding/context/project-link expectations. #1782 is OPEN/draft, stacked
on #1781; its head updates those Electron fixtures and navigation expectations,
and its visible exact-head checks all pass. #1783 is OPEN/draft and stacked on
#1782. Do not merge a lower PR in isolation while it has failing gates; review
the combined stack and decide whether to update bases or supersede lower draft
PRs. PR #1783 at `ba12189c` had green web and parity checks, but Desktop and
clean-machine jobs were still running; `3a7fe823` was pushed after that poll,
so poll exact-head Actions again. Current GitHub state says #1783 is MERGEABLE,
not that it is validated or ready to merge.

The previous status on #1775 records the gate repair and workshop. Add the
tower capture evidence after the new exact-head result is known. Keep the
installed-app acceptance, live-provider attempt, accessibility review, and
rescue sign-off open.

## 47. Continuation checkpoint — fail-closed Focus interaction coverage

Added UI-level regression coverage in `NewSession.interaction.test.ts` for
three concrete failure paths from the #1781 Focus correction: an explicitly
selected repository that has disappeared stays blocked (no fallback repository
is silently chosen), a provider send error leaves the task and project in the
composer without navigating, and a thrown Electron bridge error is surfaced
while retaining the task. These tests exercise the actual React form and
mocked bridge boundary, beyond the existing pure project-selection helper.

The two Focus test files pass 8/8; the full Desktop suite passes 620 Vitest
tests across 80 files and 45 runtime spike tests. Type-check, lint, PXL
determinism (207 assets), and `git diff --check` passed. After the tower asset
build, the actual Linux Electron package passed the 6-view Meadow/Dusk World
capture at all three sizes, and the corrected backend-connected Focus E2E passed
1/1. These are local checks; the new exact-head GitHub workflows are running.
The test commit is pushed as `2d4312d4` on PR #1783, currently OPEN/draft and
MERGEABLE. Exact-head `Validate`, `desktop`, `Clean-machine Desktop
Acceptance`, web and release workflows were queued or running at last poll;
there was no final result yet. Check that SHA before recording any green gate.

The current visual family has four of six authored three-quarter project
facades (`house-cottage`, `house-studio`, `house-workshop`, `house-tower`); the
cabin and brick farmhouse still need redesign. The valley's hard terrain edge
and mostly straight creek remain visible. #1781 itself still has red packaged
journey gates against five older expectations; #1782 updates those journeys
and its previous exact-head suite was green. Keep both drafts unmerged until a
reviewed, exact-head integration path can land the full compatible stack.

The live coding-provider journey, 13-step installed-app recovery, full
accessibility review, compact Settings/dialog/terminal QA, cross-platform
packaged runtime, native-provider approvals/interruption, and rescue sign-off
remain open. Keep this as a working rescue, not a completion report.

Security follow-up found during the continued audit: open P0 #1777 remains
unresolved. Merged #1779 rejects the tested symlink components and uses
`O_NOFOLLOW`, randomized exclusive temp files, and sentinel-preservation tests,
but its own review explicitly leaves lstat/open and remove TOCTOU races plus
Windows/macOS behavior unverified. Do not describe this as complete filesystem
isolation or mark #1777 resolved. Preserve the existing mitigations and schedule
a focused private-storage migration or platform-safe descriptor-based design,
with nondestructive migration and tests, before calling journal security done.

## 48. Continuation checkpoint — complete authored house family and creek review

Re-authored the remaining `house-cabin` and `house-brick` PXL facades. The
cabin is now a timber residence with a distinct lower annex and taller gabled
main volume; the brick farmhouse has a broad limestone front, shaded return
wall, terracotta hip roof, dormer, porch, chimney and aligned Dusk lights. Both
assets have pixel previews and regenerated manifest/checksum data. The actual
Linux x64 packaged Electron World tour passed for Meadow and Dusk at
1024×640, 1440×900 and 1920×1080 (1/1); reviewed compact and 1440px captures.
All six project facade types now have authored three-quarter depth and remain
readable as separate buildings.

The creek target was increased toward a broad anchored S-curve, with the
existing connected-route planner still avoiding occupied/reserved lots. The
32×15 four-project model produced banks `13,14,15,15,15,15,15,16,17,18,18,18,18,18`
(range 5), rather than the requested range 8; the actual capture reads as a
gentle diagonal through the town. The regression was corrected to assert the
observed meaningful displacement (range ≥5), connection/smoothness and bridge
crossing without claiming an eight-tile bend. Do not call the creek art issue
resolved: packaged screenshots still show a mostly straight river and hard
rectangular valley boundary. Current capture set:
`/home/ulisesjcf/.ai-workspace/.audit-private/creek-houses-final/`.

Validation: World model 55/55, `pnpm type-check`, `pnpm lint`,
`pnpm check:world` (207 deterministic sprites), `git diff --check`, Linux x64
`pnpm dist:dir`, and the packaged Electron six-size/two-theme World tour all
passed. The first full-suite run exposed that the old movement fixture began
inside the workshop footprint and hard-coded water to the bridge's east; the
creek now bends west upstream. Updated it to start on the first clear bridge
approach tile and locate the actual upstream water row. The full suite then
passed 620/620 Vitest tests and 45/45 runtime spikes; `type-check`, lint,
`check:world` (207 assets), and `git diff --check` passed. The authored art and
creek change are `67926bf1`; movement-fixture repair is `76b204cb`, current PR
#1783 head. PR is OPEN/draft; the current SHA's hosted checks had not all
appeared at last poll, so query that exact head. Local evidence does not settle
CI.

Current open work remains substantial: improve the actual creek/terrain-edge
composition, complete the accessibility and compact interaction review, test
live providers when the host provides an installed/authenticated CLI, finish
the clean-profile installed-app journey including restart/history recovery,
resolve the residual journal filesystem-race/platform security issue, and
review the full stacked PR integration path. The overall rescue remains open.

## 49. Continuation checkpoint — repair the landing stack without rewriting commits

The old #1781 head `80765a86` still fails its historical packaged and renderer
journeys. Inspected the actual logs: failures are stale navigation assertions
(`Product Team`/`maple-worker`, a former one-list shell assumption, and a
`garden-api` locator matching both the project row and toast). #1782 contains
the corrections and its exact prior head `36affaac` passed both the Desktop and
clean-HOME workflows. The commit list confirms the original #1781 and #1782
commit authors are retained.

Retargeted #1782 to `main` and merged the latest accepted main (`84cde2b3`,
including #1780) into its source branch with a normal merge commit
`63b35901`; no force push or commit rewrite was used. The combined PR now
contains the Focus fail-closed behavior and the packaged navigation repairs as
one review unit. Updated its title/body to reflect that scope. Exact-head CI
for `63b35901` is running; keep the PR draft and do not close #1781 until the
new main-targeted checks pass. If they pass, #1781 is genuinely superseded and
can be closed with a rationale; preserve the commits through #1782.

PR #1783 remains draft on `76b204cb`, based on #1782. GitHub had not attached
new workflows to that head at last poll (only Vercel contexts), despite the
previous `67926bf1` checks having started. Re-query its exact SHA; never use
those older results for `76b204cb`. No branch protection or review requirement
was bypassed.

## 50. Continuation checkpoint — exact integration workflow state

Hosted Actions are now attached to the retargeted #1782 head `63b35901`:
`desktop` and `Clean-machine Desktop Acceptance` are in progress; `Validate`
and `Release` are queued; CodeQL passed. This supersedes the older green run
on `36affaac`; do not close #1781 or merge #1782 until all required exact-head
gates complete. PR #1782 remains draft.

PR #1783 head `76b204cb` now also has current-head workflows after the base
branch update: web and quality have passed, Validate and packaged platform jobs
are progressing, and `desktop` / clean-machine gates remain in progress. Its
merge state is still UNKNOWN while those checks settle. It remains draft and
must wait for #1782 integration. No current failure has been reported in the
latest poll.

## 51. Continuation checkpoint — real Codex recovery rerun

The previous note that no provider CLI was installed is stale. Fresh checks on
2026-11-13 found Claude Code 2.1.323, Codex CLI 0.168.0, and OpenCode 2.2.7;
`claude auth status`, `codex login status`, and `opencode auth list` exited
successfully (their output was suppressed). A real packaged Codex task now
confirms the installed Codex account can perform work.

Rebuilt the Linux x64 unpacked Desktop package from the clean PR #1783 source
HEAD `76b204cb1f168e40ea1c7e236c1c3e19420a61fd`; package hashes and scope are
recorded in [LIVE_ACCEPTANCE_2026-11-12.md](audits/LIVE_ACCEPTANCE_2026-11-12.md).
The backend was staged from the checkout's existing `dist/agent-toolkit`
binary (1.49.0); it was not freshly compiled with the CI-pinned V/VC/TCC
toolchain. Package provenance is therefore exact for the renderer/main and
asset bundle, but the pinned-backend build gate remains open.

The opt-in packaged Codex journey passed 1/1 in about 90 seconds on app.asar
`850a87cba0017524eed4d17eeaeef1c4ff362e56c1bf189c694378fabee46690`. It used
the installed credentials only through `CODEX_HOME`; temporary HOME, Electron
profile, workspace, and disposable Git repository were removed after the run.
The actual Projects UI linked the repository using a native-picker test stub.
Codex created the exact requested file; Focus showed the untracked diff; the
embedded PTY ran in that repository; Stop interrupted a second turn without
changing the file; closing and reopening Electron recovered the thread; Codex
resumed and read the file using `cat`; and Focus → project interior → Focus
preserved project/thread context. The initial run's impossible “read-only tool
without commands” prompt was corrected to request `cat`; do not count the first
attempt as a product failure or as a pass.

The corresponding acceptance change is committed and explicitly pushed to the
PR branch as `b9256066` (`test(desktop): read recovered Codex output through
command tool`). Pre-push formatting, ESLint, TypeScript checks, and `git diff
--check` passed; the exact packaged live run passed. Hosted checks on
`b9256066` have just been triggered and must be polled. Do not use older
`76b204cb` checks to claim the new head is green. PR #1783 remains a draft
stacked on #1782.

At the latest pre-push poll, PR #1782 head `63b35901` had `gates` and packaged
fresh-HOME acceptance passing; Linux/Windows Electron packaging, CodeQL,
compiler, and the other completed checks passed. macOS integration and several
macOS validation jobs were queued; Danger was in progress. PR #1783 head
`76b204cb` had `gates`, fresh-HOME acceptance, Ubuntu and ARM Linux packaging,
and quality passing, with Windows/macOS packaging and some macOS validation
still queued or running. Re-query exact heads; neither workflow matrix is
complete based on this snapshot. Do not close #1781 or merge the stack yet.

This improves live Codex evidence only. The 13-step clean installed-app journey
still lacks real onboarding plus native-picker acceptance in one run, and
screen-reader/platform/performance gates, provider approval/deny variants,
residual journal TOCTOU/platform security, and World visual acceptance remain
open. The density-only World experiment did not materially improve the
rectangular scene edge in packaged captures and was discarded; do not integrate
it or repeat the same experiment. Focus, exact-head CI, and restart acceptance
remain ahead of another art-only sequence.

## 52. Continuation checkpoint — main integration observed and verified

GitHub moved during the acceptance run. PR #1782 merged to `main` as merge
commit `a63db4a58704de11c9924cf4b9b34e808abbd116` (PR head
`63b35901eddd786b393a565abea1faaaf5240b71`). Its exact-head `gates`,
packaged fresh-HOME acceptance, Linux/Windows/macOS Electron package jobs,
CodeQL, compiler checks, and completed platform checks passed. PR #1781 was
then reported merged with its existing head `80765a86abe7064684f3ac710afa23142a9cdb1d`;
that head and #1782's merge commit are both ancestors of the fetched main. No
commit was rewritten by this integration work. The owner performed those GitHub
merges; this session verified their state and preserved them.

Fetched `origin/main` at `a63db4a5` and merged it normally into
`rescue/codex-product-integration`; it applied without conflicts and retained
the rescue branch's authored history and evidence. Exact-main workflows are
still running: `desktop` and `Clean-machine Desktop Acceptance` are in
progress, `Validate` is queued, and CodeQL/MegaLinter have passed. Do not call
the new main head green until its exact workflows finish. No release was
published by this session.

PR #1783 was automatically retargeted to `main` after #1782 merged. Its current
head is `b92560663a5c437e48c1d51c77fe697de8c18e32`; fresh-host `gates` and
clean-profile acceptance are in progress, most fast validation is green, and
macOS checks/package jobs remain queued or running. The earlier `76b204cb`
results are historical only. Keep #1783 draft and unmerged until its exact-head
workflows finish and the full integration review is complete.

## 53. Continuation checkpoint — accessibility and ImgBot evidence review

Ran the packaged Electron `keyboard-a11y.spec.ts` and `responsive-layout.spec.ts`
against the local Linux x64 package built from source `76b204cb`; all 5 tests
passed. This exercises keyboard-only skip-link and focus-ring behavior, Tab
reachability, keyboard destination activation, reduced-motion CSS, nested
Escape/palette precedence, and the real window at 1280×800, 1024×768, and
1024×640 (including Focus, People, Library, and command palette); the responsive
suite also passed at device scale factor 2. Opened the packaged screenshots:
Focus fits and keeps the primary action visible at 1024×640; the Dusk World
fits at 1024×768 but still shows the unresolved hard rectangular terrain slab,
dense foliage, and substantial empty vertical surround. This is not a
screen-reader, contrast-matrix, or full-visual sign-off. Orca is not installed
on this host.

Reviewed exact ImgBot PR #1771 head `9236a610510bc4637939c56db4071e0a2392cf8e`
against current main. `gates` fails because the optimized PXL outputs
`preview/lamp-glow` and `preview/water` violate `pnpm check:world`. A local
decoded-pixel comparison also found five of the changed `gate0-codex-*` captures
had real content changes. The World screenshot drops several landmarks and
project houses; the relaunch-history screenshot changes two sessions to one.
These edits are not explained by the compression-only PR description. The
other listed image changes include pixel-identical files, but that does not
remedy the generated-output drift or unexplained evidence changes. Submitted a
`CHANGES_REQUESTED` review asking for regenerated previews and either
pixel-exact screenshots or reviewed, sourced replacements. PR #1771 remains
open and unmerged; preserve the bot's commit history and re-review only after a
new exact head is available.

At this checkpoint, PR #1783 exact head `b9256066` remains based on `main` with
`gates` and clean-profile packaged acceptance in progress; Linux/Windows
package work is running, and macOS checks are queued. Exact `main` head
`a63db4a5` still has `desktop` and clean-machine acceptance running and
`Validate` queued. Re-poll these exact heads; no failure is visible, but neither
matrix is complete.

## 54. Continuation checkpoint — CI-built Linux package live acceptance

Downloaded Linux x64 AppImage artifact `14031169023` from Release run
`43414288062`, built for exact PR #1783 head
`b92560663a5c437e48c1d51c77fe697de8c18e32`. The real Codex packaged journey
passed 1/1 in 1.3 minutes against this CI artifact on isolated X11. Unlike the
earlier local-package evidence in section 51, this package includes the backend
built by CI's pinned production toolchain. AppImage SHA-256 is
`27ad2e713800bda7aef5fc6ab32b5e755af1b15bf15c61c30c5e11cf46810219`;
`app.asar` SHA is
`8c5166732343459c1d2fb65edaadee7de30f935221b00384694daa44397aa08e`, backend
SHA is `7ba7d32f3c01a80f1a2742673ae4381e2d02c7d728eff6541476f3abb8aaa900`,
and packaged backend version reports `1.49.0`. Full evidence and remaining
limits are in [LIVE_ACCEPTANCE_2026-11-12.md](audits/LIVE_ACCEPTANCE_2026-11-12.md).

The live journey again proved actual Codex work, visible file diff, embedded
terminal use, safe interruption, Electron process restart/history recovery, and
World ↔ Focus project/thread continuity. Repository linking used the test
directory-picker stub; the app profile, workspace, and Git repository were
disposable. This does not establish full onboarding with the real OS picker,
screen-reader acceptance, cross-platform live-provider use, or every provider
approval/resume behavior.

At the latest exact-head poll, PR #1783's `gates`, clean-HOME package
acceptance, CodeQL, quality, and Ubuntu x64/ARM plus Windows packaging passed.
macOS package, linkage, integration, and platform validation jobs remained
pending. Exact main `a63db4a5` had `desktop`, CodeQL, and MegaLinter passing,
while `Validate` remained queued. Keep PR #1783 draft; re-poll exact heads before
integration or release decisions.

## 55. Continuation checkpoint — current state after CI artifact validation

Re-polled PR #1783 exact head `b92560663a5c437e48c1d51c77fe697de8c18e32`.
`gates`, `desktop`, clean-HOME packaged acceptance, CodeQL, web/quality, V
parity, and the completed Ubuntu/Linux ARM/Windows package jobs pass. The
remaining visible pending work is macOS: Electron packages for macOS ARM/Intel,
macOS linkage/integration, Python matrix, Node 24, and swarm e2e. Release run
`43414288062` is still in progress; Validate run `43414288013` is queued. These
are live at this checkpoint; re-query before relying on them.

PR #1783 is OPEN/draft, targets `main`, and has no review decision. Do not merge
or publish. The owner merged #1782 and #1781 into `main`; current main was last
verified at `a63db4a5` and its Validate workflow was queued even though desktop,
CodeQL, and MegaLinter passed. #1771 remains the only other open PR and has
requested changes. P0 #1777 remains OPEN: its title is “reject symlinked Focus
journal paths before reading, writing or deleting”; #1779's symlink/no-follow
mitigations do not eliminate the documented lstat/open and remove TOCTOU races
or prove macOS/Windows safety.

The integration documentation branch is pushed through `48cac41e`.
`worktrees/desktop-owner` and `worktrees/desktop-followup` resolve to the paths
and heads listed in section 2. A fresh `git worktree list` also found legacy
worktrees for accessibility, Gemini resume, Git hunks, docs, PXL and web tasks,
plus a prunable `/tmp/at-main`; do not delete or integrate these from names
alone. Inspect their remote PR/issue relationships and dirty state before any
cleanup or cherry-pick. The old status table in section 2 is retained as a
historical inventory; the “Current continuation state” block above is the
operational source of truth.

Next work must continue beyond documentation: finish exact-head macOS CI and
review #1783; close live-app gaps with the installed package; prioritize a
security-reviewed resolution for #1777 that preserves existing journals
through a nondestructive migration; then improve World boundary/creek
composition and broaden provider/accessibility acceptance. Do not call the
rescue complete while any of these product/acceptance gaps remain.

## 56. Continuation checkpoint — packaged visual tour and live Focus review

**Current date: 2026-11-13.** The preceding PR #1783 head `b9256066` completed
all visible required checks: Desktop gates, clean-HOME package acceptance,
quality, CodeQL, Validate (including macOS), and Linux x64/ARM, Windows, macOS
ARM and macOS Intel packaging/linkage. This does not apply to the new head.

The packaged Electron screenshot tour passed 1/1 for ten destinations (World,
Focus, Attention, Operations, Projects, Library, People, Insights, Terminal and
Settings), both Meadow and Dusk, and 1024×640, 1440×900 and 1920×1080. It left
60 destination screenshots plus People create/import captures under the
workspace-private `.audit-private/rescue-tour/`. Review them locally; do not
commit or publish these captures. The compact layouts remain navigable. People
is coherent, Operations reports real backend jobs and the dock runs a real PTY.
The expanded terminal dock consumes useful vertical space at 1024×640. At
1920×1080 the World still leaves large uniform meadow margins, and the creek
still reads like a narrow canal.

The local World change removes the Meadow-only gradients painted inside the
camera-transformed map rectangle. Perimeter grass now converges on `grass-0`,
the same tile used by the viewport ground, and the tiled background follows
camera pan. This removes the hard tinted slab in real packaged captures but
does not solve the oversized empty surround. The interior capture originally
landed during the 280ms doorway transition and live-data load; that image was
rejected. The current acceptance waits for live details and the transition.

The packaged Codex acceptance was rerun with a disposable HOME, workspace and
Git repository, and the installed authenticated Codex account exposed through
`CODEX_HOME`. It passed 1/1 in about 1.6 minutes: a real task created the exact
file, Focus showed its conversation and untracked state, the PTY ran in the
repository, Stop recorded an interruption without changing the file, app
restart recovered the thread, and a follow-up read the file. World → project
interior → Focus retained the project and thread. The acceptance can save these
actual states through `ATK_CAPTURE_DIR`; private screenshots are under
`.audit-private/live-codex-acceptance/` (completed Focus at 1024×640 and
1440×900, interrupted Focus with the PTY, recovered conversation and clean
project interior). No credentials or provider traces are committed. This does
not prove all providers, approval/denial variants, native OS pickers, or
cross-platform live-provider journeys.

Product worktree `worktrees/desktop-followup`, branch
`rescue/desktop-continuity-focus`, has commit
`66805d85963a957f0b3d3adf58bfdb779ec7dfb4` pushed to PR #1783. It removes the
rectangular World tint, aligns the edge with the continuing grass background,
adds a deterministic perimeter regression test, and saves real Codex review
screenshots from the acceptance gate. Local checks passed: 621/621 Vitest,
45/45 runtime-spike tests, TypeScript, ESLint, Prettier and `git diff --check`.
The packaged visual tour and real Codex acceptance passed on the local
unpacked Linux package. Its staged backend is the existing local 1.49.0
binary, not freshly compiled with CI's pinned toolchain; use section 54 for
pinned-backend package evidence.

PR #1783 is OPEN/draft, targets `main`, and has no review decision. Its exact
head `66805d85963a957f0b3d3adf58bfdb779ec7dfb4` now has all visible checks
passing, including required gates, clean-HOME packaged acceptance, CodeQL,
quality, Python/Node matrices, swarm e2e, and Linux x64/ARM, Windows, macOS ARM
and Intel packaging/linkage. This evidence applies to this SHA only; do not
merge or publish while the PR remains draft and unreviewed.

P0 #1777 remains OPEN. PR #1779 is merged and rejects many symlink cases with
`O_NOFOLLOW` file opens. Follow-up PR #1784 proposes app-owned storage and a
nondestructive migration; its CI and security review are pending. The one-time
legacy import still traverses a user-writable workspace with portable path
checks; ancestor replacement races during that read-only copy are not proven
race-free. macOS/Windows junction and reparse-point behavior is also
unverified. Do not call the journal safe or close #1777 until these residuals
and CI/platform evidence have been reviewed.

Resume in this order:

1. Poll exact-head CI for #1784 at
   `f8090484e445a903697933c0a622f3855c59cb92`; investigate failures and leave
   #1784 and #1783 draft pending review.
2. Resolve #1777 with a reviewed trust boundary, migration/downgrade behavior,
   hard-link/race coverage, and Windows junction/macOS validation. Preserve
   old journals; do not close the issue based only on unit tests.
3. Continue rendered iteration from `.audit-private/rescue-tour/` and
   `.audit-private/live-codex-acceptance/`: improve the World panorama and
   organic creek, then compact Focus/dock density. Reinspect all three required
   window sizes after each visual change.
4. Run packaged first-run onboarding with a real OS picker where available,
   provider approval/denial and recovery variants, screen-reader/contrast
   review (Orca was unavailable on the last recorded host), and the broader
   installed-app journey. Keep credentials out of fixtures and traces.
5. Recheck main, PR #1771 (still `CHANGES_REQUESTED` pending governed preview
   regeneration and pixel/content review), and legacy worktrees. Inspect remote
   PR/issue links and dirty state before integrating or cleaning any worktree.

The docs worktree is `/home/ulisesjcf/.ai-workspace/worktrees/desktop-owner`
on `rescue/codex-product-integration`; the product worktree is
`/home/ulisesjcf/.ai-workspace/worktrees/desktop-followup` on
`rescue/desktop-continuity-focus`. This is a checkpoint, not mission completion.
Keep the rescue active.

## 57. Continuation checkpoint — private Focus journal implementation

**Current date: 2026-11-13.** Implemented the app-owned journal direction in
worktree `worktrees/focus-journal-security`, branch
`fix/focus-journal-private-root`, commit
`f8090484e445a903697933c0a622f3855c59cb92`. Draft PR #1784 is open against
`main`: <https://github.com/ulises-jeremias/agent-toolkit/pull/1784>. It is
linked to #1777 without auto-closing it. All GitHub checks were pending at the
first poll; query this exact SHA before relying on CI.

Production Focus journals now live in Electron `userData/focus-journals`,
keyed by SHA-256 of the canonical workspace path. Existing workspace journals
are copied once into per-thread staged directories with atomic rename; metadata
and event log bytes are preserved exactly, and workspace sources remain
untouched. A migration marker makes subsequent sessions use app storage only.
Private POSIX modes, no-follow leaf opens where supported, hard-link checks,
static symlink checks and failed/incomplete migration handling are covered.
ADR-045 records the architecture and limitations; ADR-044 points to it.

Local verification on this branch: the full Desktop suite previously passed
589 Vitest plus 45 runtime tests; after the final migration hardening, the
focused journal suite passed 32/32, TypeScript passed, ESLint passed, Prettier
passed, and `git diff --check` passed. A Linux Electron package built
successfully. Packaged World navigation and opening a linked project into
Focus passed 2/2 with the real backend. The real Codex acceptance was attempted
against this branch's main-based package but initially did not start a provider
turn: that base reports “Codex 0.168.0 Detected. Sessions here are not available
for it yet.” Authentication was valid. A separate packaged Git test using the
old local `/usr/bin/agent-toolkit` returned an empty untracked diff. These were
backend-version mismatches, not product failures. The source-compatible CI
backend artifact for exact #1783 head `66805d85` returned the expected
`+field notes` diff and its packaged Project Changes journey passed 1/1.

For integrated validation, a disposable worktree at #1783 `66805d85` received
the private-journal commit via local cherry-pick (`860ba281`); no branch was
pushed or product PR modified by this test. A local Linux Electron package was
built from that renderer/main source, with the matching CI backend extracted
from run `43423177014` (backend SHA-256
`98340dbd91934df45ed3f2523735d5941a0b9c67f0d7e444d699ff9966b2a8e4`). The
installed authenticated Codex acceptance passed 1/1 in 1.6 minutes: exact file
creation, real Project Changes diff, terminal, safe Stop, app restart and
thread/history recovery, follow-up file read, and World/project/Focus context
continuity. Private screenshots are under
`.audit-private/focus-security-integrated-final/` (completed Focus at 1024×640
and 1440×900, interrupted and recovered conversation, and project interior).
This validates the combined behavior on Linux, not macOS/Windows security or
provider parity.

Keep #1777 open and #1784 draft. The migration's legacy reads use portable
path checks but are not proven immune to ancestor replacement races; the copy
does not write to or delete workspace paths. Windows junction/reparse-point
and macOS behavior are unverified. Downgrading shows pre-migration workspace
history only; new app-storage threads remain in Electron `userData`, and any
legacy threads created by the older app after downgrade are not automatically
reimported because the marker is one-time. Keep both stores and do not describe
downgrade as seamless. Resolve these limitations through security review and
cross-platform evidence before marking #1777 fixed.

At this checkpoint, poll #1784 exact-head CI and obtain security/platform
review; resolve the legacy-import race and Windows junction/macOS guarantee
questions before any merge or #1777 closure. Continue the World panorama/creek
iteration, compact Focus/dock density, and remaining accessibility/onboarding/
provider acceptance gaps in section 56. Keep the overall rescue active.

## 58. Continuation checkpoint — combined provider acceptance and Git diff regression

**Current date: 2026-11-13.** The product PR now includes commit
`e0f6af7cf6abbb1179f12c8738b7c469ab5fa325` on branch
`rescue/desktop-continuity-focus`, adding a GUI assertion that an untracked
text file's diff is reviewable before staging. This was first verified in a
packaged integration worktree against the CI backend artifact, then against the
packaged product branch using that same exact backend: `project-changes.spec`
passed 1/1. The branch push restarted CI for #1783; at the first poll, many jobs
were in progress/queued and none had failed. Recheck exact head `e0f6af7c`.

Root cause of an apparent diff regression: the host `/usr/bin/agent-toolkit`
was version `1.49.0` but stale relative to current source. Its API returned
`{"ok":true,"diff":""}` for a textual untracked file. The packaged artifact
from PR #1783 run `43423177014` (head `66805d85`) contains the source-compatible
backend; its SHA-256 is
`98340dbd91934df45ed3f2523735d5941a0b9c67f0d7e444d699ff9966b2a8e4` and it
returned the expected unified diff. This binary was used only in private local
packages; no artifact or package was committed.

The full live Codex acceptance passed 1/1 (1.6m) with a packaged Linux
integration build combining product head `66805d85`, private-journal cherry-pick
`860ba281`, and the matching CI backend above. It created the exact requested
file, exposed the real Git diff, used the PTY, stopped without changing the
file, restarted Electron, recovered the conversation, completed a read-only
follow-up, and preserved project/session context through World and back to
Focus. Captures remain private in `.audit-private/focus-security-integrated-final/`.
The temporary worktree was not pushed; PR #1783 received only the separate
untracked-diff regression test commit `e0f6af7c`.

PR #1784 remains OPEN/draft at `f8090484e445a903697933c0a622f3855c59cb92`.
At the latest poll, the remaining visible jobs were macOS Intel packaging,
clean-HOME packaged acceptance, and `gates` (with Required CI queued); the
other platform/package, integration, quality, security, and matrix jobs passed.
Re-poll before relying on this state. PR #1777 remains open because the
legacy-import ancestor race and Windows/macOS reparse-point guarantees have
not received a disposition.

Local V compilation was attempted only after checking no other V process was
running, under the workspace's 2 GiB/no-swap cap. The available
`/home/ulisesjcf/vlang-master/v` was `ea5156d`, not CI's `c0e47bf`; its C build
failed on V/VC incompatibility and the old fallback compiler lacked an internal
flag. No V source/toolchain checkout was modified. CI's exact backend artifact
was used for package validation instead. Do not claim this local host built a
fresh pinned backend.

## 59. Continuation checkpoint — migration recovery review fix

**Current date: 2026-11-13.** Independent security review of PR #1784 found
that migration recovery accepted an existing private thread directory whenever
its metadata parsed, even if its event log was absent or differed from the
legacy source. Since `ThreadJournal.open()` allows a missing event log, an
interruption after metadata creation could cause migration to mark itself done
and leave older events inaccessible in the private store.

Commit `34123019586ecc3c30b5de63a4c9f6f0dc50f153` on
`fix/focus-journal-private-root` fixes this: before resuming an existing
destination, migration validates both metadata and optional event-log bytes
against the legacy source. A mismatch aborts without writing the completion
marker or modifying the legacy copy. The regression test recreates a
metadata-only destination, proves migration fails, confirms the source event
bytes remain intact, and confirms no marker is written.

Validation after this fix: Focus journal/service suite 32/32, Desktop
`pnpm type-check`, full `pnpm lint`, Prettier check, and `git diff --check`
passed. The Electron targeted ESLint invocation alone ignores `electron/` by
repository configuration, so the full lint command was used. The commit was
pushed to PR #1784. Exact-head CI had started; many jobs were queued and the
Python 3.14 Ubuntu job was running at the first post-push poll. Recheck all
checks against this exact SHA before relying on them.

The review also confirms an unresolved platform race: where Node does not
provide `O_NOFOLLOW`, a same-user concurrent process may replace a checked path
component between `lstat` and file open. Private `userData` narrows exposure for
the destination, but legacy sources remain in a workspace that other local
processes can write. Static symlink checks do not prove race safety, and
Windows junction/reparse-point plus macOS behavior have not been independently
validated. Keep #1777 open and #1784 draft until a platform-specific mitigation
or a documented, reviewed trust boundary is established. Do not imply this
commit resolves that issue.

The accepted packaged Linux Codex journey from section 58 remains evidence for
the integrated behavior before this migration-only recovery fix; it did not
exercise partial migration recovery or validate platform-specific race
resistance. The user's overall desktop rescue is still active. Continue with
the remaining World visual iteration, compact Focus density, onboarding,
accessibility, provider and multi-platform acceptance gaps in section 56, and
keep checking the open rescue PRs and worktrees before integrating additional
changes.

## 60. Continuation checkpoint — creek bank art iteration

**Current date: 2026-11-13.** Packaged screenshots from section 56 showed why
the Hornero creek read as a canal: the center stream was only one terrain tile
wide, but each adjacent `water-edge-e/w` sprite was almost entirely filled
with water. The visible channel therefore occupied about three tiles, with
nearly straight parallel edges.

Commit `536810d8` on `rescue/desktop-continuity-focus` re-authors the governed
PXL east/west shore sprites as meadow tiles with an irregular shallow-water
lip. North/south shore variants received matching treatment to keep the sprite
family coherent. All generated PNGs and three owned manifests were regenerated
through `gen-world-assets-pxl.mjs`; no unrelated art or generator was changed.

Validation: PXL generation and byte-for-byte `--check` passed for all 207
sprites; World model and terrain renderer tests passed 60/60; `pnpm dist:dir`
produced a Linux unpacked Electron app using the verified CI backend artifact
from #1783. The actual packaged app capture journey passed 1/1 across Meadow
and Dusk at 1024×640, 1440×900, and 1920×1080. The screenshots are kept
privately in `.audit-private/creek-iteration-1/` and were visually inspected:
the channel now reads as a shallower stream, with bank texture visible at
compact and large sizes. These captures validate Linux only.

The full Prettier check for the PXL JavaScript source reports that file's
existing compact DSL formatting as non-Prettier; generated JSON manifests pass
Prettier and `git diff --check` passes. Do not claim PXL source formatting was
validated with Prettier. PR #1783 received commit `536810d8` and remains draft;
recheck CI against the new exact head `536810d8` before relying on the earlier
head's results.

This improves the creek's bank silhouette but does not complete the World
renaissance. The overall valley still needs an authored composition critique,
the broad meadow margins need further evaluation at 1920×1080, and the full
acceptance matrix and accessibility work remain open. Continue with section
56's other priorities after checking both open PRs and their exact-head CI.

## 61. Continuation checkpoint — packaged onboarding and current review state

**Current date: 2026-11-13.** After the creek art commit, the packaged Linux
Electron app was run through the existing `onboarding.spec.ts` first-run suite
against the source-compatible CI backend artifact. All 3 tests passed in 1.1
minutes: existing workspace setup and repository linking, explicit creation of
a missing workspace, and recovery after killing/restarting the supervised
backend. The repository picker was stubbed at Electron's native-dialog seam;
the subsequent renderer/API flow was real. The suite's fixture creates a
repository-shaped folder for linking, so this is not proof of the mission's
mandatory clean-profile journey with a populated real Git repository and a
live authenticated provider.

GitHub state was rechecked. #1773 (external repository registration) and #1774
(true first-run UI regression) are both MERGED on 2026-11-12. Their former
dependency is no longer open, though #1774's own description says Gate 0 still
needs a packaged field trial plus D08–D10 and platform/viewport evidence.
Do not equate merged regression coverage with gate acceptance.

PR #1771 remains OPEN, not draft, at ImgBot commit
`9236a610510bc4637939c56db4071e0a2392cf8e`, with review decision
`CHANGES_REQUESTED` and merge state `DIRTY`. The review requires the two
governed Desktop PXL previews (`lamp-glow` and `water`) to be regenerated from
source and five changed Gate 0 screenshots to be restored pixel-exactly or
replaced with reviewed, reproducible captures whose changed state is explained.
The branch's only commit is the bot's image optimization; do not discard it or
rewrite it. Its local worktree `worktrees/fix-1751` is clean, but the PR is
based on a main commit that is no longer an ancestor of local `origin/main`.
Before changing it, plan a history-preserving rebase/cherry-pick and compare the
current main assets. Keep the PR unmerged while governed assets and acceptance
evidence disagree.

PR #1783 is OPEN/draft at
`536810d8e4ad1cc3375e9f5a6531a0c7d259b20d`; its exact-head CI had 9 successful,
8 in progress, and 8 queued check runs at the last poll. PR #1784 is OPEN/draft
at `34123019586ecc3c30b5de63a4c9f6f0dc50f153`; it had 15 successful, 4 in
progress, and 5 queued runs. Neither has a review decision. Re-poll exact heads
and inspect failures before any integration.

The primary `repos/agent-toolkit` checkout is dirty with release/version and
plugin metadata changes plus untracked files; these are not part of this
rescue. Do not clean, reset, or stage them. Numerous older worktrees remain
active, including Valley art, Desktop UI, provider/session and World branches;
continue inspecting worktree and branch ownership before touching them. The
rescue remains active and section 56's security, visual and accessibility
priorities still apply.

## 62. Continuation checkpoint — packaged keyboard and motion QA

The packaged Linux Electron app also passed the keyboard/reduced-motion
acceptance after a test-readiness fix. An initial full-file run intermittently
sent Tab and `?` after backend health but before the Focus heading, provider
state and navigation had mounted; the isolated test passed while the suite
could fail. Commit `94883a39` on the product branch makes the affected tests
wait for those user-visible readiness signals before exercising input. The
full packaged keyboard suite then passed 3/3: skip link and destination Tab
reachability with visible focus rings, reduced-motion preference, and keyboard
shortcut map plus nested Escape behavior. The test changes do not relax any
assertions. ESLint, Prettier and `git diff --check` passed for the changed spec.

The product PR now points to exact head
`94883a39aeafa62015073fb3fb945b956bc2c553`; new CI had just started (one
success and one neutral result, with the rest not yet reported at the first
poll). Recheck this exact SHA. PR #1784 remains at
`34123019586ecc3c30b5de63a4c9f6f0dc50f153` with 17 successful, 2 in progress,
and 5 queued jobs at the same poll. No failure was reported; both PRs remain
draft and require full exact-head checks and human review.

This verifies keyboard interactions and CSS reduced motion in Linux Electron.
It does not substitute for Orca/screen-reader testing, contrast measurements,
Windows/macOS keyboard checks, live-region announcement review, or the full
mission acceptance scenario with a real repository and provider. None of
those gates is closed.
