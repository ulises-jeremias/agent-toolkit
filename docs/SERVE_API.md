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
python3 scripts/generate_surface.py        # or --check in CI
```

## Surface map

- `GET /api/v1/health`, `/api/v1/version` — liveness/build info
- `GET /api/v1/selfcheck` — runtime coherence: embedded OpenAPI freshness vs
  running binary, jobs dir writability, bind policy
- Read APIs — `inventory`, `doctor`, `matrix`, `diff`, `loops`, `swarms`
- Execution APIs — thin proxies over core (`install`, `update`, `uninstall`,
  `skills/:sub`, `mcp/:sub`, `plugin/:sub`, `workspace/:sub`, `memory/:sub`,
  `project/:sub`, `loops/:sub`, `dc/:sub`, `swarms/:sub`, `build`)
- Jobs — `POST /api/v1/jobs`, `GET /api/v1/jobs`, `GET /api/v1/jobs/:id/log`
  (process-per-run, bounded concurrency)
- `GET /` — minimal static status page (not a product surface)

## Security defaults (ADR-028)

- Binds `127.0.0.1` only. Remote binding requires explicit `--allow-remote`
  plus a bearer token (`--auth-token` or `AGENT_TOOLKIT_TOKEN`).
- Scopes derive from capability effects (`read:*`, `write:*`); destructive
  operations are flagged `x-confirm-required` in OpenAPI.
- See [security/threat-model-serve.md](security/threat-model-serve.md).

## Parity semantics

Per ADR-030, parity is enforced between the **canonical contract**, the
**core implementation** and the **programmatic API** — never between
presentations. Tests: `tests/test_surface_parity.py`. External UIs own their
own presentation and may expose any subset of the API.
