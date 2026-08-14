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
| **release** | `v*` tags (`release.yml`) | Full native **stable V** matrix, PyPI manylinux_2_38 wheels, SHA256SUMS/attestations/SBOM (#530) | Wall: release workflow ≤ 60 min. Cancel-in-progress: **no** |

Experimental native V artifacts stay on the **experimental** channel ([ADR-018](../adrs/ADR-018-release-artifacts.md)). They are **not** the release-tier stable upload (stable names are native V as of v1.11.0).

## Path filters (distribution smoke)

`.github/workflows/experimental-v.yml` already lists paths (workflow, `.v-version`, `docs/v/{experimental-binaries,release-matrix,artifact-smoke}.md`). Docs-only PRs that do not touch those files **must not** pay the 5-runner MUST matrix.

`.github/workflows/parity.yml` is limited to CLI/V/parity/make.vsh/`.v-version` paths so markdown-only PRs skip the golden harness.

## Python lane retirement trigger

[#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) gates are met (V is the product; PyPI is a launcher). The `test-package` matrix now covers the PyPI trampoline + packaging pytest only ([python-fallback.md](python-fallback.md)). CLI logic is covered by V unit tests and integration jobs.

Do not drop Python tests to save CI minutes while the wheel still ships those modules.

## Timeouts (recorded)

| Workflow / job | `timeout-minutes` |
|----------------|-------------------|
| `parity.yml` / `parity-seed` | 15 |
| `experimental-v.yml` / matrix build | 25 |
| `release.yml` overall | 60 (job-level in workflow as added) |

`concurrency.cancel-in-progress: true` on PR/main validate, parity, and experimental-v. Release concurrency must not cancel.

## Cost notes

The expensive axis is **Python 3.10–3.13 × ubuntu+macos** plus **five** experimental V runners. Path filters are the lever before shrinking the Python matrix. Do not add a sixth experimental OS without an issue.
