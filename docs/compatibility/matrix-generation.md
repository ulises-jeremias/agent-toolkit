# Docs: generated compatibility matrix — #388 (2026-08-12)

Per §66-68: Matrix must be generated from source of truth (distributions/products.yaml + skill frontmatter tools + mcp/registry + capabilities/targets/registry.yaml) not hand-edited badges. No fake cross-platform support (all ✅ when only markdown portable).

## Source of truth

Canonical: distributions/products.yaml (products → includes.skills/includes.agents + targets mapping) + catalogs/skills-layout.json (generated from skills/**/SKILL.md frontmatter via scripts/validate-skills.vsh) + mcp/registry/*.yaml (platforms matrix) + capabilities/targets/registry.yaml (targets list).

Generated: docs/SKILL_PRODUCT_MATRIX.md via scripts/generate-skill-matrix.vsh (do not hand-edit — header says Generated from distributions/products.yaml — do not hand-edit).

Current: Generated from 4 products × 77 skills × 17 agents. via products.yaml (4 products: agent-toolkit-core stable claude-code,cursor 6 skills, agent-toolkit-agents 16 agents, agent-toolkit-forge 7 skills, agent-toolkit-complete experimental 77 skills).

Honest per-skill support (validated, not badges): inventory JSON is source of truth; docs/matrix generated via conversion, not duplication. scripts/generate-skill-matrix.vsh --check enforces in CI.

Muse support verified live: muse code skill load tested via agent-toolkit doctor ai_tools: muse

Refs #388, #368, #387
