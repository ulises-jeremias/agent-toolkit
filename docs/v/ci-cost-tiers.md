# CI cost tiers (dual Python + V)

**Issue:** [#532](https://github.com/ulises-jeremias/agent-toolkit/issues/532)  
**Parent:** [#463](https://github.com/ulises-jeremias/agent-toolkit/issues/463)  
**Related:** parity harness [#548](https://github.com/ulises-jeremias/agent-toolkit/issues/548) · MUST matrix [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529) · smoke [#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531) · attestations [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) · Python removal [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540)

Dual implementation CI is expensive. Workflows follow three **cost tiers**. Distribution smoke must not run on docs-only PRs.

## Tiers

| Tier | When | What runs | Budget |
|------|------|-----------|--------|
| **PR** | `pull_request` | Lint/fmt/validate; Python unit (validate.yml); V compile via parity seed + dispatch tests in validate if present; golden parity (`parity.yml`) only when CLI/V/Python CLI paths change | Wall: parity ≤ 15 min; experimental-v **skipped** unless its path filter matches. Cancel-in-progress: yes |
| **main** | `push` to `main` | PR set plus fuller compile. Experimental V MUST matrix (`experimental-v.yml`) only on V/release-doc path changes | Wall: experimental-v job ≤ 25 min/platform. Cancel-in-progress: yes |
| **release** | `v*` tags (`release.yml`) | Full native **stable** PyInstaller matrix, PyPI publish, SHA256SUMS/attestations/SBOM (#530) | Wall: release workflow ≤ 60 min. Cancel-in-progress: **no** |

Experimental native V artifacts stay on the **experimental** channel ([ADR-018](../adrs/ADR-018-release-artifacts.md)) until an explicit promotion. They are **not** the release-tier stable upload.

## Path filters (distribution smoke)

`.github/workflows/experimental-v.yml` already lists paths (workflow, `.v-version`, `docs/v/{experimental-binaries,release-matrix,artifact-smoke}.md`). Docs-only PRs that do not touch those files **must not** pay the 5-runner MUST matrix.

`.github/workflows/parity.yml` is limited to CLI/V/parity/Makefile/`.v-version` paths so markdown-only PRs skip the golden harness.

## Python lane retirement trigger

Remove the `test-package` OS × CPython matrix from `.github/workflows/validate.yml` **only when all of**:

1. [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) gates are actually met (not merely “V is default in-repo”).
2. [#561](https://github.com/ulises-jeremias/agent-toolkit/issues/561) consumer audit is closed with no remaining in-tree Python API dependents (or they are documented exceptions).
3. PyPI/Homebrew/AUR no longer require the Python CLI as the shipped runtime ([#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535) / [#486](https://github.com/ulises-jeremias/agent-toolkit/issues/486)).

Until then, Python tests stay on **PR** and **main**. Do not drop them to save CI minutes while Python is still the stable distribution.

## Timeouts (recorded)

| Workflow / job | `timeout-minutes` |
|----------------|-------------------|
| `parity.yml` / `parity-seed` | 15 |
| `experimental-v.yml` / matrix build | 25 |
| `release.yml` overall | 60 (job-level in workflow as added) |

`concurrency.cancel-in-progress: true` on PR/main validate, parity, and experimental-v. Release concurrency must not cancel.

## Cost notes

The expensive axis is **Python 3.10–3.13 × ubuntu+macos** plus **five** experimental V runners. Path filters are the lever before shrinking the Python matrix. Do not add a sixth experimental OS without an issue.
