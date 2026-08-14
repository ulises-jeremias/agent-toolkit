# V CLI — current map

The product CLI is a **native V 0.5.2** binary (`import json`, not json2). Python on PyPI is only a thin trampoline (`agent-toolkit` → V), same idea as npm ([python-fallback.md](python-fallback.md)). Contributor how-to: [`docs/HOW_TO_DEVELOP_V.md`](../HOW_TO_DEVELOP_V.md).

Historical strangler / cutover notes live under [`archive/`](archive/).

## Build from source

```bash
# Pin is .v-version (currently 0.5.2)
./make.vsh build-cli          # → build/agent-toolkit
VMODULES=$PWD/modules ./build/agent-toolkit --version
```

See `./make.vsh --tasks` (`fmt` / `fmt-check` / `vet` / `test` / `build`). Do not run `v fmt` without reverting `json` → `json2`.

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

## Dispatcher & command surface

| Doc | Topic |
|-----|-------|
| [cli-dispatcher.md](cli-dispatcher.md) | vlib/cli `Command` tree (Consumer / Advanced groups) |
| [../CLI_SURFACES.md](../CLI_SURFACES.md) | Command inventory |
| [advanced-command-disposition.md](advanced-command-disposition.md) | PORT / REDESIGN / DEPRECATE / REMOVE |
| [../compatibility/cli-contract.yaml](../compatibility/cli-contract.yaml) | Machine-readable flags / IO |
| [result-render.md](result-render.md) | Human vs `--json` output |
| [error-model.md](error-model.md) | Exit codes and error shapes |

## Emitters & compiler

| Doc | Topic |
|-----|-------|
| [emitters.md](emitters.md) | Compiler emitter overview |
| [emitters-copilot.md](emitters-copilot.md) | Copilot adapter |
| [emitters-remaining.md](emitters-remaining.md) | Remaining target notes |
| [plugin.md](plugin.md) | Plugin sync / marketplace bundles |
| [build-check.md](build-check.md) | `agent-toolkit build --check` |
| [loader.md](loader.md) | Skill / agent / loop loading |

Product membership is declared in `distributions/products.yaml` and compiled with `agent-toolkit build` (ADR-003 retired `gen-surfaces`).

## Trampolines & packaging

| Doc | Topic |
|-----|-------|
| [python-fallback.md](python-fallback.md) | PyPI trampoline only (no Python CLI) |
| [pypi-launcher.md](pypi-launcher.md) | Wheel / launcher contract (ADR-021) |
| [ci-cost-tiers.md](ci-cost-tiers.md) | CI job tiers |
| [release-matrix.md](release-matrix.md) | MUST platform matrix |
| [artifact-smoke.md](artifact-smoke.md) | Release smoke checks |

## Consumer & advanced commands

| Doc | Topic |
|-----|-------|
| [install.md](install.md) / [uninstall.md](uninstall.md) / [update.md](update.md) | Install lifecycle |
| [doctor.md](doctor.md) / [diff.md](diff.md) | Diagnostics |
| [skills.md](skills.md) / [mcp.md](mcp.md) / [inventory.md](inventory.md) / [matrix.md](matrix.md) | Discovery |
| [workspace.md](workspace.md) / [memory.md](memory.md) / [project.md](project.md) | L3 harness |
| [loop.md](loop.md) / [swarm.md](swarm.md) / [devcompanion.md](devcompanion.md) | Orchestration |

## Core services (V)

Filesystem, process, network: [filesystem-service.md](filesystem-service.md), [process-service.md](process-service.md), [network-service.md](network-service.md). Concurrency is **process-per-run** (ADR-020).

## Verification

`SHA256SUMS` on the Release. Gatekeeper/SmartScreen: [code-signing-policy.md](code-signing-policy.md). Threat model for wrappers: [threat-model-distribution.md](threat-model-distribution.md).

## Archive (historical)

Strangler-era migration notes (cutover, rollback, experimental binaries, Python architecture map, vlib spike, risk register, Python API audit):

→ [`archive/`](archive/)
