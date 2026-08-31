# ADR-015: Runtime Resource Resolution Order (Amends ADR-005)

**Status:** Accepted  
**Date:** 2026-08-12  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#547](https://github.com/ulises-jeremias/agent-toolkit/issues/547))

## Context

ADR-005 defines Python resolution: env override → wheel/bundled data → XDG cache (optional download) → editable walk-up → CWD. ADR-011 ([#481](https://github.com/ulises-jeremias/agent-toolkit/issues/481)) chooses **hybrid packaging** (embedded baseline + external override). Runtime lookup must be updated for the V binary without leaving two conflicting Accepted orders.

## Relationship to ADR-005

**This ADR formally amends ADR-005** for the V binary-first product. ADR-005 remains the historical record of the Python wheel era. Where they differ, **this ADR wins for V** (and for Python during dual-run only where explicitly mirrored). Packaging layout remains ADR-011.

## Decision — V resolution order

Highest priority first:

1. **Explicit override** — `--data-dir` (when added) or `AGENT_TOOLKIT_ROOT` / `AI_WORKSPACE` if the path contains a valid data root (`skills/` or `profiles/` / packaged data markers as today).
2. **Installed shared / external data** — package-manager share dir or XDG data home populated by install/sync (override layer from hybrid packaging).
3. **Embedded baseline** — resources shipped with the native binary (ADR-011 baseline).
4. **Development repository checkout** — walk-up from process CWD / source tree when running from a git checkout (editable/dev mode).
5. **CWD fallback** — only if it looks like a toolkit root (same safety as ADR-005).

### Offline

`AGENT_TOOLKIT_OFFLINE=1|true|yes` **must not** download. Missing external data falls back to embedded baseline; if baseline is also missing, fail with a clear `ENV` error (ADR-010 taxonomy).

### Channel parity

GitHub binary, PyPI wrapper, Homebrew, AUR, Docker, and source builds must document how they populate (2) and (3) so users do not see accidental behavioral differences.

## Consequences

- **Positive:** Single authoritative V order; ADR-005 not left contradictory; hybrid packaging usable.
- **Negative:** Implementers must port `_paths.py` carefully; tests per channel.
- **Supersession note:** Python wheel path (importlib.resources) maps to **embedded baseline** conceptually under V; do not keep a second published “ADR-005 order” for V docs.

## Validation plan

- Fixtures for each tier winning over lower tiers.
- Offline never hits network ([#557](https://github.com/ulises-jeremias/agent-toolkit/issues/557)).
- Doctor reports which root was selected.

## References

- `docs/adrs/ADR-005-data-packaging.md`
- ADR-011 / [#481](https://github.com/ulises-jeremias/agent-toolkit/issues/481)
- Issue [#547](https://github.com/ulises-jeremias/agent-toolkit/issues/547)
- `packages/.../_paths.py`

**Verified:** 2026-08-12
