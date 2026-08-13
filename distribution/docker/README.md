# Docker adapter

**Issue:** [#537](https://github.com/ulises-jeremias/agent-toolkit/issues/537)  
**Workflow:** `.github/workflows/docker.yml`  
**Image:** `ghcr.io/ulises-jeremias/agent-toolkit`

Docker is an **adapter**. The product inside the image is the **GitHub Release V binary** (ADR-018), not a Python interpreter.

## Base image (decision)

| Choice | Class | Rationale |
|--------|-------|-----------|
| `debian:bookworm-slim` | **MUST** (stable) | `git` + `gh` + `ca-certificates` needed for `loop`/`project`/`doctor`. Distroless cannot ship those CLIs without a second stage copy of glibc-linked tools. |
| `gcr.io/distroless/cc` / scratch | **FUTURE** | Only if extra tools move to a sidecar. Not the default. |
| `python:3.11-slim` + `uv run` | **Transitional** | Current `Dockerfile` until the first Release with V assets. MUST NOT remain the stable `latest` once a V tag exists. |
| Alpine / musl | **MUST NOT** for stable | ADR-019: glibc is the MUST Linux binary. |

## Tool dependency set

| Tool | Class | Why |
|------|-------|-----|
| `agent-toolkit` (V ELF) | **MUST** | Copied from Release `agent-toolkit-linux-x86_64` or `agent-toolkit-linux-arm64` matching `TARGETARCH`. Verify `SHA256SUMS`. |
| `git` | **MUST** | `project clone`, loops, swarm worktrees |
| `gh` | **MUST** | GH API in loops / PR skills |
| `ca-certificates` | **MUST** | TLS |
| `curl` | **SHOULD** | Fetch checksums in build; not required at runtime if binary is baked |
| `uv` / CPython | **MUST NOT** in the V image | Product is the native binary. Python image is transitional only. |

`ENTRYPOINT` MUST be `/usr/local/bin/agent-toolkit` (the V binary). `CMD` MAY be `--help`.

## Tags

- `latest` / semver: **stable V** image only after a GitHub Release has floating linux assets.
- Experimental V names (`agent-toolkit-v-experimental-*`) MUST NOT be baked into `latest`.
- Multi-arch: `linux/amd64` + `linux/arm64` (glibc), matching ADR-018.

## Implementation gate

Do not rewrite `Dockerfile` to the V copy path until a tagged Release publishes `agent-toolkit-linux-x86_64` (and arm64). Until then the Python image may keep building so `ghcr` is not empty.

Owner of the Dockerfile remains this repo (unlike Homebrew/AUR).
