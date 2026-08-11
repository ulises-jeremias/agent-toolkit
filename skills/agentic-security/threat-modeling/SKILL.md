---
name: threat-modeling
description: STRIDE + agentic threat modeling — architecture discovery → assets/trust boundaries/data flows/actors → STRIDE + agentic threats → risk-ranked mitigations → incremental review → security acceptance criteria. Swarm-friendly.
origin:
  type: first-party
---

# Threat Modeling — STRIDE + Agentic Threats

Guide **architecture → threat model → security review → security acceptance criteria**. Produces a STRIDE table augmented with agentic-specific threats (prompt injection, tool poisoning, excessive agency, inter-agent trust), risk-ranked with mitigations and acceptance criteria.

**Evidence-linked, portable, incremental.** Architecture discovery reuses C4/Mermaid inputs (#369); outputs feed `agentic-security-reviewer` + `owasp-agentic-review` + `security-reviewer`.

> **Sources:** Microsoft STRIDE (Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service, Elevation of Privilege) + OWASP Threat Modeling + OWASP Agentic Security (prompt injection, tool poisoning, excessive agency, data leakage, insecure plugin/MCP). See https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats and https://owasp.org/www-project-threat-model/ .

## When to use

- New system/C4 design (`architect` output), new data flow (user → agent → tool → external), new trust boundary (skill composition, MCP addition, swarm handoff)
- Before `security-reviewer` / `owasp-agentic-review` prioritizes mitigations
- On architecture change — incremental mode re-runs only on deltas

## Inputs

| Input | Source | Required |
|-------|--------|----------|
| Architecture diagram | `architect` / C4/Mermaid (#369) — `docs/architecture/*.md`, Mermaid `C4Context`/`flowchart` | Yes (or textual description for small scopes) |
| Assets | Code + docs: skills, agents, MCP registry, secrets, data stores | Yes |
| Trust boundaries | User ↔ agent, agent ↔ MCP, agent ↔ external host, inter-agent, skill composition | Yes |
| Data flows | `audit-capability.py` shell/network/MCP/hooks surface, registry YAML, hook configs | Yes |
| Actors | Users, agents (by persona), MCP servers, external services | Yes |

## Outputs

- `threat-model.md` per `references/threat-model-template.md`: assets/boundaries/flows/actors → STRIDE + agentic threats table (severity, likelihood, impact, confidence, evidence) → mitigations → security acceptance criteria
- Incremental diff when `architecture discovery` changed
- Handoff: `agentic-security-reviewer` consumes findings for OWASP review; `security-reviewer` for app-layer vulns

## STRIDE + agentic checklist

| STRIDE | Meaning | Agentic extension | Evidence to check |
|--------|---------|-------------------|-------------------|
| **S** Spoofing | Impersonate user/agent/MCP | Identity spoofing (AGNT01), prompt hierarchy violation (AGNT06) | `agents/*/AGENT.md` identity, MCP `auth.env`, delegation tables |
| **T** Tampering | Modify data/code/instructions in transit | Tool poisoning (AGNT02), training-data/supply-chain poisoning (LLM03) | `mcp/registry/*.yaml` tool descriptions with imperative injection, `capabilities/upstream.lock` digests |
| **R** Repudiation | Deny action without audit trail | Missing `output-handshake`, Swarm handoff without logging | `output-handshake` gates, `ops/swarm-handoff` audit |
| **I** Information disclosure | Leak secrets/PII via tool output | Data leakage (AGNT04), sensitive info disclosure (LLM06), model theft (LLM10) | `security.network_hosts`, `secret_storage`, scans for `ghp_`, `sk-`, PII |
| **D** Denial of service | Exhaust tokens/compute | Model DoS (LLM04) — unbounded skill context, swarm fan-out | Skill token count, subagent fan-out limits, `docs/research` context audit |
| **E** Elevation of privilege | Gain permissions beyond least privilege | Excessive agency (LLM08), permission creep (AGNT05), insecure plugin design (LLM07) | `approval.default`, `security.dangerous_permissions`, composed skill chain |

Map each finding to STRIDE letter(s) + agentic IDs (`LLM01`–`LLM10`, `AGNT01`–`AGNT06`) where applicable. One finding can map to multiple STRIDE categories (e.g., tool poisoning = T + E).

## Workflow

1. **Discover scope:** Identify assets + trust boundaries + data flows + actors from architecture diagram (or `git diff HEAD` deltas in incremental mode). Enumerate: skills (`skills/**`), agents (`agents/**`), MCP servers (`mcp/registry/*.yaml` + templates), hooks, subagents, external hosts.
2. **Enumerate threats:** For each asset/flow/boundary, apply STRIDE + agentic checklist above. Ask per element: who can spoof? what can be tampered? what lacks repudiation? what leaks? what DoS? what elevates? Add agentic prompts: can tool description inject? can MCP exfiltrate? can agent over-act?
3. **Risk-rank:** Score `Impact` (who/what compromised) × `Likelihood` (Low/Med/High) × `Confidence` (High/Med/Low) → `Severity` Critical/High/Medium/Low (or Blocking/Major/Minor). Cite evidence: `file:line`, registry YAML path, `audit-capability.py` output, diagram node.
4. **Mitigate + acceptance criteria:** Per finding: `mitigation` (least-privilege, pin + provenance, sanitize, gate), `residual risk`, `security acceptance criteria` (testable, e.g., "`tool descriptions contain no imperative injection` via `audit-capability.py` clean"). Apply `output-handshake` before final artifact.
5. **Incremental review:** On architecture change, diff `threat-model.md` previous version: keep unchanged findings, re-evaluate only changed assets/flows. For large systems, shard by trust boundary or swarm agent.

## Risk table shape

| # | Asset / Flow (diagram ref) | Trust boundary | STRIDE | Agentic ID | Threat (observation, file:line) | Attack path (actor → boundary → asset) | Impact | Likelihood | Severity | Confidence | Mitigation | Residual | Acceptance criteria | Evidence |
|---|----------------------------|----------------|--------|------------|----------------------------------|----------------------------------------|--------|------------|----------|------------|------------|----------|---------------------|----------|

Sort by Severity (Critical → Low), then Likelihood. Include `Residual risk` after mitigation.

## Incremental mode

- **Input:** `git diff` + previous `threat-model.md` (from repo `docs/security/threat-model*.md` or prior PR).
- **Behavior:** Carry forward findings for unchanged elements with `status: unchanged`; mark `new`/`updated`/`removed` for deltas; re-rank only affected rows.
- **Swarm-friendly:** Split large architectures by trust boundary (e.g., `user ↔ agent` vs `agent ↔ MCP`) and run parallel subagents; merge tables, dedupe by asset+STRIDE.

## Collaboration

| Need | Delegate to |
|------|-------------|
| System design, C4/Mermaid, ADRs | `architect` / `tech-assistant` — provides `Inputs` architecture diagram |
| App/code vulns (OWASP Web) | `security-reviewer` / `agents/security-reviewer` — consumes threat model for prioritized review |
| Agentic / LLM / MCP / supply-chain | `agentic-security-reviewer` + `agentic-security/owasp-agentic-review` (LLM01-10 + AGNT01-06) — joint risk table |
| Full supply-chain surface | `agentic-security/supply-chain-audit` |
| MCP config/impl depth | `agentic-security/mcp-audit` |
| Output gate | `output-handshake` |
| Swarm decomposition | `ops/swarm-handoff` |

Sequence: `architecture discovery → threat-modeling (this skill) → security review (owasp-agentic + security-reviewer) → security acceptance criteria`.

## Anti-patterns

- Do not hallucinate STRIDE findings without evidence (cite `file:line` or registry path).
- Do not collapse STRIDE into single category — one flow often maps to S+T+E.
- Do not claim full coverage from automated checks alone — mark `Not assessed (requires manual review)` where needed (per #380 a11y analog).
- Do not run full model on every file change — use incremental mode.

## References

- `references/threat-model-template.md` — report template
- Microsoft STRIDE: https://learn.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats
- OWASP Threat Modeling: https://owasp.org/www-project-threat-model/
- OWASP Agentic Security: https://owasp.org/www-project-agentic-security/
- `mcp/registry/*.yaml` + `scripts/audit-capability.py` — static surface
- `architect` / C4/Mermaid (#369) — discovery inputs
