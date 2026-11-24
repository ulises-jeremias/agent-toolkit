# Homebrew adapter

<div align="center">

[![Homebrew](https://img.shields.io/badge/Homebrew-ulises--jeremias%2Ftap-ea580c?style=flat&labelColor=1f2937&logo=homebrew&logoColor=white)](https://github.com/ulises-jeremias/homebrew-tap)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)

</div>

**Issue:** [#538](https://github.com/ulises-jeremias/agent-toolkit/issues/538) · **ADR:** [`docs/adrs/ADR-023-homebrew.md`](../../docs/adrs/ADR-023-homebrew.md) (discussion: [#490](https://github.com/ulises-jeremias/agent-toolkit/issues/490))

**Owner:** [`ulises-jeremias/homebrew-tap`](https://github.com/ulises-jeremias/homebrew-tap) (not this tree). Notify: `.github/workflows/notify-homebrew.yml`.

**Implementation:** [homebrew-tap#4](https://github.com/ulises-jeremias/homebrew-tap/issues/4) / [homebrew-tap#5](https://github.com/ulises-jeremias/homebrew-tap/pull/5).

Contract:

- Formula lives **only** in the tap. This repo MUST NOT copy a Formula.
- Formula installs the versioned GitHub Release standalone archive, including the native V executable, SHA-256-verified offline bundle, and license. It does not install a Python wheel or a Homebrew bottle of a source build.
- Archive URLs follow `agent-toolkit-<version>-<os>-<arch>.tar.gz`; the formula updater verifies the downloaded archive against `manifest.json` before opening its PR.
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
