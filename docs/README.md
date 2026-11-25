# Documentation

Agent Toolkit's current scope is portable capabilities and CLI tooling. Veasel
Code owns the supported coding application. The former Electron source and its
design documents are archival migration evidence, not current product contracts;
see the [preservation and migration map](LEGACY_DESKTOP_MIGRATION.md) before
removing or migrating any code or user data.

## Source of truth

| Audience | Canonical docs | Notes |
| --- | --- | --- |
| Consumers | `README.md`, `docs/INSTALLATION.md`, `docs/UNINSTALL.md`, `docs/MIGRATION.md`, `docs/TRUST_BOUNDARIES.md` | Prefer these over wiki mirrors |
| Contributors | `CONTRIBUTING.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/HOW_TO_DEVELOP_V.md`, `docs/HOW_TO_ADD_SKILL.md` | Agent Toolkit owns portable capabilities and their CLI; Veasel Code owns the supported coding application and shared session runtime |
| Architecture | `docs/CONCEPTS.md` (short model) → `docs/ARCHITECTURE.md` (canonical) | Portable capability, CLI automation, and Veasel Code ownership boundaries |
| Veasel Code | [Veasel Labs/Veasel](https://github.com/veasel-labs/veasel) | Supported TUI + Desktop product, designed around one backend; packaged shared-session acceptance remains tracked in [#550](https://github.com/veasel-labs/veasel/issues/550) |
| Former Toolkit Desktop | [`docs/VEASEL_COMPATIBILITY.md`](VEASEL_COMPATIBILITY.md), [`docs/desktop/README.md`](desktop/README.md) | Historical Electron source and evidence only; no new Toolkit installers or product features |
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
| Use a graphical or terminal coding app | [Veasel Code](https://github.com/veasel-labs/veasel) |
| Review former Toolkit Desktop data boundaries | [Veasel compatibility and retirement](VEASEL_COMPATIBILITY.md) |
| Preserve former Toolkit People records | [People data compatibility](PEOPLE.md) |
| Inspect or safely stop an old Swarm v1 run | [Swarm v1 disposition](SWARM_V1_DISPOSITION.md) |
| Run or schedule recurring workflows | [Loops](LOOPS.md) |
| Configure MCP providers safely | [MCP](MCP.md) → [Trust boundaries](TRUST_BOUNDARIES.md) |
| Understand upstream capability updates and human trust review | [Upstream synchronization](UPSTREAM_SYNC.md) → [Trust and provenance](TRUST.md) |
| Contribute or change the V backend | [Contributing](../CONTRIBUTING.md) → [V development](HOW_TO_DEVELOP_V.md) |

The `docs/desktop/` and `apps/desktop/` trees describe a former Electron
application. Their screenshots and workflow records are historical evidence,
not current Veasel acceptance. Veasel's own repository is authoritative for
current product behavior, release status, and shared-session evidence.

Swarm v1 recipe and adapter pages are historical references. Current Toolkit
builds reject new Swarm runs; start with the
[disposition page](SWARM_V1_DISPOSITION.md) if an old run's state must be
inspected or recovered.
