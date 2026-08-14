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

### Maintainer: formula PR must open automatically

After `notify-homebrew.yml` dispatches the tap, `update-formula.yml` pushes `chore/agent-toolkit-v*` and must open a PR. If Actions only push the branch (as on v1.14.0 / v1.14.1), fix **on the tap**:

1. Tap **Settings → Actions → General → Workflow permissions** → enable **Allow GitHub Actions to create and approve pull requests**.
2. Ensure environment secret `HOMEBREW_TAP_TOKEN` (fine-grained PAT) has **Contents: R/W** and **Pull requests: R/W** on `ulises-jeremias/homebrew-tap` (fallback when the Actions toggle is off).
3. Same secret on this repo’s `homebrew` environment for `notify-homebrew.yml` → `repository_dispatch`.

```bash
gh api -X PUT repos/ulises-jeremias/homebrew-tap/actions/permissions/workflow \
  -f default_workflow_permissions=write \
  -F can_approve_pull_request_reviews=true
```

Details: [homebrew-tap README](https://github.com/ulises-jeremias/homebrew-tap#ci-secrets-and-permissions-maintainer).

```bash
brew tap ulises-jeremias/homebrew-tap
brew install agent-toolkit
```
