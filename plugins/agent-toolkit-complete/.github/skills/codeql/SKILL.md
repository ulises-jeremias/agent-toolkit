---
name: codeql
description: CodeQL operational workflow — discover/config, run/inspect, triage SARIF findings (rule/query ID, source→sink, evidence), remediate, re-validate. Distinguishes broad MegaLinter linting from semantic security analysis.
origin:
  type: first-party
---

# CodeQL — Operational Security Analysis Workflow

Help coding agents **operate** CodeQL, not just explain syntax. Covers discovery of existing setup, config review, scan execution/inspection, SARIF triage with evidence discipline, remediation, and targeted re-validation.

> **Sources:** GitHub Docs Code Scanning with CodeQL (2026-08-12, https://docs.github.com/en/code-security/code-scanning/automatically-scanning-your-code-for-vulnerabilities-and-errors/about-code-scanning-with-codeql), CodeQL CLI (`github/codeql` MIT, CLI binaries separate), `github/codeql-action` (https://github.com/github/codeql-action), and this repo's `.github/workflows/codeql.yml` (Analyze Python via `codeql-action/init@v4` + `analyze@v4`).

**Relationship to MegaLinter:**
- **MegaLinter:** broad linting/formatting/static quality orchestration (50+ linters, Docker-based, `.mega-linter.yml`, fast feedback on style, config, IaC).
- **CodeQL:** semantic security analysis / dataflow / vulnerability classes (source→sink taint, e.g., `python/sql-injection`, `js/xss`, SARIF alerts).
- Neither replaces the other. Composition: `code-quality / secure-delivery → { MegaLinter, CodeQL }` without a giant orchestrator.

## When to use

- Repo has or needs CodeQL code scanning (`.github/workflows/codeql.yml`, `codeql-action`, SARIF alerts)
- Need to triage a CodeQL alert (security tab, SARIF file, CI log) with evidence
- Need to fix a finding and re-validate
- Workflow failing (timeout, OOM, build failure for compiled languages, config error)
- Need custom query / query-pack guidance (when to write vs reuse)

## Modes (one skill, contextual)

| Mode | Trigger | What it does |
|------|---------|--------------|
| **SETUP / CONFIG REVIEW** | No CodeQL workflow, or outdated `codeql-action` version, or new language to add | Inspect `.github/workflows/codeql.yml`, `languages:`, `queries:`, `paths:`, `paths-ignore:`, schedule, permissions (`security-events: write`); recommend `init@v4`/`analyze@v4` (or `codeql-action` latest), language matrix, `build-mode` for compiled (manual/autobuild/none) |
| **FINDING TRIAGE** | SARIF file, alert URL, or `Run CodeQL` log with failure | Parse SARIF (`runs[].tool.driver.rules[]`, `runs[].results[]`), map `ruleId` → query help, extract `locations[0].physicalLocation`, `codeFlows` (source→sink), `message.text`, `level`/`category`, `partialFingerprints`; produce evidence table |
| **REMEDIATION** | Triaged finding with fix needed | Propose minimal fix (sanitize, parameterized query, escape), show diff, reference query docs, note confidence/severity, and how to suppress via `// lgtm[…]` or `codeql-config.yml` only when justified (ask before suppress) |
| **WORKFLOW TROUBLESHOOTING** | `analyze` job failed, no alerts, or `out of memory` | Check `codeql-action` logs, `AUTOBUILD` vs manual build, `ram:` / `threads:`, `debug: true`, `upload-sarif` fallback, `category` duplication |
| **CUSTOM QUERY** | Need to detect a repo-specific pattern beyond standard packs | Guide when to reuse `security-and-quality` vs `security-extended` vs write custom QL (pack `codeql/<lang>-queries`), use `codeql pack create` + `codeql query run` locally, test with `codeql test run` |

Do not split into separate skills — routing is via the mode table above.

## Workflow (operational loop)

```
DISCOVER existing CodeQL setup (workflow, languages, queries, schedule)
      ↓
RUN or INSPECT scan (CI `analyze` job or local `codeql database create` + `codeql database analyze`)
      ↓
TRIAGE findings (SARIF: ruleId, location, source→sink, evidence, confidence, severity)
      ↓
PLAN remediation (fix vs suppress vs needs investigation)
      ↓
IMPLEMENT fix (minimal, preserve semantics)
      ↓
RE-VALIDATE targeted (re-run that query / re-upload SARIF / re-check alert)
      ↓
DOCUMENT residual (fixed / suppressed with justification / needs investigation)
```

1. **Discover:** `ls .github/workflows/codeql.yml` + `cat` (languages, `on: push/pull_request/schedule`, `permissions`, `strategy.matrix.language` if present). Check GitHub Security tab API (`gh api repos/{owner}/{repo}/code-scanning/alerts`) for open alerts, or `find . -name "*.sarif"` locally.
2. **Run / Inspect:**
   - **CI:** Trigger workflow (`gh workflow run codeql.yml`) or watch latest run (`gh run list --workflow=codeql.yml`, `gh run view <id>`, `gh run view <id> --log-failed`). Prefer CI when available (no local DB build needed).
   - **Local (fallback):** `codeql database create --language=python --source-root=. /tmp/codeql-db` (compiled: add `--build-mode` or manual build command), then `codeql database analyze /tmp/codeql-db codeql/python-queries:codeql-suites/python-security-and-quality.qls --format=sarif-latest --output=/tmp/results.sarif`. Use `codeql pack download` for custom packs. Local needs CodeQL CLI installed (`gh codeql` or `codeql` binary, Java for DB).
3. **Triage (evidence discipline):**
   - For each `result` in SARIF: extract `ruleId` (e.g., `py/sql-injection`), `message.text`, `locations[0].physicalLocation.artifactLocation.uri` + `region` (line/col), `codeFlows[0].threadFlows[0].locations` (source→sink), `partialFingerprints.primaryLocationLineHash` (stable ID), `properties.severity` / `security-severity`, `level` (error/warning/note).
   - Do not dismiss as false positive without evidence. If source→sink lacks a sanitizer, mark `Needs investigation` and propose confirming with query help link (`https://codeql.github.com/codeql-query-help/python/py-sql-injection`).
   - Table columns: `# | ruleId | location (file:line) | source→sink | code evidence (snippet) | severity/confidence | remediation | validation | status`.
4. **Remediate:** Propose minimal fix with diff. For `py/sql-injection`: use parameterized `cursor.execute("SELECT ... WHERE id = %s", (user_id,))` not `f"SELECT ... {user_id}"`. For `js/xss`: escape via `textContent` or DOMPurify. For `java/sql-injection`: use `PreparedStatement`. Ask before adding `// lgtm[py/sql-injection]` or `codeql-config.yml` `query-filters: - exclude: py/sql-injection` — suppress only with justification.
5. **Re-validate:** Re-run that single query pack (`codeql database analyze --query-suite=... --sarif-category=python`) or push branch and re-check Security tab alert state (`open` → `fixed` after merge to default branch, or `dismissed` if suppressed). For CI, watch new `analyze` run; for local, `codeql database analyze` with `--rerun`.
6. **Document residual:** `fixed` (with commit), `dismissed` (reason + `dismissedReason: false positive` + comment), or `needs investigation` (insufficient evidence, e.g., custom sanitizer not modeled).

## Evidence discipline (per finding)

| Field | Required | Example |
|-------|----------|---------|
| `ruleId` / `query ID` | Yes | `py/sql-injection`, `java/sql-injection` |
| `location` | Yes | `src/app.py:42:12` (uri + region) |
| `source → sink` | Yes when taint query | `request.args.get("id")` (source, line 38) → `cursor.execute(…)` (sink, line 42) via `codeFlows` |
| `code evidence` | Yes | Snippet `cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")` |
| `confidence` | Yes | High/Med/Low (from `properties.precision`: `very-high`/`high`/`medium`) |
| `severity` | Yes | `error` / `warning` + `security-severity: 8.5` |
| `remediation` | Yes | Parameterized query, or `needs investigation` if sanitizer unknown |
| `validation` | Yes | `re-ran py/security-and-quality on /tmp/db → 0 results for py/sql-injection` or `CI analyze #123 green` |

If evidence insufficient: status `Needs investigation` is valid — do not mark `fixed` or `false positive` without code proof.

## MegaLinter vs CodeQL (documented)

| Aspect | MegaLinter | CodeQL |
|--------|------------|--------|
| Scope | Broad linting/formatting/IaC (100+ linters, `.mega-linter.yml`) | Semantic security / dataflow (SARIF, `codeql/*` packs) |
| Runtime | Docker `ghcr.io/oxsecurity/megalinter:v10` via `npx mega-linter-runner` | `github/codeql-action` (init/analyze) or `codeql` CLI + DB |
| Output | Console + `megalinter-reports/mega-linter-report.json` + logs | SARIF `results.sarif` + GitHub Security alerts |
| Fix loop | ≤3 bounded (safe auto-fix → targeted re-check) | One finding at a time, re-analyze DB after fix |
| When to use | Every PR for hygiene | Every push/PR for security, plus scheduled weekly |

**Do not duplicate workflows.** When both are needed, run `megalinter-check` for hygiene and `codeql` triage for security; share the same branch but keep SARIF vs linter reports separate.

## Safety

- Never auto-suppress a CodeQL alert without user confirmation — suppression hides a security finding.
- Never push to `main` to fix a CodeQL alert — create branch `codeql/fix-<rule>-<id>`, fix, push, verify `analyze` passes.
- For custom queries, keep them in `codeql-query-pack/` with `qlpack.yml` and `codeql test` — do not edit `github/codeql` directly.

## References

- `references/codeql-queries.md` — curated query packs (`security-and-quality`, `security-extended`, `security-experimental`), per-language `codeql/<lang>-queries` locations, and when to write custom QL
- GitHub Docs: Code scanning with CodeQL (2026-08-12), CodeQL CLI, `github/codeql-action` (https://github.com/github/codeql-action, MIT), `github/codeql` (MIT, queries)
- This repo: `.github/workflows/codeql.yml` (Analyze Python, `init@v4` + `analyze@v4`, schedule `0 6 * * 1`)
