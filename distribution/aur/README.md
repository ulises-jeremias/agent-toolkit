# AUR adapter

<div align="center">

[![AUR](https://img.shields.io/aur/version/agent-toolkit-bin?style=flat&label=AUR&labelColor=1f2937&logo=archlinux&logoColor=white)](https://aur.archlinux.org/packages/agent-toolkit-bin)
[![AUR votes](https://img.shields.io/aur/votes/agent-toolkit-bin?style=flat&label=votes&labelColor=1f2937&color=0891b2)](https://aur.archlinux.org/packages/agent-toolkit-bin)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)

</div>

**Issue:** [#539](https://github.com/ulises-jeremias/agent-toolkit/issues/539) · **ADR:** [#491](https://github.com/ulises-jeremias/agent-toolkit/issues/491) (ADR-024)

**Owner:** [`ulises-jeremias/aur-packages`](https://github.com/ulises-jeremias/aur-packages) (not this tree). Playbook: [docs/AUR_PLAYBOOK.md](../../docs/AUR_PLAYBOOK.md). Notify: `.github/workflows/notify-aur.yml`.

**Implementation:** [aur-packages#5](https://github.com/ulises-jeremias/aur-packages/issues/5) / [aur-packages#6](https://github.com/ulises-jeremias/aur-packages/pull/6).

Contract:

- PKGBUILD lives **only** in `aur-packages`. This repo MUST NOT copy a PKGBUILD.
- **Canonical package:** `agent-toolkit-bin` — Linux x86_64/arm64 standalone GitHub Release archives, containing the V binary, offline bundle, and license. The updater verifies archive hashes against `manifest.json`. `provides`/`conflicts` `agent-toolkit`.
- Optional source/Python package `agent-toolkit` may remain; it is **not** the product (ADR-024).
- `pacman -Syu` / AUR helpers own the binary. `agent-toolkit update` is capability/profile refresh only (ADR-017).
- First AUR publish needs an empty `ssh://aur@aur.archlinux.org/agent-toolkit-bin.git`.
- **Offline (ADR-026/047):** a fresh package installs the complete gzip resource bundle at `/usr/share/agent-toolkit/data`; the runtime verifies its SHA-256 against a digest compiled into the binary. The raw floating executable is not a complete standalone package. Dual sync `agent-toolkit 1.10.0→1.16.0` (aur-packages#7) keeps `provides` parity.

```bash
yay -S agent-toolkit-bin
```
