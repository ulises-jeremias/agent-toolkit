# ADR-040 — Live model catalogue and cancel hardening

- **Status:** Accepted (2026-10-21); implemented in this slice
- **Deciders:** ulises-jeremias (owner)
- **Amends:** ADR-020 (loop runner fail-closed policy — unchanged), Pack A tasks 5–6

## Context

Model selection was driven by the static `swarm_model_profiles()` map.
Providers retire and rename models continuously, so the picker offered
stale ids and the failure only surfaced at spawn time, after the user
had configured a whole session. Competitor research (Pack A) shows the
fix: AgentSystemLabs' Agent Office asks each CLI for its own catalogue
(`opencode models`, `codex debug models`, `cursor-agent models`),
caches it for 60 s, and treats the output as untrusted input.

Cancellation had the mirror problem: the V `ProcessService` timeout
went straight to SIGKILL (no chance for a provider CLI to flush state
or stop its own children), and the Desktop PTY `signal('term'|'kill')`
killed only the leader pid, orphaning grandchildren.

## Decision

1. **Live catalogue in the V core** (`model_catalogue.v`). Per-runner
   probe commands (argv only, never a shell): `opencode models`,
   `codex debug models`, `cursor-agent models`. Runners without a
   verified list command (claude, copilot, muse, skeleton) report
   `source: 'static'` honestly. The probe drains stdout while the
   child runs (a long catalogue cannot block on a full pipe), caps
   output at 4 MiB, times out at 10 s, strips ANSI, and only accepts
   model-shaped tokens. Results cache on disk under the OS cache dir
   for 60 s. Any probe failure degrades to the static profiles with an
   explanatory `detail` — never fake data, never a blocked picker.
2. **One validation rule.** Session start accepts a model when the
   static profiles *or* the live catalogue list it
   (`model_available_for_runner`), so a model picked from the live
   catalogue cannot fail validation for being absent from the static
   map, and a retired model fails at pick time instead of at spawn.
3. **API** `GET /api/v1/models/live?runner=<id>` returns the typed
   `LiveModelsResponse` (`source: live|static|unavailable`). Declared
   in the `api-schemas.yaml` SSOT; OpenAPI and Desktop types are
   regenerated, never hand-edited.
4. **Cancel hardening, V side.** `ProcessService` timeouts now run
   `terminate_with_grace`: SIGTERM, a grace window
   (`RunOptions.term_grace`, default 1 s), then a process-group kill,
   then SIGKILL.
5. **Cancel hardening, Desktop side.** PTY `term`/`kill` signals go
   through `killProcessTree`: a negative-pid group signal (the PTY
   child leads its own group on POSIX) with a bare-pid fallback.

## Consequences

- The Person Start dialog merges live entries into the model picker
  (labelled `live · <id> · <name>`) and says so in the field hint;
  offline or unlistable runners keep the previous static behaviour.
- The catalogue cache is a hint, not truth: entries older than 60 s
  are re-probed, and session validation re-checks the same source the
  picker used.
- Catalogue output is untrusted CLI output: ids must be single
  whitespace-free printable tokens of at most 120 chars, names are
  control-stripped and capped at 80 chars, codex entries with
  `visibility != 'list'` are excluded.
- Windows: process-group kill degrades to the bare-pid fallback;
  `terminate_with_grace` still applies the TERM grace. Verified by
  unit tests on POSIX; Windows behaviour is covered by the same code
  path shape but not yet by a Windows PTY test.
