# ADR-012: Python / V Coexistence During Strangler Migration

**Status:** Accepted  
**Date:** 2026-08-12  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#482](https://github.com/ulises-jeremias/agent-toolkit/issues/482))

## Context

During the strangler migration, both Python and V implementations will exist. We must decide whether end users get a dual-engine switch, a separate experimental binary, per-command delegation, or CI-only dual builds.

## Options considered

| ID | Option | Summary |
|----|--------|---------|
| **A** | Separate experimental V preview binary | Distinct artifact/name or clearly marked pre-release; Python remains default `agent-toolkit` until cutover gate [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555) |
| **B** | Global engine env (`AGENT_TOOLKIT_ENGINE=python\|v`) | One entrypoint switches implementation |
| **C** | Per-command strangler | V root binary delegates unfinished commands to Python |
| **D** | CI-only dual implementation | No runtime dual engine; channels publish one artifact at a time |

## Decision

Adopt **option A** as the primary coexistence strategy, with **D** for continuous integration parity:

1. Publish an **experimental native V binary** (naming/tagging clearly non-canonical, e.g. experimental assets / prerelease) for early platform and parity learning ([#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562)).
2. Keep the **canonical `agent-toolkit` command** on the Python implementation until the V-default cutover gate ([#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)).
3. Run **Python↔V golden parity in CI** ([#476](https://github.com/ulises-jeremias/agent-toolkit/issues/476) / [#548](https://github.com/ulises-jeremias/agent-toolkit/issues/548)) without requiring users to set an engine env var.
4. **Reject B and C for the default product path** — they increase packaging complexity, mixed semantics, and support burden. If a future spike proves C is necessary for a short window, it requires a new ADR amendment; it is not authorized by this decision.

### Observability

Experimental and stable binaries should expose engine/language, version, and commit via existing diagnostic surfaces (e.g. `doctor --json` / version JSON when added) without polluting normal human output.

## Consequences

- **Positive:** Clean mental model; no silent mixed engines; early binary validation without forcing users onto V.
- **Negative:** Two artifacts during transition; docs must explain experimental vs stable.
- **Rejected:** Global engine switch (drift/support); per-command Python exec from V (packaging and security complexity).

## Validation plan

- Experimental releases never overwrite stable channel assets without explicit promotion.
- Cutover [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555) requires parity gates before renaming/replacing the canonical binary.
- Doctor/version diagnostics report which binary ran.

## Cutover status (#555, 2026-08-13)

[#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555) is **accepted for the source/canonical implementation**:

- From-source `make build-cli` / `make install-cli` installs V as `agent-toolkit`.
- Consumer commands (install lifecycle + skills/mcp/plugin) are implemented in V.
- GitHub Release binaries are **stable native V** since `v1.11.0` ([#530](https://github.com/ulises-jeremias/agent-toolkit/issues/530) / ADR-018). Experimental CI names (`agent-toolkit-v-experimental-*`) remain a separate channel and must not overwrite stable assets.
- **PyPI/`uvx`:** packaging strategy is [ADR-021](ADR-021-pypi-binary.md) (platform wheels + thin launcher over the V binary). Implementation is [#535](https://github.com/ulises-jeremias/agent-toolkit/issues/535). Not a dual-engine switch (options B/C still rejected).
- Unfinished advanced commands stay `not_implemented` in V. Fallback is quarantined `agent-toolkit-py` ([python-fallback.md](../v/python-fallback.md)), not option C (V exec of Python).
- Observability: `doctor --json` and `version --json` include `engine`, `version`, and `commit` without changing human stdout.

Rollback: [docs/v/rollback.md](../v/rollback.md). Cutover narrative: [docs/v/cutover.md](../v/cutover.md).

## References

- Issues [#482](https://github.com/ulises-jeremias/agent-toolkit/issues/482), [#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555), [#562](https://github.com/ulises-jeremias/agent-toolkit/issues/562)
- Program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)

**Verified:** 2026-08-13
