# Documentation

## Source of truth

| Audience | Canonical docs | Notes |
|----------|----------------|-------|
| Consumers | `README.md`, `docs/INSTALLATION.md`, `docs/UNINSTALL.md`, `docs/MIGRATION.md`, `docs/TRUST_BOUNDARIES.md` | Prefer these over wiki mirrors |
| Contributors | `CONTRIBUTING.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/HOW_TO_DEVELOP_V.md`, `docs/HOW_TO_ADD_SKILL.md` | V CLI first; Python is launcher/tests only |
| V migration | [`docs/v/README.md`](v/README.md), [`docs/RELEASING.md`](RELEASING.md), [`distribution/`](../distribution/README.md) | Native binary is canonical; Python is launcher only |
| Target matrix | `docs/TARGETS.md`, `docs/targets/*-certification.md` | |
| Research / historical | `docs/research/`, `docs/wiki/` | Wiki pages may lag; treat as mirrors until sync |

When `docs/` and `docs/wiki/` disagree, **`docs/` wins**. Wiki pages are **indexes** that should link here — not a second catalog. Update or delete a wiki page in the same PR if it duplicates or contradicts `docs/` (#101).
