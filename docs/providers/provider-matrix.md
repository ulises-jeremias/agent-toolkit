# Provider Capability Matrix — 2026-08-12

**WHAT vs HOW** — capability intent (`what.verbs` + `entities`) is stable; `how` is target- and context-dependent. No universal `plugin > MCP > CLI` ranking.

**Sources (2026-08-12):** Linear MCP (`mcp.linear.app/mcp`, https://linear.app/docs/mcp), Slack `mcp-server-slack` + `slack-cli` (`docs.slack.dev/tools/slack-cli`, `docs.slack.dev/ai/mcp-server`), Figma MCP (`mcp.figma.com/mcp`, https://www.figma.com/developers/mcp), plus Toolkit `mcp/registry/*.yaml` (dated 2026-08-12).

## Summary

| Capability | WHAT (verbs) | Preferred HOW per target | Alternative HOW |
|------------|--------------|--------------------------|-----------------|
| **Linear** | `list, get, create, update, comment, triage, plan` on `issue, project, cycle` | `mcp` `https://mcp.linear.app/mcp` (OAuth, `streamable_http`) for Claude/Cursor/OpenCode — native, no token env | `community_mcp` `@ibraheem4/linear-mcp` (PAT, `stdio`) for single-workspace; `api` `https://api.linear.app/graphql` (admin, needs approval) for `deleteIssue`; `skill_fallback` `skills/integrations/linear` (delegates) |
| **Slack** | `list, post, react, create, deploy, api` on `channel, message, reaction, app` | `mcp` `@anthropic-ai/mcp-server-slack` (Socket Mode, `stdio`, `SLACK_BOT_TOKEN`+`SLACK_APP_TOKEN`) for chat automation — native, low latency | `cli` `slack-cli` (`docs.slack.dev/tools/slack-cli`, `Apache-2.0`, admin, needs approval) for app scaffolding; `api` `https://slack.com/api/chat.postMessage` (direct); `skill_fallback` |
| **Figma** | `get_design_context, get_screenshot, get_metadata, implement` on `file, node, component` | `mcp` `https://mcp.figma.com/mcp` (OAuth, `streamable_http`, `FIGMA_OAUTH_TOKEN`+`FIGMA_REGION`) for design-to-code — remote, read-only, low context | `api` `https://api.figma.com/v1/files/:file_key` (PAT, read-only); `api` `figma plugin API` (write, Figma Desktop, needs approval); `skill_fallback` `skills/design/figma` |

## Detailed per-HOW evaluation

### Linear

| HOW | Mechanism | Targets | Auth | Read | Write | Destructive | Trust / Privilege | Runtime | Maintenance | Notes |
|-----|-----------|---------|------|------|-------|-------------|-------------------|---------|-------------|-------|
| `linear-mcp-official` | `mcp` `https://mcp.linear.app/mcp` | claude-code, cursor, opencode, windsurf, vscode | `oauth` (browser, no env) | `list_issues`, `get_issue`, `list_projects`, `list_cycles` | `create_issue`, `update_issue`, `create_comment` | — | `official` / `read-write` (separate — highly trusted source but can create/update, no delete) | remote, browser OAuth, medium latency, low context, offline `false` | active 2026-08-12 | Preferred for most |
| `linear-mcp-community-pat` | `community_mcp` `@ibraheem4/linear-mcp` | claude-code, cursor, opencode | `api_key` `LINEAR_API_KEY` | `list_issues` etc. | `create_issue`, `update_issue` | — | `community` / `read-write` | local `stdio`, low latency | community 2026-08-12 | PAT fallback |
| `linear-api-graphql` | `api` `https://api.linear.app/graphql` | universal | `api_key` `LINEAR_API_KEY` (admin scopes) | GraphQL queries | `createIssue`, `updateIssue` | `deleteIssue` (admin) | `official` / `admin` (needs approval) | remote `https`, none context | active | Most powerful, needs approval |
| `linear-skill-fallback` | `skill_fallback` `skills/integrations/linear` | universal | `oauth` | via MCP | via MCP | — | `first-party` / `read-only` | hybrid (delegates) | active | Skill instructs MCP workflow |

*Provider choice is contextual:* OAuth MCP for team workspaces (no token env) vs PAT MCP for solo/single-workspace vs API for admin/delete.

### Slack

| HOW | Mechanism | Targets | Auth | Read | Write | Destructive | Trust / Privilege | Runtime | Notes |
|-----|-----------|---------|------|------|-------|-------------|-------------------|---------|-------|
| `slack-mcp-official` | `mcp` `@anthropic-ai/mcp-server-slack` | claude-code, cursor, opencode, vscode | `bearer-env` `SLACK_BOT_TOKEN`, `SLACK_APP_TOKEN` | `conversations_history` etc. | `chat_post_message`, `reactions_add` | — | `official` / `read-write` | local `stdio` Socket Mode, low latency | Chat automation |
| `slack-cli-official` | `cli` `slack-cli` (`docs.slack.dev/tools/slack-cli`, Apache-2.0) | universal | `oauth` | `slack list`, `slack api conversations.list` | `slack create`, `slack deploy` | `slack delete` (admin) | `official` / `admin` (needs approval) | local CLI, OAuth | App dev |
| `slack-api-web` | `api` `https://slack.com/api/chat.postMessage` | universal | `bearer-env` `SLACK_BOT_TOKEN` | `conversations.history` | `chat.postMessage` | — | `official` / `read-write` | remote `https` | Direct |
| `slack-skill-fallback` | `skill_fallback` | universal | `bearer-env` | via delegates | via delegates | — | `first-party` / `read-only` | hybrid | Skill |

*Chat automation prefers MCP (native, low latency). App scaffolding prefers CLI (admin). No universal ranking.*

### Figma

| HOW | Mechanism | Targets | Auth | Read | Write | Destructive | Trust / Privilege | Runtime | Notes |
|-----|-----------|---------|------|------|-------|-------------|-------------------|---------|-------|
| `figma-mcp-official` | `mcp` `https://mcp.figma.com/mcp` | claude-code, cursor, opencode, vscode | `bearer-env` `FIGMA_OAUTH_TOKEN`, `FIGMA_REGION` | `get_design_context`, `get_screenshot` etc. | — | — | `official` / `read-only` | remote `streamable_http`, OAuth | Preferred for design-to-code |
| `figma-rest-api` | `api` `https://api.figma.com/v1/files/:file_key` | universal | `bearer-env` `FIGMA_PERSONAL_ACCESS_TOKEN` | `GET files, nodes` | — | — | `official` / `read-only` | remote `https` | Fallback |
| `figma-plugin-api` | `api` `figma plugin API` | figma-plugin | `none` | `read node` | `create frames` etc. (plugin only) | — | `official` / `read-write` (needs approval) | local Figma Desktop | Write, needs Figma plugin |
| `figma-skill-fallback` | `skill_fallback` `skills/design/figma` | universal | `bearer-env` | via MCP | — | — | `first-party` / `read-only` | hybrid | Skill |

*Read-only design context prefers MCP (remote, low context). Write via plugin needs Figma Desktop + approval.*

## Security — source trust vs runtime privilege (distinct)

| Capability | Source trust (who vouches) | Runtime privilege (what it can do) | Separate? |
|------------|----------------------------|-------------------------------------|-----------|
| Linear official MCP (`mcp.linear.app`) | `official` (Linear) — highly trusted as source | `read-write` (create/update, no delete) — needs no approval for normal, approval for bulk/destructive | Yes — trusted source but still bounded privilege |
| Slack CLI (`slack-cli`, `docs.slack.dev`) | `official` — highly trusted | `admin` (can delete apps, admin scopes) — requires approval even though source is trusted | Yes |
| Figma MCP (`mcp.figma.com`) | `official` — highly trusted | `read-only` — cannot mutate files | Yes — high trust but low privilege |

Reuse existing Toolkit `security` declarations (`scripts/audit-capability.py` surface, `mcp/registry/*.yaml` `security` + `approval` fields) rather than a new framework.

## Minimal provider model (recurring fields after 3 pilots)

After Linear + Slack + Figma, the genuinely common fields are:

```yaml
id, display_name, purpose
what: {verbs[], entities[]}
how[]: {id, mechanism, targets[], package, repository, license, transport, provenance, version_policy,
        auth: {type, env[], scopes[]},
        read[], write[], destructive[],
        permissions: {source_trust, runtime_privilege, requires_approval},
        runtime: {local_vs_remote, sandbox, latency, context_overhead, offline},
        availability: {maintenance, cross_agent[], native_ux}}
evaluation: {notes}
security: {source_trust, runtime_privilege}  # summary, distinct
```

No `official plugin > MCP > CLI` law — provider selection is per-capability and per-target (e.g., Linear OAuth MCP for Claude vs PAT MCP for solo vs API for admin).

See `providers/providers.yaml` (machine-readable) and `schemas/provider.schema.json` (validation).
