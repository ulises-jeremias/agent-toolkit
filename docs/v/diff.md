# V `agent-toolkit diff`

**Issue:** [#515](https://github.com/ulises-jeremias/agent-toolkit/issues/515)

Compiles selected products/targets into a temp tree and compares file digests against `plugins/` (Python `cli/diff.py` parity):

- Default targets: Tier-1 (`cursor`, `claude-code`, `opencode`)
- Reports `+` added / `~` changed; exit non-zero when any changes
- Flags: `--target`, `--product`, `--json`

Related: `build --check` (#510) for plugin drift gates.
