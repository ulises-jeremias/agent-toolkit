# Desktop UX architecture

Status: **CURRENT CONTRACT** — intended interaction contract, 2026-09-05,
re-confirmed 2026-09-13 at `ecc4d67c`. Current implementation is
`cmd/agent-toolkit-desktop/main.v`, using gg/sokol. Historical
[ADR-032](../adrs/ADR-032-desktop-gui-framework.md) records the vlang/gui
Phase-0 feasibility decision and the retirement of its implementation
(`modules/agent_toolkit_gui/` removed 2026-09-13, #1206); production is
`gg`/`sokol`-direct. Preserve that history. This document does not approve
a rewrite.

## Shell and navigation

The active workspace and Search / Run are always discoverable. Electron Desktop
primary destinations (see [SEMANTIC_WORLD.md](SEMANTIC_WORLD.md),
[ADR-034](../adrs/ADR-034-semantic-world.md)):

| Destination | User question | Contents |
|---|---|---|
| **World** (default home) | Where am I in this toolkit, and what is real here? | Semantic places/objects/characters from domain state; list fallback; click → inspectors |
| Office | What needs attention now? | Failures, blocked work, self-check, backend; running work summary |
| Library | What can I use or add? | Skills, agents, products and packs with clear distinctions |
| Operations | What is running and how do I control it? | Jobs, loops, swarms, Doctor |
| Workspace | Where am I working? | Workspace lifecycle, projects, context, files and relevant Git changes |
| Insights | What happened over time? | Measured usage, cost, budgets and execution history |
| Terminal | Where do I work with agents directly? | PTY sessions |
| Settings | How is the product configured? | Appearance, language, scale, motion, setup and coding-tool/MCP connections |

World is the home. Other destinations are inspectors/workstations opened from
places, the nav, or the command palette — not competing spatial homes.

Connections initially have a clearly labeled setup home in Settings and contextual
entry points from installation and Doctor. Promote Connections to primary navigation
only if journey evidence shows this improves discovery. Do not add a destination
merely to match a CLI command.

Office prioritizes attention, running operations and useful next actions. An empty
runtime says "No agents are currently running." A catalog agent is not a running
process. Recent activity contains real events only. The world must not be required
to find operations or sessions — palette and nav remain.

## Shared action and entity model

One typed registry supplies global search, command palette, contextual actions,
entity results and recent actions from Engine/catalog/runtime state. Results retain
entity identity and workspace context. An action has typed arguments, validation,
availability with a reason, preview, execution result and recovery information.
Forms support selection, scope and dry run without shell strings as authority.
Unavailable actions explain why; no silent dispatch fallthrough.

Installation reviews files, destinations, conflicts and reversibility before apply.
Transactions record actual artifacts and results. Irreversible actions require
specific confirmation; reversible operations expose real Undo and its limits.

## State and geometry

Converge incrementally on Engine canonical state → typed ViewModel → layout →
renderer → interaction dispatch → typed Engine operation. The CLI currently calls
core directly and Desktop has additional domain logic; shared authority is a gap,
not an accomplished property. Reuse working core operations through typed seams.

One geometry calculation drives draw, hover, hit test, focus and tooltip anchors.
Extract repeated components as they are used, not a speculative widget framework.
Buttons, fields, rows, status indicators, drawers, empty/error/loading states and
terminal chrome share semantics. Applicable states include default, hover, focus,
pressed, selected, disabled, loading, success, warning and error. Status needs text
or shape in addition to color. Disabled controls explain the reason.

Guard every integer selection before indexing with `>= 0 && < len`, including
desk, terminal panes, loops, jobs, skills, memory and swarms. Validate selections
again after filtering, refresh and workspace switch. Mask secrets before values
reach rendering, logs, previews or diagnostic exports. UI projections must not
contain credentials merely because the underlying operation needs them.

## Inspector, activity and terminal

The inspector follows selection for skills, agents, coding tools, MCP, jobs, loops,
swarms, workspaces, projects, products/packs, receipts and files. Order information
as identity, status, key facts, recent activity, primary actions, secondary detail
and advanced data. No selection shows useful guidance without invented activity.

One always-available activity control summarizes real running work, approvals and
failures and opens the relevant entity. Coalesce updates rather than sending
repeated notifications.

Terminal sessions support create, attach, switch, split, resize, scrollback,
selection, copy/paste, search, exit and explicit recovery. Exited processes remain
exited until the user requests a new process. Hide/compact/tall/max are temporary
view states. Do not persist pane focus or MAX across launches. The current local
`modules/ghostty` is a custom V VT parser, not upstream libghostty; upstream Ghostty
integration and actual VT compatibility require a separate evidence-backed decision.

## Focus and responsive behavior

Event precedence is modal → active text field → terminal → focused widget →
panel-local shortcuts → global shortcuts. Escape closes the innermost context and
never unexpectedly quits. Long lists use roving focus. Help reflects actual
bindings. Test text and terminal input collisions.

Wide layouts can show navigation, content and inspector together. Medium layouts
collapse optional detail. Compact layouts use drawers/tabs, wrapping and scrolling;
they never shrink text to fit or clip primary actions. Validate breakpoints through
the [resolution matrix](VISUAL_QA.md), including scaled text and long translations.

Persist durable preferences only, and persist them through the Engine, never
from views directly: appearance, language, density, reduced motion, scale,
tool paths and setup configuration live in the Engine-owned derived
`ui_state.env` (`modules/desktop_engine/ui_state_persistence.v`); dock
layout lives in the Engine-owned derived `dock.json`
(`modules/desktop_engine/dock_persistence.v`). Both are restorable derived
state under the XDG-cache persist path, mirrored into the StateRepository.
Session-only view state is never restored: terminal MAX restarts as compact
(see `persisted_terminal_mode`). Setup & Onboarding can be revisited
without resetting the environment.
