# Security Policy

> **Consumers:** see [docs/TRUST.md](docs/TRUST.md) for install verification, receipts,
> and what files the toolkit writes on your machine.

## Supported Versions

Only the latest commit on the `main` branch is actively supported. There are no versioned releases with backported security patches at this time.

| Version | Supported |
|---|---|
| `main` (latest) | Yes |
| Any tagged release | Best-effort only |

If you are using a pinned commit or an older tag, we recommend updating to `main` before reporting an issue, in case it has already been fixed.

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
