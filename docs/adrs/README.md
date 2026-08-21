# Architecture Decision Records

This repository keeps **two ADR trees**. Do **not** merge them.

| Tree | Path | Purpose |
|------|------|---------|
| **Engineering ADRs** | [`docs/adrs/ADR-0xx-*.md`](./) | Implementation / packaging / CLI architecture (V migration, installers, schemas, release channels) |
| **Product / pack semantics ADRs** | [`docs/adr/000x-*.md`](../adr/) | Capability declaration, pack/product meaning, assessment units |

## Engineering ADRs (`docs/adrs/`)

Numbered `ADR-001` … `ADR-026`. Status is in each file header.

| ADR | Title |
|-----|-------|
| [ADR-001](ADR-001-canonical-ir.md) | Canonical IR |
| [ADR-002](ADR-002-windsurf-bundle.md) | Windsurf bundle |
| [ADR-003](ADR-003-retire-gen-surfaces.md) | Retire gen-surfaces |
| [ADR-004](ADR-004-profiles-vs-plugins.md) | Profiles vs plugins |
| [ADR-005](ADR-005-data-packaging.md) | Data packaging |
| [ADR-006](ADR-006-packs-docs-only.md) | Packs docs-only |
| [ADR-007](ADR-007-install-sh-deprecation.md) | install.sh deprecation / removal |
| [ADR-008](ADR-008-swarm-orchestration.md) | Swarm orchestration |
| [ADR-009](ADR-009-v-module-architecture.md) | V module architecture |
| [ADR-010](ADR-010-cli-core-boundary.md) | CLI / core boundary |
| [ADR-011](ADR-011-resource-packaging.md) | Resource packaging |
| [ADR-012](ADR-012-python-v-coexistence.md) | Python / V coexistence (cutover completed) |
| [ADR-013](ADR-013-yaml-strategy.md) | YAML strategy |
| [ADR-014](ADR-014-schema-validation.md) | Schema validation |
| [ADR-015](ADR-015-runtime-resolution.md) | Runtime resolution |
| [ADR-016](ADR-016-versioning-migration.md) | Versioning migration |
| [ADR-017](ADR-017-update-ownership.md) | Update ownership |
| [ADR-018](ADR-018-release-artifacts.md) | Release artifacts |
| [ADR-019](ADR-019-linux-libc.md) | Linux libc |
| [ADR-020](ADR-020-v-concurrency.md) | V concurrency |
| [ADR-021](ADR-021-pypi-binary.md) | PyPI binary / launcher |
| [ADR-022](ADR-022-release-manifest.md) | Release manifest |
| [ADR-023](ADR-023-homebrew.md) | Homebrew |
| [ADR-024](ADR-024-aur.md) | AUR |
| [ADR-025](ADR-025-npm-binary.md) | npm binary |
| [ADR-026](ADR-026-full-embed.md) | Full embed |

## Product / pack semantics ADRs (`docs/adr/`)

Numbered `0001` … `0004`. These define *what* products/packs/capabilities mean for consumers and assessment — not the V CLI packaging story.

| ADR | Title |
|-----|-------|
| [0001](../adr/0001-capability-declaration-and-external-provenance-lock.md) | Capability declaration and external provenance lock |
| [0002](../adr/0002-design-assessment-as-design-unit.md) | Design assessment as design unit |
| [0003](../adr/0003-pack-semantics-products-own-installation.md) | Pack semantics — products own installation |
| [0004](../adr/0004-capability-provider-abstraction-what-vs-how.md) | Capability provider abstraction (what vs how) |

When writing a new decision: put engineering/implementation choices under `docs/adrs/`; put product/pack semantics under `docs/adr/`.
