# Agentic-Security Pack — docs-only

Curated for agentic-security per #390: supply-chain, MCP audit, OWASP agentic, threat-modeling.

## Components
- **Skills:** supply-chain-audit (provenance lock per ADR-0001), mcp-audit + mcp-security, owasp-agentic-review, threat-modeling, inventory
- **Agents:** security-reviewer, agentic-security-reviewer
- **Loops:** security-audit (optional)

## Setup
```bash
cp packs/agentic-security/config.yaml ~/.ai-workspace/packs/agentic-security.yaml
```

## Workflow
supply-chain-audit → mcp-audit → owasp-agentic-review → threat-modeling (STRIDE) → agentic-security-reviewer → ADR.

## Trust
All first-party except supply-chain (reviewed) — pack trust_tier: verified; no community shell skill auto-enabled.
