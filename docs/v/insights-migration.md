# Insights — `agent-toolkit insights` (re-ported in V 1.26, was DEPRECATE #526)

**Status:** **PORT** — re-ported as thin wrapper over `bin/tool-insights` (all runners). `DEPRECATE` #526 is superseded.

## Summary

Python `agent-toolkit insights opencode|cursor|claude [--days N] [--output PATH]` (up to `fbb2280`)
was externalized to `bin/tool-insights` (self-bootstraps at `~/.local/share/tool-insights-venv`, uses Anthropic API). V 1.23-1.25 kept a stub; **V 1.26 re-ports it** as `agent-toolkit insights [TOOL] [--days N] [--output PATH] [--no-llm] [--json]` — thin wrapper that validates the tool and delegates to `bin/tool-insights` (single source of truth). See `modules/agent_toolkit_core/insights.v` + `modules/agent_toolkit_cli/{commands,dispatch,options}.v`.

`context_budget` clip `2000` tokens (~8000 chars, V keeps `2000` char clip parity) formerly applied to
`memory inject` and devcompanion plan generation (`devcompanion.v:412` `plan[..2000]`), retained via
`modules/agent_toolkit_core/context_budget.v` `context_clip()` and `memory.v:memory_inject()`.

## Migration

| Before (Python V ≤ 1.12) | After (V 1.23-1.25, external) | After (V ≥ 1.26, re-ported) |
|---|---|---|
| `agent-toolkit insights opencode [--days N] [--output PATH]` | `python3 bin/tool-insights opencode [--days N] [--output PATH]` | `agent-toolkit insights opencode [--days N] [--output PATH] [--no-llm]` |
| `agent-toolkit insights cursor [--output PATH]` | `python3 bin/tool-insights cursor [--output PATH]` | `agent-toolkit insights cursor [--output PATH] [--no-llm]` |
| `agent-toolkit insights claude --days 7 [--output PATH]` | `python3 bin/tool-insights claude --days 7 [--output PATH]` | `agent-toolkit insights claude --days 7 [--output PATH] [--no-llm]` |
| `agent-toolkit insights --help` | `python3 bin/tool-insights --help`  (V stub `insights_help_text()`) | `agent-toolkit insights --help` (V native, all runners) |

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

### V CLI (re-ported 1.26, thin wrapper)

```bash
build/agent-toolkit insights --help
# prints insights_help_text() with all runners, exit 0

build/agent-toolkit insights opencode --days 7 --no-llm
# delegates to bin/tool-insights, exit 0 (raw stats, no API key needed)

build/agent-toolkit insights all --no-llm --json
# structured JSON via --json global flag
```

`--days` filters opencode/claude/windsurf; `--output PATH` saves HTML to PATH (else to `~/.claude/usage-data/`); `copilot`/`codex`/`pi`/`muse` report “no data” until collectors exist.

## `context_budget` clip 2000

`cli/context_budget.py:455` `clip(text, budget=2000)` word-truncated to 2000 tokens. V parity:

- `modules/agent_toolkit_core/context_budget.v:context_clip(text, 2000)` — `text[..2000]` char clip
- `modules/agent_toolkit_core/memory.v:memory_inject()` — clips final injection block to `2000` chars
- `modules/agent_toolkit_core/devcompanion.v:412` — `clip := if plan.len > 2000 { plan[..2000] } else { plan }`

Approximation `4 chars/token` → `2000` tokens ≈ `8000` chars; V keeps `2000` char wire parity for
plan `plan.md` rendering and `memory inject` output (see `docs/v/devcompanion.md` and `docs/v/memory.md`).

## References

- `modules/agent_toolkit_core/insights.v` `run_insights()` — thin wrapper over `bin/tool-insights` (V 1.26)
- `modules/agent_toolkit_cli/{commands,options,dispatch}.v` `insights_command()` / `parse_insights_options()` / `insights_help_text()`
- `modules/agent_toolkit_core/context_budget.v` / `memory.v:memory_inject()` / `devcompanion.v:412`
- `docs/v/advanced-command-disposition.md` `insights` PORT (re-ported 1.26)
- `docs/compatibility/cli-contract.yaml` `insights` re-added as `rewrite-v`
- Evidence: `git show fbb2280:packages/pypi/agent-toolkit-cli/src/agent_toolkit/cli/insights.py` + `bin/tool-insights`
