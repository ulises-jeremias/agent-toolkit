# V `loop` command family

**Issue:** [#523](https://github.com/ulises-jeremias/agent-toolkit/issues/523) (EPIC 5 [#462](https://github.com/ulises-jeremias/agent-toolkit/issues/462), disposition [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) **REDESIGN**)  
**Concurrency:** [ADR-020](../adrs/ADR-020-v-concurrency.md)

Not a 1:1 port of Python `loop/runner.py` threads. The V CLI is a **single-threaded supervisor**; each iteration is an OS process (ProcessService). LLM PATH runners (`--runner claude|opencode|codex|cursor|copilot|muse|pi`, prompt as argv, wall timeout, transcript capture) run the adapter binary directly; unknown or missing runners **fail closed to skeleton** (`--no-llm` / `--runner skeleton`). Cursor probes `cursor-agent` → `agent` → `cursor` (Python-era #228); copilot uses `-p -s --no-ask-user --allow-all` (#229). `AGENT_TOOLKIT_LOOP_MODEL` pins `--model` for every runner whose CLI supports it (all but cursor).

Subcommands: `init` / `run` / `list` / `status` / `audit` / `cost` / `schedule` / `sync` / `templates`.

- Instances live under workspace `loops/<name>/loop.yaml` (+ `STATE.md`, `runs/`).
- Bundled templates come from toolkit `loops/*/loop.yaml`.
- `gh` mutations are enforced in-core: per-run `gate-bin/gh` shim → hidden `loop gate-exec` (`classify_gh_argv` / `gate_evaluate`); Tier L1 is read-only Stages (not Layers — see `docs/ARCHITECTURE.md`); merge/close require Stage L3 + allowlist + fresh verifier receipt (`loop gate-issue-receipt`); AI attribution on outbound prose; denials audit-logged to `gate-denials.jsonl`.
- `schedule` writes a systemd user unit on Unix; **not supported on Windows**.
