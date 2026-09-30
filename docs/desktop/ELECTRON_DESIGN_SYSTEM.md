# Electron design system

The single design system for the Electron Desktop (`apps/desktop`). Every
destination is built from these tokens, primitives and hooks; a new screen
should not need new CSS beyond its own layout. The visual direction and the
reasons behind it live in [DESIGN.md](DESIGN.md); this document is the
working reference for implementing it in React.

![Office, Paper, 1920x1080](assets/electron/foundations/paper-1920x1080-office.png)

## Principles

- **Editorial, not SaaS.** Warm paper, ink rules, manila folders for the
  panels that ask for attention, brass for focus and the current selection.
  No gradients, glass, emoji or illustration.
- **Truth over polish.** Every value on screen comes from the backend or the
  Electron supervisor. When the backend says `ok: false`, the view shows that
  output and says it failed. Nothing is invented to fill an empty state.
- **Keyboard first.** Every action is a real `<button>` or link, dialogs are
  native `<dialog>` with focus placed and restored, and focus is always
  visible as a brass ring.
- **Motion is optional.** Transitions are short and only communicate state.
  `prefers-reduced-motion` and the Settings "Reduced" choice both turn them
  off, including the pulsing live dot.

## Layers

| Folder | Holds | May import |
|---|---|---|
| `src/lib/` | Transport, envelopes, query keys, SSE bridge, formatting. No React. | nothing above it |
| `src/data/` | React hooks over TanStack Query and the Electron bridge. | `lib` |
| `src/ui/` | Presentational primitives. No data fetching. | `lib` types only |
| `src/shell/` | App frame: router, context bar, command palette, terminal dock, live indicator, error boundaries. | all of the above |
| `src/features/` | One folder per destination; composition only. World owns semantic projection + theme resolution + renderer chrome. | all of the above |
| `src/features/world/model/` | Pure semantic world model + deterministic layout (no React, no sprites as truth). | `lib` |
| `src/features/world/theme/` | Theme packs keyed by semantic ids ([SEMANTIC_WORLD.md](SEMANTIC_WORLD.md)). | nothing above model |

Domain logic stays in the V backend. The renderer maps envelopes to UI and
never interprets command semantics beyond what the envelope's `ok` and `data`
fields say. Spatial presentation follows
[SEMANTIC_WORLD.md](SEMANTIC_WORLD.md) / [ADR-034](../adrs/ADR-034-semantic-world.md):
world home, inspectors for work, characters only from proven runtime rows.

## Tokens

All tokens are CSS custom properties in `src/design/tokens.css`, in two tiers.

- **Primitives** (`--pc-*`) are named colours: cream, manila, bone, ink, char,
  brass, sage, rust, teal and the terminal set. Components never use them
  directly.
- **Semantic tokens** are what components use, and they are re-pointed per
  theme:
  - surfaces: `--surface-canvas`, `-panel`, `-sunken`, `-manila`, `-chrome`, `-terminal`, …
  - text: `--text-primary`, `-secondary`, `-muted`, `-link`, `-on-chrome`, `-terminal`, …
  - borders: `--border-subtle`, `-default`, `-strong`, `-chrome`, `-terminal`
  - actions: `--action-{primary,secondary,danger}-{bg,bg-hover,fg}`
  - status: `--status-{ok,warn,err,info,idle}-{fg,bg}`
  - accent and focus: `--accent-brass*`, `--focus-ring`, `--focus-halo`

**Themes.** `:root[data-theme='paper']` is the default (warm light) and
`:root[data-theme='ink']` is the deliberate dark. "System" resolves to one of
the two from `prefers-color-scheme`. `src/design/theme.ts` owns the
preference:

- `initAppearance()` applies it before the first paint;
- `setThemePreference()` and `setMotionPreference()` change it;
- `useAppearance()` reads it.

The sidebar chrome is dark in both themes, so the frame stays put while the
page changes.

**Scale.**

- Spacing: `--space-0-5` … `--space-12`, on a 4px base.
- Radii: `--radius-sm|md|lg`.
- Row and target sizes: `--row-height` (36px) and `--target-min` (32px, above the WCAG 2.2 minimum of 24px).
- Content width: `--page-max`, 100rem (1600px), centered in the content area.

## Typography

Fonts are bundled through `@fontsource` (OFL) and imported once in
`src/design/fonts.ts`; nothing is fetched at runtime.

| Role | Family | Token |
|---|---|---|
| Destination and panel titles, rare editorial moments | Fraunces Variable (optical size axis) | `--font-display` |
| UI and body | IBM Plex Sans 400/500/600 | `--font-body` |
| Commands, paths, IDs, logs, terminal | IBM Plex Mono 400/500 | `--font-mono` |

The type scale runs from `--text-2xs` (11px, eyebrows and table headers) to
`--text-3xl` (36px). Eyebrows and table headers use uppercase with
`--tracking-caps`. Body copy is capped at 62ch.

## Primitives

Everything is exported from `src/ui/index.ts`.

| Primitive | Use |
|---|---|
| `PageHeader({ eyebrow, title, lede?, actions? })` | One per destination. The `<h1>` is the destination's answer, and the eyebrow is its name. |
| `Panel({ title, meta?, actions?, tone?: 'paper' \| 'manila', headingLevel? })` | A `<section>` region labelled by its heading. `manila` is reserved for "needs you" content: attention items, doctor, session context. |
| `Stack`, `Grid` | Vertical rhythm, and an auto-fit grid with columns at least 24rem wide that drops to one column when narrower. |
| `Table` | Editorial table with ink-ruled headers. Use `<th scope="row">` for the row's identity, and add `data-align="end"` for numbers. |
| `KeyValue({ items })` | Label/value definition list; `mono` per item for paths and IDs. |
| `StatusBadge({ tone, label, live? })` | The shape carries meaning as well as colour: square for failure, dot for ok. `live` pulses unless motion is reduced. |
| `Button({ variant, size, busy, busyLabel })` | Variants are `primary` (one per view), `secondary`, `ghost` and `danger`. `busy` disables it and swaps in the label. |
| `ButtonRow`, `Kbd`, `Mono`, `VisuallyHidden` | Small helpers. |
| `Field({ label, hint?, error? }, render)` | Render prop that hands the control its `id` and ARIA wiring. |
| `TextInput`, `Select`, `FormRow` | Form controls; `TextInput mono` for commands and paths. |
| `Report({ text, label })` | Pre-formatted CLI output, scrollable. |
| `LoadingState`, `EmptyState`, `ErrorState({ error, onRetry })` | `ErrorState` shows the message plus a recovery hint from `recoveryHint(error)`. |
| `Dialog({ open, onClose, title, description?, footer, initialFocus?, size? })` | Native `showModal()`. Escape closes it and focus returns to the trigger; a backdrop click does not close it. |
| `ConfirmAction({ label, title, description, confirmLabel, onConfirm, variant?, triggerVariant?, busy? })` | Every destructive or machine-changing command goes through this. Cancel is focused first. |
| `ReceiptsProvider`, `useReceipts()`, `useActionReceipt(title)` | Receipts are the toasts that confirm an action. Pass `useActionReceipt(...)` as a mutation's callbacks. Success receipts auto-dismiss after 6 seconds; errors and warnings stay until dismissed. Hover or focus holds a receipt. |
| `QueryView({ query, loading, errorTitle }, render)` | Renders loading, error, or data for one query, so views never branch on query state by hand. |
| `CommandReport({ envelope, label, failureLabel?, hideFields? })` | A command envelope: its text output plus its scalar `data` fields. |
| `DestinationBoundary({ name })` | Per-route error boundary in the shell. It resets on navigation. |

### First run

Electron only, until `localStorage['atk.desktop.onboarding.complete']` is set
(Settings and the command palette can replay it). First-run is a Paper Co.
welcome desk (paper / manila / sage, pixel tools, no numbered wizard, no
invented agents), then the path into the world: backend ready →
`window.atk.harnessChoose` / confirm then `harnessSet(default, { create: true })`
/ `harnessReset` (never mkdir `~/.ai-workspace` without confirm). Desktop
never invents tool INSTALLED badges. Replay is `session:replay-onboarding`.
Home after setup is `/world` (semantic world from #1335).

### Shell contracts later destinations must use

Do not invent a second session scope, toast, dialog, or terminal host. Destination PRs compose these:

| Contract | Where | Rule |
|---|---|---|
| Session context | `useSessionContext()` / `withContext()` | `workspace`, `agent` and `run` live in the URL. Seed workspace from `backend.harness` (the #1314 `backend-status` IPC). Every in-app link uses `href(path, extra)` so navigation never drops scope. |
| Command palette | Ctrl/Cmd+K, `src/shell/CommandPalette.tsx` | Add a `PALETTE_COMMANDS` entry for new global actions. Do not bind a second Ctrl+K. |
| Dialog / confirm | `Dialog`, `ConfirmAction` | Native `<dialog>`. No custom modal stacks. |
| Toasts | `useActionReceipt` / `useReceipts` | Receipts are the only toast surface. |
| Terminal | `useTerminalSessions` + the dock | xterm instances mount in `TerminalHost` only. A destination may create/attach a session; it must not construct its own `Terminal`. The world focuses a real session with `href('/terminal', { pty })` or agent/run/cwd identity — never a fake PTY. |
| Query / live | `qk`, `useSubQuery` / `useJobs`, `useLiveStatus` | Keys come from the factory. SSE writes go through `applyLiveEvent`. |
| Visual | tokens + `src/ui` | Paper/Ink/System via `theme.ts`. Fraunces + IBM Plex via `@fontsource`. No new typefaces. |

### Vocabulary

Use the same words the CLI uses (`job`, `completed`, `failed`, `workspace`,
`persona`, `profile`), and write the rest in plain sentences: "No work is
running.", "Could not list personas". Status labels stay lowercase because
they are the backend's status words. Buttons are verbs ("Start job", "Apply
fixes"), and confirmation buttons repeat the verb ("Uninstall").

Operations is the **workshop inspector** — a Paper Co. operations board the
world opens (`job=` / `loop=` / `swarm=`). Paper job table, manila doctor,
brass on the selected row. Do not invent NPCs, progress bars, or dashboard
metrics the backend did not return.

## Data hooks

| Hook | Contract |
|---|---|
| `useBackend()` | `{ backend, backendUrl, client, restartBackend }` from the Electron supervisor. When the URL changes, every query is invalidated. |
| `useHealth()`, `useSelfcheck()`, `useHelp({ enabled })` | Backend meta. Health polls every 10 seconds. |
| `useReport(kind)` | GET report endpoints (doctor, insights, inventory, matrix, diff). A report with `ok: false` is data, not an error. |
| `useSubQuery(family, sub, body?, { enabled, staleTime, failureIsData })` | POST `/api/v1/<family>/<sub>`. `ok: false` throws `ApiError('command')` unless `failureIsData` is set, which is for checks whose failure *is* the answer (validate, plugin check). |
| `useSubMutation(family, sub, { invalidates })`, `useOperation(kind)` | Mutations with explicit invalidation. `OPERATION_EFFECTS` in `lib/query/invalidation.ts` lists which domains each operation touches. |
| `useJobs()`, `useJob(id)`, `useJobLog(id)`, `useJobLiveLines(id)` | Jobs are polled every 5 seconds. Live lines come from the SSE bridge. |
| `useCreateJob()`, `useCancelJob()`, `useDeleteJob()` | These update the cache directly and then invalidate. |
| `useLiveStatus()` | `{ connection: 'connecting' \| 'online' \| 'offline', streams, lastHealthyAt }`. |

Query keys come only from the `qk` factory in `lib/query/keys.ts`. Mutations
invalidate by domain (`qk.domain(...)`), never by hand-written arrays.

### Live bridge

`JobStreamManager` (`lib/live/jobStreams.ts`) keeps one `EventSource` per
active job:

- it reconnects with jittered exponential backoff (1s base, 30s cap);
- it pauses entirely while the backend is offline;
- it reports `idle | connecting | live | reconnecting | offline`.

`applyLiveEvent` writes stream events into the Query cache, keeping the last
500 lines. On `done` it sets the final status and invalidates the list and the
log. `EventBusManager` consumes `GET /api/v1/events` and `applyBusEvent`
invalidates jobs/loops/swarms/doctor (or patches a known job status) without
inventing records. Per-job streams remain the log source. If the bus never
opens, Office polls jobs every 5 seconds and says the list may be stale.

The shell's `LiveIndicator` turns backend state plus live status into one
label ("Connected", "Live", "Reconnecting", "Offline", "Backend down").
`StaleNotice` tells the user when the screen shows last-known data.

## Patterns

- **Needs-you first.** Office lists failures and warnings before anything
  running, each with a link to the exact item (`/operations?job=<id>`).
  The palette command "Next that needs me" cycles crash/mismatch → failed
  jobs → running jobs. Completed-needing-review is omitted until the
  backend can distinguish it (approvals / review flags).
- **Selection lives in the URL.** List and detail views keep the selection in
  search params, so reloads, links and the back button work. Session scope
  (`workspace`, `agent`, `run`) is the same contract: the context bar writes
  it, destinations only read and preserve it.
- **Command palette is the shortcut map.** Ctrl/Cmd+K opens it; `?` opens the
  binding list. Destination-local shortcuts stay on those screens.
- **The terminal dock is the host.** Sessions stay mounted across navigation.
  Tabs show agent, run, cwd and process state. Terminal is a workstation
  place, not a second product home; `pty` in the URL focuses a real session.
- **Offline disables and explains.** Actions that need the backend are
  disabled with a `title` that says why. They are never hidden.
- **Command preview.** Dialogs that run a command show the exact command line
  before running it.
- **Danger is separated.** Irreversible actions sit in their own "Remove"
  area and use the `danger` variant behind a `ConfirmAction`.

## Verification

`pnpm test:e2e` runs two Playwright projects:

- `renderer`: the React app under vite dev with no backend. It covers the
  shell, navigation and fallbacks.
- `electron`: the built app (`pnpm build:all`) launched through Playwright's
  Electron driver. It runs with the real V backend inside a throwaway HOME and
  a workspace scaffolded by `agent-toolkit workspace init`. It covers:
  - backend startup;
  - every destination rendering from live data;
  - a real job run end to end;
  - dialog focus handling;
  - theme persistence;
  - a real PTY session;
  - first-run happy path (existing `~/.ai-workspace`) and missing-harness
    confirm-create (`e2e/electron/onboarding.spec.ts`).

  Point it at a backend with `ATK_E2E_BACKEND_BIN`; CI uses the
  `dist/agent-toolkit` it builds. On Linux without a display, run it under
  `xvfb-run`.

`ATK_CAPTURE=1 pnpm exec playwright test --project=electron capture`
regenerates the screenshots below:

- every destination;
- Paper and Ink;
- 1024x640 (the minimum window) and 1920x1080.

The jobs and the terminal session they show are created through the UI
during the run.

| Destination | Paper | Ink |
|---|---|---|
| Office | ![](assets/electron/foundations/paper-1024x640-office.png) | ![](assets/electron/foundations/ink-1024x640-office.png) |
| Operations | ![](assets/electron/foundations/paper-1920x1080-operations.png) | ![](assets/electron/foundations/ink-1920x1080-operations.png) |
| Workspace | ![](assets/electron/foundations/paper-1920x1080-workspace.png) | ![](assets/electron/foundations/ink-1920x1080-workspace.png) |
| Library | ![](assets/electron/foundations/paper-1920x1080-library.png) | ![](assets/electron/foundations/ink-1920x1080-library.png) |
| Insights | ![](assets/electron/foundations/paper-1920x1080-insights.png) | ![](assets/electron/foundations/ink-1920x1080-insights.png) |
| Terminal | ![](assets/electron/foundations/paper-1920x1080-terminal.png) | ![](assets/electron/foundations/ink-1920x1080-terminal.png) |
| Settings | ![](assets/electron/foundations/paper-1024x640-settings.png) | ![](assets/electron/foundations/ink-1024x640-settings.png) |

All 28 captures are in `assets/electron/foundations/`, named
`<theme>-<width>x<height>-<destination>.png`.

First-run captures (Phase 4.1) live in `assets/electron/onboarding/`. Ready and
harness frames are in tree; World home is the #1335 semantic slice (`WorldView`).
Regenerate `03-world.png` with `ATK_CAPTURE=1`.

| Step | Existing harness | Missing harness |
|---|---|---|
| Welcome desk | ![](assets/electron/onboarding/01-ready.png) | (same step) |
| The folder | ![](assets/electron/onboarding/02-harness-existing.png) | ![](assets/electron/onboarding/fallback-01-missing.png) |
| Confirm create | — | ![](assets/electron/onboarding/fallback-02-confirm.png) |
| After create | — | ![](assets/electron/onboarding/fallback-03-created.png) |

## Known gaps

- `GET /api/v1/jobs` is documented and the Desktop client uses the GET
  operation. Job `retry_of` and `POST /api/v1/jobs/{id}/retry` are wired.
- Most sub-command responses are text envelopes, so views render CLI output
  verbatim. Structured panels (project lists, persona tables) wait for JSON
  fields in the contract.
- Office agent/run rows wait on typed agents and runs (Phase 2 PR C / E).
  Rows today show only real job fields (`cmd`, `status`, `workspace`,
  times, `exit_code`) and link through `href()`.
- Human approvals and "completed needing review" wait on typed approvals
  (Phase 2 PR E). The palette cycle has the slot; it stays empty rather
  than inventing a queue.
- In a fresh install (no toolkit checkout), `plugin check` and `mcp list`
  report "Cannot locate toolkit directory". The views show that failure as
  it is.
- A workspace from `workspace init` fails its own `workspace validate`
  because `knowledge/processes/` is not created.
- The skills catalog is truncated server-side, sometimes mid-character.
