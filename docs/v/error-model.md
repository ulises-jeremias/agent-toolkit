# V domain error model and exit codes

**Issue:** [#498](https://github.com/ulises-jeremias/agent-toolkit/issues/498)  
**ADR:** [ADR-010](../adrs/ADR-010-cli-core-boundary.md)

Core returns `DomainError` with `ErrorClass` (`user`/`config`/`env`/`external`/`network`/`internal`/`usage_flags`). CLI maps via `map_exit`:

| Class | Exit |
|-------|------|
| ok | 0 |
| usage_flags | 2 |
| all others | 1 |

Core must not print; CLI renders and exits.
