# Homebrew adapter

**Issue:** [#538](https://github.com/ulises-jeremias/agent-toolkit/issues/538) · **ADR:** [#490](https://github.com/ulises-jeremias/agent-toolkit/issues/490)

**Owner:** `ulises-jeremias/homebrew-tap` (not this tree). Notify workflow: `.github/workflows/notify-homebrew.yml`.

Contract:

- Formula lives **only** in the tap. This repo MUST NOT copy a Formula.
- Canonical download URL is the GitHub Release stable floating name for the host OS/arch (ADR-018).
- `brew upgrade` owns the binary. `agent-toolkit update` is capability/profile refresh only (ADR-017).

Until V promotion, the tap may still ship the Python formula; the ADR records the binary vs bottle vs source choice.
