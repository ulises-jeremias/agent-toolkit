# PyPI adapter

**Issue:** [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535) · **ADR:** [ADR-021](../../docs/adrs/ADR-021-pypi-binary.md)

**Layout** (npm parallel under `packages/`):

| Path | Role |
|------|------|
| `packages/pypi/agent-toolkit-cli/` | Hatchling project **`agent-toolkit-cli`**: thin launcher + quarantined `agent-toolkit-py` fallback |
| `packages/pypi/agent-toolkit-cli/platforms.json` | GitHub Release asset → PEP 425/600 wheel tag |
| `scripts/pack_pypi.py` | Copies Release V binaries into the wheel at CI time (like `scripts/pack_npm.py`) |
| `scripts/prepare-native-bin.sh` | Local/PR helper: copy `build/agent-toolkit` into `src/agent_toolkit/bin/` |

There are **no** per-OS Python packages. npm uses `optionalDependencies`; pip consumes **platform-tagged wheels** of one distribution.

## Wheel tags (honest glibc)

v1.11.0 linux ELF needs **GLIBC_2.38**. Tags:

| Wheel tag | Bundled asset |
|-----------|----------------|
| `manylinux_2_38_x86_64` | `agent-toolkit-linux-x86_64` |
| `manylinux_2_38_aarch64` | `agent-toolkit-linux-arm64` |
| `macosx_11_0_arm64` | `agent-toolkit-macos-arm64` |
| `macosx_11_0_x86_64` | `agent-toolkit-macos-x86_64` |
| `win_amd64` | `agent-toolkit-windows-x86_64.exe` |

Do **not** emit raw `linux_x86_64` (PyPI 400). Do **not** claim `manylinux_2_17` / `2_35`. No `py3-none-any` product wheel (ADR-021).

## Pack / publish

```bash
export RELEASE_BIN_DIR=binaries
export RELEASE_VERSION="$(tr -d '[:space:]' < VERSION)"
bash scripts/prepare-package-data.sh
python3 scripts/pack_pypi.py   # sdist + one wheel per present asset → dist/
```

- Tag releases: `.github/workflows/release.yml` `publish-pypi` (after `upload-assets`).
- Manual republish (e.g. v1.11.0 after the manylinux fix): workflow **Publish (manual)** — downloads `v$(cat VERSION)` Release assets and packs the same way.

Console scripts: `agent-toolkit` / `agent-toolkit-cli` → `agent_toolkit.launcher:main` (exec V). `agent-toolkit-py` is a quarantined fallback ([docs/v/python-fallback.md](../../docs/v/python-fallback.md)).
