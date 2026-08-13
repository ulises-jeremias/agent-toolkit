# Python architecture map & classification

**Issue:** [#477](https://github.com/ulises-jeremias/agent-toolkit/issues/477)  
**Parent:** [#457](https://github.com/ulises-jeremias/agent-toolkit/issues/457) (EPIC 0)  
**Product runtime:** native V binary is canonical ([#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)). Python remains a fallback CLI (`agent-toolkit-py`) and the PyPI/npm launcher host until [#540](https://github.com/ulises-jeremias/agent-toolkit/issues/540).

Tree: `packages/pypi/agent-toolkit-cli/src/agent_toolkit/`.

```
Python package (agent_toolkit)
├── launcher.py          # product entry: exec V binary (ADR-021 / #535)
├── cli/                 # argparse CLI (fallback: agent-toolkit-py)
│   ├── consumer: install/update/uninstall/doctor/diff/skills/mcp/plugin
│   └── advanced: loop/workspace/memory/project/devcompanion/insights/build/inventory/matrix/release/swarm
├── compiler/            # IR + target emitters (plugins/)
├── installer/           # receipts, merge, sources
├── loop/ + runner/      # loop templates + process backends
├── swarm/               # swarm recipes + Herdr/tmux backends
└── cross-cutting: _paths.py, data_cache.py, data_sync.py, data/ (wheel payload)
```

## Classification

| Class | Modules | Migration note |
|-------|---------|----------------|
| **PURE LOGIC** | `compiler/` model, recipe parsing (partial), inventory/matrix tables | Ported or still dual; keep fixtures in `tests/parity/` |
| **I/O** | `installer/`, workspace/memory CLI, `data_cache.py`, `_paths.py` | V filesystem service; XDG/Windows path rules must match |
| **EXTERNAL PROCESS** | `loop/`/`runner/`, swarm backends, `project` clone, `insights` | ADR-020 process-per-run; do not clone Python threads |
| **CONCURRENT** | Python loop threads; swarm orchestration | **V: process-per-run only** (ADR-020). No `go` workers on 0.5.2 |
| **GENERATED DATA** | `plugins/`, `catalogs/`, wheel data via `scripts/prepare-package-data.sh` | Unchanged source of truth; V reads the same trees |
| **NETWORKED** | `data_sync.py` GitHub download; `mcp setup` | Secrets never in git; env names only |

## PLATFORM-SPECIFIC

`_paths.py` (XDG on Linux, `~/Library` on macOS, `%APPDATA%` on Windows). V must honor the same layout. Symlinks on Windows are a known risk ([#478](https://github.com/ulises-jeremias/agent-toolkit/issues/478)).

## Wave order (validated)

Research supported Waves 1–5; this map does **not** amend it:

1. Foundation + pin (`.v-version` 0.5.2)
2. Read-only (`version`/`help`/`inventory`/`doctor`)
3. Install lifecycle
4. Consumer skills/mcp/plugin
5. Advanced PORT/REDESIGN per [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560)

`insights` is DEPRECATE; `release` is REMOVE (CI, not CLI).

## Security callouts

- `data_sync.py` talks to GitHub — treat as networked; cache under user data dir.
- `launcher.py` must not download unsigned blobs at runtime (ADR-021 A; [#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)).
