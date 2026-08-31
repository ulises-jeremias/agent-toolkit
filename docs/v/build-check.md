# V build --check

**Issue:** [#510](https://github.com/ulises-jeremias/agent-toolkit/issues/510)

`agent-toolkit build --check` dry-runs Tier-1 emitters into a temp dir. Compile errors fail the check. For shared plugin products (`agent-toolkit-core`, `agent-toolkit-agents`, `agent-toolkit-forge`), it also compares Cursor/Claude Code `skills/` + `agents/` digests against committed `plugins/` (digest parity with `plugin check`). OpenCode is compile-validated only. Supports `--target`, `--product`, `--output`, and `--json`.
