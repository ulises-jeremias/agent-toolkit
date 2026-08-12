# V build --check

**Issue:** [#510](https://github.com/ulises-jeremias/agent-toolkit/issues/510)

`agent-toolkit build --check` dry-runs Tier-1 emitters into a temp dir. Compile errors fail the check. For gen-surfaces products (`agent-toolkit-core`, `agent-toolkit-agents`, `agent-toolkit-forge`), also compares Cursor/Claude Code `skills/` + `agents/` digests against committed `plugins/` (ADR-003 dual-run). OpenCode is compile-validated only. Supports `--target`, `--product`, `--output`, and `--json`.
