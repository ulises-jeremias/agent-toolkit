# ADR-023: Homebrew installs upstream GitHub Release V binaries

**Status:** Accepted  
**Date:** 2026-08-13  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#490](https://github.com/ulises-jeremias/agent-toolkit/issues/490))

## Context

Canonical Homebrew packaging lives in [`ulises-jeremias/homebrew-tap`](https://github.com/ulises-jeremias/homebrew-tap) — this repo MUST NOT copy a Formula ([#534](https://github.com/ulises-jeremias/agent-toolkit/issues/534) / [#538](https://github.com/ulises-jeremias/agent-toolkit/issues/538)). The tap Formula today uses `Language::Python::Virtualenv` and builds a wheel from the source tarball. After [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555) the product is the native V binary; GitHub Releases are canonical ([ADR-018](ADR-018-release-artifacts.md)).

Do **not** call upstream GitHub binaries “bottles.” A Homebrew bottle is a Homebrew-built bottle of a source formula.

Implementation PR: [homebrew-tap#5](https://github.com/ulises-jeremias/homebrew-tap/pull/5) (issue [homebrew-tap#4](https://github.com/ulises-jeremias/homebrew-tap/issues/4)).

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | Formula installs **upstream prebuilt GitHub Release binary** | `url` per OS/arch (ADR-018 floating names); `bin.install`; verify sha256. |
| **B** | Formula builds from V source on the user machine | `depends_on "vlang"`; `make build-cli`. |
| **C** | Source formula **and** Homebrew generates true **bottles** | Homebrew CI bottles the V build; still not “our” GitHub assets. |

## Decision

Adopt **A**.

1. Formula `agent-toolkit` downloads `agent-toolkit-{macos-arm64,macos-x86_64,linux-x86_64,linux-arm64}` from `ulises-jeremias/agent-toolkit` GitHub Releases. Intel macOS is declared; if an asset is missing, `brew install` fails closed (do not fall back to Python).
2. No `depends_on python`. No virtualenv. `brew upgrade` owns the binary ([ADR-017](ADR-017-update-ownership.md)).
3. Automation: `notify-homebrew.yml` dispatches the tap; `update-formula.yml` patches per-arch sha256 and opens an **auditable PR** (no force-push to `main`).
4. This is **not** a bottle. Gatekeeper/notarization is [#543](https://github.com/ulises-jeremias/agent-toolkit/issues/543) FUTURE.

### Rejected

- **B** — users should not need a V compiler for `brew install`; duplicates CI.
- **C** — bottles are a later Homebrew-core/tap optimization, not the migration requirement; they are not GitHub Release assets.

## Consequences

- **Positive:** Same bytes as GitHub Releases / PyPI wheels (ADR-021 A); one implementation.
- **Negative:** `brew install` is blocked until a tag attaches V assets (v1.10.0 currently has an empty asset list). Release.yml must upload V binaries ([#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530)), not PyInstaller, onto stable names after promotion.
- **Follow-on:** [#538](https://github.com/ulises-jeremias/agent-toolkit/issues/538) contract README; notify workflow waits for darwin/linux **binary** assets, not only the source tarball.

## Validation plan

- Tap PR: Formula has no `Virtualenv` / `python@`.
- After the next V-asset release: `brew install ulises-jeremias/homebrew-tap/agent-toolkit` and `agent-toolkit version` matches the tag (V engine).

## References

- [homebrew-tap#4](https://github.com/ulises-jeremias/homebrew-tap/issues/4), [homebrew-tap#5](https://github.com/ulises-jeremias/homebrew-tap/pull/5)
- [ADR-017](ADR-017-update-ownership.md), [ADR-018](ADR-018-release-artifacts.md), [ADR-021](ADR-021-pypi-binary.md)
- `distribution/homebrew/README.md`
