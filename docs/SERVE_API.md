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

Regenerate after changing the contract:

```bash
./scripts/generate_surface.vsh        # or --check in CI
```

## Surface map

- `GET /api/v1/health`, `/api/v1/version` — liveness/build info
- `GET /api/v1/selfcheck` — runtime coherence: embedded OpenAPI freshness vs
  running binary, jobs dir writability, bind policy, and a live diff of
  registered routes vs the embedded OpenAPI (`route_manifest_match`)
- Read APIs — `inventory`, `doctor`, `matrix`, `diff`, `loops`, `swarms`
- Execution APIs — thin proxies over core (`install`, `update`, `uninstall`,
  `skills/:sub`, `mcp/:sub`, `plugin/:sub`, `workspace/:sub`, `memory/:sub`,
  `project/:sub`, `loops/:sub`, `dc/:sub`, `swarms/:sub`, `build`)
- Generic subcommand routes (`<family>/:sub`) take a typed JSON body — see
  [Typed subcommand bodies](#typed-subcommand-bodies)
- Jobs — `POST /api/v1/jobs`, `GET /api/v1/jobs`, `GET /api/v1/jobs/:id/log`,
  **SSE streaming** via `GET /api/v1/jobs/:id/events` (`status` transitions,
  `log` lines, terminal `done`; process-per-run, bounded concurrency),
  `POST /api/v1/jobs/:id/cancel` (running → `canceled`, child terminated;
  409 when already terminal), `DELETE /api/v1/jobs/:id` (terminal jobs;
  running jobs need `?force=true`)
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
- **Paths.** `workspace` and `workspace dir` follow `POST /api/v1/jobs`:
  traversal `400`, missing `404`, outside the allowed roots (symlinks
  resolved) `403`. Relative path references (`pack`, `artifact`, `recipe`,
  `workspace load` / `project add` `arg`) must not traverse; absolute ones
  must exist inside the allowed roots.
- **Names and ids** (loop names, run/gate/handoff ids, roles, runners,
  models, git refs, commits, cron) are validated and rejected with `400`;
  option-like values (leading `-`) are never accepted.

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
