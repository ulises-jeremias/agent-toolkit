# ADR-017: Package-Manager Ownership vs `update` / Self-Update

**Status:** Accepted  
**Date:** 2026-08-13  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#489](https://github.com/ulises-jeremias/agent-toolkit/issues/489))

## Context

`agent-toolkit update` refreshes **installed profiles / capability data**. The CLI **executable** is also distributed via Homebrew, AUR, npm, PyPI/`uv tool`, and GitHub Release binaries.

Silently replacing `argv[0]` would fight package managers (Homebrew cellar, pacman-owned files, npm prefix, uv tool venvs) and break signature/attestation expectations ([#474](https://github.com/ulises-jeremias/agent-toolkit/issues/474)).

EPIC 4 ([#461](https://github.com/ulises-jeremias/agent-toolkit/issues/461)) already ports capability `update` ([#516](https://github.com/ulises-jeremias/agent-toolkit/issues/516)). This ADR freezes ownership rules before any self-update feature exists.

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | Capability-only `update` | `update` never writes the executable. Package managers own binary upgrades. |
| **B** | Detect ownership; self-update only unmanaged installs | GitHub-release / copied binaries may self-replace; brew/AUR/npm/uv/pipx are refused. |
| **C** | Always self-update (`update` replaces the binary) | One command upgrades code + profiles. |
| **D** | Separate `upgrade` subcommand for the binary | Keep `update` for profiles; add `upgrade` later with ownership checks. |

## Decision

Adopt **A** now, and reserve **D** (with **B**'s ownership checks) as the only allowed future binary-upgrade path.

1. **`agent-toolkit update` is capability update only.** It may refresh toolkit data and profile files. It must not overwrite the running executable, adjacent binaries, or package-manager metadata.
2. **Package managers own the binary.** Homebrew, AUR/pacman, npm, PyPI wheels / `uv tool` / pipx, and Docker images upgrade via those channels. This repo documents contracts (`distribution/` when present); it does not ship foreign PKGBUILD/Formula in this ADR.
3. **No silent self-update.** A future binary upgrade command (not `update`) requires a new implementation issue. It MUST refuse to replace files owned by a package manager. Detection heuristics (non-exhaustive): Homebrew prefix/Cellar; `pacman -Qo`; npm global prefix / `node_modules`; uv tool / pipx home; read-only `/usr` without write intent.
4. **Standalone GitHub Release binaries** are the only class that *may* later opt into self-replace, and only after SHA256/attestation checks ([#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530)) and the threat model ([#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)).

### Rejected

- **C** — mixes content and executable; breaks managed installs.
- **B as the default `update` behavior** — too easy to surprise users who ran `update` expecting profiles.

## Consequences

- **Positive:** Matches shipped Python/V `update` (#516); clear support story; supply-chain upgrades stay in signed package channels.
- **Negative:** Standalone-binary users must re-download releases until a dedicated `upgrade` exists.
- **Follow-on:** Homebrew (#490/#538), AUR (#491/#539), PyPI (#486/#535), npm (#487/#536) integration ADRs/contracts must not teach `agent-toolkit update` as the binary upgrade path.

## Validation plan

- V/Python `update` tests never assert writes to `os.executable()` / `sys.argv[0]`.
- Docs (`docs/v/update.md`, install/uninstall) state capability vs binary ownership.
- Any future `upgrade` issue must cite this ADR and include ownership-refusal tests.

## References

- Issues [#489](https://github.com/ulises-jeremias/agent-toolkit/issues/489), [#516](https://github.com/ulises-jeremias/agent-toolkit/issues/516)
- [ADR-012](ADR-012-python-v-coexistence.md) coexistence / cutover
- [ADR-016](ADR-016-versioning-migration.md) versioning (channels track one SemVer)

**Verified:** 2026-08-13
