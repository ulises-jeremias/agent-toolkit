# Homebrew adapter

**Issue:** [#538](https://github.com/ulises-jeremias/agent-toolkit/issues/538) · **ADR:** [`docs/adrs/ADR-023-homebrew.md`](../../docs/adrs/ADR-023-homebrew.md) (discussion: [#490](https://github.com/ulises-jeremias/agent-toolkit/issues/490))

**Owner:** [`ulises-jeremias/homebrew-tap`](https://github.com/ulises-jeremias/homebrew-tap) (not this tree). Notify: `.github/workflows/notify-homebrew.yml`.

**Implementation:** [homebrew-tap#4](https://github.com/ulises-jeremias/homebrew-tap/issues/4) / [homebrew-tap#5](https://github.com/ulises-jeremias/homebrew-tap/pull/5).

Contract:

- Formula lives **only** in the tap. This repo MUST NOT copy a Formula.
- Formula installs **GitHub Release V binaries** (ADR-018 floating names), not a Python wheel and not a Homebrew bottle of a source build (ADR-023 option A).
- Canonical URLs: `agent-toolkit-macos-arm64`, `agent-toolkit-macos-x86_64`, `agent-toolkit-linux-x86_64`, `agent-toolkit-linux-arm64`.
- `brew upgrade` owns the binary. `agent-toolkit update` is capability/profile refresh only (ADR-017).
- Tap updater opens an **auditable PR** with per-arch sha256; it must not force-push `main`.

```bash
brew tap ulises-jeremias/homebrew-tap
brew install agent-toolkit
```
