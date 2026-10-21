# ADR-039 — Swarm collaboration semantics: speech acts, hop budget, human routing, broadcast

- **Status:** Accepted (2026-10-21); engine slice implemented, Desktop "Needs-you" inbox follows
- **Deciders:** ulises-jeremias (owner)
- **Amends:** ADR-008 (canonical swarm runtime — extended, not replaced)

## Context

The canonical swarm handoff queue (`outbox → queued → active →
{completed,failed}`) moves artifacts and commits between roles, but it carries
no notion of *intent* (is this a proposal, a review, an approval?), no bound on
agent-to-agent reply chains (two roles can bounce feedback forever, burning
budget), no first-class place for "a human must decide this", and no convenient
one-to-many assignment. Competitor research (packs A/C in
`research/agent-workstations`) shows durable agent messaging with explicit
human-in-the-loop routing as a core differentiator; the goal is to add those
semantics to the existing filesystem queue instead of inventing a second
orchestration engine.

## Options

### 1. New mailbox/messaging subsystem beside handoffs

- Pros: clean-sheet model.
- Cons: a second source of truth for agent communication; Desktop, CLI and
  world would have to reconcile two queues; violates the "extend the canonical
  swarm" decision recorded in the research decision ledger.

### 2. Extend the handoff record and state machine (chosen)

- Pros: one durable queue; existing validation, audit gate, wake/autostart and
  trace behavior keep applying; legacy records decode unchanged (new fields
  default to empty/zero).
- Cons: handoff ids now incorporate the new fields, so a re-encoded legacy
  record hashes differently — acceptable, ids are assigned at write time and
  never recomputed for records already on disk.

## Decision

Extend `HandoffRecord` with three optional fields and one new state:

- `act` — speech act: `propose | review | approve | reject |
  request_decision | inform`. Empty means a legacy record; any other value is
  rejected by `validate_handoff`.
- `hops` / `max_hops` — reply-chain budget. A create that answers an active
  handoff addressed to the sender inherits `hops + 1` and the incoming
  `max_hops` when not given explicitly. Default budget is
  `handoff_default_max_hops = 6`.
- State `awaiting_human` — when a reply would exceed the budget, the handoff
  is *not* dropped or failed: its act is forced to `request_decision` and it
  is routed to `handoffs/awaiting_human/`. The incoming active handoff is
  completed as usual, a `handoff_awaiting_human` trace event is recorded, and
  the create report returns `state: awaiting_human` with the hop counts.
  A human resolves it with `agent-toolkit swarm task complete --handoff <id>`
  (which also accepts `awaiting_human` as a source state and traces
  `handoff_resolved`), then hands the work on explicitly.

Broadcast: `swarm handoff create --to all` fans out to one queued handoff per
recipe role (excluding the sender and `human`) by running the normal
single-target create per recipient, so validation, the commit audit gate and
role wake-up behave identically for every recipient. The report carries
`broadcast: true`, the comma-joined `handoff_ids` and the recipient count;
partial failures are named in the message, and the broadcast only fails when
every recipient fails.

`swarm status` counts `awaiting_human` alongside the other queues, so the
Desktop Needs-you inbox (next slice) is a projection of real engine state,
not a renderer-side invention.

## Consequences

- Agent loops are bounded by construction; runaway reply chains surface to a
  human with full provenance instead of silently consuming budget.
- The Desktop gains a truthful "needs a human" signal without a new store.
- Speech acts give the world/UI a legible intent per handoff (proposal vs
  approval vs decision request) without changing the transport.
- No migration: pre-existing runs and records keep working; the
  `awaiting_human` directory is created lazily by state transitions and by
  `ensure_swarm_run_dirs` for new runs.
