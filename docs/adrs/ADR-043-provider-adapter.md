# ADR-043: First-party thin ProviderAdapter; T3 Code not adopted

- Status: Proposed (Gate 1 spike evidence, #1669; human review pending)
- Date: 2026-11-11
- Related: #1667, #1668, #1669, ADR-008, ADR-027, ADR-033, ADR-037, ADR-038, ADR-040

## Context

Provider dialect knowledge (binary discovery, launch argv, permission
mode, session-id capture, resume, usage) is duplicated in at least four
places: `swarm_backend.v` (shell strings), `loop_runners.v` (argv),
`personRunner.ts`/`providerResume.ts` (interactive PTY), and
`discovery.v` (probes). Interactive Desktop sessions stream raw PTY
bytes only, so tool calls, approvals and usage are invisible to the
product. Gate 1 (#1669) required comparing a T3 Code fork/service
against a first-party adapter with real providers before any rewrite.

## Measured evidence (2026-11-11, this host, real authenticated runs)

- **Interactive PTY (current Desktop path)**: genuine Claude session
  completed the acceptance fixture through People → Start → terminal →
  fix → Stop → relaunch (Gate 0 field trial, PR #1760). No structured
  events; interventions are terminal text; works today.
- **Claude headless** (`claude -p --output-format stream-json`):
  structured `system`/`assistant`/`result` events with named tool calls
  (Bash/Edit/Read) and a `result` carrying usage and cost
  ($0.172, 30.8 s API for the fixture). In print mode without an
  allowlist, its Edit did not persist — headless runs need an explicit
  permission/allowed-tools dialect entry.
- **Codex headless** (`codex exec --json`): structured
  `thread.started`/`item.*`/`turn.completed` events including
  `command_execution` (argv, output, exit code) and `file_change`
  items plus token usage. Default sandbox is read-only and rejected
  the patch; `--sandbox workspace-write` completed the same fix
  (16 events). Sandbox mode is therefore part of the dialect, not a
  global flag.
- **T3 Code at the repo pin** (`pingdotgg/t3code@9e855385`, MIT):
  inspected, not adopted. It is a full competing product — its own
  server, desktop/web/mobile apps and an orchestration protocol with
  pairing/remote access — not an embeddable library. Its provider
  packages (`effect-acp`, `provider-codex-app-server`, …) confirm ACP
  as a viable transport, but adopting the runtime would create a
  second session/state authority beside the V backend (ADR-027/033)
  and the swarm filesystem state machine (ADR-008).

## Decision

1. Build **one first-party, data-driven ProviderAdapter in V**
   (extending the ADR-038 dialect registry): per-provider
   `discovery / launch / permission / sandbox / session_capture /
   resume / usage` entries. The four duplicated tables collapse into
   it incrementally; no big-bang rewrite.
2. Two transport classes feed the Gate 1 journal contract
   (`scripts/spikes/1669-session-journal.mjs`, fail-closed since
   #1758): **structured headless** (Claude `stream-json`, Codex
   app-server/JSON; ACP where a provider offers it) for
   swarm/loop/automation, and **PTY interactive** (existing detached
   PTY host, ADR-037) for People sessions, with the journal
   normalizing both into one event vocabulary.
3. **T3 Code is not forked, vendored or sidecared at this time.**
   Revisit only if the first-party adapter demonstrably fails Gate 1
   exit criteria with real Claude+Codex sessions; any revisit starts
   from the pinned upstream and this ADR's measurement table.
4. Interface is versioned (`provider-adapter/v1`): adding a provider
   means adding a dialect row plus its transport proof, never a new
   execution path.

## Consequences

- Smallest new surface; V stays the domain authority; existing
  resume/capture machinery (ADR-038) and PTY host (ADR-037) are kept.
- We own per-provider quirks (permission prompts, sandbox flags,
  crash recovery) — bounded by the dialect table and journal tests.
- Structured tool/usage visibility arrives for headless runs first;
  interactive PTY remains text-grade until a provider offers a
  structured interactive transport.
- Migration: (1) extract dialect rows from `providerResume.ts` +
  `loop_runners.v` into the V table behind current behavior;
  (2) wire Codex JSON + Claude stream-json into the journal for one
  swarm runner each; (3) delete duplicated rows as proofs land.
