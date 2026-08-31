# V capability loader

**Issue:** [#507](https://github.com/ulises-jeremias/agent-toolkit/issues/507)

Loads `skills/**/SKILL.md`, `agents/*/AGENT.md`, and `distributions/products.yaml` into a `CanonicalGraph` (ADR-001). Packs remain docs-only (ADR-006). Product selection is `select_product(id)`. Skill descriptions with YAML folded scalars are not decoded here (`vlib/yaml`); ids come from the tree walk.
