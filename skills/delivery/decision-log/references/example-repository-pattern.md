# Decision: Migrate from Monolithic ORM to Repository Pattern

## Decision

Replace the active-record style ORM with a repository pattern that separates data access from business logic. This will happen incrementally, starting with the `orders` and `payments` domains.

## Rationale

The current ORM couples domain logic directly to database schemas, making unit testing difficult and creating hidden dependencies. The repository pattern enables better testability, clearer domain boundaries, and reduces the risk of schema changes rippling through business logic.

## Date

2024-02-15

## Responsible

Backend Platform Team

## References / Linked Work Items

- [TRD-011: Data Access Layer Refactoring](./trd-011-data-access-layer.md)
- Epic-142: Database Migration Phase 2

## Review

- [ ] Destination confirmed.
- [ ] Human review required.
