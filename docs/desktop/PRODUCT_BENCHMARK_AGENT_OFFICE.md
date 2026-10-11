# Product benchmark: Agent Office

Reviewed 2026-10-11 against the upstream [Agent Office repository](https://github.com/AgentSystemLabs/agent-office), its [feature guide](https://github.com/AgentSystemLabs/agent-office/blob/main/docs/features.md), [agent selection](https://github.com/AgentSystemLabs/agent-office/blob/main/docs/agents.md), [controls](https://github.com/AgentSystemLabs/agent-office/blob/main/docs/controls.md), [configuration](https://github.com/AgentSystemLabs/agent-office/blob/main/docs/configuration.md), [maps](https://github.com/AgentSystemLabs/agent-office/blob/main/docs/maps.md), and [runtime notes](https://github.com/AgentSystemLabs/agent-office/blob/main/docs/how-it-works.md).

This review adopts product lessons only. Agent Toolkit keeps its own domain model, V backend, Electron product, semantic world, and original art. Agent Office is MIT licensed, but this project does not need its source code, maps, characters, or artwork.

## Strong lessons for Agent Toolkit

| Agent Office lesson | Agent Toolkit direction |
| --- | --- |
| A project is a persistent spatial context, and switching projects preserves your place. | Keep each project as a real World building and keep project switching available through direct navigation and the palette. Workspace packs remain shared context, separate from Library capabilities. |
| A worker's identity, runner, model, task, and live terminal stay connected. | Keep Person, AgentDefinition, SwarmRole, and runtime session distinct; expose only backend- and PTY-backed state. Person sessions already open real PTYs, and swarm role bindings remain configuration until real runtime evidence exists. |
| Human gates are conspicuous and one action opens the exact worker/run that needs attention. | Surface canonical swarm approval and recovery states in the shared Attention inspector, order them before routine running work, and route to the existing Operations run inspector. |
| The command palette and keyboard paths act on the same entities as spatial controls. | Continue mapping shortcuts to the existing canonical routes/actions. `Next that needs me` shares the same resolver as Attention rather than implementing another action path. |
| Failed worktrees have an explicit recovery path; destructive cleanup previews unpushed work. | Preserve Swarm cleanup previews and recovery evidence. Add GUI recovery only where the V backend can prove what will be restored or removed. |
| Model choice and defaults are visible at the point a task is assigned. | Show resolved runner/model per role before Start and in run inspection; keep defaults overridable and avoid guessing unsupported runner flags. |
| Live progress and stale/offline state are explicit. | Use typed events and backend snapshots. A connection failure must never look like an idle team, and a finished run is not automatically described as requiring review. |
| A lighter view makes the system usable on constrained screens and devices. | Keep compact layouts and keyboard alternatives. A separate low-performance/mobile world mode is a later, evidence-driven direction; Electron Desktop stays the flagship. |

## Already present in the current product

- The World is the home screen, projects are distinct buildings, and global places have their own landmarks.
- Spatial actions, direct navigation, and typed command-palette actions converge on the same application destinations.
- People persist while offline; only a real PTY linked to a Person and project creates a character in that project.
- Operations exposes typed swarm recipes, role bindings, approvals, handoffs, artifacts, trace entries, lifecycle actions, and cleanup review.
- The integrated terminal is a real PTY and remains available when routes change or the supervised backend restarts.
- MCP and capability installation use typed previews, secret-safe configuration, and receipt-backed evidence.

## Incorporated in this pass

Swarm runs in `awaiting_plan_approval` or `awaiting_human` now appear in Attention and in the shared “Next that needs me” sequence. Failed, budget-exhausted, and cleanup-pending runs also link to their canonical Operations inspector. If swarm inventory fails to load, Attention reports an unknown state rather than saying everything is clear. Completed runs are not automatically put into a human-review queue because the backend has no such review state.

## Follow-up opportunities and boundaries

- **Important:** connect swarm role processes to durable PersonSession identity and World presence only after the backend exposes authoritative per-role process/session state. Current `person_bindings` are resolution metadata and do not prove a live Person session.
- **Important:** strengthen adapter-backed run observation and recovery with real Herdr/tmux evidence. A headless run record is never presented as a live agent.
- **Important:** review host CPU/memory pressure and safe concurrency limits for local runners before offering broad parallel execution controls.
- **Future:** typed GitHub issue/PR boards and task queues could bring actionable repository work into project spaces; these need explicit auth, provenance, mutation previews, and a canonical backend API.
- **Future:** voice, multi-user presence, shared terminals, remote deployment, and live screen sharing are outside the local Electron trust boundary. Do not expose local PTYs or credentials to a network service without a separate security design.

Agent Office also includes alternate role-play maps and many playful interactions. Agent Toolkit should keep one coherent semantic world: ambience may make it warm, but decorations must not imply work or application state that does not exist.
