# ADR-011: Capability Resource Packaging (Embed vs Data Artifact vs Hybrid)

**Status:** Accepted  
**Date:** 2026-08-12  
**Deciders:** maintainers (V migration program [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456), issue [#481](https://github.com/ulises-jeremias/agent-toolkit/issues/481))

## Context

Agent Toolkit ships large capability trees (`skills/`, `agents/`, `loops/`, `profiles/`, `mcp/`, `catalogs/`, `distributions/`, `capabilities/`, …). Python today copies them into the wheel via `scripts/prepare-package-data.sh` and also supports XDG cache / GitHub download (ADR-005). The V binary-first product must choose how those trees are packaged **without** compiling every file into opaque source constants, and without conflating packaging with **runtime resolution order** (owned by [#547](https://github.com/ulises-jeremias/agent-toolkit/issues/547) / ADR-005 amend).

## Options considered

1. **A — Embed all resources in the binary** — single artifact; large binary; painful capability updates.
2. **B — Sidecar data artifact** — `agent-toolkit` + `agent-toolkit-data.*`; simpler updates; two artifacts to keep in sync.
3. **C — Hybrid** — embed a **baseline** set required for offline `doctor` / read-only inventory; allow external override/update directory for full trees and fresher content.

## Decision

Adopt **option C (Hybrid)**.

- Ship a **baseline** capability snapshot suitable for core read-only commands and offline diagnostics inside (or beside) the primary binary distribution, with integrity metadata (checksums) published on the GitHub Release.
- Allow an **external data directory** (installed share dir, XDG, or explicit flag) to override/extend baseline for full installs and capability updates.
- Do **not** redefine runtime lookup order here. **ADR-005 remains authoritative until [#547](https://github.com/ulises-jeremias/agent-toolkit/issues/547) formally amends or supersedes it.** This ADR only decides packaging layout.
- Do **not** turn capability Markdown/YAML into generated V constants as the primary model.
- Channel adapters (PyPI wheel, Homebrew, AUR, Docker) must document how baseline + external data are laid out so behavior does not accidentally diverge.

## Consequences

- **Positive:** Offline baseline works; updates need not rebuild the engine; aligns with existing wheel+cache mental model.
- **Negative:** Two layers (baseline vs override) to test; release must publish matching data checksums.
- **Rejected:** Full embed-only (oversized binaries / slow content cadence); sidecar-only without baseline (breaks offline first-run UX).

## Validation plan

- Release checklist: baseline integrity verified; override wins where ADR-005/#547 say it should.
- Parity fixtures for offline baseline vs online/override.
- Package docs under future `distribution/*` contracts.

## References

- ADR-005 (`docs/adrs/ADR-005-data-packaging.md`)
- `scripts/prepare-package-data.sh`
- `.github/workflows/release.yml` (native V binaries on ADR-018 names since v1.11.0)
- Issues [#481](https://github.com/ulises-jeremias/agent-toolkit/issues/481), [#547](https://github.com/ulises-jeremias/agent-toolkit/issues/547)

**Verified:** 2026-08-12
