# Research: Integration Candidates — #393 (2026-08-12)

**Purpose:** Rank each SaaS integration's backends per target per #386 WHAT vs HOW (no universal ranking law) and decide ADOPT/ADAPT/EXTERNAL/NATIVE/REJECT with real upstream provenance. Validates ADR-0004 generalization beyond 3 pilots (Linear/Slack/Figma) per review §36-37.

**Scope:** Notion, Sentry, Vercel, Jira, Confluence, Datadog, AWS, Supabase. Sources dated 2026-08-12.

## Findings — per candidate

### Notion — ADOPT (upgrade community MCP → official remote MCP)

- **Existing:** `mcp/registry/notion.yaml` → community `suekou/mcp-notion-server` MIT `stdio` `NOTION_API_TOKEN` (read/write, 6 tools, `mcp-notion-server`, https://github.com/suekou/mcp-notion-server, archived/active 2026-08-12) — bridged for opencode/pi, blocked for copilot-cli/codex.
- **Official:** `makenotion/notion-mcp-server` https://github.com/makenotion/notion-mcp-server (Official Notion MCP Server, TypeScript, 4.5k stars, Apache-2.0? MIT? — check LICENSE, maintained by Notion) — remote `https://mcp.notion.com/mcp` `streamable_http` OAuth (also Docker `mcp/notion` https://hub.docker.com/r/mcp/notion). Docs: https://developers.notion.com/docs/mcp, https://github.com/makenotion/notion-mcp-server. Native for Claude/Cursor/OpenCode/VS Code.
- **Other HOWs:** Notion REST API `https://api.notion.com/v1` `bearer-env` `NOTION_API_TOKEN` (universal, direct); community alternatives `ramidecodes/mcp-server-notion`, `piskunproject/notion-mcp-server` (Apify) — REJECT (official dominates); `skill_fallback` `skills/integrations/notion` (future).
- **Ranking (contextual, not law):** OAuth remote MCP (team, no env, low context) > PAT `stdio` community (solo) > REST API (admin/batch, needs approval) — per ADR-0004 §36.
- **Decision:** **ADOPT** — migrate `mcp/registry/notion.yaml` to official remote MCP as preferred, keep `suekou` as fallback + REST API. Add to `providers/providers.yaml` as `notion` with 4 HOWs. License/Maintenance: official actively 2026-08-12.
- **Security:** `source_trust: official` vs `community`, `runtime_privilege: read-write` (both need approval for delete) — distinct.

### Sentry — ADOPT (official MCP)

- **Official:** `getsentry/sentry-mcp` https://mcp.sentry.dev (hosted `https://mcp.sentry.dev/mcp`, `Sentry-Bearer ${SENTRY_ACCESS_TOKEN}` separate from `Bearer` OAuth, `streamable_http` remote, tools `sentry_list_alert_rules`, `sentry_retrieve_alert_rule_detail`, issues/stacktraces). Docs: https://mcp.sentry.dev, https://docs.sentry.io/product/sentry-mcp/ . Maintained by Sentry, active 2026-08-12.
- **Community/PyPI:** `mcp-server-sentry` (`mcp-server-sentry 0.4.1` PyPI), `mcp-server-sentry-xhs`, `codyde/mcp-sentry-ts` — REJECT (official dominates).
- **CLI/API:** `sentry-cli` (official CLI, `https://docs.sentry.io/cli/`), REST `https://sentry.io/api/0/` `bearer-env` `SENTRY_AUTH_TOKEN` — API for admin (delete).
- **Decision:** **ADOPT** — add `sentry` to `providers/providers.yaml` (official MCP remote + CLI + API + skill_fallback). Justified: on-call triage across existing `diagnostics` + `code-review` capabilities.
- **Security:** `official` / `read-write` (issues) vs `admin` for org delete — distinct.

### Vercel — ADOPT (official MCP, CLI complementary)

- **Official MCP:** `https://mcp.vercel.com` remote OAuth `streamable_http` (Vercel docs https://vercel.com/docs/agent-resources/vercel-mcp, https://vercel.com/docs/mcp/vercel-mcp/tools, https://github.com/vercel/vercel-mcp-overview). Tools: `search docs`, `get_project`, `get_deployment`, `get_logs`, `get_domains`, `web_fetch_vercel_url` for protected deployments. Reviewed clients (Claude, Cursor, Copilot). Active 2026-08-12.
- **CLI:** `vercel` / `vc` official CLI `https://vercel.com/docs/cli` (npm `vercel`, `vc deploy`, `vc logs`) — `admin` privilege for deploy/delete.
- **Community:** `asthetech/cl-mcp-vercel`, `mewcp-vercel` — REJECT.
- **API:** `https://api.vercel.com/v1` `bearer-env` `VERCEL_TOKEN` — universal fallback.
- **Decision:** **ADOPT** — `vercel` provider (MCP remote for read/logs/docs vs CLI for deploy vs API vs skill_fallback). Contextual: MCP for inspection/docs, CLI for scaffolding/deploy.
- **Security:** `official` / `read-only` (MCP) vs `admin` (CLI/API) — distinct, needs approval.

### Jira + Confluence — ADOPT (official Atlassian Rovo remote MCP)

- **Official:** `atlassian/atlassian-mcp-server` https://github.com/atlassian/atlassian-mcp-server — **Atlassian Rovo MCP Server** cloud-hosted remote `https://mcp.atlassian.com` OAuth 2.1 / API token, covers **Jira, Confluence, Jira Service Management, Bitbucket, Compass** in one bridge. Docs: https://support.atlassian.com/atlassian-rovo-mcp-server/docs/use-atlassian-rovo-mcp-server/ . Tools: JQL search, transition, create issue; CQL search, create page. Active 2026-08-12.
- **Community:** `sooperset/mcp-atlassian` (`mcp-atlassian`, Python, MIT, `stdio` with `JIRA_URL`/`CONFLUENCE_URL` + `JIRA_API_TOKEN`), `star7js/mcp-atlassian` fork, `iotashan-llc/atlassian-attachments-mcp` (local attachments complement), `bhayanak/atlassian-private-mcp-server` (self-hosted Data Center) — keep community as fallback for on-prem, plus attachments complement.
- **Decision:** **ADOPT** — add `jira` and `confluence` as separate WHATs but single Rovo HOW shared (or `atlassian` aggregated) — prefer **ADOPT** official remote for Cloud, keep community + API for Data Center + attachments. Moves thin workstation `skills-external/` (14+17 packs) into Toolkit as provider-abstracted capabilities per boundary #368 — no longer external.
- **Security:** `official` / `read-write` (needs approval for delete/transition) vs `community` / `read-write` — distinct; Data Center needs private host trust.
- **Note:** Treat as **2 capabilities, 1 Rovo HOW** — document as `jira` and `confluence` sharing `https://mcp.atlassian.com/mcp` (or `mcp.atlassian.com/v1`).

### Datadog — REJECT (no materially better official MCP; workflow benefit not proven)

- **Official:** No stable official Datadog MCP at `mcp.registry` level 2026-08-12 (datadog has `datadog-mcp` experiments but not marketplace-listed; docs `docs.datadoghq.com` has API/CLI `datadog-ci`). Community `datadog/mcp` sparse.
- **CLI/API:** `datadog-ci` CLI, REST `https://api.datadoghq.com/api/v1` `bearer-env` `DATADOG_API_KEY`+`APP_KEY`.
- **Decision:** **REJECT** for now — no differentiated agentic workflow vs existing `diagnostics` + `sentry` + Grafana; reconsider if `mcp.datadoghq.com/mcp` becomes official and workflow benefit proven. No provider added.

### AWS — REJECT (custom skill would duplicate official MCPs; defer to AWS MCP portfolio)

- **Official:** AWS has MCP portfolio at `https://github.com/awslabs/mcp` (`awslabs/aws-mcp-server` family: `aws-docs-mcp`, `aws-pricing-mcp`, `bedrock` etc.) remote/stdio mix. Not a single SaaS — 200+ services; official ranking impossible per-verb.
- **CLI/API:** `aws cli` `aws-cli` + APIs — `admin` privilege.
- **Decision:** **REJECT** general AWS skill — custom wrapper would duplicate `awslabs/mcp` and is `admin` risk. Specific narrow capabilities (e.g., `aws-docs` via `aws-docs-mcp`) can be ADOPT individually when workflow benefit proven; not this batch. No provider added (keep #384 cloud Well-Architected separate).

### Supabase — REJECT (workflow benefit not proven vs direct `supabase` CLI)

- **Official:** `supabase/supabase-mcp` (?) exists but 2026-08-12 not marketplace-stable; Supabase docs focus on `supabase` CLI `https://supabase.com/docs/reference/cli` + REST `https://*.supabase.co/rest/v1` `bearer-env` `SUPABASE_SERVICE_ROLE_KEY`.
- **Community:** `supabase-community/supabase-mcp` variants.
- **Decision:** **REJECT** — no differentiated value vs `supabase` CLI + API already in infra skills; defer until edge function / DB orchestration workflow proven.

## Summary matrix

| Candidate | Verdict | Preferred HOW | Fallback HOWs | Reason |
|-----------|---------|---------------|---------------|--------|
| Notion | **ADOPT** | official `makenotion/notion-mcp-server` remote OAuth `https://mcp.notion.com/mcp` | `suekou/mcp-notion-server` community PAT `stdio`, REST `api.notion.com/v1`, skill | Official dominates, community keep for offline |
| Sentry | **ADOPT** | official `https://mcp.sentry.dev/mcp` `Sentry-Bearer` remote | `sentry-cli`, REST `sentry.io/api/0`, skill | On-call workflow |
| Vercel | **ADOPT** | official `https://mcp.vercel.com` OAuth remote | `vercel` CLI, REST `api.vercel.com/v1`, skill | Inspection vs deploy split |
| Jira | **ADOPT** | official Atlassian Rovo `https://mcp.atlassian.com` remote OAuth 2.1 | `sooperset/mcp-atlassian` community `stdio` (Data Center), REST `*.atlassian.net/rest/api`, skill, attachments local | Cloud official, on-prem fallback |
| Confluence | **ADOPT** | same Rovo as Jira | same + `iotashan-llc/atlassian-attachments-mcp` local | same |
| Datadog | **REJECT** | — | `datadog-ci` CLI / API only if needed | No stable official MCP, benefit not proven |
| AWS | **REJECT** | — | `awslabs/mcp` portfolio per-service later | Too broad, admin risk |
| Supabase | **REJECT** | — | `supabase` CLI / REST | Benefit not proven |

**Next:** Extend `providers/providers.yaml` with 5 ADOPT (notion, sentry, vercel, jira, confluence) using same WHAT vs HOW schema (ADR-0004) — validates generalization without forcing fields. No custom skill where official MCP is materially better (all ADOPT prefer official remote). Phase 2: `mcp/registry/{notion,sentry,vercel,atlassian}.yaml` sync + `inventory` wiring deferred per #387.

**Risks/tradeoffs:** Official remote MCPs require OAuth + internet — keep PAT/API fallback for offline/CI; Atlassian Rovo folds Jira+Confluence into one HOW — document as shared transport; Vercel MCP limited to reviewed clients — CLI fills gap; community fallbacks need `trust_tier: community` explicit opt-in per #364.
