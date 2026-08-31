<p align="center">
  <img src="https://github.com/ulises-jeremias/agent-toolkit/blob/main/static/banner.svg?raw=true" width="100%" alt="agent-toolkit banner">
</p>

<div align="center">

# agent-toolkit-cli-linux-arm64

**Native V binary** for Linux arm64 (glibc) — optionalDependency of [`agent-toolkit-cli`](https://www.npmjs.com/package/agent-toolkit-cli).

[![npm](https://img.shields.io/npm/v/agent-toolkit-cli-linux-arm64?style=flat&labelColor=1f2937&color=7c3aed)](https://www.npmjs.com/package/agent-toolkit-cli-linux-arm64)
[![npm downloads](https://img.shields.io/npm/dm/agent-toolkit-cli-linux-arm64?style=flat&label=downloads&labelColor=1f2937&color=0891b2)](https://www.npmjs.com/package/agent-toolkit-cli-linux-arm64)
[![License: MIT](https://img.shields.io/badge/license-MIT-7c3aed?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/LICENSE)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)
[![os](https://img.shields.io/badge/os-linux-0891b2?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-025-npm-binary.md)
[![cpu](https://img.shields.io/badge/cpu-arm64-ea580c?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-025-npm-binary.md)
[![libc](https://img.shields.io/badge/libc-glibc-16a34a?style=flat&labelColor=1f2937)](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-019-linux-libc.md)

[Meta-package](https://www.npmjs.com/package/agent-toolkit-cli) ·
[GitHub Release](https://github.com/ulises-jeremias/agent-toolkit/releases/latest) ·
[ADR-025](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-025-npm-binary.md) ·
[Installation](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/INSTALLATION.md)

</div>

---

## What is this package?

This package ships **only** the floating GitHub Release asset `agent-toolkit-linux-arm64` as `bin/agent-toolkit`. It is **not** a second CLI and is **not** meant to be installed directly.

Install the meta-package instead:

```bash
npm install -g agent-toolkit-cli
agent-toolkit --help
```

npm selects this package via `optionalDependencies` when `os=linux`, `cpu=arm64`, and `libc=glibc` ([ADR-019](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/adrs/ADR-019-linux-libc.md) — musl/Alpine is not a MUST tag).

| Field | Value |
|-------|-------|
| npm name | `agent-toolkit-cli-linux-arm64` |
| Release asset | `agent-toolkit-linux-arm64` |
| Binary path | `bin/agent-toolkit` |
| Parent | [`agent-toolkit-cli`](https://www.npmjs.com/package/agent-toolkit-cli) |

---

## Requirements

- Linux **arm64** with **glibc** (typically 2.38+ for current Release builds)
- Prefer installing via the meta-package so the Node launcher can resolve this binary

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

**MIT** © [ulises-jeremias](https://github.com/ulises-jeremias) · [npm](https://www.npmjs.com/package/agent-toolkit-cli-linux-arm64) · [GitHub](https://github.com/ulises-jeremias/agent-toolkit)

</div>
