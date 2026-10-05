# Documentation

## Source of truth

| Audience | Canonical docs | Notes |
|----------|----------------|-------|
| Consumers | `README.md`, `docs/INSTALLATION.md`, `docs/UNINSTALL.md`, `docs/MIGRATION.md`, `docs/TRUST_BOUNDARIES.md` | Prefer these over wiki mirrors |
| Contributors | `CONTRIBUTING.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/HOW_TO_DEVELOP_V.md`, `docs/HOW_TO_ADD_SKILL.md` | V CLI first; Python is launcher/tests only |
| Architecture | `docs/CONCEPTS.md` (short model) → `docs/ARCHITECTURE.md` (canonical) | Engine/backend, CLI and Desktop ownership; `CONCEPTS.md` is the quick orientation |
| Desktop product | `docs/desktop/PRODUCT_VISION.md`, `docs/desktop/USER_JOURNEYS.md`, `docs/desktop/workflows.yaml` | The workflow ledger records verified GUI journeys and open gaps; `VISUAL_QA.md` records screenshot evidence |
| ADRs | `docs/adrs/` (single directory, 40 records) | `ADR-001…036` + `0001…0004` — see `docs/adrs/README.md` |
| V migration | [`docs/v/README.md`](v/README.md), [`docs/RELEASING.md`](RELEASING.md), [`distribution/`](../distribution/README.md) | Native binary is canonical; Python is launcher only |
| Distribution | `distribution/` (channel contracts) vs `distributions/` (compiler input) | One letter apart — see `distribution/README.md:17` |
| Target matrix | `docs/TARGETS.md`, `docs/targets/*-certification.md` | |
| Research / historical | `docs/research/`, `docs/wiki/` | Wiki pages may lag; treat as mirrors until sync |

When `docs/` and `docs/wiki/` disagree, **`docs/` wins**. Wiki pages are **indexes** that should link here — not a second catalog. Update or delete a wiki page in the same PR if it duplicates or contradicts `docs/` (#101).
