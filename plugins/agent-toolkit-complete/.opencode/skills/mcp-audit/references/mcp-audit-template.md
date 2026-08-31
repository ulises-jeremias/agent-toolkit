# MCP Audit Report

**Scope:** `mcp/registry` + `mcp/templates`  **Date:** [YYYY-MM-DD]  **Auditor:** [name]
**Mode:** config + implementation (static)  **Registry:** 7 providers (github, slack, notion, linear, figma, clickup, chrome-devtools)

> Static only — did not execute remote servers. Evidence: registry YAML + template JSON + `audit-capability.py` surface.

## Verdict

| Provider | Config | Impl | Package | License | Version policy | Provenance | Verdict | Evidence |
|----------|--------|------|---------|---------|----------------|------------|---------|----------|
| github | ✅ auth bearer-env GITHUB_PERSONAL_ACCESS_TOKEN, ghcr.io/github/github-mcp-server pinned digest, no secrets | ✅ no shell, no SSRF, delete_file only where needed | ghcr.io/github/github-mcp-server | MIT | pin image digest | official github/github-mcp-server | ALLOW | mcp/registry/github.yaml + mcp/templates/github/config.template.json |
| slack | ✅ bearer-env SLACK_* placeholders | ✅ no injection | @modelcontextprotocol/server-slack | MIT | pin to minor | official modelcontextprotocol/servers | ALLOW |  |
| notion | ✅ oauth remote + bearer-env local | ✅ | @notionhq/notion-mcp-server / https://mcp.notion.com/mcp | MIT | remote hosted / pin local | official makenotion | ALLOW |  |
| linear | ✅ bearer-env / OAuth (streamable_http https://mcp.linear.app/mcp) | ✅ no SSRF to metadata | https://mcp.linear.app/mcp | proprietary (Linear) | remote hosted | official Linear | ALLOW |  |
| figma | ✅ bearer-env FIGMA_OAUTH_TOKEN streamable_http https://mcp.figma.com/mcp | ✅ read-only, no shell | https://mcp.figma.com/mcp | proprietary | remote hosted | official Figma | ALLOW |  |
| clickup | ✅ bearer-env CLICKUP_API_TOKEN | ✅ | mcp-clickup-server | MIT | pin to minor | community → verified | ALLOW |  |
| chrome-devtools | ✅ auth none, package chrome-devtools-mcp@latest npx-latest, 7 env opt-outs, no secrets | ✅ no shell, no SSRF, read-write justified (can modify page) | chrome-devtools-mcp@latest | Apache-2.0 | npx-latest | official ChromeDevTools/chrome-devtools-mcp | ALLOW | mcp/registry/chrome-devtools.yaml + mcp/templates/chrome-devtools/config.template.json |

**Legend:** ALLOW (no Blocking), CAUTION (Major, e.g., unpinned), BLOCK (hardcoded secret, command injection, SSRF to metadata, provenance unknown)

## Config audit — per-provider notes

- All 7 `auth.env` list only names, templates use `${VAR}` placeholders — verified no `ghp_`/`xoxb` in registry (test_no_secrets_in_registry).
- `security.network_hosts` enumerates expected hosts, no private `.local`/`192.168.` (test_registry_no_private_hostnames).
- `platforms` matrix present per provider; `approval.default` matches risk (read-only vs read-write for chrome-devtools).
- Template `args[:2] == ["-y", package]` for npx providers — verified test_stdio_templates.

## Implementation audit — per-provider notes

- No `sh -c` or shell interpolation in `args`; `command` in npx/docker/uvx only.
- No SSRF to metadata endpoints (`169.254.169.254`).
- Tool `write`/`destructive` minimal (only github lists `delete_file`).
- Tool descriptions scanned for prompt injections — none found (if found, mark BLOCK).

## Missing evidence / Not assessed

| Check | Why not assessed | What would enable |
|-------|------------------|-------------------|
| Remote Figma/Linear TLS cert chain | static only, no live probe | live `tools-list` healthcheck with timeout_ms |

## Follow-ups

- [ ] If CAUTION/BLOCK: file issue with provider + checklist gate + evidence link
- [ ] Re-audit when `mcp/registry/*.yaml` changes (CI `validate-manifests` + `audit-capability.py`)

## Output handshake

- **Destination:** [docs/security/mcp-audit-YYYY-MM-DD.md or issue comment]
- **Reviewer:** [who approves adoption]
- **Confirmed:** [date]
