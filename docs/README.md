# Documentation

## Source of truth

| Audience | Canonical docs | Notes |
|----------|----------------|-------|
| Consumers | `README.md`, `docs/INSTALLATION.md`, `docs/UNINSTALL.md`, `docs/MIGRATION.md`, `docs/TRUST_BOUNDARIES.md` | Prefer these over wiki mirrors |
| Contributors | `CONTRIBUTING.md`, `AGENTS.md`, `docs/ARCHITECTURE.md`, `docs/HOW_TO_DEVELOP_V.md`, `docs/HOW_TO_ADD_SKILL.md` | V CLI first; Python is launcher/tests |
| V migration | [`docs/v/README.md`](v/README.md), [`docs/RELEASING.md`](RELEASING.md), [`distribution/`](../distribution/README.md) | Native binary is canonical; Python is launcher/fallback |
| Target matrix | `docs/TARGETS.md`, `docs/targets/*-certification.md` | |
| Research / historical | `docs/research/`, `docs/wiki/` | Wiki pages may lag; treat as mirrors until sync |

When `docs/` and `docs/wiki/` disagree, **`docs/` wins**. Update or delete the wiki page in the same PR (#101).
