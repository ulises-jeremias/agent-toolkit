# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

<!-- markdownlint-disable MD024 -->
## [1.29.3] — 2026-09-02

- **Feat (desktop)** — Paper Co. design pass on the native GUI: every panel on the warm paper ledger (cream/manila/kraft cards, brass rails, Fraunces letterheads) with the ink filing-cabinet chrome; unified paper letterhead `paper_letterhead` for all 13 panels
- **Feat (desktop)** — Brand typography shipped in-binary-adjacent: Fraunces Display (letterheads), IBM Plex Sans (+SemiBold), IBM Plex Mono (real mono slot via `IBMPlexSansMono` naming), IBM Plex Sans Arabic, Noto Sans SC chrome subset (34 KB) — all OFL in `assets/fonts/`, resolved next to the binary, graceful system-font fallback
- **Fix (desktop)** — Text input was dead on Linux/X11: V sokol delivers printables as separate `.char` events; `on_event` now replays them as `key_down` (per-frame dedupe for C backends). Palette, search, skills filter, memory recall and the Ghostty prompt all accept typing now
- **Fix (desktop)** — Glyph coverage: replaced symbols missing from Plex (`⌘ ⌕ ● ◐ ○ ◉ ▾ ▸ ◈ ≡ ✉ ■`) with drawn primitives (`draw_envelope`, `draw_search_lens`, `draw_floor_legend`) and safe glyphs; minimum type size raised to 10 px
- **Fix (desktop)** — Type ramp quantization (`type_ramp`): zoom snaps to 12 canonical sizes so the fixed fontstash atlas (sfons cannot expand) cannot overflow into tofu; release builds use `-d gg_text_buff_size=4096`
- **Fix (desktop)** — `needs_sc/needs_ar` iterated UTF-8 bytes (`for ch in s` semantics in V 0.5.2) — now iterate `.runes()`; Arabic + CJK font routing works everywhere
- **Feat (desktop)** — i18n 4-lang EN/ES/中文/عربي with RTL: dock/inspector flip for Arabic (bidi-lite run reversal), translated dock, header, status bar, palette labels/descriptions and panel letterheads; language chips in the header (click or palette)
- **Feat (desktop)** — Insights grows to 7 tabs: new **Realtime** (EventBus live feed + GOD 4·t·(1−t) flow meter) and **Gallery** (living style guide: palette chips, type specimens, components); Budgets now renders recent loop history rows; tab hit-tests match the new layout
- **Feat (desktop)** — Embedded terminal UX: GHOSTTY VT header with focus pill, height modes **1× / 2× / MAX / hidden** (buttons + Ctrl+`), 16 px rows, per-desk VT preview enlarged (6 rows) in the inspector
- **Feat (desktop)** — Office floor re-layout: 15 desks on a clean grid, GOD manager corner + station wall in a kraft-divided right corridor (no more card overlaps), legend swatches, fleet minimap
- **Chore (desktop)** — VERSION-aligned header, folder tab + manila stationery signatures, `scripts/subset-sc-font.sh` tooling

## [1.26.0] — 2026-08-31


- **Feat (insights)** — Re-port `agent-toolkit insights` as native V command (pure V, all runners): opencode, cursor, claude, windsurf, copilot, codex, pi, muse, all — with `--days`, `--output`, `--json`, `--no-llm`. No Python dependency. `/api/v1/insights` server route added.
- **Feat (swarm)** — Graph-engineered swarms: feedback cycles (`reviewer⇢implementer` bounded by round-trip limit), `swarm graph --json` live topology, edge activation (autostart + wake on every handoff type)
- **Fix (loop)** — Restore `attribution` support in V (was lost in the rewrite): `attribution: false|true|{enabled,template}` in `loop.yaml`
- **Fix (swarm)** — Enforce graph delegation: `--to` flag shadowing fix, audit gate on commit handoffs, Python-parity aliases (`recipe list`, `ls`), `swarm attach` argv fix, herdr lifecycle fixes
- **CI** — Validate workflow fix (`paths`+`paths-ignore` 422), swarm-e2e backend selection, macOS mcp test skip, plugin check advisory, loop help grep fix

- **Feat (swarm)** — Full multi-agent orchestration parity with the legacy Python CLI, plus new capabilities:
  - `swarm start` flags `--request-file/--issue/--base-ref/--workspace/--json` (#883, #915); git **worktree per writer** with lazy `initial_roles` (#884, #912); `compose_role_prompt` + `GLOBAL_PROTOCOL` + per-role prompts (#885, #913)
  - **Blocking attach** (`os.execvp`-style) + `swarm attach` subcommand for tmux/herdr (#886)
  - Lifecycle: `pause`/`resume`/`stop`/`cleanup`/`promote` (#887, #914); `init`/`plan`/`activate`/`deactivate` (#905, #934)
  - Observability: `watch`/`report`/`artifacts`/`handoffs`/`logs`/`approvals` (#889, #922); `status --json` full payload (#896, #925); `list --json` + `list_all_runs` (#895, #918)
  - Atomic state store with `STATE_VERSION`, worktree dirty guard, task-contract (#891, #923); per-recipe **budget** (`900k tok / $4 / 7200s` pair/team, `1.2M / $8 / 10800s` full) with `budget_exhausted` state (#892, #924)
  - `runners` + `models` commands (#893); `recipes` detail parity (#894, #917); `config resolve_config` + `BUILTIN_RECIPES` persona/policy (#897, #926)
  - `swarm prune --older-than` (7d default) + herdr `--json` fallback (#909, #938)
  - **NEW (this release): graph-engineered swarms** — the run is a directed graph, not a pipeline: nodes are roles, edges derive from consumes/produces (multi-successor fan-out), and **feedback cycles** (`reviewer⇢implementer`, bounded by the blocking round-trip limit) re-loop work for iteration. New `swarm graph <run-id> [--json]` renders the live topology: node status (running/waiting/unspawned), edges, and in-flight handoffs
  - **NEW (this release): role-chain auto-start** — when a work handoff (`artifact`/`commit`) reaches a waiting role, its runner launches automatically in its existing pane/window (swarm-forge `handoffd` behavior without the daemon): implementer → reviewer → integrator chain runs end-to-end; the "Will auto-start <role>" UX promise is now true
  - **NEW (this release): real tmux UI spawn** — `swarm start --backend tmux` now creates the dedicated socket (`agent-toolkit-swarm-<id>`), the session, and one window per role, launching the same runner surface as the herdr backend (previously it only attempted an attach to a session that was never created)
  - **NEW (this release): visual test harness** — `scripts/swarm-visual/` (tmux `pipe-pane` continuous log → ANSI→PNG renderer + timeline GIF, per-role process probes, herdr `pane read` snapshots); runbook in `docs/v/swarm-visual-testing.md`
  - **Fix**: `swarm attach` — V's `os.execvp` prepends `prog` to argv itself, so the duplicated argv[0] made tmux/herdr fail with `unknown command: tmux`; herdr attach now resolves the workspace id by label and runs `workspace focus` (`workspace open` does not exist in herdr 0.8)
  - **NEW (this release): handoff audit gate** — first `commit` handoff per (run, from, to, commit) returns `AUDIT_REQUIRED`; an identical re-run passes and queues; any payload change re-challenges (swarm-forge discipline, filesystem SoT)
  - **NEW (this release): `swarm recipe list`, `swarm ls` alias** (Python parity) and **fix**: `handoff create --to ROLE` was shadowed by the `promote --to` parser rule and silently ignored
- **Feat (V parity sprint)** — close the Python→V capability gap: `loop gh_gate` + budget enforcement + pack parity (#898, #927); `install` compiler targets pi/windsurf + tool_mapping (#899, #928); `doctor` provenance/pack/MCP/matrix + swarm herdr/tmux checks (#900, #929); `workspace` 11-subcommand parity (#901, #930); `project init` + `OWNER/REPO` shorthand + `--workspace/-C` (#902, #931); `devcompanion queue --template/--request/--id` + `run-once --no-llm` + `llm-status` (#903, #932); `mcp` registry + offline + health/doctor parity (#904, #933); serve/tui not masked in contract (#908, #937)
- **Feat** — Vendor 31 JIRA + Confluence skills as first-class upstream capabilities: 14 `integrations/jira-*` (grandcamel/JIRA-Assistant-Skills @ `b583731`) and 17 `integrations/confluence-*` (grandcamel/Confluence-Assistant-Skills @ `403eac8`). Bodies byte-identical to upstream; Toolkit frontmatter overlay + provenance lock + `trust.reviewed_provenance` binding. `jira-assistant` / `confluence-assistant` are the router hubs. Require `jira-as` / `confluence-as` CLIs (provisioned by workstation, not toolkit)
- **Feat** — Skill capability registry grows 85 → 116; all 31 owned by `platform-engineer`, wired into `skills/core/assistant/references/ORCHESTRATION.md`
- **Chore** — Docs counts switched from exact ("85 skills") to floor ("116+ skills") with a new `tests/test_docs_count_floor.py` guard (floor never overstates catalog; precise SoT remains `agent-toolkit inventory`)
- **Feat (taxonomy)** — Target capability registry (#862), skill capability map (#863), specialist taxonomy decision (#865), agent relationship graph (#866), portable Agent Plugin compiler (#867), adapter tiers (#868), nine-harness adapters (#869), swarm role alignment (#870)
- **Feat (build)** — `insights claude --days` + context_budget clip 2000 parity in `bin/tool-insights` (#906, #935 — insights left the CLI per #526)
- **Docs** — `docs/v` parity post-`9163c93`: `cutover.md` + `rollback.md` promoted from `archive/`, `pypi-launcher.md` + `python-fallback.md` synchronized to the hatch trampoline (#907, #936); single `docs/adrs/` tree (34 records); `distributions/` vs `distribution/` disambiguation README; README/CONCEPTS/CONTRIBUTING made declarative (floors over counts, no stale links); `docs/surface/openapi.json` regenerated for 1.25.0; `docs/compatibility/cli-contract.yaml` synced to the shipped V surface (flags, subcommands, 21 entries)
- **CI** — `swarm-e2e` gate added to `Required CI`, macOS matrix for `check-v-modules` + parity, path filtering for docs-only PRs (#941); Jira operations skill checks repaired; yamllint alignment with generated data; shipped profiles/plugins refreshed to 116+ floors and retired-`insights` references removed

## [1.24.0] — 2026-08-25

- **Feat** — New skill `architecture/architecture-diagram`: create polished dark-themed architecture diagrams as self-contained HTML+SVG files (semantic color palette, spacing/legend layout rules, PNG/PDF export toolbar). Ships `resources/template.html` as the customization starting point. Registered in `agent-toolkit-complete` and the architecture domain (85 skills total)

## [1.23.1] — 2026-08-25

- **Feat** — `GET /api/v1/jobs/:id/events`: SSE streaming of job lifecycle (`status`/`log`/`done`) — resolves the async-execution story ([#859](https://github.com/ulises-jeremias/agent-toolkit/issues/859))
- **Feat** — Deep selfcheck: `route_manifest_match` runtime diff of registered routes vs embedded OpenAPI ([#859](https://github.com/ulises-jeremias/agent-toolkit/issues/859))
- **Feat** — OpenAPI now documents server-native endpoints (health/openapi/selfcheck/jobs+events/doctor-fix/loops conveniences/swarms)
- **Fix** — `POST /api/v1/jobs`: inject `--workspace` only for workspace-aware commands (`loop`); other commands run with the resolved workspace as working directory
- **Tests** — Parity gates extended: `registered_api_routes` const ↔ route attributes ↔ OpenAPI exact match

## [1.23.0] — 2026-08-25

> **Breaking:** the interactive TUI is no longer a supported product surface.
> `agent-toolkit tui` now prints a removal notice (exit 1). Capabilities remain
> fully available via the CLI and via the programmatic API (`agent-toolkit serve`).
> Rationale and migration: [ADR-030](docs/adrs/ADR-030-capability-contract-binary-first.md).

- **BREAKING** — Retire TUI: remove `modules/agent_toolkit_tui`, generated `tui_registry.v`, docs; CLI keeps an actionable removal stub ([#837] superseded by ADR-030)
- **BREAKING** — Retire Web application: replace the dashboard SPA with a minimal static server status page; remove `web_nav.json` generation ([#838] superseded by ADR-030)
- **Arch** — ADR-030 supersedes ADR-029: contract semantics move from presentation parity to capability description; parity gates now enforce contract ↔ OpenAPI ↔ registered server routes only
- **Feat** — `GET /api/v1/selfcheck`: runtime coherence checks (embedded OpenAPI freshness vs running binary, jobs dir writability, bind policy)
- **Feat** — Add missing programmatic surfaces for contract capabilities: `POST /api/v1/loops/{sub}`, `/api/v1/dc/{sub}`, `/api/v1/swarms/{sub}` (thin core proxies)
- **Contract** — Drop `insights`/`release` entries (retired commands are not capabilities); add `api: false` for human-only meta capabilities (`completion`, `serve`)
- **Tests** — Rewrite `test_surface_parity.py`: capability↔OpenAPI↔routes coverage, retired-artifact guard, scope/confirm metadata; TUI registry test removed

## [1.22.3] — 2026-08-24

- **Fix** — TUI Skills: use `find_toolkit_root()` + embedded fallback (was `lookup_checkout_root` only, failed from `~/.ai-workspace` with `skills not found`)
- **Fix** — Server: jobs log not found — `watch()` now captures stdout/stderr and writes `log_path`, handles `workspace` param and `--workspace` injection, fixes arg duplication `loop loop`
- **Fix** — Server: workspace routing — `jobs_create`/`loops_*` now honor `workspace` field / `AGENT_TOOLKIT_WORKSPACE` / walk-up instead of hardcoded `os.getwd()` (fixes `other campu` without `--workspace`)

## [1.22.2] — 2026-08-24

- **Fix** — TUI: support legacy `LOOP.md`, add `--workspace` flag, fallback to bundled templates when workspace empty (fixes `tui` showing no loops in `my-ai-workspace`)
- **Fix** — TUI: `resolve_workspace` now honors `AGENT_TOOLKIT_WORKSPACE`/`HARNESS_DIR` and walk-up `loops/.git/AGENTS.md/knowledge`

## [1.22.1] — 2026-08-24

- **Fix** — Server embed: use `to_string()` not `str()` for $embed_file — web was returning `EmbedFileData{...}` debug struct instead of HTML (affects `/`, `/openapi.json`, `/help`)

## [1.22.0] — 2026-08-24

- **Feat** — Real interactive TUI: ANSI colors, 4 screens (dashboard/loops/skills/doctor), j/k navigation, reverse-video selection, loop browser with goal preview, doctor checks with ✓/!/✗ colors, help screen, in-process core calls per ADR-494
- **Feat** — Full Web dashboard SPA (330 lines): sidebar nav Overview/Loops/Skills/Doctor/Run, stats grid, loops table tier badges L1/L2/L3 color-coded, searchable skills table, doctor report, jobs list with status colors, log viewer monospace, toast system, hash navigation, 15s auto-refresh with AbortController
- **Fix** — Embed web assets at compile time via $embed_file for self-contained serve, fix web tier= stripping, esc() XSS protection, refresh() undefined, pad_right negative panic, AbortError handling
- **Chore** — Unify terminal help for tui/serve, workspace walk-up resolution

## [1.21.0] — 2026-08-24

- **Fix** — Embed web/index.html, openapi.json, cli-help.md at compile time so `serve` works from any directory ([#850](https://github.com/ulises-jeremias/agent-toolkit/pull/850), [#851](https://github.com/ulises-jeremias/agent-toolkit/pull/851))

## [1.20.0] — 2026-08-24

- **Feat** — TUI MVP: `agent-toolkit tui` dashboard with loops table (tier, cadence, status), in-process core calls, offline-first ([#837](https://github.com/ulises-jeremias/agent-toolkit/issues/837), [#848](https://github.com/ulises-jeremias/agent-toolkit/pull/848))
- **Feat** — Web UI SPA: single-page dashboard served at `/` by `serve` (health badge, inventory counts, loops table, doctor report, run loop via Jobs API) ([#838](https://github.com/ulises-jeremias/agent-toolkit/issues/838), [#849](https://github.com/ulises-jeremias/agent-toolkit/pull/849))
- **Feat** — Full CLI parity: 21/21 contract commands now have HTTP routes via `serve` (install, update, uninstall, skills, mcp, plugin, workspace, memory, project, build, swarms) ([#836](https://github.com/ulises-jeremias/agent-toolkit/issues/836), [#846](https://github.com/ulises-jeremias/agent-toolkit/pull/846), [#847](https://github.com/ulises-jeremias/agent-toolkit/pull/847))
- **Docs** — `docs/security/threat-model-serve.md` with STRIDE analysis and abuse-case checklist ([#541](https://github.com/ulises-jeremias/agent-toolkit/issues/541), [#847](https://github.com/ulises-jeremias/agent-toolkit/pull/847))

## [1.19.0] — 2026-08-23

- **Feat** — Feature-complete `serve` (unified platform, SSOT contract): codegen `generate_surface.py` emitting `openapi.json`/`cli-help.md`/`web_nav.json`/`tui_registry.v` from `cli-contract.yaml` with parity tests ([#831](https://github.com/ulises-jeremias/agent-toolkit/pull/840)), ADRs 027-029 (thin adapter, security defaults, surface-parity SSOT) ([#832](https://github.com/ulises-jeremias/agent-toolkit/pull/841)), `serve` skeleton via `veb` (`/health`, `/version`, `/openapi.json`, remote bearer gate) ([#833](https://github.com/ulises-jeremias/agent-toolkit/pull/842), [#844](https://github.com/ulises-jeremias/agent-toolkit/pull/844)), read-only APIs (`/inventory`, `/doctor`, `/matrix`, `/diff`, `/loops`) ([#834](https://github.com/ulises-jeremias/agent-toolkit/pull/843)), Jobs API with process-per-run + SSE (`POST /jobs`, `GET /jobs`, `GET /jobs/:id/log`) ([#835](https://github.com/ulises-jeremias/agent-toolkit/pull/845)), gated writes for full CLI parity (`install`, `update`, `uninstall`, `skills`, `mcp`, `plugin`, `workspace`, `memory`, `project`, `build`, `swarms`, `loops/:name/run|schedule`) ([#836](https://github.com/ulises-jeremias/agent-toolkit/pull/846), [#847](https://github.com/ulises-jeremias/agent-toolkit/pull/847))
- **Docs** — `docs/LOOPS.md` remote execution via `schedule --platform github-actions` + `examples/remote-loops`, `docs/security/threat-model-serve.md` (STRIDE, 7 threats, abuse checklist) for #541
- **Fixed** — `serve` now uses `vlib/veb` per maintainer decision (was `net.http` stub)

## [1.18.0] — 2026-08-21

- **Feat** — Complete Epic #743 (cursor/plugins adoption): vendor `tooling/cli-for-agents` ([#779](https://github.com/ulises-jeremias/agent-toolkit/pull/779)), absorb fix-ci patterns into `forge/gh-fix-ci` ([#780](https://github.com/ulises-jeremias/agent-toolkit/pull/780)), add `forge/fix-merge-conflicts` ([#781](https://github.com/ulises-jeremias/agent-toolkit/pull/781)), extend `core/workspace-knowledge-sync` with learned facts ([#792](https://github.com/ulises-jeremias/agent-toolkit/pull/792)), and add first-party `quality/deep-review` rubric ([#808](https://github.com/ulises-jeremias/agent-toolkit/pull/808))
- **Feat** — Emit `hooks/hooks.json` for Cursor from the canonical `capabilities/hooks/*.yaml` registry ([#794](https://github.com/ulises-jeremias/agent-toolkit/pull/794))
- **Feat** — Spec-complete Cursor/Claude `plugin.json` manifests (`$schema` + `author.url` per Agent Plugins 1.0.0) ([#795](https://github.com/ulises-jeremias/agent-toolkit/pull/795))
- **Feat** — New stable `agent-toolkit-craft` product (unslop + deslop + blast-radius), registered in Claude Code and Cursor marketplaces ([#796](https://github.com/ulises-jeremias/agent-toolkit/pull/796))
- **Chore** — Integration audit: inventory counts (84 skills / 17 agents / 5 products), marketplace docs (four plugins) ([#756](https://github.com/ulises-jeremias/agent-toolkit/issues/756))
- **Fixed** — Catalog/profile/docs drift audit (20 issues): sync `skills-layout.json` ghost `ui-ux-pro-max` → 84 skills ([#799](https://github.com/ulises-jeremias/agent-toolkit/issues/799), [#810](https://github.com/ulises-jeremias/agent-toolkit/pull/810)), remove `ORCHESTRATION.md` ghost ([#800](https://github.com/ulises-jeremias/agent-toolkit/issues/800), [#811](https://github.com/ulises-jeremias/agent-toolkit/pull/811)), remove 3 dangling pack loops + phantom agent ([#801](https://github.com/ulises-jeremias/agent-toolkit/issues/801), [#812](https://github.com/ulises-jeremias/agent-toolkit/pull/812)), fix `SKILLS.md` domain counts ([#802](https://github.com/ulises-jeremias/agent-toolkit/issues/802), [#813](https://github.com/ulises-jeremias/agent-toolkit/pull/813)), expand `AGENTS.md` allowlist 9→14 domains ([#803](https://github.com/ulises-jeremias/agent-toolkit/issues/803), [#814](https://github.com/ulises-jeremias/agent-toolkit/pull/814)), fix MCP dead links 7→8 ([#804](https://github.com/ulises-jeremias/agent-toolkit/issues/804), [#815](https://github.com/ulises-jeremias/agent-toolkit/pull/815)), badge drift 80→84 + ADR-026 + wiki links ([#805](https://github.com/ulises-jeremias/agent-toolkit/issues/805), [#816](https://github.com/ulises-jeremias/agent-toolkit/pull/816)), add `test_skills_layout` coverage ([#806](https://github.com/ulises-jeremias/agent-toolkit/issues/806), [#817](https://github.com/ulises-jeremias/agent-toolkit/pull/817)), Pi/Muse-code profile parity ([#807](https://github.com/ulises-jeremias/agent-toolkit/issues/807), [#818](https://github.com/ulises-jeremias/agent-toolkit/pull/818))
- **Fixed** — `CHANGELOG` missing 1.17.0 ([#782](https://github.com/ulises-jeremias/agent-toolkit/issues/782), [#819](https://github.com/ulises-jeremias/agent-toolkit/pull/819)), Cursor `README` heredoc ([#783](https://github.com/ulises-jeremias/agent-toolkit/issues/783), [#820](https://github.com/ulises-jeremias/agent-toolkit/pull/820)), duplicate `forge/workflow-*` stubs ([#791](https://github.com/ulises-jeremias/agent-toolkit/issues/791), [#821](https://github.com/ulises-jeremias/agent-toolkit/pull/821)), `complete` missing 17 agents ([#793](https://github.com/ulises-jeremias/agent-toolkit/issues/793), [#822](https://github.com/ulises-jeremias/agent-toolkit/pull/822)), profile parity `contribution-planner` + inline `settings.json` ([#784](https://github.com/ulises-jeremias/agent-toolkit/issues/784), [#785](https://github.com/ulises-jeremias/agent-toolkit/issues/785), [#823](https://github.com/ulises-jeremias/agent-toolkit/pull/823)), `PROFILES.md` Cursor per-agent ([#788](https://github.com/ulises-jeremias/agent-toolkit/issues/788), [#824](https://github.com/ulises-jeremias/agent-toolkit/pull/824)), `muse-code`/`codex`/`gemini` profiles ([#789](https://github.com/ulises-jeremias/agent-toolkit/issues/789), [#790](https://github.com/ulises-jeremias/agent-toolkit/issues/790), [#825](https://github.com/ulises-jeremias/agent-toolkit/pull/825)), Pi docs ([#787](https://github.com/ulises-jeremias/agent-toolkit/issues/787))


## [1.17.0] — 2026-08-21

- **Feat** — Embed all capability data in V binary — standalone offline-first (distribution) ([#778](https://github.com/ulises-jeremias/agent-toolkit/pull/778))

## [1.16.0] — 2026-08-19

- **Docs** — Add upstream vs first-party governance (`docs/UPSTREAM_VS_FIRST_PARTY.md`), skill integration checklist, and `ORCHESTRATION.md` routing table (Epic #743, Wave 0) ([#757](https://github.com/ulises-jeremias/agent-toolkit/pull/757))
- **Feat** — Vendor `quality/unslop`, `quality/deslop`, and `quality/blast-radius` from cursor/plugins (complete product; provenance lock) ([#759](https://github.com/ulises-jeremias/agent-toolkit/pull/759), [#746](https://github.com/ulises-jeremias/agent-toolkit/pull/746))
- **Fixed** — MCP templates use official servers only; remove all `wrapper.sh` launchers ([#765](https://github.com/ulises-jeremias/agent-toolkit/pull/765))
  - Slack → `@modelcontextprotocol/server-slack` (`SLACK_BOT_TOKEN` + `SLACK_TEAM_ID`)
  - Notion → remote OAuth `https://mcp.notion.com/mcp` + local `@notionhq/notion-mcp-server` fallback
  - GitHub → `ghcr.io/github/github-mcp-server` (Docker)
- **Docs** — Expand MCP template READMEs for Notion, Slack, and GitHub ([#742](https://github.com/ulises-jeremias/agent-toolkit/pull/742), Resolves [#339](https://github.com/ulises-jeremias/agent-toolkit/issues/339))
- **Docs** — README footer: star CTA, issue templates, contributors grid ([#764](https://github.com/ulises-jeremias/agent-toolkit/pull/764))
- **Fixed** — Include `quality/deslop` in `agent-toolkit-complete` product membership
- **Docs** — Regenerate `docs/UPSTREAM.md` after blast-radius vendor (10 capabilities)
- **Docs** — Make `static/*.svg` command-accurate: real `agent-toolkit install` / documented install paths and per-tool dests from `install.v`; drop invented `~/toolkit --mode=production`, `muse skills install`, Copilot/OpenCode agents-or-skills checkmarks, Cursor `marketplace.json` as an install dest, Pi loops, and L3 `agentic-harness`

## [1.15.0] — 2026-08-16

- **Feat** — Restore literal upstream skill bodies and weekly sync PRs ([#737](https://github.com/ulises-jeremias/agent-toolkit/pull/737))
- **Docs** — Add npm / PyPI version + downloads, AUR, Homebrew, GHCR, and GitHub Release badges to the root README and published adapter READMEs; align AUR install examples to `agent-toolkit-bin` ([#738](https://github.com/ulises-jeremias/agent-toolkit/pull/738))
- **Docs** — Refresh `static/*.svg` to current inventory (80 skills, 7 tools including Muse Code, all 10 loop names, install channels); align live docs that still said 77 skills ([#739](https://github.com/ulises-jeremias/agent-toolkit/pull/739))
- **Docs/CI** — Invoke shebang `.vsh` scripts as `./scripts/…` / `./make.vsh` (not `v run scripts/…`); Windows GHA keeps `"${VBIN}" run make.vsh` exception ([#736](https://github.com/ulises-jeremias/agent-toolkit/pull/736))
- **Fixed** — `bump-version.vsh` updates `generatorVersion` in `plugins/*/.provenance.json` (not only digests / `"version"` sidecars)
- **Breaking (contributor)** — Retire `scripts/gen-surfaces.vsh` and CI `check-surfaces` ([ADR-003](docs/adrs/ADR-003-retire-gen-surfaces.md) Remove). Sole surface gates: `agent-toolkit build --check` + `agent-toolkit plugin check` ([#734](https://github.com/ulises-jeremias/agent-toolkit/pull/734))
- **CI** — Add Required `check-v-modules` (`./make.vsh vet` / `test`; fmt-check deferred — modules not fully vfmt'ed / json2 risk); drop `coverage` and `test-uvx` from Required (`test-uvx` = published PyPI smoke on main/dispatch only); `experimental-v.yml` is `workflow_dispatch` only; unify V install via `setup-v` in validate/parity/release/experimental
- **Chore** — Remove dead `scripts/validate-skills.sh`, `scripts/install.sh`, and `scripts/doctor.sh`; docs/CI use V CLI and `*.vsh` validators ([ADR-007](docs/adrs/ADR-007-install-sh-deprecation.md) Remove phase)
- **Chore** — Add `scripts/validate-loops.vsh` (python3+jsonschema); `validate.yml` `validate-loops` job calls it
- **Chore** — Archive legacy `schemas/skill.schema.json` → `docs/archive/` (skill.json removed; see [MIGRATION.md](docs/MIGRATION.md)); `products.yaml` `version_source: VERSION`
- **Docs** — Present-tense V-first contributor docs (AGENT.md, generated catalogs, no `installer/sources.py`); move strangler-era `docs/v/*` to `docs/v/archive/`; ROADMAP post-1.14; ADR-003/004/007/012 amendments; `docs/adrs/README.md` index; Homebrew formula PR permissions note ([#735](https://github.com/ulises-jeremias/agent-toolkit/pull/735))
- **CI** — Skip Docker image smoke when GitHub Release `v$(VERSION)` does not exist yet (version-bump chicken-egg; `Release.yml` still publishes after assets)

## [1.14.1] — 2026-08-14

Patch release for post-`v1.14.0` release hygiene that landed on `main` after the tag.

- **Fixed** — `bump-version.vsh` now bumps Dockerfile `ARG VERSION`, Codex/Gemini/pi plugin sidecars, and refreshes `plugins/*/.provenance.json` digests for `plugin.json` so `plugin check` stays green after a version bump
- **Chore** — Sync leftover 1.14.0 sidecars that the previous bump missed; tighten Dockerfile `ARG VERSION` regex in the bump script

## [1.14.0] — 2026-08-14

- **Docs** — Align `docs/v/*` and ADR-012/021 amendments with launcher-only PyPI (no `agent-toolkit-py`); scrub leftover CONTRIBUTING / distribution present-tense quarantine wording
- **Refactor** — Migrate V CLI dispatch to `vlib/cli` Command tree (`Command.parse` + execute callbacks; Consumer/Advanced groups). ADR-010 shim only for unknown flags → exit **2** (vlib uses 1); unit tests keep `dispatch()` walk ([docs/v/cli-dispatcher.md](docs/v/cli-dispatcher.md), [vlib-cli-spike.md](docs/v/archive/vlib-cli-spike.md))
- **Fixed** — Re-`setup()` root Command after return-by-value before `parse` so Windows TCC parent pointers stay valid (`agent-toolkit version` Integration crash)
- **Chore** — Rewrite `make.vsh` on vlib `build` (bobatea-style short tasks + [upstream build_system example](https://github.com/vlang/v/blob/master/examples/build_system/build.vsh)); remove `Makefile`; CI/docs use `./make.vsh <target>` (shebang); `install-cli --prefix=/path` (hyphen flags skipped by `context.run`, parsed manually; `PREFIX` env fallback)
- **Tests** — Expand npm trampoline suite (`node --test`) to mirror PyPI launcher coverage; add dedicated `test-npm` CI job (Node 22/24 × ubuntu/macOS/Windows)
- **CI** — Bump primary Python to **3.14** (matrix still covers 3.10–3.14); Node jobs use **24** (markdownlint / Danger; npm tests also cover 22 LTS)

## [1.13.0] — 2026-08-14

- **Breaking** — Remove quarantined Python CLI (`agent-toolkit-py` and `src/agent_toolkit/{cli,compiler,installer,…}`). PyPI is an npm-style trampoline over the V binary; CLI tests live in V (`modules/**/*_test.v`) and CI

## [1.12.2] — 2026-08-13

Audit cleanup and V-first ops: CI gates, Docker/Release coupling, scripts→`.vsh`, docs/packaging nits.

- **Fixed** — `pack_release_assets.vsh` uses an absolute `RELEASE_OUT_DIR` so Windows zip packing after `cd` into a temp dir does not fail with I/O error
- **Fixed** — Docker reusable workflow publishes via `inputs.publish` (caller `event_name` stays `push`, so `event_name == workflow_call` never matched)
- **Fixed** — Docker metadata always applies raw `VERSION` tags (semver patterns alone miss `:x.y.z` on workflow_dispatch/branch callers)
- **Docs** — Replace remaining ai-workspace brand with agentic-harness in skills/packs (Fixes #681)
- **Tests** — Parity harness V_SEMANTIC disposition fixtures for insights/release; widen docs/v paths (Fixes #691)
- **Docs** — Teach `agent-toolkit loop` instead of obsolete `bin/loop` in skills/packs/loop.yaml (Fixes #680)
- **Tests** — Stop treating `insights` as a normal ADVANCED_COMMANDS harness entry (DEPRECATE #526)
- **CI** — Fix validate.yml yamllint empty-lines after check-build insert
- **CI** — ADR-003 dual-run: add `check-build` (`build --check`) alongside gen-surfaces (Fixes #678)
- **Products** — Include `agentic-security-reviewer` in `agent-toolkit-agents` (Fixes #689)
- **CI** — Drop stale `packaging` path from MegaLinter FILTER_REGEX_EXCLUDE
- **Chore** — Migrate repo tooling scripts from Python to V (`.vsh`); add `make.vsh` with thin Makefile forwarder; keep `provenance.py` / `validate-upstream.py` and PyPI launcher Python; host skills use CLI / Grep (repo-root `scripts/` is checkout/CI only)
- **Docs** — Clarify experimental-v.yml header (ADR-018; drop PyInstaller channel wording)
- **Packaging** — PyPI classifier Development Status Beta → Production/Stable
- **Docs** — ADR-007 / install messaging aligned V-first (thin wrappers to agent-toolkit) (Fixes #682)
- **Docs** — AUR playbook and release replay use `agent-toolkit-bin`; warn off legacy `agent-toolkit` AUR (Fixes #675)
- **Docs** — Polish published npm/PyPI package READMEs to the cozy banner/badge style of `packages/pypi/agent-toolkit-cli/README.md`; document why the PyPI `src/` launcher tree stays
- **CI** — Build/push the Docker image from `release.yml` after V assets exist (`GITHUB_TOKEN` cannot trigger `on: release`)
- **Docs** — PyPI republish guidance uses `release.yml` OIDC (not Publish manual)
- **Docs** — Fix broken `docs/SWARMS.md` link to missing `CLI_REFERENCE.md` → `CLI_SURFACES.md`
- **Packaging** — Bump Dockerfile default `ARG VERSION` to match `VERSION`
- **Docs** — Note that wiki-style `[[Page]]` links in docs/wiki are intentional for wiki-sync
- **Docs** — Mark `insights` DEPRECATE (#526) and `release` REMOVE (#527) in SCOPE.md / CLI_SURFACES.md
- **CI** — Docker push-to-main is smoke-only; registry push requires Release assets (Fixes #679)
- **Chore** — scripts/install.sh and doctor.sh are thin wrappers around the V CLI (Fixes #683)
- **CI** — Include `check-surfaces` in `required-ci` needs so surface drift cannot merge (Fixes #677)
- **Docs** — Homebrew README links in-repo ADR-023 path (keep #490 as discussion)
- **Fixed** — `distributions/products.yaml` `version_source` points at packages/pypi layout


## [1.12.1] — 2026-08-13

- **Fixed** — V CLI help matches or exceeds Python: real command blurbs, inventory/matrix usage, doctor `--provenance`, examples, and honest #526/#527 insights/release dispositions

## [1.12.0] — 2026-08-13

Inventory-honest docs and V-first install/upgrade paths. Ships Unreleased work since `v1.11.0` (completions, Docker `TARGETARCH`, PyPI launcher/`doctor` root, Python CLI quarantine as `agent-toolkit-py`).

- **Docs** — Align inventory counts (77 skills / 17 agents / 7 MCP / 7 packs), V-first install/update/uninstall, and collapse stale wiki mirrors that still described Python/`install.sh` as the product
- **Docs** — Quarantine Python CLI as named `agent-toolkit-py` fallback (ADR-021 launcher stays; #540/#470). Product path remains V.
- **Docs** — Contributor how-tos are V-first: `docs/HOW_TO_DEVELOP_V.md` (V 0.5.2, `import json`, Makefile), install matrix GitHub/brew/AUR/PyPI/npm, GitHub Release adapter no longer claims PyInstaller, `uv run agent-toolkit` removed from HOW_TO/certification docs
- **Docs** — Install/release docs match V-first channels: GitHub Release, PyPI launcher, Homebrew, AUR `agent-toolkit-bin`, npm `agent-toolkit-cli` + platform packages, Docker `debian:trixie-slim`
- **Feat** — V CLI `completion` emits bash/zsh/fish/PowerShell scripts (Closes #544)
- **Fixed** — Docker multi-arch image honors BuildKit `TARGETARCH` (no amd64 default) so linux/arm64 installs `agent-toolkit-linux-arm64`; skip exec during QEMU cross-build and smoke `version` on a native load
- **Fixed** — Install `types-PyYAML` in the PyPI adapter dev extra so incremental mypy can type `yaml` imports
- **Fixed** — PyPI launcher exports wheel `data/` as `AGENT_TOOLKIT_ROOT`; V `doctor` uses `find_toolkit_root` (wheel `bin/../data`) and `embedded_version` instead of a hardcoded 1.10.0; uvx CI checks out the repo so published wheels can resolve skills/loops
- **CI** — Republish PyPI via `workflow_dispatch` on `release.yml` (Trusted Publishing is registered for that workflow, not `publish.yml`)
- **Packaging** — Move PyPI adapter to `packages/pypi/` (npm-parallel layout; platform-tagged wheels, not fake optionalDeps packages), drop the root uv workspace, tag Linux wheels `manylinux_2_38_*` after PyPI rejected `linux_x86_64` on 1.11.0, and ship a V-first Docker image from GitHub Release binaries
- **Docs** — Agentic Workstation adapter: CLI-only bootstrap, channel preference, no `import agent_toolkit` (#469)
- **Docs** — V vs Python CLI performance baseline (startup/help/inventory/doctor) (Closes #533)
- **Docs** — Audit: no first-party Python `import agent_toolkit` consumers outside this repo (Closes #561)
- **Docs** — V development & distribution documentation index (Closes #545)

## [1.11.0] — 2026-08-13

First GitHub Release that attaches **native V binaries** (ADR-018 names, SHA256SUMS, manifest.json). `v1.10.0` has empty assets — do not retag it.

- **Docs** — Docker adapter: debian-slim + GitHub Release V binary; git/gh MUST (Closes #537)
- **Docs** — macOS Gatekeeper / Windows SmartScreen / code signing policy (Closes #543)
- **Docs** — V migration risk register with ADR status (Closes #478)
- **Docs** — Python architecture map & subsystem classification for V waves (Closes #477)
- **Docs** — CLI surfaces inventory maps every command to owner issue and disposition (Closes #475)
- **Feat** — npm `agent-toolkit-cli` launcher over GitHub Release V binaries with OIDC trusted publish (Closes #536)
- **Docs** — ADR-025 npm package is `agent-toolkit-cli` with optionalDependencies platform binaries (Closes #487)
- **Docs** — AUR adapter contract: `agent-toolkit-bin` consumes GitHub Release V binaries (Closes #539)
- **Docs** — Homebrew adapter contract: Formula consumes GitHub Release V binaries (Closes #538)
- **Docs** — ADR-024 AUR `agent-toolkit-bin` installs GitHub Release V binaries (Closes #491)
- **Feat** — GitHub Releases attach native V binaries, SHA256SUMS, and `manifest.json` (Closes #530)
- **Docs** — ADR-023 Homebrew Formula installs GitHub Release V binaries (Closes #490)
- **Docs** — Distribution wrapper threat model (wheel-bundle vs runtime download) (Closes #563)
- **Docs** — ADR-022 machine-readable GitHub Release `manifest.json` (Closes #488)
- **Feat** — PyPI `agent-toolkit` is a thin launcher over the bundled V binary (Closes #535)
- **Docs** — ADR-021 PyPI ships platform wheels with bundled V binary + thin launcher (Closes #486)
- **Docs** — Add `distribution/` adapter contracts (GitHub Release canonical; no Formula/PKGBUILD copies) (Closes #534)
- **Docs** — CI cost tiers (PR/main/release) with path filters, timeouts, Python-lane retirement trigger (Closes #532)
- **Feat** — V `swarm` REDESIGN (recipes/start/status/doctor/approve/reject/cancel; filesystem SoT) (Closes #524)
- **Feat** — V `loop` REDESIGN (init/run/status/audit/cost/schedule/sync; process-per-run skeleton) (Closes #523)
- **Feat** — Execute MUST-platform V artifacts (`--version`/`--help`/`inventory`/`doctor`) with arch mismatch fail (Closes #531)
- **Feat** — Native V MUST build matrix (linux x86_64/arm64, macos arm64/x86_64, windows x86_64; experimental names) (Closes #529)
- **Feat** — Experimental native V CI artifacts (linux-x86_64, macos-arm64, windows-x86_64; experimental names only) (Closes #562)
- **Docs** — ADR-020 V concurrency: process-per-run supervisor (no Python threads / no `go` workers) (Closes #528)
- **Feat** — V `devcompanion`/`dc` filesystem queue (queue/run-once --no-llm/status/done/sync-todos) (Closes #525)
- **Docs** — ADR-019 Linux glibc is the MUST/stable binary; musl is an optional extra name (Closes #485)
- **Feat** — V `project` init/clone/list/add/remove/scan (repos/ + projects/ symlinks) (Closes #522)
- **Feat** — V `memory` add/search/inject/review/todo (knowledge markdown; atomic writes) (Closes #521)
- **Docs** — ADR-018 canonical release artifact names (floating stable + versioned archives; experimental prefix) (Closes #484)
- **Feat** — V `workspace` command family (init/context/sync + personas/packs) (Closes #520)
- **Fixed** — V install JSON merge (`ownership=merged`) writes without `--force` (Closes #611)
- **Feat** — V binary is the in-repo canonical `agent-toolkit` (consumer CLI; Python package fallback for unfinished advanced commands) (Closes #555)
- **Docs** — EPIC 5 advanced-command disposition (PORT/REDESIGN/DEPRECATE/REMOVE) (Closes #560)
- **Docs** — ADR-017 package-manager ownership: `update` is capability-only; never overwrite brew/AUR/npm/uv binaries (Closes #489)
- **Feat** — V `agent-toolkit install` via InstallTransaction (dry-run/force/receipts) (Closes #607)
- **Feat** — V `plugin sync|check` gen-surfaces parity (Closes #519)
- **Feat** — V `mcp` list/setup/health/doctor/uninstall (env names only; no secrets) (Closes #518)
- **Feat** — V `skills` list/sync/validate command family (Closes #517)
- **Feat** — V `doctor --fix` allowlisted profile refresh (Closes #550)
- **Feat** — V capability `update` (profile refresh; --check/--pin; not self-update) (Closes #516)
- **Feat** — V `agent-toolkit diff` (compile vs plugins/ added/changed) (Closes #515)
- **Feat** — install receipt compatibility schema (`schemas/install-receipt.schema.json`) (Closes #511)
- **Feat** — V uninstall/rollback from install receipts (created-only; dry-run) (Closes #514)
- **Feat** — V atomic install transaction (stage/commit/rollback + receipt save) (Closes #513)
- **Feat** — V read-only install receipt parser (SCHEMA + path-escape/secrets refuse) (Closes #512)
- **Feat** — V remaining target emitters (copilot, windsurf, pi, gemini, muse, codex, agent-plugins) (Closes #552)
- **Feat** — V `build --check` Tier-1 dry-run + plugins/ skill/agent drift detection (Closes #510)
- **Feat** — V Tier-1 target emitters (cursor, claude-code, opencode) with provenance (Closes #509)
- **Feat** — V provenance emission compatible with Python `.provenance.json` schema (Closes #508)
- **Feat** — V capability loader + product selection from `distributions/products.yaml` (Closes #507)
- **Docs** — ADR-016 versioning during Python→V migration: major at cutover, not experimental binary (Closes #495)
- **Feat** — V content sync/download client (GitHub release data; offline never networks; staging validation) (Closes #557)
- **Feat** — V content cache service (XDG hit/miss/offline; no network) (Closes #556)
- **Feat** — V `doctor` read-only + `--json` with engine/version/platform (Closes #505)
- **Feat** — V `inventory` lists skills/agents/products from the toolkit tree (Closes #503)
- **Feat** — V `matrix` prints the platform capability matrix (Closes #504)
- **Feat** — V `version` / `--version` resolves from VERSION file (fallback synced via bump-version) (Closes #502)
- **Feat** — V toolkit root resolution per ADR-015 (env override → XDG → embedded → checkout → CWD; offline never downloads) (Closes #506)
- **Test** — Python↔V golden CLI parity harness + CI seed job (Closes #548)
- **Feat** — experimental V CLI dispatcher + `make build-cli` (`build/agent-toolkit-v`) (Closes #553)
- **Feat** — V structured CommandResult + CLI human/JSON/quiet renderers (Closes #501)
- **Feat** — V shared HTTP/network client (offline short-circuit, TLS, checksum hook) (Closes #558)
- **Feat** — V process service (no-shell spawn, cwd/env/timeout/capture) (Closes #500)
- **Feat** — V filesystem service (XDG paths, join, atomic write) (Closes #499)
- **Feat** — V domain error model + CLI exit-code mapping (ADR-010 classes) (Closes #498)
- **Docs** — vlib/cli spike matrix vs CLI contract; GO with thin exit/completion wrapper (Closes #554)
- **Chore** — Makefile `fmt`/`fmt-check`/`vet`/`test`/`build` for V modules (Closes #497)
- **Chore** — pin V compiler via `.v-version` (0.5.2) + upgrade policy (Closes #496)
- **Docs** — configuration/env precedence contract (`flags > env > config > defaults`) + `AGENT_TOOLKIT_*` inventory (Closes #559)
- **Docs** — machine-readable CLI contract manifest (`docs/compatibility/cli-contract.yaml`) (Closes #549)
- **Docs** — Python↔V golden CLI parity harness design (taxonomy EXACT/NORMALIZED/SCHEMA/SEMANTIC/BEHAVIORAL; no harness code) (Closes #476)
- **Docs** — ADR-015 runtime resolution (amends ADR-005 for V binary hybrid packaging) (Closes #547)
- **Docs** — ADR-014 schema validation: typed validators in core + Python bridge only during parity (Closes #546)
- **Docs** — ADR-013 YAML strategy: use `vlib/yaml` for toolkit config; no custom general YAML parser (Closes #483)
- **Docs** — ADR-012 Python/V coexistence via experimental V binary; Python remains canonical until cutover (Closes #482)
- **Fixed** — `agent-toolkit update` honors `AGENT_TOOLKIT_OFFLINE` and maps download `OSError` to skippable errors (CI flake)
- **Docs** — ADR-011 hybrid capability packaging (embedded baseline + external override); resolution order remains ADR-005/#547 (Closes #481)
- **Docs** — ADR-010 CLI/core boundary: structured domain results; CLI renders human/JSON; exit-code classes (Closes #480)
- **Docs** — ADR-009 V module architecture: `agent_toolkit_core` + `agent_toolkit_cli` (no premature server/TUI stubs) (Closes #479)

## [1.10.0] — 2026-08-12

### Added
- **Providers** — capability provider abstraction WHAT vs HOW (Closes #386), audit 8 candidates + 5 ADOPT via hierarchy (Refs #393), curated agentic-security/code-quality/architecture/design-engineering packs (Closes #390)
- **Design** — Vercel web-design-guidelines + Microsoft frontend-design-review dual-source pinning (Closes #372, #391), design-assessment orchestration (Closes #373), browser-grounded design-improvement iteration (Closes #374), Chrome DevTools MCP provider (Closes #375)
- **A11y & Figma** — WCAG 2.2 AA accessibility review (Closes #377), Figma ecosystem audit (Closes #376)
- **Security** — MCP config + implementation audit (Closes #379), OWASP agentic review (Closes #380), STRIDE threat-modeling + agentic threats (Closes #381)
- **Quality** — MegaLinter coding-agent orchestration v10 (Closes #382), CodeQL operational workflow (Closes #383), cloud Well-Architected + Mermaid/C4 diagrams (Closes #384, #385)
- **Governance** — upstream provenance schema/trust tiers + validate-upstream (Closes #364), external provenance lock + integrity validation (Closes #370), supply-chain audit skill (Closes #378), update discovery for provenance lock (Closes #428), ADRs 0004/0005
- **CLI** — `doctor` provenance/pack/MCP + matrix + context-cost + audit surface (Closes #387, #388, Refs #395, Closes #397), skill-catalog 73→77 + pack validation (Closes #390, #451, #450)

### Fixed
- **CI green** — MegaLinter PYTHON_RUFF + v10.0.0 alignment + `providers.yaml` empty-line fix (Closes #453, #454), Required CI aggregate gate, branch protection `Required CI` (app_id 15368) enforcement
- **Swarm** — tear down tmux server on cleanup to stop orphan-socket leak
- **Workspace/Packs** — validate nested packs, warn on unknown profile keys, regenerate catalogs

### Changed
- **Docs** — addyosmani documentation-and-adrs vs adr/docs-generator diff (Closes #394), third-party UI UX Pro Max as optional external (REJECT vendoring) per #392

## [1.9.0] — 2026-08-10

### Added
- **Agent Plugins 1.0** portable plugin standard — every plugin in `plugins/` now ships as `plugin.json` (`$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`) + `skills/` + `mcp.json` for Cursor, VS Code, GitHub Copilot, ChatGPT/Codex, Kiro. Dual emit keeps `.claude-plugin/plugin.json` for Claude Code (which does not yet support the spec). See `docs/AGENT_PLUGINS.md`, `plugins/README.md`, and `schemas/agent-plugins/1.0.0/`. Compiler target `agent-plugins`, validator `scripts/validate-agent-plugins.vsh`, and CI job `validate-agent-plugins` added; `scripts/bump-version.vsh` now preserves `$schema`/`extensions`.

### Changed
- **Docs** — `docs/COMPATIBILITY.md` clarifies Claude legacy-only and adds VS Code/Kiro + dedicated Agent Plugins 1.0 subsection; `docs/TARGETS.md` adds Agent Plugins 1.0 row to capability matrix.

## [1.8.4] — 2026-08-07

### Fixed
- **Swarm interactive bootstrap** — when `swarm start` is run without a prompt (`--recipe full --ui herdr --runner claude --attach`), the first agent now does only a very brief context analysis (runs `agent-toolkit workspace context` if inside a workspace like `~/.ai-workspace`, otherwise brief `README`/`git status` check) and stays on standby awaiting the user's first request. Applies `assistant` discovery + `workflow-generic-project` (plan -> approval -> implement -> draft PR) once the task arrives. Prevents the planner from inventing work.

## [1.8.3] — 2026-08-06

### Fixed
- **CI ruff format** — run `uv run ruff format` on `tests/test_swarm_cli.py` after `pytest.skip` line wrap (fixes Validate `Ruff format check` failure on 1.8.2).

## [1.8.2] — 2026-08-06

### Fixed
- **CI macos tmux** — make `test_swarm_auto_fallback_to_tmux` skip when neither herdr nor tmux is available on runner (fixes 1 failure on macos-latest).

## [1.8.1] — 2026-08-06

### Fixed
- **CI portability** — fix `tests/test_swarm_cli.py` hardcoded `/home/ulisesjcf/...` project path to `Path(__file__).resolve().parents[1]` so `uv run --project` works on any runner (fixes Validate `test_swarm_cli` 9 failures on Python 3.13).

## [1.8.0] — 2026-08-06

### Added
- **Swarm skills (Herdr-first)** — 4 new swarm-focused skills: `swarm` (launcher via `agent-toolkit swarm start --recipe pair/team/full --ui herdr/tmux --runner opencode/claude --model-profile balanced/economy --attach "task"` with eager windows `Waiting for handoff: <pred> -> <role>` and `_user_shell()` `zsh` detection), `swarm-observer` (monitor `status/handoffs/logs/attach` and recover `worktree_failed`/`headless` fallback), `swarm-handoff` (artifact/commit file handoffs with worktree-per-writer and promotion), `herdr` (Herdr workspace/tab/pane management) and `worktree` (Git worktree isolation). All validated via `muse skills validate` and `agent-toolkit skills validate` (61 total) and integrated with `code-reviewer`/`security-reviewer`/`github-cli-workflow`/`output-handshake`.
- **Workspace orchestration skills** — `workspace` (stateless `~/.ai-workspace` `workspace context` + `memory inject/todo` + packs), `project` (`project clone/list` multi-repo), `mcp` (`mcp setup/list/doctor`), and `inventory` (`inventory/matrix/skills list` discovery). Completes end-to-end DX: `workspace` → `project` → `swarm` → `handoff` → `promote` → `github-cli-workflow`.
- **Skill catalog growth** — total 52 → 61 skills across 9 domains; `agent-toolkit-complete` now includes all 9 new skills; badges, `catalogs/skill-catalog.yaml`, `catalogs/skills-layout.json`, and `docs/SKILL_PRODUCT_MATRIX.md` regenerated; `README.md`, `packages/pypi/agent-toolkit-cli/README.md`, `docs/GETTING_STARTED.md`, `docs/TROUBLESHOOTING.md`, `docs/wiki/Home.md` updated.

### Fixed
- **Docs 100% current** — regenerated catalogs (`scripts/generate-catalogs.vsh`, `prepare-package-data.sh`, `generate-skill-matrix.py`), fixed stale `skills-52` badges and `50 skills` assertions, and ensured `agent-toolkit install` deploys 61 skills to `~/.config/muse/skills` and `~/.agents/skills`.

## [1.7.2] — 2026-08-06

### Fixed
- **Swarm workspace UX polish** — fix `swarm list` duplicate entries when aggregating from `~/.ai-workspace`, make `swarm status/stop/cleanup/attach/report/artifacts/handoffs/logs` workspace-aware via `find_run_dir_by_id` (works from `~/.ai-workspace` without `--workspace` and with `--workspace OWNER/REPO`/`-C`), and ensure prompt autodetect works for all Create-Node-App aliases. Ensures `agent-toolkit swarm start "Fix https://github.com/Create-Node-App/..."` from workspace root creates worktree in correct repo with isolated tmux `-L agent-toolkit-swarm-<id>` N-windows like `swarm-forge` `./swarm`.

## [1.7.1] — 2026-08-06

### Added
- **Swarm prompt autodetect + workspace UX** — `agent-toolkit swarm start/plan` now autodetects repo from prompt (`https://github.com/OWNER/REPO`, `OWNER/REPO#123`, aliases `create-node-app`/`cna-templates` → `Create-Node-App/...`) and resolves to `~/.ai-workspace/repos/github.com/OWNER/REPO`, so `agent-toolkit swarm start "Fix https://github.com/Create-Node-App/create-node-app/issues/240"` works from `~/.ai-workspace` without `--workspace`/`--issue` flags (like `swarm-forge` `./swarm` but better: backend-neutral Herdr/tmux, isolated worktrees, handoffs). Adds `--workspace`/`--repo`/`-C` to `plan`/`start` and workspace-aware `list`/`status` (`list_all_runs`/`find_run_dir_by_id` aggregating across clones). Inspired by swarm-forge patterns (window-per-role tmux, worktrees, handoffs) clean-room.

## [1.7.0] — 2026-08-06

### Added
- **Swarm orchestration** — new `agent-toolkit swarm` CLI (ADR-008) with backend-neutral orchestration (Herdr recommended, tmux fallback), recipes `pair`/`team`/`full` (lazy/elastic, `pair→team→full` promotion), Git worktree isolation per writer, durable filesystem handoffs (artifact/commit/feedback/decision_request), commit-based code transfer, human approval gates, budgets (tokens/cost/wall-clock/concurrency/round-trips), model profiles (`economy`/`balanced`/`quality`/`private`), runner abstraction (OpenCode primary, Muse/Claude/Codex/Cursor/Copilot), OpenCode per-role agent generation, Herdr backend (JSON CLI) + tmux backend (isolated socket `agent-toolkit-swarm-<run-id>`), Herdr plugin (`integrations/herdr/agent-toolkit-swarm`), and docs (`docs/SWARMS.md`, `SWARM_ARCHITECTURE.md`, `SWARM_RECIPES.md`, `SWARM_HANDOFFS.md`, `SWARM_MODELS_AND_COSTS.md`, `SWARM_HERDR.md`, `SWARM_TMUX.md`, `SWARM_SECURITY.md`, `HOW_TO_CREATE_SWARM_RECIPE.md`) with Mermaid diagrams and offline `--runner skeleton` demo. Complete cross-repo integration: Workstation provision (tmux/Herdr) and Harness reference workspace.

## [1.6.0] — 2026-08-06

### Added

- **Loop `list` command** — `agent-toolkit loop list` (alias `ls`) lists detected loops in the same places `loop run <name>` searches (`workspace/loops/` → bundled `data/loops/`), showing `source`, `tier`, `cadence`.

## [1.5.1] — 2026-08-06

### Fixed

- **Release 1.5.0 plugin bundles**: sync `plugins/*/.claude-plugin|*.cursor-plugin|*.codex-plugin|gemini-extension|pi-package|.provenance` versions to `1.5.1` — fixes `test_diff_no_changes_returns_0` (Validate `diff`).

## [1.5.0] — 2026-08-06

### Added

- **Muse Code support (Meta, <https://developer.meta.com/ai/products/muse-code/>)** — new `muse-code` build target (`muse` alias) via `MuseCodeAdapter` (`packages/pypi/agent-toolkit-cli/src/agent_toolkit/compiler/targets/muse_code.py`) registered in `capabilities/targets/registry.yaml` (stable). `agent-toolkit build --target muse-code` and `install --tools muse-code` now deploy 50 skills to `~/.config/muse/skills/<name>/SKILL.md` plus `.agents/skills` (universal fallback) per Agent Skills spec (`muse skills import --from claude`). New profile `profiles/muse-code/README.md` and docs `README.md`.

## [1.0.1] — 2026-08-04

### Fixed

- Publish agent-toolkit-cli to PyPI (release.yml was missing build + publish steps in v1.0.0)
- SVG animations: replace CSS @keyframes with native SVG <animate> (GitHub strips CSS)
- Banner SVG: fix text overlap between title and right panel (shift from x=575 to x=530)
- CLI wheel install: shared _paths.py resolves toolkit root correctly in all install modes
- CI: remove pytest || true so test failures block the pipeline

## [1.0.2] — 2026-08-04

### Fixed

- release.yml now correctly builds wheel and publishes to PyPI

## [1.0.3] — 2026-08-04

### Fixed

- release.yml YAML syntax fixed for GitHub Actions validator

## [1.0.4] — 2026-08-04

### Fixed

- **Wheel install**: data files (profiles/, loops/, skills/, etc.) now packed inside
  the wheel at `agent_toolkit/data/` — works correctly with pip, uvx, and brew
- `_paths.py`: resolve data from `importlib.resources` and direct package path
  before falling back to walking up the filesystem (which breaks in uvx cache)
- Added `agent-toolkit-cli` as script alias so `uvx agent-toolkit-cli` works

## [1.0.5] — 2026-08-04

### Fixed

- loop runner: resolve toolkit root from package data dir before CWD fallback,
  preventing it from picking up the user's ai-workspace loops when run via uvx/pip

## [1.0.6] — 2026-08-04

### Fixed

- **CRITICAL**: Local `toolkit_root()` in cli/install.py, doctor.py, mcp.py, skills.py,
  plugin.py was defined *after* the import from `_paths.py`, shadowing it — so the
  correct resolution logic was never called in wheel/uvx installs
- Removed module-level `TOOLKIT_DIR: Path = toolkit_root()` (evaluated at import time,
  crashed before any function ran) — replaced with lazy `toolkit_root()` per call site

## [1.0.7] — 2026-08-04

### Fixed

- `skills list`: now correctly parses YAML block scalars (>-, |-) in SKILL.md descriptions
  — all 52 skill descriptions now display properly instead of showing ">-"
- `install` command: Copilot prompt no longer blocks in non-interactive/dry-run mode
  (stdin.isatty() check; skips automatically in CI, pipes, --dry-run)
- `pyproject.toml`: added agent-toolkit-cli script alias so `uvx agent-toolkit-cli` works

## [1.0.8] — 2026-08-04

### Fixed

- Copilot never auto-installed during `install` auto-detect — always requires `--tools copilot` (it needs a project path)
- CI integration tests: use relative file paths instead of /tmp (cross-platform)
- CI integration tests: fix Windows runner compatibility

## [1.0.9] — 2026-08-04

### Fixed

- Windows compatibility: `os.getuid()` doesn't exist on Windows — wrapped in try/except
  so `agent-toolkit doctor` no longer crashes on Windows runners

## [1.0.10] — 2026-08-04

### Fixed

- `loop run` now works from pip/uvx installs — `loop-gh-gate` (the gh CLI
  security shim) is now included in the wheel at `agent_toolkit/loop/loop-gh-gate`
- Windows compatibility: `os.getuid()` wrapped in try/except AttributeError

### Added

- uv workspace structure: `packages/pypi/agent-toolkit-cli/` — ready for future packages
  (`agent-toolkit-server`, `agent-toolkit-mcp`, etc.)
- Root `pyproject.toml` with `[tool.uv.workspace]` and shared dev tooling

## [1.1.0] — 2026-08-04

### Added — Full workspace capability

agent-toolkit is now a complete workspace toolkit. Every capability from
~/.ai-workspace and agentic-harness is available as a CLI subcommand:

**`agent-toolkit workspace`** — Workspace scaffolding and session context
- `workspace init [--dir PATH]` — scaffold harness workspace (AGENTS.md, knowledge/, packs/, personas/, loops/, projects/, repos/)
- `workspace context` — session state snapshot for AI session start
- `workspace sync` — sync loop escalations into knowledge todos

**`agent-toolkit memory`** — Persistent knowledge base (replaces bin/assistant-memory)
- `memory add --type <learning|process|todo> "content"` — add to knowledge base
- `memory search "query"` — search all knowledge files
- `memory inject` — output full knowledge context block for AI session
- `memory review` — show stale entries
- `memory todo` — list pending todos

**`agent-toolkit project`** — Project clone and symlink manager (replaces bin/project-indexer)
- `project clone owner/repo` — clone + symlink into projects/
- `project list` — list indexed projects
- `project add <path>` — symlink existing repo
- `project remove <name>` — remove symlink
- `project scan` — consistency check

**`agent-toolkit devcompanion`** — Background job queue (replaces bin/devcompanion)
- `devcompanion queue <project> [--request "..."] [--template NAME]` — queue a job
- `devcompanion run-once [--no-llm]` — execute oldest pending job
- `devcompanion status` — show all jobs
- `devcompanion done <job-id>` — mark job complete
- `devcompanion sync-todos` — sync plan.md todos to knowledge

**`agent-toolkit insights`** — AI tool usage analytics (replaces bin/tool-insights)
- `insights opencode` — OpenCode sessions from SQLite DB
- `insights cursor` — Cursor agent transcripts
- `insights claude` — Claude Code sessions
- `insights all` — aggregate across all tools

**Templates** — workspace scaffold templates bundled in the wheel
- 12 CLI modules, 42 template files (AGENTS.md, personas, knowledge, etc.)
- `agent-toolkit workspace init` = what agentic-harness now scaffolds from

**Profile updates** — Claude Code, Cursor, OpenCode, Windsurf profiles updated with
agent-toolkit CLI reference and session-start protocol

### Changed

- agentic-harness: bin/workspace-context and bin/assistant-memory are now
  thin wrappers that delegate to agent-toolkit CLI

## [1.2.0] — 2026-08-05

### Added — Native multi-runtime compiler platform (Phases 3-7)

The canonical compiler pipeline now generates native artifacts for 9 AI coding targets:

**Compiler targets:**
- Claude Code (plugin — .claude-plugin/) — stable GA
- Cursor IDE/CLI (plugin — .cursor-plugin/) — stable GA
- GitHub Copilot CLI (plugin — plugin.json) — stable GA
- GitHub Copilot Repository (.github/ assets) — stable GA
- Gemini CLI (extension — gemini-extension.json + commands.toml) — stable GA
- OpenCode (companion-assets — .opencode/) — stable
- Pi Coding Agent (companion-assets — pi-package.json) — stable
- Windsurf/Devin (customization-bundle — rules + AGENTS.md) — accurately labeled (no marketplace)
- OpenAI Codex (plugin — .codex-plugin/) — experimental

**Canonical compiler pipeline:**
- `distributions/products.yaml` — declarative product catalog
- `src/agent_toolkit/compiler/` — model, loader, targets/
- `agent-toolkit build` — compile to any target
- `agent-toolkit diff` — show changes vs installed
- `agent-toolkit inventory` — list all capabilities
- `agent-toolkit matrix` — platform capability matrix
- `agent-toolkit release --dry-run` — generate dist/ artifacts + checksums

**MCP and hooks:**
- `mcp/registry/` — canonical registry for 6 providers (github, slack, notion, linear, figma, clickup)
- `capabilities/hooks/` — canonical hook definitions with platform parity matrix
- `schemas/hook.schema.yaml` — JSON Schema for hook definitions

**Testing (227 tests):**
- Contract tests for all 9 compiler adapters
- Golden/snapshot tests for deterministic output
- Security tests: path traversal, secret redaction
- Installer receipt tests
- MCP registry tests
- Hook registry tests
- Provenance/diff tests

**Docs:**
- `docs/TARGETS.md` — honest capability matrix for all 9 targets
- `docs/research/` — platform capability matrix, source ledger, audit
- `docs/adrs/` — ADR-001 (canonical IR), ADR-002 (Windsurf bundle)
- `docs/security/` — threat model

### Security

- Removed `skipDangerousModePermissionPrompt` from Claude Code profile
- Replaced private LAN URLs in OpenCode profile with portable defaults
- Updated schema `$id` to remove stale agentic-workstation references

### Added — Loop runners, memory review, and consumer polish

- Loop runners: Cursor Agent CLI, GitHub Copilot CLI (`copilot -p`), OpenAI Codex (`codex exec`)
- `loop run --runner` / `AGENT_TOOLKIT_LOOP_RUNNER` for explicit runner selection
- `memory review` — duplicates, contradictions, stale/orphan detection with `--fix`
- Installer receipts, safe JSON merge, update/uninstall, profile sanitization
- README Key Concepts table; Windsurf rule parity with Cursor
- Blocking YAML lint in validate CI; docs/TARGETS and trust boundary guides

## [1.2.2] — 2026-08-05

### Changed

- Publish an elevated `packages/pypi/agent-toolkit-cli/README.md` to PyPI (parity with the monorepo root README: install, CLI surfaces, tool matrix, ecosystem)

## [1.2.1] — 2026-08-05

### Fixed

- `loop status` falls back to bundled templates when no workspace instances exist (uvx/pip installs)
- Release CI: `uv sync --package agent-toolkit-cli --extra all` and current SBOM action pins

---

[Unreleased]: https://github.com/ulises-jeremias/agent-toolkit/compare/v1.25.0...HEAD
[1.25.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.25.0
[1.24.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.24.0
[1.23.1]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.23.1
[1.23.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.23.0
[1.22.3]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.22.3
[1.22.2]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.22.2
[1.22.1]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.22.1
[1.22.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.22.0
[1.21.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.21.0
[1.20.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.20.0
[1.19.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.19.0
[1.18.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.18.0
[1.17.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.17.0
[1.16.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.16.0
[1.15.1]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.15.1
[1.15.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.15.0
[1.14.1]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.14.1
[1.14.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.14.0
[1.13.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.13.0
[1.12.2]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.12.2
[1.12.1]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.12.1
[1.12.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.12.0
[1.11.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.11.0
[1.2.2]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.2.2
[1.2.1]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.2.1
[1.2.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.2.0
[1.1.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.1.0