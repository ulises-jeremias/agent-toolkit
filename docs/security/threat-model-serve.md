# Threat Model — `agent-toolkit serve`

**Status:** Draft for review (blocks #541, required before `--allow-remote` docs)
**Related:** ADR-027 (thin adapter), ADR-028 (localhost-first), ADR-029 (SSOT), Epic #830

## 1. Trust Boundaries

```
[User CLI] ──localhost──> [serve] ──in-proc──> [core]
     │                          │
     └─remote (bearer)──► [serve] ──policy──> [core] ──FS/network
```

- **Local:** `127.0.0.1:3847` — no auth, user already owns machine.
- **Remote:** `0.0.0.0` + bearer token — untrusted network; every write is policy-gated.

## 2. Assets

| Asset | Sensitivity | Exposure via serve |
|-------|-------------|--------------------|
| `skills/` templates | Public | Read (inventory, loops) |
| `STATE.md`, `report.md` | Internal | Read/write via loops (scoped) |
| `~/.config/agent-toolkit/` receipts | Internal | install/uninstall (write:fs) |
| `AGENT_TOOLKIT_TOKEN` | Secret | Never logged, env only |
| `GITHUB_TOKEN` for loops | Secret | Injected via runner env, never returned |
| Job logs | Internal | Read via `/jobs/:id/log` (scope) |

## 3. Threats & Mitigations (STRIDE-lite)

| Threat | Example | Mitigation | Test |
|--------|---------|------------|------|
| **Spoofing** remote as local | `Host: 127.0.0.1` header spoof | Check actual bind address, not header | `curl --header "Host: 127.0.0.1" http://evil:3847` → 401 |
| **Token leak** via logs | `Authorization: Bearer …` in trace | `sanitize_args()` strips tokens; never log headers | grep logs |
| **CSRF** via browser form | Malicious site POSTs to `http://localhost:3847/api/v1/loops/x/run` | No cookies; require `Authorization` for writes when remote; check `Origin`/`Sec-Fetch-Site` on mutating | fetch without token → 401 |
| **CORS exfiltration** | Evil JS reads `GET /inventory` | CORS off by default; `--cors` allowlist; preflight fails | fetch without CORS → blocked |
| **FS mutation from remote** | `POST /install` from internet | `write:fs` scope denied unless `--allow-remote-write-fs`; default `local-full` only for CLI | POST /install remotely → 403 without flag |
| **Loop L3 merge abuse** | Remote triggers `oss-pr-monitor` merge | `loop-gh-gate` still enforced in core; `GITHUB_TOKEN` scope checked server-side | L2 cannot merge even via server |
| **DoS: many jobs** | 100 concurrent `POST /jobs` | `max_running=2` queue, 429 when full; `max_tokens`/`max_wall_seconds` still enforced | load test script in #839 |
| **XSS via report.md** | Loop writes `<script>` → rendered by an external UI | Out of scope since 1.23.0 (ADR-030): repo ships no HTML renderer; landing page is static text-only. External UIs own their CSP | mitigated by surface reduction |

## 4. Abuse-Case Checklist (CI)

- [ ] `curl http://127.0.0.1:3847/api/v1/loops` → 200 without token
- [ ] `curl -H "Authorization: Bearer bad" http://0.0.0.0:3847/api/v1/loops/1/run` → 401
- [ ] `curl -X POST http://127.0.0.1:3847/api/v1/install` → 200 (local allowed)
- [ ] `curl -X POST http://0.0.0.0:3847/api/v1/install` (remote, no token) → 401
- [ ] `curl -X POST -H "Authorization: Bearer $TOKEN" http://0.0.0.0:3847/api/v1/install` without `--allow-remote-write-fs` → 403
- [ ] Large `Authorization: Bearer $(python -c 'print("x"*10000)')` → 401, no crash, no OOM
- [ ] Replay old token after rotation → 401

## 5. Out of Scope (deferred)

- mTLS, OIDC — tracked as follow-up if remote adoption grows.
- WebSocket for jobs — SSE preferred (simpler, works behind proxies).

## 6. Sign-off

Requires review by maintainer before documenting any remote example in `GETTING_STARTED.md` (blocks #493).
