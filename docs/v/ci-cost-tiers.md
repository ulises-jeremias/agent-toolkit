# CI cost tiers (post V cutover)

**Issue:** [#532](https://github.com/ulises-jeremias/agent-toolkit/issues/532)  
**Parent:** [#463](https://github.com/ulises-jeremias/agent-toolkit/issues/463)  
**Related:** parity harness [#548](https://github.com/ulises-jeremias/agent-toolkit/issues/548) · release matrix [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529) · attestations [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530)

Product CI is **V-first**. Python/npm jobs cover trampoline adapters only ([python-fallback.md](python-fallback.md), ADR-025). Workflows follow three **cost tiers**.

## Tiers

| Tier | When | What runs | Budget |
|------|------|-----------|--------|
| **PR** | `pull_request` | `validate.yml` Required CI: V `vet`/`test` (fmt-check deferred; json2 risk), skills/agents/loops/products/catalogs, `build --check`, launcher pytest matrix, npm trampoline tests, integration CLI smoke | Wall: parity ≤ 15 min when path-filtered. Cancel-in-progress: yes |
| **main** | `push` to `main` | PR set plus post-release `test-uvx` (published PyPI smoke). Experimental V matrix is **manual only** (`workflow_dispatch`) | Cancel-in-progress: yes |
| **release** | `v*` tags (`release.yml`) | Full native **stable V** matrix, PyPI manylinux_2_38 wheels, SHA256SUMS/attestations/SBOM (#530) | Wall: release workflow ≤ 60 min. Cancel-in-progress: **no** |

Stable GitHub Release assets are native V ([ADR-018](../adrs/ADR-018-release-artifacts.md)). Experimental asset names remain for optional `workflow_dispatch` smoke only.

## Path filters

`.github/workflows/parity.yml` is limited to CLI/V/parity/`make.vsh`/`.v-version` paths so markdown-only PRs skip the golden harness.

## Adapter tests (Python / npm)

[#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) is complete: V is the product; PyPI/npm are trampolines. Keep:

- `test-package` — PyPI launcher + packaging pytest (Python 3.10–3.14)
- `test-npm` — Node 22/24 trampoline (`node --test`)
- `ruff` — launcher Python style

`test-uvx` hits **published** PyPI (not the PR commit). It runs on `main` / dispatch only and is **not** in Required CI.

Launcher `coverage` is advisory (same suite as `test-package`); not in Required CI.

## Timeouts (recorded)

| Workflow / job | `timeout-minutes` |
|----------------|-------------------|
| `parity.yml` / `parity-seed` | 15 |
| `experimental-v.yml` / matrix build | 25 (manual) |
| `release.yml` overall | 60 |

`concurrency.cancel-in-progress: true` on PR/main validate and parity. Release concurrency must not cancel.

## Cost notes

The expensive axes are the Python trampoline matrix and the release V MUST platforms. Do not re-enable automatic experimental-v on every PR. Do not add a sixth release OS without an issue.

## Update 2026-08-27 — swarm-e2e + macos signal (Phase 1)

* `check-v-modules` now `ubuntu+macos` (was `ubuntu` only) — `+1 macos` (~7 min, +$0.12) for `herdr`/`zsh`/`paths` parity.
* `swarm-e2e` new `ubuntu+macos` (skeleton, no LLM, `herdr` mock) — `+2` (`+~$0.20`) for `swarm start --dry-run` matrix + filesystem SoT + `loop cost/status` + `workspace context`.
* `parity` now `ubuntu+macos` (was `ubuntu` only) — `+1 macos` (~4 min, +$0.07) for launcher fallback `AGENT_TOOLKIT_ROOT` vs `site-packages`.

Net PR cost `+3–4` jobs `~+$0.29–0.39/PR` vs today `~24` jobs. `paths:` filter (`docs/**/*.md` skip) offsets doc-typo PRs (3 min vs 25 min). See `validate.yml` `swarm-e2e` job and `parity.yml` matrix.

