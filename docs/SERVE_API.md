# Serve — the Agent Toolkit Programmatic API

`agent-toolkit serve` is the **programmatic/headless surface** of Agent Toolkit
(ADR-030). It exposes the same core capabilities as the CLI over HTTP so that
integrations, IDEs, dashboards, scripts and other external clients can discover
and invoke them without spawning processes or parsing stdout.

The CLI remains the primary *human* interface; this server is for machines.

## Quick start

```bash
agent-toolkit serve                # http://127.0.0.1:3847 (localhost-only)
agent-toolkit serve --port 8080 --no-browser
```

## Machine-readable contract

| Artifact | Purpose |
|---|---|
| `/api/v1/openapi.json` | OpenAPI 3.1 spec — every capability, scope and confirmation flag |
| `docs/surface/openapi.json` | same file, generated from `docs/compatibility/cli-contract.yaml` |
| `docs/compatibility/cli-contract.yaml` | canonical capability contract (SSOT) |
| `docs/compatibility/api-schemas.yaml` | typed response schemas (`components.schemas`) and server-native endpoints; each schema is parity-checked against its V struct |

Regenerate after changing the contract:

```bash
./scripts/generate_surface.vsh        # or --check in CI
```

## Surface map

- `GET /api/v1/health`, `/api/v1/version` — liveness/build info
- `GET /api/v1/selfcheck` — runtime coherence: embedded OpenAPI freshness vs
  running binary, jobs dir writability, bind policy, and a live diff of
  registered routes vs the embedded OpenAPI (`route_manifest_match`)
- Read APIs — `inventory`, `doctor`, `matrix`, `diff`, typed `loops` /
  `swarms` (see [Swarms and loops](#swarms-and-loops))
- Execution APIs — thin proxies over core (`install`, `update`, `uninstall`,
  `skills/:sub`, `mcp/:sub`, `plugin/:sub`, `workspace/:sub`, `memory/:sub`,
  `project/:sub`, `loops/:sub`, `dc/:sub`, `swarms/:sub`, `build`)
- Generic subcommand routes (`<family>/:sub`) take a typed JSON body — see
  [Typed subcommand bodies](#typed-subcommand-bodies)
- Jobs — `POST /api/v1/jobs`, `GET /api/v1/jobs`, `GET /api/v1/jobs/:id`,
  `GET /api/v1/jobs/:id/log`,
  **SSE streaming** via `GET /api/v1/jobs/:id/events` (`status` transitions,
  `log` lines, terminal `done`; process-per-run, bounded concurrency),
  `POST /api/v1/jobs/:id/cancel` (running → `canceled`, child terminated;
  409 when already terminal), `POST /api/v1/jobs/:id/retry` (failed or
  canceled job → new job with the same cmd/args/workspace and `retry_of`;
  409 otherwise), `DELETE /api/v1/jobs/:id` (terminal jobs; running jobs
  need `?force=true`). Job bodies are the `Job` schema.
- Events — `GET /api/v1/events`, the global SSE bus (see
  [Event stream](#event-stream))
- Agents and tools — `GET /api/v1/agents` (persona catalog),
  `GET /api/v1/tools` (coding-agent CLI discovery),
  `GET /api/v1/providers` (swarm runners), `GET /api/v1/models`
  (swarm model-profile slots). See [Agents and tools](#agents-and-tools)
- Memory — typed `GET /api/v1/memory`, `/memory/hits`, `/memory/file`
  plus `POST`/`PUT` `/memory/file` and `POST /memory/file/archive`.
  Memory is learnings/processes/todos, not the knowledge tree. See
  [Memory](#memory). The generic `memory/:sub` route remains for
  CLI-parity add/search/inject/review/todo.
- `GET /` — minimal static status page (not a product surface)

## Typed subcommand bodies

`skills`, `mcp`, `plugin`, `workspace`, `memory`, `project`, `loops`, `dc` and
`swarms` expose `POST /api/v1/<family>/{sub}` (read subcommands also accept
`GET`). The body is a JSON object of typed options for that family; its
schema is the operation's `requestBody` in OpenAPI, sourced from `api_body`
in `docs/compatibility/cli-contract.yaml`.

```bash
curl -s -X POST http://127.0.0.1:3847/api/v1/memory/search \
  -H 'Content-Type: application/json' -d '{"query":"veb"}'
```

- **The path is authoritative.** Bodies have no `subcommand` field; a
  `"subcommand"` key is ignored, so a body can never turn `search` into `add`.
- **Allowlist.** `{sub}` must be in the family's `api_subcommands` (the
  OpenAPI `sub` enum), otherwise `404`. Not exposed over HTTP: `loops run`
  (use the job-backed `POST /api/v1/loops/{name}/run`), `loops gate-*` (reads
  the server process argv/env), and `swarms attach` (replaces the server
  process with a terminal). `swarms start` never attaches a terminal.
- **Bodies.** Empty body keeps the defaults. A non-object or malformed JSON
  body is `400`. Unknown keys are ignored.
- **Paths.** `workspace` (and `dir` on `workspace/{sub}`) follow `POST /api/v1/jobs`:
  traversal `400`, missing `404`, outside the allowed roots (symlinks
  resolved) `403`. Relative path references (`pack`, `artifact`, `recipe`,
  `workspace load` / `project add` `arg`) must not traverse; absolute ones
  must exist inside the allowed roots.
- **Names and ids** (loop names, run/gate/handoff ids, roles, runners,
  models, git refs, commits, cron) are validated and rejected with `400`;
  option-like values (leading `-`) are never accepted.

## Workspace rooting

serve has no `--workspace` flag. It keeps its jobs dir at
`<cwd>/.agent-toolkit/server`, counts cwd as an allowed containment root, and
resolves the workspace for `loops`, `memory`, `workspace`, `swarms` and
`project` with core `find_workspace_root` when a request does not pass
`workspace`: `AGENT_TOOLKIT_WORKSPACE`, then `HARNESS_DIR`, then walking up
from cwd. To root serve at a harness, launch it
from that directory with `AGENT_TOOLKIT_WORKSPACE` pointing at the same path.
Desktop does this for its default harness; see
[desktop/ELECTRON_MIGRATION.md](desktop/ELECTRON_MIGRATION.md#default-harness).

## Event stream

`GET /api/v1/events` streams server events over SSE. Each message has
`id: <boot>-<seq>`, `event: <type>` and a JSON `ApiEvent` in `data`
(`seq`, `boot`, `type`, `at`, `subject`, `status`, `exit_code`, `ref`,
`message`). `boot` changes whenever the server restarts; `exit_code` is only
meaningful for `job.*` and `loop.*`.

| Type | `subject` | Notes |
|---|---|---|
| `backend.ready` | `serve` | once per server process; `message` = version |
| `backend.resync` | `serve` | cursor too old or from an earlier process — refetch state; carries no `id:` |
| `job.created` / `job.updated` / `job.deleted` | job id | `status`, `exit_code`; `ref` = `retry_of` |
| `loop.started` / `loop.finished` | loop name | for `loop run` jobs; `ref` = job id |
| `swarm.changed` | run id (may be empty) | after a successful mutating `swarms/{sub}`; `message` = sub |
| `memory.changed` | entry type | after a successful `memory/add` |
| `install.started` / `install.finished` | `install`, `update` or `uninstall` | `status` = `completed` or `failed` |

- **Resume** with `Last-Event-ID` (browsers send it on reconnect, and it
  wins over `?since`) or `?since=<seq>` (a bare seq of the current process).
  The server keeps the last 512 events; a cursor older than that, or one
  issued by another server process (different `boot`), gets
  `backend.resync` followed by every retained event.
- `swarm.changed` is not emitted for `dry_run` calls, nor for `handoff` /
  `task` sub-operations that only read.
- **Filter** with `?types=job.,loop.finished` (exact types or `family.`
  prefixes).
- A `: ping` comment every 15 s keeps the connection alive and detects
  dead clients; at most 16 concurrent subscribers (`503` beyond that).
- Events describe what the server did; they are not persisted. Read
  endpoints remain the source of truth.

## Agents and tools

- `GET /api/v1/agents` — personas from `agents/<id>/AGENT.md` (`id`,
  `name`, `kind`, `description`, `source_file`). Empty when the toolkit
  root has no `agents/` tree.
- `GET /api/v1/tools` — coding-agent CLIs with split planes:
  `detected` (binary on this session's PATH), `configured` (known
  settings sentinel exists), `enabled` (`unknown` until serve owns an
  enablement store; Desktop Engine SQLite is not this process),
  `verified` (`--version` exited 0). `install_hint` is empty unless a
  real first-party install argv exists.
- `GET /api/v1/providers` — swarm runner CLIs (`opencode`, `claude`,
  …, `skeleton`). `auto` is a resolver and is omitted.
- `GET /api/v1/models` — flattened `swarm_model_profiles()` slots
  (`profile`, `runner`, `model`).

## Memory

Typed memory API, distinct from the workspace knowledge tree and from
`GET /api/v1/files`. `?workspace=` (or `workspace` in the body) is
contained like other serve workspace fields; empty uses the default
harness root. Entries are markdown under
`knowledge/{learnings,processes,todos}/` only. Other `knowledge/*.md`
files (including `scratch.md`) are not memory. Symlinks and `..` that
leave `knowledge/` are rejected.

- `GET /api/v1/memory` — list files (`id`, `kind`, `title`, `snippet`,
  `tags`, `provenance`). `body` is empty on list. Missing workspace is
  `200` with `entries: []`, so the catalog exists even when no harness
  is configured.
- `GET /api/v1/memory/hits?q=` — case-insensitive line hits (`path`,
  `line`, `snippet`, `kind`). Empty `q` is `400`.
- `GET /api/v1/memory/file?path=` — read one file (`body` populated).
  `provenance.author` is the last git committer when `.git` exists,
  otherwise empty. `provenance.agent` is empty unless recorded.
  Missing files are `404`.
- `POST /api/v1/memory/file` — `{entry_type, title?, content}` adds a
  learning, process, or todo via the same writer as `memory add`.
- `PUT /api/v1/memory/file` — `{path, content}` atomically replaces a
  memory markdown file (64 KiB cap, no NUL).
- `POST /api/v1/memory/file/archive` — `{path}` moves the file under
  `knowledge/archive/`. Already-archived paths are `409`. Nothing is
  deleted.
- `GET` on `memory/{sub}` is allowed for `list`, `search`, `show`,
  `get`, `inject`, and `todo`. `list`/`show`/`get` are reserved names
  for the typed routes above; they are not CLI subcommands yet.

Add/edit/archive emit `memory.changed`.

## Swarms and loops

Typed work APIs over the filesystem swarm SoT and loop dirs. `?workspace=`
is contained like other serve workspace fields.

- `GET /api/v1/swarms` — runs (`run_id`, `recipe`, `backend`, `run_state`,
  `created_at`, `task`).
- `GET /api/v1/swarms/runs/{id}` — run plus budget, approvals, handoffs,
  tasks, artifacts, trace tail. `budget.cost_status` is `unavailable`
  unless a cost limit or spend is recorded.
- `GET /api/v1/swarms/runs/{id}/handoffs|tasks|approvals|artifacts`
- `POST /api/v1/swarms/runs/{id}/approve` `{gate_id}`
- `POST /api/v1/swarms/runs/{id}/reject` `{gate_id, reason}`
- `POST /api/v1/swarms/runs/{id}/stop` — cancel. Mutations emit
  `swarm.changed`.
- Tasks are the durable handoff queue (status = handoff state, owner =
  `to` role, `blocked_reason` only when `blocking` and not terminal).
- `GET /api/v1/loops` — installed loops. `GET /loops/{name}/status`,
  `/audit`, `/history`, `/cost`. Cost is `unavailable` unless traces
  record tokens (audit). The generic `swarms/:sub` and `loops/:sub`
  routes remain for CLI-parity writes.

## Security defaults (ADR-028)

- Binds `127.0.0.1` only. Remote binding requires explicit `--allow-remote`
  plus a bearer token (`--auth-token` or `AGENT_TOOLKIT_TOKEN`).
- Scopes derive from capability effects (`read:*`, `write:*`); destructive
  operations are flagged `x-confirm-required` in OpenAPI.
- Browser CSRF guard: mutating routes on a loopback bind reject
  `Sec-Fetch-Site: cross-site` requests. First-party non-browser clients
  (Electron Desktop over `file://`, which Chromium always flags cross-site)
  send `X-Atk-Desktop: 1` instead. Browsers cannot send that header
  cross-origin without a CORS preflight the server never answers (no
  `Access-Control-Allow-Origin` is emitted), and non-loopback `Origin` values
  stay rejected — so browser pages must remain same-origin.
- See [security/threat-model-serve.md](security/threat-model-serve.md).

## Parity semantics

Per ADR-030, parity is enforced between the **canonical contract**, the
**core implementation** and the **programmatic API** — never between
presentations. Tests: `tests/test_surface_parity.py`. External UIs own their
own presentation and may expose any subset of the API.
