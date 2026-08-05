# PRD-042: Unified API Strategy

## Objective

Consolidate the current fragmented API landscape (4 REST endpoints, 2 legacy SOAP services, and 1 internal gRPC interface) into a unified, versioned API surface that supports frontend and mobile clients with a single, coherent interface. This enables faster iteration, reduces backend coupling, and provides the foundation for a future GraphQL federation layer.

## User Flow / Personas

**Primary Users:**
- Frontend developers building product pages (web and mobile)
- Mobile team requiring low-latency, expressive queries
- Partner integrations consuming the public API

**User Flow:**
1. Client sends query to unified endpoint (REST or GraphQL)
2. Gateway validates request and routes to domain service
3. Domain service returns typed response through API layer
4. Client receives consistent, versioned response

## Entities & Use Cases

**Core Entities:**
- Product (id, name, category, pricing, inventory, media)
- Category (id, name, parent, attributes, metadata)
- User (id, roles, preferences, session)
- Order (id, user, items, status, fulfillment)

**Primary Use Cases:**
- UC-1: Fetch product details with category hierarchy
- UC-2: Search products by filters and sort options
- UC-3: Fetch related products or accessories
- UC-4: Aggregate analytics data per product

## Acceptance Criteria

- [ ] `/api/v1/products` returns product list with pagination
- [ ] `/api/v1/products/:id` returns full product details with media URLs
- [ ] `?category=` filter supports hierarchical category traversal
- [ ] `?include=related` embeds related products in response
- [ ] Response schema is documented in OpenAPI 3.1
- [ ] Version header (`API-Version: 1`) accepted on all requests
- [ ] Deprecation notice returned in headers for versions with EOL within 6 months

## Edge Cases

- Category filter returns empty set: return empty array with 200, not error
- Product not found: return 404 with error schema `{code, message, request_id}`
- Invalid include parameter: return 400 with valid values in error message
- Rate limit exceeded: return 429 with `Retry-After` header

## Integrations

- Inventory Service (gRPC): for real-time stock levels
- Pricing Service (REST): for dynamic pricing rules
- Analytics Platform (Kafka): for event emission on product views

## Timeline

- Phase 1 (Weeks 1-4): API Gateway setup + `/products` endpoint migration
- Phase 2 (Weeks 5-8): Search and filter endpoints
- Phase 3 (Weeks 9-12): Deprecate legacy endpoints; publish GraphQL

## Approvals

- VP Engineering: Elena Vasquez — 2024-01-15
- Product Lead: Marcus Chen — 2024-01-16

## Related

- [TRD-007: Platform API Migration](./trd-007-platform-api-migration.md)
- [ADR-003: API Versioning Standard](./adr-003-api-versioning.md)
