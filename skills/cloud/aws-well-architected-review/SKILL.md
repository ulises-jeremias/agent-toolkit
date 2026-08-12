---
name: aws-well-architected-review
description: 'WHAT — AWS Well-Architected Framework review (6 pillars) — operational excellence, security, reliability, performance, cost, sustainability + WAR process. Checklist for workload evaluation on AWS; complementary to official AWS MCP for live account data.'
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - aws
  - well-architected
  - review
  - war
  - cloud
---

# AWS Well-Architected Review (WHAT)

**Sources (2026-08-12):** Framework `https://docs.aws.amazon.com/wellarchitected/latest/framework/the-pillars-of-the-framework.html` + `https://docs.aws.amazon.com/wellarchitected/latest/framework/welcome.html` + `https://aws.amazon.com/architecture/well-architected/`; WAR Tool `https://docs.aws.amazon.com/wellarchitected/latest/userguide/getting-started.html`; MCP `awslabs/mcp` https://github.com/awslabs/mcp + `https://github.com/aws/mcp-proxy-for-aws` GA `https://aws.amazon.com/blogs/aws/the-aws-mcp-server-is-now-generally-available/`; servers `awslabs.core-mcp-server`, `awslabs.well-architected-security-mcp-server 0.1.3`, `awslabs.ecs-mcp-server 0.1.17` `uvx awslabs.*@latest` `AWS_PROFILE`/`AWS_REGION`.

> **Provider hierarchy:** `official MCP` (`awslabs/mcp` family, `mcp-proxy-for-aws` GA) > `custom` prompts for **account-aware** ops (live context, auth via `AWS_PROFILE`/`AWS_REGION`); **prompts** (this skill checklist) remain fallback for offline/low-privilege/CI. See `docs/cloud/research-384-candidates.md`.

## When to use

- Designing or reviewing workload on AWS against 6 pillars.
- Running Well-Architected Review (WAR) without console Tool access.

## Instructions

1. **Run checklist** per pillar: operational excellence (runbooks, observability), security (IAM, encryption, least privilege), reliability (multi-AZ, backup, retry), performance (right-sizing, caching), cost (graviton, S3 lifecycle), sustainability (right-sizing, serverless).
2. **Map** to `cloud-design-patterns` where relevant (e.g., reliability → `Circuit Breaker`).
3. **If live account:** delegate to `awslabs/mcp` (`mcp-proxy-for-aws` or `awslabs.core-mcp-server` `uvx`) for context; else **do NOT** paste `${AWS_*}` secrets — use placeholders `${AWS_PROFILE}`, `${AWS_REGION}`, `${AWS_ACCOUNT_ID}`.
4. Record findings as `High/Medium/Low` risk per pillar and link to lenses/hands-on labs.

## Security

- Must not exfiltrate credentials; use `${AWS_*}` placeholders; mark `aws-well-architected-review` as optional (no vendor lock).
