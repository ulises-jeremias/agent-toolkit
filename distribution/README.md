# Distribution contracts

**Issue:** [#534](https://github.com/ulises-jeremias/agent-toolkit/issues/534)  
**EPIC:** [#463](https://github.com/ulises-jeremias/agent-toolkit/issues/463) (binary release engineering)

This directory is **documentation-only contracts** for packaging adapters. It is not `distributions/` (product/target compiler input).

## Canonical source

**GitHub Releases** on `ulises-jeremias/agent-toolkit` are the canonical binary source ([ADR-018](../docs/adrs/ADR-018-release-artifacts.md)). PyPI, Homebrew, AUR, npm, and Docker are **adapters**: they fetch or wrap those artifacts (or, until V promotion, the current Python wheel / PyInstaller names).

Do **not** duplicate Formula/PKGBUILD/npm `package.json` here. Those live in their owner repos:

| Channel | Owner repo (out of this tree) | Contract in this repo |
|---------|-------------------------------|------------------------|
| GitHub Release | this repo (`.github/workflows/release.yml`) | [github-release/README.md](github-release/README.md) |
| PyPI | this repo (`packages/agent-toolkit-cli`) until wrapper [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535) | [pypi/README.md](pypi/README.md) · ADR [#486](https://github.com/ulises-jeremias/agent-toolkit/issues/486) |
| Homebrew | `ulises-jeremias/homebrew-tap` | [homebrew/README.md](homebrew/README.md) · [#538](https://github.com/ulises-jeremias/agent-toolkit/issues/538) · ADR [#490](https://github.com/ulises-jeremias/agent-toolkit/issues/490) |
| AUR | `ulises-jeremias/aur-packages` | [aur/README.md](aur/README.md) · [#539](https://github.com/ulises-jeremias/agent-toolkit/issues/539) · ADR [#491](https://github.com/ulises-jeremias/agent-toolkit/issues/491) |
| npm | future adapter | [npm/README.md](npm/README.md) · [#536](https://github.com/ulises-jeremias/agent-toolkit/issues/536) · ADR [#487](https://github.com/ulises-jeremias/agent-toolkit/issues/487) |
| Docker | this repo (`.github/workflows/docker.yml`) | [docker/README.md](docker/README.md) · [#537](https://github.com/ulises-jeremias/agent-toolkit/issues/537) |
| Workstation (L1) | `ulises-jeremias/agentic-workstation` | [workstation/README.md](workstation/README.md) · [#469](https://github.com/ulises-jeremias/agent-toolkit/issues/469) |

## Verification

Consumers MUST verify checksums when [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) ships `SHA256SUMS`. Attestations/SBOM, if present, prove **provenance of the build**, not “secure software”.

`agent-toolkit update` never replaces the executable ([ADR-017](../docs/adrs/ADR-017-update-ownership.md)). Package managers own binary upgrades.

## Experimental vs stable

Experimental V names (`agent-toolkit-v-experimental-*`) MUST NOT overwrite stable floating names. Promotion is an explicit release decision ([docs/v/release-matrix.md](../docs/v/release-matrix.md)).
