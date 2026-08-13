# V development & distribution

**Issue:** [#545](https://github.com/ulises-jeremias/agent-toolkit/issues/545)  
**Program:** [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)

The product CLI is a **native V 0.5.2** binary (`import json`, not json2). Python is a launcher (`agent-toolkit` → V) plus `agent-toolkit-py` fallback until [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540). Contributor how-to: [`docs/HOW_TO_DEVELOP_V.md`](../HOW_TO_DEVELOP_V.md).

## Build from source

```bash
# Pin is .v-version (currently 0.5.2)
make build-cli          # → build/agent-toolkit
VMODULES=$PWD/modules ./build/agent-toolkit --version
```

See `Makefile` (`fmt` / `fmt-check` / `vet` / `test` / `build`). Do not run `v fmt` without reverting `json` → `json2`.

## Install channels (adapters)

Canonical artifacts: **GitHub Releases** ([ADR-018](../adrs/ADR-018-release-artifacts.md), [RELEASING.md](../RELEASING.md)).

| Channel | Contract | Notes |
|---------|----------|-------|
| GitHub Release | [distribution/github-release](../../distribution/github-release/README.md) | Floating + versioned archives, `SHA256SUMS`, `manifest.json` |
| PyPI `agent-toolkit-cli` | [distribution/pypi](../../distribution/pypi/README.md) · ADR-021 | Wheel bundles V; launcher execs it |
| npm `agent-toolkit-cli` | [distribution/npm](../../distribution/npm/README.md) · ADR-025 | OIDC `publish-npm.yml` |
| Homebrew | [distribution/homebrew](../../distribution/homebrew/README.md) · ADR-023 | `ulises-jeremias/homebrew-tap` |
| AUR `agent-toolkit-bin` | [distribution/aur](../../distribution/aur/README.md) · ADR-024 | `ulises-jeremias/aur-packages` |
| Docker | [distribution/docker](../../distribution/docker/README.md) | debian-slim + glibc V binary |
| Workstation | [distribution/workstation](../../distribution/workstation/README.md) | L1 CLI-only bootstrap (#469) |

Checksums **MUST**. Attestations/SBOM prove provenance only ([code-signing-policy.md](code-signing-policy.md)).

## Architecture & CLI

| Doc | Topic |
|-----|-------|
| [python-architecture-map.md](python-architecture-map.md) | Python tree classification (#477) |
| [../CLI_SURFACES.md](../CLI_SURFACES.md) | Command inventory (#475) |
| [advanced-command-disposition.md](advanced-command-disposition.md) | PORT/REDESIGN/DEPRECATE/REMOVE (#560) |
| [../compatibility/cli-contract.yaml](../compatibility/cli-contract.yaml) | Machine-readable flags/IO (#549) |
| [cutover.md](cutover.md) | Engine cutover |
| [python-api-consumers.md](python-api-consumers.md) | Python import audit (#561); #540 must cite this |
| [migration-risk-register.md](migration-risk-register.md) | Risks (#478) |
| [performance-baseline.md](performance-baseline.md) | Startup/help/inventory/doctor timings (#533) |

## Core services (V)

Filesystem, process, network, error model, result render: `filesystem-service.md`, `process-service.md`, `network-service.md`, `error-model.md`, `result-render.md`. Concurrency is **process-per-run** (ADR-020) — no Python threads, no `go` workers on 0.5.2.

## Verification

`SHA256SUMS` on the Release. Gatekeeper/SmartScreen: [code-signing-policy.md](code-signing-policy.md). Threat model for wrappers: [threat-model-distribution.md](threat-model-distribution.md).
