# ADR-025: npm package topology — `agent-toolkit-cli` launcher

**Status:** Accepted  
**Date:** 2026-08-13  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#487](https://github.com/ulises-jeremias/agent-toolkit/issues/487))

## Context

npm must ship the **same** GitHub Release V binaries as PyPI/Homebrew/AUR (ADR-018). Node is a launcher only — no second CLI implementation. [#485](https://github.com/ulises-jeremias/agent-toolkit/issues/485) / [ADR-019](ADR-019-linux-libc.md) chose **glibc MUST**; musl is not a MUST npm tag. The npm **distribution name** must match PyPI: **`agent-toolkit-cli`**.

Root `package.json` in this repo (`"name": "agent-toolkit"`) is skills/marketplace metadata, **not** the published CLI.

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | Meta-package `agent-toolkit-cli` + `optionalDependencies` platform packages | Installer pulls the host OS/arch binary package; bin `agent-toolkit` execs it. |
| **B** | Single package that downloads from GitHub at install/first run | Same as PyPI option B; blocked as default by [#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563). |
| **C** | Publish under a different npm name (`@scope/agent-toolkit`, `agent-toolkit`) | Breaks “same name as PyPI”; `agent-toolkit` on npm would collide with the repo metadata name and is the wrong product id. |

## Decision

Adopt **A**. npm name **MUST** be `agent-toolkit-cli`.

### Packages

| npm name | Role | `os` / `cpu` / `libc` |
|----------|------|------------------------|
| `agent-toolkit-cli` | Meta-package: `bin.agent-toolkit` → thin Node launcher | none (JS only) |
| `agent-toolkit-cli-linux-x64` | glibc ELF | `linux` / `x64` / `glibc` |
| `agent-toolkit-cli-linux-arm64` | glibc ELF | `linux` / `arm64` / `glibc` |
| `agent-toolkit-cli-darwin-arm64` | Mach-O | `darwin` / `arm64` |
| `agent-toolkit-cli-darwin-x64` | Mach-O | `darwin` / `x64` |
| `agent-toolkit-cli-win32-x64` | PE | `win32` / `x64` |

No musl/Alpine npm package (ADR-019). No Node business logic. Launcher: resolve optional dep binary → `exec` / spawn with forwarded argv, stdio, signals, exit (same constraints as ADR-021 / [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535)). Windows quoting tests in [#536](https://github.com/ulises-jeremias/agent-toolkit/issues/536).

Platform packages contain **only** the GitHub Release asset bytes (ADR-018 floating names mapped at pack time). They are not a second compile.

### Publish

GitHub Actions **OIDC trusted publishing** (npm CLI ≥ 11.5.1 / `npm trust` ≥ 11.15.0), mirroring PyPI Trusted Publishing. No long-lived `NPM_TOKEN` in Actions. Workflow filename is the trust pin (e.g. `release.yml` or `publish-npm.yml`).

### Rejected

- **B** — runtime GitHub download is not the npm default (#563).
- **C** — user requirement: npm name equals PyPI `agent-toolkit-cli`.

## Consequences

- **Positive:** `npx agent-toolkit-cli` / `npm i -g agent-toolkit-cli` runs V; one product name across PyPI and npm.
- **Negative:** Several npm packages per release; first publish requires an npm account + `npm trust github`.
- **Follow-on:** [#536](https://github.com/ulises-jeremias/agent-toolkit/issues/536) launcher + packing; [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) must attach the binaries the packer copies.

## Validation plan

- Unit tests: launcher forwards argv/exit; missing platform package exits non-zero (no silent JS CLI).
- CI: pack one platform package from a built V binary, `node bin` runs `version`.

## References

- [#487](https://github.com/ulises-jeremias/agent-toolkit/issues/487), [#536](https://github.com/ulises-jeremias/agent-toolkit/issues/536), [ADR-018](ADR-018-release-artifacts.md), [ADR-019](ADR-019-linux-libc.md), [ADR-021](ADR-021-pypi-binary.md)
- [npm trusted publishers](https://docs.npmjs.com/trusted-publishers/); `npm trust github <pkg> --file <workflow.yml> --repository owner/repo --allow-publish`
