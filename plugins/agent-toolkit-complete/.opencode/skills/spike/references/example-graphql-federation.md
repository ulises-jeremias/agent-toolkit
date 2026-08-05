# SPIKE-012: GraphQL Federation Evaluation

## Purpose

Evaluate GraphQL Federation as the future API architecture for the platform. Assess feasibility, team readiness, and infrastructure requirements before committing to a migration path.

**Spike Ticket:** ARCH-018

## Findings and Conclusions

GraphQL Federation is viable for the platform and recommended for adoption. The team has sufficient backend expertise; frontend teams have expressed strong interest. Infrastructure exists to support the gateway. The main risk is the learning curve for distributed schema ownership.

**Decision recommended:** Proceed with phased adoption starting with the product domain.

### Architecture Fit (if applicable)

| Layer / Area | Purpose / Role | Tools / Services | Notes |
| --- | --- | --- | --- |
| API Gateway | Schema routing, query planning | Apollo Federation v2 | Supports REST passthrough during migration |
| Product Subgraph | Product domain data | GraphQL Nexus + Prisma | Team owns this subgraph |
| User Subgraph | User and session data | GraphQL Nexus | Owned by Auth team |
| Inventory Subgraph | Stock levels, warehouse | REST (existing) → GraphQL | Low priority; can remain REST behind Apollo |
| Clients | Web (React), Mobile (React Native) | Apollo Client 3 | Both support Federation |

## High-Level Implementation Strategy

### Components / Layers

1. **Gateway layer:** Deploy Apollo Gateway as `/graphql` endpoint; existing `/api/v1` REST remains available
2. **Product subgraph:** Migrate from REST to GraphQL first; establishes pattern for other teams
3. **Client migration:** Update Apollo Client to use GraphQL; maintain REST fallback during transition
4. **Auth integration:** User subgraph implemented by Auth team; timeline TBD

### Phase 1 (Weeks 1-6)

- Gateway + Product subgraph
- REST backward compatibility maintained
- Mobile team as early adopter

### Phase 2 (Weeks 7-12)

- Expand to other domains (orders, customers)
- Deprecate REST endpoints with 6-month notice

## Security, Governance, or Compliance Considerations

- Access controls: Field-level auth via JWT claims in GraphQL context
- Auditability: GraphQL operation logging to Datadog (query, variables, user ID)
- Sensitive data handling: PII fields marked with `@auth` directive; rate limiting per client ID

## Start Small, Scale Fast

- **First safe step:** Deploy gateway with Product subgraph only; no client traffic yet
- **Deferred work:** Auth subgraph, order history, mobile-optimized queries

## Research Notes / Tradeoffs

| Option | Pros | Cons | Notes |
| --- | --- | --- | --- |
| GraphQL Federation | Expressive queries, type safety, single graph | More infra, learning curve, caching harder | Recommended |
| REST with JSON:API | Simple, CDN-cacheable, team familiarity | Versioning complexity, over-fetching | Rejected — does not solve core pain points |
| gRPC | Performance, binary protocol | Not browser-native, mobile support weak | Rejected for client-facing; consider for service-to-service |

## Open Questions

1. Auth team bandwidth for User subgraph? Status: Open — meeting scheduled Jan 30
2. Existing REST endpoint deprecation timeline? Status: Open — PM to define
3. GraphQL schema registry tooling? Status: Answered — Apollo Studio with schema checks in CI

## References

- [PRD-042: Unified API Strategy](./prd-042-unified-api-strategy.md)
- Apollo Federation docs: https://www.apollographql.com/docs/federation/
- Engineering sync notes 2024-01-15

## Review

- [ ] Destination confirmed.
- [ ] Human review required.
