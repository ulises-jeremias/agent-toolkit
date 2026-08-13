# GitHub Release adapter

**Owner:** this repository (`.github/workflows/release.yml`).  
**Names:** [ADR-018](../../docs/adrs/ADR-018-release-artifacts.md).

Stable floating assets are **native V binaries** (since `v1.11.0`). Do not treat PyInstaller as the product. Do **not retag** `v1.10.0` (empty asset list).

- `agent-toolkit-linux-x86_64` / `agent-toolkit-linux-arm64`
- `agent-toolkit-macos-arm64` / `agent-toolkit-macos-x86_64`
- `agent-toolkit-windows-x86_64.exe`
- Versioned archives `agent-toolkit-<semver>-<os>-<arch>.tar.gz` (Windows `.zip`)
- `SHA256SUMS`, `manifest.json`, `sbom.cyclonedx.json`

Experimental V CI artifacts use the `agent-toolkit-v-experimental-` prefix only and MUST NOT overwrite stable names ([#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562)).

Checksums are MUST. Attestations/SBOM: [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530). Manifest: [ADR-022](../../docs/adrs/ADR-022-release-manifest.md). Runbook: [`docs/RELEASING.md`](../../docs/RELEASING.md).
