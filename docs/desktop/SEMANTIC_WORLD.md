# Semantic World — Desktop spatial product contract

**Status: CURRENT CONTRACT** (2026-09-30) — primary product goal for Agent
Toolkit Desktop spatial UX. Governing ADR:
[ADR-034](../adrs/ADR-034-semantic-world.md). Complements
[DESIGN.md](DESIGN.md), [UX_ARCHITECTURE.md](UX_ARCHITECTURE.md),
[ELECTRON_DESIGN_SYSTEM.md](ELECTRON_DESIGN_SYSTEM.md), and
[WORKSTATION_REFERENCE_ANALYSIS.md](WORKSTATION_REFERENCE_ANALYSIS.md).

English is authoritative.

## 0. One-sentence product goal

> A calm, cozy top-down **semantic world** that *explains* Agent Toolkit
> (workspace, projects, knowledge, memory, tools, agents, jobs) while Paper Co.
> **inspectors** stay the professional way to act fast.

The world is the home. The palette, keyboard, terminal dock, and destination
inspectors remain mandatory productivity rails. This is not pixel-art SaaS and
not "game before tool".

## 1. Decision audit (KEEP / EVOLVE / REPLACE / REMOVE)

| Decision | Verdict | Notes |
|---|---|---|
| Paper Co. palette, materials, Fraunces / IBM Plex | **KEEP** | Inspectors, chrome, tables, terminal stay Paper Co. |
| Design hierarchy Clarity → Control → Feedback → Discoverability → Personality → Delight | **KEEP** | Personality never outranks truth or input focus |
| Operational truth before animation; empty is valid | **KEEP** | Ambient *environment* motion OK; system activity only from real state |
| No fake gamification / XP / invented metrics | **KEEP** | Already binding in DESIGN.md and WORLD_VIEW.md |
| Command palette, keyboard, terminal dock, conventional controls | **KEEP** | Click must not require a 30s walk |
| Accessibility, reduced motion, non-color status | **KEEP** | Every spatial entity has a structured list fallback |
| V = domain truth; React maps envelopes (ADR-033) | **KEEP** | Semantic model is a *projection*, not a second backend |
| Canonical entities `Agent + Run + Session + Job` | **KEEP** | Do not invent a TypeScript `Worker` |
| Concept images in `assets/design/` | **KEEP (directional)** | Aesthetic only; never copy mock data or IA blindly |
| Office as default home / flagship spatial surface | **REPLACE** | World (`/world`) is default home; Office becomes attention inspector |
| Floor Map / Workshop zones as decorative side view | **EVOLVE** | Become the semantic world model + layout |
| Pixel art as sticker decoration on dashboards | **REPLACE** | Pixel art is the world material system via theme packs |
| Hardcoded asset filenames in features (`cottage-blue.png`) | **REMOVE** | Features resolve **semantic theme keys** only |
| Fake NPCs / ambient agent walking without backend proof | **REMOVE** | No agent → no character; no fake activity |
| Phaser / Pixi / full game shell for v1 | **REMOVE (defer)** | Hybrid DOM tile/sprite inside Electron shell; engine optional later |
| Native gg World View as production spatial authority | **REPLACE** | Electron hybrid world; native retained as historical reference |
| Cyberpunk / space / alternate themes now | **REMOVE (defer)** | One excellent cozy top-down default; architecture allows more later |
| Forcing Office Floor metaphor onto every workflow | **REMOVE** | World explains structure; inspectors own dense work |
| Historical Workshop vector-sprite vocabulary as visual authority | **REMOVE** | WORLD_VIEW.md motion/truth contracts remain binding |

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
| Project (symlink under `projects/`) | Building / cottage | A development repo you enter to work | Enter project space; open Workspace | ok / broken / empty roster | List: project name + link status | `project.building` |
| Project knowledge / memory files scoped to a project | Project shelf / ledger | Project-local durable notes | Open memory read / Workspace | present / empty / unavailable | List: memory entries for project | `knowledge.project` |
| Memory entry (typed memory API) | Document / ledger page | Durable knowledge file with provenance | Open memory inspector | listed / readable / archived | List: id, kind, title | `memory.entry` |
| Memory search / hits | Card index | Retrieval without inventing results | Open search / hits | hits / no hits / unavailable | List of hits | `memory.index` |
| Terminal / PTY session | Terminal workstation | Direct agent/shell work | Open Terminal destination / dock | idle / attached / exited | List: session ids | `tool.terminal` |
| Coding tool (detected CLI) | Tool rack slot | Real PATH/config discovery | Open Settings / Library tools | detected / configured / verified / unknown enablement | List: ToolInfo fields | `tool.coding` |
| MCP / pack capability (catalog) | Library shelf | Installable capability, not runtime | Open Library | installed / catalog-only / unavailable | Library list | `capability.shelf` |
| Catalog Agent (`agents/*/AGENT.md`) | Desk plate / nameplate | Definition exists; not a living character | Open Library agent | catalog | List: AgentInfo | `agent.catalog` |
| Job (serve jobs registry) | Working character / task figure | Proven runtime work | Hover tooltip; click → Operations job | queued / running / terminal statuses / unknown verbatim | List: job id, cmd, status | `agent.working` / `agent.blocked` / `agent.idle`* |
| Swarm run | Meeting table / handoff tray | Multi-agent coordination evidence | Open Operations swarms | present / empty / unavailable | List: run ids when API provides them | `swarm.table` |
| Loop | Calendar / clock object | Scheduled or invoked loop evidence | Open Operations loops | started / finished via events | List: loop subject from events | `loop.clock` |
| Install / update operation | Crate / delivery | Real install lifecycle events | Open Library / Insights | started / finished | List: install events | `ops.crate` |
| Attention (failed jobs, self-check, backend down) | Red stamp / inbox | Needs a human | Open Office attention inspector | items / none | Office "Needs you" table | `attention.inbox` |
| Backend live stream | Workshop lamp | Connection health | Status in chrome | live / reconnecting / offline / stale | Live indicator text | `ops.lamp` |

\* `agent.idle` is used only when a runtime row exists in an idle-compatible
status, or as the theme key for a catalog nameplate that is *not* animated.
Never spawn a walking character for an idle catalog agent alone.

### Character rule

| Condition | World representation |
|---|---|
| No job / run / session evidence | **No character** |
| Job queued or running | Character with `agent.working` (or blocked if status/evidence says waiting on human) |
| Job failed / rejected (recent) | Character or stamp with blocked/attention — also listed in Office |
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

Default theme id: `cozy-topdown` (Paper Co. cozy workshop / project-houses world).

**Visual language** (from [assets/design/](assets/design/) concept boards — aesthetic only):

- Paper Cream / Manila / Sage / Dusty Teal / Rust / Brass / Ink hexes from DESIGN.md;
- cozy top-down readable furniture (desk, bookshelf, terminal, plants);
- serif product moments + warm editorial chrome; dark terminal dock;
- small Hornero bird as a restrained accent — not a mascot crowd;
- Library place reads as a bookshelf annex; Operations opens the workshop inspector;
- **Home is a world of project houses + shared library**, not a single Office Floor
  dashboard. Pixel rooms are **interiors you enter**, not the whole product.

**Do not take from the boards:** fake counts ("6 agents online", "12.4K installs",
"62% progress"), decorative NPCs, card-dashboard home, marketplace popularity.

### Rules

1. Feature code references **semantic keys** only (column "Theme key" above).
2. A theme pack is a JSON/TS module:
   `{ id, label, tileSize, assets: Record<SemanticKey, AssetRef>, labels?: … }`.
3. `AssetRef` may be `{ kind: 'sprite', src, frame? }` or
   `{ kind: ' procedural', fill, stroke }` for the default pack's minimal
   originals. Missing keys fall back to a labeled placeholder glyph — never
   silently borrow another product's art.
4. Alternate themes (cyberpunk, space, …) are **extension points only**. Do
   not ship them in this track.
5. Pixel rendering: nearest-neighbor, integer scale when possible, one light
   direction, original/licensed art only.

### Default pack obligations

- Small footprint (prefer simple SVG/PNG tiles under a few KB each).
- Distinguish at least: grounds, building, knowledge annex, terminal desk,
  working character, blocked/attention mark, empty slot.
- Critical state must include text/shape in the list fallback and tooltip, not
  only hue or motion.

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

## 11. Alignment for sibling feature agents

If you own Office, Onboarding, Operations, Terminal, Library, Insights, or
Settings:

- Treat **World as home**; your surface is an inspector/workstation.
- Reuse semantic keys when you add environmental chrome.
- Do not introduce Worker types, fake activity, or competing spatial homes.
- Prefer linking *into* your destination with session context (`href`) over
  duplicating domain fetches inside novel dashboards.
