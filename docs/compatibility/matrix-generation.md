# Docs: generated compatibility matrix — #388 (2026-08-12)

Per §66-68: Matrix must be generated from source of truth (distributions/products.yaml + skill frontmatter tools + mcp/registry + capabilities/targets/registry.yaml) not hand-edited badges. No fake cross-platform support (all ✅ when only markdown portable).

## Source of truth

Canonical: distributions/products.yaml (products → includes.skills/includes.agents + targets mapping) + catalogs/skills-layout.json (generated from `skills/**/SKILL.md` via `scripts/generate-catalogs.vsh`) + mcp/registry/*.yaml (platforms matrix) + capabilities/targets/registry.yaml (targets list).

Generated: docs/SKILL_PRODUCT_MATRIX.md via scripts/generate-skill-matrix.vsh (do not hand-edit — header says Generated from distributions/products.yaml — do not hand-edit).

The original counts below describe the 2026-08-12 snapshot only. Catalog sizes
change as repository-owned capabilities evolve; the generated matrix header is
the current count, and `scripts/generate-skill-matrix.vsh --check` verifies it.
The five product names remain declared in `distributions/products.yaml`.

Honest per-skill support (validated, not badges): inventory JSON is source of truth; docs/matrix generated via conversion, not duplication. scripts/generate-skill-matrix.vsh --check enforces in CI.

Muse support verified live: muse code skill load tested via agent-toolkit doctor ai_tools: muse

Refs #388, #368, #387
