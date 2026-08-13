# Native V GitHub Actions build matrix

**Issue:** [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529)  
**Spike:** [#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562)  
**Names:** [ADR-018](../adrs/ADR-018-release-artifacts.md) · **Libc:** [ADR-019](../adrs/ADR-019-linux-libc.md)

V **cannot cross-compile to macOS**. Every macOS artifact is built **on** a macOS runner.

Stable GitHub Release names (`agent-toolkit-linux-x86_64`, `agent-toolkit-macos-arm64`, `agent-toolkit-windows-x86_64.exe`) remain **PyInstaller** until an explicit promotion after [#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531) smoke. This matrix publishes **experimental** names only.

## MUST capabilities (verified 2026-08-13)

| Capability | `runs-on` (this date) | V zip | Experimental asset |
|------------|----------------------|-------|--------------------|
| Linux x86_64 (glibc) | `ubuntu-latest` | `v_linux.zip` | `agent-toolkit-v-experimental-linux-x86_64` |
| Linux ARM64 (glibc) | `ubuntu-24.04-arm` | `v_linux_arm64.zip` | `agent-toolkit-v-experimental-linux-arm64` |
| macOS ARM64 | `macos-latest` | `v_macos_arm64.zip` | `agent-toolkit-v-experimental-macos-arm64` |
| macOS x86_64 | `macos-15-intel` | `v_macos_x86_64.zip` | `agent-toolkit-v-experimental-macos-x86_64` |
| Windows x86_64 | `windows-latest` | `v_windows.zip` | `agent-toolkit-v-experimental-windows-x86_64.exe` |

Labels are **not** forever architecture. Re-verify when GitHub retargets `-latest` or retires `macos-15-intel` / `ubuntu-24.04-arm`. Source: [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) (public repo table, 2026-08-13).

## FUTURE / not in this matrix

| Capability | Notes |
|------------|--------|
| Windows ARM64 | Issue #529 FUTURE (`windows-11-arm` exists; not a retirement gate). |
| Linux musl | Optional extra (ADR-019); must not overwrite glibc names. |
| Stable floating names | Still PyInstaller in `release.yml` until promotion. |

macOS x86_64 is **MUST here** (experimental channel). The historical #256 skip (`agent-toolkit-darwin-x86_64` / stable `macos-x86_64`) stays for the **stable** floating name until promotion.

## Workflow

`.github/workflows/experimental-v.yml` — `fail-fast: false`, `contents: read`, Actions artifacts only (no `gh release upload`).

Smoke: `--version` / `--help` / `inventory` / `doctor --json` plus an arch mismatch gate ([#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531), [artifact-smoke.md](artifact-smoke.md)).

CI cost tiers (PR / main / release) and Python-lane retirement: [ci-cost-tiers.md](ci-cost-tiers.md) ([#532](https://github.com/ulises-jeremias/agent-toolkit/issues/532)).
