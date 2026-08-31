# Python↔V Golden CLI Parity Harness — Design Specification

**Status:** Accepted design (implementation: [#548](https://github.com/ulises-jeremias/agent-toolkit/issues/548))  
**Date:** 2026-08-12  
**Issue:** [#476](https://github.com/ulises-jeremias/agent-toolkit/issues/476)  
**Program:** [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)

## Goal

Correctness of the V rewrite is defined by a **compatibility contract**, not vibes. This document specifies the harness design only — **no harness executable code lands in this change**.

## Architecture

```text
              fixture
                 │
        ┌────────┴────────┐
        ▼                 ▼
   Python CLI           V CLI
        │                 │
        └────────┬────────┘
                 ▼
           parity assertion
```

Python remains the reference oracle until cutover ([ADR-012](../adrs/ADR-012-python-v-coexistence.md)).

## Parity taxonomy

### EXACT

- Exit codes
- Stable enum/string identifiers (tool names, product IDs, recipe names)
- Canonical machine-readable bytes **only where explicitly required**

### NORMALIZED EXACT

Same logical bytes after normalizing:

- path separators
- temp-dir prefixes
- timestamps / non-deterministic fields
- unspecified list ordering
- platform-dependent absolute paths (compare relative or tagged fields)

### SCHEMA

- JSON output structure/types
- Receipt / provider / capability / manifest structures
- Validation accept/reject behavior ([ADR-014](../adrs/ADR-014-schema-validation.md) / [#546](https://github.com/ulises-jeremias/agent-toolkit/issues/546))

**Do not** classify “JSON schemas” as EXACT.

### SEMANTIC

- Human help/text meaning (wording need not be identical)
- Ordering-insensitive lists when order is not contractual

### BEHAVIORAL

- Files created/removed, permissions/symlinks, rollback effects
- External process argv shape (no shell), exit propagation

## Seed fixtures (minimum)

| Command | Classes |
|---------|---------|
| `version` / `--version` | EXACT or NORMALIZED EXACT on version string policy; exit 0 |
| `--help` / `help` | SEMANTIC; exit 0 |
| `inventory` | SCHEMA/SEMANTIC for structured output; BEHAVIORAL none |
| `doctor` (read-only, no `--fix`) | SCHEMA for `--json`; BEHAVIORAL none |

Map all other commands via the machine-readable CLI contract ([#549](https://github.com/ulises-jeremias/agent-toolkit/issues/549)).

## Fixture rules

- No secrets, tokens, or live credentials
- Prefer hermetic trees under `tests/parity/fixtures/` (implementation issue)
- Document which binary paths (`agent-toolkit` Python vs experimental V) the harness accepts

## CI policy

Coordinate with [#532](https://github.com/ulises-jeremias/agent-toolkit/issues/532):

- **PR:** small seed subset
- **main / release:** fuller matrix when dual binaries exist

## Non-goals

- Scaffold placeholder harness that reports green without assertions
- Byte-identical human output by default

## Implementation handoff

Executable harness + CI job: **[#548](https://github.com/ulises-jeremias/agent-toolkit/issues/548)** after this design is merged.

**Verified:** 2026-08-12
