# V CLI contract fixtures

Golden checks for the **native V** binary (`tests/parity/run_harness.py`).

Formerly compared Python↔V; the Python CLI quarantine is removed. Fixtures now
assert V exit codes and output contracts only.

Disposition commands (`insights` / `release`) are covered as V-only semantics
([docs/v/advanced-command-disposition.md](../../docs/v/advanced-command-disposition.md)).
