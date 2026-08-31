# TRD-007: Platform API Migration

## Scope

Migrate the legacy REST API surface (`/api/v1/products`, `/api/v1/orders`, `/api/v1/users`) into a new GraphQL Federation layer. This covers the gateway setup, product domain migration, client migration, and deprecation of legacy endpoints.

**Out of scope:** User and Order domain migrations (Phase 2), Auth service changes.

## Architecture Overview

```
Client (Web/Mobile)
       ↓
  Apollo Gateway  ←  /graphql endpoint
       ↓
┌──────────┬──────────────┐
│Product   │  Legacy REST │  (future: additional subgraphs)
│Subgraph  │  /api/v1/*   │
└──────────┴──────────────┘
```

- **Apollo Gateway** runs as a separate service (`api-gateway`) on `gateway.svc.internal:4000`
- **Product Subgraph** implemented in `product-service` (Node.js + GraphQL Nexus)
- **Legacy REST** continues serving `/api/v1/*` during transition period
- Gateway is the single entry point; clients updated to call `/graphql` exclusively

## Data Model / API Contracts

### Product Entity (GraphQL)

```graphql
type Product {
  id: ID!
  name: String!
  category: Category!
  pricing: PriceInfo!
  inventory: InventoryStatus!
  media: [MediaItem!]!
  relatedProducts: [Product!]!
}

type Category {
  id: ID!
  name: String!
  parent: Category
  attributes: [Attribute!]!
}

type PriceInfo {
  amount: Float!
  currency: String!
  discountedAmount: Float
  validFrom: DateTime
  validTo: DateTime
}
```

### REST Legacy Contract (to be deprecated)

```json
GET /api/v1/products?category=&sort=&include=
{
  "products": [...],
  "pagination": { "total": 0, "page": 1, "per_page": 20 }
}
```

Legacy contract must remain functional until 6-month deprecation notice expires.

## Technical Decisions

- [ADR-003: API Versioning Standard](./references/adr-003-api-versioning.md) — Gateway versioning approach
- [SPIKE-012: GraphQL Federation Evaluation](./references/spike-012-graphql-evaluation.md) — Chosen over REST with JSON:API

## Dependencies

| Dependency | Owner | Status | Notes |
|---|---|---|---|
| Apollo Federation v2 | Platform | Ready | License confirmed |
| Product service GraphQL schema | Backend Team A | In Progress | ETA: Week 3 |
| Client SDK update (Apollo Client 3) | Frontend Team | Not Started | Handoff: Week 5 |
| Staging environment for gateway | SRE/Infra | Not Started | Request submitted |

## Risks & Constraints

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Staging env not ready by Week 3 | Medium | High | Follow up with Infra by Jan 23; fall back to manual testing |
| Client migration delays | Medium | Medium | Maintain `/api/v1` in parallel during transition |
| Schema drift between subgraphs | Low | High | Schema checks in CI before merge |
| Auth team bandwidth for User subgraph | High | Medium | ADR to propose User subgraph deferral to Phase 2 |

## Testing Strategy

1. **Unit tests:** GraphQL resolvers tested with Jest; schema validation with `graphql剑法` import validation
2. **Integration tests:** Apollo Gateway integration tests with product subgraph; use staging environment
3. **Contract tests:** Use Apollo Studio contract checks in CI to prevent breaking changes
4. **E2E tests:** Playwright tests for product listing and detail pages (critical user flows)
5. **Performance:** Lighthouse for page load; Datadog RUM for real-user metrics post-deploy

## Implementation Plan

### Phase 1 (Weeks 1-4): Gateway + Product Subgraph

- Week 1: Gateway service setup; local dev environment
- Week 2: Product subgraph implementation; schema design review
- Week 3: Gateway + subgraph integration in staging; test client (Postman/Insomnia)
- Week 4: Internal dogfood; Frontend team onboards to test client

### Phase 2 (Weeks 5-8): Client Migration + Search

- Week 5: Frontend team updates Apollo Client; web app points to `/graphql`
- Week 6: Mobile team migration (React Native Apollo Client 3)
- Week 7: Search endpoint migration (faceted search with aggregations)
- Week 8: Remove REST from web client; staging clean

### Phase 3 (Weeks 9-12): Legacy Deprecation + Monitoring

- Week 9: Publish GraphQL Explorer in Confluence; announce deprecation
- Week 10-12: Monitor error rates; collect usage metrics on legacy endpoints
- Week 12: Issue 6-month deprecation notice for `/api/v1` (if not already done)
- Ongoing: Phase 2 domains (Orders, Users) tbd based on Phase 1 learnings
