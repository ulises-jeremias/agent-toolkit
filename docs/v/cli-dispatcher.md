# V CLI shell / dispatcher

**Issue:** [#553](https://github.com/ulises-jeremias/agent-toolkit/issues/553)  
**Spike:** [`vlib-cli-spike.md`](vlib-cli-spike.md)

## Layout

| File | Role |
|------|------|
| `modules/agent_toolkit_cli/commands.v` | `cli.Command` tree: Consumer/Advanced `group`, aliases (`dc`, `rollback`), nested families, global `--json`/`--quiet`, `-V` |
| `modules/agent_toolkit_cli/dispatch.v` | AT wrapper: walk tree (does **not** call `Command.parse` — keeps integer exit codes), peel leading `--json`/`--quiet`, bad flags → **2**, unknown command → **1**, render CommandResult |
| `modules/agent_toolkit_cli/options.v` | Flag/arg parsers → core option structs |
| `modules/agent_toolkit_cli/render.v` | Human / JSON / quiet output |

Business logic stays in `agent_toolkit_core`. Root `--help` uses `Command.help_message()` (grouped sections). Per-command `--help` keeps rich core/`subcommand_help` text for parity.

Build: `./make.vsh build-cli` → `build/agent-toolkit` (canonical, #555) and `build/agent-toolkit-v` (parity harness alias).
