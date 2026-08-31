# Security Policy

> **Consumers:** see [docs/TRUST.md](docs/TRUST.md) for install verification, receipts,
> and what files the toolkit writes on your machine.

## Supported Versions

> **Single matrix:** see [`docs/TRUST.md#Installation channels`](docs/TRUST.md#installation-channels) for the full channel table (GitHub Releases, PyPI, npm, Homebrew, AUR, GHCR container, Claude/Cursor marketplaces, Agent Plugins artifacts) with trust anchor, support level, and verification command. `SECURITY.md` and `docs/TRUST.md` are the single sources for the channel matrix and must agree.

This project ships **semver-tagged GitHub Releases** (native V binaries — the **canonical artifact**, `agent-toolkit` + `SHA256SUMS` + `manifest.json` per ADR-018/ADR-022) as the canonical distribution channel. The product CLI is the **native V binary**; Python `agent-toolkit-cli` on PyPI is a thin launcher (ADR-021) — Python or shell scripts are not the core runtime.

**Supported channels** (all wrap or fetch the canonical artifact; see matrix): GitHub Releases (canonical artifact), PyPI trampoline, npm, Homebrew tap, AUR, GHCR container, Claude/Cursor marketplaces, Agent Plugins artifacts.

- **GHCR container** and **marketplace artifacts** are built from the same canonical artifact and follow the same supported-version policy.
- **Homebrew/AUR** are downstream packages that fetch the canonical artifact from the Release — they are downstream maintained (best effort) and may lag the Release until their workflow is green (see `docs/RELEASING.md#Downstream publish verification` and `distribution/README.md`).

**Support policy:** **latest released minor only** (e.g. `1.3.x` when `v1.3.0` is latest). Security-supported channels are the canonical artifact + distribution adapters PyPI and npm; Homebrew/AUR are downstream maintained with best-effort security guidance. The previous minor receives best-effort guidance to upgrade; we do not backport patches unless the maintainer announces otherwise. `main` is pre-release and may contain fixes ahead of the next tag.

> **Verification:** use the commands in `docs/TRUST.md#Installation channels` (e.g. `sha256sum -c SHA256SUMS --ignore-missing` for the canonical artifact, `agent-toolkit --version` for adapters). The **canonical artifact** vs **distribution adapter** vs **downstream package** vs **marketplace artifact** distinction is defined in `docs/RELEASING.md` and `docs/TRUST.md` and is used consistently — no contradictory “Python is core” wording.

---

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Please use **GitHub's private vulnerability disclosure** mechanism:

1. Navigate to the repository on GitHub
2. Click **Security** → **Report a vulnerability**
3. Fill in the form with as much detail as possible

You can also reach the maintainer directly via the email address listed on the [GitHub profile](https://github.com/ulises-jeremias).

### What to include in your report

- A clear description of the vulnerability
- The file(s) affected and relevant line numbers
- Steps to reproduce the issue
- The potential impact (what an attacker could do)
- Any suggested remediation, if you have one

### Response timeline

| Stage | Target |
|---|---|
| Acknowledgement | Within 48 hours |
| Initial assessment | Within 5 business days |
| Patch or mitigation | Depends on severity; critical issues are prioritized |

We will credit reporters in the relevant commit or release notes unless you prefer to remain anonymous.

---

## Security Principles for This Repository

### No Secrets in the Repository

This repository must **never** contain credentials, API keys, tokens, passwords, or any other secrets. This rule applies to:

- All files in `skills/`, `agents/`, `loops/`, `profiles/`, `packs/`
- MCP configuration templates in `mcp/templates/` — these use clearly marked placeholder values only:

  ```json
  {
    "GITHUB_TOKEN": "${GITHUB_TOKEN}",
    "SLACK_BOT_TOKEN": "${SLACK_BOT_TOKEN}"
  }
  ```

- Documentation, comments, and example files

If you find a secret accidentally committed to the repository, report it immediately via private disclosure above. Do not attempt to scrub it yourself via a force push without coordinating with the maintainer first, as this can make the situation worse.

### Secret Scanning

GitHub's secret scanning is enabled on this repository. Any push containing a recognized secret pattern (GitHub tokens, Slack tokens, AWS keys, etc.) will be blocked automatically.

If a push is blocked by secret scanning and you believe it is a false positive, open a private disclosure report with details so we can evaluate and configure an exclusion if appropriate.

### Environment Variables Only

All MCP templates and documentation that reference external credentials must use environment variable substitution syntax. Never hardcode values. Example pattern:

```bash
export GITHUB_TOKEN="$(gh auth token)"
export SLACK_BOT_TOKEN="xoxb-your-token-here"   # placeholder only — never a real token
```

### Dependency Security

This repository has minimal runtime dependencies (primarily bash and Python for scripts). If you add a new script dependency, document it in `CONTRIBUTING.md` and ensure it comes from a reputable source.

---

## Out of Scope

The following are **not** considered security vulnerabilities for this repository:

- Skills or prompts that produce output an end user considers harmful — prompt quality is a functionality concern, not a security vulnerability
- Performance issues with validation scripts
- Compatibility issues between a skill and a specific tool version

If you are unsure whether your finding is in scope, err on the side of reporting privately. We would rather receive a non-issue than miss a real vulnerability.
