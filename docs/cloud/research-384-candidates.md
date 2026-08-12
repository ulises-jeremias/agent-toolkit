# Research: Cloud + AWS Well-Architected — #384 (2026-08-12)

**Purpose:** Evidence-based cloud capability per §43: AWS Well-Architected 6 pillars vs generic distributed patterns, AWS MCP ecosystem vs prompts, vendor-neutral `architecture` vs optional `cloud-architecture` pack.

## Findings

### AWS Well-Architected Framework (6 pillars)
- **Source:** `https://docs.aws.amazon.com/wellarchitected/latest/framework/the-pillars-of-the-framework.html` + `https://aws.amazon.com/architecture/well-architected/` + `https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html` (official AWS docs, authoritative).
- **Pillars:** operational excellence, security, reliability, performance efficiency, cost optimization, sustainability (+ domain lenses, hands-on labs, Well-Architected Tool free in console).
- **WAR process:** Well-Architected Review (workload evaluation, high-risk identification, improvement tracking).
- **Dates:** 2026-08-12 verified.

### AWS MCP ecosystem (official)
- **Repos:** `awslabs/mcp` monorepo https://github.com/awslabs/mcp — 20+ servers (e.g., `awslabs.core-mcp-server` `uvx awslabs.core-mcp-server@latest`, `awslabs.aws-serverless-mcp-server` `awslabs.aws-serverless-mcp-server@latest` PyPI `awslabs.aws-serverless-mcp-server 0.1.18`, `awslabs.ecs-mcp-server 0.1.17`, `awslabs.well-architected-security-mcp-server 0.1.3`, `awslabs.aws-bedrock-custom-model-import-mcp-server`, `mcp-proxy-for-aws` https://github.com/aws/mcp-proxy-for-aws generally available).
- **Docs:** `https://aws.amazon.com/blogs/machine-learning/introducing-aws-mcp-servers-for-code-assistants-part-1/` (Part 1), `https://aws.amazon.com/blogs/aws/the-aws-mcp-server-is-now-generally-available/` (GA), `https://awslabs.github.io/mcp/servers/...` per-server config (mcpServers `command: uvx` `args: [awslabs.*@latest]`, env `AWS_PROFILE`, `AWS_REGION`).
- **License/Maintenance:** Apache-2.0 (awslabs), active 2026-08-12.
- **Versus prompts:** MCP provides live account context (projects, deployments via proxy) and tool-enforced auth (`AWS_PROFILE`/`AWS_REGION`), lower context overhead than pasting docs, but requires `uvx` + credentials. Prompts (Well-Architected checklist as Markdown) remain valuable offline/low-privilege; MCP is superior for account-aware ops (e.g., CloudTrail analysis via `awslabs.cloudtrail-mcp-server`).

### cloud-design-patterns (generic distributed)
- **Candidates:** Microsoft `Azure Architecture Center` cloud design patterns (e.g., `Circuit Breaker`, `CQRS`, `Sidecar`, 30+ patterns) — high quality but **Azure-oriented** per §43 warning; `AWS Well-Architected` lenses already cover distributed concerns vendor-neutral when abstracted; community `cloud-design-patterns` skills (generic) often paraphrase Microsoft without adding value.
- **Evaluation:** Do NOT dump Azure-pattern catalog verbatim into generic cloud skill — abstract to vendor-neutral primitives (e.g., `Retry`, `Bulkhead`, `Leader Election`, `Event Sourcing`) with AWS/GCP/Azure mapping notes, or reference Well-Architected reliability pillar.
- **Existing Toolkit:** No `skills/cloud/` domain; `docs/ARCHITECTURE.md` has manual Mermaid but no pattern catalog.

### Terraform / K8s / Helm
- **Official:** Terraform via `hashicorp/terraform` CLI (`terraform` Apache-2.0/MPL) + `opentofu`; K8s via `kubectl` (Apache-2.0); Helm via `helm` (Apache-2.0). Community MCPs exist (e.g., `awslabs.eks-mcp-server` wraps K8s) but are thin wrappers over CLI — not high-value as separate skills vs `mcp/registry` entries + docs fallback.
- **Decision:** REJECT standalone Terraform/K8s/Helm skills for now — IaC deployment automation is out-of-scope per issue; `cloud-design-patterns` can reference them as implementation hints, and AWS MCP `core`/`ecs`/`serverless` already cover deployment primitives when needed.

## Decisions (ADOPT/REJECT + pack semantics)

| Candidate | Verdict | Rationale | Provider hierarchy |
|-----------|---------|-----------|---------------------|
| `cloud-design-patterns` | **ADOPT** (first-party) | Minimal vendor-neutral catalog of distributed patterns (abstracted from Azure/AWS, not dumped) — stable verbs, low churn | `custom` prompt > `community MCP` (no superior official MCP for generic patterns) |
| `aws-well-architected-review` | **ADOPT** (first-party) | 6-pillar checklist + WAR process as Markdown workflow, offline-friendly; AWS MCP complementary for live account data | `official MCP` (`awslabs/mcp` family, `mcp-proxy-for-aws`) > `custom` prompts for account-aware ops; prompts remain fallback for offline/low-privilege |
| Terraform / K8s / Helm standalone | **REJECT** | Thin CLI wrappers, out-of-scope full IaC automation; covered via `cloud-design-patterns` hints + existing AWS MCPs | `official CLI` (`terraform`/`kubectl`/`helm`) > `community MCP` — keep as CLI, not skill |
| Generic Azure-pattern dump | **REJECT** | Violates §43 — Azure-oriented, not abstracted | — |

**Pack semantics (ADR-0003 + ADR-0004):**
- Keep `architecture` **vendor-neutral**: `architect + ADR + TRD + threat-model + mermaid (+ C4 via mermaid)` — no AWS-specific content.
- Make `cloud-architecture` **optional pack/docs-only** (not compiler-wired) that composes `cloud-design-patterns + aws-well-architected-review + mermaid` on top of `architecture` core. `distributions/products.yaml` stays sole compiler input; packs remain docs-only per ADR-0003 (future `install --preset` not pack compiler change). This satisfies "cloud optional, architecture stays AWS-neutral".
- **AWS MCP vs prompts decision documented above:** prefer official MCP (`awslabs/mcp`, `mcp-proxy-for-aws`, GA) where it provides better mechanism than prompts (account-aware, auth via `AWS_PROFILE`/`AWS_REGION`, low context), otherwise prompts (Well-Architected checklist) for offline/vendor-neutral.

**Security:** Cloud skills must not exfiltrate credentials; use `${AWS_*}` placeholders; mark cloud as optional (no vendor lock). No shell/network beyond docs reference.

**Risks/tradeoffs:** MCP requires `uvx` + creds + internet — keep prompt fallback for CI/offline; Well-Architected Tool is console-only — skill bridges via checklist; abstracted patterns risk over-generic — mitigate via concrete AWS/GCP/Azure mapping table and link to official pillars.

**Next:** Add `skills/cloud/cloud-design-patterns/` + `skills/cloud/aws-well-architected-review/` as first-party; update `packs/` docs (optional cloud-architecture) deferred to #390.
