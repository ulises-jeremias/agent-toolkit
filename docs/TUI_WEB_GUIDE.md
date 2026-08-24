# TUI & Web Dashboard Guide

Interactive surfaces for `agent-toolkit` — terminal TUI and browser Web UI served by `serve`.

## TUI (`agent-toolkit tui`)

Real interactive terminal dashboard (ANSI colors, keyboard navigation) — in-process core calls, offline-first per ADR-494, no HTTP.

### Screens

| Key | Screen | Content |
|-----|--------|---------|
| `1` | Dashboard | Header `agent-toolkit TUI — <version>`, workspace path, loops preview (tier colors L1 green, L2 yellow, L3 red — Stages, not Layers) |
| `2` | Loops | Browser with tier colors, reverse-video selection, detail pane (status, runs, goal preview), `r` run |
| `3` | Skills | Inventory grouped by domain (live via `agent-toolkit inventory`), `lookup_checkout_root()` + `load_inventory_at()` |
| `4` | Doctor | Health checks `✓ ok` / `! warn` / `✗ err` with colored status, version/platform |
| `h` | Help | Keyboard reference + workspace auto-detection note |

### Keys

- `1`/`2`/`3`/`4` switch screens, `j`/`down` / `k`/`up` navigate list (loops screen only), `r`/`enter` run selected loop (`no_llm` safe), `h`/`?` help, `q`/`quit`/`exit` quit
- Workspace auto-detected via walk-up: `loops/` / `AGENTS.md` / `.git` / `knowledge` or `AGENT_TOOLKIT_WORKSPACE` / `HARNESS_DIR` env
- Batch mode: `printf "2\nj\nr\nq\n" | agent-toolkit tui` (non-interactive pipe)

### Examples

```bash
agent-toolkit tui
agent-toolkit tui --help
printf "2\nj\nq\n" | agent-toolkit tui
```

Implementation: `modules/agent_toolkit_tui/app.v` (ansi, truncate, pad_right, resolve_workspace, list_loops), `render.v` (4 screens), `main.v` (REPL `clear_screen` + `handle_input`), `v vet` 0 errors, pure V stdlib (no bobatea/term.ui).

## Web Dashboard (`agent-toolkit serve`)

Self-contained SPA served at `/` via `vlib/veb` — embedded at compile time with `$embed_file` (no FS dependency), works from any directory.

### Pages (sidebar nav, hash routing, 15s auto-refresh)

- **Overview**: health badge (`/api/v1/health` `version/commit/uptime_s`), stats grid `Skills/Agents/Products/Domains` (`/inventory`), quick actions
- **Loops**: table tier badges L1/L2/L3 (mutation-safety **Stages**, not Layers) color-coded, `parseLoops()` strips `tier=`/`cadence=` prefixes, safeTier whitelist, Run button → `selectLoopAndRun()`
- **Skills**: searchable `skills-filter` input, domain regex `  domain/ (n)` + `✓ skill`, `skillsRows` cache, `filterSkills()` live, empty state
- **Doctor**: `pre#doctor-out` from `/doctor` (`ok` ? `var(--text)` : `var(--warn)`)
- **Run Job**: `select#loop-select` populated from `parseLoops()`, `Start` POST `/api/v1/jobs` `{cmd:"loop",args:["loop","run",name,"--no-llm"]}`, handle `max concurrent (2)` toast, `loadJobs()` sorted `started_at` table `ID Cmd Status Started Log`, `viewLog()` `GET /jobs/:id/log` with `content-type` check, `log-pane` monospace `max-height 350px`, `toast` system, `AbortController` dedup

### Security

`serve` binds `127.0.0.1:3847` by default (localhost-only), remote requires `--allow-remote` + `bearer` token (`AGENT_TOOLKIT_TOKEN`), `deny_if_remote()` gate on all routes, per ADR-028.

### Examples

```bash
agent-toolkit serve --port 3847 --no-browser
curl http://127.0.0.1:3847/api/v1/health | jq
curl http://127.0.0.1:3847/api/v1/loops | jq
curl http://127.0.0.1:3847/api/v1/inventory | jq
# Web: open http://localhost:3847 → Overview/Loops/Skills/Doctor/Run
```

Implementation: `web/index.html` (330 lines, vanilla JS, dark theme `--bg/--card/--accent`), `modules/agent_toolkit_server/server.veb.v` (`web_index_html.to_string()`, `openapi_json.to_string()`, `jobs_create/list/log`).

## CLI Reference

Both surfaces are registered in `modules/agent_toolkit_cli/commands.v` (`tui_command()`, `serve_command()`) and `dispatch.v` (`execute_command` + `subcommand_help`), group `Advanced commands` per `docs/CLI_SURFACES.md`.

See also: `docs/compatibility/cli-contract.yaml` (23 commands + help SSOT), `docs/surface/openapi.json` (generated via `scripts/generate_surface.py` — do not hand-edit), `modules/agent_toolkit_server/tui_registry.v`, `CHANGELOG.md` `1.22.0`/`1.22.1`.
