# V atomic install transaction

**Issue:** [#513](https://github.com/ulises-jeremias/agent-toolkit/issues/513)

`InstallTransaction` stages profile install writes, commits with `FsService.write_atomic`, and rolls back created files (or restores force-overwrites) if commit/receipt save fails:

- refuse path-escape at stage time
- `--dry-run` / preserve-without-`--force` parity with Python `cli/install.py`
- receipt save only after successful commit (`save_install_receipt`)

Depends on [#512](https://github.com/ulises-jeremias/agent-toolkit/issues/512) receipt parser. Consumer CLI wiring is [#607](https://github.com/ulises-jeremias/agent-toolkit/issues/607). Uninstall/rollback CLI is [#514](https://github.com/ulises-jeremias/agent-toolkit/issues/514).
