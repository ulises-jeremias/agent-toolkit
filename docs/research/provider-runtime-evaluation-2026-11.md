# Provider runtime evaluation ledger — 2026-11-04

Mission: [#1667](https://github.com/ulises-jeremias/agent-toolkit/issues/1667). Implementation spike: [#1669](https://github.com/ulises-jeremias/agent-toolkit/issues/1669).

**This is an investigation protocol, not an architecture decision.** Inspected docs/code outline promising capabilities; no runtime candidate has passed installed-provider validation here.

## Reference SHAs / ownership

| Reference | SHA sampled | Product lesson |
| --- | --- | --- |
| [T3 Code](https://github.com/pingdotgg/t3code) (MIT) | `9e85538535c8553901351112ab02dd1dd62db5ee` | Provider adapters, app-owned threads, graph projections, MCP delegation, PTY and Git provenance |
| [Agent Office](https://github.com/AgentSystemLabs/agent-office) | `852e2ab28c4f3f31bffdf4b20353bd119c9d3270` | Persistent desks/worktrees and direct live-terminal access |
| [Pixel Agents](https://github.com/pixel-agents-hq/pixel-agents) | `b1bafd02896d90d83457266575a1e8e5011ce997` | Real agent-activity animation and subagent/status cues |
| [Pixel & Process](https://github.com/Pixel-Process-UG/agent-office) | `da62eee3bb054d0500b15ace53dd005adcfa512d` | Pixel office UX study |
| [Munder Difflin legacy path](https://github.com/chaitanyagiri/munder-difflin) | **Redirected** | Resolve canonical upstream and verify current commit before cloning |

The owner's main use case is not a generic agent dashboard. The priority is **existing subscriptions + local provider-native lifecycle + full inspectability + cozy meaningful world**.

## T3 Code capabilities to verify in a local build

Primary sources:
- [Architecture](https://github.com/pingdotgg/t3code/blob/main/docs/internals/overview.md): runtime server owns Git, provider processes, terminal and workspace files; client must not impersonate local environment.
- [Provider semantics](https://github.com/pingdotgg/t3code/blob/main/docs/internals/providers.md): provider instance/account isolation, native protocols and permission boundaries.
- [Orchestration V2](https://github.com/pingdotgg/t3code/tree/main/docs/orchestration-v2): threads/runs/execution graph, native vs app-owned subagents, provenance, event projections and provider handoffs.
- [Orchestrator MCP](https://github.com/pingdotgg/t3code/blob/main/docs/orchestration-v2/orchestrator-mcp-server.md): `delegate_task`, task status/cancel/wait, thread controls, scoped credentials.
- [ACP providers](https://github.com/pingdotgg/t3code/blob/main/docs/user/providers-acp.md): generic agent integration and concrete native-provider adapters.

**Do not assume a document labeled 'V2' has fully shipped.** For each feature, inspect code and execute it; separately record implementation status and proven behavior.

## Proof matrix (initial state: unverified, no subjective scores)

| Test | Fork/extract T3 | T3 sidecar/API | Native adapters/ACP |
| --- | --- | --- | --- |
| Claude subscription sign-in and real turn | U | U | U |
| Codex subscription and native root turn | U | U | U |
| OpenCode native stream and tool provenance | U | U | U |
| Tool/plan/approval streaming in renderer | U | U | U |
| Terminal resize/focus/backpressure | U | U | U |
| Safe cancellation and provider process exit | U | U | U |
| Session history after app restart | U | U | U |
| Cross-provider delegated child identity | U | U | U |
| Typed Toolkit V API integration | U | U | U |
| Windows/macOS/Linux packaging path | U | U | U |
| Permission and license compliance | U | U | U |
| Upgrade/fork maintenance surface | U | U | U |

Fill cells with *pass/fail/blocked + commit/trace URL*; do not turn lack of evidence into a score.

## Existing Toolkit friction to challenge

- `modules/agent_toolkit_core/swarm.v`: large filesystem state machine and prompt-driven handoff system; verify observed provider behavior before reusing.
- `modules/agent_toolkit_core/swarm_backend.v`: shell-command launch per provider, default Claude permission bypass, static model guesses.
- `apps/desktop/electron/harness*.ts`, `pty-host*.ts`: useful PTY/process ownership and replay that may not be full provider-native conversation state.
- `apps/desktop/src/features/world/`: spatial model works only to the extent its backing session/process states are authoritative.
- `docs/desktop/workflows.yaml`: green component journeys, but no acceptance evidence for the core session use case.

## Required decision output

For every candidate: supported provider versions, exact process/SDK handshake, event loss behavior, authoritative stop/resume, auth portability, sandbox and credential boundary, worktree ownership, external service/protocol stability, runtime dependencies, binary size, CPU/RAM observations, maintenance burden, license/attribution and fully reproducible trial instructions.

Choose the architecture that maximizes proven reliability with **minimal owned orchestration code**, not the one that produces the most features or preserves the most historic design decisions.
