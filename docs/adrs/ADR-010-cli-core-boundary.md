# ADR-010: CLI / Core Boundary and Output Rendering

**Status:** Accepted  
**Date:** 2026-08-12  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#480](https://github.com/ulises-jeremias/agent-toolkit/issues/480))

## Context

Today the Python CLI often mixes argparse, domain work, and printing in the same modules. For the V rewrite, CLI must remain a thin adapter over `agent_toolkit_core` so HTTP/`serve` and TUI can reuse the same results without reimplementing behavior.

## Options considered

1. **CLI-centric architecture** — keep business logic in command handlers (Python status quo).
2. **Core returns structured domain results; CLI only parses and renders** — human / JSON / quiet / verbose are presentation modes over the same model.
3. **Core returns strings** — domain layer formats output.

## Decision

Adopt **option 2**.

- Core APIs return **typed domain results** (success models or domain errors). They do not print to stdout/stderr as their primary contract.
- CLI adapter:
  - Parses argv / flags / subcommands
  - Invokes core
  - Maps domain errors to **stable exit codes**
  - Renders:
    - **human** — default terminal prose
    - **JSON** — machine-readable (`--json` where the Python CLI already supports it; expand carefully with schema parity)
    - **quiet / verbose** — verbosity filters over the same result (when introduced, must not fork business logic)
- Future `serve` serializes the **same** domain models.
- Future TUI displays the **same** models interactively (in-process preferred).

### Exit-code taxonomy (domain → CLI)

Align with `docs/CLI_SURFACES.md` (consumer/advanced handlers return int; bad flags → 2):

| Class | Meaning | Typical exit |
|-------|---------|--------------|
| OK | Success | 0 |
| USER | Bad usage / validation the user can fix | 1 |
| CONFIG | Invalid/missing configuration | 1 |
| ENV | Missing tools / offline / path resolution | 1 |
| EXTERNAL | Subprocess / agent / git / gh failure | 1 |
| NETWORK | Download / API failure | 1 |
| INTERNAL | Bug / invariant violation | 1 |
| USAGE_FLAGS | argparse / CLI parse errors | **2** |

Exact numeric mapping beyond 0/1/2 is refined in the error-model implementation issue; this ADR freezes the **classes** and that help stays exit 0 while bad flags stay exit 2.

## Consequences

- **Positive:** One behavior, many adapters; golden parity can assert SCHEMA on JSON and SEMANTIC on human text.
- **Negative:** More types/boilerplate up front.
- **Rejected:** String-returning core (blocks JSON/schema parity and server reuse).

## Validation plan

- Unit tests call core without capturing stdout.
- CLI tests assert exit codes + JSON SCHEMA fixtures where `--json` exists.
- Import lint / review: no `println` of business results inside core modules.

## References

- `docs/CLI_SURFACES.md`
- ADR-009 (module layout)
- Issue [#480](https://github.com/ulises-jeremias/agent-toolkit/issues/480)

**Verified:** 2026-08-12
