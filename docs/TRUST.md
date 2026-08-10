# Trust and Security for Consumers

This guide explains what agent-toolkit installs on your machine, how to verify
it, and where to report security concerns. For vulnerability disclosure, see
[SECURITY.md](../SECURITY.md).

---

## What gets installed

Depending on your install method, agent-toolkit may deploy:

| Artifact | Typical location | Contains secrets? |
|----------|------------------|-------------------|
| Skill instructions | Tool-specific skills/rules dirs | No |
| Agent personas | `~/.claude/agents/`, `.cursor/rules/`, etc. | No |
| Plugin manifests | Marketplace-managed | No |
| MCP templates | Referenced from docs; you add credentials locally | Placeholders only |
| CLI metadata | `~/.config/agent-toolkit/` | No |

**Credentials never ship in the repository.** MCP templates use `${ENV_VAR}`
placeholders. You provide tokens via your shell or tool config.

---

## Verify your install

```bash
# Detect installed profiles and tools
agent-toolkit doctor

# List canonical capabilities (skills, agents, products)
agent-toolkit inventory

# Validate skill definitions from a git checkout
bash scripts/validate-skills.sh
```

After marketplace or CLI install, open your AI tool and confirm loaded skills
match what you expect. Unrecognized rules or agents may indicate a partial
install or conflicting older profile.

---

## Installation receipts

The installer receipt module (`agent_toolkit.installer.receipt`) defines a
JSON schema for recording what was installed:

- **Location:** `~/.config/agent-toolkit/receipts/<target>-<product>.json`
- **Fields:** product, target, version, file paths, content digests
- **Secrets:** always empty (`secrets: []`)

Receipts are written by `agent-toolkit install` / `update` and consumed by
`agent-toolkit uninstall` / rollback. Lifecycle tests cover create, save, load,
and uninstall-by-receipt.

Example shape (illustrative):

```json
{
  "schemaVersion": 1,
  "product": "agent-toolkit-core",
  "target": "cursor",
  "version": "1.2.0",
  "artifacts": [
    { "path": "~/.cursor/rules/code-reviewer.mdc", "digest": "sha256:…", "ownership": "created" }
  ],
  "secrets": []
}
```

---

## Safe defaults

agent-toolkit follows these principles (see also
[docs/security/threat-model.md](security/threat-model.md)):

- No API keys, tokens, or passwords in source files
- No private hostnames in distributed configs
- No permission-bypass flags (e.g. skip dangerous-mode prompts) in shipped artifacts
- MCP credentials via environment variables only
- Secret scanning (Gitleaks) and CodeQL Python analysis in CI (`.github/workflows/codeql.yml` — PRs and `main`); Trivy **Planned** (see #260)

---

## Supply chain

| Install method | Trust anchor |
|----------------|--------------|
| `uvx --from agent-toolkit-cli` | PyPI package + [CHANGELOG](../CHANGELOG.md) |
| Claude/Cursor marketplace | GitHub repo `ulises-jeremias/agent-toolkit` |
| `git clone` + manual copy | Pin a commit; review diff before copying |
| Homebrew/AUR | Tap/package maintainer signatures |

Prefer tagged releases or marketplace installs over unreviewed forks.

### Provenance & third-party capabilities (per #364)

Every third-party skill/plugin/MCP declares immutable provenance in its `SKILL.md` frontmatter:

```yaml
upstream:
  repository: anthropics/skills
  path: skills/frontend-design
  ref: abc1234def5678abc1234def5678abc1234def56  # 40-char SHA or tag, never main/master/latest
  license: MIT
trust:
  tier: verified  # first-party | verified | community | experimental
distribution:
  mode: vendored  # vendored | external | generated | native-plugin
  redistribution_allowed: true
security:
  scripts: false
  shell: false
  network: false
```

**Trust tiers:**

| Tier | Meaning | Default install | Auto-update | Permissions gate |
|------|---------|-----------------|-------------|------------------|
| `first-party` | Toolkit-authored | enabled | via Toolkit release | none special |
| `verified` | Well-maintained upstream, reviewed & pinned | enabled | PR with diff + license/security check → human review | declare `security.*` |
| `community` | Useful but not verified | **opt-in** only | manual PR | explicit opt-in + `dangerous_permissions` review |
| `experimental` | Unstable/research | opt-in | manual | human gate required |

**Decision matrix:**

| Situation | Decision | Distribution |
|-----------|----------|--------------|
| Stable, small, MIT/Apache, secure, cross-platform | **ADOPT / VENDORED** pinned SHA | `vendored` |
| Useful but large/license-sensitive/actively maintained/AGPL | **PIN EXTERNALLY** | `external` (Renovate PR, not bundled) |
| Product-native integration materially better | **USE NATIVE PLUGIN/MCP** | `native-plugin` |
| Core knowledge useful but tool-specific | **ADAPT** | ported prompt, new upstream path |
| Stale/redundant/insecure/unclear-license | **REJECT** | — |

Validate locally and in CI:

```bash
python3 scripts/validate-upstream.py --check
python3 scripts/validate-skills.py
agent-toolkit inventory --json | jq .upstream
agent-toolkit doctor  # reports missing provenance / mutable refs
```

See `schemas/upstream.schema.json` and `schemas/skill-md-frontmatter.schema.json` for the canonical model.

---

## Reporting issues

| Concern type | Where to report |
|--------------|-----------------|
| Security vulnerability | [SECURITY.md](../SECURITY.md) — private disclosure only |
| Incorrect/harmful prompt output | GitHub Issues (functionality) |
| Install left unexpected files | GitHub Issues with `agent-toolkit doctor` output |

---

## Related guides

| Guide | Description |
|-------|-------------|
| [UNINSTALL.md](UNINSTALL.md) | Remove installed artifacts |
| [MIGRATION.md](MIGRATION.md) | Change install method safely |
| [INSTALLATION.md](INSTALLATION.md) | Primary install flow |
| [SECURITY.md](../SECURITY.md) | Vulnerability reporting policy |
