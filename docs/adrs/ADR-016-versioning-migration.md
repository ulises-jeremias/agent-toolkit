# ADR-016: Versioning Strategy During Python→V Migration

**Status:** Accepted  
**Date:** 2026-08-12  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#495](https://github.com/ulises-jeremias/agent-toolkit/issues/495))

## Context

Shipping a native V binary alongside the Python CLI raises a versioning question: should the language rewrite force a **major** bump, or can releases stay **compatible** while Python remains the user-visible oracle until cutover ([ADR-012](ADR-012-python-v-coexistence.md))?

User-visible compatibility (CLI argv, exit codes, JSON schemas, install layouts) matters more than implementation language. Dependent work (compiler, installer, packaging wrappers) needs a frozen policy.

## Options considered

1. **Major bump on first V-default cutover only** — keep `1.x` while dual-run; bump major when V becomes the default binary ([#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)).
2. **Major bump when experimental V binary ships** — treat any V binary as a breaking product change even if Python remains canonical.
3. **Parallel version lines** — Python `1.x` and V `2.x` published concurrently with divergent features.

## Decision

Adopt **option 1**.

- **Until cutover (#555):** shared toolkit version (`VERSION` / PyPI / V `embedded_version`) stays on the current major. The experimental V binary is labeled experimental in docs/help; behavioral parity is enforced by the golden harness ([#548](https://github.com/ulises-jeremias/agent-toolkit/issues/548)).
- **At V-default cutover (#555):** bump **major** if any user-visible contract breaks (CLI surface, receipt schema, install paths). Prefer a **compatible major** only if contracts are proven identical by the parity harness and packaging channel docs.
- **After cutover:** continue SemVer on the V-first product; Python removal ([#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540)) does not by itself require another major if already cut over.
- **Homebrew / AUR / PyPI wrappers:** track the same SemVer; channel-specific rebuilds do not invent a second public version line.

## Consequences

- **Positive:** Users are not forced through a major for an experimental dual-run binary; cutover remains the intentional compatibility gate.
- **Negative:** Experimental V may lag Python features within the same SemVer — must be documented and gated by inventory “migrated” status.
- **Rejected:** Parallel version lines (option 3) — doubles packaging and support cost.

## Validation plan

- `scripts/bump-version.py` keeps `VERSION`, Python `__version__`, and V `embedded_version` in lockstep.
- Parity harness seed grows with each migrated command; release notes call out experimental V coverage.
- Cutover checklist (#555) explicitly records whether the major bump is required from contract diffs.

## References

- [ADR-012](ADR-012-python-v-coexistence.md) Python/V coexistence
- Issue [#495](https://github.com/ulises-jeremias/agent-toolkit/issues/495)
- Epic [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)

## Cutover status (2026-08-13)

[#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555) made V the **in-repo** canonical `agent-toolkit`. Public SemVer is **not** bumped here: PyPI/`uvx` still ship Python; GitHub native artifacts stay experimental until MUST-platform promotion. Human CLI stdout for `version` is unchanged. See [docs/v/cutover.md](../v/cutover.md).

**Verified:** 2026-08-12
