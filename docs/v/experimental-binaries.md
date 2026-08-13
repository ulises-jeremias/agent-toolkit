# Experimental native V binaries

**Issue:** [#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562)  
**Names:** [ADR-018](../adrs/ADR-018-release-artifacts.md)  
**Libc:** [ADR-019](../adrs/ADR-019-linux-libc.md) (Linux MUST artifact is glibc)

These are **CI artifacts only**. They are not the stable GitHub Release channel (`agent-toolkit-linux-x86_64`, `agent-toolkit-macos-arm64`, `agent-toolkit-windows-x86_64.exe` — those remain PyInstaller until [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529) promotion). Experimental names **must not** overwrite stable names.

## Workflow

`.github/workflows/experimental-v.yml` (`workflow_dispatch`, and on changes to that workflow / `.v-version`).

Compiler pin: `.v-version` (currently `0.5.2`).

## Runner labels (verified 2026-08-13)

| Experimental asset | GitHub-hosted `runs-on` | V zip | Notes |
|--------------------|-------------------------|-------|--------|
| `agent-toolkit-v-experimental-linux-x86_64` | `ubuntu-latest` | `v_linux.zip` | glibc (ADR-019). Not musl. |
| `agent-toolkit-v-experimental-macos-arm64` | `macos-latest` | `v_macos_arm64.zip` | Apple Silicon. `macos-latest` was arm64 on this date; revisit if GitHub retargets the label. |
| `agent-toolkit-v-experimental-windows-x86_64.exe` | `windows-latest` | `v_windows.zip` | |

No `darwin-x86_64` job (same skip as #256 / ADR-018). Linux arm64 / musl extras are out of this spike (#529 / ADR-019 optional musl).

## Smoke

Each job runs `--version` and `--help` on the freshly built binary. Broader smoke (`inventory` / `doctor`) is [#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531).

## How to fetch

Actions → **Experimental V binaries** → workflow run → Artifacts. Do not `gh release upload` these names onto a stable `v*` tag.

```bash
gh run download <run-id> --name agent-toolkit-v-experimental-linux-x86_64
```
