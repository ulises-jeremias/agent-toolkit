---
name: cloud-design-patterns
description: WHAT — Vendor-neutral distributed cloud patterns (Retry, Bulkhead, Circuit Breaker, CQRS, Event Sourcing, etc.) abstracted from AWS/Azure/GCP sources — when to apply, tradeoffs, mapping to AWS/GCP/Azure primitives. Offline checklist, no live account required.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '1.0'
  tags:
  - cloud
  - architecture
  - patterns
  - aws
  - distributed
---

# Cloud Design Patterns (WHAT — vendor-neutral)

**Sources (2026-08-12):** AWS Well-Architected `https://docs.aws.amazon.com/wellarchitected/latest/framework/the-pillars-of-the-framework.html` (6 pillars), `https://aws.amazon.com/architecture/well-architected/`; abstracted from Azure Architecture Center cloud design patterns (Circuit Breaker, CQRS, Sidecar etc.) per §43 — do NOT dump Azure catalog verbatim; `https://docs.microsoft.com/en-us/azure/architecture/patterns/`.

> **Pack:** Vendor-neutral `architecture` core (`architect + ADR + TRD + threat-model + mermaid (+ C4)`) stays AWS-neutral. `cloud-architecture` is **optional pack/docs-only** that composes `cloud-design-patterns + aws-well-architected-review + mermaid` on top of `architecture`. See `docs/cloud/research-384-candidates.md` for ADOPT/REJECT + pack semantics (ADR-0003).

## When to use

- Designing distributed system (retry, bulkhead, leader election, saga, event sourcing) without vendor lock.
- Need mapping to AWS/GCP/Azure primitives without dumping provider-specific dump.

## Instructions

1. **Select pattern** from minimal catalog (abstracted): `Retry/Backoff`, `Bulkhead`, `Circuit Breaker`, `CQRS`, `Event Sourcing`, `Saga`, `Sidecar`, `Strangler Fig`, `Leader Election`, `Throttling`.
2. **Evaluate** via Well-Architected lenses: operational excellence, security, reliability, performance, cost, sustainability.
3. **Map** to primitives: e.g., `Retry` → AWS `SQS`+`Lambda` retry, GCP `Cloud Tasks`, Azure `Service Bus`; `Circuit Breaker` → `Resilience4j`/`Polly`/`AWS App Mesh`.
4. Reference `aws-well-architected-review` for pillar check when on AWS; otherwise keep vendor-neutral.

## Anti-patterns

- Do not paste Azure pattern dump verbatim — abstract.
- Do not conflate generic pattern with Terraform/K8s/Helm deployment (those are `official CLI` `terraform`/`kubectl`/`helm` — see research).
