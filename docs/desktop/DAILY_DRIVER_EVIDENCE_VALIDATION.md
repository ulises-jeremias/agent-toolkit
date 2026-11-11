# Daily Driver evidence shape guard (Gate 0, #1668)

The hermetic validator in `apps/desktop/scripts/spikes/daily-driver-evidence.mjs` checks **JSON rows** mirroring the YAML run form in [DAILY_DRIVER_ACCEPTANCE.md](DAILY_DRIVER_ACCEPTANCE.md). It is deliberately not a provider adapter or an acceptance runner.

- `validateEvidence(rows)` rejects invalid rows, missing real-provider provenance, and any `pass` recorded using mock, replay, or unverified evidence.
- `packagedGateStatus(rows)` requires a packaged `P/pass` row for each D01–D07. Even then its strongest result is `evidence-recorded-needs-human-review`, **never** an automatic Gate 0 sign-off.
- Evidence metadata is **not authenticated**: a fabricated row can satisfy the schema. A human must inspect redacted recordings, installed binary checksums, logs, native provider identity and the actual diff.
- Do not commit tokens, proprietary conversation logs or private paths. Missing credentials/host remain `U/unverified`.

Run `cd apps/desktop && node --test scripts/spikes/daily-driver-evidence.test.mjs`. The existing Desktop `pnpm test` includes `scripts/spikes/*.test.mjs`.

This check neither changes the historical workflow ledger nor asserts that D01–D07 were executed. It is safe to revert without touching session data or the v1.49.0 release line.
