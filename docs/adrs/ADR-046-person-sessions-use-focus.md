# ADR-046: Person-initiated coding sessions use Focus

**Status:** Proposed — requires owner review before acceptance  
**Date:** 2026-11-14  
**Amends:** ADR-044's decision to keep Person → Start on a separate PTY lifecycle  
**Related:** #1667, #1670, #1671, #1675, ADR-036, ADR-037, ADR-044, ADR-045

## Context

Person is a durable collaborator identity. A Person Start currently creates a
workspace `PersonSession`, launches a separate PTY, and opens Terminal. Focus
already owns structured provider turns, approvals, event history, recovery,
terminal access, and Git changes. The separate path means a developer cannot
inspect a Person's coding task in Focus or navigate from its real activity in
the World to the same canonical conversation.

The workflow must preserve old `PersonSession` records and continue to show
legacy PTY sessions. Person settings such as isolation, token/cost budgets,
skills, and MCP preferences are not uniformly enforced by Focus and must not be
implied to be active.

## Options Considered

### Keep Person Start on the PTY path

**Pros:** Keeps current resume behavior and the existing V-owned lifecycle
record unchanged.

**Cons:** Retains a second session workflow with no Focus event journal,
approvals, shared session inspector, or World → Focus identity. It perpetuates
the product split the primary coding surface is meant to remove.

### Start Person sessions as Focus threads (chosen)

**Pros:** Reuses the provider runtime, session journal, approvals, terminal,
diff, history and navigation. The Focus thread ID is the identity used by
People, World and Focus; no second session is fabricated.

**Cons:** Person-associated threads are stored in Focus's private app journal,
not workspace `PersonSession` files. Per-Person runtime/token/cost limits and
isolation remain unavailable unless a provider/runtime capability enforces
them. Existing PTY sessions cannot be retroactively converted into structured
Focus events.

## Decision

New Person starts create a Focus thread and attach an optional `personId` to
that thread's private metadata. Focus remains the sole source of truth for the
provider process, status, event stream, approvals, transcript and diff. People
reads the same thread by ID and opens it in Focus; the World displays a Person
only while that linked provider session is actually running or awaiting an
approval, and clicking the character opens that same Focus thread.

The V `PersonSession` contract remains intact for Swarm task runs and old
interactive PTY history. Existing records, IDs and provider conversation IDs
are not rewritten or deleted. Old live PTYs remain operable through Terminal;
old history stays labeled as legacy PTY history. Starting a new Focus thread
from an old record does not claim to import its transcript or resume its
provider conversation.

The start dialog offers only providers that Focus reports as installed and
ready and capable of structured Focus sessions, uses the saved Person
role/goal/notes as explicit initial context, and requires acknowledgement for
configured Person limits or isolation that the runtime cannot enforce.
Permission mode is selected explicitly; default is `ask`. Unknown or archived
Person IDs are not surfaced as World characters. Until Focus gains adapters
for more providers, new Person starts are unavailable for runners that only
worked in the legacy interactive PTY path. Existing PTY sessions/history remain
inspectable, but there is no new Person-session PTY fallback in this slice.

## Consequences

- Person, Focus thread, provider process and Swarm task-run remain distinct
  concepts, linked by explicit IDs rather than duplicated session records.
- Focus threads created from People can be discovered in People, Projects,
  Focus and World after app restart, subject to the same private journal
  lifecycle as other Focus threads.
- There is no workspace migration. Journals without `personId` remain
  unassociated; missing `personId` parses as `null` for compatibility.
- Legacy PTY-based Person sessions remain visible and are not silently
  reclassified as Focus sessions. Their old conversation history is not
  reconstructed from provider-side state.
- Person token/cost caps, max runtime, worktree isolation, and skill/MCP
  preferences remain unmeasured or unenforced where Focus/provider contracts
  do not supply those controls. UI copy must say so.
- Broader Person Start coverage follows Focus adapter coverage; the current
  Focus runtime registers Claude only. Provider support must never be inferred
  from provider discovery alone.

## References

- [Mission #1667](https://github.com/ulises-jeremias/agent-toolkit/issues/1667)
- [Focus UX #1671](https://github.com/ulises-jeremias/agent-toolkit/issues/1671)
- [Toolkit context integration #1675](https://github.com/ulises-jeremias/agent-toolkit/issues/1675)
- PR: pending; this ADR and implementation are proposed together for review.
