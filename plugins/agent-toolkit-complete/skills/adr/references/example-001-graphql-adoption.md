# ADR-001: Adopt GraphQL for the Product API

**Status:** Accepted

## Context

The current REST API has accumulated significant complexity as the product domain grew. Multiple frontend clients (web, mobile) are experiencing over-fetching, under-fetching, and fragile coupling to backend structure. The team spends significant time on API versioning and backward compatibility work.

Key constraints:
- Existing REST endpoints cannot be deprecated immediately
- Mobile team needs faster iteration cycles
- Analytics requirements demand a more expressive data querying interface

## Options Considered

### Option A: GraphQL Federation
**Pros:**
- Single coherent graph for all clients
- Type safety and auto-generated docs
- Separate subgraph ownership reduces coupling

**Cons:**
- Higher initial infrastructure complexity
- Requires Apollo Federation or equivalent gateway
- Caching strategies differ from REST patterns

### Option B: REST with JSON:API
**Pros:**
- Team familiarity with REST patterns
- Simpler infrastructure (no gateway needed)
- Easier to cache at CDN level

**Cons:**
- Still requires versioning as domain grows
- Multiple endpoints needed for complex queries
- No built-in type safety or schema

### Option C:渐进式迁移 — Evolve REST to GraphQL incrementally
**Pros:**
- Low risk approach
- Existing clients unaffected during transition
- Can validate GraphQL value before full commitment

**Cons:**
- Longer timeline to realize benefits
- Requires maintaining both API styles temporarily
- Higher total implementation effort

## Decision

Adopt GraphQL with a phased approach: establish a new `/graphql` endpoint alongside existing REST, migrate the product domain first, then expand to other domains as teams gain familiarity.

Rationale: Provides immediate relief for frontend teams while preserving existing investments. The federation model future-proofs architecture for microservices decomposition.

## Consequences

- New `api-gateway` service will be introduced in Q3
- Mobile team leads the product domain migration (most urgent need)
- REST API maintained for backward compatibility until deprecation notice (6-month notice period)
- Existing client SDKs updated to support both endpoints during transition

## References

- [PRD-042: Unified API Strategy](./prd-042-unified-api-strategy.md)
- [Spike-012: GraphQL vs REST evaluation](./spike-012-graphql-evaluation.md)
- Engineering sync 2024-11-15
