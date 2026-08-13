# AUR adapter

**Issue:** [#539](https://github.com/ulises-jeremias/agent-toolkit/issues/539) · **ADR:** [#491](https://github.com/ulises-jeremias/agent-toolkit/issues/491)

**Owner:** `ulises-jeremias/aur-packages` (not this tree). Playbook: [docs/AUR_PLAYBOOK.md](../../docs/AUR_PLAYBOOK.md). Notify: `.github/workflows/notify-aur.yml`.

Contract:

- PKGBUILD lives **only** in `aur-packages`. This repo MUST NOT copy a PKGBUILD.
- Package name advertised to users: `agent-toolkit` (`yay -S agent-toolkit`). A `-bin` split is an ADR-491 decision.
- `pacman -Syu` / AUR helpers own the binary. `agent-toolkit update` is capability/profile refresh only (ADR-017).

Until V promotion, AUR may still wrap the Python package.
