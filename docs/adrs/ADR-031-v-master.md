# ADR-031 — V master as baseline for entire Agent Toolkit (including Desktop)

- **Status:** Accepted (2026-08-31)
- **Deciders:** ulises-jeremias
- **Related issues:** Desktop EPICs #1007-1015, #279, user request 2026-08-31 “usar directamente la versión de la rama master de V para todo agent toolkit”
- **Supersedes:** implicit pin `0.5.2` in `.v-version` (2026-07-12) for all surfaces
- **Amends:** ADR-012 (Python/V coexistence), ADR-020 (V concurrency), ADR-026 (full-embed) build assumptions

## Context

Agent Toolkit pinned `V 0.5.2` (`51bda99`, stable release 2026-07-12) via `.v-version` + `.github/actions/setup-v` (download `v_linux.zip` etc.). `vlang/gui` (USE for Desktop), `vglyph`, `x/async`, `eventbus`, `sokol` all evolve on `vlang/v@master`; weekly tags (`weekly.2026.08` etc.) lag behind `master` HEAD (`78e581e` at time of decision). Desktop feasibility requires the latest `master` capabilities (docking, canvas, virtualized lists, inspector) without backporting, and the user explicitly requested `V master` for the **entire** product, not just GUI, to avoid split-brain toolchain (core/cli/server/desktop on different compilers).

Staying on `0.5.2` would force Desktop to avoid `master-only` APIs or carry conditional compilation, increasing backlog risk. Using `master` for the whole repo keeps one compiler, one `V` stdlib surface, and aligns with `vlang/gui`’s own `master` tracking.

## Options

1. **Stay on `0.5.2` stable for all** — low churn, reproducible, but Desktop cannot use `master-only` `vlib` APIs; `vlang/gui` spikes may be blocked.
2. **Split:** `core/cli/server` on `0.5.2`, `desktop` on `master` — two compilers in one repo/release, doubles CI matrix and `setup-v` complexity; violates one-engine/one-release (ADR-018).
3. **Adopt `V master` for entire toolkit (chosen)** — one compiler (`master` HEAD), `setup-v` clones `vlang/v@master` and builds via `make`, `V --version` reports `master` SHA, Desktop backlog validates against `master`.

## Decision

Adopt `V master` as baseline for the entire Agent Toolkit.

- `.v-version` → `master` (literal, not tag).
- `.github/actions/setup-v/action.yml` → if `PIN == "master"` then `git clone --depth 1 https://github.com/vlang/v && make -j$(nproc)` and expose `vlang-master/v` (instead of downloading release zip).
- All modules (`agent_toolkit_core`, `agent_toolkit_cli`, `agent_toolkit_server`, `agent_toolkit_gui` future) build with `V master`; `make.vsh vet/test/build-cli` run on `master`.
- Release artifacts (floating binaries + `SHA256SUMS` + `manifest.json` + SBOM) are produced from `master`; `bump-version.vsh` still the single version source (`VERSION`), but compiler is `master`.
- Desktop EPICs #1007-1015 and sub-issues #1016-1032 are retroactively re-baselined to `V master` (titles mentioning `0.5.2` are superseded by this ADR).
- This ADR is the single source for the decision; no per-surface `V` pin.

## Consequences

- **Positive:** Desktop can use latest `vlib/x/async`, `eventbus`, `sokol/audio`, `gg`, `vglyph` without version skew; one CI compiler path; aligns with `vlang/gui` upstream.
- **Negative:** `master` is less stable than `0.5.2` — CI may need `allow_failure` for `V master nightly` until upstream stabilizes; contributors must build `V master` locally (`make` ~1-2 min). Mitigated by pinning the exact `master` SHA in CI logs (`78e581e` at adoption) and documenting it here.
- **Neutral:** `V 0.5.2` remains the last stable fallback; revert is `echo 0.5.2 > .v-version` + restore `setup-v`.

## Validation plan

- `cat .v-version` == `master`, `gh api repos/vlang/v/commits/master --jq .sha` matches `78e581e`.
- `VJOBS=2 ./make.vsh vet` and `VJOBS=2 ./make.vsh build-cli` pass on `master` (or record blocker in Phase 0 spike #1018).
- `.github/actions/setup-v` `if [ "$PIN" = "master" ]` branch exercised in `validate.yml` (or `check-build`).
- Desktop feasibility spike #1018 re-validates window/canvas/docking/virtualized list/Markdown/dialogs/clipboard/dnd/notifications/audio/worker→GUI/high-DPI/packaging on `master` across Linux/macOS/Windows native.

## References

- `.v-version`, `.github/actions/setup-v/action.yml`, `gh api repos/vlang/v/commits/master` (`78e581e`), `V 0.5.2 51bda99`
- `vlang/gui` https://github.com/vlang/gui (ROADMAP, WINDOWS.md, examples/dock_layout.v, snake.v)
- Desktop EPICs #1007-1015, issues #1016-1032 (re-baselined), ADR-012, ADR-020, ADR-026, ADR-030
- User request 2026-08-31 “usar directamente la versión de la rama master de V para todo agent toolkit! no solo la GUI”

**Verified:** 2026-08-31
