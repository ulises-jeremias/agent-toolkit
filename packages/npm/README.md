# packages/npm

<div align="center">

[![npm](https://img.shields.io/npm/v/agent-toolkit-cli?style=flat&label=npm&labelColor=1f2937&color=7c3aed&logo=npm&logoColor=white)](https://www.npmjs.com/package/agent-toolkit-cli)
[![npm downloads](https://img.shields.io/npm/dm/agent-toolkit-cli?style=flat&label=downloads&labelColor=1f2937&color=0891b2)](https://www.npmjs.com/package/agent-toolkit-cli)
[![Node](https://img.shields.io/node/v/agent-toolkit-cli?style=flat&labelColor=1f2937)](https://www.npmjs.com/package/agent-toolkit-cli)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)

</div>

npm adapter sources. PyPI equivalent: [`packages/pypi/`](../pypi/).

| Directory | npm name | Role |
|-----------|----------|------|
| `agent-toolkit-cli/` | `agent-toolkit-cli` | Thin Node launcher (`bin/agent-toolkit.js`) over GitHub Release V binaries (ADR-025) |
| `agent-toolkit-cli-linux-x64/` | `agent-toolkit-cli-linux-x64` | glibc ELF (`optionalDependency`) |
| `agent-toolkit-cli-linux-arm64/` | `agent-toolkit-cli-linux-arm64` | glibc ELF (`optionalDependency`) |
| `agent-toolkit-cli-darwin-arm64/` | `agent-toolkit-cli-darwin-arm64` | macOS arm64 Mach-O |
| `agent-toolkit-cli-darwin-x64/` | `agent-toolkit-cli-darwin-x64` | macOS x64 Mach-O |
| `agent-toolkit-cli-win32-x64/` | `agent-toolkit-cli-win32-x64` | Windows x64 PE |

Pack at release time: `scripts/pack_npm.vsh` (copies Release assets into `bin/`). Publish: `.github/workflows/publish-npm.yml` (OIDC trusted publishing).

Trampoline tests (no V compile):

```bash
npm test --prefix packages/npm/agent-toolkit-cli
```

CI runs Node **22** and **24** across ubuntu/macOS/Windows (`validate.yml` → `test-npm`).

Each published package has a polished `README.md`. Platform packages are shorter than the meta-package but document platform, install path, and when *not* to install them directly.
