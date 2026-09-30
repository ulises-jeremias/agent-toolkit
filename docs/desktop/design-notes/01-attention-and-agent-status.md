# Design note 01 — Attention queue and real agent status

Status: **PROPOSAL** (2026-09-30). Part of
[WORKSTATION_REFERENCE_ANALYSIS.md](../WORKSTATION_REFERENCE_ANALYSIS.md).
Program todos: `attention-queue`, `real-agent-status`, `return-to-work`
(Phase 4.2 Office, Phase 2 PR B/E backend).

## Problem

Office today counts selfcheck warnings plus running jobs as "attention" and
says "Nothing needs you" after a failed job or while the backend is down
(baseline captures in the analysis doc). No agent, session or run has a status
that comes from the agent itself.

Both references solve "what needs me" better:

- Agent Office derives `working` / `needs_input` / `done` from provider hooks,
  an OpenCode plugin and ACP (for DeepSeek Harness), and lets **N** jump to the
  worker that has waited longest (`src/client/nextup.ts`: sort by
  `waitingSince`, a per-round visited set, then wrap).
- Munder has an explicit "ASK ME" rule: only things blocked on the human.

Neither separates *kinds* of attention: in Agent Office a permission prompt, a
question and "finished, nobody looked" are all one `needs_input`/`done` pair,
ordered only by wait time. There is no severity, no failure item, no
approval/gate item and no cross-project ordering (N stays on the current
project and only *names* another project that has someone waiting).

## Interim (Phase 4.2 Office, shipped)

Until V emits `AttentionItem`, Office answers the five questions from
today's typed sources only: supervisor `backend-status` (crash / version
mismatch / harness), `GET /api/v1/jobs` + status, selfcheck, health, and
the #1320 bus (`GET /api/v1/events`). Manila "Needs you" is crash,
mismatch, harness, failed jobs, and failing self-checks. Running and
completed stay in their own sections. Empty copy is "Nothing needs you."
only after the job list and self-check succeed — never on a crash or a
failed query. Palette "Next that needs me" cycles crash/mismatch → failed
jobs → running jobs. The completed-needing-review slot stays empty until
Phase 2 PR E. This is honesty, not the V attention queue.

## Decision

### V owns attention items; React only renders them

An attention item is a V domain entity, derived from real transitions, stored
in the workspace and published on the global event bus from #1320
(`/api/v1/events`). The renderer never computes "needs me" from other data.

```text
AttentionItem
  id            string   stable, "<kind>:<subject.type>:<subject.id>[:<n>]"
  kind          enum     see table below
  severity      enum     blocking | action | review | info
  workspace     string   workspace root id (always present, even with one backend)
  subject       { type: run|session|job|loop|swarm_run|task|handoff|install|backend, id }
  owner         { agent?, role?, provider?, model? }      only when known
  title         string   server-authored, short, no raw CLI text
  detail        string?  verbatim provider-reported ask (e.g. tool + args), truncated
  opened_at     RFC 3339 when the condition began (wait-time anchor)
  updated_at    RFC 3339
  seen_at       RFC 3339?  set when the human opens the subject
  resolved_at   RFC 3339?
  resolution    enum?    approved | rejected | answered | retried | resumed | dismissed | superseded | cleared
  actions       [{ id, method, path, confirm_required }]   only actions V can perform now
  evidence_ref  string?  log, receipt or trace path
  source        enum     engine | job_runner | swarm_state | loop_runner | hook:<provider> | acp
```

Kinds (each maps to a real V transition; nothing is inferred from terminal text):

| Kind | Severity | Source today or needed |
| --- | --- | --- |
| `approval_pending` (swarm gate, `x-confirm-required` op) | blocking | swarm `approvals.json` gates exist; PR E types them |
| `permission_requested` (provider asks to run a tool) | blocking | provider hooks (needs session ingestion, below) |
| `input_requested` (agent asked a question) | blocking | provider hooks / ACP |
| `task_blocked` (dependency, blocking handoff) | action | swarm handoffs have `blocking`; PR E |
| `session_crashed` / `session_lost` | action | session process state (design note 02) |
| `session_resumable` (exited mid-turn, provider session id known) | action | design note 02 |
| `job_failed`, `loop_failed`, `swarm_failed` | action | job runner, loop runner, swarm `run_state` |
| `budget_exhausted`, `gate_rejected` | action | swarm `budget_exhausted` state, gate rejection |
| `auth_required`, `setup_required` | action | provider hooks / discovery (PR C) |
| `backend_degraded` | blocking | supervisor state (Electron main publishes locally; not a V item) |
| `review_ready` (turn done, result not reviewed) | review | provider `Stop`/idle + unseen |
| `conflict` (worktree cannot merge base) | review | git read rails (PR G) |
| `cleanup_suggested` (PR merged, worktree clean) | info | design note 03 |

Endpoints (typed in OpenAPI):

- `GET /api/v1/attention?state=open` — current items.
- `POST /api/v1/attention/{id}/seen` — marks `seen_at`; idempotent.
- `POST /api/v1/attention/{id}/dismiss` — allowed only for `review` and `info`.
  `blocking`/`action` items resolve only through their action (approve,
  answer, retry, resume) or when the underlying condition clears.
- Events: `attention.opened`, `attention.updated`, `attention.resolved`, each
  carrying the full item, on the existing seq/resume ring.

### Ordering and grouping

1. Severity band: blocking, action, review, info.
2. Within a band: unseen before seen, then oldest `opened_at` first, then `id`.
3. Group by workspace only when more than one workspace is open; group by
   subject (one row per run with a count) when a run has several items.

This keeps Agent Office's strongest property (oldest waiting first, so nobody
starves) and adds what it lacks: failures and approvals outrank "done".

### "Next needing me" keyboard flow

- `N` when focus is not in a terminal or text field; `Ctrl/Cmd+Alt+N`
  everywhere, including inside a terminal. Also a palette command.
- Each press opens the next item's subject at the right facet (approval
  dialog, terminal at the prompt, failed job log, changes view) and marks it
  seen. A per-round visited set (as in Agent Office) avoids bouncing between
  two items; an item that reopens after being visited is new to the round.
- The count lives in the shell, not only in Office: sidebar badge, window
  title prefix `(n)`, and taskbar badge (`app.setBadgeCount`).

### Cross-workspace aggregation

`serve` is cwd-rooted, so one backend serves one workspace. The renderer keys
every attention query by `workspace` from day one. When Desktop supervises
more than one backend, main merges their streams; ordering stays the same
across workspaces. The context-bar workspace switcher shows per-workspace
blocking/action counts.

### Notifications and return to work

Electron main shows a native notification for `blocking` and `action` items
when the window is unfocused, after a short debounce (Agent Office waits a few
seconds with nobody at the terminal before its team webhook fires). Clicking
focuses the window and deep-links to the subject. No sound by default.
Webhooks (Slack/Discord) are **later**, through the existing loop/notify
paths, never a Desktop-only feature.

## Real agent status

Status comes only from provider-native mechanisms; if none reports, the state
is `unknown`. No idle timers pretend to know "done", and terminal output is
never parsed for status.

Status is several facets, not one badge:

- `process`: starting, running, exited (code), signaled, lost.
- `turn`: idle, working, awaiting_permission, awaiting_input, done,
  interrupted, unknown.
- `blocked_reason`: auth_required, setup_required, provider_error,
  rate_limited, or none.
- `current_action`: provider-reported tool name plus a bounded argument
  summary (for example `Bash: npm test`), with `reported_at`.

Provider mechanisms Agent Office uses and ATK can use the same way:

| Provider | Mechanism | Events that matter |
| --- | --- | --- |
| Claude Code | command hooks in a settings file | `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Notification`, `Stop` |
| Codex | command hooks passed as `-c hooks.<Event>=…` overrides | `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `PermissionRequest`, `Stop` (sub-agent hooks carry the root session id, so they are ignored) |
| OpenCode | plugin file | `session.idle` / `session.status`, `permission.asked`, `question.asked`, `permission.replied`, `question.replied` |
| Grok, Muse | command hooks in an isolated XDG config | same Claude-style set plus `PermissionRequest`, `PostToolUseFailure` |
| ACP agents | ACP session messages | session updates, permission requests, usage updates |

How events reach V (ATK-native, not a copy of Agent Office's HTTP listener):

1. When V starts a session it mints `ATK_SESSION_ID` and a per-session token,
   and passes them in the environment with the session's run directory.
2. Provider hooks call one helper, `agent-toolkit session emit --provider
   <p> --event <e>`, which reads the hook JSON from stdin, keeps an allowlist
   of fields with length bounds, and appends one line to
   `<run_dir>/sessions/<id>/events.jsonl`.
3. V tails that file, updates the session facets and publishes
   `session.updated` and attention events.

The file sink is durable across `serve` restarts (V replays it on start), needs
no extra port, and fits ATK's file-based handoff queue. An optional
`POST /api/v1/sessions/{id}/events` with the session token can lower latency
later. Hook config is written to an isolated per-session config location (as
Agent Office does for Muse/Grok via XDG) so the user's own settings are never
modified.

## What V must emit vs what React renders

- V: attention items and events, session facets, allowed actions, evidence
  refs. V decides severity and ordering keys.
- React: lists, counts, grouping, the `N` flow, deep links, notification text
  from `title`/`detail`. No derived truth, no fallback "quiet" state when a
  query fails: a failed attention query renders as an error with retry.

## Not adopted

- One flat "waiting" badge for questions, permissions, failures and "done".
- Animated acting-out of tool calls, jumping, dinging, pins on a 3D compass.
- LLM-written task-card summaries (Agent Office calls Claude Haiku through the
  `claude` CLI). ATK shows provider-reported text or nothing; a summary would
  be an opt-in, budgeted job with a receipt.
