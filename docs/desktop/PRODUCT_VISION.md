# Agent Toolkit Desktop product vision

Status: **CURRENT CONTRACT** — governing product direction, adopted
2026-09-05, re-confirmed 2026-09-13 at `ecc4d67c`; **visual direction reset
2026-09-30** ([ADR-035](../adrs/ADR-035-cozy-pixel-world.md)): Cozy Pixel
World replaces Paper Co. This document defines the destination, not a claim
that current builds meet it. Start with
[workflow coverage](WORKFLOW_COVERAGE.md) for verified gaps and
[visual QA](VISUAL_QA.md) for acceptance evidence.

Agent Toolkit Desktop makes a coding-agent environment understandable, discoverable,
configurable, observable, operable, safe, extensible and pleasant to use. The running
application is the product. Issue closure, unit tests and matching goldens are
necessary evidence where applicable, but do not establish product quality.

## Users and standalone promise

A new user can install one native application, open it from an OS launcher, create
or reuse a workspace, detect coding tools, install something useful and operate it.
Required terminal commands, external repository clones and manual configuration
edits must each be zero. A source checkout, V compiler, developer cwd, developer
HOME and sibling repositories are not runtime prerequisites.

Existing users retain custom skills, agents, MCP configuration, tool integrations
and git-managed workspaces. Multiple workspaces are supported without mixing their
state or sessions. My AI Workspace, agentic-harness and agentic-workstation are
optional integrations through explicit contracts. They are never basic setup
requirements. A project is a development repository or directory; a workspace is
the managed environment that organizes projects, configuration and operations.

## Product principles

- Clarity, control, feedback and discovery precede personality and decoration.
- Display real state or explain that it is unavailable. Empty is a valid state.
  Never invent activity, compatibility, health, progress, costs or installation.
- Show the planned changes before mutation. Preserve user-owned files, report
  partial failure accurately and provide recovery. Offer Undo only when it works.
- Use task language before internal vocabulary. Reveal technical details on request.
- Keep the Engine authoritative. CLI and GUI consume shared typed domain operations.
  The GUI must not parse its own CLI output or duplicate installation logic.
- V remains core, CLI, and `agent-toolkit serve` backend authority. Desktop
  presentation is Electron + React (`apps/desktop/`, [ADR-033](../adrs/ADR-033-electron-desktop.md)).
  Do not reintroduce a second domain backend in TypeScript, and do not treat the
  historical native gg/sokol Desktop as the shipping product surface.
- Accessibility, localization, keyboard use and responsive layout are product work.
  Document toolkit limitations without claiming unsupported conformance.

## Cozy Pixel World identity

Agent Toolkit Desktop presents as a **beautiful cozy top-down pixel world that
happens to be a real developer workstation** (visual contract:
[DESIGN.md](DESIGN.md), decision: [ADR-035](../adrs/ADR-035-cozy-pixel-world.md);
the former Paper Co. language is deprecated). The **semantic spatial world** is
the default home and visually dominates it
([SEMANTIC_WORLD.md](SEMANTIC_WORLD.md), [ADR-034](../adrs/ADR-034-semantic-world.md)):
it explains workspace, projects, knowledge, tools and proven runtime work;
other destinations are inspectors rendered in the same game-menu language.
Pixel display type carries titles and world labels; dense body text and the
terminal stay crisp and readable. Motion communicates real state changes;
ambient world life never implies agent activity. Reduced Motion removes
nonessential movement. Never invent activity.

## First use and daily use

Within 30 seconds users should understand the product, active workspace, setup
status, detected tools, attention items and next action. Within five minutes they
should establish a workspace, discover and install a useful skill, inspect an
agent, access a real terminal, run an operation and understand its result.

Daily use includes search and keyboard actions, sessions, jobs, loops, swarms,
Doctor, MCP, coding tools, workspace context, costs and workspace switching.
Every workflow needs understandable failure and recovery.

## Non-goals and benchmark

This is not an IDE, full GitHub client, project-management dashboard, monitoring
platform, game, generic AI SaaS dashboard or general terminal-emulator competitor.
Preserve the terminal as a flagship coding-agent workflow without expanding into
unrelated terminal features.

[Munder Difflin](https://munderdiffl.in/) and
[Agent Office](https://github.com/AgentSystemLabs/agent-office) are capability
references, not visual authorities. Inspected revisions and the comparison live
in [WORKSTATION_REFERENCE_ANALYSIS.md](WORKSTATION_REFERENCE_ANALYSIS.md).
Learn user outcomes (setup discoverability, session durability, attention);
do not copy interfaces, terms, assets, 3D/game surfaces or implementation.
Marketing claims are not independently verified runtime evidence.

## Delivery and completion

Work in coherent reviewed PRs from fresh canonical main. Audit first; establish
trust and shared interactions before redesigning separate panels. Build, run,
navigate, capture, open images, critique and correct every major UX change.
Merge only green changes without unresolved Blocker/High findings. Release
publication requires separate authorization.

The mission ends only after a packaged product tour verifies standalone setup,
important workflows, truthful state, terminal reliability, responsive layouts,
keyboard/accessibility, localization, clean-machine resources and performance.
The master tracker must contain final SHA, PR sequence, issue reconciliation,
workflow and visual matrices, packaging/soak evidence and known limitations.
Do not close it while release-blocking gaps remain.
