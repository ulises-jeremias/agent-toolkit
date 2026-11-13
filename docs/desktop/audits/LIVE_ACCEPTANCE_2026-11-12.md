# Packaged Desktop live acceptance — 2026-11-12

This is partial installed-app evidence for the rescue mission, not a release sign-off.
The mandatory journey is still open because repository registration through the native
picker, Codex live use, full visual coverage, a cancel-during-mutation check, accessibility,
performance, and non-Linux platforms remain unverified.

## Exact environment and artifact

- Host: Arch Linux x86_64, kernel `7.2.14-arch1-1`.
- Node: `v22.22.0`.
- App: Agent Toolkit Desktop `1.49.0`, Electron `44.11.0`, Linux x64 unpacked package at
  `/home/ulisesjcf/.ai-workspace/.audit-private/package-codex/linux-unpacked`.
- Electron app payload SHA-256 (`resources/app.asar`):
  `cf3f3935f8f01919ecd7057c8afb0de065bb7b67eb7ea75939e6cd75ebe81e8e`.
- Backend SHA-256 (`resources/bin/agent-toolkit`):
  `a74f1cc8117a0e40372d4364d0c1fd5bd481b6e12c7f7378bb608495dd14a3d2`.
- Source integration HEAD: `8a753ec5445b5cc4eff40b593e57fa7ce7f669ef` plus dirty, uncommitted
  integration edits. The backend binary is the existing build from rescue commit `0c730540`;
  it has no fresh-build provenance from this integration tree. The exact pinned V toolchain
  could not be compiled under the host's 2 GiB / no-swap requirement (details in the handoff).
- Providers: Claude Code `2.1.322`, authenticated to a Claude Pro subscription, and
  Codex `0.167.2`, authenticated to ChatGPT. Both performed separate live tasks in
  separate disposable repositories. OpenCode `2.2.7` was detected and shown as
  unsupported for Focus sessions.
- Electron userData, XDG paths, workspace, and repository were isolated under
  `.audit-private`; provider authentication was discovered through the user's existing
  provider installation. No credentials or private provider traces were copied into the
  fixture or repository.

## Observed journey

| Step | Result | Evidence |
|---|---|---|
| Launch with clean Electron profile | Pass | Packaged application showed onboarding; provider authentication was separately discovered from the real local provider configuration. |
| Create workspace through onboarding UI | Pass | “Create workspace folder” created the isolated workspace. |
| Register existing Git repository through UI | Open | A disposable repository outside the workspace was registered through the CLI before the task. The Projects “Link a repository” UI was opened, but the native OS directory picker cannot be driven in headless mode. |
| Discover authenticated provider | Pass | Focus displayed Claude Pro and ChatGPT account status; no credentials were exposed. |
| Start coding task | Pass | Real Claude Code session in packaged Focus, using “Ask before changes”. |
| Observe structured work | Pass | Transcript showed assistant messages, tool calls, test output, approval state and provider completion. |
| Inspect actual changes | Pass | Independently checked Git status and `git diff`; UI Changes inspector displayed the exact `src/math.js` one-line diff and `test/` untracked. |
| Use project terminal | Pass | Integrated terminal ran real `/usr/bin/zsh`; `pwd` matched the disposable repo and `git status --short` matched the actual tree. |
| Intervene safely | Pass, partial | Two reviewed tool requests were approved with “Allow once”. Tests first failed against the bug, then passed after the one-line fix. Live cancel/deny during mutation remains untested. |
| Close/reopen same packaged app/profile | Pass | Same isolated `userData` and workspace reopened the completed thread, project, transcript, provider state and diff. |
| Resume behavior | Pass for completed task | The task had completed before close, so durable history was restored. No in-flight continuation was claimed. |
| Project history | Pass | Thread remained in Focus history after restart and its transcript could be reopened. |
| World context and return | Pass, with interaction gap | World showed the linked project and “0 sessions working”; Focus showed the same thread in its list and selecting it restored the full transcript. World → Focus did not automatically reselect the thread. |

A separate real Codex task used the newly packaged Codex adapter in `ui-link-repo-CniQrH`:
implement `greet(name)` and two `node:test` cases without dependencies or package metadata
changes. Codex inspected the repository, requested approval to write the two files, and was
approved once. Its initial shell write reported the host disk quota and left empty files;
Codex recognized the failure, rewrote both files through its patch tool, and reran
`node --test` successfully. Independent inspection found only `src/greeting.cjs` and
`test/greeting.test.cjs`, and independent `node --test` passed 2/2. This validates real Codex
session startup, approval, file changes, recovery after a tool failure, and test execution;
it does not establish parity for every Codex approval type, cancellation, resume, or child
agent behavior. The initial failed write remains visible as an honest tool failure in the
conversation and did not modify other files.

The disposable task was: change `src/math.js` so `add(a, b)` returns a sum, and add five
`node:test` cases for positive, negative, mixed-sign, and zero inputs without other files or
dependencies. Claude first added only the tests. They exposed four failures against the
original subtraction bug (zero plus zero passed by coincidence). After “Allow once” for the
test write, Claude proposed the one-line source correction; after a second “Allow once”, all
five tests passed. Independent `npm test`, `git diff --check`, Git status, and the rendered
diff confirmed that only `src/math.js` and `test/math.test.js` changed. The fixture was not
committed.

## Verification

- `pnpm --filter agent-toolkit-desktop type-check` — passed.
- Focused changed-area Vitest run — 6 files / 52 tests passed.
- Full Desktop `pnpm test` — 78 Vitest files / 597 tests and 45 Node runtime tests passed.
- `pnpm --filter agent-toolkit-desktop build:all` — passed. Vite still reports the 670.60 kB
  main chunk and a config-loader deprecation notice.
- `electron-builder --dir` — produced the exact Linux x64 package above.
- `git diff --check` — passed.
- After adding bounded Codex RPC deadlines, the full suite passed at 78 Vitest files / 597
  tests and 45 Node runtime tests; the Codex protocol test file passed 8/8.
- Vitest initially failed to write under `/tmp` because of the host's temp quota. Re-running
  unchanged with `TMPDIR=/home/ulisesjcf/.ai-workspace/.audit-private/tmp` passed.

## Visual evidence and remaining limits

Screenshots are kept privately, not committed, under `.audit-private`:

- `packaged-headless-1ksWMh/onboarding-dusk-1024x640.png`
- `packaged-headless-1ksWMh/onboarding-dusk-1440x900.png`
- `packaged-headless-1ksWMh/onboarding-dusk-1920x1080.png`
- `packaged-headless-1ksWMh/onboarding-meadow-1024x640.png` (the attempted media override
  did not switch the app from Dusk, so this is not Meadow evidence)
- `final-focus-diff.png` (final package, 1024×640; real completed transcript and Git diff)
- `live-terminal-smoke.png`, `live-changes-review.png` (earlier live run; actual PTY and
  Changes panel)

The onboarding screen is readable at the three requested widths. Focus plus its inspector
works at 1024×640, though the narrower conversation area under the open diff panel needs
another visual pass. There is no full Meadow/Dusk × surface screenshot matrix, nor verified
keyboard-only, screen-reader, contrast, reduced-motion, startup/performance, macOS, or Windows
acceptance. Do not infer those gates from these screenshots or automated tests.

## Codex packaged re-verification — 2026-11-13

Repeated the opt-in `e2e/electron/codex-live-acceptance.spec.ts` against the Linux x64
unpacked Electron package built from source HEAD
`76b204cb1f168e40ea1c7e236c1c3e19420a61fd`. Package hashes:

- `resources/app.asar`: `850a87cba0017524eed4d17eeaeef1c4ff362e56c1bf189c694378fabee46690`.
- `resources/bin/agent-toolkit`: `39e048990b3d18910899066404de4af15a15a246e1b9b7f07d77636a81af5ded`.
- Codex CLI: `0.168.0`; Electron: `44.11.0`; Desktop package: `1.49.0`.

The test passed 1/1 in about 90 seconds. It used the installed Codex account through
`CODEX_HOME` while the app HOME, Electron profile, workspace, and Git repository were
temporary. The repository was registered through the Projects UI using a test stub for
the native directory picker, so the real window-manager picker remains unverified.
Codex created `live-result.txt` with the exact requested content, Focus showed the real
untracked-file diff, the embedded PTY ran inside the disposable repository, Stop
interrupted a second turn without changing the file, and a new Electron process recovered
the thread and completed a follow-up read of the same file. Focus → project World interior
→ Focus retained the project and thread.

The first attempt exposed a bad acceptance prompt: it demanded a “read-only tool” and
prohibited commands, so Codex correctly explained it had no such tool. The test now
requests the available command action (`cat live-result.txt`) and the full journey passed.
No provider credentials or traces were copied to the repository. This confirms the
packaged Codex journey on this host; it does not close Claude/OpenCode parity, native-picker,
in-flight resume guarantees, approval/deny variants, security/platform, accessibility, or
complete 13-step daily-driver acceptance.

## CI-produced packaged Codex acceptance — 2026-11-13

Repeated the real-provider journey against the Linux x64 AppImage produced by
Release workflow run `43414288062` for PR #1783 exact head
`b92560663a5c437e48c1d51c77fe697de8c18e32` (artifact `electron-linux-x86_64`,
ID `14031169023`). This closes the earlier provenance gap for the Linux backend:
this was the package from CI's pinned production toolchain, not the host
checkout's pre-existing `dist/agent-toolkit`.

- AppImage SHA-256: `27ad2e713800bda7aef5fc6ab32b5e755af1b15bf15c61c30c5e11cf46810219`.
- Extracted `resources/app.asar` SHA-256:
  `8c5166732343459c1d2fb65edaadee7de30f935221b00384694daa44397aa08e`.
- Packaged backend SHA-256:
  `7ba7d32f3c01a80f1a2742673ae4381e2d02c7d728eff6541476f3abb8aaa900`;
  `resources/backend-version.json` reports `1.49.0`.
- `e2e/electron/codex-live-acceptance.spec.ts` passed 1/1 in 1.3 minutes on
  isolated X11 (`:99`) with installed Codex CLI `0.168.0` and the existing
  authenticated `CODEX_HOME`. App HOME/profile/workspace/repository were
  temporary and cleaned after the test.

The result verifies UI repository linking (with the test directory-picker
stub), a real Codex-created file, Focus diff, embedded PTY, safe Stop, process
restart/history recovery, provider follow-up via `cat`, and Focus ↔ project World
context retention. This is Linux x64 package evidence only; the real OS picker,
screen reader, macOS/Windows live-provider use, and remaining acceptance gaps
stay open. The artifact remains in the ignored private audit directory and was
not committed.
