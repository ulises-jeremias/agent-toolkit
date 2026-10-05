# Desktop UX architecture

Agent Toolkit Desktop is Electron + React over `agent-toolkit serve`. The V core owns workspace, capability, People, job, loop, swarm, memory, and installation semantics. Desktop calls typed backend operations and presents their real results. An Electron-only shell owns windows, local settings, and PTY hosting. CLI and Desktop must converge on the same domain operations.

## Spatial home and direct navigation

`/world` is the home and occupies the main canvas. A workspace is a valley; each actual project is a building. Shared capabilities are distinct landmarks: Library for reusable capabilities, Archive for memory, Operations for runtime work, Terminal for direct shells, and Workspace Hall for context. Inside a project, semantic objects open real Files, Knowledge, Memory, Tools, and Terminal resources. A building or object with no truthful click action or state relationship should not appear as a functional affordance.

World click targets, navigation, contextual actions, and the command palette use the same routes and operations. No task requires walking an avatar. Inspectors open for precise control while the world retains context. Library, project knowledge, memory, and files remain separate concepts.

The recovery inspector is labeled **Attention** in navigation. Its `/office`
route remains stable for existing links and palette queries; the visible
language describes the real function rather than an office metaphor.

## Identity and runtime

AgentDefinition is reusable capability; Person is durable collaborator configuration; AgentSession is a live process; SwarmRole is an ephemeral responsibility. A configured Person appears in the roster even when offline. A character in the world requires actual runtime evidence and a project assignment. Runtime exit removes its presence without deleting the Person. Environmental animals and effects must never imply agent activity.

## Interaction rules

Important mutations use a purpose-built configuration flow, backend validation, review of affected scope and paths, explicit apply, and a real receipt or result. Importing a Person never runs code or starts a session. Errors explain what happened, what remains safe, and how to retry or recover. Partial success is reported as such. Secrets are masked and not echoed in diagnostics.

A palette action opens the same flow as its menu or world equivalent. Disabled actions explain why. Keyboard focus is visible, Escape closes the innermost layer, and text/terminal input takes precedence over global shortcuts. Dense operational content uses readable body and monospace text; pixel display type is reserved for small labels. Responsive compact layouts preserve primary actions and avoid clipping. Reduced motion applies to ambient effects.

Terminal views connect to real PTY sessions. Switching route or collapsing the dock does not kill a session; close and process exit are explicit and observable. Reattach only to a process that exists. Swarm Operations shows topology, handoffs, approvals, budget, artifacts, and logs; the world only shows where actual work is happening.

## Evidence

The source of executable workflow status is [`workflows.yaml`](workflows.yaml). Visual review and packaging gates are in [`VISUAL_QA.md`](VISUAL_QA.md) and [`PACKAGING.md`](PACKAGING.md). Documentation does not convert a partial or unimplemented operation into a working Desktop journey.
