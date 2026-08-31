# ADR-019: Linux glibc vs musl (or both)

**Status:** Accepted  
**Date:** 2026-08-13  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#485](https://github.com/ulises-jeremias/agent-toolkit/issues/485))

## Context

Native Linux `agent-toolkit` binaries will run on developer workstations, CI images, Docker, and (later) package wrappers. V can link against **glibc** or **musl**. Musl static binaries look attractive for Alpine/scratch images and “copy one file” installs, but they are not automatically better: DNS (`nsswitch`), TLS (OpenSSL vs bundled), NSS plugins, and binary size all change. Python wheels already follow **manylinux** (glibc) for PyPI.

Canonical asset names are [ADR-018](ADR-018-release-artifacts.md): the floating name `agent-toolkit-linux-x86_64` is the **stable** Linux x86_64 artifact.

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | glibc only | One Linux binary, built on a manylinux-like / Ubuntu runner; matches PyPI/Docker Debian-ubuntu users. |
| **B** | musl static only | One fully static (or musl-dynamic) binary; Alpine-first; hope it runs everywhere. |
| **C** | Both: glibc is MUST/stable; musl is optional extra | Stable name is glibc; musl ships as a distinctly named extra when the matrix can afford it. |
| **D** | Distroless “universal” via zig cc / extra flags | One builder produces both; still need two artifacts and two smoke jobs. |

## Decision

Adopt **C**.

1. **MUST Linux artifact is glibc.** `agent-toolkit-linux-x86_64` (and `linux-arm64` when #529 includes it) is built against a **supported glibc** (manylinux_2_28-class or Ubuntu LTS used in #529). This is the binary wrappers, Docker (Debian/Ubuntu), and `docs/RELEASING.md` mean by “Linux”.
2. **Do not assume musl is superior.** Static musl can regress DNS/TLS (no glibc NSS; extra care for certificates). Size is an empirical #533 measurement, not a reason to default musl.
3. **Optional musl extra.** If #529/#532 cost tiers allow, publish `agent-toolkit-linux-x86_64-musl` (versioned archive too) as **non-stable** / documented for Alpine. It MUST NOT overwrite the floating glibc name. Experimental V (#562) may use musl only under the experimental prefix ([ADR-018](ADR-018-release-artifacts.md)).
4. **Docker:** default image tracks glibc (Debian/Ubuntu). An Alpine variant is a separate tag, not a replacement.

### Rejected

- **B** — breaks the majority workstation/CI glibc install base; TLS/DNS surprises.
- **A forever** — forbids an Alpine extra even when we can afford it.
- **D as the product default** — extra toolchain risk; still two artifacts to smoke (#531).

## Consequences

- **Positive:** Matches PyPI manylinux expectations; stable name is unambiguous; Alpine is opt-in.
- **Negative:** Two Linux builds when musl is enabled (CI cost — #532).
- **Follow-on:** #529 matrix lists glibc as MUST; musl as SHOULD/MAY. #531 smokes glibc always; musl only if the extra asset exists.

## Validation plan

- Release notes / ADR-018 table: `linux-x86_64` = glibc.
- Smoke (#531) on the glibc artifact: `--version` / `--help` / `inventory` / `doctor`.
- If musl extra ships: separate smoke job; document Alpine install in `docs/RELEASING.md` without changing the stable name.

## References

- Issues [#485](https://github.com/ulises-jeremias/agent-toolkit/issues/485), [#484](https://github.com/ulises-jeremias/agent-toolkit/issues/484), [#529](https://github.com/ulises-jeremias/agent-toolkit/issues/529), [#531](https://github.com/ulises-jeremias/agent-toolkit/issues/531), [#532](https://github.com/ulises-jeremias/agent-toolkit/issues/532), [#533](https://github.com/ulises-jeremias/agent-toolkit/issues/533)
- [ADR-018](ADR-018-release-artifacts.md) artifact names

**Verified:** 2026-08-13
