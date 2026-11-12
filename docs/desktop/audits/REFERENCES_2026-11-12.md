# Desktop rescue: direct reference research

Audited 2026-11-12. Shallow clones retained privately at `.audit-private/references/`. This is source and installed-CLI inspection, not a claim of live provider or packaged UX acceptance. No borrowed source or assets were added to Agent Toolkit.

## Verified versions and licensing

| Repository | Audited commit | License |
|---|---|---|
| [t3code](https://github.com/pingdotgg/t3code) | `4e48d9e6a5aba8d0184ac2c953598086ed034c29` | MIT, T3 Tools Inc. |
| [agent-office](https://github.com/AgentSystemLabs/agent-office) | `852e2ab28c4f3f31bffdf4b20353bd119c9d3270` | MIT, AgentSystemLabs |
| [munder-difflin](https://github.com/HarnessMD/munder-difflin) | `9bc1e5ab658ee9e41671d35f7ecd190cf46b8b2d` | Source MIT; bundled tilesets/maps have separate LimeZu terms, not MIT |
| [pixel-agents](https://github.com/pixel-agents-hq/pixel-agents) | `4dd14d612fd37d89ffbbc977959f572395c4eec8` | Root source MIT, Pablo De Lucca; external asset packs require independent license review |

The requested chaitanyagiri/munder-difflin URL now redirects to HarnessMD/munder-difflin. MIT source reuse requires preserving notices. Do not import reference artwork; Munder explicitly excludes bundled artwork from its source license in [LICENSE-ASSETS](https://github.com/HarnessMD/munder-difflin/blob/9bc1e5ab658ee9e41671d35f7ecd190cf46b8b2d/LICENSE-ASSETS).

## Concrete mechanisms worth transferring

### T3 Code: the best functional architecture reference

- Real Codex integration uses app-server through a dedicated adapter, declares capabilities (including native approval IDs and live-only approval callbacks), and treats permission responses as request-bound actions. Source: [CodexAdapterV2.ts](https://github.com/pingdotgg/t3code/blob/4e48d9e6a5aba8d0184ac2c953598086ed034c29/apps/server/src/orchestration-v2/Adapters/CodexAdapterV2.ts). Transfer the explicit capability matrix and native request identity, not its considerable Effect-specific infrastructure wholesale.
- Resume of the UI event stream is distinct from provider continuation: replay has sequence numbers, a 128-event / 1 MiB bound, and snapshot fallback. Source: [ThreadStream.ts](https://github.com/pingdotgg/t3code/blob/4e48d9e6a5aba8d0184ac2c953598086ed034c29/apps/server/src/orchestration-v2/ThreadStream.ts). Toolkit should distinguish reconnect, history reload and provider resume in both contract and copy.
- Provider onboarding derives checking/disabled/install/signIn/ready/attention from installation, authentication and runtime status rather than equating binary presence with readiness. Source: [providerReadiness.logic.ts](https://github.com/pingdotgg/t3code/blob/4e48d9e6a5aba8d0184ac2c953598086ed034c29/apps/web/src/onboarding/providerReadiness.logic.ts).
- [ChatView.tsx](https://github.com/pingdotgg/t3code/blob/4e48d9e6a5aba8d0184ac2c953598086ed034c29/apps/web/src/components/ChatView.tsx) routes approval/question answers to the outstanding request and prevents a fresh-session send from stealing them. Native subagent interventions route to the parent. [Sidebar](https://github.com/pingdotgg/t3code/tree/4e48d9e6a5aba8d0184ac2c953598086ed034c29/apps/web/src/components/sidebar) groups project/thread navigation; [diff components](https://github.com/pingdotgg/t3code/tree/4e48d9e6a5aba8d0184ac2c953598086ed034c29/apps/web/src/components/diffs) separate file navigation/loading/code display. These are strong domain boundaries for Focus.

### Agent Office: live process state, efficient terminal observation

- [terminal.ts](https://github.com/AgentSystemLabs/agent-office/blob/852e2ab28c4f3f31bffdf4b20353bd119c9d3270/src/server/workers/terminal.ts) maintains headless xterm state, sends changed rows and periodic full keyframes (8 seconds) for recovery from dropped diffs. OSC progress catches cancellation that emits no Stop hook. Offline copy says the worker is not running and only offers session resume if it has a session ID.
- [acp.ts](https://github.com/AgentSystemLabs/agent-office/blob/852e2ab28c4f3f31bffdf4b20353bd119c9d3270/src/server/workers/acp.ts) guards late callbacks by checking the active session object, persists provider session IDs, and distinguishes application shutdown from process exit. Transfer generation/ownership guards and truthful exit handling. Do not make terminal-emulated conversations the default Focus UX.

### Munder Difflin: terminal continuity and lifecycle

- [terminalPool.ts](https://github.com/HarnessMD/munder-difflin/blob/9bc1e5ab658ee9e41671d35f7ecd190cf46b8b2d/src/renderer/src/components/terminalPool.ts) keeps one xterm instance per PTY, reparenting its host across views so navigation does not discard scrollback or produce blank terminals. Generation counters reject stale process callbacks. Theme notifications are sent only to terminals that opt into DEC 2031.
- Its terminal font explicitly moved from VT323 to JetBrains Mono for readability. Transfer that separation of playful art from serious technical text. Pool ownership must remain bounded and dispose on actual PTY termination; permanent hidden render loops are not required.
- This is a useful terminal reliability reference, not justification for replacing structured Focus with another embedded TUI.

### Pixel Agents: spatial truth and restrained provider abstraction

- [provider.ts](https://github.com/pixel-agents-hq/pixel-agents/blob/4dd14d612fd37d89ffbbc977959f572395c4eec8/core/src/provider.ts) normalizes actual lifecycle/tool/permission events. It distinguishes awaiting input from completed turns, native subagent lifecycle from background teammate creation, and explicitly documents that only its real hook provider ships rather than inventing hypothetical adapters.
- [sessionRouter.ts](https://github.com/pixel-agents-hq/pixel-agents/blob/4dd14d612fd37d89ffbbc977959f572395c4eec8/server/src/sessionRouter.ts) holds pending external sessions until confirmation, maps provider session IDs to displayed agent IDs, and buffers out-of-order events with expiration. Transfer this verified identity boundary to World: a declared Person never proves a running session.
- Hook installation and usage bridges have explicit provider-specific consent. World observation must not silently mutate external provider configuration.

## Installed provider interfaces verified without model calls

`codex-cli 0.167.2`, `Claude Code 2.1.322`, `opencode v2.2.7` are installed under `/usr/bin`. Help output confirms Codex app-server, exec, resume, fork, queue and doctor; Claude print mode, explicit agent configuration and background session commands; OpenCode ACP, serve, API, service and session management. This verifies available entry points only, not authentication, protocol compatibility or working paid execution. No credentials were printed and no model task was invoked.

## Product recommendation

Keep a conventional workspace/project/thread shell and make Focus the default work surface. Treat World as another projection of the same selected project and verified session registry. Start with one structured provider adapter supporting start, events, interrupt and native approvals; show continuation only when the adapter can prove it. Keep terminal PTY lifetime independent of React view lifetime. Persist canonical session history separately from transient rendering state. Copy these mechanisms conceptually; neither a wholesale dependency transplant nor reference artwork is justified by this audit.

Live visual and interaction comparison of the reference applications remains unperformed; none of the source observations above should be represented as hands-on UX acceptance.
