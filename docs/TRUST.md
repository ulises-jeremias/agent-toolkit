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
./scripts/validate-skills.vsh
```

After marketplace or CLI install, open your AI tool and confirm loaded skills
match what you expect. Unrecognized rules or agents may indicate a partial
install or conflicting older profile.

---

## Installation receipts

The installer receipt module (`agent_toolkit.installer.receipt` / V
`agent_toolkit_core`) records what was installed. The **compatibility schema**
is published at [`schemas/install-receipt.schema.json`](../schemas/install-receipt.schema.json)
(issue [#511](https://github.com/ulises-jeremias/agent-toolkit/issues/511)):

- **Location:** `~/.config/agent-toolkit/receipts/<target>-<product>.json`
- **schemaVersion:** `1` only
- **Fields:** product, target, scope, version, installedAt, sourceDigest, artifacts, configPatches, secrets
- **Secrets:** always empty (`secrets: []`)
- **Ownership:** `created` (uninstall removes) or `merged` (preserved)
- **Safety:** artifact paths must not contain `..` segments

Receipts are written by `agent-toolkit install` / `update` and consumed by
`agent-toolkit uninstall` / rollback. Lifecycle tests cover create, save, load,
and uninstall-by-receipt; schema tests live in `tests/test_install_receipt_schema.py`.

Example shape (illustrative):

```json
{
  "schemaVersion": 1,
  "product": "agent-toolkit-core",
  "target": "cursor",
  "version": "1.2.0",
  "artifacts": [
    { "path": "/home/user/.cursor/rules/code-reviewer.mdc", "digest": "deadbeefcafebabe", "ownership": "created" }
  ],
  "configPatches": [],
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

> **Canonical artifact:** the native V binary from a GitHub Release (`agent-toolkit-<os>-<arch>`, plus `SHA256SUMS` + `manifest.json` per ADR-018/ADR-022). All other channels are **distribution adapters** or **downstream packages** that fetch or wrap that canonical artifact. V is canonical; Python (`agent-toolkit-cli` on PyPI) is a thin launcher (ADR-021) — this repository does not treat Python or shell scripts as the core runtime.

### Installation channels

| Channel | Artifact | Build / Sign | Support level | Trust anchor | Verify |
|---------|----------|--------------|----------------|--------------|--------|
| GitHub Releases | native V binary (`agent-toolkit-<os>-<arch>`, `SHA256SUMS`, `manifest.json`, `sbom.cyclonedx.json`) | `.github/workflows/release.yml` (OIDC, `SHA256SUMS` + `manifest.json` per ADR-022) | officially supported · security-supported | GitHub Release assets + `SHA256SUMS`; see `docs/RELEASING.md` | `curl -fsSL -O https://github.com/ulises-jeremias/agent-toolkit/releases/download/<tag>/SHA256SUMS && sha256sum -c SHA256SUMS --ignore-missing` |
| PyPI `agent-toolkit-cli` | launcher wheel (`packages/pypi/agent-toolkit-cli`, ADR-021) | `release.yml` `publish-pypi` via PyPI Trusted Publishing (OIDC env `pypi`) | officially supported · security-supported | PyPI OIDC + `uv`/`pip` metadata | `uv tool install agent-toolkit-cli && agent-toolkit --version` · `pip show agent-toolkit-cli` |
| npm `agent-toolkit-cli` | `packages/npm/*` wrappers (`agent-toolkit-cli`, `agent-toolkit-cli-<platform>`, ADR-025) | `publish-npm.yml` via npm Trusted Publishing (OIDC `id-token: write`) | officially supported | npm registry OIDC + `optionalDependencies` pins | `npm view agent-toolkit-cli version && npm view agent-toolkit-cli optionalDependencies` |
| Homebrew `homebrew-tap` | Formula `agent-toolkit.rb` fetching GitHub Release V binary (ADR-018 floating names) | `ulises-jeremias/homebrew-tap` (Formula `url` + `sha256`, built from Release) | downstream maintained · best effort | Homebrew Formula signature; maintainer `HOMEBREW_TAP_TOKEN` | `brew info agent-toolkit && gh run list --repo ulises-jeremias/homebrew-tap --limit 3` |
| AUR `agent-toolkit-bin` | PKGBUILD sourcing GitHub Release V binary + `SHA256SUMS` | `ulises-jeremias/aur-packages` (PKGBUILD) | downstream maintained · best effort | AUR package metadata | `yay -Si agent-toolkit-bin && gh run list --repo ulises-jeremias/aur-packages --limit 3` |
| GHCR `ghcr.io/ulises-jeremias/agent-toolkit` | container image wrapping GitHub Release V binary | `.github/workflows/docker.yml` (reusable job on Release) | officially supported · best effort (experimental) | GHCR signature + Docker metadata | `docker pull ghcr.io/ulises-jeremias/agent-toolkit:<tag> && docker run --rm ghcr.io/ulises-jeremias/agent-toolkit:<tag> agent-toolkit --version` |
| Claude marketplace | `plugins/*/plugin.json` (`agent-toolkit-core`, `agent-toolkit-agents`, `agent-toolkit-forge`) | `.github/workflows/release.yml` + `plugins/*` compiler output | officially supported | Claude marketplace manifest (`plugin.json`) + GitHub repo | `/plugin marketplace add ulises-jeremias/agent-toolkit` → `/plugin install agent-toolkit-core@agent-toolkit` |
| Cursor marketplace | `plugins/*/plugin.json` + `.cursor-plugin/marketplace.json` (Cursor plugin) | `release.yml` + `plugins/*` | officially supported | Cursor marketplace manifest | `cursor-agent` → `/plugin` → install `agent-toolkit-core` |
| Agent Plugins artifacts | portable `plugin.json` + `skills/` + `mcp.json` (Agent Plugins 1.0) | `agent_toolkit.compiler.targets.agent_plugins` (`build` → `plugins/*`) | officially supported | `agent-plugins.org` schema + `schemas/agent-plugins/1.0.0/*.schema.json` | `agent-toolkit build && ./scripts/validate-agent-plugins.vsh --check` |

> **Adapters vs downstream:** PyPI/npm/marketplaces/Agent Plugins are **distribution adapters** that wrap the canonical artifact; Homebrew/AUR are **downstream packages** that fetch the canonical artifact from the Release. Never publish an adapter without a published canonical artifact.

Prefer tagged releases or marketplace installs over unreviewed forks. Single matrix source: this section. See also `SECURITY.md#Supported Versions`, `docs/RELEASING.md` (canonical artifact), `distribution/README.md`, and `docs/INSTALLATION.md`.

### Legacy table (kept for compatibility)

| Install method | Trust anchor |
|----------------|--------------|
| `uvx --from agent-toolkit-cli` | PyPI package + [CHANGELOG](../CHANGELOG.md) |
| Claude/Cursor marketplace | GitHub repo `ulises-jeremias/agent-toolkit` |
| `git clone` + manual copy | Pin a commit; review diff before copying |
| Homebrew/AUR | Tap/package maintainer signatures |

### Provenance & third-party capabilities (per #364) — P0 foundation

**Architecture per ADR-0001 (PR #403 — external provenance lock, accepted 2026-08-11):**

```text
CAPABILITY DECLARATION        — “What is this capability and what external sources does it intend to use?”
        ↓ resolution              SKILL.md frontmatter (origin, sources/upstream, trust, maintenance, distribution, security)
EXTERNAL PROVENANCE LOCK      — “What exact immutable external artifacts were resolved?”
        ↓ integrity verification  capabilities/upstream.lock v2: capability ID → source ID → {requested, resolved {commit, content_checksum, body_checksum, license, resolved_at}, provenance_digest}
VENDORED / EXTERNAL STATE     — “What bytes/package/plugin actually correspond to that resolution?”
        ↓ generation             skills/<domain>/<name>/SKILL.md (Toolkit frontmatter + **literal upstream body**) + LICENSE (+ siblings)
TARGET SURFACES               — “How Claude/Cursor/Copilot/OpenCode/etc. consume the capability”
                                 plugins/*, catalogs/*, docs/UPSTREAM.md (generated from declaration+lock)
```

> **Lock is a resolution artifact, not a second capability catalog.** It is sparse — only `origin: upstream` capabilities with external content appear; `first-party` never appears. Runtime package resolution (`uv.lock`, `pnpm-lock.yaml`, Docker digest) stays in ecosystem locks, not `upstream.lock`. See `docs/adrs/0001-capability-declaration-and-external-provenance-lock.md` and `schemas/upstream-lock.schema.json`.

Validation is offline/deterministic: `SKILL.md` + committed `capabilities/upstream.lock` + vendored bytes are enough for `python3 scripts/provenance.py check` (schema, SHA40, SPDX, content_checksum vs bytes, **body_checksum fidelity**, provenance_digest, orphan/missing, review binding). Network is only for scheduled/manual `updates` / `updates --apply`; normal PR CI never requires network.

**Fidelity invariant (vendored):** Local `SKILL.md` body (everything after the closing `---`) must be **byte-identical** to upstream at the resolved commit. Only Toolkit overlay keys differ in frontmatter (`origin`, `sources`/`upstream`, `trust`, `maintenance`, `distribution`, `security`, `updates`). Sibling files from the upstream skill path are copied verbatim. Lock field `resolved.body_checksum` proves body identity offline.

**Implemented now (in #399):** Explicit origin classification + immutable provenance in `SKILL.md` frontmatter, validated via `scripts/validate-upstream.py` (`origin.type` required, 40-char SHA, SPDX subset — `schemas/upstream.schema.json`).

**Implemented now (in #403):** `capabilities/upstream.lock` v2 as external provenance lock (separate schema `schemas/upstream-lock.schema.json`, deterministic `scripts/provenance.py lock` / `check` / `docs`). Validation is in `.github/workflows/validate.yml` (`validate-upstream` + `provenance check` + `lock --check` + `docs --check`).

**Implemented now (closes #428):** Path-scoped / semver-tag discovery via `scripts/provenance.py updates`; `--apply` rewrites vendored skills to literal upstream bodies + Toolkit frontmatter, regenerates lock + `docs/UPSTREAM.md`, and sets `trust.tier: experimental` (drops `reviewed_provenance`) until human re-binds. Weekly `.github/workflows/update-upstream.yml` opens a **draft** PR (never auto-merges).

**AGPL note:** MegaLinter coding-agent skills are vendored under AGPL-3.0 with per-skill `LICENSE` (aggregation). See `docs/megalinter/AGPL-VENDING.md`.

**Planned in #387:** `agent-toolkit inventory` and `doctor` provenance wiring (display `sources`/`provenance_digest`, warn on stale pins, missing provenance). Until #387, provenance is visible via `scripts/provenance.py check` and frontmatter inspection only.

#### Canonical source table

| Data                           | Canonical source                           |
| ------------------------------ | ------------------------------------------ |
| Capability behavior            | `SKILL.md` / capability declaration        |
| Capability ID                  | declaration / catalog identity (`design/frontend-design`) |
| Origin                         | declaration (`origin.type`)                |
| Source intent (`requested` ref)| declaration (`upstream`/`sources`)         |
| Trust status                   | declaration (`trust`)                      |
| Security declaration           | declaration (`security`)                   |
| Distribution policy            | declaration (`distribution`)               |
| Requested upstream version/ref | declaration (`upstream.ref` / `sources[].ref`) |
| Resolved commit                | `capabilities/upstream.lock` (`resolved.commit`) |
| Content checksum               | `capabilities/upstream.lock` (`resolved.content_checksum`) |
| Body checksum (fidelity)       | `capabilities/upstream.lock` (`resolved.body_checksum`) |
| Observed resolved license      | `capabilities/upstream.lock` (`resolved.license`) |
| Resolution timestamp           | `capabilities/upstream.lock` (`resolved.resolved_at`) |
| Provenance digest              | `capabilities/upstream.lock` (`provenance_digest`) + declaration `trust.reviewed_provenance` binding |
| Product membership             | `distributions/products.yaml`              |
| Generated catalogs             | `catalogs/*` generator output              |
| Target plugin copies           | `agent-toolkit build` / `plugin sync` output |
| Runtime package versions       | ecosystem-specific lock (`uv.lock`, etc.)  |

**Review lifecycle:** `provenance_digest = hash(source IDs + resolved commits + content_checksum + license spdx)`. Human review sets `trust.reviewed_provenance = provenance_digest`. Updating `capabilities/upstream.lock` to new commit/checksum/license changes the digest → existing `reviewed_provenance` mismatch → `provenance.py check` fails with *review binding invalid* until declaration is re-audited and `trust.reviewed_provenance` (and `reviewed_at`/`reviewed_by`) are updated. This elegantly separates lock resolution from human trust state (see ADR-0001 §13-14).

**Security lifecycle:** Declarations keep `security: {scripts, shell, network, mcp, hooks, dangerous_permissions, cve_policy}` as enforceable policy. Update tooling recomputes detected signals (`scripts/audit-capability.vsh`) and compares to declarations; a PR that introduces `shell: true` where declaration said `shell: false` fails or requires explicit declaration change + review. License policy vs observed: declaration `upstream.license` is expected `spdx: Apache-2.0`; lock `resolved.license.spdx` is observed. CI detects `expected vs observed` drift.

Every `SKILL.md` must have an explicit origin — no inference from path or absence (gate 2):

```yaml
origin:
  type: first-party  # or upstream
```

For `first-party`, no provenance is allowed. For `upstream`, one or more sources are required (gate 9).

#### inspired_by vs vendored lock

First-party skills may record upstream inspiration without vendoring:

```yaml
origin:
  type: first-party
metadata:
  inspired_by:
    - repository: cursor/plugins
      path: fix-ci/skills/fix-ci
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: CI log triage patterns absorbed into gh-fix-ci
```

| Mechanism | When | Provenance lock | Body fidelity |
|-----------|------|-----------------|---------------|
| **Vendored upstream** | Literal copy of portable third-party skill | Required in `capabilities/upstream.lock` | Body byte-identical to upstream |
| **inspired_by** | First-party skill enhanced with third-party ideas | Not in lock | First-party body; attribution in frontmatter only |

See [UPSTREAM_VS_FIRST_PARTY.md](UPSTREAM_VS_FIRST_PARTY.md) for the decision matrix.

#### First-party example

```yaml
---
name: assistant
description: Assistant — scan README→docs→AGENTS before code; cite sources.
origin:
  type: first-party
---
```

#### Single-source upstream (Anthropic frontend-design — Apache-2.0 verified 2026-08-11)

```yaml
---
name: frontend-design
description: Distinctive, intentional visual design (Anthropic).
origin:
  type: upstream
upstream:
  repository: anthropics/skills
  path: skills/frontend-design
  ref: f17010c9bb483898c1d9c9f42dde2b3a98889434  # full 40-char SHA, never short SHA (gate 1)
  license: Apache-2.0  # SPDX subset (gate 6) — verified 2026-08-11: LICENSE.txt Apache-2.0, not MIT
trust:
  tier: reviewed  # gate 5: 'reviewed' replaces 'verified' (verified is deprecated alias)
  reviewed_at: "2026-08-11"
  reviewed_by: ulises-jeremias
maintenance:
  status: active  # gate 4: independent of trust tier
  last_activity: "2026-08-07"
distribution:
  mode: vendored  # gate 8: mutually exclusive delivery channel (see semantics below)
  redistribution_allowed: true
security:
  scripts: false
  shell: false
  network: false
  cve_policy: not-applicable  # gate 4: for pure instruction assets, not package CVE
---
```

#### Multi-source upstream (Vercel web-design-guidelines — gate 9)

One capability may derive from multiple artifacts. Use `sources` with `role`:

```yaml
origin:
  type: upstream
sources:
  - role: wrapper
    repository: vercel-labs/agent-skills
    path: skills/web-design-guidelines
    ref: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a
