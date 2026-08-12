# Architecture Pack — docs-only, vendor-neutral

Curated for architecture per #390: vendor-neutral core + optional cloud.

## Components
- **Core (vendor-neutral):** architect, adr, trd, threat-modeling, mermaid + c4-model (C4 via Mermaid per #385)
- **Optional (cloud):** cloud-design-patterns, aws-well-architected-review (disabled by default, enable for AWS per #384 — see docs/cloud/research-384-candidates.md, AWS MCP vs prompt)
- **Loops:** architecture-review (optional)

## Setup
```bash
cp packs/architecture/config.yaml ~/.ai-workspace/packs/architecture.yaml
# Enable cloud optional:
# cloud/cloud-design-patterns: enabled: true
# cloud/aws-well-architected-review: enabled: true
```

## Workflow
architect → adr (6-part, lifecycle PROPOSED→ACCEPTED→SUPERSEDED) → trd → threat-model → mermaid/c4-model → cloud-design-patterns/aws-well-architected-review (optional, via awslabs/mcp when live).

## Trust
All first-party, vendor-neutral core trust_tier: verified; cloud optional adds aws-well-architected (first-party) — no community shell.
