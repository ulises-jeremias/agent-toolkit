# ADR-024: AUR `agent-toolkit-bin` consumes GitHub Release V binaries

**Status:** Accepted  
**Date:** 2026-08-13  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#491](https://github.com/ulises-jeremias/agent-toolkit/issues/491))

## Context

Canonical AUR packaging lives in [`ulises-jeremias/aur-packages`](https://github.com/ulises-jeremias/aur-packages) — this repo MUST NOT copy a PKGBUILD ([#534](https://github.com/ulises-jeremias/agent-toolkit/issues/534) / [#539](https://github.com/ulises-jeremias/agent-toolkit/issues/539)). The current `agent-toolkit` PKGBUILD builds a **Python wheel** from the GitHub source tarball. After [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555) Arch users should install the native V binary.

Implementation PR: [aur-packages#6](https://github.com/ulises-jeremias/aur-packages/pull/6) (issue [aur-packages#5](https://github.com/ulises-jeremias/aur-packages/issues/5)).

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | Mandatory `agent-toolkit-bin` from GitHub Release linux binaries + SHA256 | `arch=(x86_64 aarch64)`; `provides/conflicts agent-toolkit`. |
| **B** | Replace `agent-toolkit` in place with a `-bin` style PKGBUILD (same name) | Breaks users who `yay -S agent-toolkit` expecting a rebuildable source package. |
| **C** | Source-build `agent-toolkit` with pinned V as the only package | Requires V on every user machine; dual cost if we also ship `-bin`. |

## Decision

Adopt **A** as the **MUST** migration outcome. Source `agent-toolkit` is **OPTIONAL** and is not the product.

1. Package **`agent-toolkit-bin`**: download `agent-toolkit-linux-x86_64` / `agent-toolkit-linux-arm64` (ADR-018), verify sha256, install `/usr/bin/agent-toolkit`.
2. `provides=('agent-toolkit')` and `conflicts=('agent-toolkit')`.
3. Existing Python `agent-toolkit` PKGBUILD may remain as an optional source/wheel package; it is **not** canonical. Product install is `agent-toolkit-bin`.
4. Automation prefers GitHub-mirror commits plus AUR publish; first AUR push needs an empty `aur.archlinux.org/agent-toolkit-bin.git`. `notify-aur.yml` should dispatch `package_name=agent-toolkit-bin` (and may still bump the optional source package).
5. `pacman -Syu` / AUR helpers own the binary ([ADR-017](ADR-017-update-ownership.md)).

### Rejected

- **B** — silent type change of `agent-toolkit` surprises rebuilders.
- **C-only** — source-with-V is extra maintainer cost; not required for migration.

## Consequences

- **Positive:** Arch path matches GitHub Release bytes; advertised install is `yay -S agent-toolkit-bin`.
- **Negative:** Need a new AUR package registration; v1.10.0 has no binary assets yet — next V-asset tag unblocks `makepkg`.
- **Follow-on:** [#539](https://github.com/ulises-jeremias/agent-toolkit/issues/539) contract README; [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) SHA256SUMS / V upload on the GitHub Release.

## Validation plan

- aur-packages PR adds `agent-toolkit-bin/PKGBUILD` with Release URLs and no `python-build`.
- After V assets exist: `makepkg -si` installs a binary whose `version` matches the tag.

## References

- [aur-packages#5](https://github.com/ulises-jeremias/aur-packages/issues/5), [aur-packages#6](https://github.com/ulises-jeremias/aur-packages/pull/6)
- [ADR-017](ADR-017-update-ownership.md), [ADR-018](ADR-018-release-artifacts.md); Homebrew [#490](https://github.com/ulises-jeremias/agent-toolkit/issues/490)
- `distribution/aur/README.md`, `docs/AUR_PLAYBOOK.md`
