# Documentation

## Source of truth

| Audience | Canonical docs | Notes |
| --- | --- | --- |
| Consumers | `README.md`, `docs/INSTALLATION.md`, `docs/UNINSTALL.md`, `docs/MIGRATION.md`, `docs/TRUST_BOUNDARIES.md` | Prefer these over wiki mirrors |
| Contributors | `CONTRIBUTING.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/HOW_TO_DEVELOP_V.md`, `docs/HOW_TO_ADD_SKILL.md` | V owns domain behavior and the backend; Electron + React owns Desktop presentation |
| Architecture | `docs/CONCEPTS.md` (short model) → `docs/ARCHITECTURE.md` (canonical) | Engine/backend, CLI and Desktop ownership; `CONCEPTS.md` is the quick orientation |
| Desktop product | [`docs/desktop/README.md`](desktop/README.md), `PRODUCT_VISION.md`, `USER_JOURNEYS.md`, `workflows.yaml` | The Desktop guide is the entry point; the workflow file records verified GUI journeys and gaps; `VISUAL_QA.md` records opened screenshot evidence; README product images are real PNG captures |
| ADRs | `docs/adrs/` (single directory, 40 records) | `ADR-001…036` + `0001…0004` — see `docs/adrs/README.md` |
| V migration | [`docs/v/README.md`](v/README.md), [`docs/RELEASING.md`](RELEASING.md), [`distribution/`](../distribution/README.md) | Native binary is canonical; Python is launcher only |
| Distribution | `distribution/` (channel contracts) vs `distributions/` (compiler input) | One letter apart — see `distribution/README.md:17` |
| Target matrix | `docs/TARGETS.md`, `docs/targets/*-certification.md` | |
| Research / historical | `docs/research/`, `docs/archive/`, [`docs/desktop/design-notes/`](desktop/design-notes/README.md), `docs/desktop/VISUAL_QA_HISTORY.md`, `docs/desktop/WORKSTATION_REFERENCE_ANALYSIS.md` | Historical material is kept for provenance; current product guides and contracts take precedence |

When `docs/` and `docs/wiki/` disagree, **`docs/` wins**. Wiki pages are **indexes** that should link here — not a second catalog. Update or delete a wiki page in the same PR if it duplicates or contradicts `docs/` (#101).

## Find a guide

Choose the path that matches what you want to do:

| You want to… | Start here |
| --- | --- |
| Install Agent Toolkit and make the first capability useful | [Getting Started](GETTING_STARTED.md) |
| Understand the CLI, backend and ownership boundaries | [Concepts](CONCEPTS.md) → [Architecture](ARCHITECTURE.md) |
| Use the Desktop spatial workspace | [Agent Toolkit Desktop](desktop/README.md) |
| Build, test, package, or capture Desktop | [Desktop package guide](../apps/desktop/README.md) → [visual QA](desktop/VISUAL_QA.md) |
| Configure durable People and understand live sessions | [People](PEOPLE.md) |
| Start, observe or recover a swarm | [Swarm guide](SWARMS.md) → [Swarm recipes](SWARM_RECIPES.md) |
| Run or schedule recurring workflows | [Loops](LOOPS.md) |
| Configure MCP providers safely | [MCP](MCP.md) → [Trust boundaries](TRUST_BOUNDARIES.md) |
| Contribute or change the V backend | [Contributing](../CONTRIBUTING.md) → [V development](HOW_TO_DEVELOP_V.md) |

The Desktop guide links to current product screenshots and the executable
workflow ledger. The ledger is authoritative for functional coverage; the
design contract and latest opened screenshot review govern visual direction
and evidence. The old native V GUI has no source files in the current product;
ADR-032 and its migration-era notes remain only to explain the architectural
decision captured by ADR-033. Historical research and archived reviews are
kept for provenance and are not current implementation guidance.
