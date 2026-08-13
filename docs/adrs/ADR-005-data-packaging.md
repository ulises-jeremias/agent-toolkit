# ADR-005: Wheel / Data Packaging Sources of Truth and Resolution Order

**Status:** Accepted  
**Date:** 2026-08-06  
**Deciders:** maintainers (Wave 3 #266, parent #263)

> **Amendment (V binary-first):** For the V product and dual-run V path, runtime resolution order is defined by [ADR-015](ADR-015-runtime-resolution.md) ([#547](https://github.com/ulises-jeremias/agent-toolkit/issues/547)). This ADR remains the historical Python wheel-era record; where they differ, ADR-015 wins for V.

## Context

Toolkit data can come from multiple places: editable repo checkout (`skills/`, `profiles/`, `loops/` at repo root), wheel-bundled `agent_toolkit/data/` (populated by `scripts/prepare-package-data.sh` before `uv build`), XDG cache (`~/.cache/agent-toolkit` or `~/.local/share/agent-toolkit/data`), or a GitHub Release tarball download. The resolution logic lives in `packages/pypi/agent-toolkit-cli/src/agent_toolkit/_paths.py` / `data_cache.py` / `data_sync.py` and is tribal knowledge for Homebrew/AUR packagers (#257/#258).

Brew/AUR bugs stem from misunderstanding this. Bus-factor hotspot: not documented centrally.

## Decision

### Source of truth

- **Canonical content SoT:** the monorepo trees `skills/`, `agents/`, `loops/`, `profiles/`, `mcp/`, `catalogs/`, `distributions/`, `packs/`, `capabilities/` at repo root. These are the only human-edited sources.
- **Wheel SoT:** `packages/pypi/agent-toolkit-cli/src/agent_toolkit/data/` is a **generated copy** of the canonical trees (via `scripts/prepare-package-data.sh`). It is gitignored and rebuilt on every `uv build`. Wheel installs never read the repo root.
- **XDG cache SoT:** `~/.local/share/agent-toolkit/data` (or `XDG_DATA_HOME`) is a **derived cache** populated from a GitHub Release tarball by `data_sync.py` / `data_cache.py`. It is not committed.

### Resolution order (runtime)

Implemented in `find_toolkit_root()` (`_paths.py`):

1. **Env override** — `AGENT_TOOLKIT_ROOT` / `AI_WORKSPACE` if set and contains `skills/` or `profiles/` (user-forced checkout; highest priority, also offline mode)
2. **importlib.resources / wheel data** — `importlib.resources.files("agent_toolkit").joinpath("data")` and `agent_toolkit/data/` next to the package (the wheel-bundled copy). This is the normal `pip install` / `uvx` path.
3. **XDG cache** — `~/.local/share/agent-toolkit/data` (or `XDG_CACHE_HOME/agent-toolkit`) if present, with optional GitHub Release download on first run (when not offline). See `data_sync.py:download_data()` and `data_cache.py:ensure_cached_data()`.
4. **Editable walk-up** — walk parents of `agent_toolkit/_paths.py` looking for `skills/` + `loops/` (development checkout without install)
5. **CWD fallback** — `Path.cwd()` with `skills/`/`loops/`

If none is found, `find_toolkit_root()` raises `EnvironmentError` with a hint to set `AGENT_TOOLKIT_ROOT` or allow network access for the first-run download.

Offline (`AGENT_TOOLKIT_OFFLINE=1|true|yes`) skips the network step and only checks the XDG cache / bundled data.

### Packaging notes

- **Wheel build:** `scripts/prepare-package-data.sh` copies all capability trees into `packages/pypi/agent-toolkit-cli/src/agent_toolkit/data/` before `uv build --project packages/pypi/agent-toolkit-cli`. CI job `build-package` runs this; local dev must run it before `pip install` from sdist.
- **Editable install:** `uv sync --project packages/pypi/agent-toolkit-cli --all-extras` + `AGENT_TOOLKIT_ROOT=$PWD` uses the repo root directly; no need to prepare package data. The repo root is not a uv workspace.
- **Homebrew / AUR (current):** Formula and `agent-toolkit-bin` install **GitHub Release V binaries** ([ADR-023](ADR-023-homebrew.md), [ADR-024](ADR-024-aur.md)). They do not consume this Python wheel. See [`distribution/`](../../distribution/README.md).
- **Historical Python-wheel packaging notes:** if unpacking wheel `data/` separately, set `AGENT_TOOLKIT_ROOT` and `AGENT_TOOLKIT_OFFLINE=1` in sandboxed builds (see #257/#258).

## Alternatives Considered

- **Always require AGENT_TOOLKIT_ROOT:** Rejected — breaks `uvx` / `pip install` one-liner UX.
- **Single source (only wheel data):** Rejected — editable development and tarball-cache fallback are needed for `uvx` first-run without bundling full data.
- **Rewrite path resolution in same PR:** Out of scope per issue; ADR documents existing order, follow-up may simplify `data_cache.py` vs `data_sync.py` duplication.

## Consequences

- **Positive:** Packager bugs become diagnosable; docs point to one resolution list.
- **Negative:** Resolution order is still complex (5 tiers) — future work should reduce tiers if feasible.
- **Risk:** Duplicate cache helpers (`data_cache.py` vs `data_sync.py`) diverge; ADR flags this as tech debt.

## References

- `packages/pypi/agent-toolkit-cli/src/agent_toolkit/_paths.py` (`find_toolkit_root`, `toolkit_root`)
- `packages/pypi/agent-toolkit-cli/src/agent_toolkit/data_cache.py` and `data_sync.py`
- `scripts/prepare-package-data.sh`
- `packages/pypi/agent-toolkit-cli/pyproject.toml` (`[tool.hatch.build.targets.wheel]` + sdist)
- `.github/workflows/validate.yml` job `build-package` (runs prepare-package-data.sh before uv build)
- Related packaging issues #257 (Homebrew), #258 (AUR)
