# Python↔V golden CLI parity harness

Design: [`docs/compatibility/parity-harness-design.md`](../../docs/compatibility/parity-harness-design.md)

```bash
make build-cli
python3 tests/parity/run_harness.py --v-bin build/agent-toolkit-v
```

Seed fixtures: `fixtures/seed.json` (`version`, `help`, `inventory`, `doctor`, bad-flag).
Failures cite `[command] CLASS: …`.
