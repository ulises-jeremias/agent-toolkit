# Agent Toolkit Desktop rescue — execution handoff for GPT-6-Luna

Updated: 2026-11-12 (latest integration check). Requested by the owner to
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
HEAD at handoff: 8a753ec5
```

This worktree has IMPORTANT UNCOMMITTED changes. Inspect them before any checkout,
reset, rebase or cleanup. Do not recreate the implementation from scratch.

| Location / branch | State and handling |
|---|---|
| `repos/agent-toolkit`, `chore/release-v1.47.5` | Old checkout, unrelated dirty release/version/plugin files and `.claude/`. Preserve; do not use as current product source. |
| `worktrees/rescue`, `rescue/shell-v2`, `0c730540` | Existing PR #1780; replacement shell, onboarding, Focus, Projects/Context and new Valley. Preserved in integration branch. |
| `worktrees/desktop-owner`, `rescue/codex-product-integration` | Started from canonical main `3e08b51e`; local merge `dbbbcb57` preserves rescue commits. Protocol fix cherry-picked as `8a753ec5`. Nothing from this integration branch has been pushed. |
| `worktrees/codex-protocol`, `rescue/codex-protocol`, `2b8de6d6` | Reviewed protocol fix; already cherry-picked as `8a753ec5`. Do not apply twice. |
| `worktrees/workspace-continuity`, `rescue/workspace-continuity` | Uncommitted partial implementation by subagent; NOT reviewed, tested or integrated. See critical persistence flaw below. |
| `.claude/worktrees/agent-a8c96dfe4dfec7e8d`, `rescue/valley-art` | Existing art work; preserve. Do not infer an active agent from the worktree. |
| Old PXL/web/a11y/history worktrees | Inspect PR relationships before any cleanup. No cleanup was authorized as part of this handoff. |

All paths above are relative to `/home/ulisesjcf/.ai-workspace` unless absolute.
Run `git worktree list` again to detect changes after this snapshot.

### Uncommitted integration edits

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
- [ ] Make Focus the normal work entry; World is optional navigation, not a gate.

### P0 — Finish and verify the real Focus runtime

- [x] Review current dirty edits and run focused tests/type checking.
- [ ] Retain `8a753ec5`: thread/turn filtering, request-bound approval ownership,
  stale turn/start protection, visible unsupported requests, explicit user reviewer,
  failed-interrupt reporting and immediate forced process-group stop.
- [x] Add bounded 30-second Codex app-server request deadlines; clear pending timers
  on response, close, and disposal; surface timeout errors; and stop an unresponsive
  process after a failed handshake or turn/start request. Fake-server tests cover
  initialize timeout, turn/start timeout, forced disposal cleanup. The real-provider
  Codex journey remains open.
- [x] Keep Codex token usage honest: official app-server schema separates `last`
  and thread-cumulative `total`, and Codex describes `last` as active context size.
  Focus aggregates provider usage as per-turn spend, so Codex usage is now reported
  unavailable (`null`) until turn deltas can be derived safely. Regression coverage
  confirms neither context nor thread totals are mislabeled. Sources:
  [generated schema](https://github.com/openai/codex/blob/main/codex-rs/app-server-protocol/schema/json/v2/ThreadTokenUsageUpdatedNotification.json),
  [Codex TUI usage semantics](https://github.com/openai/codex/blob/main/codex-rs/tui/src/token_usage.rs).
- [ ] Verify approval scope truth (`availableDecisions`, network context, grantRoot,
  allow-once vs allow-session) against installed schema, not assumed dialects.
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
  commands below). A private pinned clone is prepared; an unrelated V smoke process
  was active, so the first bootstrap attempt was stopped before running V.
- [x] Rebuild renderer/main, stage the existing backend binary from rescue commit
  `0c730540`, and package `dist:dir` for Linux x64. No V source changes exist between
  that binary's source commit and this integration branch. This is a packaging
  smoke artifact, not acceptance of a newly compiled backend.
- [x] Launch the exact unpacked package and verify UI/backend with the same profile
  across a close/reopen. It returned to the completed Focus thread, provider discovery,
  project, transcript, approval/tool events, and diff.
- [ ] Use a clean Electron userData/profile and disposable Git repository. Keep
  real provider authentication separate; never copy credentials into fixtures.
- [ ] Drive the complete 13-step journey in section 9 from the UI. Workspace creation
  was through onboarding; the existing repo was initially registered by CLI, so UI
  registration/native picker remains open. Other live Focus, terminal, diff, restart,
  history, and World-context steps have been exercised.
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

- [ ] Critique the actual new Valley, not just the earlier 201-sprite set. Re-author assets
  if quality requires it; asset count is not a quality measure.
- [ ] Cozy original pixel world with coherent perspective, light, depth, composition,
  recognizable project buildings and meaningful Library/Archive/Workshop/Operations.
- [ ] Professional readable technical typography; pixel display type used sparingly.
- [ ] Real session-backed characters only. Decorative animals/weather never imply work.
- [ ] World is optional spatial context, not a compulsory avatar-walking interface.
- [ ] Every real action has normal navigation/keyboard access and shares canonical state.
- [ ] Preserve project/session context entering/leaving World/interiors.
- [ ] Restrained animations, reduced motion, efficient rendering and useful empty state.
- [ ] Multiple capture → open → critique → fix → recapture iterations before visual sign-off.
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
- [ ] #1773 external repo linking and #1774 true first-run are merged; preserve them.
- [ ] #1776 Claude runtime and #1779 journal hardening are merged; preserve them.
- [ ] Review #1780 against current code and the final architecture. Update its stale
  description or choose focused follow-up PRs; avoid duplicate giant salvage PRs.
- [ ] Review outstanding review threads/CI, not merely reported pass counts.
- [x] Push the continuity/runtime slice as draft [#1783](https://github.com/ulises-jeremias/agent-toolkit/pull/1783),
  stacked on [#1782](https://github.com/ulises-jeremias/agent-toolkit/pull/1782), which
  is itself stacked on #1781 and #1780; post verified acceptance status to
  [#1775](https://github.com/ulises-jeremias/agent-toolkit/issues/1775).
  #1780/#1781/#1782 have failing required Desktop gates; this draft remains unmerged
  pending a healthy, reviewed base. #1782 corrects stale shell smoke assertions
  (empty-state headings and the six-place rail) and disambiguates a project row from
  its toast. The failing desktop run is specifically four packaged Electron journeys,
  not those renderer smoke assertions: workspace context-pack discovery, two
  project-changes flows that cannot see the review dialog/path, and workspace
  switching that cannot see the linked path in that dialog. The standalone
  project-link journey passes, so trace these flows independently rather than
  assuming one global picker defect. Run IDs: desktop 43298967157; packaged
  43298966315.
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

## 9. Mandatory installed-app acceptance (all still open)

Use a disposable repository; record exact executable/hash, source commit plus dirty
state, backend version, provider version, OS, profile and sanitized evidence.

1. [ ] Open installed Desktop with clean user profile.
2. [ ] Create workspace through UI.
3. [ ] Register existing Git repository through UI (including outside workspace root).
4. [ ] Discover real authenticated provider; auth success is not quota success.
5. [ ] Start real coding task.
6. [ ] Observe messages, structured tool calls and true process state.
7. [ ] Inspect actual generated file changes and diff.
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
- Full visual matrix, performance pass, screen-reader/accessibility pass, actual Meadow
  capture, and macOS/Windows packaged acceptance remain open.
- Draft follow-up [PR #1783](https://github.com/ulises-jeremias/agent-toolkit/pull/1783)
  is pushed as `rescue/desktop-continuity-focus`, stacked on #1782's
  `fix/desktop-shell-smoke-navigation-20261112` branch (which carries #1781 and #1780).
  The owner-authored commits from #1781 and #1782 are preserved in branch history;
  PR base is retargeted to #1782. The acceptance update is posted to
  [mission #1775](https://github.com/ulises-jeremias/agent-toolkit/issues/1775).
  Its source quality and local Desktop tests pass. Latest hosted status has the
  required `gates` and packaged Electron jobs still in progress, as are several
  repository validation jobs; recheck before acting. It is intentionally unmerged
  while #1780/#1781/#1782 have failing required Desktop checks. No release was created.

## 11. How Luna should execute efficiently

1. Read this file, git status/diff, then only the source needed for the first P0 slice.
2. Do not re-export Muse, re-clone references or repeat broad audits without a reason.
3. Preserve dirty work and partial worktrees. Review before merging/cherry-picking.
4. Fix one integrated user journey at a time; do not let more artwork precede working
   Focus/restart acceptance again.
5. Keep changes reviewable, tests meaningful and evidence truthful. Re-run only when
   code changes/failures/new risks justify it.
6. Update this checklist and a short evidence entry after each slice, including the
   next exact action. Never mark a checkbox done from another agent's assertion alone.
7. Use bounded subagents only if useful and available; the active owner integrates
   and personally verifies results. Usage limits are not product completion.
8. Do not ask again for ordinary architectural/engineering permissions already granted.
9. The final success question is whether the owner can comfortably complete real
   development work in Desktop and enjoy it. Until that is demonstrated, keep the
   mission and relevant acceptance gates open.
