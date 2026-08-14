# Agreement: API Versioning Policy

## Agreement Summary

All public APIs will follow semantic versioning with a minimum 6-month deprecation notice before breaking changes. Version support windows are tied to major versions.

## Parties Involved

- Platform Team (API owners)
- All consuming service teams
- Product Management (for public API consumers)

## Terms and Conditions

1. **Version numbering:** Follows `MAJOR.MINOR.PATCH` semantic versioning
2. **Breaking changes:** Require a new major version with 6-month overlap period
3. **Deprecation notice:** Written notice in API response headers and changelog minimum 6 months before EOL
4. **Sunset timeline:** Major versions receive security patches for 18 months from release, then EOL
5. **Version discovery:** `/versions` endpoint lists supported versions with EOL dates

## Date and Validity

- Start Date: 2024-01-01
- Review / Due Date: 2025-07-01 (first review)

## References / Linked Work Items

- [ADR-003: API Versioning Standard](./adr-003-api-versioning.md)
- [TRD-007: Platform API Migration](./trd-007-platform-api-migration.md)
