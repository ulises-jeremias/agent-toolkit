# Insights migration — `agent-toolkit insights` → `bin/tool-insights` (DEPRECATE #526)

**Status:** DEPRECATE per `docs/v/advanced-command-disposition.md` #526 — `insights` is intentionally
removed from the V product CLI. Use the external analytics script.

## Summary

Python `agent-toolkit insights opencode|cursor|claude [--days N] [--output PATH]` (up to `fbb2280`)
ported to the standalone **external** tool `bin/tool-insights` (self-bootstraps at
`~/.local/share/tool-insights-venv`, uses Anthropic API). The V CLI retains a stub that prints a
migration notice and exits `0` for `--help`, `1` for any subcommand (see
`modules/agent_toolkit_cli/dispatch.v:287` `insights_help_text()`).

`context_budget` clip `2000` tokens (~8000 chars, V keeps `2000` char clip parity) formerly applied to
`memory inject` and devcompanion plan generation (`devcompanion.v:412` `plan[..2000]`), retained via
`modules/agent_toolkit_core/context_budget.v` `context_clip()` and `memory.v:memory_inject()`.

## Migration

| Before (Python V ≤ 1.12) | After (V ≥ 1.23) |
|---|---|
| `agent-toolkit insights opencode [--days N] [--output PATH]` | `python3 bin/tool-insights opencode [--days N] [--output PATH]` |
| `agent-toolkit insights cursor [--output PATH]` | `python3 bin/tool-insights cursor [--output PATH]` |
| `agent-toolkit insights claude --days 7 [--output PATH]` | `python3 bin/tool-insights claude --days 7 [--output PATH]` |
| `agent-toolkit insights --help` | `python3 bin/tool-insights --help`  (V stub also prints `insights_help_text()`) |

### `bin/tool-insights` (external, not V CLI)

Self-bootstraps its venv on first run (no `/tmp` dependency). See `AGENTS.md` *CI/Monitoring Scripts* /
`Knowledge Base` and `bin/tool-insights` header.

```bash
python3 bin/tool-insights --help
python3 bin/tool-insights opencode --days 30
python3 bin/tool-insights opencode --output ~/opencode-report.html
python3 bin/tool-insights cursor --output ~/cursor-report.html
python3 bin/tool-insights claude --days 7
python3 bin/tool-insights claude --days 7 --output ~/claude-report.html
```

All providers support `--output PATH` → HTML report; without it, Markdown to stdout.
`opencode` and `claude` support `--days N` (filter to last N days via SQLite `time_created`
or JSONL `created_at`).

### V CLI stub (`#526`)

```bash
build/agent-toolkit insights --help
# prints insights_help_text() with migration pointer, exit 0

build/agent-toolkit insights claude --days 7
# prints insights_help_text() + eprintln migration, exit 1
# flags --days / --output are accepted (parity #906) but still DEPRECATE
```

`insights claude --days 7 --json` is not a V JSON surface — use `bin/tool-insights`.

## `context_budget` clip 2000

`cli/context_budget.py:455` `clip(text, budget=2000)` word-truncated to 2000 tokens. V parity:

- `modules/agent_toolkit_core/context_budget.v:context_clip(text, 2000)` — `text[..2000]` char clip
- `modules/agent_toolkit_core/memory.v:memory_inject()` — clips final injection block to `2000` chars
- `modules/agent_toolkit_core/devcompanion.v:412` — `clip := if plan.len > 2000 { plan[..2000] } else { plan }`

Approximation `4 chars/token` → `2000` tokens ≈ `8000` chars; V keeps `2000` char wire parity for
plan `plan.md` rendering and `memory inject` output (see `docs/v/devcompanion.md` and `docs/v/memory.md`).

## References

- `modules/agent_toolkit_cli/commands.v:762` `insights_command()` — flags `--days`/`--output` (parity) but description stays `removed #526`
- `modules/agent_toolkit_cli/dispatch.v:287-303` `insights_help_text()` / `insights_subcommand()`
- `modules/agent_toolkit_core/context_budget.v` / `memory.v:memory_inject()` / `devcompanion.v:412`
- `docs/v/advanced-command-disposition.md` `insights` DEPRECATE #526
- `docs/v/python-fallback.md` — Python CLI quarantine removed, external fallback only
- Evidence: `git show fbb2280:packages/pypi/agent-toolkit-cli/src/agent_toolkit/cli/insights.py`
- Plan refs: `python-v-parity-audit-mega-plan.md:§3.7 Build`, `§4.5 P3-02`
