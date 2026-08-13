# V capability `update`

**Issue:** [#516](https://github.com/ulises-jeremias/agent-toolkit/issues/516)

Refreshes installed AI-tool **profiles** from toolkit capability data (not executable self-update):

- Tools: `claude-code`, `cursor`, `opencode`, `windsurf`, `pi`
- `--check` dry-run (exit non-zero when changes pending)
- `--pin VERSION` / auto data refresh via `DataSync.ensure_data`
- Atomic writes via `FsService.write_atomic`

See also ADR package-manager ownership (#489) — this command updates content, not the CLI binary.
