# Experimental native V binaries

**Issue:** [#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562)  
**Names:** [ADR-018](../adrs/ADR-018-release-artifacts.md)  
**Libc:** [ADR-019](../adrs/ADR-019-linux-libc.md) (Linux MUST artifact is glibc)

These are **CI artifacts only**. They are not the stable GitHub Release channel (`agent-toolkit-linux-x86_64`, `agent-toolkit-macos-arm64`, `agent-toolkit-windows-x86_64.exe` — those remain PyInstaller until promotion after [#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531)). Experimental names **must not** overwrite stable names.

The MUST platform matrix (Linux x86_64/ARM64, macOS ARM64/x86_64, Windows x86_64) is documented in [release-matrix.md](release-matrix.md) ([#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529)).

## Workflow

`.github/workflows/experimental-v.yml` (`workflow_dispatch`, and on changes to that workflow / `.v-version`).

Compiler pin: `.v-version` (currently `0.5.2`).

## Runner labels

Spike (#562) verified `ubuntu-latest` / `macos-latest` / `windows-latest` on 2026-08-13. The full MUST matrix (including `ubuntu-24.04-arm` and `macos-15-intel`) is in [release-matrix.md](release-matrix.md).

## Smoke

Each job runs `--version` and `--help` on the freshly built binary. Broader smoke (`inventory` / `doctor`) is [#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531).

## How to fetch

Actions → **Experimental V binaries** → workflow run → Artifacts. Do not `gh release upload` these names onto a stable `v*` tag.

```bash
gh run download <run-id> --name agent-toolkit-v-experimental-linux-x86_64
```
