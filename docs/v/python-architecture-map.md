# Python architecture map (historical → current)

**Issue:** [#477](https://github.com/ulises-jeremias/agent-toolkit/issues/477)  
**Parent:** [#457](https://github.com/ulises-jeremias/agent-toolkit/issues/457) (EPIC 0)  
**Product runtime:** native V binary is canonical ([#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555)). Python on PyPI is an **npm-style trampoline only** ([python-fallback.md](python-fallback.md) / [ADR-021](../adrs/ADR-021-pypi-binary.md)). The quarantined Python CLI (`agent-toolkit-py`, `cli/` / `compiler/` / …) was **removed** in v1.13.0.

Tree today: `packages/pypi/agent-toolkit-cli/src/agent_toolkit/`.

```
Python package (agent_toolkit) — trampoline only
├── launcher.py          # product entry: exec V binary (ADR-021)
├── __init__.py / __main__.py
├── bin/                 # bundled native binary (wheel)
└── data/                # wheel capability payload (skills/plugins/…)
```

CLI business logic, compiler, installer, loop, and swarm live in **`modules/agent_toolkit_*` (V)**. Packaging / docs / schema pytest that does not import a Python CLI remains under `tests/`.

## Historical classification (pre-v1.13.0)

Useful when reading older issues/ADRs. Those Python modules no longer ship.

| Class | Former modules | Current home |
|-------|----------------|--------------|
| **PURE LOGIC** | `compiler/` | V emitters / loader in `agent_toolkit_core` |
| **I/O** | `installer/`, workspace/memory CLI | V install / workspace / memory |
| **EXTERNAL PROCESS** | `loop/`/`runner/`, swarm | V loop / swarm (ADR-020 process-per-run) |
| **GENERATED DATA** | `plugins/`, `catalogs/` | Unchanged SoT; V + wheel `data/` |
| **NETWORKED** | former `data_sync.py` | V update / capability refresh |

## Wave order (completed)

1. Foundation + pin (`.v-version` 0.5.2)
2. Read-only (`version`/`help`/`inventory`/`doctor`)
3. Install lifecycle
4. Consumer skills/mcp/plugin
5. Advanced PORT/REDESIGN per [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560)

`insights` is DEPRECATE; `release` is REMOVE (CI / RELEASING, not product CLI).

## Security callouts

- Launcher must not download unsigned blobs at runtime (ADR-021 A; [#563](https://github.com/ulises-jeremias/agent-toolkit/issues/563)).
- Capability data in the wheel / `AGENT_TOOLKIT_ROOT` is the trusted tree for offline installs.
