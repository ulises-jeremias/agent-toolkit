# V `devcompanion` / `dc` command family

**Issue:** [#525](https://github.com/ulises-jeremias/agent-toolkit/issues/525) (EPIC 5 [#462](https://github.com/ulises-jeremias/agent-toolkit/issues/462), disposition [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) **PORT**)

Filesystem job queue matching Python `cli/devcompanion.py` (alias **`dc` retained**):

- `queue <project> --request "..." | --template NAME` — write pending job JSON
- `run-once [--no-llm]` — oldest pending job; **`--no-llm` is skeleton-only (no network)**
- `status` / `done <job-id>` / `sync-todos`

Queue layout: workspace `.devcompanion/queue/*.json`, or harness dirs when `HARNESS_DC_HOME` / `HARNESS_DIR` is set. LLM runners stay a workstation concern; V falls back to the skeleton plan (same as Python when no runner is found). No tmux/Herdr.
