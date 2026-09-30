# Electron migration — rollback, status, and parity ledger

Canonical plan: [ADR-033](../adrs/ADR-033-electron-desktop.md). Design contract:
[DESIGN.md](DESIGN.md). Capability references (not visual authorities):
[WORKSTATION_REFERENCE_ANALYSIS.md](WORKSTATION_REFERENCE_ANALYSIS.md).
Template foundation: Create Awesome Node App
`react-vite-starter` (React 19, Vite 8, TS 6, ESLint + jsx-a11y + Prettier).

## Rollback (proven 2026-09-29, branch `feat/electron-desktop` base)

- Tag `v1.35.0` (`bd8e28c`) has an **empty tree diff** against `origin/main`
  (`19f87adb`, merge of PR #1308): `git diff --stat v1.35.0..origin/main`
  reports no changes, so the tag exactly preserves the native Desktop sources.
- `gh release view v1.35.0` is final with all 10 native desktop artifacts plus
  manifest/SBOM/SHA256.
- **Rollback = check out `v1.35.0` / reinstall its assets. No new tag needed;
  existing tags are never moved or rewritten.**

## Architecture (this branch)

- `apps/desktop/` — Electron + React workstation; one canonical
  `pnpm-lock.yaml` at repo root; `pnpm-workspace.yaml` declares
  `onlyBuiltDependencies` (electron, node-pty, unrs-resolver).
- V stays authoritative: every destination reads/mutates through
  `agent-toolkit serve` typed client (`src/lib/api.ts`, schema generated from
  `docs/surface/openapi.json` via `pnpm gen:api`).
- Electron main supervises `agent-toolkit serve --host 127.0.0.1 --port
  <dynamic> --no-browser` (health-gated, version-checked, crash-detected,
  clean shutdown). Terminals use node-pty in main as a transport adapter only.

## Default harness and runtime switch

Desktop's default harness is `~/.ai-workspace`, expanded with the OS home
directory. `electron/harness.ts` resolves it again on every backend start
(and after every Settings switch):

1. **override**: `AGENT_TOOLKIT_WORKSPACE`, then its alias `HARNESS_DIR`
   (the order core `find_workspace_root` uses, see
   [env-precedence.md](../compatibility/env-precedence.md)). Desktop expands
   `~` and relative paths and passes the absolute result to serve; core does
   not expand `~`. A value that is not a directory is skipped. While an
   override is set, Desktop refuses `atk:harness-set` / `choose` / `reset`.
2. **user**: the persisted Desktop choice in
   `<userData>/harness.json` (`current` + MRU `recent`, cap 8), if that
   path is still a directory. A vanished choice stays on disk (so it wins
   again when it returns) and the next tier is used for this start, with a
   notice.
3. **default**: `~/.ai-workspace`, if it is a directory.
4. **fallback**: the behavior from before this default existed. serve
   inherits the Desktop process cwd and resolves its workspace from there.
   This applies when an override is set but broken, or when the default is
   missing. Desktop never creates `~/.ai-workspace`, so Agent Toolkit stays
   usable without My AI Workspace.

For every source except `fallback`, serve is spawned with `cwd` set to the
harness and `AGENT_TOOLKIT_WORKSPACE` set to the same path. That keeps the
jobs dir, containment roots and `find_workspace_root` in agreement (see
[SERVE_API.md](../SERVE_API.md#workspace-rooting)). New terminal sessions
default their cwd to the same resolved harness (`TerminalService.defaultCwd`);
existing sessions keep the cwd they already report.

The resolution (`path`, `source`, `defaultPath`, `overrideVar`, `notice`)
travels on `BackendState.harness` through `atk:backend-status` and
`atk:backend-state`. Settings shows the harness, any notice, and the MRU
list; Office shows the harness on the backend line.

### IPC (`window.atk`)

| Channel | Bridge | Purpose |
|---|---|---|
| `atk:harness-status` | `harnessStatus()` | Current resolution, MRU, `switching`, `lockedBy` |
| `atk:harness-recent` | `harnessRecent()` | MRU entries with `exists` / `current` |
| `atk:harness-set` | `harnessSet(path)` | Validate (absolute or `~/…`, existing writable dir), persist, restart serve |
| `atk:harness-choose` | `harnessChoose()` | Native folder picker, then the same flow as `harnessSet` |
| `atk:harness-reset` | `harnessReset()` | Clear the Desktop choice; back to `~/.ai-workspace` (or fallback) |

A successful set/choose/reset restarts the supervised backend (stop → spawn
in the new cwd → health gate) unless the resolved path is unchanged. Types
live on `window.atk` (`apps/desktop/src/types/electron.d.ts`).

Known caveats: serve writes job logs to `<harness>/.agent-toolkit/server`,
so a harness that is a git repository should ignore `.agent-toolkit/`. A dev
backend with no embedded data and no XDG data can mistake a harness that has
`loops/` and `profiles/` for toolkit data, through core's cwd tier in
`find_toolkit_root`. Packaged and installed backends are unaffected because
they ship embedded data.

Verified 2026-09-30 in the Electron dev app (CDP recipe in
[WORKSTATION_REFERENCE_ANALYSIS.md](WORKSTATION_REFERENCE_ANALYSIS.md#appendix-b--capture-recipe-reusable),
no V rebuild):

- Default harness `~/.ai-workspace` (`source=default`); Settings shows
  **Change harness…**. Evidence:
  [settings-harness-switch.png](assets/electron/settings-harness-switch.png).
- `window.atk.harnessSet` to a temp folder returned `{ok:true, restarted:true,
  harness.source:'user'}`, persisted the MRU, and respawned serve in that
  cwd. Evidence:
  [settings-harness-switched.png](assets/electron/settings-harness-switched.png).
- New terminal form defaults cwd to the harness
  ([terminal-harness-cwd.png](assets/electron/terminal-harness-cwd.png)).
- Installed `~/.local/bin/agent-toolkit` 1.35.0 is selected from PATH and
  reported as `version-mismatch` / `desktop-gate-missing` (honest; not
  crashed). `/usr/bin/agent-toolkit` 1.16.0 is listed under Rejected
  binaries: `too old: has no serve command`.
- With PATH=`/usr/bin` only: `failed` / `binary-rejected` naming the stale
  binary. Evidence:
  [settings-backend-rejected.png](assets/electron/settings-backend-rejected.png).

Earlier default/fallback captures (2026-09-29):
[default](assets/electron/settings-harness-default.png),
[fallback](assets/electron/settings-harness-fallback.png).

## Backend binary resolution

`electron/backend-binary.ts` picks the `agent-toolkit` the supervisor
spawns, then probes it **before** `serve` starts. Order:

1. **`ATK_BACKEND_BIN`** — explicit, authoritative. A broken path does not
   fall through to PATH.
2. **bundled** — `<process.resourcesPath>/bin/agent-toolkit` in a packaged
   app. Also authoritative (a stale bundle must not silently run a foreign
   PATH binary).
3. **staged** — `apps/desktop/resources/bin` written by `pnpm stage:backend`
   (dev only).
4. **PATH** — every `agent-toolkit` on `PATH`, in PATH order, de-duplicated
   by realpath.

Each candidate must be an executable file, print a version from
`--version`, match the major pin (`ATK_EXPECTED_BACKEND_MAJOR` or
`resources/backend-version.json`), and answer `serve --help`. After health
passes, the supervisor also probes the `X-Atk-Desktop` first-party gate.

Honest `BackendState` (never a generic "crashed" for a selection failure):

| `status` | `problem` | Meaning |
|---|---|---|
| `failed` | `no-backend` | No candidate exists |
| `failed` | `binary-rejected` | Candidates exist; each rejection names path, source, version, and reason (`too old`, not executable, `--version` failed, major pin) |
| `failed` | `spawn-error` / `exited-during-start` / `health-timeout` / `port` | OS or startup failure after a binary was chosen |
| `version-mismatch` | `major-mismatch` | Healthy serve reports another major than the pin |
| `version-mismatch` | `desktop-gate-missing` | Healthy serve rejects Desktop mutations (403) |
| `crashed` | `exited` | Serve exited **after** it was ready |

Settings shows the selected binary, any rejected candidates, and the
problem code. The shell banner prefers `detail` over "Backend crashed".

## Live verification (2026-09-29, backend 1.35.0 @ 19f87ad + branch V fixes)

- `pnpm lint`, `pnpm type-check`, `pnpm test` (16/16), `pnpm build:all` green.
- V: `v test modules/agent_toolkit_server/` 4/4 with pinned V c0e47bf
  (includes new `test_is_first_party_mutation`).
- Playwright smoke 3/3 against a live backend: navigation, all destinations,
  terminal fallback outside Electron.
- Endpoint probe: read APIs, sub-proxies, jobs create/log, help all 200.
  `GET workspace/personas` and `GET memory/todo` return 405 (server read
  allowlist); the UI uses POST actions for those — no dead controls.
- Packaged app (`electron-builder --dir`, Linux, bundled backend 1.35.0):
  window boots with zero console errors, supervises its own backend on a
  dynamic localhost port, renders all 7 destinations, opens a real bash PTY
  with interactive echo round-trip, and creates a real job end-to-end
  (listed completed/exit 0 with persisted log).
- Screenshots (packaged artifact, CDP capture): [office](assets/electron/office.png),
  [operations job loop](assets/electron/operations-job.png),
  [live terminal](assets/electron/terminal-live.png).
- Named SSE events proven live in the packaged app: `status=running` →
  `status=completed` → `log` lines → `done=completed` delivered to named
  `EventSource` listeners for a real job.
- Backend crash/restart proven in the packaged app: `SIGKILL` on the
  supervised child flips the bridge to `crashed` with signal detail, the UI
  shows a "Backend crashed … Restart backend" banner plus per-panel Retry,
  and clicking Restart relaunches a fresh backend (`restarts` increments,
  new dynamic port, status returns to `ready`, UI recovers, no restart loop).
  Evidence: [crash banner](assets/electron/crash-banner.png).

## Packaging rule: rebuild the backend before `dist`

`stage-backend` copies `dist/agent-toolkit` verbatim. A packaged artifact
built from a stale binary silently ships old server behavior (observed: an
AppImage whose bundled backend predated the `X-Atk-Desktop` gate rejected
every first-party job POST with 403). Always rebuild first:

```sh
VMODULES=$PWD/modules v -prod -cc gcc -d "commit=$(git rev-parse --short HEAD)" \
  -o dist/agent-toolkit cmd/agent-toolkit
```

then `pnpm --filter agent-toolkit-desktop dist`. CI (`desktop.yml`) builds the
backend from source on every run, so release artifacts never go stale there.

## Backend strengthening backlog (land in V, never in TS workarounds)

1. Typed domain models beyond generic `{ok, message, data: string-map}`
   envelopes for catalog/skills/agents/receipts/evidence/budgets.
2. Read-classified GET subs for `workspace/personas`, `memory/todo`
   (currently POST-only via `is_read_subcommand`).
3. Job cancellation/delete endpoint (server exposes create/list/log/events).
4. V-owned PTY session API as a future alternative to the node-pty adapter.
5. `x-confirm-required` enforcement/negotiation (currently contract metadata).

## Landed during migration (branch `feat/electron-desktop`)

- **First-party Desktop mutations**: `X-Atk-Desktop: 1` header gate
  (`is_first_party_mutation`, tested in `server_security_test.v`) lets the
  Electron `file://` client POST on loopback while cross-site browser pages
  stay 403 and non-loopback origins stay rejected. Verified live:
  403 without header / 200 with header / 403 evil origin.
- **Top-level envelope normalizer**: V spreads data fields at the top level
  of command responses (no nested `data`); the TS client normalizes via
  `toEnvelope` (tested in `api.test.ts`). OpenAPI still describes the
  top-level shape — a future backend pass should document it per-endpoint.
- **Named SSE subscription**: the V jobs stream emits named events
  (`event: status/log/done`), which never reach `EventSource.onmessage` —
  the client's "Live output" was silently dead and masked by 2s log
  polling. `subscribeJobEvents` now registers named listeners via
  `namedJobStreamEvent` (tested in `api.test.ts`); the `done` exit code is
  0 for `completed`, 1 otherwise, with the authoritative code arriving via
  the `jobs` refetch on `done`.

## Native GUI functional coverage audit (2026-09-29)

`agent-toolkit serve` imports only `agent_toolkit_core` — no route handler
touches `modules/desktop/` facades or `modules/desktop_engine/`. The native
GUI (`cmd/agent-toolkit-desktop`, gg/sokol) renders typed engine views that
have no `serve` equivalent. Coverage per area:

| Native capability | serve route | Electron status |
|---|---|---|
| Office state (backend health, selfcheck, jobs) | `health`, `selfcheck`, `jobs` | Covered; "needs attention" derived client-side from these three |
| Office swarm/loop liveness, approvals, completions, budget | no typed route (only `swarms/:sub`, `loops/:sub` CLI proxies) | **Gap**: native `office_*` facade rules live neither in `serve` nor Electron; retirement blocker |
| Jobs (spawn, list, log, stream) | `POST/GET /api/v1/jobs`, `:id/log`, `:id/events` | Fully covered, verified live |
| Swarm run control + task views (graph, queue, handoffs, budgets, artifacts) | `swarms/:sub` CLI proxy only — no typed views | **Gap**: not surfaced in Electron; retirement blocker |
| Loop audit / cost / receipts / validate / schedule state | `loops/:sub` CLI proxy only — no typed views | **Gap**: not surfaced in Electron; retirement blocker |
| Workspace authoring guard | `workspace/:sub` proxy | Covered via POST actions |
| Library installs, skills/MCP/plugins | `install`, `update`, `uninstall`, `skills/:sub`, `mcp/:sub`, `plugin/:sub` | Covered |
| Terminals | n/a (node-pty adapter in Electron main) | Covered, verified live |

Before native retirement, the typed `desktop_engine` views the UI needs
(swarm/task state, loop audit/cost/receipts) must move down into
core/server as typed `serve` routes — never reimplemented as TS domain
logic or CLI-output parsing. The Electron app follows the same rule the
native facades document: omit what the backend cannot prove rather than
drawing dead buttons (no pause/steer/halt, no job cancel/delete, no
scheduler-install claims).

## Native GUI retirement checklist (only after verified replacement)

- [ ] Electron is installable from a packaged artifact on Linux (blocker)
- [ ] Packaged-app UAT passes (backend lifecycle, terminals, jobs, installs)
- [ ] Remove native GUI from packaging/release paths (keep V domain code)
- [ ] Update ARCHITECTURE.md + ADRs; remove Electron-forbidden statements
- [ ] v2.0.0 (or version per history) published; public artifact re-tested
- [ ] `release.yml`: replace/extend the native `build-desktop` matrix (sokol
  `agent-toolkit-desktop` binaries) with electron-builder artifacts
  (Linux AppImage/deb blocker; macOS/Windows when verified), built from a
  freshly compiled `dist/agent-toolkit` per the packaging rule above
