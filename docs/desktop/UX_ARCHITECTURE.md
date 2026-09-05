# Desktop UX architecture

Status: intended interaction contract, 2026-09-05. Current implementation is
`cmd/agent-toolkit-desktop/main.v`, using gg/sokol. Historical
[ADR-032](../adrs/ADR-032-desktop-gui-framework.md) describes a vlang/gui wrapper
that is not the production renderer. Preserve that history; a superseding ADR is
required to reconcile the implementation. This document does not approve a rewrite.

## Shell and navigation

The active workspace and Search / Run are always discoverable. Keep six primary
destinations while validating actual journeys:

| Destination | User question | Contents |
|---|---|---|
| Office | What needs attention now? | Setup, approvals, failures, running work, recent activity, session entry |
| Library | What can I use or add? | Skills, agents, products and packs with clear distinctions |
| Operations | What is running and how do I control it? | Jobs, loops, swarms, Doctor |
| Workspace | Where am I working? | Workspace lifecycle, projects, context, files and relevant Git changes |
| Insights | What happened over time? | Measured usage, cost, budgets and execution history |
| Settings | How is the product configured? | Appearance, language, scale, motion, setup and coding-tool/MCP connections |

Connections initially have a clearly labeled setup home in Settings and contextual
entry points from installation and Doctor. Promote Connections to primary navigation
only if journey evidence shows this improves discovery. Do not add a destination
merely to match a CLI command.

Office prioritizes attention, running operations and useful next actions. An empty
runtime says "No agents are currently running." A catalog agent is not a running
process. Recent activity contains real events only. The optional floor map must
not be needed to find operations or sessions.

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

Persist durable preferences only: appearance, language, density, reduced motion,
scale, tool paths and setup configuration. Setup & Onboarding can be revisited
without resetting the environment.
