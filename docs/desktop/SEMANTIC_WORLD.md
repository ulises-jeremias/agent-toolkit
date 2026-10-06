# Semantic World — Desktop spatial product contract

**Status: CURRENT CONTRACT** (2026-09-30) — primary product goal for Agent
Toolkit Desktop spatial UX. Governing ADRs:
[ADR-034](../adrs/ADR-034-semantic-world.md) (spatial pipeline) and
[ADR-035](../adrs/ADR-035-cozy-pixel-world.md) (visual language — Cozy Pixel
World). Complements [DESIGN.md](DESIGN.md), [UX_ARCHITECTURE.md](UX_ARCHITECTURE.md),
[ELECTRON_DESIGN_SYSTEM.md](ELECTRON_DESIGN_SYSTEM.md), and
[WORKSTATION_REFERENCE_ANALYSIS.md](WORKSTATION_REFERENCE_ANALYSIS.md).

English is authoritative.

## 0. One-sentence product goal

> A calm, cozy top-down **semantic pixel world** that *is* the screen and
> *explains* Agent Toolkit (workspace, projects, knowledge, memory, tools,
> agents, jobs) while game-menu **inspectors** stay the professional way to
> act fast.

The world is the home and visually dominates it. The palette, keyboard,
terminal dock, and destination inspectors remain mandatory productivity rails.
This is not pixel-art SaaS and not "game before tool".

## 1. Decision audit (KEEP / EVOLVE / REPLACE / REMOVE)

| Decision | Verdict | Notes |
|---|---|---|
| Paper Co. palette, materials, Fraunces / IBM Plex editorial type | **REMOVE (2026-09-30, ADR-035)** | Visual language deprecated; superseded by Cozy Pixel World (DESIGN.md). |
| Cozy Pixel World language (pixel world + game-menu panels) | **KEEP** | Single visual contract: world + inspectors share one art direction |
| Design hierarchy Clarity → Control → Feedback → Discoverability → Personality → Delight | **KEEP** | Personality never outranks truth or input focus |
| Operational truth before animation; empty is valid | **KEEP** | Ambient *environment* motion OK; system activity only from real state |
| No fake gamification / XP / invented metrics | **KEEP** | Binding in DESIGN.md and here |
| Command palette, keyboard, terminal dock, conventional controls | **KEEP** | Click must not require a 30s walk |
| Accessibility, reduced motion, non-color status | **KEEP** | Every spatial entity has a structured list fallback |
| V = domain truth; React maps envelopes (ADR-033) | **KEEP** | Semantic model is a *projection*, not a second backend |
| Canonical entities `Agent + Run + Session + Job` | **KEEP** | Do not invent a TypeScript `Worker` |
| Concept images in `assets/design/` (Paper Co. era) | **REMOVE (authority)** | Historical reference only — do not restore as visual goal |
| Office as default home / flagship spatial surface | **REPLACE** | World (`/world`) is default home; Office is the attention inspector |
| Floor Map / Workshop zones as decorative side view | **EVOLVE** | Became the semantic world model + layout |
| Pixel art as sticker decoration on dashboards | **REPLACE** | Pixel art is the world material system via theme packs |
| Hardcoded asset filenames in features (`cottage-blue.png`) | **REMOVE** | Features resolve **semantic theme keys** only |
| Fake NPCs / ambient agent walking without backend proof | **REMOVE** | No agent → no character; ambient life (birds, butterflies, fireflies, water) is environmental only |
| Phaser / Pixi / full game shell for v1 | **REMOVE (defer)** | Hybrid DOM tile/sprite + canvas terrain inside Electron shell; engine optional later |
| Native gg World View as production spatial authority | **REPLACE** | Electron hybrid world; native retained as historical reference |
| Cyberpunk / space / alternate themes now | **REMOVE (defer)** | One excellent cozy world; architecture allows more later |
| Forcing Office Floor metaphor onto every workflow | **REMOVE** | World explains structure; inspectors own dense work |
| Historical Workshop vector-sprite vocabulary as visual authority | **REMOVE** | Runtime truth and ambient motion rules are in this document and UX_ARCHITECTURE.md |

## 2. Pipeline (hard rule)

```
DOMAIN STATE  →  SEMANTIC WORLD MODEL  →  LAYOUT  →  THEME / ASSET PACK  →  RENDERER
     ↑ V serve + SSE              ↑ TS projection        ↑ deterministic     ↑ cozy pack     ↑ DOM tiles (+ React inspectors)
```

- **Domain state** comes from `agent-toolkit serve` (jobs, events, memory,
  agents catalog, tools, workspace/project envelopes, harness path).
- **Semantic model** names places/objects/characters with stable ids and
  concept kinds — never sprites.
- **Layout** is a pure function of structured state (1, 5, or 20 projects must
  not shuffle tomorrow). Prefer sorted ids + grid slots.
- **Theme pack** maps semantic keys → assets/colors/labels.
- **Renderer** paints; it is never the source of truth and must not delay jobs.

## 3. Semantic vocabulary

Every visible world thing is a row in this vocabulary. Extension points that
are not backed by a live API are **omitted** or shown as **Unavailable** — never
filled with fabricated contents.

| Domain concept | Metaphor | Why this metaphor | Primary interaction | States (truthful) | A11y fallback | Theme key |
|---|---|---|---|---|---|---|
| Active harness / workspace root | Workshop grounds / home lot | One managed environment organizing projects | Select → Workspace inspector | known / missing harness / notice | List: workspace path + harness source | `workspace.grounds` |
| Workspace knowledge (`knowledge/` or memory API with workspace scope) | Shared archive / library annex | Shared facts for every agent started here | Open → Workspace / memory | present / empty / unavailable | List: knowledge entry counts or "empty" | `knowledge.workspace` |
| Registered project | Distinct project house on the east-bank neighborhood | A development repo gets a stable place in the workspace valley | Click / Enter opens that project's interior; the overview board opens its project context | ok / broken / empty roster | World Index lists project name + link status | `project.building` |
| Project files | Filing cabinet / project desk | Files belong to the registered repository root, which may live outside the workspace | Open Workspace Files scoped to that project | listed / empty / unavailable / unsafe link skipped | List: relative path + project name | `files.project` |
| Project knowledge | Project study shelf | Project-scoped knowledge, only when a project knowledge API exists | Open project knowledge inspector | present / empty / unavailable | List: knowledge entry counts or unavailable | `knowledge.project` (reserved; omitted until backed by an API) |
| Memory entry (typed memory API) | Archive record card | Durable remembered context with provenance | Open memory inspector | listed / readable / archived | List: id, kind, title | `memory.entry` |
| Memory search / hits | Card index | Retrieval without inventing results | Open search / hits | hits / no hits / unavailable | List of hits | `memory.index` |
| Terminal / PTY session | Terminal workstation | Direct agent/shell work | Open Terminal destination / dock | idle / attached / exited | List: session ids | `tool.terminal` |
| Coding tool (detected CLI) | Tool rack slot | Real PATH/config discovery | Open Settings / Library tools | detected / configured / verified / unknown enablement | List: ToolInfo fields | `tool.coding` |
| MCP / pack capability (catalog) | Library shelf | Installable capability, not runtime | Open Library | installed / catalog-only / unavailable | Library list | `capability.shelf` |
| Catalog Agent (`agents/*/AGENT.md`) | Desk plate / nameplate | Definition exists; not a living character | Open Library agent | catalog | List: AgentInfo | `agent.catalog` |
| Configured Person | Roster profile and durable portrait | Reusable collaborator identity is separate from a process | Open People to inspect, edit, start, archive, or restore | configured offline / archived / session open | People roster and profile | `person.profile` |
| Live Person-bound local PTY | That Person's character at the project house / terminal | Only an actual open process creates world presence; saved identity survives exit | Hover for role/runner/model; click opens People session; Open Terminal reaches the bound PTY | session open / stopping until exit is confirmed | People profile with project and session details | `person.session` |
| Job (serve jobs registry) | Working character / task figure | Proven runtime work | Hover tooltip; click → Operations job | queued / running / terminal statuses / unknown verbatim | List: job id, cmd, status | `agent.working` / `agent.blocked` / `agent.idle`* |
| Swarm run | Meeting table / handoff tray | Multi-agent coordination evidence | Open Operations swarms | present / empty / unavailable | List: run ids when API provides them | `swarm.table` |
| Loop | Calendar / clock object | Scheduled or invoked loop evidence | Open Operations loops | started / finished via events | List: loop subject from events | `loop.clock` |
| Install / update operation | Crate / delivery | Real install lifecycle events | Open Library / Insights | started / finished | List: install events | `ops.crate` |
| Attention (failed jobs, self-check, backend down) | Signal board and status lantern | Needs a human | Open Attention inspector | items / none | Attention list with a text status | `attention.inbox` |
| Backend live stream | Workshop lamp | Connection health | Status in chrome | live / reconnecting / offline / stale | Live indicator text | `ops.lamp` |

\* `agent.idle` is used only when a runtime row exists in an idle-compatible
status, or as the theme key for a catalog nameplate that is *not* animated.
Never spawn a walking character for an idle catalog agent alone.

### Spatial navigation and direct actions

The `/world` map is a primary interface. Shared workspace services face the
commons; registered project houses occupy their own neighborhood across the
creek, joined by the bridge and paths. The empty-project marker opens the same
reviewed GUI project-link flow as Workspace. Clicking a landmark opens its
canonical destination; clicking a project house enters that project's
interior. Inside, the overview board opens project context, the filing cabinet
opens real files scoped to the registered root, the records cabinet opens
workspace memory, and the terminal desk opens the real PTY route. Library
capabilities, project knowledge, workspace knowledge, memory, and files remain
distinct concepts even where their visual materials relate.

Map objects expose semantic names and descriptions through their accessible
labels/tooltips, and the World Index provides a keyboard-friendly list fallback.
World state remains a projection of backend data: only real jobs/runs/sessions
can create runtime people; configured or catalog-only people stay off-map.
Camera fitting and deterministic placement adapt to the roster size; screenshots
for empty, one-project, and multi-project states are captured at compact and
large viewports in the project-link Electron E2E.

### Character rule

| Condition | World representation |
|---|---|
| No job / run / session evidence | **No character** |
| Job queued or running | Character with `agent.working` (or blocked if status/evidence says waiting on human) |
| Job failed / rejected (recent) | Runtime character with an explicit blocked/attention marker — also listed in Attention |
| Catalog agent only | Nameplate / desk object, not a character |

### Event mapping (`GET /api/v1/events`)

Map only kinds the backend emits today:

| Event `type` | World effect |
|---|---|
| `backend.ready` / `backend.resync` | Refresh domain snapshot; lamp ok |
| `job.created` / `job.updated` / `job.deleted` | Upsert/remove job character; never invent progress bars |
| `loop.started` / `loop.finished` | Update loop object state from `subject` / `status` |
| `swarm.changed` | Refresh swarm place if data available; else mark stale→refetch |
| `memory.changed` | Refresh knowledge/memory objects |
| `install.started` / `install.finished` | Update crate object |
| Anything else / missing | Show unknown/idle honestly — **do not** invent `agent.thinking` |

Job-scoped SSE (`GET /api/v1/jobs/{id}/events`) remains for Operations log
tails; the world prefers the global bus for presence.

## 4. Theme contract

Default theme pack id: `cozy-valley` (the Cozy Pixel World village).

**Visual language** (from [DESIGN.md](DESIGN.md) §5/§7 — executable tokens and
the asset generator are canonical):

- a lush daytime valley: layered grass greens, warm dirt roads, clear creek
  water (2-frame), forest edges, flowers, lamps and signs;
- roof-first readable buildings (terracotta, slate, teal, rust, moss, straw)
  with doors, windows, shadows and environmental integration;
- gently magical tech accents: glowing windows, cyan terminal light, warm
  lanterns, fireflies, tiny rune-like glows;
- the hornero bird as a restrained ambient signature near the hall;
- game-menu inspectors (deep framed panels, pixel display type) opened from
  places — the world and the menus share one art direction.

Historical Paper Co. concept boards are not visual authority (ADR-035).

**Do not take from any reference:** fake counts ("6 agents online", "12.4K
installs", "62% progress"), decorative NPCs, card-dashboard home, marketplace
popularity, copied game artwork.

### Rules

1. Feature code references **semantic keys** only (column "Theme key" above).
2. A theme pack is a TS module:
   `{ id, label, tileSize, assets: Record<SemanticKey, AssetRef>, decor, facades, labels? }`.
3. `AssetRef` is `{ kind: 'sprite', src, frame? }`; decor/terrain follow the
   same manifest. Missing keys fall back to a labeled placeholder glyph —
   never silently borrow another product's art. Procedural CSS tiles (`kind:
   'css'`) remain transitional for keys without authored sprites; the goal is
   authored art for every key.
4. Alternate themes (cyberpunk, space, …) are **extension points only**. Do
   not ship them in this track.
5. Pixel rendering: 16×16 source grid, integer scale (2×/3×/4×),
   nearest-neighbor, one light direction, original/licensed art only
   (DESIGN.md §7).

### Default pack obligations

- Original pixel assets generated by `apps/desktop/scripts/gen-world-assets.mjs`
  (repeatable, license-clean); imported art only with recorded license.
- Distinguish at least: grounds, building, knowledge annex, terminal desk,
  working character, blocked/attention mark, empty slot.
- Critical state includes text/shape in the list fallback and tooltip, not
  only hue or motion.
- Ambient decor (water, glows, critters) never encodes domain state.

## 5. Layout contract

- Input: sorted project ids, optional knowledge presence, job ids, stable
  workspace id.
- Output: integer grid positions `{ x, y, w, h }` in tile units.
- Determinism: same input → same positions across reloads and days.
- Density: 1 project ≠ huge empty void of fake buildings; 20 projects scroll
  or paginate — do not random-scatter.
- Entering a project changes **focus space** (filter/layout to that project's
  knowledge, memory, terminal links) without destroying the workspace model.

## 6. Navigation and inspectors

| User intent | Fast path |
|---|---|
| Go to world home | `/` → `/world`; palette "Go to World" |
| Inspect attention | `/office` (Needs you) |
| Control jobs | `/operations` (+ `?job=`) |
| Workspace / projects detail | `/workspace` |
| Capabilities | `/library` |
| Health / history | `/insights` |
| PTY | `/terminal` + dock |
| Config | `/settings` |

World tooltips show: **name**, **concept**, **state**, and the click action
(inspect). Clicks call existing routes via `href()` / palette commands — never
dead sprites.

Preserve the existing seven inspector destinations; World is the home
surface added as the eighth primary nav entry (first in order). Do not fight
parallel Office/Operations/Library/Terminal branches by rewriting them here.

## 7. Accessibility

- Parallel **structured list** (and optionally a table) enumerates every
  entity the renderer shows.
- Focusable rows/buttons for each entity; Enter activates the same navigation
  as click.
- Tooltips are supplementary; list has the same facts.
- `prefers-reduced-motion` and Settings "Reduced" disable non-essential
  ambient animation; state changes may still update instantly.
- Status uses text (and optionally shape), not color alone.

## 8. Performance

- No continuous `requestAnimationFrame` unless a measured animation is active
  and the document is visible.
- Pause ambient timers when `document.hidden`.
- Measure idle cost in development; world idle should be near-zero CPU when
  calm.
- Never block or throttle job execution, SSE ingest, or PTY I/O for animation.

## 9. What we will not fake

- NPCs without jobs/runs/sessions
- Busy animations without matching event/job status
- Rooms full of skills/metrics the API does not provide
- Copied game or competitor artwork
- A TypeScript Worker domain type
- Progress percentages not supplied by the backend
- "Thinking" states the event bus does not emit

## 10. Vertical slice acceptance

A working `/world` home that:

1. Builds grounds from the real harness/workspace.
2. Places project buildings from real `project list` (honest empty if none).
3. Shows shared knowledge only if memory/knowledge evidence exists; otherwise
   omits or shows empty.
4. Lets the user enter a project space and open knowledge / memory / terminal
   via real hrefs.
5. Spawns characters only for proven jobs (or omits them when none).
6. Hover tooltip + list fallback + click → existing inspectors.
7. Unit tests assert semantic entities from N projects + M jobs; plus one
   opened screenshot critique (not screenshot-only CI).

### Implemented on main (honest scope)

| Concept | Status |
|---|---|
| `/world` home + project interiors | **Implemented** |
| Project board → Workspace project context; filing cabinet → registered project files | **Implemented** (typed project-scoped file API; read-only, symlink-safe) |
| Project houses from roster | **Implemented** (CLI-text parser transitional) |
| Memory archive + per-entry tiles → memory-file inspector | **Implemented** |
| Library annex → `/library` | **Implemented** |
| Operations / settings / files commons places | **Implemented** |
| Job characters (queued/running/failed/rejected) | **Implemented** |
| Event bus presence (`job.*`, `memory.*`, `backend.*`) | **Implemented** |
| Swarm / loop / crate / lamp / catalog nameplate as dedicated places | **Theme-ready; Operations uses `ops.crate`, Settings uses `ops.lamp` as place chrome — no invented swarm/loop tiles** |
| Escape: detail → interior → grounds | **Implemented** |

## 11. Alignment for sibling feature agents

If you own Office, Onboarding, Operations, Terminal, Library, Insights, or
Settings:

- Treat **World as home**; your surface is an inspector/workstation.
- Reuse semantic keys when you add environmental chrome.
- Do not introduce Worker types, fake activity, or competing spatial homes.
- Prefer linking *into* your destination with session context (`href`) over
  duplicating domain fetches inside novel dashboards.
