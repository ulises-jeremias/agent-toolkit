# AUR adapter

**Issue:** [#539](https://github.com/ulises-jeremias/agent-toolkit/issues/539) · **ADR:** [#491](https://github.com/ulises-jeremias/agent-toolkit/issues/491) (ADR-024)

**Owner:** [`ulises-jeremias/aur-packages`](https://github.com/ulises-jeremias/aur-packages) (not this tree). Playbook: [docs/AUR_PLAYBOOK.md](../../docs/AUR_PLAYBOOK.md). Notify: `.github/workflows/notify-aur.yml`.

**Implementation:** [aur-packages#5](https://github.com/ulises-jeremias/aur-packages/issues/5) / [aur-packages#6](https://github.com/ulises-jeremias/aur-packages/pull/6).

Contract:

- PKGBUILD lives **only** in `aur-packages`. This repo MUST NOT copy a PKGBUILD.
- **Canonical package:** `agent-toolkit-bin` — linux x86_64/arm64 V binaries from GitHub Releases (ADR-018 names + sha256). `provides`/`conflicts` `agent-toolkit`.
- Optional source/Python package `agent-toolkit` may remain; it is **not** the product (ADR-024).
- `pacman -Syu` / AUR helpers own the binary. `agent-toolkit update` is capability/profile refresh only (ADR-017).
- First AUR publish needs an empty `ssh://aur@aur.archlinux.org/agent-toolkit-bin.git`.

```bash
yay -S agent-toolkit-bin
```
