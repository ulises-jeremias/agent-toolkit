# V `doctor` command (read-only)

**Issue:** [#505](https://github.com/ulises-jeremias/agent-toolkit/issues/505)

Read-only health report. `--json` includes `engine`, `version`, and `platform` for migration observability. `--fix` is accepted and ignored (no writes). Missing tools are warnings so the seed stays hermetic; a missing toolkit root is an error.
