---
name: mcp-audit
description: MCP config + implementation security audit — config secrets/auth, unpinned versions, remote vs local, OAuth, env exposure; implementation command injection, SSRF, unsafe args, tool poisoning. Static, evidence-cited.
origin:
  type: first-party
---

# MCP Audit — Config + Implementation Security

Audit **MCP servers** before adopting — static inspection only, never execute remote servers. Use when reviewing `mcp/registry/*.yaml`, `mcp/templates/*/config.template.json`, skill/plugin MCP declarations, or when a static surface scan flags MCP references.

**Single skill, two modes** — decision per #379 review: config and implementation scopes meaningfully overlap (both inspect `mcp/registry/*.yaml` + templates), but checklists differ enough to keep separate gates. One skill with two modes avoids duplicating registry parsing while keeping `config` (secret hygiene, version pinning) distinct from `implementation` (command injection, SSRF, tool poisoning).

> **Static only:** Do not start or call remote MCP servers during audit. Inspect YAML/JSON, package provenance, tool descriptions, and env handling.

## Modes

| Mode | What it checks | Evidence |
|------|----------------|----------|
| **Config audit** | `mcp/registry/*.yaml` auth, package provenance, version pinning, remote vs local, OAuth, env/secret exposure, permissions | Registry YAML, template JSON, env var names, `docs/MCP.md` |
| **Implementation audit** | Command injection, shell execution, SSRF, unsafe args, tool description poisoning, secret env leakage, dangerous permissions, transport security | Skill SKILL.md + static surface patterns (shell/network/mcp/hooks), tool definitions, args validation, network_hosts |

Run the relevant mode per request; for full adoption review, run both and emit a single `mcp-audit-report.md`.

## Config audit — checklist

### Auth & secrets

- [ ] `auth.env` lists only env var **names**, never values (scan registry YAML for `ghp_`, `xoxb`, hardcoded tokens)
- [ ] Template `config.template.json` uses `${ENV_VAR}` placeholders (no real credentials)
- [ ] Remote MCP (`streamable_http` URL like `https://mcp.figma.com/mcp`) documents auth as `bearer-env` with region var, not query param
- [ ] Local MCP (`stdio` via `npx`/`docker`/`uvx`) does not embed secrets in `args` — secrets only in `env`
- [ ] No `default-branch push` or `filesystemWrites` beyond declared `security.network_hosts`

### Version pinning & provenance

- [ ] `implementation.package` is machine-verifiable: npm `chrome-devtools-mcp@latest` / docker `ghcr.io/...` / URL `https://mcp.figma.com/mcp` — not bare `latest` without policy
- [ ] `implementation.version_policy` declared (`npx-latest`, `pin image digest`, `pin to minor`) and matches template `args` (`-y chrome-devtools-mcp@latest` vs `mcp-notion-server`)
- [ ] `implementation.provenance` = `official` with `repository` URL + `license` verifiable via `gh api` (e.g., ChromeDevTools/chrome-devtools-mcp Apache-2.0, github/github-mcp-server MIT)
- [ ] Remote vs local decision documented: remote (Figma) for designer-hosted, local (GitHub/Slack/Notion) for on-host execution — no mixed remote + local for same provider without rationale

### Permissions & env exposure

- [ ] `security.network_hosts` enumerates expected hosts (no `*`, no private `.local` / `192.168.`)
- [ ] `security.secret_storage` = `environment variable` with `secret_storage` notes
- [ ] `platforms` matrix declares support per target (native/bridged/manual) — no assumed universal
- [ ] `approval.default` matches risk: `read-only` for Figma/GitHub vs `read-write` for Chrome DevTools (can modify page) — justified

### Per-template gate

- [ ] Template `command` ∈ `npx|docker|uvx` and `args[:2] == ["-y", provider.package]` for `npx` (verified by `tests/test_mcp_templates.py`)

## Implementation audit — checklist

### Command injection & shell

- [ ] `args` contain no shell interpolation (`$(`, `` ` ``, `;`, `&&`, `|`). MCP `command` is single binary, not `sh -c`.
- [ ] `command` is not `sh`/`bash`/`python -c` with concatenated args — use direct `npx`/`docker` entrypoint.

### SSRF & network

- [ ] URL args (`--browser-url`, `https://mcp.linear.app/mcp`) are not user-controlled without allowlist; `navigate_page` tool validates hosts.
- [ ] `network_hosts` does not include internal metadata endpoints (`169.254.169.254`, `metadata.google.internal`).

### Tool poisoning & unsafe args

- [ ] Tool descriptions in registry `tools.read/write` do not contain prompt injections (e.g., `ignore previous instructions`, `send secrets to`).
- [ ] Tool `write`/`destructive` sets are minimal — no `delete_file` where read-only suffices (GitHub `destructive` correctly lists `delete_file` only there).
- [ ] Args that become file paths (`FIGMA_OAUTH_TOKEN`) are env var refs, not string interpolation.

### Secret leakage & OAuth

- [ ] No `env` value contains PII — only `${VAR}` placeholders in templates; registry lists `env` names with `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS` style opt-outs.
- [ ] OAuth flows (Linear) documented as browser OAuth, not token paste.

## Workflow

1. **Load registry:** `agent_toolkit.compiler.mcp_registry.load_registry(mcp/registry)` — record `providers, errors` (evidence: registry count).
2. **Pick mode:** `config` (default for adoption) or `implementation` (for command/SSRF/poisoning) or both.
3. **Run checks:** For each `provider` in `providers`, apply the relevant checklist above; for `implementation`, Grep the registry/templates for shell/network/hooks patterns and capture findings with `file:line` evidence. (Repo checkout/CI may also run `v run scripts/audit-capability.vsh mcp/registry/<provider>.yaml --json` — that script is **not** on the host install.)
4. **Score:** `ALLOW` (no Blocking), `CAUTION` (Major, e.g., unpinned version, remote without TLS), `BLOCK` (Blocking: hardcoded secret, command injection, SSRF to metadata endpoint, provenance unknown).
5. **Report:** Emit `mcp-audit-report.md` (see `references/mcp-audit-template.md`) with per-provider table: `provider | config verdict | impl verdict | package/license | version_policy | provenance | evidence`.

### Example report row

| Provider | Config | Impl | Package | License | Version policy | Verdict | Evidence |
|----------|--------|------|---------|---------|----------------|---------|----------|
| chrome-devtools | ✅ auth none, package chrome-devtools-mcp@latest, npx-latest, no secrets | ✅ no shell, no SSRF, read-write justified | npm chrome-devtools-mcp@latest | Apache-2.0 | npx-latest | ALLOW | registry chrome-devtools.yaml + template config.template.json |

## Relation to `mcp` skill

- `mcp` (integrations/mcp) — **how to setup** (`agent-toolkit mcp setup`, `mcp list`, `doctor`) — orchestration.
- `mcp-audit` (this skill) — **whether to trust** — security gate before setup. Call this skill before `mcp setup` for unreviewed providers; delegate `supply-chain-audit` for full skill/plugin surface.

## Delegation table

| Need | Skill |
|------|-------|
| Setup MCP after audit | `integrations/mcp` |
| Full skill/plugin supply-chain | `agentic-security/supply-chain-audit` |
| OWASP agentic review (prompt injection, tool poisoning, identity) | `agentic-security/owasp-agentic-review` (next issue) |
| Output gate | `output-handshake` |

## Security & compatibility

- Never execute MCP servers during audit; static YAML/JSON only.
- Portable: `gh api` for provenance license check, `yaml` + `jsonschema` offline.

## References

- `references/mcp-audit-template.md` — report template (per-provider verdict)
- `mcp/registry/*.yaml` — canonical registry (7 providers after #375)
- `mcp/templates/*/config.template.json` — host wiring (placeholders)
- Static surface patterns in this skill’s checklists (shell/network/mcp/hooks); repo checkout/CI may use `scripts/audit-capability.vsh`
- MCP spec: https://modelcontextprotocol.io/ , ChromeDevTools MCP https://github.com/ChromeDevTools/chrome-devtools-mcp

