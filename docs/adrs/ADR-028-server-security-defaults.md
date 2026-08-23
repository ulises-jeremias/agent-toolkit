# ADR-028 — Server security defaults (localhost-first, fail-closed remote)

- **Status:** Accepted (2026-08-23)
- **Deciders:** maintainer
- **Related issues:** #493, #541 (threat model gate), epic #830

## Context

`agent-toolkit serve` exposes powerful mutations (install, loop run/schedule, swarm start). Default posture must be safe by default while still enabling remote/GUI use-cases.

## Decision

**Network**
- Default bind `127.0.0.1:3847`.
- Remote bind (`0.0.0.0`) requires BOTH `--allow-remote` AND `--auth-token TOKEN` (or `--auth-token-env VAR`). Missing either → exit 2 with guidance.

**AuthN/Z**
- Localhost requests: no auth (desktop model, parity with `gh`).
- Non-localhost: `Authorization: Bearer <token>` required; constant-time compare; tokens never logged (`sanitize_args()`).
- **Policy scopes** from `.agent-toolkit/server/policy.yaml` map to contract effects (ADR-029): `read:*`, `write:fs`, `write:loops`, `write:swarm`, `write:memory`, `write:projects`, `write:dc`, `write:mcp`, `write:plugins`, `write:catalog`, `write:workspace`.
- Destructive routes additionally require `X-Confirm: true` header or `confirm:true` JSON field → else `428 Precondition Required`.
- FS-mutating scopes (`write:fs`) denied for non-localhost unless `--allow-remote-write-fs`.

**Web hardening**
- No cookies → CSRF risk minimal; still enforce `Origin`/`Sec-Fetch-Site` checks on writes.
- CORS disabled by default; `--cors https://app.example.com` emits allowlist.
- CSP `default-src 'self'` for embedded UI.

## Consequences

+ Safe-by-default; remote is explicit and auditable.
+ Capability parity retained — policy gates permission, not existence.
− Two flags needed for remote; acceptable (documented in GETTING_STARTED).

## Validation plan

- Unit: middleware tests (401/403/428 paths, token compare, scope matrix).
- Integration: remote schedule loop with correct token succeeds; without token fails 401.
- Threat-model checklist (#541) reviewed before documenting any remote example.
