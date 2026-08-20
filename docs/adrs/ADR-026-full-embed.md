# ADR-026: Full-Embed — V Binary Carries All Capability Data (Supersedes ADR-011)

**Status:** Accepted
**Date:** 2026-08-20
**Deciders:** maintainers (standalone offline-first epic [#766](https://github.com/ulises-jeremias/agent-toolkit/issues/766), spikes #767-773, PR #778)
**Supersedes:** ADR-011 (Hybrid) — see ADR-011 “Rejected: Full embed-only”
**Amends:** ADR-015 tiers (adds 3a in-memory `embedded` + 3b FHS `/usr/share`)

## Context

After `ADR-011` (Hybrid C) and `ADR-015` (tiers) shipped in v1.16.0, a fresh `yay -S agent-toolkit-bin` (AUR `1.16.0-1`) still failed:

* `toolkit root not found: Cannot locate agent-toolkit data directory` (`paths.v:124`, `install.v:50` offline-only, #557)
* then with `AI_WORKSPACE=~/.ai-workspace` → `Toolkit: ~/.ai-workspace` → `Profile source not found for cursor...` (`install.v:216`) because `is_valid_toolkit_root()` (`paths.v:25`) misclassifies the harness workspace (`profiles/oss-contrib.yaml` + `loops/`).
* `yay` also showed staleness `agent-toolkit 1.10.0` vs `-bin 1.16.0`.

Spikes #767-773 evaluated every alternative (matrix in #766): `A1` full-embed ELF, `A2` gzip, `B1` source tarball, `B2` data artifact, `C` Hybrid baseline, `D` FHS sidecar `/usr/share`, `E` workstation bootstrap (`agentic-workstation#210`), `F` wheel, `G` deprecate source. The evaluation was done on **clean Arch without workstation** (`XDG_DATA_HOME=/tmp/empty`, `AI_WORKSPACE` set, `AGENT_TOOLKIT_OFFLINE=1`) — the “súper completo standalone” UX the CLI must satisfy without ever installing `agentic-workstation`.

Hybrid’s minimal baseline left `install` still needing `XDG` download or workstation bootstrap. Standalone requires the first `install` to be green offline.

## Decision

**Adopt full-embed (Option A) with FHS sidecar as tier 3b compat.**

* Generate `modules/agent_toolkit_core/embedded_data.v` at `make.vsh gen-embedded` via `scripts/generate-embedded-data.py` (`$embed_file('../../skills/...')` per file, 1179 files, ~3.7M payload, `+4.8M` ELF `3.8M→8.6M`). Build `build-cli` depends on `gen-embedded`.
* `paths.v` tier order becomes: `override (AGENT_TOOLKIT_ROOT/AI_WORKSPACE, sanitized)` → `xdg_data` → `xdg_cache` → **`3a` in-memory `embedded` (`embedded_is_valid_root()` → path `embedded`, tier `embedded`)** → **`3b` FHS `/usr/share/agent-toolkit/data`** → **`3c` next-to-exe sidecar** → `checkout` → `cwd`. Sanitization: `is_harness_workspace()` (`AGENTS.md`/`knowledge`) without `has_toolkit_tool_data()` (`profiles/claude-code`, `profiles/cursor`, `skills`, `plugins`) → skip override, so `AI_WORKSPACE=~/.ai-workspace` correctly falls to `embedded`.
* `data_io.v` abstraction (`is_embedded_root`, `data_is_dir/file/read/ls/map`) handles `embedded/` prefix (strip 9 chars) and routes to `embedded_*` helpers; `install.v`/`update.v` use `data_*` and `embedded_read` for `stage_install_mapping`/`update_file_hash`.
* Release `release.yml` still publishes floating binaries + `SHA256SUMS`; data artifact `B2` is **not** needed for standalone now, but `FHS probe` keeps `aur-packages` compat if PKGBUILD ships sidecar.

## Consequences

* **Positive:** `yay -S agent-toolkit-bin` (no prior `XDG`, no workstation, no network) → `doctor --offline` `root: embedded, ok true`, `install --dry-run` all 6 tools `Toolkit: embedded` green (verified). No more `toolkit root not found`. Both AUR packages can stay at same `1.16.0` and future `1.17.0` will ship new payload in the ELF; `pacman -Syu` still owns binary, `agent-toolkit update` stays capability-only (ADR-017).
* **Negative:** ELF grows; capability updates require a new tag+release (no longer XDG-only hotfix). Mitigated by `+8.6M` still < `#533` budget and `XDG_DATA` override wins, so a fresher `update` can still override without rebuild.
* **Rejected for now:** `B2` data artifact alone (still needs sidecar), `C` minimal baseline (not “ya tiene todo”), `E` workstation bootstrap (kept 1 release as compat in `agentic-workstation#210`, to be retired).

## Validation plan

* `XDG_DATA_HOME=/tmp/empty XDG_CACHE_HOME=/tmp/empty ./build/agent-toolkit doctor --json` → `root: embedded`
* `install --dry-run` from `/tmp` without `AI_WORKSPACE` and with `AI_WORKSPACE=~/.ai-workspace` → both `embedded`
* `update --check` → `Data: embedded` without network
* `make.vsh test`, `release.yml` 5-platform, `SHA256SUMS` still pass (CI `feat/embed-full-data` run)

## References

* ADR-011 (`ADR-011-resource-packaging.md`), ADR-015 (`ADR-015-runtime-resolution.md`), ADR-017, ADR-018, ADR-022
* `scripts/generate-embedded-data.py`, `modules/agent_toolkit_core/embedded_data.v`, `data_io.v`, `paths.v`, `install.v`, `update.v`, `make.vsh:gen-embedded`
* Issues #767-773 spikes, #774 ADR, #775 core, #766 epic, `aur-packages#7`
* Repro: `chezmoi init --apply --source=. --config agentic-workstation.toml` with `agent-toolkit-bin`

**Verified:** 2026-08-20
