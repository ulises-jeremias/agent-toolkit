# ADR-037 — Detached PTY host owns interactive terminal sessions

- **Status:** Accepted (2026-10-21); implemented in `apps/desktop/electron/pty-host*.ts`
- **Deciders:** ulises-jeremias (owner)
- **Amends:** ADR-033 (Electron Desktop — terminal transport was node-pty in Electron main)
- **Related:** ADR-036 (durable People — names process continuity after Desktop exits as unsupported; this ADR removes that limit at the PTY layer)

## Context

Interactive PTYs (agent CLIs, shells) were spawned by node-pty inside the
Electron main process and kept in an in-memory map (`TerminalService`).
Quitting or crashing the app killed every running agent session, and a
renderer reload lost the byte stream. Competitor research (Pack A:
AgentSystemLabs Agent Office, Munder Difflin) shows durable sessions that
survive the UI is a baseline expectation for an agent workstation, and our
own People model (ADR-036) explicitly listed "process continuity after
Desktop exits" as unsupported.

The V engine remains authoritative for domain state (sessions records,
People, jobs). The PTY layer is transport only: it owns processes and
bytes, never domain truth.

## Options

### 1. Keep PTYs in Electron main, persist metadata only

- Pros: no new process; simplest.
- Cons: processes still die with the app; metadata without a live process
  is a false promise of continuity. Rejected.

### 2. Detached per-user PTY host daemon (chosen)

A small Node host process, spawned detached by the first client, owns
every PTY. Electron main is a client over a local socket; app quit/crash
only detaches. The next launch reattaches (`list` + `tail` journal
replay).

- Pros: real continuity; crash isolation between UI and agent processes;
  the host is transport-only and holds no domain state; one host per
  user, exits when idle.
- Cons: a new process to package, secure and lifecycle-manage; native
  node-pty now loads in the host instead of main.

### 3. Move PTYs into the V backend (`agent-toolkit serve`)

- Pros: single runtime authority.
- Cons: V has no PTY primitive today; interactive byte streaming through
  the HTTP API would need a new websocket/PTY subsystem in the engine.
  Larger, riskier change; can be revisited if the engine grows a native
  PTY capability.

## Decision

Adopt option 2.

- **Process**: `pty-host.ts` (compiled to `pty-host.js` by
  `build:electron`) is spawned detached by `PtyHostClient` on first use:
  `process.execPath entry --runtime-dir <dir>`, with
  `ELECTRON_RUN_AS_NODE=1` when the parent is Electron. In tests the
  client accepts a `spawnHost` override; the survival test drives the
  real compiled entry from a separate driver process.
- **Transport**: newline-delimited JSON (`pty-protocol.ts`,
  `PTY_HOST_PROTOCOL = 1`) over a Unix domain socket
  (`<runtime>/pty-host.sock`, 0600) or the Windows named pipe
  `\\.\pipe\agent-toolkit-pty-host`.
- **Auth**: the first frame must be `hello` with the shared token from
  `<runtime>/pty-host.token` (0600) and the protocol version; anything
  else destroys the connection. This is a local same-user boundary, not
  a security sandbox claim.
- **Runtime dir**: `$XDG_RUNTIME_DIR/agent-toolkit` when available, else
  `<tmp>/agent-toolkit-<uid>`; created 0700.
- **State**: sessions live in the host's memory; output is journaled to
  `<runtime>/pty-<id>.log` and ring-buffered (256 KiB) for `tail`
  replay; a best-effort `pty-registry.json` records host pid + session
  infos for observability. A restarted host owns no live PTYs and does
  not fake replay of dead sessions.
- **Lifecycle**: the host exits after the last session ends and no
  client has connected for 60 s. `TerminalService.dispose()` detaches
  only; explicit teardown is `terminateAll()`. Per-session time budgets
  (`maxSeconds`, `exitReason: 'time-budget'`) are enforced by the host
  so they survive app restarts too.
- **Client surface**: `TerminalService` keeps its established
  synchronous IPC shape (`list/tail/write/resize/signal/close`,
  `onData/onExit`, `attachWindow`) over a local mirror reconciled with
  the host on start/reconnect; only `create()` became async. The IPC
  channels and renderer contract are unchanged.

## Consequences

- Agent terminals survive Desktop quit, crash and renderer reload, and
  are rediscovered on next launch with recent output intact.
- ADR-036's "process continuity after Desktop exits" limitation is
  lifted at the PTY layer. Provider-level conversation resume (Slice 4)
  builds on this but is a separate concern: `agentSessionId` remains the
  Toolkit session id, not a provider CLI session id.
- Packaging must ship `pty-host.js` beside `main.js` (it does:
  `build:electron` compiles the whole `electron/` tree) and node-pty's
  native binding must load under `ELECTRON_RUN_AS_NODE`.
- Risks: orphan hosts after hard kills (mitigated by idle exit and the
  socket singleton — a stale socket file is unlinked on listen), token
  file shared by all same-user clients by design.

## Rollback

Revert `TerminalService` to the in-memory implementation (pre-ADR-037
`terminal.ts`) and delete `pty-host*.ts`. No user data is stored in the
host; journals/registry in the runtime dir are disposable.
