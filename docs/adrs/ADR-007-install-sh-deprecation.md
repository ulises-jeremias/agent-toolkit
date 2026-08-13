# ADR-007: Deprecate scripts/install.sh Behind V CLI (Thin Wrapper)

**Status:** Accepted (V-first amendment — see #682)  
**Date:** 2026-08-06  
**Deciders:** maintainers (Wave 3 #270, parent #263)

> **V-first note (2026-08):** Primary consumer path is the native V `agent-toolkit` binary. PyPI remains a launcher channel (ADR-021), not a separate product CLI. Thin wrappers: `scripts/install.sh` → `agent-toolkit install`, `scripts/doctor.sh` → `agent-toolkit doctor`.

## Context

Two installers existed: `scripts/install.sh` (bash, profile-copy) and the product CLI (`agent-toolkit install`). The **product** is the native **V** binary (brew / AUR `agent-toolkit-bin` / GitHub Release); PyPI `agent-toolkit-cli` is a thin launcher over that binary (ADR-021). Dual bash/CLI paths drifted — examples taught `bash install.sh` while INSTALLATION.md moved V-first.

The goal is one consumer install path to reduce support load.

## Decision

**Deprecate `scripts/install.sh` with a warning; do not remove it in this ADR.** Offer a thin-wrapper option for contributors who prefer the bash entrypoint.

- `scripts/install.sh` remains but prints a deprecation notice on every invocation:
  ```
  [warn] scripts/install.sh is deprecated — use `uvx --from agent-toolkit-cli agent-toolkit install` (or `agent-toolkit install` after `uv tool install`). See docs/INSTALLATION.md and docs/adrs/ADR-007-install-sh-deprecation.md
  ```
- **Primary install** is the **V CLI** (`agent-toolkit install`) via brew / AUR / GitHub Release, or the PyPI launcher:
  ```bash
  uvx --from agent-toolkit-cli agent-toolkit install
  uvx --from agent-toolkit-cli agent-toolkit install --dry-run
  agent-toolkit install --tools claude-code,cursor --force
  ```
- **Examples and INSTALLATION.md** point at the V CLI first; `bash scripts/install.sh` is legacy and prints a deprecation warning.
- **Bash as thin caller:** `scripts/install.sh` and `scripts/doctor.sh` `exec` `agent-toolkit install|doctor` when on PATH (P01 / #683); otherwise they fail with channel install hints.
- No removal in this ADR's PR. Removal requires the migration notes in INSTALLATION.md and a deprecation period (see timeline).

## Migration checklist

- [x] Add deprecation `warn` echo at top of `scripts/install.sh` (before `parse_args`)
- [x] Update `docs/INSTALLATION.md` — primary flow is `uvx`/CLI; bash script moved to “Git clone + legacy fallback” with deprecation callout
- [x] Update `examples/project-onboarding/README.md` — replace `bash install.sh` tutorial with `uvx ... install` primary, keep bash as fallback with warning
- [x] Update `docs/ARCHITECTURE.md` L1 layer note (installer is `agent-toolkit install`, not only `scripts/install.sh`)
- [ ] CI: no job change needed (`install.sh` still works); follow-up may add a lint that fails on `bash install.sh` in new docs
- [ ] Removal milestone: v2.0 or next major, after deprecation notice has shipped for one minor

## Timeline

| Phase | Window | Action |
|-------|--------|--------|
| **Deprecate (now)** | v1.3.x | ADR-007 accepted; `install.sh` prints warning; docs point to CLI |
| **Wrapper** | v1.12.x+ | `install.sh` / `doctor.sh` `exec` V CLI when available (thin caller), still warning (#683) |
| **Remove** | v2.0 | Maintainer vote to delete `scripts/install.sh` if CLI covers all needs; keep fallback copy in release notes if offline users need it |

## Alternatives Considered

- **Keep both permanently:** Rejected — doubles support and example maintenance.
- **Immediate removal:** Rejected — breaks offline/git-clone users before migration docs land (violates CMP incrementalism, out of scope per #270).
- **Rewrite bash as full compiler-aware installer:** Rejected — Python CLI already has receipts, detection, and `installer/sources.py` logic; bash wrapper should stay thin.

## Consequences

- **Positive:** One documented consumer path; fewer divergent example code blocks
- **Negative (transitional):** Two paths still work, but the warning makes the preferred path visible
- **Risk:** Users without `uv`/`pip` still rely on bash + `git clone` — fallback remains functional with warning

## References

- `scripts/install.sh`, `packages/pypi/agent-toolkit-cli/src/agent_toolkit/cli/install.py`
- `docs/INSTALLATION.md`, `examples/project-onboarding/README.md`, `docs/ARCHITECTURE.md`
- #270 (parent #263)
