# Spike: `vlib/cli` vs Agent Toolkit CLI contract

**Status:** Completed research  
**Date:** 2026-08-12  
**Issue:** [#554](https://github.com/ulises-jeremias/agent-toolkit/issues/554)  
**Program:** [#456](https://github.com/ulises-jeremias/agent-toolkit/issues/456)  
**Docs baseline:** [vlib/cli](https://modules.vlang.io/cli.html) — V **0.5.2** (Verified: 2026-08-12)  
**Contract:** [`docs/compatibility/cli-contract.yaml`](../compatibility/cli-contract.yaml)

## Recommendation (go / no-go)

**GO for `vlib/cli` as the primary parser** for the experimental V binary dispatcher, with a **thin AT wrapper** for:

1. Exit-code mapping (domain errors → ADR-010 classes; bad flags → **2**)
2. Consumer vs advanced help grouping (map to `Command.group`)
3. Shell completion (keep generating from contract / Python `completion.py` until a V generator exists)
4. JSON error envelopes (CLI render layer; not inside `vlib/cli`)

**NO** third-party CLI framework without a new ADR and evidence that `vlib/cli` cannot meet nested commands + aliases + global flags.

## Matrix

| Feature | Python today | vlib/cli (0.5.2) | Gap / workaround |
|---------|--------------|------------------|------------------|
| Nested commands | Custom dispatch in `cli/main.py` + per-command argparse | First-class `Command.commands` + `setup`/`parse` | None — use nested `cli.Command` |
| Aliases (`dc`, …) | Explicit aliases in `ADVANCED_COMMANDS` / handlers | `Command.alias` (e.g. `s` for `sub`) | Map each contract alias onto `alias`; multi-alias may need multiple stub commands or a pre-parse rewrite |
| Global flags | Limited / per-command | `Flag.global` + `Inherited flags:` help section | Prefer global flags on root command for `--json` / verbosity when introduced |
| Help grouping | Custom consumer vs advanced text in `main.py` | `Command.group` sections in `--help` | Put consumer commands in one group, advanced in another; keep wording parity SEMANTIC |
| Exit 2 on bad flags | argparse → exit 2 | `parse` does not document argparse-identical codes | **Wrapper:** catch parse failures / unknown flags and `exit(2)` in CLI adapter (ADR-010) |
| Completion | `cli/completion.py` | No built-in shell completion generator in `vlib/cli` | Generate from `cli-contract.yaml` or keep Python generator during dual-run; do not block dispatcher |
| Man pages | Limited | `Command.manpage` / `print_manpage_for_command` | Optional later; not on critical path |
| Custom JSON errors | Ad-hoc `--json` in some commands | Not a `vlib/cli` concern | CLI render layer over domain errors (ADR-010 / #498) |
| Passthrough args | Some commands accept trailing argv | `Command.args` after flags | Use for runner/tool passthrough; document per-command in contract |
| Examples / learn-more | Scattered docs | `examples []string`, `learn_more` | Optional UX improvement |

## Evidence notes

- Nested subcommands and aliases are documented with a runnable example on modules.vlang.io.
- Help layout supports inherited/global flags and grouped commands — enough to replace the hand-written consumer/advanced help split without a custom parser.
- Man page support exists but is not required for parity seed fixtures (`version`, `help`, `inventory`, `doctor`).

## Non-goals

- Implementing the root dispatcher in this spike (blocked issue proceeds after merge).
- Inventing Bobatea or other TUI CLI stacks.

## Handoff

Root CLI dispatcher / shell issue should depend on this spike and on error-model [#498](https://github.com/ulises-jeremias/agent-toolkit/issues/498).

**Verified:** 2026-08-12
