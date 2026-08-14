# ADR-021: PyPI binary strategy (platform wheels + thin launcher)

**Status:** Accepted (implemented `v1.11.0+`: platform wheels + thin launcher over stable GitHub Release V binaries)  
**Date:** 2026-08-13  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#486](https://github.com/ulises-jeremias/agent-toolkit/issues/486))

## Context

PyPI distribution **`agent-toolkit-cli`** shipped a full Python CLI at decision time. After [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555), V is the in-repo canonical implementation. Leaving PyPI on the Python CLI would keep a second product runtime.

GitHub Releases are the canonical binary source ([ADR-018](ADR-018-release-artifacts.md)). PyPI must be an **adapter**, not a second implementation.

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | Platform wheels containing the native V binary + tiny launcher | `uv tool install agent-toolkit-cli` gets a wheel tagged for the host; entrypoint `exec`s the bundled binary. |
| **B** | Bootstrap downloader | Wheel has no binary; first run detects OS/arch, downloads a GitHub Release asset, verifies, execs. |
| **C** | Keep Python CLI on PyPI indefinitely | Simplest packaging; contradicts cutover. |
| **D** | Rename/replace PyPI project with a non-Python artifact only | PyPI is Python-centric; dropping a wheel breaks `uv`/`pip`. |

## Decision

Adopt **A**.

### Strategy

1. **Product path is the V binary.** The commands `agent-toolkit` and `agent-toolkit-cli` MUST `exec` (or equivalent spawn+wait with signal/stdio/exit forwarding) a native V binary. They MUST NOT run Python business logic.
2. **Bundle at wheel-build time.** CI copies the matching GitHub Release asset (stable floating name since `v1.11.0`) into the wheel. Runtime download (option B) is **not** the default and is blocked on the distribution threat model ([#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)).
3. **Thin Python process is allowed.** `uv tool install` may start a tiny Python entrypoint whose only job is locate-binary + `os.execv` / `subprocess` with forwarded argv, env, cwd, stdio, signals, and exit code. **Zero Python implementation**, not zero Python process.
4. **Python CLI remains a named fallback.** Console script `agent-toolkit-py` keeps the quarantined Python implementation ([python-fallback.md](../v/python-fallback.md)). It is not the product command. [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) does **not** require deleting this script or the thin launcher.

### Name continuity

| Kind | Decision |
|------|----------|
| PyPI **distribution** name | Keep **`agent-toolkit-cli`**. Do not require acquiring the unused `agent-toolkit` name on PyPI. |
| Console **command** name | **`agent-toolkit`** (and alias `agent-toolkit-cli`) → V launcher. |
| Python **import** name | `agent_toolkit` stays for the thin launcher and quarantined modules. Importing `agent_toolkit.cli.main` is advanced/fallback, not the product path. |

### Platform tags (glibc MUST)

Wheels are **platform-specific** (not `py3-none-any` for the product command). Tags follow current packaging specs and [ADR-019](ADR-019-linux-libc.md):

| Wheel tag (illustrative) | Bundled asset (ADR-018) |
|--------------------------|-------------------------|
| `manylinux_2_38_x86_64` | `agent-toolkit-linux-x86_64` (glibc 2.38; PyPI rejects raw `linux_x86_64`) |
| `manylinux_2_38_aarch64` | `agent-toolkit-linux-arm64` |
| `macosx_*_arm64` | `agent-toolkit-macos-arm64` |
| `macosx_*_x86_64` | `agent-toolkit-macos-x86_64` when published; otherwise omit the wheel |
| `win_amd64` | `agent-toolkit-windows-x86_64.exe` |

Musl/Alpine is **not** a PyPI MUST tag. No `py3-none-any` product wheel that silently runs Python CLI.

### Wrapper constraints (implemented in [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535))

- Forward argv unchanged (no re-parsing into a second CLI).
- Forward stdio; on POSIX, replace the process (`execv`) so signals hit the V binary.
- On Windows, spawn with signal/Ctrl-C forwarding and wait; return the native exit code.
- Version printed by `agent-toolkit version` is the **V binary** version, not the launcher’s packaging version if they ever diverge (they should not).
- Missing bundled binary in an editable/dev tree is an error pointing at `make build-cli` / `agent-toolkit-py` — not a silent Python fallback.

### Rejected

- **B as default** — install-time or first-run download needs #563; also fails offline `uv tool install`.
- **C** — PyPI would remain a second implementation after #555.
- **D** — breaks the `uv`/`pip` install path the docs already advertise.

## Consequences

- **Positive:** `uvx --from agent-toolkit-cli agent-toolkit` runs V; one implementation; checksums happen at wheel build (Release asset → wheel).
- **Negative:** Must publish several platform wheels per release; sdist cannot usefully contain every native binary; macOS x86_64 wheel omitted until that asset exists.
- **Follow-on:** [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535) launcher + tests; [#488](https://github.com/ulises-jeremias/agent-toolkit/issues/488) manifest so the build can pick the asset without scraping HTML; [#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) SHA256SUMS for build-time verify.

## Layout follow-up (2026-08-13)

Sources live under **`packages/pypi/agent-toolkit-cli/`**, parallel to **`packages/npm/`**. That is topology only:

* npm installs per-OS bits via `optionalDependencies` on separate packages.
* PyPI installs per-OS bits via **platform-tagged wheels of one project**. There are no `agent-toolkit-cli-linux-*` Python packages (pip cannot consume them the way npm optionalDeps work).

CI copies GitHub Release V binaries into the wheel (`scripts/pack_pypi.vsh` + `scripts/prepare-native-bin.sh`). The repo root is not a uv workspace; `uv.lock` belongs next to the adapter if present. Pre-commit Ruff uses `language: python` (`ruff-pre-commit`) with root `ruff.toml` — no product uv workspace.

Contract: [`distribution/pypi/README.md`](../../distribution/pypi/README.md).

## Retirement follow-up (2026-08-13)

[#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540) / [#470](https://github.com/ulises-jeremias/agent-toolkit/issues/470) close with this ADR still in force: the PyPI **product** path is the bundled V binary + thin launcher. `agent-toolkit-py` stays as a quarantined fallback for DEPRECATE/REMOVE commands and pytest. Deleting `packages/pypi` would break `uv tool install agent-toolkit-cli`.

## Validation plan

- Unit tests: launcher forwards argv/exit; refuses to import `cli.main` on the product path.
- One CI job per MUST OS builds or fetches the V binary, packs a wheel, runs `agent-toolkit --help` / `version` from that wheel (not `agent-toolkit-py`).
- `py3-none-any` wheel, if still built for sdist completeness, must not install `agent-toolkit` as the Python CLI; prefer no universal product wheel.

## References

- Issues [#486](https://github.com/ulises-jeremias/agent-toolkit/issues/486), [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535), [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555), [#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)
- [ADR-012](ADR-012-python-v-coexistence.md), [ADR-017](ADR-017-update-ownership.md), [ADR-018](ADR-018-release-artifacts.md), [ADR-019](ADR-019-linux-libc.md)
- `distribution/pypi/README.md` ([#534](https://github.com/ulises-jeremias/agent-toolkit/issues/534) / #535)

## Update — Python CLI quarantine removed

The thin launcher remains (npm-style trampoline). Console script `agent-toolkit-py` and
`src/agent_toolkit/{cli,compiler,installer,loop,runner,swarm}` were deleted. Product tests
are V (`modules/**/*_test.v`) plus packaging/launcher pytest. See [python-fallback.md](../v/python-fallback.md).

