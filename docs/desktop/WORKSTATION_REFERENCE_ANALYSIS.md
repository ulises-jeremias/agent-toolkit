# Workstation reference analysis

Status: **HISTORICAL ENGINEERING ANALYSIS** (snapshot 2026-09-30; not a
current implementation ledger).
Renamed from `MUNDER_GAP.md` via `git mv` (history preserved).

> **Visual-authority note (2026-09-30):** the Paper Co. visual language this
> document references ("ATK keeps Paper Co.") is **deprecated by
> [ADR-035](../adrs/ADR-035-cozy-pixel-world.md)**. The capability matrix and
> reference lessons below remain valid; visual claims are superseded by
> [DESIGN.md](DESIGN.md) (Cozy Pixel World).

> **Current-state notice (2026-10-02):** several implementation-status rows
> below describe the pre-stabilization baseline and are retained only as
> historical reasoning. For current product status, use
> [workflows.yaml](workflows.yaml), [PACKAGING.md](PACKAGING.md),
> [PEOPLE.md](../PEOPLE.md), and the accepted [ADR-033](../adrs/ADR-033-electron-desktop.md).
> The Electron Desktop is canonical; the former native V GUI and its unused
> terminal modules have been removed.

This is the single in-repo comparison of Agent Toolkit Desktop against two
external capability references. It is not a feature-parity program and not a
visual brief.

Visual authority is [DESIGN.md](DESIGN.md) (Cozy Pixel World).
Design notes:

- [01 — Attention and agent status](design-notes/01-attention-and-agent-status.md)
- [02 — Sessions, adapters, durability](design-notes/02-sessions-terminals-and-durability.md)
- [03 — Git / worktree write lifecycle](design-notes/03-git-worktree-write.md)

Classification vocabulary used below:

| Label | Meaning |
| --- | --- |
| **SOLVED** | Agent Toolkit already delivers the user outcome |
| **ATK-BETTER** | Agent Toolkit's model is already the one to keep |
| **ADOPT** | Take the concept as-is into ATK architecture |
| **ADAPT** | Take the user outcome; re-express it in V + Electron |
| **BACKEND** | Useful, but a V primitive must land first |
| **LATER** | Valuable after current Electron/typed-API work |
| **REJECT** | Do not implement; rationale recorded |
| **N/A** | Not a Desktop product concern |

---

## 1. Reference SHAs (2026-09-30)

| Product | Revision | Date | How verified |
| --- | --- | --- | --- |
| Agent Toolkit `origin/main` | `ada41cfc` (merge of #1320) | 2026-09-30 | Reconstructed from GitHub `commits/main`. Parents: #1321 `a25496ad` then #1320. Latest tag **v1.35.0** (2026-09-29). |
| Agent Toolkit Electron app | shipped on `main` since #1311; default harness #1314; foundations #1321 | 2026-09-29/30 | GitHub tree after #1321: context bar, Ctrl+K palette, persistent dock, Paper/Ink primitives, Playwright E2E. Baseline captures still at `d4ff3731` (#1317). |
| Agent Office `main` | `f88a31f18269b7ea11491e51ca9ba9b64daf04c2` | 2026-09-30 00:26:25 -0400 | Fetched `origin/main`. Tag `v0.1.174` (`c1924dbf`); HEAD is `v0.1.174-2-gf88a31f`. #197 lost-worktree wait (`13c104eb`) plus #198 pointer-lock settle only (`player.ts` SETTLE 100/150 ms — 3D camera, not capability). Clone: `repos/agent-office`. |
| Munder Difflin local | `5756722e93980610e024a3f1ee7e918365ef60ec` | 2026-09-29 00:05 +0530 | Same SHA as the 2026-09-29 live run (package 0.4.6 / tag `v0.5.3-40`). |
| Munder `origin/main` | `ed06e3e7618b3477a9fb325203e243a53037d5d2` | 2026-09-29 15:22 +0530 | **SEO-engine blog commits only** after `5756722e`. No product/runtime change. Capability refresh = no-op. |

Agent Office local run (this research): CLI `--help` succeeded; `node bin/agent-office.js --host 127.0.0.1 --port 14600 --home /tmp/ao-probe-*` printed "agent-office is open" and `GET /` + `GET /lite` returned **302** (login). No floors, no paid provider, no 3D client. Exact PID stopped (`SIGTERM`); leftover research instance on :4817 also stopped. Probe home deleted. **No generated password is recorded here.**

Verification legend: **SRC** = read source; **RUN** = exercised; **DOC** = project docs only; **GH** = GitHub issue/PR.

---

## 2. Agent Toolkit snapshot from the research date

### Architecture now

At the time of this research on 2026-09-30, ADR-033 was still proposed. It was
accepted on 2026-09-30 and is now the current presentation authority. This
snapshot is retained to explain the comparison, not to describe today's state.
The accepted architecture is:

- **V** = core + CLI + `agent-toolkit serve` (domain authority).
- **Electron + React** = Desktop (`apps/desktop/`).
- Electron main/preload = infrastructure only (lifecycle, bundled `serve`,
  IPC, node-pty adapter).
- React must not become a second domain implementation.

Implementation on `main` already advances that split (#1311 Electron app,
#1312/#1316 backend pin, #1313 job cancel/delete, #1314 default harness
`~/.ai-workspace`, #1315 typed `:sub` bodies, #1318 memory table fix,
#1321 design system / typed data layer / Electron E2E / context bar).
ADR-033 supersedes ADR-032 at the presentation layer; V remains the core,
CLI, and backend authority. v1.35.0 is preserved as a historical release;
current package guidance is in
[PACKAGING.md](PACKAGING.md).

### Open work (do not derail)

| PR | State | Role |
| --- | --- | --- |
| [#1318](https://github.com/ulises-jeremias/agent-toolkit/pull/1318) | **MERGED** | Memory `prepend_table_row` fix |
| [#1321](https://github.com/ulises-jeremias/agent-toolkit/pull/1321) | **MERGED** `a25496ad` | Paper/Ink design system, typed data layer, real Electron E2E, context bar |
| [#1320](https://github.com/ulises-jeremias/agent-toolkit/pull/1320) | **MERGED** `ada41cfc` | `GET /api/v1/events` SSE ring, job get/retry, typed schemas. Kinds today: `backend.*`, `job.*`, `loop.*`, `swarm.changed`, `memory.changed`, `install.*`. Room remains for `attention.*` / `session.*`. |
| [#1322](https://github.com/ulises-jeremias/agent-toolkit/pull/1322) | OPEN, rebased onto post-#1323 `main` | Runtime harness switch + honest backend binary resolution. Settings picker / MRU; env > persisted > `~/.ai-workspace` > fallback; switch restarts serve. |

#1320 and #1321 have landed. #1321's context bar encodes workspace/agent/run
in the URL and seeds workspace from the resolved harness. Settings can now
change that harness (`atk:harness-choose` / `set` / `recent` / `reset`); a
switch still restarts the one supervised backend (cwd-rooted). No first-run
wizard or "add a repo" yet.

### Stale statements (do not follow)

| Claim | Where | Current truth |
| --- | --- | --- |
| "native V + gg/sokol" as Desktop invariant | #1227 body | Historical direction; ADR-033 now makes Electron + React the canonical presentation. |
| #1227 slices A–J "DONE on main" as Electron truth | #1227 | Those slices landed on the **native** Desktop. Electron Office (`Office.tsx` after #1321) still builds a **client** `AttentionItem[]` from backend health, harness notice, recent failed jobs, and failing self-checks — not a V `AttentionItem` bus. |
| `git_service.v` is a git backend | native engine | `backend_available` is **hard-false**; `git_changes`/`git_history`/`git_diff` return empty. Checkout is omitted with a reason string. Worktree *visibility* in native GUI ≠ a write lifecycle and ≠ a `serve` git API. |
| PTY durability exists | #1073 / #1227 OPEN-future | Electron terminals are node-pty in main; they die with the window. 8 KiB tail replay only. |
| ADR-033 is still proposed | this 2026-09-30 research snapshot | Accepted and current; see [ADR-033](../adrs/ADR-033-electron-desktop.md). |
| #1118 "production is gg/sokol-direct" | #1118 2026-09-13 body | True of the native binary at that SHA. Electron is now the active Desktop implementation track. Paper Co. is retired by ADR-035; Cozy Pixel World is the current visual authority. |

### Domain entities that exist in V today

| Entity | Where | Notes |
| --- | --- | --- |
| Agent (catalog) | agents catalog / Library | Definition, not a running process |
| Job | `serve` jobs | CLI invocation; SSE; cancel/delete (#1313); get/retry + `GET /api/v1/events` (#1320 on `main`) |
| Swarm run | `swarm.v` state | Roles, worktrees, handoffs, gates, budgets |
| Loop | loops + optional cron *flag* | No scheduler daemon (honest) |
| Task / handoff | swarm mailbox | Not a standalone Task entity |
| Terminal session | Electron main ad-hoc ids; native `modules/pty.Session` | **No V session record** linking provider + run + process |
| Approval | swarm `approvals.json`; `x-confirm-required` metadata | No typed Desktop approval inbox yet |
| Memory | core memory files | #1318 fixed table rows |
| Git | Engine stubs; native read rails in Desktop modules | No `serve` git/write API |

**Do not invent a TypeScript `Worker`.** The row people point at is
`Agent + Run + Session + Job` projected by ids from V.

---

## 3. Agent Office architecture (how it actually works)

Node HTTP server + browser client. A **floor** is one git checkout. Workers
are first-class runtime rows persisted in `<floor>/.agent-office/workers.json`
(direct overwrite, mode `0600`, **not** atomic). Each worker has provider,
model, effort, desk, worktree, optional extra repos, `sessionId`, PTY claim,
`midTurn`.

**Strongest technical ideas (SRC at `f88a31f`; capability code unchanged since `13c104eb`):**

1. **Detached PTY host** (`ptyhost.ts` / `ptys.ts`): Unix `detached`+`unref`
   process, owner-only Unix socket + 24-byte token file, protocol version 1,
   newest office wins, 30-minute orphan timeout, headless xterm snapshot on
   attach. **Process durability ≠ conversation durability.**
2. **Per-provider adapters** (Claude, Codex, OpenCode, Grok, Muse, DSH/ACP)
   with hook-captured session ids and resume argv / ACP `session/resume`.
3. **Worktree lifecycle** (`office/<name>-<4hex>`), dirty/unpushed protection,
   merged-PR `headRefOid` exemption for squash, leave-on-merge, prune, #197
   lost-worktree rebuild (user action, not automatic).
4. **Capability-scoped worker ops** via loopback `office-workers` + MCP
   (`list` / `hire` / `tell` / `home`), authenticated per worker token — not
   a central planning brain.
5. **Attention as "oldest waiting first"** (`nextup.ts`: `needs_input` +
   unseen `done`, `N` with a per-round visited set).
6. **Service discovery** (`services.ts`): `ss`/`lsof` + ppid walk to PTY,
   then `AGENT_OFFICE_WORKER_ID` env, then worktree cwd; HTTP probe before
   publish. User-owned terminals are excluded.
7. **`/lite`**: same floor operations without the 3D world.

**Weaknesses / tradeoffs:**

- Domain truth lives in Node. Restart persistence is a JSON file overwrite.
- One flat `needs_input` mixes permission, question, and "finished".
- PRs are never drafts; queue completion ≠ PR opened.
- 3D office + game surfaces are the product identity, not the capability.
- Windows: no PTY host (in-process only).
- Service attribution falls back to cwd heuristics after detach/`nohup`.
- Machine pressure is warn-only; `--max-workers` is the hard cap.

---

## 4. What each reference is for

| | Munder Difflin | Agent Office |
| --- | --- | --- |
| Best as | Command-center IA, agent cards, memory/tasks, IDE/Git chrome, polished desktop product, onboarding gating | Direct manipulation of live agent sessions, durable PTY, provider resume, worktrees/PRs, multi-repo, queue, agent-to-agent *tools*, attention shortcut, services, `/lite` |
| Overlap | Hire/configure an agent, per-agent terminal, worktree isolation, "what needs me" | Same user outcomes, different runtime |
| Fundamentally different | Always-on god orchestrator ("Michael"), Sims floor as primary, auto-mode defaults | Multiplayer 3D office, workers as the entity, MCP `office-workers`, detached PTY host |
| Visual/brand | REJECT (parody cast, maroon/gold, Pixi floor) | REJECT (3D, walking, elevators, rooftop/arcade/sports/cars/dog/weather) |

At the time of this historical comparison, the recommendation was to retain the
then-current visual language. ADR-035 later replaced it with Cozy Pixel World.
The enduring architecture constraints are typed Engine/`serve` truth, gated permissions, no
telemetry-by-default, no god-agent as domain authority.

---

## 5. Unified capability matrix

Desired end state is always **ATK's own model**, not a union of the two
references.

| Capability | ATK now | Munder | Agent Office | Desired ATK | Class |
| --- | --- | --- | --- | --- | --- |
| First-run / setup | Phase 4.1: backend ready → confirm-create `~/.ai-workspace` → honest CLI/model gaps + Doctor → real `version` job or PTY → Office | 6-step wizard (persona, engine, repos, permissions) | Login / floor gating | Keep honest gaps until typed discovery; never mkdir without confirm | **ATK-BETTER** (honesty) |
| Agent lifecycle (define → launch → inspect → stop) | Catalog + jobs + swarm runs; no session entity; Electron launch is free-form argv | Hire modal + command preview + restore team | Hire/tell/home + persist + resume | Catalog Agent + Run + Session; typed launch form | **ADAPT** |
| Provider abstraction | Split: `tool_discovery.v`, swarm runners, profiles; #1227 OPEN-future | 13 presets + model chips | One module per provider + ACP | One V `ProviderAdapter` table | **ADAPT** / **BACKEND** |
| Model / effort per session | Absent in Desktop | Per-agent model | Per-worker model + effort | Session fields from adapter | **ADAPT** / **BACKEND** |
| Sessions | Missing in V | Provider `--resume` on respawn | `sessionId` + midTurn + carry-on | V Session record | **ADAPT** / **BACKEND** |
| Terminal architecture | node-pty in Electron main (ADR-033) | In-process node-pty | Hosted Unix PTY + in-process Windows | Main owns bytes; V owns identity | **ATK-BETTER** (split) |
| PTY persistence | 8 KiB tail; dies with window | Process dies; conversation resume | Detached host + 3k-line snapshot + 15s `.ansi` | G1 mirror now; G2 resume; G3 optional host | **ADAPT** |
| Status / attention | Electron: health + jobs; native: richer, stale vs Electron | ASK ME = blocked-on-human | Oldest `needs_input`/`done` + `N` | Typed `AttentionItem` kinds + severity | **ADAPT** |
| Approvals | Contract metadata; swarm gates in core | ASK ME + who-can-hire | Provider permission hooks | Server-enforced, first in Office | **BACKEND** |
| Orchestration | Swarm recipes, budgets, gates | God agent + dispatch | Queue + meetings + MCP hire | Typed swarm/queue; no god | **ATK-BETTER** |
| Task queue | Jobs + loop run + swarm; composer in native | Kanban + god assign | FIFO queue, max workers, issue claim | Converge on jobs/loops/swarm; no fourth queue | **ADAPT** |
| Worktrees | Native visibility rail; Engine git stubs; no serve write | Per-agent isolation | Full create/protect/prune/rebuild | V-owned write lifecycle | **BACKEND** |
| Multi-repo | Harness / workspace is one root | Multi-floor (source) | One worker, N worktrees, linked PRs | Later, harness-shaped | **LATER** |
| Git lifecycle | Read omitted in Engine; Electron has no Git panel | IDE Changes/History/Compare | Changes beside worker; merge-base | Run inspector facet after V git | **BACKEND** |
| PR integration | None | CI on-demand (thin) | `gh pr create` (not draft); leave-on-merge | Optional, receipted, never a GH clone | **LATER** |
| Services / previews | None | None comparable | Port scan + PTY/env/cwd attribution | Only with proven ownership | **LATER** |
| Scheduler / loops | Loops exist; cron flag ≠ daemon | Triggers + immediate fire on first run | Queue pump 10s | Keep honest flag; daemon later | **ATK-BETTER** (honesty) |
| Memory / context | Files + #1318; Desktop surface thin | Memory tab + MemPalace | Chat log + task cards (Haiku summaries) | Provenance-first memory | **ATK-BETTER** |
| Costs / budgets | Config; unmeasured in UI | OTel + breaker (Claude) | Provider usage fields | Show only accounted | **ATK-BETTER** |
| GitHub integration | `gh` via skills, not Desktop | Slack/org workers | Issues/PRs/queue/`gh` | Keep as skill/CLI; Desktop later | **LATER** |
| Command / search | Native typed registry; Electron Ctrl+K palette shipped in #1321 (static Go/Session/Appearance/Help — not live entities, not Engine registry) | IDE palette | Palette = live entities; search ≠ palette | Typed registry authority; terminal search separate | **ATK-BETTER** + **ADAPT** |
| Persistence | Jobs on disk; sessions not | Hive files + sqlite scalars | `workers.json` / `queue.json` | V session dir + jsonl events | **ADAPT** |
| Crash recovery | Supervised `serve` restart (ATK strength) | Restore team | SIGTERM keeps host; SIGINT kills | Keep supervisor; add session reload | **ATK-BETTER** + **ADAPT** |
| Resumability | Restart same argv | Provider `--resume` | Adapter resume + carry-on | V `provider_session` | **ADAPT** |
| Collaboration | Single-user Desktop | Single-user | Multiplayer / voice / screenshare | Single-user workstation | **REJECT** (multiplayer product) |
| Accessibility | Electron a11y path; native incomplete | Pixel-font headings | `/lite` + 3D primary | Compact/text twin required | **ADAPT** (lesson) |
| Compact / narrow | 1024 captures; Office still sparse | Command Center column is the real UI | `/lite` | Every workflow without Office decor | **ADAPT** |
| Security | First-party gate, contained paths, no CLI parse | Auto-mode default on | Loopback token, env scrub, isolated homes | ATK model wins on conflict | **ATK-BETTER** |
| Architecture boundary | V domain / TS infra (Proposed) | Electron monolith domain | Node domain | Keep the split | **ATK-BETTER** |

---

## 6. Areas A–L (Agent Office → ATK)

### A. Provider abstraction — **ADAPT / BACKEND**

AO separates identity, discovery, argv, model/effort, isolated HOME/XDG,
hooks, session-id capture, resume, usage, permissions. DSH is ACP-over-stdio
rendered as ANSI into the same headless xterm (not a fake PTY).

ATK already has discovery + swarm runners. Collapse them into one V adapter
table (design note 02). #1227 "provider/model per-agent = OPEN-future" stays
open but is no longer "intentionally absent forever" — it becomes a Session
field once the adapter exists. **Do not implement provider parity in
TypeScript.**

### B. Durable terminals — **ADAPT in tiers (G1 now / G2 next / G3 later)**

AO host: detached Node, Unix socket, token, snapshot, 30 min orphan.
ATK already chose node-pty in Electron main (ADR-033). **Do not copy the host
into V.** PTYs survive a `serve` restart *by construction* if main owns them.

Guarantee table (never say "sessions survive restart"):

| Failure | Process | Screen | Conversation | Commit |
| --- | --- | --- | --- | --- |
| Renderer reload / window recreate | kept | replay | kept | **G1** |
| `serve` restart | kept | kept | kept | **G1** |
| Electron main crash | lost | persisted tail | resumable if id known | **G2** |
| Quit / reboot | lost (default) | persisted tail | resumable | **G2**; **G3** = opt-in keep-alive |

G3 (detached host) only with an explicit "keep sessions after quit" setting,
Unix first, visible list. Windows has no AO host.

### C. Workers as entities — **REJECT as a new type; ADAPT the lifecycle**

AO worker = ATK Agent + Run + Session. Lifecycle (hire/assign/working/
waiting/done/resume/tell/changes/PR/cleanup) maps onto V ops + projections.
Missing piece is **Session**, not Worker.

### D. Worktree lifecycle — **BACKEND**

AO is the best write-lifecycle evidence we have (fetch current branch, record
base/`from`/`made`, dirty/unpushed, squash `headRefOid`, prune, #197 rebuild).
ATK: native visibility only; Engine git `backend_available=false`; no serve
git. **Do not expose Desktop git writes until V owns preview + receipt.**
See design note 03.

### E. Multi-repo workers — **LATER**

Useful for cross-repo refactors. ATK's harness is one workspace root today
(#1314). Do not add a second workspace model. Revisit after single-repo
worktree writes exist. Classify user outcomes worth keeping: linked PRs,
`GIT_CEILING_DIRECTORIES`, all-or-nothing create, per-repo PR failure.

### F. Queue — **ADAPT (converge, do not add a fourth system)**

AO: FIFO, `maxWorkers` (default 3), machine cap, issue assign, restart marks
running tasks exited. ATK already has jobs, loops, swarm, native queue
composer. Completion = worker status, not PR. Use jobs/loops/swarm; add
concurrency caps as V policy.

### G. Agents managing agents — **refine the rejection**

Keep **REJECT** of a central god-agent / agent-manager as domain authority
(Munder "Michael", inbox flood). **ADAPT later**: capability-scoped tools
(`list_runs`, `inspect_run`, `create_run`, `send_message`, `cancel_run`,
`list_pending_approvals`, `inspect_worktree`, `cleanup_completed_run`) that
only call Engine/`serve` ops, same policy as the human. MCP must not become
an orchestration engine. `office-workers` is evidence that this distinction
is real.

### H. Attention — **ADAPT**

AO `N` + oldest-wait is the UX to steal. Do not flatten kinds. V owns
`AttentionItem` (design note 01). Failures and approvals outrank "done".
Backend-down is a local supervisor item, not a fabricated V fact.

Phase 4.2 Office is the honesty **inspector** (design note 01), not the
product home. The world owns lights/characters; this destination is the
detailed list. Manila "Needs you" from crash / version-mismatch / harness
/ failed jobs / failing self-checks; running and completed stay separate;
empty copy only after jobs + selfcheck succeed; palette "Next that needs
me" cycles crash → failed → running on the current harness. World link:
`href('/office', { inspect: key })`. Approvals and review-ready still
wait on V. Cross-workspace later.

### I. Changes / PR — **BACKEND then LATER**

Natural home is the run/session inspector (prompt → session → files → diff →
tests → commit → PR → cleanup). Not a GitHub client. Draft-by-default if ATK
ever opens PRs (AO does not use `--draft` — we should).

### J. Services — **LATER, only if attribution is proven**

AO order: PTY ancestor, then env, then worktree cwd; HTTP probe; exclude
agent-own ports. Cwd fallback is **not** fact. ATK may ship a "possible
preview" only when pid ancestry or an ATK env id is proven; otherwise
"unattributed listener".

### K. Search / scrollback / palette — **ATK-BETTER + ADAPT**

Keep the typed action/entity registry as palette authority. Terminal
full-text search is a different surface (AO does this correctly). Persist a
bounded serialized screen in the run directory (atomic write — AO does not).

### L. `/lite` — **ADAPT the lesson, REJECT the product**

ATK is not a web collaboration app. Every workflow must work without Office
pixel-art composition (a11y, reduced motion, 1024×640, screen reader). That
is the `/lite` lesson.

---

## 7. Explicit rejections

**From Agent Office — do not copy:** 3D office, first-person walking,
elevators as navigation, rooftop bar, arcade, basketball, axe throwing,
cars, office dog, weather, day/night, avatar navigation, decorative
multiplayer, voice chat, screen sharing, gamification, their assets / maps /
characters / wording / branding. MIT license does not authorize a port.
Independent implementation only; attribute if any snippet is ever reused.

**From Munder — do not copy:** Michael / GOD / Dunder cast, floor/hive/hire
vocabulary, maroon/gold, Pixi floor as primary, auto-mode and telemetry on
by default, scheduled prompts that fire on first run.

**Architecture:** no TypeScript Worker; no god-agent as truth; no
motion-as-doctrine; no V-owned PTY on Windows (POSIX-only `modules/pty`).

---

## 8. Implications

### Backend (V) — later slices, after #1320/#1321 (both on `main`)

1. Session identity + `provider_session` + events.jsonl (notes 01–02).
2. `ProviderAdapter` table (discovery, launch, resume, hooks).
3. `AttentionItem` + events on the #1320 bus (`attention.*`).
4. Git read API on `serve`, then guarded write (worktree add/remove, commit,
   push) with preview + receipt (note 03).
5. Optional MCP ops surface that calls the same routes as Desktop.

### Electron main — after G1 commitment

Headless xterm mirror, serialize-on-attach, atomic scrollback in the run
dir, resize-owns-typist, scrubbed env. Detached host is G3 only.

### React — do not start from this research

Consume the typed hooks that landed in #1321. Office (Phase 4.2) is the
attention inspector the world opens — not the product home. It renders
today's sources honestly and consumes #1320 events; it does not invent
`AttentionItem` or NPCs. Render V attention/session facets when they exist.
No derived "quiet". Compact destinations must work without Office decor.
Visual authority is now [DESIGN.md](DESIGN.md) and ADR-035 (Cozy Pixel World);
this research snapshot's earlier visual guidance is superseded.

### Testing (durability modes separately)

Renderer reload; BrowserWindow recreate; `serve` restart; renderer crash;
main crash; intentional quit; unexpected death; reboot. Never one test
named "sessions survive restart". Plus path-containment, worktree delete
guards, hook allowlists, Paper+Ink+1024 captures.

### Migration

Does **not** block remaining Desktop PRs (#1322). Informs the *next* backend/frontend slices.
Native #1227 "DONE" rows stay historically true of gg/sokol and are **not**
Electron acceptance.

---

## 9. Issue mapping

| Tracker | Action |
| --- | --- |
| #1227 | Comment + body note: Electron/ADR-033 Proposed; AO as second reference; refine god-agent wording; re-state OPEN items with evidence. No silent close. |
| #1118 | Comment: visual authority unchanged; Electron is presentation, not a new look; do not copy AO/Munder art. |
| #1073 SessionBackend | Still the optional native-PTY eval; Electron durability is G1–G3 here, not a rewrite of #1073. |
| New issues | **None created.** Dependency chain lives in this doc. First *future* issue, if filed: session identity contract (not "durable sessions"). |

Proposed later chain (not filed): session identity → provider adapter →
session metadata → G1 mirror → G2 resume → crash acceptance → UI recovery;
then git write; then scoped agent ops; then services; then multi-repo.

---

## 10. Fifteen answers

1. **Formal multi-provider adapter?** Yes, in V, data-driven. Stop spreading
   provider behavior across target / swarm / run / discovery.
2. **Canonical entity?** Composition: **Agent** (catalog) + **Run** (unit of
   work) + **Session** (provider process/conversation) + **Job** (one CLI
   invocation). Not Worker.
3. **Detached PTY host in Electron?** Applicable as **G3 opt-in**, not
   default. Offer G1 (main-owned PTY + mirror) now. Never claim more.
4. **PTYs survive `serve` restart with V as authority?** Yes, if main owns
   the PTY and V owns the session record. V must not own the bytes.
5. **Who owns terminal/session?** V owns identity/status/resume. Electron
   main owns PTY bytes. A separate supervisor is G3 only. V `serve` must
   not become the PTY daemon.
6. **Provider session ids?**
   `provider_session { provider, id, captured_from, captured_at, verified }`
   on the V Session. Resume only when id + adapter resume exist.
7. **Git write now?** No Desktop exposure until V git read is real, then
   guarded writes. Native checkout stays omitted for the right reason.
8. **Multi-repo?** Valuable later; unnecessary scope for the Electron
   migration. One harness/workspace first.
9. **Agent-to-agent compatible with rejecting god-agent?** Yes, if it is a
   thin MCP/HTTP face over Engine ops. The god-agent rejection stands.
10. **Engine-backed MCP ops?** Improves ATK only if it is the same API the
    Desktop uses. Otherwise it duplicates CLI/API and will drift. Later.
11. **Run/session facets?** Yes, first-class: changes, worktree, terminal,
    approvals, artifacts, provider/model, recovery state. Services and PR
    when attributed/receipted. Not all required on day one.
12. **Service discovery shippable?** Not yet. Ship only proven pid/env
    attribution; cwd match is a hint.
13. **AO superior to Munder?** Durable PTY host, provider resume adapters,
    worktree write lifecycle, `office-workers` MCP (scoped), oldest-wait
    `N`, service attribution attempt, `/lite` operational fallback,
    multi-repo related PRs.
14. **AO decisions to reject?** 3D/game/brand; god-like central planner
    (AO does not have Munder's Michael — keep rejecting that anyway);
    non-atomic persist; flattening attention; non-draft PRs; Windows host
    absence presented as fine; Haiku task-card summaries as default.
15. **What changes in #1227?** Record Electron + ADR-033 Proposed; mark
    gg/sokol wording stale; add AO as evidence; keep Sims/visual rejection;
    refine god-agent rejection; move provider/model from "intentionally
    absent" to BACKEND; keep git write / PTY durability OPEN with G1–G3
    and V-first git; do not close the tracker.

---

## 11. Report A–J (for the parent track)

**A. Current ATK.** Electron+React over `serve` on `main` (`ada41cfc`,
#1320 after #1321 `a25496ad`). ADR-033 Proposed. Native parity slices are
not Electron truth. Session entity missing. Git Engine stubs. Electron
Office attention is still a client derivation. #1322 is the only
in-flight Desktop PR this research must not derail.

**B. Agent Office.** Floor = repo; worker = persisted runtime; detached PTY
host; provider adapters including ACP; worktrees/PRs/queue/MCP. Strongest:
durability split, adapters, worktree lifecycle, scoped tools, `N`. Weak:
Node as domain, flat attention, 3D identity.

**C. Munder vs AO.** Munder = IA/product chrome/memory/IDE. AO = live
session runtime. Overlap on hire/terminal/worktree/attention. Different
entities (god vs worker) and surfaces (Command Center vs 3D+`/lite`).

**D. Matrix.** SOLVED/ATK-BETTER: supervised backend, honest empty states,
typed-registry direction, no telemetry/auto-mode. ADAPT: adapters,
sessions, G1 PTY, attention kinds, worktree *design*, scoped MCP.
BACKEND: session, git write, approvals. LATER: multi-repo, services, PRs.
REJECT: god-agent, 3D/game/brand, TS Worker.

**E. Recommendations.** V: session + adapter + attention + git. Main: G1
mirror. React: render only. MCP: same ops as HTTP, later. No V PTY daemon.

**F. Roadmap.** Update #1227/#1118 only. No new issues. Order: session
identity → adapter → G1 → git read/write → scoped ops.

**G. Impact on current work.** Nothing in this doc blocks #1322. Backend
owner: leave room on the landed #1320 bus for `attention.*` / `session.*`.
Frontend owner: do not build a Worker model; keep compact destinations
independent of Office decor. Palette is chrome, not the typed registry.

**H. Security.** ATK wins: contained paths, first-party gate, no hook
listener port (file jsonl sink), scrubbed env, isolated hook config, no
Desktop rewrite of user Claude settings, confirm on git destroy, no
approval bypass via MCP. AO loopback+token is a pattern, not a free pass.
Cwd-based service ownership is not fact.

**I. Test plan.** Separate durability failures; V schema parity; Electron
E2E already in #1321; git fixtures; hook allowlist; no V builds in this PR.

**J. Next actions.** Merge this docs PR. Comment #1227/#1118 with the
refreshed SHAs. First implementation slice after that: V session identity
(not G3).

---

## Appendix A — Do not copy (vocabulary, brand, defaults)

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
  scheduled prompts that fire immediately after onboarding.

Agent Office brand/game surfaces are equally off-limits (section 7).

Agent Toolkit's current Cozy Pixel World language is defined in [DESIGN.md](DESIGN.md):
workspace, agent, run, job, loop, swarm, task, approval, receipt.

---

## Appendix B — Capture recipe (reusable)

Preserved from the 2026-09-29 Electron/Munder live ledger (#1317).
#1321 later added a context bar that seeds workspace from the #1314 harness;
the 2026-09-29 workflow tables stay in git history of this file (pre-rewrite).

What worked on Linux/Hyprland (Wayland) with no Xvfb installed:

1. Build: `pnpm install` at repo root. If `node_modules/.pnpm/electron@*/node_modules/electron/dist` is missing (pnpm reused the store and skipped postinstall), run `node install.js` in that package. Then `pnpm --filter agent-toolkit-desktop build:all`.
2. Launch detached and **unset `ELECTRON_RUN_AS_NODE`** (Cursor terminals export it; Electron then runs as plain Node and `app` is undefined):
   `env -u ELECTRON_RUN_AS_NODE PATH="<dir with agent-toolkit>:$PATH" setsid -f electron apps/desktop --remote-debugging-port=9333 --user-data-dir=/tmp/<profile>`.
   `setsid -f` matters: without it the app dies when the launching shell exits.
3. Drive and capture through CDP on `127.0.0.1:9333`: `Runtime.evaluate` (set `location.hash`, click buttons), `Input.insertText` / `Input.dispatchKeyEvent` for xterm typing, `Emulation.setDeviceMetricsOverride` for a fixed 1440×900 or 1024×640 viewport, `Page.captureScreenshot` for PNGs. Works while the window is tiled on another workspace.
4. Backend: the supervisor probes `ATK_BACKEND_BIN` → bundled → staged → PATH (version pin + `serve` capability). Put a gate-capable build first on `PATH` for dev; for packaged runs set `ATK_BACKEND_BIN=<binary>` before `pnpm dist:dir` (no V build needed if a binary exists). A stale PATH binary is `failed`/`binary-rejected` (path, version, reason), not "crashed".
5. Stop by exact PID of the Electron main process (`SIGTERM`); the supervisor stops its `serve` child. Verify no `agent-toolkit serve --host 127.0.0.1` remains.

Screenshots from that baseline live in [`assets/electron/baseline/`](assets/electron/baseline/).
Munder screenshots were reviewed but are intentionally **not** committed.

The detailed 2026-09-29 per-destination UX critique (Office quiet-after-fail,
truncated job ids, raw CLI Library/Insights, missing `xterm.css`) remains
valid as the Electron baseline at `d4ff3731` and is in git history of this
file before this revision. #1321 remediates chrome/typed data on `main`;
domain gaps in the matrix remain.

## Appendix C — Evidence log

- 2026-09-30 — Harness switch + honest backend binary resolution on `feat/desktop-harness-switch` (Settings picker / MRU / restart; env > persisted > `~/.ai-workspace` > fallback; terminals default cwd = resolved harness; `ATK_BACKEND_BIN` → bundled → PATH with version pin). Live Electron (CDP 9333, no V rebuild): `harnessSet` restarted serve into a user harness; PATH `/usr/bin/agent-toolkit` 1.16.0 reported `failed`/`binary-rejected` ("too old", not crashed); installed 1.35.0 reported `desktop-gate-missing`. Evidence: [settings-harness-switch.png](assets/electron/settings-harness-switch.png), [settings-harness-switched.png](assets/electron/settings-harness-switched.png), [settings-backend-too-old.png](assets/electron/settings-backend-too-old.png), [settings-backend-rejected.png](assets/electron/settings-backend-rejected.png), [office-harness-switch.png](assets/electron/office-harness-switch.png), [office-backend-too-old.png](assets/electron/office-backend-too-old.png), [terminal-harness-cwd.png](assets/electron/terminal-harness-cwd.png).
- 2026-09-29 — Live baseline: ATK dev Electron + packaged `dist:dir` at `d4ff3731`; Munder `5756722e` run locally (onboarding, Command Center tabs, add-agent, IDE, settings). Munder terminal crash recovery not exercised (source-read only).
- 2026-09-30 — Three-way decision artifact. ATK reconstructed from GitHub `origin/main` `ada41cfc` (#1320 after #1321 `a25496ad`). Agent Office `f88a31f` (v0.1.174+2) studied from source; #198 is pointer-lock settle only (capability unchanged since `13c104eb`). Local AO server probed earlier (302 login, no floors, no paid agent). Munder capability refresh: `origin/main` `ed06e3e` is SEO-only vs `5756722e`. #1321 context-bar / palette / dock folded in from `main`.
- 2026-09-30 — Phase 4.1 first-run on Electron: confirm-create `~/.ai-workspace`, honest EmptyState when CLI discovery / agent-model APIs are untyped, live `version` job. Captures in [`assets/electron/onboarding/`](assets/electron/onboarding/).
