# V CLI shell / dispatcher

**Issue:** [#553](https://github.com/ulises-jeremias/agent-toolkit/issues/553)  
**Spike:** [`vlib-cli-spike.md`](vlib-cli-spike.md)

Single dispatch table matching `docs/CLI_SURFACES.md` consumer/advanced split, aliases (`dc`, `rollback`), help via `vlib/cli` grouping, bad-flag exit **2**, unknown command exit **1**. Business logic stays in core; unfinished advanced commands return `not_implemented`. Consumer `install` is wired (#607).

Build: `make build-cli` → `build/agent-toolkit-v`.
