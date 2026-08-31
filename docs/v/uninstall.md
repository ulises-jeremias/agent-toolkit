# V uninstall / rollback from receipts

**Issue:** [#514](https://github.com/ulises-jeremias/agent-toolkit/issues/514)

Receipt-based uninstall matching Python `cli/uninstall.py`:

- remove only `ownership=created` artifacts; skip `merged`
- refuse path-escape; `--dry-run` lists without deleting
- delete `<target>-agent-toolkit-profiles.json` after success
- CLI: `uninstall` / alias `rollback`; flags `--tools`, `--dry-run`, `--rollback`

Depends on [#512](https://github.com/ulises-jeremias/agent-toolkit/issues/512) / [#513](https://github.com/ulises-jeremias/agent-toolkit/issues/513).
