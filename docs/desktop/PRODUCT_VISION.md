# Agent Toolkit Desktop product vision

Status: governing product direction, adopted 2026-09-05. This document defines the
destination, not a claim that current builds meet it. Start with
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
- Maintain native V, gg/sokol and real PTY terminal operation. Do not replace the
  application with Electron, Tauri, a WebView or a browser frontend.
- Accessibility, localization, keyboard use and responsive layout are product work.
  Document native toolkit limitations without claiming unsupported conformance.

## Paper Co. identity

Paper Co. is a design language: warm paper, ink, manila, brass, rust and sage;
Fraunces, IBM Plex Sans and IBM Plex Mono; filing tabs, ledgers and restrained
stamps. Typography and spacing establish hierarchy. Decoration must not compete
with status, actions or text. A floor map may be an optional view if useful; it is
not the primary navigation or operational model. Motion communicates real state
changes. Reduced Motion removes nonessential movement.

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

[Munder Difflin](https://munderdiffl.in/) is a category benchmark, inspected
2026-09-05. Its landing page makes the local CLI-agent relationship, download and
setup story prominent. Learn from that immediate explanation and discoverability;
do not copy its interface, terms, assets or implementation. Marketing claims are
not independently verified runtime evidence.

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
