# Munder Difflin vs Agent Toolkit Desktop: live gap ledger

Status: **LIVE LEDGER**, baseline 2026-09-29. Update a row whenever a phase of
the desktop workstation program lands. Every row cites how it was verified.

## Baseline identity

| Product | Revision | How it ran |
| --- | --- | --- |
| Munder Difflin | `5756722e93980610e024a3f1ee7e918365ef60ec` (2026-09-29, package 0.4.6) | `npm install` (native rebuild of node-pty and better-sqlite3 succeeded on Linux) and `npm run dev` (electron-vite). Isolated `HOME`/`XDG_*`, `DO_NOT_TRACK=1`, provider API keys unset, no paid agent launched. |
| Agent Toolkit Desktop | `d4ff3731` (`main`, merge of #1312) | Dev Electron (`build:all`, then `electron apps/desktop`) and packaged `pnpm dist:dir` (`release/linux-unpacked`) with a bundled backend. Linux, Hyprland/Wayland. |
| ATK backend | `agent-toolkit` 1.35.0 | Dev runs used a locally built binary that includes the `X-Atk-Desktop` first-party gate (sha256 prefix `ebffe23c3b8d`). The released 1.35.0 on `~/.local/bin` lacks the gate (see failure rows). |

Verification legend for the last column:

- **ATK run** — exercised in the running Electron app at the baseline SHA, with a screenshot.
- **ATK src** — read from source only.
- **M run** — observed in the running Munder app.
- **M src** — read from Munder source only (not exercised).

Screenshots live in [`assets/electron/baseline/`](assets/electron/baseline/).
Munder screenshots were reviewed but are intentionally **not** committed: they are
full of Munder brand art and characters.

## Do not copy (vocabulary, brand, defaults)

Munder is a parody-branded product. None of the following may appear in
Agent Toolkit UI, docs, code identifiers or assets:

- Names and roles: **Michael**, **GOD** / `god` / "boss", the Dunder cast used as
  agent characters (Jim, Pam, Dwight, Kevin, Angela, Oscar, Stanley, Phyllis, Andy,
  Kelly, Ryan, Toby, Creed, Meredith), "clone of you".
- Metaphors: **floor**, **hive** (hive mail, hive board, hive memory), **hire** /
  hires / "import hire", **ASK ME**, "town hall", MemPalace, Founders' Wall.
- Visual identity: Munder's **maroon/gold** accents, pixel-font UI headings, the
  Pixi office floor with desks and character avatars as the primary surface.
- Unsafe defaults: autonomous "auto mode" (`--permission-mode bypassPermissions`,
  Codex sandbox bypass) **on by default**, telemetry **on by default**, and
  scheduled prompts that fire immediately after onboarding (the "hourly ops
  standup" showed "fired just now" on first run).

Agent Toolkit keeps its own Paper Co. language from [DESIGN.md](DESIGN.md):
workspace, agent, run, job, loop, swarm, task, approval, receipt.

## Workflow ledger

Each row: what Munder achieves for the user, what ATK achieves today, the gap,
the chosen ATK solution (with the program phase from the desktop workstation
plan), and how each side was verified.

### First run and setup

| Workflow | Munder outcome | ATK outcome today | Gap | Chosen ATK solution | Verified |
| --- | --- | --- | --- | --- | --- |
| First-run onboarding | 6-step wizard: technical/non-technical persona, feature tour, harness home folder, orchestrator engine + model, repos, permissions & reliability. Ends in a live orchestrator terminal. | None. The app opens on Office with backend health only ([office.png](assets/electron/baseline/office.png)). | Total | Phase 4.1 Onboarding: backend ready, then choose workspace, detect coding-agent CLIs, configure agent/provider/model, launch first real work, live terminal. Benchmarked step by step against Munder's wizard. | ATK run · M run |
| Coding-agent CLI detection | Engine list with per-CLI state: INSTALLED, NOT INSTALLED, INSTALLS ON FIRST RUN, WORKERS ONLY; recommended engine; model picker per engine. | None in Desktop. `tool_discovery.v` exists only in the native engine; no serve route. | Total | Phase 2 PR C: typed discovery split into detected / configured / enabled / verified, with install hints only where a real command exists. Phase 4.1 renders it. | ATK src · M run |
| Workspace selection | Harness home folder picker plus "add a repo" (native folder picker) during onboarding. | Context bar encodes workspace/agent/run in the URL and seeds workspace from the #1314 harness IPC (`~/.ai-workspace` when it exists). No picker yet; switching workspace still requires a backend restart. | Picker / multi-window | Phase 4.1 workspace step; evaluate one supervised backend per window/workspace. | ATK src · M run |
| Prerequisites / setup health | Settings → Prerequisites: "9 of 16 ready", one card per tool with READY state, resolved path and docs link, plus a button that asks the orchestrator agent to install what is missing. | Insights → Doctor is a flattened CLI text dump with a `--fix` confirm button ([insights.png](assets/electron/baseline/insights.png)). Settings → Selfcheck is a clean 4-row table. | Doctor is not actionable or scannable | Phase 4.3 Doctor with per-check impact, preview and apply-fix; Phase 4.1 reuses it for setup. Needs typed doctor checks from V. | ATK run · M run |
| Stale/missing backend | n/a (single bundled app). | A stale `/usr/bin/agent-toolkit` 1.16.0 without `serve` was picked from `PATH` and reported as "Backend crashed … Unknown command: serve"; Office still showed "Gathering attention items…" about 9 s after launch; Restart would relaunch the same `PATH` binary (per `backend.ts`) ([backend-missing-office.png](assets/electron/baseline/backend-missing-office.png)). | Wrong diagnosis, no next action | Phase 5 failure matrix: classify "incompatible backend" (version/capability probe before `serve`), show which binary was found and how to fix. | ATK run |
| Telemetry | PostHog analytics, opt-out (default on), honors `DO_NOT_TRACK`. | None. | Intentional difference | Keep telemetry absent; anything added later must be opt-in and receipt-visible. | ATK src · M run |
| Auto-update | Checks every 6 hours; version badge "click to check for updates". | None. | Gap | Required before a v2 release; out of scope for Phases 3–4. | ATK src · M run |

### Agents, runs and attention

| Workflow | Munder outcome | ATK outcome today | Gap | Chosen ATK solution | Verified |
| --- | --- | --- | --- | --- | --- |
| See agents and what they are doing | Agent strip cards (name, role, status, voice); Monitor tab lists each agent with cwd, budget bar, tool-call count, engine + model and "restart & continue". Canvas speech bubbles ("running the floor", "awaiting"). | Office shows backend version/URL and "Needs attention" only ([office.png](assets/electron/baseline/office.png)). No agent or run entity exists in the UI. | Total | Phase 2 PR C (agents catalog) + PR E (runs) + PR B (event bus), then Phase 4.2 Office: run rows with provider, model, workspace, current task, blocked reason, each linking to terminal/diff/evidence. No avatars, no fake progress. | ATK run · M run |
| Attention truth | ASK ME tab: "Nothing needs you right now" plus the rule for what lands there (blocked on your input or a to-do only you can do). | "Nothing needs you. The workstation is quiet." is shown right after a job **failed** ([office-after-jobs.png](assets/electron/baseline/office-after-jobs.png)) and while the backend is **crashed** ([crash-banner-office-after-health.png](assets/electron/baseline/crash-banner-office-after-health.png)). Running jobs are counted as attention. | Office misstates state | Phase 4.2: needs-me = approvals, failures, blocked, backend down; running and recently completed are separate sections. Fed by PR B events. | ATK run · M run |
| Launch/configure an agent | Add-agent dialog: identity, workspace (project, git worktree isolation, resume session id), engine (13 providers incl. custom, model list), briefing. Shows the exact command it will run. Import from a JSON manifest. | Only free-form job argv in Operations and free-form command in Terminal. | Total | Phase 2 PR C + Phase 4.1/4.3: typed agent-launch form with provider, model, workspace, isolation and an exact command preview. Gated permissions by default. | ATK run · M run |
| Human approvals | ASK ME queue, a "who can add agents: only me" setting, and onboarding lists human approvals under guardrails. | `x-confirm-required` is contract metadata only; no approval UI. | Total | Phase 2 PR E typed approvals (approve/reject with reason), Phase 4.2 surfaces them first in Office. Server-enforced, never a client allowlist. | ATK src · M run |
| Queue input while an agent is busy | QUEUE composer under the terminal (text, file attachments, voice); messages drain one by one when the agent goes idle. | None. | Gap | Phase 4.5 only if queue semantics are real in V; never a local echo. | ATK src · M run + M src |
| Dispatch work to an orchestrator | Monitor → "Dispatch": free-text task, suggested owner, orchestrator decomposes and assigns. | None (jobs are single CLI invocations). | Gap by design | Phase 4.3 swarm launch with explicit recipe, scope and budget preview instead of an always-on orchestrator persona. | M run |

### Operations: jobs, loops, swarms, schedules

| Workflow | Munder outcome | ATK outcome today | Gap | Chosen ATK solution | Verified |
| --- | --- | --- | --- | --- | --- |
| Run a job and watch it | n/a (work happens inside agent terminals). | Real `doctor` job: created ([operations-job-running.png](assets/electron/baseline/operations-job-running.png)), live SSE lines, `completed` exit 0, persisted log ([operations-job-done.png](assets/electron/baseline/operations-job-done.png)). Failed job shows `failed`/exit 1 with log ([operations-job-failed-detail.png](assets/electron/baseline/operations-job-failed-detail.png)). Jobs persist across backend restarts. | ATK strength, but rough | Phase 4.3: typed forms instead of argv, full job IDs (every row currently reads `job_2026`), detail beside the list, cancel/retry/delete once PR B lands. | ATK run |
| Job creation against the released backend | n/a | Released 1.35.0 rejects Desktop POSTs: "cross-site request forbidden" with no explanation ([operations-job-403-installed-1.35.0.png](assets/electron/baseline/operations-job-403-installed-1.35.0.png)); the supervisor still said `ready` because dev has no version pin. | Non-actionable error | Phase 5: map 403-from-gate to "backend too old for this Desktop build", and pin/verify capability, not only major version. | ATK run |
| Schedules / triggers | Triggers tab: schedules with interval, target, last/next fire and on/off; context compaction; webhooks; organisation link. | Loops exist in CLI (`loops/:sub` proxy) but no Desktop surface. | Total in UI | Phase 2 PR E typed loop list/status/history/receipts + Phase 4.3 loops: configure, schedule, budgets, gates, history. Schedules never auto-enabled. | ATK src · M run |
| Task board | Tasks kanban (TODO / DOING / BLOCKED …) fed by dispatched work; task detail overlay. | None. | Total | Phase 2 PR E tasks (status, owner, dependencies, blocked reason, history) + Phase 4.4 Work: list and board. | ATK src · M run |
| Message topology / activity | Graph tab (agents as nodes, legend request/query/propose/agree/refuse/inform) and Activity log (spawn, message, drop, app-start) plus a shared board. | None. | Gap | Phase 2 PR B event bus; Phase 4.3 swarm topology from real handoffs; activity feed from events. | M run |
| Budgets and circuit breaker | Floor token budget, token velocity, repeated-tool and error-storm limits; steer → constrain → stop; hard-stop toggle. Monitor shows Σ tokens and tok/min (OpenTelemetry, Claude only per source). | Token budgets exist as config; nothing measured or shown. | Total in UI | Phase 2 PR E budgets + Phase 4.9 Insights: show measured usage only where accounted, otherwise "unmeasured". | ATK src · M run + M src |
| Background workers (Slack) | Workers tab: isolated workers spun up per Slack message (0 / 4). | None. | Out of scope | Explicit decision later; not in this program. | M run |

### Terminal

| Workflow | Munder outcome | ATK outcome today | Gap | Chosen ATK solution | Verified |
| --- | --- | --- | --- | --- | --- |
| Live interactive terminal | Orchestrator PTY is live in the Command Center with font size controls and a focus-mode toggle. | Real bash PTY: typed input, colored output, `exit 3` reported with Restart ([terminal-live.png](assets/electron/baseline/terminal-live.png), [terminal-exited.png](assets/electron/baseline/terminal-exited.png)). Session survives navigation through tail replay ([terminal-after-nav.png](assets/electron/baseline/terminal-after-nav.png)). | Parity on basics; defects | Phase 3 persistent terminal dock (xterm stays mounted) + Phase 4.5 identity/split/lifecycle. Immediate defects: `xterm.css` is never imported (helper textarea and measure element render as a stray box top-left); a prompt is duplicated by the live/tail race; exit state wraps the toolbar. | ATK run · M run |
| Terminal bound to an agent/run | Every terminal belongs to an agent; header shows `live · pty <id>`. | Free-text "Run / agent identity" field; no link to a run, job or workspace. | Gap | Phase 4.5: tabs show agent, run, cwd and process state from typed entities. | ATK run · M run |
| Crash/exit recovery | Provider-aware `--resume` on respawn, "restore team" after quit, power-resume detection; quit is intercepted while PTYs are live. | Exit shows "exited N" + Restart (same args); PTYs die with the window. | Gap on reattach | Phase 4.5 relaunch-in-same-context; PTY reattach needs a transport design first. | ATK run · M src |

### Workspace: files, git, memory, skills

| Workflow | Munder outcome | ATK outcome today | Gap | Chosen ATK solution | Verified |
| --- | --- | --- | --- | --- | --- |
| Files and editor | IDE scoped to the agent and its folder: file tree, Monaco with tabs, copy path, save, find/replace/palette shortcuts shown in the empty state. | None. Workspace destination shows `workspace/info`, which the CLI rejects ("Unknown workspace subcommand: info"), rendered as a field table ([workspace.png](assets/electron/baseline/workspace.png)). | Total + a dead default call | Phase 2 PR F workspace-contained files API + Phase 4.6 Monaco editor. Phase 1 PR A allowlists turn the unknown `info` sub into a 404; the UI must stop calling it. | ATK run · M run |
| Git changes, history, compare | IDE Changes / History / Compare tabs; honest "Not a git repo." when applicable; per-agent git worktree isolation. | None. `git_service.v` is stubs only. | Total | Phase 2 PR G read-first git (status, diff, log, graph, branches, compare, worktrees) + Phase 4.6 Git panel scoped to agent/run. | ATK src · M run |
| Memory | Memory tab: text search across board/tasks/memory, semantic search (reports "not set up" honestly), per-agent memory file viewer/editor. | No Memory screen (only a `memory/:sub` proxy). | Total | Phase 2 PR D typed memory with provenance + Phase 4.7 Memory, beating Munder on provenance (file, author, timestamp, project/agent). | ATK src · M run |
| Skills | Skills tab: "Installed (17)", browse, search, cards with provider and BUNDLED badges, path, open folder. | Library → Skills catalog is one flattened paragraph of CLI output with descriptions truncated mid-word and a mojibake `CI�` from a byte-cut UTF-8 sequence ([library.png](assets/electron/baseline/library.png)). Plugins panel calls `plugin/list`, which does not exist ("Valid subcommands: sync, check"). | Unusable presentation, dead call | Phase 2 typed catalog + Phase 4.8 Library: separate agents/skills/packs/MCP/plugins views with catalog / installed / configured / verified / running states and install → verify → receipt. | ATK run · M run |
| MCP / connections | Settings lists a Connections section (not opened in this run). | Library → MCP servers is a health text dump. | Gap | Phase 4.8 + 4.10: MCP connections with masked config, probe and repair. | ATK run · M run (not opened) |

### Insights, settings, shell

| Workflow | Munder outcome | ATK outcome today | Gap | Chosen ATK solution | Verified |
| --- | --- | --- | --- | --- | --- |
| Insights / reporting | Monitor token totals; activity feed. | Insights report shows escaped JSON twice (`JSON`, `__RAW_JSON` rows); capability matrix is Markdown flattened into a paragraph; diff surface is CLI text ([insights.png](assets/electron/baseline/insights.png)). | Raw output, no metrics | Phase 4.9: real activity, outcomes, durations, token usage and cost only where accounted; receipts and failures. Needs typed insights from V. | ATK run · M run |
| Settings | Modal with sections: General (version, updates, home folder), Prerequisites, Agents & Models, Autonomy & Budgets, Connections, Voice, Memory & Knowledge. | Backend identity + Restart, Selfcheck table, Update/Uninstall profiles (destructive button beside a benign one), full CLI help as a `<pre>` that overflows horizontally ([settings.png](assets/electron/baseline/settings.png)). | Gap | Phase 4.10: appearance, scale, motion, tools/MCP connections, backend diagnostics; move help behind a link; destructive actions confirmed in a dialog. | ATK run · M run |
| Backend crash and restart | n/a | SIGKILL of the supervised `serve` child flips to `crashed` with signal detail and a Restart banner; Restart relaunches on a new port, `restarts` increments, panels recover, no loop ([crash-banner-operations.png](assets/electron/baseline/crash-banner-operations.png), [backend-restarted-office.png](assets/electron/baseline/backend-restarted-office.png)). During restart the banner disappears while panels still show the old-port error ([backend-restarting.png](assets/electron/baseline/backend-restarting.png)). | ATK strength; copy/controls need work | Phase 5: human-readable crash copy, disable mutations (Start job stays enabled while crashed), per-panel Retry hidden while the backend itself is down. | ATK run |
| Packaged app | Munder ships AppImage/dmg/exe with auto-update (not exercised). | `pnpm dist:dir` with `ATK_BACKEND_BIN` staged: bundled backend used ("via bundled"), ready within about 1.2 s, real job and PTY work ([packaged-office.png](assets/electron/baseline/packaged-office.png), [packaged-settings.png](assets/electron/baseline/packaged-settings.png), [packaged-terminal.png](assets/electron/baseline/packaged-terminal.png)). | Parity on boot | Final UAT: AppImage/deb across the 15 journeys in [USER_JOURNEYS.md](USER_JOURNEYS.md). | ATK run |
| Keyboard and command palette | IDE lists shortcuts (Ctrl+F, Ctrl+H, F1 palette, Ctrl+G, Ctrl+Shift+O); focus mode toggle. | Skip link and visible 2px brass focus ring on every control ([focus-nav-keyboard.png](assets/electron/baseline/focus-nav-keyboard.png), [focus-input-keyboard.png](assets/electron/baseline/focus-input-keyboard.png)); no palette, no shortcuts. | Gap | Phase 3 command palette (Ctrl/Cmd+K) over real commands + discoverable shortcut map. | ATK run · M run |
| Themes and typography | Light/dark toggle; pixel display font for headings, sans body. | Paper only. Fonts are not bundled: the stack falls back from Iowan Old Style/Palatino to P052 on this machine, so headings and body are the same serif at 15px. | Gap vs DESIGN.md | Phase 3: bundle Fraunces + IBM Plex Sans/Mono via `@fontsource`; Paper, Ink, System tokens. | ATK run · M run |
| Multi-project | Multiple "floors" keep running when a window closes (source: close dialog "Other floors keep running", `HivePicker.tsx`). | Single cwd-rooted workspace. | Gap | Context-bar workspace switching first; multi-window only if journeys prove it. | ATK run · M src |

## Top 15 prioritized UX gaps

Ordered by user impact on the first 10 minutes and on trust. Phase refers to
the desktop workstation plan.

| # | Gap | Phase |
| --- | --- | --- |
| 1 | No first-run onboarding: no workspace choice, CLI detection or engine/model setup | 4.1 (+ 2 PR C) |
| 2 | No workspace chooser/switcher; outside a workspace every action fails with an env-var instruction | 3 context bar, 4.1 |
| 3 | Office misstates reality: "workstation is quiet" after a failed job and while the backend is down | 4.2 (+ 2 PR B) |
| 4 | No agent or run presence (provider, model, status, current action) anywhere | 2 PR C/E, 4.2 |
| 5 | No typed way to launch agent work; only free-form argv with no command preview | 2 PR C, 4.1/4.3 |
| 6 | Library, Insights and Workspace render raw CLI text, escaped JSON and mojibake; two panels call subcommands that do not exist (`workspace/info`, `plugin/list`) | 1 PR A, 2, 4.8/4.9 |
| 7 | Terminal is not a flagship: form dominates, viewport below the fold at 1024×640, missing `xterm.css`, toolbar wraps on exit, no dock | 3 dock, 4.5 |
| 8 | No human approvals / needs-me inbox | 2 PR E, 4.2 |
| 9 | No task board or task detail | 2 PR E, 4.4 |
| 10 | No files/editor or git changes/history/compare | 2 PR F/G, 4.6 |
| 11 | No memory browse/search/edit | 2 PR D, 4.7 |
| 12 | Failure diagnosis: stale backend on PATH reported as a crash; gate 403 shown as "cross-site request forbidden"; Start job enabled while crashed | 5 failure matrix |
| 13 | No budgets, usage or circuit-breaker visibility | 2 PR E, 4.9 |
| 14 | No loops/schedules surface | 2 PR E, 4.3 |
| 15 | No command palette or shortcut map; fonts not bundled (DESIGN.md typography unmet) | 3 |

## Baseline UX critique per ATK destination

All captures at 1440×900 unless named `compact-*` (1024×640), dev Electron at `d4ff3731`.

### Office — [office.png](assets/electron/baseline/office.png), [compact-office.png](assets/electron/baseline/compact-office.png)

- **Hierarchy:** infrastructure first. The largest element is "backend 1.35.0 · `http://127.0.0.1:<port>`", which answers nothing about work.
- **Density:** two short panels; more than half of the viewport height is empty.
- **Typography:** single serif family (fallback P052) for heading, labels and body; weak contrast between levels.
- **Actions:** none. No way to start work, open a run or respond to anything.
- **State communication:** wrong. Reports "quiet" after a failure and during a crash. The attention panel has no error branch: when the backend never starts it shows "Gathering attention items…" and, once the queries give up, can only fall back to "Nothing needs you".
- **Keyboard/focus:** skip link and visible focus ring work; nothing actionable to reach.

### Operations — [operations.png](assets/electron/baseline/operations.png), [operations-job-done.png](assets/electron/baseline/operations-job-done.png), [operations-job-failed-detail.png](assets/electron/baseline/operations-job-failed-detail.png)

- **Hierarchy:** the "Start work" form outranks the job list; job detail opens below the fold.
- **Density:** table is reasonable, but the ID column truncates every ID to the identical `job_2026`, and full ISO timestamps waste width.
- **Typography:** mono for commands and IDs is correct; headings and labels share one serif.
- **Actions:** free-form "Command/Arguments/Workspace" text fields; no cancel, retry or delete.
- **State communication:** status dots plus words (good, not color-only); live output and persisted log duplicate the same content.
- **Keyboard/focus:** tab order and focus ring are fine; the job ID button is the only way to open detail.

### Workspace — [workspace.png](assets/electron/baseline/workspace.png), [emptyws-workspace-actions.png](assets/electron/baseline/emptyws-workspace-actions.png)

- **Hierarchy:** the default panel shows a CLI error as if it were data.
- **Density:** four action buttons with no explanation of what each produces.
- **Typography:** field table in uppercase serif labels; nothing editorial.
- **Actions:** buttons that run CLI subcommands; results are one-line messages.
- **State communication:** failures ("workspace not found…") render as plain paragraphs, not errors, and point at an env var instead of an in-app action.
- **Keyboard/focus:** reachable; no disabled explanations.

### Library — [library.png](assets/electron/baseline/library.png), [compact-library.png](assets/electron/baseline/compact-library.png)

- **Hierarchy:** none. The skills catalog is a single wall of text.
- **Density:** extreme and unscannable; descriptions are cut mid-word.
- **Typography:** body serif at 15px for a catalog that needs a list/table; mojibake `CI�` visible.
- **Actions:** one "Install profiles" confirm button; no per-item inspect, install or verify.
- **State communication:** Plugins panel shows "Unknown subcommand: list"; MCP health is prose.
- **Keyboard/focus:** long page with no in-page navigation or search.

### Insights — [insights.png](assets/electron/baseline/insights.png)

- **Hierarchy:** four equal panels of raw output; no summary numbers.
- **Density:** the insights report repeats the same escaped JSON three times (message, `JSON`, `__RAW_JSON`).
- **Typography:** Markdown tables flattened into paragraphs.
- **Actions:** "Run doctor --fix" with confirm; no preview of what it changes.
- **State communication:** session counts per tool exist in the payload but are never charted or tabulated.
- **Keyboard/focus:** fine; nothing to navigate to.

### Terminal — [terminal.png](assets/electron/baseline/terminal.png), [terminal-live.png](assets/electron/baseline/terminal-live.png), [terminal-exited.png](assets/electron/baseline/terminal-exited.png), [compact-terminal.png](assets/electron/baseline/compact-terminal.png)

- **Hierarchy:** the new-session form sits above the terminal on every visit; at 1024×640 the viewport starts below the fold.
- **Density:** fixed-height viewport; the page scrolls instead of the terminal filling the destination.
- **Typography:** xterm mono fallback is fine; the missing `xterm.css` leaves a visible helper box and dotted measure line top-left.
- **Actions:** Ctrl-C, Terminate, Close, Restart, search all work; Close is destructive and styled red, good.
- **State communication:** tab dot turns red and "exited 3" appears, but the toolbar wraps and the body never says the process ended.
- **Keyboard/focus:** xterm takes focus on open; no shortcut to switch tabs or open a new session.

### Settings — [settings.png](assets/electron/baseline/settings.png), [packaged-settings.png](assets/electron/baseline/packaged-settings.png)

- **Hierarchy:** backend identity first is right for a diagnostics section, but there are no appearance or tool settings.
- **Density:** the full CLI help `<pre>` causes a horizontal scrollbar across the whole page.
- **Typography:** `dl` renders as indented serif text; selfcheck table is the cleanest table in the app.
- **Actions:** "Uninstall profiles" (destructive) sits next to "Update profiles" with the same weight except color.
- **State communication:** status/version/detail are honest, including "no staged version pin".
- **Keyboard/focus:** fine.

### Shell-wide

- Sidebar is a plain list with no counts, status or current context; brand text is the only header.
- The crash banner is the only global state surface; there is no stale/offline indicator and no toast/receipt surface.

## Where ATK is already stronger

- Supervised backend lifecycle: health-gated start, crash detection with signal detail, one-click restart that recovers on a new port without a loop.
- Server-side jobs that persist across backend restarts and app instances, with named SSE events.
- Honest refusal to show controls the backend cannot prove (no fake cancel, no fake progress).
- Safe defaults: no telemetry, no autonomous permission bypass, nothing scheduled on first run.

## Munder UX notes (for calibration, not imitation)

- The Pixi office canvas takes about two thirds of the window and carries little operational information; the useful surface is the Command Center column. ATK should give that space to runs, attention and the terminal.
- Ten Command Center tabs in a 4×3 grid are dense; several are empty on a fresh install.
- Pixel-font uppercase headings hurt scanning at small sizes.
- Strong ideas worth matching in ATK's own language: install-state badges per CLI, the exact command preview before launch, per-agent worktree isolation, agent-scoped IDE, honest "not set up / not a git repo" states, quit interception while terminals are live.

## Capture recipe (reusable)

What worked on Linux/Hyprland (Wayland) with no Xvfb installed:

1. Build: `pnpm install` at repo root. If `node_modules/.pnpm/electron@*/node_modules/electron/dist` is missing (pnpm reused the store and skipped postinstall), run `node install.js` in that package. Then `pnpm --filter agent-toolkit-desktop build:all`.
2. Launch detached and **unset `ELECTRON_RUN_AS_NODE`** (Cursor terminals export it; Electron then runs as plain Node and `app` is undefined):
   `env -u ELECTRON_RUN_AS_NODE PATH="<dir with agent-toolkit>:$PATH" setsid -f electron apps/desktop --remote-debugging-port=9333 --user-data-dir=/tmp/<profile>`.
   `setsid -f` matters: without it the app dies when the launching shell exits.
3. Drive and capture through CDP on `127.0.0.1:9333`: `Runtime.evaluate` (set `location.hash`, click buttons), `Input.insertText` / `Input.dispatchKeyEvent` for xterm typing, `Emulation.setDeviceMetricsOverride` for a fixed 1440×900 or 1024×640 viewport, `Page.captureScreenshot` for PNGs. Works while the window is tiled on another workspace.
4. Backend: the supervisor uses `resources/bin/agent-toolkit` when packaged, else the first `agent-toolkit` on `PATH`. Put a gate-capable build first on `PATH` for dev; for packaged runs set `ATK_BACKEND_BIN=<binary>` before `pnpm dist:dir` (no V build needed if a binary exists).
5. Stop by exact PID of the Electron main process (`SIGTERM`); the supervisor stops its `serve` child. Verify no `agent-toolkit serve --host 127.0.0.1` remains.

## Evidence log

- 2026-09-29 — Live baseline: ATK dev Electron + packaged `dist:dir` at `d4ff3731`; Munder `5756722e` run locally (onboarding, Command Center tabs, add-agent, IDE, settings). Munder terminal crash recovery not exercised (source-read only). Replaces the earlier code-tour matrix at Munder `ed06e3e`.
