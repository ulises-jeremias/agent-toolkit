# GitHub Release adapter

**Owner:** this repository (`.github/workflows/release.yml`).  
**Names:** [ADR-018](../../docs/adrs/ADR-018-release-artifacts.md).

Stable floating assets (today PyInstaller until V promotion):

- `agent-toolkit-linux-x86_64`
- `agent-toolkit-macos-arm64`
- `agent-toolkit-windows-x86_64.exe`

Experimental V assets use the `agent-toolkit-v-experimental-` prefix only ([#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562)).

Checksums, attestations, SBOM: [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530). Manifest: [#488](https://github.com/ulises-jeremias/agent-toolkit/issues/488).
