# Design note 02 — Sessions, provider adapters and terminal durability

Status: **FOUNDATION IMPLEMENTED; provider continuity remains proposed**
(2026-10-06). This note separates shipped lifecycle evidence from future
provider-session work. See [People](../../PEOPLE.md) and the
[Desktop workflow ledger](../workflows.yaml) for current evidence.

## Entities: composition, not a "Worker"

ATK keeps V as the only domain authority (ADR-033, accepted). The Desktop row
people call "an agent" is a projection of four V concepts:

| Entity | Meaning | Exists today |
| --- | --- | --- |
| **Agent** | Catalog definition: persona, skills, default provider/model | agents catalog (typed in PR C) |
| **Run** | A unit of work: goal, workspace, budget, gates, worktrees, handoffs, artifacts. A swarm run or a single-agent run | swarm runs (`swarm.v` state file); single-agent run not yet |
| **Session** | One provider process/conversation attached to a run: provider, model, transport, process state, turn state, provider session id | Person PTYs have durable V lifecycle records in `.agent-toolkit/sessions/`; provider conversation IDs and swarm-role session records are still missing |
| **Job** | One CLI invocation run by `serve` | server jobs (`jobs.v`), SSE, cancel/delete (#1313), get/retry (#1320) |

No TypeScript-invented `Worker` entity. The renderer shows Session + Run
joined by ids from typed endpoints.

## Formal provider adapter (yes)

Agent Office encodes per-provider behavior in one module per provider
(`agents.ts`, `codex.ts`, `opencode.ts`, `grok.ts`, `muse.ts`, `dsh.ts`).
ATK already has pieces: `tool_discovery.v` (detected/configured),
`swarm_backend.v` runners (`runner_available`, `herdr_runner_cmd`) and model
profiles. They should become one data-driven V adapter table:

```text
ProviderAdapter
  id                    claude | codex | opencode | grok | muse | acp:<name> | custom
  discovery             executable names, version probe argv
  launch                argv builder: model, effort, prompt, cwd
  permission_mode       default = gated; bypass flags only behind an explicit, receipted opt-in
  hook_install          settings-file | cli-overrides | plugin-file | xdg-isolated | acp | none
  session_id_capture    hook field | acp session/new | pre-assigned (--session-id) | none
  resume                argv template (e.g. `claude --resume {id}`, `codex resume {id}`,
                        `opencode --session {id}`, `grok --resume {id}`, `muse resume {id}`) | acp session/resume | none
  prompt_on_resume      argv | paste-after-SessionStart | acp | unsupported
  usage_source          provider-reported tokens/cost | none (shown as "unmeasured")
```

Resume argv values are what Agent Office uses at `13c104eb`; ATK must
re-verify each against the installed CLI version in discovery before
offering Resume.

## Canonical provider session id

Stored on the V Session record, never in the renderer:

```text
provider_session { provider, id, captured_from: hook|acp|preassigned, captured_at, verified: bool }
```

Resume is offered only when `id` is known and the adapter has a resume
mechanism. When the process died mid-turn (`turn` was `working` or
`awaiting_*`), V resumes with a fixed "continue" prompt and records that it did
so (Agent Office's `CARRY_ON_PROMPT` idea). Unknown id means **no Resume
button**, only "Start a new session in this run".

## Who owns what

| Concern | Owner | Why |
| --- | --- | --- |
| Person PTY identity, Person/project link, runner/model and reported lifecycle state | **V** (`serve`, `.agent-toolkit/sessions/`) | Durable domain history; status is updated by the local Desktop adapter |
| Provider conversation ID, run link, turn state and resume decision | **V** (`serve`, future Session entity) | Domain truth once runner adapters can report provider lifecycle evidence |
| PTY bytes, resize, input, screen mirror | **Electron main** (ADR-033: node-pty adapter, no domain state) | Native terminal transport on supported Electron platforms |
| Swarm roles on tmux/herdr backends | the backend (tmux/herdr) | already detached; V records `transport: tmux|herdr` |
| Detached PTY host (later, opt-in) | a small supervisor spawned by Electron main | only for process durability across app quit/crash |

Consequence: **PTYs survive a `serve` restart by construction**, because V never
owned them. On restart V reads PersonSession lifecycle records from disk;
Electron main continues to own the live PTY and its bounded in-memory tail.
There is no persisted terminal transcript or event replay after Desktop exits.

## Durability guarantee ATK should offer

Say exactly which failure keeps what. Never "sessions survive restart".

| Failure | Process | Screen | Conversation | Tier |
| --- | --- | --- | --- | --- |
| Renderer reload | kept (main owns PTY) | replay from the in-memory 8 KiB tail | kept while Electron main lives | implemented |
| BrowserWindow closed and recreated (app still running) | expected kept while main is alive | in-memory tail | kept | not separately exercised |
| `serve` restart / crash | kept (Electron main owns PTY) | replay from the in-memory tail | V reloads the durable PersonSession record | implemented |
| Renderer crash | kept | replay from the in-memory tail | kept while Electron main lives | implemented |
| Electron main crash | lost | lost | record is reconciled as interrupted on next Desktop startup | current behavior |
| Intentional quit | stopped by Desktop | lost | record is reconciled as interrupted on next Desktop startup | current behavior |
| Unexpected death / reboot | lost | lost | record is reconciled as interrupted on next Desktop startup | current behavior |

- **Next: provider continuity.** Add provider adapters only after each
  installed CLI's start/session-id/resume behavior is verified. Until then the
  UI records the real process lifecycle and does not promise a resumable
  conversation or preserve terminal output across app exit.
- **Evaluate later: detached PTY host.** (Agent Office: `detached` +
  `unref`, owner-only Unix socket, random token file mode 0600, protocol
  version handshake, "newest client wins", 30-minute orphan timeout). In
  Electron this means a separate Node process that outlives the app, which
  changes quit semantics and adds a process the user did not start. Ship only
  with an explicit "keep sessions running after quit" choice, Unix first, and
  a visible list of kept sessions. Windows has no equivalent in Agent Office.

## Terminal features worth adopting

- Late attach gets the serialized screen, then live bytes.
- Resize policy with several views: the view that is typing owns the size;
  opening a view does not resize a shared PTY.
- Drop or paste a file: copy into a run-scoped folder inside the workspace
  (size cap, sanitized name, no overwrite), type the shell-quoted path,
  delete with the run. Agent Office: 25 MB cap, `.agent-office/drops/<id>/`.
- Terminal full-text search stays separate from the command palette. The
  palette searches typed entities from V (runs, sessions, jobs, approvals,
  tasks); terminal search searches screen text and says so.
- Protocol-driven agents (ACP) render into the same terminal surface by
  writing ANSI into the mirror, with input handled as prompts, not PTY bytes.

## Environment hygiene

Sessions get a scrubbed environment: no Desktop/serve tokens except their own
session variables, no parent agent-session variables (Agent Office scrubs
`AGENT_OFFICE_*` and nested-agent prefixes before adding its own). Provider
config for hooks goes to an isolated per-session location so the user's own
Claude/Codex settings are never rewritten.
