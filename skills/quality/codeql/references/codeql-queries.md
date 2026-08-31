# CodeQL Query Packs — 2026-08-12

**Upstream:** `github/codeql` (MIT, https://github.com/github/codeql) — standard QL libraries and queries. Packs per language under `codeql/<lang>-queries` (e.g., `python`, `javascript`, `java`, `go`, `cpp`). Suites: `codeql-suites/<lang>-security-and-quality.qls`, `security-extended.qls`, `security-experimental.qls`.

**GitHub Docs (2026-08-12):** CodeQL code scanning for compiled languages (build modes), CodeQL CLI (`codeql database create` / `analyze`), `github/codeql-action` (https://github.com/github/codeql-action, MIT, `init@v4` + `analyze@v4`).

## Curated suites

| Suite | What it contains | When to use |
|-------|------------------|-------------|
| `security-and-quality` | Security + correctness (precision `very-high`/`high`) | Default for CI — `Analyze Python` in this repo uses `codeql/python-queries:codeql-suites/python-security-and-quality.qls` implicitly via `codeql-action` without custom `queries:` |
| `security-extended` | Additional security with more false positives (`medium` precision) | When you need broader coverage and can triage |
| `security-experimental` | Experimental queries | Only for research, not CI gate |

**Per-language pack locations (examples):**
- `codeql/python-queries` — `py/sql-injection`, `py/xss`, `py/path-injection`, etc. Help: https://codeql.github.com/codeql-query-help/python/
- `codeql/javascript-queries` — `js/sql-injection`, `js/xss`, etc.
- `codeql/java-queries` — `java/sql-injection`, etc.
- `codeql/cpp-queries`, `codeql/go-queries`, `codeql/ruby-queries`, `codeql/csharp-queries`

## This repo

- `.github/workflows/codeql.yml`: `languages: python` via `github/codeql-action/init@v4` + `analyze@v4`, `on: push[main] + pull_request[main] + schedule 0 6 * * 1`, `permissions: security-events: write`.
- No custom `queries:` yet — uses default `security-and-quality` pack.
- To add a language: add to `matrix.language` or separate job with `language: java` + build spec (`autobuild` for Maven/Gradle, manual `mvn package` for custom).

## When to write custom QL

- Reuse `security-and-quality` first. Only write custom when you need a repo-specific pattern (e.g., internal sanitizer, framework-specific sink).
- Create `codeql-query-pack/qlpack.yml`:
  ```yaml
  name: my-org/my-queries
  version: 0.0.1
  dependencies:
    codeql/python-queries: "*"
  ```
- Write `my-query.ql` with `import python`, `from DataFlow::Node source, sink where ... select sink, "message"`, add `metadata` (`id`, `kind: path-problem`, `severity`, `precision`), help docs.
- Test: `codeql test run codeql-query-pack/`, then `codeql pack create` + `codeql database analyze --query-suite=my-suite.qls`.

## References

- `github/codeql` README (MIT, 2026-08-11), `github/codeql-action` README (MIT)
- GitHub Docs: Code scanning with CodeQL, CodeQL CLI, CodeQL query help
