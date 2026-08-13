# Python↔V golden CLI parity harness

Design: [`docs/compatibility/parity-harness-design.md`](../../docs/compatibility/parity-harness-design.md)

```bash
make build-cli
python3 tests/parity/run_harness.py --v-bin build/agent-toolkit-v
```

Seed fixtures: `fixtures/seed.json` (`version`, `help`, `inventory`, `doctor`, bad-flag).
Failures cite `[command] CLASS: …`.

## Disposition fixtures (insights / release)

`V_SEMANTIC` fixtures assert V help encodes DEPRECATE (#526) / REMOVE (#527) without
requiring Python parity (quarantined `agent-toolkit-py` may still implement them).
See `docs/v/advanced-command-disposition.md` (#560).

Workflow path filters include `docs/v/**` and CLI surface docs so disposition doc
drift re-runs the harness.
