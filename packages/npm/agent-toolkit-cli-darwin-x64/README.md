<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%" alt="agent-toolkit banner">
</p>

<div align="center">

# agent-toolkit-cli-darwin-x64

**Native V binary** for macOS Intel — optionalDependency of [`agent-toolkit-cli`](https://www.npmjs.com/package/agent-toolkit-cli).

[![npm](https://img.shields.io/npm/v/agent-toolkit-cli-darwin-x64?style=flat&labelColor=1f2937&color=7c3aed)](https://www.npmjs.com/package/agent-toolkit-cli-darwin-x64)
[![License: MIT](https://img.shields.io/badge/license-MIT-7c3aed?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/LICENSE)
[![os](https://img.shields.io/badge/os-darwin-0891b2?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-025-npm-binary.md)
[![cpu](https://img.shields.io/badge/cpu-x64-ea580c?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-025-npm-binary.md)

[Meta-package](https://www.npmjs.com/package/agent-toolkit-cli) ·
[GitHub Release](https://github.com/ulises-jeremias/agent-toolkit/releases/latest) ·
[ADR-025](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-025-npm-binary.md) ·
[Installation](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/INSTALLATION.md)

</div>

---

## What is this package?

This package ships **only** the floating GitHub Release asset `agent-toolkit-macos-x86_64` as `bin/agent-toolkit`. It is **not** a second CLI and is **not** meant to be installed directly.

Install the meta-package instead:

```bash
npm install -g agent-toolkit-cli
agent-toolkit --help
```

npm selects this package via `optionalDependencies` when `os=darwin` and `cpu=x64`.

| Field | Value |
|-------|-------|
| npm name | `agent-toolkit-cli-darwin-x64` |
| Release asset | `agent-toolkit-macos-x86_64` |
| Binary path | `bin/agent-toolkit` |
| Parent | [`agent-toolkit-cli`](https://www.npmjs.com/package/agent-toolkit-cli) |

---

## Requirements

- macOS on **Intel** (x86_64)
- Prefer installing via the meta-package so the Node launcher can resolve this binary
- Gatekeeper / code-signing notes: [docs](https://github.com/ulises-jeremias/agent-toolkit/tree/main/docs) (see code-signing policy in the monorepo)

---

## Documentation

| Guide | Description |
|-------|-------------|
| [agent-toolkit-cli (npm)](https://www.npmjs.com/package/agent-toolkit-cli) | Meta-package README — install, commands, tools |
| [ADR-025](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-025-npm-binary.md) | npm topology |
| [ADR-018](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-018-release-artifacts.md) | Canonical Release asset names |
| [Monorepo](https://github.com/ulises-jeremias/agent-toolkit) | Source of truth |

---

<div align="center">

**MIT** © [ulises-jeremias](https://github.com/ulises-jeremias) · [npm](https://www.npmjs.com/package/agent-toolkit-cli-darwin-x64) · [GitHub](https://github.com/ulises-jeremias/agent-toolkit)

</div>
