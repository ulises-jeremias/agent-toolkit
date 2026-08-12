# ADR-014: Schema Validation Strategy in V

**Status:** Accepted  
**Date:** 2026-08-12  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#546](https://github.com/ulises-jeremias/agent-toolkit/issues/546))

## Context

Parsing YAML/JSON successfully is not validation. Agent Toolkit relies on structured accept/reject behavior for products, targets, loops, MCP registry entries, receipts, provenance, and related manifests. Risk register [#478](https://github.com/ulises-jeremias/agent-toolkit/issues/478) flags JSON Schema gaps as Medium/High. YAML parsing is ADR-013 ([#483](https://github.com/ulises-jeremias/agent-toolkit/issues/483)); this ADR covers **validation**.

## Options considered

1. Mature V JSON Schema library (if quality/license acceptable).
2. Strictly limited subset validator owned by Agent Toolkit.
3. **Generated / hand-maintained typed validators** from known schemas and structs.
4. External validator bridge (long-term).
5. Keep Python validator during parity phase only, then cut over.

## Decision

Adopt a **phased combination of 3 + 5**:

1. **Primary (V):** typed validators in `agent_toolkit_core` for first-party documents we control (products, targets, receipts, MCP registry shapes, provenance fields). Prefer decode-to-struct + explicit field/invariant checks over a general JSON Schema engine.
2. **Parity phase:** where existing Python tests or `jsonschema` fixtures already encode accept/reject cases, keep those fixtures runnable against Python until V validators cover the same cases ([#548](https://github.com/ulises-jeremias/agent-toolkit/issues/548)).
3. **Do not** silently weaken validation because a Python library disappears.
4. Revisit a full JSON Schema library only if typed validators cannot express a **required** upstream schema; that requires an ADR amendment with fixtures.

## Consequences

- **Positive:** Validation stays in-core; no weak “parse OK” bar; clear parity fixtures.
- **Negative:** More hand-maintained checks; must inventory current schema call sites.
- **Rejected:** Custom general YAML/JSON-Schema engine as day-one work; permanent Python bridge after cutover.

## Validation plan

- Inventory Python validation call sites (compiler/installer/doctor/loops).
- Golden accept/reject fixtures per document class.
- Block compiler/installer parity issues on green fixture sets.

## References

- Issues [#546](https://github.com/ulises-jeremias/agent-toolkit/issues/546), [#483](https://github.com/ulises-jeremias/agent-toolkit/issues/483), [#478](https://github.com/ulises-jeremias/agent-toolkit/issues/478)
- ADR-013 (YAML parse)

**Verified:** 2026-08-12
