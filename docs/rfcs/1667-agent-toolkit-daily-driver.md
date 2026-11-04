# RFC #1667 — Agent Toolkit Daily Driver Reboot

- **Status:** Proposed / implementation-gated; product direction authorized by the owner on 2026-11-04.
- **Mission:** https://github.com/ulises-jeremias/agent-toolkit/issues/1667
- **Baseline:** `main` at 1563d17354119e6940cad12776181aa1c5106f87 (the v1.49.0 integration/release remains a separate stabilization track).
- **Decision authority:** evidence from packaged runtime / user journeys, not feature count, passing unit tests or historical architectural commitments.

## Problem, not a feature request

The initial CLI/workspace/skills/loops were understandable. Swarm introduced complex, prompt-dependent semantics and a second layer of agent coordination; the V rewrite and Desktop expansion made the system harder to operate. The owner's repeated real-user report is **Desktop is not usable for productive coding**, despite many recorded successful component tests.

This is a product and domain-model issue. A prettier map, additional animation, more documentation, or another configured swarm role alone will not solve it.

The `docs/desktop/workflows.yaml` ledger currently labels 18 workflows `ok`. That is **existing feature evidence**, not verified acceptance of installed local coding-agent workflows. Keep it truthful, and add a separate real-provider acceptance gate (see [Daily Driver Acceptance](../desktop/DAILY_DRIVER_ACCEPTANCE.md)).

## Product promise

A single installable, local-first developer workspace where I can:

1. Link an existing repository and use my **existing provider subscriptions** with Claude Code, Codex, OpenCode, and eventually others.
2. Run, observe, control, suspend, resume and inspect real agent tasks, tool calls, file changes, conversation and terminal output in one **Focus** UI.
3. Walk around a beautiful original fantasy pixel-art semantic world where each project and object represents real state; hover over an active worker to learn *what they are actually doing*, click to open the same canonical session.
4. Assign planning, implementation and review across multiple provider instances via **actual runtime-owned orchestration**, while preserving native subagents and their honest lifecycle.
5. Use Toolkit skills, personas, loops, context packs and memory during those sessions without understanding four repository boundaries.

An empty workspace is honestly empty. A process disappearing is not success. A token/cost estimate is never represented as a hard cap unless enforced. A provider-native approval must never be replaced by a decorative UI indicator.

## Architectural review — no preemptive fork

Current boundaries:

- `modules/agent_toolkit_core/`: V catalog, skills, loops, workspace, memory, People and v1 Swarm.
- `modules/agent_toolkit_server/`: V typed HTTP/event backend; for production, own only domains it can implement truthfully.
- `apps/desktop/electron/`: Electron main process, supervised V backend and PTY host.
- `apps/desktop/src/`: React Focus/World/Operations/Library/People UI.
- `agentic-harness`: reference persistent workspace; `my-ai-workspace`: personal instance; `agentic-workstation`: provisioning. None should become a competing orchestration engine.

There are **three architectures to demonstrate in a P0 spike** (#1669), not three to implement forever:

| Candidate | Advantage to prove | Risk to measure |
| --- | --- | --- |
| A. MIT-licensed T3 Code fork or extracted orchestration subset | Real provider lifecycle, session graph, existing adapters, event model, SDK integrations and MCP | Maintaining a large fast-moving upstream, runtime/persistence/license integration, package build complexity |
| B. T3 as a user-installed sidecar / service through supported interfaces | Low initial duplication, independent provider releases | Whether API/MCP exposes *all* needed streams, session control, terminal + approvals, compatibility and distributable installation |
| C. Minimal first-party session runtime using supported SDKs/ACP/native provider APIs | Clean ownership and V Toolkit composition | Reimplementing crash recovery, idempotency, approvals, provider-specific quirks, worktrees and event stream |

**Selection gate:** at least two viable prototypes; one real installed provider end-to-end; explicit cross-platform/recovery/security analysis; reproducible pinned sources. Do not choose A merely because a repository is MIT. Do not choose C because V is preferred for the CLI. Prefer less owned orchestration code, more truthful provider capabilities and more reliable local experience.

### Proposed canonical vocabulary (subject to Gate 1)

- **Project:** registered Git working directory.
- **Workspace:** user-owned grouping and scoped capability configuration.
- **ContextPack / Memory / Skill:** portable evidence-backed capability inputs owned by V.
- **Person / AgentDefinition:** persistent role/profile, not a running process.
- **ProviderInstance:** a concrete installed authenticated coding tool/version/account, with capability flags.
- **AppThread:** conversation identity owned by Toolkit.
- **Run:** one user-visible task/turn; its root lifecycle determines completion.
- **ExecutionNode:** nested provider-native tool, plan, approval, subagent or app delegation. Native provider ids stay as references.
- **ProviderSession:** supervised native process/SDK session and durable provider cursor.
- **Worktree:** Git isolation and artifact provenance, not an OS sandbox.
- **Workflow:** dependency-aware composition of runs across providers.
- **Loop:** scheduled/repeated invocation of the same task/workflow with policy and audit.

Only one backend owns authoritative thread/run/session state. World and Focus are **two projections** of it. No fake NPCs or independent TS `Worker` state.

### Provider adapter contract hypothesis

Each adapter needs capability declarations for authentication, launch, session ids, resume, streamed text/tool/plan/subagent events, approval/request callbacks, interruption, steering, model selection, usage, checkpointing, and provider-native forks. Unsupported capabilities must be explicit.

Preserve raw provider lifecycle meaning. App ids are stable; adapter-native ids are provenance refs; child-run completion never completes a root run. Retry a side effect only if it is safe and idempotent; recover after lost provider processes honestly.

A *technical session can always expose its real PTY*, but a transcript with semantic tool calls requires provider-native structured events. A PTY-only provider gets PTY-level observability, not fabricated structured tools.

### Swarm v1 decision

**Freeze new v1 features except correctness and security. Do not delete v1 user data yet.** The legacy implementation is retained behind an explicit transition while new app-owned workflows are proven. Map its `pair/team/full` recipes to task sequences when semantics permit; convert previous runs into durable archives if needed; protect owned worktrees and external changes. Do not fake migration of an active tmux/Herdr session into a new provider cursor.

## Design contract — a game that remains a workstation

- Home: original cozy top-down semantic world, with legible crisp text and quiet motion.
- Project houses: contextual entry points; Library=skills; Archive=memory; Operations=tasks/loops; real session/person=project-scoped character.
- Hover gives provider, model, project, **last observed event**, status/stale/needs-you; click opens same app thread/run/session in Focus.
- Focus is a high-density professional workspace with conversation, tool events, terminal, diff, approvals, checkpoints, worktrees, Git/PR and keyboard navigation.
- No core task requires walking, hovering or an animation. Same action exists in palette/keyboard/list. Accessibility and reduced motion.
- Existing `SEMANTIC_WORLD.md` remains the art/runtime-truth contract until Gate 3 specifically supersedes it. Do not start a game-engine rewrite prematurely.

## Delivery sequence

1. **#1668 Gate 0:** reproduce installed application failures and create independent real-provider evidence ledger.
2. **#1672 security:** remove default permission bypass and accurately represent true restrictions before unattended launch.
3. **#1669 Gate 1:** compare/exercise architectures; decision ADR; exact real provider proof.
4. **#1670 / #1671 Gate 2:** canonical sessions and Focus must deliver the daily-driver vertical slice with a tested installed build.
5. **#1673 Gate 3:** connect high-fidelity World to genuine session state, not vice versa.
6. **#1674 / #1676 Gate 4:** MCP cross-provider workflows; migrate Swarm only after parity proof.
7. **#1675 / #1677 Gate 5:** scope skills/loops/context and run cross-platform package acceptance.

## Gates and vetoes

- No full product rewrite based solely on a source-code comparison.
- No issue closure based solely on a PR, mock E2E, generated screenshots or documentation agreement.
- No CI bypass, force merge, silent provider permission override, fabricated usage, invented health, or hidden project-file overwrite.
- Every vertical PR requires a real-task demonstrator (where the runtime is in scope), tests, failure evidence, risk/rollback section and maintainability notes.
- Changes that modify provider runtime and UI should be an independently executable vertical slice, not 30 unrelated panels in parallel.
- Keep ongoing v1.49.0 stabilization PRs #1655/#1664/#1666 isolated from this major architecture project. Start implementation on fresh main after integration.

## Sources inspected 2026-11-04

- [T3 Code](https://github.com/pingdotgg/t3code): [providers](https://github.com/pingdotgg/t3code/blob/main/docs/internals/providers.md), [architecture](https://github.com/pingdotgg/t3code/blob/main/docs/internals/overview.md), [orchestration](https://github.com/pingdotgg/t3code/tree/main/docs/orchestration-v2) and [MCP delegation](https://github.com/pingdotgg/t3code/blob/main/docs/orchestration-v2/orchestrator-mcp-server.md). MIT; snapshot SHA to pin in the spike: `9e85538535c8553901351112ab02dd1dd62db5ee`.
- [Agent Office](https://github.com/AgentSystemLabs/agent-office): snapshot `852e2ab28c4f3f31bffdf4b20353bd119c9d3270`.
- [Pixel Agents](https://github.com/pixel-agents-hq/pixel-agents): snapshot `b1bafd02896d90d83457266575a1e8e5011ce997`.
- [Munder Difflin original URL](https://github.com/chaitanyagiri/munder-difflin): currently redirects, so the spike must verify canonical upstream owner, clone target and license rather than treating the old GitHub URL as stable.
- [Pixel & Process](https://github.com/Pixel-Process-UG/agent-office): snapshot `da62eee3bb054d0500b15ace53dd005adcfa512d`.
- [Current Toolkit product vision](../desktop/PRODUCT_VISION.md), [workflow ledger](../desktop/workflows.yaml), [Swarm security](../SWARM_SECURITY.md).

**Important:** reference documentation is not proof of an upstream running feature. All benchmark claims must be corroborated with source, trace or a locally reproduced run.
