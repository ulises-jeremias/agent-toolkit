# ADR-013: YAML Strategy for the V Migration

**Status:** Accepted  
**Date:** 2026-08-12  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#483](https://github.com/ulises-jeremias/agent-toolkit/issues/483))

## Context

Agent Toolkit uses YAML heavily (`distributions/products.yaml`, target YAMLs, loop configs, MCP registry, provenance, frontmatter-adjacent content, etc.). Python optionally depends on PyYAML. V 0.5.2 ships `vlib/yaml` for common configuration files. YAML correctness is a migration risk if we weaken parsing or invent a general-purpose custom parser.

Schema **validation** (JSON Schema / typed accept-reject) is a separate decision ([#546](https://github.com/ulises-jeremias/agent-toolkit/issues/546)); this ADR covers **parsing/encoding** only.

## Options considered

1. **Use `vlib/yaml`** for toolkit configuration YAML (decode to typed structs / `yaml.Any` as needed).
2. **Retain Python YAML only during parity**, then delete without a V parser — unacceptable for binary-first.
3. **Convert all internal formats to JSON** — large breaking content migration; out of scope for engine rewrite.
4. **Write a custom general YAML parser** — high risk; rejected.
5. **Third-party V YAML dependency** — only if `vlib/yaml` is proven insufficient for required constructs.

## Decision

Adopt **option 1 (`vlib/yaml`)** as the default YAML stack for Agent Toolkit V code.

- Prefer decoding into **typed V structs** for known documents (`products.yaml`, receipts, registries).
- Use tree/`Any` access only where documents are open-ended.
- Document unsupported YAML constructs if encountered; prefer constraining **authored** toolkit YAML to what `vlib/yaml` handles rather than writing a general parser.
- Do **not** introduce a third-party YAML library unless a concrete blocker is filed with fixtures proving `vlib/yaml` cannot parse a **required** existing file. That escalation needs an ADR amendment.
- JSON remains the preferred **machine output** surface for CLI `--json` (ADR-010). Do not silently replace user-facing YAML content formats with JSON without a migration issue.
- Pair with [#546](https://github.com/ulises-jeremias/agent-toolkit/issues/546) so parse success ≠ validation success.

## Consequences

- **Positive:** Stdlib dependency; matches V 0.5.2 ecosystem; avoids custom parser debt.
- **Negative:** Must inventory YAML features used in-repo and add fixtures; possible follow-up if exotic YAML appears in third-party overlays.
- **Rejected:** Custom general YAML parser; wholesale JSON conversion of capability content as part of language migration.

## Validation plan

- Golden fixtures: decode every first-party YAML class used by compiler/installer/doctor (products, targets, loops sample, MCP registry sample, provenance samples).
- Parity: Python PyYAML vs V `vlib/yaml` on the same fixtures for fields we contractually care about (SCHEMA / NORMALIZED EXACT).
- Pin V via `.v-version`; re-run fixtures on V upgrades.

## References

- https://modules.vlang.io/yaml.html (V 0.5.2 era docs; Verified 2026-08-12)
- Issue [#483](https://github.com/ulises-jeremias/agent-toolkit/issues/483), [#546](https://github.com/ulises-jeremias/agent-toolkit/issues/546)
- Python call sites: `compiler/loader.py`, `target_registry.py`, `cli/doctor.py`, `swarm/recipes.py`, etc.

**Verified:** 2026-08-12
