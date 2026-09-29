# Munder Difflin → Agent Toolkit Desktop: capability gap loop

Source: `https://github.com/chaitanyagiri/munder-difflin` @ `ed06e3e`
(package 0.4.6), cloned to `/tmp/munder-study` 2026-09-29. Code + docs
evidence only (Electron + node-pty app needing native rebuild, paid agent
CLIs and credentials were out of proportion to run; re-verify by running
before release).

Munder stack (for contrast, not copying): Electron + React 18 + TS +
Pixi.js office floor, xterm, Monaco + CodeMirror, better-sqlite3,
electron-updater. Parody identity (floors, Michael/GOD, characters) is
explicitly NOT adopted.

Legend: ✅ ATK equivalent shipped · 🟡 partial · ❌ gap (needs backend + UI)

## Agent presence and control

| Munder outcome | Mechanism observed | ATK equivalent | Status | Chosen ATK UX |
|---|---|---|---|---|
| Agent cards with status/provider/model | `AgentCard.tsx`, `AgentStrip.tsx`, roster store | Office backend panel (health/selfcheck) | ❌ | Paper Co. run ledger rows: run identity, workspace, provider/model, live status — no avatars |
| Current task + action/tool visibility | `AgentDetailPanel.tsx`, `ToolWaterfall.tsx` | JobDetail shows cmd + live log lines | 🟡 | Extend JobDetail with current-action derivation from log tail (presentation only) |
| Crash state with recovery | `BlockedBanner.tsx`, `terminalRecovery.ts` | Crash banner + Restart backend (packaged-UAT proven) | ✅ | Keep; add per-run crash cards when typed run models land |
| Right-click/common actions | control strip components | Buttons only; no context menus | ❌ | Add context menu on run rows (inspect, restart, open terminal, open logs) |
| Queue input while agent busy | `MessageQueueComposer.tsx` | None | ❌ | Needs backend queue primitive; do NOT fake with local echo |
| Launch/configure agent (CLI, provider, model, perms, budget) | `AddAgentModal.tsx`, `EditAgentModal.tsx`, `hire.ts` | Terminal + job create with free-form cmd | ❌ | Agent-launch wizard backed by typed server routes (missing today) |

## Orchestration

| Munder outcome | Mechanism observed | ATK equivalent | Status | Chosen ATK UX |
|---|---|---|---|---|
| Tasks list + Kanban, real entities | `TasksKanban.tsx`, `TaskDetailOverlay.tsx` | None (jobs only) | ❌ | Typed task model must come from server first; board after |
| Inbox / messaging / handoffs | `ThreadsPanel.tsx`, AskMe flow | None | ❌ | Approvals + handoff views need server models (see below) |
| Approvals (ask-me gate) | `AskMeTab.tsx`, `askMeOrder.ts` | `x-confirm-required` is contract metadata only | ❌ | Approval center enforcing server gates; never client-side allowlist |
| Automations / schedules | `triggers/`, schedule UI | `loops/:name/schedule` proxy + cron-flag honesty | 🟡 | Typed schedule state routes before UI claims |
| Session resume | terminal + roster persistence | Terminal sessions die with window; jobs persist server-side | 🟡 | Reattach to jobs by id today; PTY reattach needs transport design |
| Circuit breaker | `breaker.ts` | Backend crash detection only | ❌ | Budgets/gates surfaced per-run (ATK strength: explicit over magic) |

## Workspace: files, git, memory

| Munder outcome | Mechanism observed | ATK equivalent | Status | Chosen ATK UX |
|---|---|---|---|---|
| IDE files/tree/edit/diff/image preview | `ide/` (Monaco + CodeMirror), `FilesTab.tsx`, `FileTree.tsx` | Workspace destination exists; verify depth | 🟡 | Monaco editing via typed file routes or narrow brokered IPC — never raw fs in renderer |
| Git status/diff/history/worktrees | `git/` main module, `GitTab.tsx`, `GitPanes.tsx` | Unknown depth | 🟡 | Audit Workspace git surface; typed V git routes before dangerous ops |
| Memory browse/search/provenance | `MemoryPanel.tsx`, `memory.ts`, memory-graph spec | `memory/:sub` proxy | 🟡 | Memory workspace with source/provenance per entry (ATK must beat Munder on inspectability) |
| Skills/capabilities install | `SkillsTab.tsx`, `IntegrationsRegistry.tsx` | Library destination over typed routes | ✅ | Keep; add receipts linkage per install |

## Runtime truth: cost, telemetry, setup

| Munder outcome | Mechanism observed | ATK equivalent | Status | Chosen ATK UX |
|---|---|---|---|---|
| Real cost/telemetry/budgets | `pricing.ts`, `realtimeCost.ts`, `costLifetime.ts`, `TELEMETRY.md` | Token budgets as config; no measured spend | ❌ | Receipts-backed usage views; show "unmeasured" truthfully until backend meters |
| Missing-CLI install + provider setup | `cliInstall.ts`, `nodeInstall.ts`, provider settings | Settings surface; install via jobs | 🟡 | In-app setup flows that shell real installers; never README dumps |
| Local models | model catalog references | Unknown | ❌ | Decide explicitly: support or documented reject |
| External input / webhooks | `webhook.ts`, `localtunnel` dep | None | ❌ | Explicit decision; security-first |
| Onboarding wizard | `OnboardingWizard.tsx`, `SetupPanel.tsx` | None in Electron | ❌ | First-run: backend → workspace → agents → first terminal (beat Munder here) |
| Keyboard UX | `CommandBar.tsx`, shortcuts | Semantic HTML + skip link; no palette | 🟡 | Command palette over real commands only |
| Multi-project | hive picker (`HivePicker.tsx`) | Single workspace context | ❌ | Projects/workspaces natively; multi-window only with unambiguous identity |
| CI visibility | github workflows integration | None in Desktop | ❌ | Explicit decision (CLI surface exists; Desktop value unclear) |
| Auto-update | `electron-updater` | None | ❌ | Required before v2.0.0 publish |

## Backend gaps that block the above (V work, never TS)

1. Typed swarm/task/handoff/approval models as `serve` routes
   (today only coarse CLI proxies; native `desktop_engine` views unexposed).
2. Loop audit/cost/receipts/schedule-state typed routes.
3. `office_*` facade rules (liveness reconcile, approvals, budget) as
   server truth instead of client derivation.
4. Job cancel/delete endpoint.
5. Memory entries with provenance + search.
6. Measured cost/telemetry pipeline feeding receipts.
7. Typed file + git routes for Workspace editing.

## Evidence log

- 2026-09-29: matrix created from Munder @ `ed06e3e` code tour.
- ATK packaged UAT (AppImage, Linux): backend ready, job SSE live to
  `done`, PTY restart preserves args, crash banner + restart, 0 console
  errors (`docs/desktop/ELECTRON_MIGRATION.md`).
