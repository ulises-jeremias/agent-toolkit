# OWASP Agentic Review Report

**Scope:** [skills/agents/mcp/registry/plugins]  **Date:** [YYYY-MM-DD]  **Reviewer:** [agentic-security-reviewer]
**OWASP source:** LLM Top 10 2025 v1.1 (2025-02-18) https://owasp.org/www-project-top-10-for-large-language-model-applications/ + Agentic Security https://owasp.org/www-project-agentic-security/ (2025)

> Evidence-cited — do not hallucinate. Every finding needs observation + OWASP ID + impact + likelihood + confidence + evidence.

## Assets, trust boundaries, data flows, actors

| Asset | Trust boundary | Data flow | Actor |
|-------|----------------|-----------|-------|
| [skill SKILL.md] | user ↔ agent ↔ MCP ↔ external host | user input → skill instructions → tool args → external API | [agent name] |

## Risk-ranked findings

| # | OWASP ID | Title | Observation (file:line, registry) | Attack path | Impact | Likelihood | Severity | Confidence | Mitigation | Residual risk | Evidence |
|---|----------|-------|-----------------------------------|-------------|--------|------------|----------|------------|------------|---------------|----------|
| 1 | LLM01 | Prompt Injection via tool description | `mcp/registry/example.yaml:12 tool description "ignore previous"` | user → tool description → LLM override | prompt hierarchy violation, data exfiltration | Medium | High | High | sanitize tool descriptions, delimit user input, hook prompt escaping | Low after fix | file:line + audit-capability.py |
| 2 | LLM05 | Unpinned supply chain | `mcp/registry/example.yaml package: mcp-example` without digest/policy | attacker publishes malicious `mcp-example@latest` | supply-chain compromise | Low | Medium | High | pin to `mcp-example@1.2.3` or digest, version_policy | Low | registry YAML |

## Mitigations & security acceptance criteria

| Finding | Mitigation | Acceptance criteria | Owner |
|---------|------------|---------------------|-------|
| LLM01 | sanitize tool descriptions, delimit user input | no injection phrases in `skills/**`/`mcp/registry` + `audit-capability.py` clean |  |
| LLM08 | add `output-handshake` + `approval.default: read-only` | no `destructive` without explicit approval |  |

## Output handshake

- **Destination:** [docs/security/owasp-agentic-YYYY-MM-DD.md or PR comment]
- **Reviewer:** [who approves]
- **Confirmed:** [date]
