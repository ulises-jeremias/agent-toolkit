# Performance baseline

**Issue:** [#533](https://github.com/ulises-jeremias/agent-toolkit/issues/533)  
**Parent:** [#463](https://github.com/ulises-jeremias/agent-toolkit/issues/463) / [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)

Migration is not a performance project. These numbers exist so later changes can catch **severe** regressions. They are **not** release-matrix acceptance tests.

## Environment

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| OS / arch | Linux x86_64 |
| V | 0.5.2 (`v version` 45e92d1), pin `.v-version` |
| Commit | `b356e19` (docs/python-api-audit; methodology applies to `main` at audit time) |
| N | 7 timed runs after 1 warmup; median and p95 |
| Python | `uv run --project packages/pypi/agent-toolkit-cli --directory . agent-toolkit-py` (not the V launcher; no root uv workspace) |
| V binary | `./make.vsh build-cli` → `build/agent-toolkit` (debug, tcc→cc fallback) |
| V `-prod` | **Does not build** on 0.5.2: `import json` is a **error** under `-prod` (we MUST keep `json`, not json2) |
| PyInstaller | N/A — `v1.10.0` GitHub Release has **zero** assets |

`AGENT_TOOLKIT_ROOT` = repo root. RSS not recorded (`/usr/bin/time` absent on the host).

## Results (median / p95, milliseconds)

| Command | V debug | Python CLI |
|---------|---------|------------|
| `--version` | 4.7 / 4.9 | 42.8 / 44.2 |
| `--help` | 4.9 / 5.5 | 40.9 / 42.6 |
| `inventory` | 8.6 / 8.9 | 164 / 169 |
| `doctor` | 5.6 / 5.9 | 735 / 760 |
| `build --check` (1 run) | 998 | 714 |

Binary size (debug ELF): **3.8 MiB** (3 779 000 bytes).

Startup/`doctor`/`inventory` are much faster in V. `build --check` is not — compiler work is comparable; do not gate on it yet.

## Proposed non-regression thresholds (Linux x86_64, V **debug** `./make.vsh build-cli`)

Informational until a second machine reproduces. Fail a dedicated job only after they are wired (not Required CI today):

| Metric | Threshold | Rationale |
|--------|-----------|-----------|
| `--version` median | < 25 ms | ~5× headroom vs 4.7 ms |
| `--help` median | < 25 ms | same |
| `inventory` median | < 50 ms | ~6× vs 8.6 ms |
| `doctor` median | < 50 ms | ~9× vs 5.6 ms |
| debug binary size | < 8 MiB | ~2× vs 3.8 MiB |
| `build --check` | no SLO | V not faster than Python in this sample |

Do **not** apply these to Python or to `-prod` until `-prod` builds with `import json`.

## Reproduce

```bash
./make.vsh build-cli
# time as in this report: 7 runs of build/agent-toolkit {--version,--help,inventory,doctor}
```
