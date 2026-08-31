# RFC 279: Harness extract vs stay-in-binary (consumer progressive disclosure)

> **Status:** RFC — discussion before implementation. **No implementation until RFC accepted.** Label `rfc`, wave:5, maintainer-only.

## Problem

Workstation harness (`loop`, `workspace`, `memory`, `devcompanion`, `insights`) shares one binary with consumer install. `SCOPE.md` already progressive-discloses; long-term split is undecided.

## Why it matters

Speculative package split is expensive. Record an RFC so the decision is transparent even if the answer is “stay one binary for 12 months”.

## Options

### 1. Stay one binary (baseline, recommended for 12 months)

- **What:** Keep one repo, one canonical binary, one release. Capability vs Runtime planes remain documentary (docs/ARCHITECTURE.md#Two Planes), not code split. Harness commands remain in `agent_toolkit_core` but are hidden behind progressive disclosure (`SCOPE.md`).
- **Pros:** No migration, one version source (`VERSION`), one `SHA256SUMS`/`manifest.json`, one `bump-version.vsh` path, no cross-repo sync.
- **Cons:** Consumer binary carries harness code (embedded data already makes it ~5MB, harness is minor).
- **When to choose:** Until harness consumer impact or binary size justifies split.

### 2. Soft-extract (internal package, same repo/release)

- **What:** Move harness to `modules/agent_toolkit_harness/` within same repo, still one binary/release, but import boundaries enforce `agent_toolkit_harness` → `agent_toolkit_core` (not vice versa). Build still `make.vsh build-cli` one ELF.
- **Pros:** Clear ownership, test isolation, still one release.
- **Cons:** Refactor churn, still one binary.

### 3. Hard-split (separate repo/binary)

- **What:** New repo `agentic-harness` builds `agent-toolkit-harness` binary, consumer binary is `agent-toolkit` without harness. Two releases, two `VERSION`, two `SHA256SUMS`.
- **Pros:** Smallest consumer binary, independent versioning.
- **Cons:** High cost: two release matrices, two Homebrew/AUR formulas, two sets of adapters, cross-repo integration tests, version skew.

## Criteria for revisiting

Revisit only if **all** are true:

- Consumer telemetry or `insights` shows >20% of installs are consumer-only and blocked by harness size/deps.
- Harness feature velocity requires breaking changes that would churn consumer binary (e.g. major `swarm` protocol change).
- A champion owns the second repo/release pipeline (Homebrew/AUR + PyPI + npm + GHCR) for ≥6 months.
- ADR drafted and accepted (not just issue #279 discussion).

## Decision

**Stay one binary for 12 months.** No package split in this issue. RFC stays open for transparent review; implementation blocked until ADR accepted. See `docs/ARCHITECTURE.md#Plane boundaries and import rules (#982)` and ADR-030 (TUI retired, preserved in git history).

## Out of scope

Implementing a package split in this issue.
