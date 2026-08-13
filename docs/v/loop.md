# V `loop` command family

**Issue:** [#523](https://github.com/ulises-jeremias/agent-toolkit/issues/523) (EPIC 5 [#462](https://github.com/ulises-jeremias/agent-toolkit/issues/462), disposition [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) **REDESIGN**)  
**Concurrency:** [ADR-020](../adrs/ADR-020-v-concurrency.md)

Not a 1:1 port of Python `loop/runner.py` threads. The V CLI is a **single-threaded supervisor**; each iteration is an OS process (ProcessService). Until ProcessService stdin exists, LLM PATH runners **fail closed to skeleton** (`--no-llm` / `--runner skeleton`).

Subcommands: `init` / `run` / `list` / `status` / `audit` / `cost` / `schedule` / `sync` / `templates`.

- Instances live under workspace `loops/<name>/loop.yaml` (+ `STATE.md`, `runs/`).
- Bundled templates come from toolkit `loops/*/loop.yaml`.
- `gh` mutations are classified in-core (`classify_gh_argv` / `loop_gate_allows`); L1 is read-only; merge/close require L3 + allowlist.
- `schedule` writes a systemd user unit on Unix; **not supported on Windows**.
