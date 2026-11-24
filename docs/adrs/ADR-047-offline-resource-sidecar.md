# ADR-047: Ship the Offline Resource Bundle Beside Native Binaries

**Status:** Accepted
**Date:** 2026-11-24
**Deciders:** maintainers (Creative Studio resource packaging, PR [#1845](https://github.com/ulises-jeremias/agent-toolkit/pull/1845))
**Amends:** ADR-015 and ADR-026

## Context

ADR-026 requires a fresh installation to retain all toolkit capabilities offline. The generated gzip bundle preserves that contract, but embedding its 19 MB compressed payload into a V-generated C array made native package builds stall on macOS. On PR #1845, both macOS Electron package jobs spent their full 60-minute limit compiling the backend with `clang`; Windows and Linux package jobs passed.

## Decision

Keep the complete, deterministic gzip bundle as a runtime sidecar named `embedded_data.bundle.gz`. Native binaries locate it beside the executable, in the packaged data directory, in the supported FHS data directory, or from a source checkout during development. `AGENT_TOOLKIT_DATA_BUNDLE` provides an explicit override. Installed binaries do not rely on the current working directory.

The bundle SHA-256 is generated from the same tracked source files and compiled as a small constant into the binary. The loader verifies the digest before decompressing or reading any resource. A missing, unreadable, corrupt, or mismatched bundle fails closed with a diagnostic.

Every supported distribution must include the sidecar:

- Versioned GitHub CLI archives contain the native binary, `embedded_data.bundle.gz`, and `LICENSE`.
- Electron packages stage the sidecar beside the bundled backend.
- npm platform packages include it beside the native executable.
- PyPI wheels include it under `agent_toolkit/data/`, next to the wheel's capability trees.
- Release manifest `binary` assets remain native executables for package builders; standalone CLI users install the versioned `archive` asset.

The generator and CI drift check keep both the bundle and its compiled digest synchronized with the tracked capability sources. No network fetch is introduced into offline operation.

## Consequences

- Native compilation no longer turns thousands of resources or a multi-megabyte archive into C source.
- Standalone release archives remain self-contained and offline-capable; their archive hash covers both executable and resources.
- npm and PyPI package size grows by the compressed bundle, while the native executable remains substantially smaller.
- Replacing a sidecar without rebuilding the binary is detected by the embedded digest.
- A binary copied out of its distribution package must be paired with the package's resource directory or an explicit `AGENT_TOOLKIT_DATA_BUNDLE` path.

## Validation

- V unit tests cover bundle parsing, binary asset preservation, SHA-256 validation, and package path candidates.
- Generated-artifact CI regenerates the bundle and digest and rejects `$embed_file` in the runtime module.
- Release packaging tests inspect each archive for the binary, license, and bundle.
- Clean offline package smoke runs `skills list` and installation preview from outside the checkout for each supported distribution.

## References

- [ADR-015 — Runtime Resource Resolution](ADR-015-runtime-resolution.md)
- [ADR-026 — Full offline resource contract](ADR-026-full-embed.md)
- [PR #1845 — Creative Studio resource packaging](https://github.com/ulises-jeremias/agent-toolkit/pull/1845)
