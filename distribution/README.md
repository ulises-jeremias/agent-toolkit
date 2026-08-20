# Distribution contracts

<div align="center">

[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)
[![npm](https://img.shields.io/npm/v/agent-toolkit-cli?style=flat&label=npm&labelColor=1f2937&color=7c3aed&logo=npm&logoColor=white)](https://www.npmjs.com/package/agent-toolkit-cli)
[![PyPI](https://img.shields.io/pypi/v/agent-toolkit-cli?style=flat&label=PyPI&labelColor=1f2937&color=7c3aed&logo=pypi&logoColor=white)](https://pypi.org/project/agent-toolkit-cli/)
[![AUR](https://img.shields.io/aur/version/agent-toolkit-bin?style=flat&label=AUR&labelColor=1f2937&logo=archlinux&logoColor=white)](https://aur.archlinux.org/packages/agent-toolkit-bin)
[![Homebrew](https://img.shields.io/badge/Homebrew-ulises--jeremias%2Ftap-ea580c?style=flat&labelColor=1f2937&logo=homebrew&logoColor=white)](https://github.com/ulises-jeremias/homebrew-tap)
[![GHCR](https://img.shields.io/badge/GHCR-agent--toolkit-2563eb?style=flat&labelColor=1f2937&logo=docker&logoColor=white)](https://github.com/ulises-jeremias/agent-toolkit/pkgs/container/agent-toolkit)

</div>

**Issue:** [#534](https://github.com/ulises-jeremias/agent-toolkit/issues/534)  
**EPIC:** [#463](https://github.com/ulises-jeremias/agent-toolkit/issues/463) (binary release engineering)

This directory is **documentation-only contracts** for packaging adapters. It is not `distributions/` (product/target compiler input).

## Canonical source

**GitHub Releases** on `ulises-jeremias/agent-toolkit` are the canonical binary source ([ADR-018](../docs/adrs/ADR-018-release-artifacts.md)). PyPI, Homebrew, AUR, npm, and Docker are **adapters** that fetch or wrap those V artifacts. Python on PyPI is a thin trampoline only (`packages/pypi/agent-toolkit-cli`) — not the product CLI ([python-fallback.md](../docs/v/python-fallback.md)).

Do **not** duplicate Formula/PKGBUILD/npm `package.json` here. Those live in their owner repos:

| Channel | Owner repo (out of this tree) | Contract in this repo |
|---------|-------------------------------|------------------------|
| GitHub Release | this repo (`.github/workflows/release.yml`) | [github-release/README.md](github-release/README.md) |
| PyPI | this repo (`packages/pypi/agent-toolkit-cli`) | [pypi/README.md](pypi/README.md) · [ADR-021](../docs/adrs/ADR-021-pypi-binary.md) |
| Homebrew | `ulises-jeremias/homebrew-tap` | [homebrew/README.md](homebrew/README.md) · [#538](https://github.com/ulises-jeremias/agent-toolkit/issues/538) · ADR [#490](https://github.com/ulises-jeremias/agent-toolkit/issues/490) |
| AUR | `ulises-jeremias/aur-packages` | [aur/README.md](aur/README.md) · [#539](https://github.com/ulises-jeremias/agent-toolkit/issues/539) · ADR [#491](https://github.com/ulises-jeremias/agent-toolkit/issues/491) |
| npm | this repo (`packages/npm/`) | [npm/README.md](npm/README.md) · [#536](https://github.com/ulises-jeremias/agent-toolkit/issues/536) · [ADR-025](../docs/adrs/ADR-025-npm-binary.md) |
| Docker | this repo (`.github/workflows/docker.yml`) | [docker/README.md](docker/README.md) · [#537](https://github.com/ulises-jeremias/agent-toolkit/issues/537) |
| Workstation (L1) | `ulises-jeremias/agentic-workstation` | [workstation/README.md](workstation/README.md) · [#469](https://github.com/ulises-jeremias/agent-toolkit/issues/469) |

## Verification

Consumers MUST verify checksums when [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) ships `SHA256SUMS`. Attestations/SBOM, if present, prove **provenance of the build**, not “secure software”.

`agent-toolkit update` never replaces the executable ([ADR-017](../docs/adrs/ADR-017-update-ownership.md)). Package managers own binary upgrades.

## Offline / embedded baseline (ADR-026, #766)

Since `v1.17.0` (PR #778) the V binary is **full-embed**: `skills/ loops/ profiles/ mcp/ catalogs/ agents/ capabilities/ distributions/ plugins/ packs` (1179 files) via `scripts/generate-embedded-data.py` → `modules/agent_toolkit_core/embedded_data.v` (`$embed_file`). `paths.v` tier `3a` `embedded` (path `embedded`) wins over `checkout/CWD` but after `XDG_DATA`/`XDG_CACHE`, and `3b` FHS `/usr/share/agent-toolkit/data` is probed for `aur-packages` sidecar compat. Fresh `yay -S agent-toolkit-bin` (no XDG, no `AI_WORKSPACE`, no network) → `doctor --offline` `root: embedded, ok true`, `install --dry-run` all 6 tools green. `agentic-workstation#210` XDG bootstrap is now 1-release compat only.

## Experimental vs stable

Experimental V names (`agent-toolkit-v-experimental-*`) MUST NOT overwrite stable floating names. Promotion is an explicit release decision ([docs/v/release-matrix.md](../docs/v/release-matrix.md)).
