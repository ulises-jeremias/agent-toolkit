# ADR-018: Canonical Release Artifact Format & Naming

**Status:** Accepted  
**Date:** 2026-08-13  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#484](https://github.com/ulises-jeremias/agent-toolkit/issues/484))

## Context

GitHub Release binaries today use unversioned platform suffixes ([#256](https://github.com/ulises-jeremias/agent-toolkit/issues/256), `docs/RELEASING.md`):

- `agent-toolkit-linux-x86_64`
- `agent-toolkit-macos-arm64`
- `agent-toolkit-windows-x86_64.exe`

Native V artifacts are still **experimental** until MUST-platform promotion ([#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562) / [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529) / [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)). Wrappers (PyPI/Homebrew/AUR/npm) must be able to fetch a stable, checksummable name without scraping HTML. A machine-readable manifest is a sibling decision ([#488](https://github.com/ulises-jeremias/agent-toolkit/issues/488)).

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | Keep unversioned platform names only | Today's assets; latest release overwrites the same names. |
| **B** | Versioned archives only | `agent-toolkit-<semver>-<os>-<arch>.tar.gz` (Windows `.zip`); no floating names. |
| **C** | Dual: floating stable names + versioned archives | Unversioned names are the **stable** channel; versioned archives are the checksum/attestation unit. Experimental V uses a distinct prefix. |
| **D** | GoReleaser default (`project_os_arch`) | Adopt Go community names (`linux_amd64`) instead of existing `linux-x86_64`. |

## Decision

Adopt **C**.

### Stable GitHub Release names (do not change without a major)

Retain the existing tokens (OS: `linux` / `macos` / `windows`; arch: `x86_64` / `arm64`):

| Asset | Notes |
|-------|--------|
| `agent-toolkit-linux-x86_64` | ELF; **glibc** ([ADR-019](ADR-019-linux-libc.md)); no extension |
| `agent-toolkit-linux-arm64` | When MUST-platform matrix includes it ([#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529)) |
| `agent-toolkit-macos-arm64` | Mach-O |
| `agent-toolkit-windows-x86_64.exe` | PE; `.exe` required |
| `agent-toolkit-darwin-x86_64` | **Not published** until #256 is explicitly lifted |

These names are the **stable** channel. Experimental native V builds MUST NOT upload over them ([ADR-012](ADR-012-python-v-coexistence.md) / [docs/v/archive/cutover.md](../v/archive/cutover.md)). Experimental prefix: `agent-toolkit-v-experimental-<os>-<arch>` (prerelease GitHub assets only).

### Versioned archives (checksum / SBOM / attestation unit)

Each promoted MUST-platform build also attaches:

```
agent-toolkit-<semver>-<os>-<arch>.tar.gz   # linux, macos
agent-toolkit-<semver>-windows-x86_64.zip
```

Archive contents: one binary named `agent-toolkit` (or `agent-toolkit.exe` on Windows), plus `LICENSE`. Semver matches `VERSION` / the git tag without the leading `v` in the filename (`v1.10.0` tag → `1.10.0` in the archive name).

`SHA256SUMS` and attestations attach to these archives ([#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530)). The floating stable names are copies of the same bytes as the versioned archive’s binary for that tag.

### Manifest

A JSON release manifest (filename and schema) is **[#488](https://github.com/ulises-jeremias/agent-toolkit/issues/488)**, not this ADR. This ADR only requires that whatever #488 chooses can key assets by `{os, arch, channel: stable|experimental, semver}`.

### Rejected

- **A alone** — cannot pin checksums across retags; wrappers need a versioned object.
- **B alone** — breaks existing docs/scripts that fetch unversioned names.
- **D** — renaming `x86_64` → `amd64` and `macos` → `darwin` is a user-visible break without a compatibility win.

## Consequences

- **Positive:** Wrappers and humans keep today’s names; CI/attestation get immutable versioned blobs; experimental V cannot clobber stable.
- **Negative:** Two assets per platform per release (floating + archive). Document both in `docs/RELEASING.md`.
- **Follow-on:** #529 matrix, #531 smoke, #562 experimental spike, #488 manifest, #486/#490/#491 wrappers consume these names (contracts in this repo only).

## Validation plan

- Release workflow (when #529 lands) uploads both floating and versioned names; experimental jobs use the experimental prefix only.
- `docs/RELEASING.md` Asset naming section matches this table.
- Parity/smoke ([#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531)) runs against the binary *inside* the versioned archive, not a random nightly name.

## References

- Issues [#484](https://github.com/ulises-jeremias/agent-toolkit/issues/484), [#256](https://github.com/ulises-jeremias/agent-toolkit/issues/256), [#488](https://github.com/ulises-jeremias/agent-toolkit/issues/488), [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529), [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530), [#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562)
- [ADR-012](ADR-012-python-v-coexistence.md), [ADR-016](ADR-016-versioning-migration.md), [ADR-017](ADR-017-update-ownership.md)
- `docs/RELEASING.md` Asset naming

**Verified:** 2026-08-13
