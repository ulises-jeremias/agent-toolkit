# Docker adapter

<div align="center">

[![GHCR](https://img.shields.io/badge/GHCR-agent--toolkit-2563eb?style=flat&labelColor=1f2937&logo=docker&logoColor=white)](https://github.com/ulises-jeremias/agent-toolkit/pkgs/container/agent-toolkit)
[![Release](https://img.shields.io/github/v/release/ulises-jeremias/agent-toolkit?style=flat&label=release&labelColor=1f2937&color=16a34a)](https://github.com/ulises-jeremias/agent-toolkit/releases/latest)

</div>

**Issue:** [#537](https://github.com/ulises-jeremias/agent-toolkit/issues/537)  
**Workflow:** `.github/workflows/docker.yml`  
**Image:** `ghcr.io/ulises-jeremias/agent-toolkit`

Docker is an **adapter**. The product inside the image is the **GitHub Release V binary** (ADR-018), not a Python interpreter.

## Base image (decision)

| Choice | Class | Rationale |
|--------|-------|-----------|
| `debian:trixie-slim` | **MUST** (stable) | `git` + `gh` + `ca-certificates` for `loop`/`project`/`doctor`. Release linux ELF needs **GLIBC_2.38**; bookworm (2.36) cannot run v1.11.0+ binaries. |
| `debian:bookworm-slim` | **MUST NOT** | glibc 2.36 < 2.38. |
| `gcr.io/distroless/cc` / scratch | **FUTURE** | Only if extra tools move to a sidecar. Not the default. |
| `python:3.11-slim` + `uv run` | **REMOVED** | Legacy uv-workspace image. |
| Alpine / musl | **MUST NOT** for stable | ADR-019: glibc is the MUST Linux binary. |

## Tool dependency set

| Tool | Class | Why |
|------|-------|-----|
| `agent-toolkit` (V ELF) | **MUST** | Copied from Release `agent-toolkit-linux-x86_64` or `agent-toolkit-linux-arm64` matching `TARGETARCH`. Verify `SHA256SUMS`. |
| `git` | **MUST** | `project clone`, loops, swarm worktrees |
| `gh` | **MUST** | GH API in loops / PR skills |
| `ca-certificates` | **MUST** | TLS |
| `curl` | **SHOULD** | Fetch checksums in build; not required at runtime if binary is baked |
| `uv` / CPython | **MUST NOT** | Product is the native binary. |

`ENTRYPOINT` MUST be `/usr/local/bin/agent-toolkit` (the V binary). `CMD` MAY be `--help`.

Build-arg `VERSION` (default from `VERSION` file) selects the GitHub Release tag `v${VERSION}`.

`ARG TARGETARCH` MUST be declared **without a default**. BuildKit injects `amd64` or `arm64` per `--platform`. A Dockerfile default of `amd64` installs the x86_64 ELF into the linux/arm64 image; running it then fails with `agent-toolkit: not found` (missing amd64 dynamic linker).

The Dockerfile MUST NOT `exec` the V binary during `RUN` (QEMU user-mode for the foreign `--platform` lacks that ELF's dynamic linker). Smoke `agent-toolkit version` from `.github/workflows/docker.yml` after a native `load` (PRs) or after push (main).

## Tags

- `latest` / semver: **stable V** image after a GitHub Release has floating linux assets.
- Experimental V names (`agent-toolkit-v-experimental-*`) MUST NOT be baked into `latest`.
- Multi-arch: `linux/amd64` + `linux/arm64` (glibc), matching ADR-018.

Owner of the Dockerfile remains this repo (unlike Homebrew/AUR).

## CI triggers

| Event | Behavior |
|-------|----------|
| `pull_request` (Dockerfile paths) | Native smoke build (`load`); no registry push |
| `push` to `main` (Dockerfile paths) | Native smoke build only — **no push** (avoids racing ahead of Release assets) |
| `workflow_call` from `release.yml` after `upload-assets` | Multi-arch build **and push** (preferred path) |
| `release: published` / `workflow_dispatch` | Multi-arch build **and push**, after verifying `v$(VERSION)` Release has linux assets |

`GITHUB_TOKEN`-created Releases do not start sibling `on: release` workflows; prefer `workflow_call` from `release.yml`.

