# V CLI shell / dispatcher

**Issue:** [#553](https://github.com/ulises-jeremias/agent-toolkit/issues/553)  
**Spike:** [`vlib-cli-spike.md`](vlib-cli-spike.md)

## Layout

| File | Role |
|------|------|
| `modules/agent_toolkit_cli/commands.v` | `cli.Command` tree: Consumer/Advanced `group`, aliases (`dc`, `rollback`), nested families, global `--json`/`--quiet`, `-V` |
| `modules/agent_toolkit_cli/handlers.v` | `Command.parse` execute / pre_execute callbacks; maps parsed flags → `execute_command` |
| `modules/agent_toolkit_cli/dispatch.v` | `run()` → thin ADR-010 **bad-flag → exit 2** shim, then `Command.parse()`; `dispatch()` return-code walk for unit tests only |
| `modules/agent_toolkit_cli/options.v` | Flag/arg parsers → core option structs (used from handlers / test walk) |
| `modules/agent_toolkit_cli/render.v` | Human / JSON / quiet output |

Business logic stays in `agent_toolkit_core`. Production entry is idiomatic vlib/cli (`parse` + execute). The only hand-rolled argv pass is unknown-flag → **2** (vlib always `exit(1)`; see spike). Unit tests call `dispatch()` so they do not hit noreturn `parse()`.

Root `--help` uses `Command.help_message()` (grouped sections). Per-command rich help remains for test/parity paths via `subcommand_help`.

Build: `./make.vsh build-cli` → `build/agent-toolkit` (canonical) and `build/agent-toolkit-v` (parity harness alias).
