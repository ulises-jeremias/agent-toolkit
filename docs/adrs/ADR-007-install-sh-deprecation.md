# ADR-007: Deprecate scripts/install.sh Behind Python CLI (Thin Wrapper)

**Status:** Accepted  
**Date:** 2026-08-06  
**Deciders:** maintainers (Wave 3 #270, parent #263)

## Context

Two installers exist: `scripts/install.sh` (bash, profile-copy) and `packages/agent-toolkit-cli/src/agent_toolkit/cli/install.py` (Python, `agent-toolkit install`). Dual paths drift — examples still teach `bash install.sh`, `INSTALLATION.md` lists both, and bash lacks the CLI's detection, receipts, and target-aware logic (`installer/sources.py`).

The goal is one consumer install path to reduce support load.

## Decision

**Deprecate `scripts/install.sh` with a warning; do not remove it in this ADR.** Offer a thin-wrapper option for contributors who prefer the bash entrypoint.

- `scripts/install.sh` remains but prints a deprecation notice on every invocation:
  ```
  [warn] scripts/install.sh is deprecated — use `uvx --from agent-toolkit-cli agent-toolkit install` (or `agent-toolkit install` after `uv tool install`). See docs/INSTALLATION.md and docs/adrs/ADR-007-install-sh-deprecation.md
  ```
- **Primary install** is the Python CLI (`uvx` one-liner or `uv tool install`):
  ```bash
  uvx --from agent-toolkit-cli agent-toolkit install
  uvx --from agent-toolkit-cli agent-toolkit install --dry-run
  agent-toolkit install --tools claude-code,cursor --force
  ```
- **Examples and INSTALLATION.md** now point at the Python CLI first; `bash install.sh` is documented under “Legacy / offline fallback” with the deprecation note.
- **Bash as thin caller (optional):** if `agent-toolkit` is on PATH, `install.sh` may delegate to it (preserving flags `--tools`, `--dry-run`, `--force`) while still printing the deprecation warning. Implementation is a small `if command -v agent-toolkit >/dev/null; then exec agent-toolkit install "$@"; fi` guard — out of scope for this ADR's docs-only PR but recorded as the intended wrapper direction.
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
| **Wrapper (optional, next minor)** | v1.4.x | Teach `install.sh` to `exec agent-toolkit install` when available (thin caller), still warning |
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

- `scripts/install.sh`, `packages/agent-toolkit-cli/src/agent_toolkit/cli/install.py`
- `docs/INSTALLATION.md`, `examples/project-onboarding/README.md`, `docs/ARCHITECTURE.md`
- #270 (parent #263)
