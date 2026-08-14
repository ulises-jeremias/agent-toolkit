---
name: supply-chain-audit
description: Inspect agent supply chain — skills/plugins/MCP/npm/py packages, hooks, scripts, remote prompts,
  provenance, version pins, hashes, licenses, network and dangerous permissions — before adopting.
origin:
  type: first-party
trust:
  tier: first-party
distribution:
  mode: vendored
  redistribution_allowed: true
security:
  scripts: false
  shell: false
  network: false
  mcp: []
  hooks: []
  dangerous_permissions: []
  cve_policy: not-applicable
requires: []
produces:
- supply-chain-report.md
tools:
- claude-code
- cursor
- opencode
- copilot-cli
- universal
triggers:
- audit supply chain
- inspect skill provenance
- check plugin security
- review MCP packages
---
# Supply-Chain Audit

Inspect a capability's supply chain **before** adopting — validate provenance, pins, hashes, licenses, network, and permissions.

## Use when

- Reviewing a PR that vendors a new third-party skill/plugin/MCP
- Deciding ADOPT vs PIN EXTERNALLY vs REJECT for an upstream
- Auditing existing `skills/`, `mcp/registry/`, `plugins/`, hooks, or npm/py deps

## Inputs

- Capability path (e.g., `skills/design/frontend-design/`, `mcp/registry/github.yaml`, `plugins/agent-toolkit-core/.claude-plugin/plugin.json`)
- Optional: `capabilities/upstream.lock` or `SKILL.md` frontmatter `upstream` block

## Steps

### 1. Provenance

Check `upstream: {repository, path, ref, license}`:
- `ref` must be immutable tag or 40-char SHA — never `main`/`master`/`latest`
- `license` must be SPDX or `unknown` (if unknown → prefer PIN EXTERNALLY, document why)
- Compare `ref` to upstream latest (`gh api repos/<owner>/<repo>/commits` or `git ls-remote`) — flag drift
- For vendored content, verify `LICENSE.txt`/`NOTICE` preserved alongside

**Host users:** apply the checks above by reading `SKILL.md` frontmatter and `capabilities/upstream.lock` (when present). Do **not** rely on repo-root `scripts/` — those paths are not installed with the toolkit.

**Maintainer / repo checkout / CI only:**

```bash
python3 scripts/validate-upstream.py --check
python3 scripts/validate-upstream.py --strict  # flags missing provenance for third-party-looking paths
```
### 2. Version pins & hashes

- MCP: `mcp/registry/*.yaml` `package` must be pinned (tag/SHA), not `latest`
- npm/py: `package.json`/`pyproject.toml` pins, no unpinned `*`
- Docker (MegaLinter): image `sha256:` pinned
- Hooks: `command` array, no `curl | bash`, no `npx` without pin
- Check for `capabilities/upstream.lock` or embedded `checksum` (per #370) if available

### 3. Licenses & redistribution

- Verify `upstream.license` matches repo LICENSE (check `gh api repos/<owner>/<repo>/license` and per-subdir LICENSE if ambiguous — e.g., `nextlevelbuilder/ui-ux-pro-max-skill` gallery/cli)
- If AGPL (e.g., `oxsecurity/megalinter`) → prefer PIN EXTERNALLY, not vendored (avoid MIT contagion)
- Document `distribution.redistribution_allowed` and `attribution_file`

### 4. Security surface (static, never exec untrusted code)

Scan for:

```
shell execution: sh -c, bash, curl, wget, npx, npm, pip, uv, docker run
network: curl/wget/fetch, raw.githubusercontent.*main, npx download
MCP: mcp/registry auth.env secrets not values, remote vs local servers, OAuth
env: credentials exposure, .env.example vs .env, secrets: [] in receipts
filesystem: writes outside workspace, destructive mv/rm -rf
git: hooks, subagents, default-branch push
hooks: blocking/destructive classification per schemas/hook.schema.yaml
```

**Host users:** perform the static scan with Grep/Read against the patterns above (do not execute untrusted code). Cite `file:line` evidence in the report.

**Maintainer / repo checkout / CI only** (repo-root tooling is not on the host install):

```bash
v run scripts/audit-capability.vsh <path>            # per-capability
v run scripts/audit-capability.vsh skills/ mcp/      # whole repo
```
### 5. Trust tier & recommendation

Map to tiers from `docs/TRUST.md`:

| Tier | Gate |
|------|------|
| `first-party` | passes, no special gate |
| `verified` | ALLOW with PR diff + license/security check → human review |
| `community` | CAUTION — require explicit opt-in, review `dangerous_permissions` |
| `experimental` | BLOCK default — require isolated test |

Emit recommendation: **ALLOW** / **CAUTION** / **BLOCK** with evidence citations.

## Outputs

- `supply-chain-report.md`:

```md
## Supply-chain report — <capability>
- Provenance: repo/path@ref (SHA), license SPDX, checksum
- Pins: versions/hashes (pinned vs mutable)
- Licenses: SPDX, redistribution_allowed, attribution_file
- Security surface: scripts/shell/network/mcp/hooks/dangerous_permissions (list + lines)
- Trust tier: first-party|verified|community|experimental
- Recommendation: ALLOW|CAUTION|BLOCK — rationale with line citations
```

## Human gates

- Never auto-merge PRs with `security.shell: true` or `network: true` or `mcp: [community]` without review
- Secrets via `${ENV_VAR}` placeholders only — never log values

## Related

- `docs/TRUST.md#provenance` (schema + matrix)
- `schemas/upstream.schema.json`, `schemas/skill-md-frontmatter.schema.json`
- Repo checkout/CI only: `scripts/validate-upstream.py`, `scripts/audit-capability.vsh` (not installed on host)
- `skills/agentic-security/mcp-audit` (MCP-specific)
- `skills/agentic-security/owasp-agentic-review` (agentic threats)
