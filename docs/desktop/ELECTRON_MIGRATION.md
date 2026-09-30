# Electron migration — rollback, status, and parity ledger

Canonical plan: [ADR-033](../adrs/ADR-033-electron-desktop.md). Design contract:
[DESIGN.md](DESIGN.md). Template foundation: Create Awesome Node App
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

## Default harness

Desktop's default harness is `~/.ai-workspace`, expanded with the OS home
directory. `electron/harness.ts` resolves it again on every backend start:

1. **override**: `AGENT_TOOLKIT_WORKSPACE`, then its alias `HARNESS_DIR`
   (the order core `find_workspace_root` uses, see
   [env-precedence.md](../compatibility/env-precedence.md)). `~` and relative
   paths are expanded. A value that is not a directory is skipped.
2. **default**: `~/.ai-workspace`, if it is a directory.
3. **fallback**: the behavior from before this default existed. serve
   inherits the Desktop process cwd and resolves its workspace from there.
   This applies when an override is set but broken, or when the default is
   missing. Desktop never creates `~/.ai-workspace`, so Agent Toolkit stays
   usable without My AI Workspace.

For `default` and `override`, serve is spawned with `cwd` set to the harness
and `AGENT_TOOLKIT_WORKSPACE` set to the same path. That keeps the jobs dir,
containment roots and `find_workspace_root` in agreement (see
[SERVE_API.md](../SERVE_API.md#workspace-rooting)). The resolution
(`path`, `source`, `defaultPath`, `overrideVar`, `notice`) travels on
`BackendState.harness` through `atk:backend-status` and `atk:backend-state`.
Settings shows the harness and any notice, and Office shows it on the backend
line.

Switching the harness at runtime means restarting the backend: serve is
cwd-rooted, so one backend serves one harness. The supervisor takes a
`resolveHarness` option, so a later onboarding or workspace picker can
provide a chosen path and call `restart()`.

Verified 2026-09-29 in the Electron dev app against the installed backend
1.35.0. By default, the serve child ran in `~/.ai-workspace` with the env
set. Selfcheck `jobs_dir_writable`, `GET /loops` and `workspace/context` all
reported `~/.ai-workspace`. With `AGENT_TOOLKIT_WORKSPACE` pointing at a
missing directory, Settings showed the fallback notice, serve stayed in the
inherited cwd, and nothing was created. Evidence:
[default](assets/electron/settings-harness-default.png),
[fallback](assets/electron/settings-harness-fallback.png).

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
