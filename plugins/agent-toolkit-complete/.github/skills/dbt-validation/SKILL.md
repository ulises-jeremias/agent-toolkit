---
name: dbt-validation
description: >-
  HOW — Run dbt checks as documented in the target repo (parse, compile, test, selective run).
  Does not configure Snowflake accounts or change cloud security.
---

# dbt validation (HOW)

Use when the repository is a **dbt** project or the task requires **dbt** verification. Client workflows may delegate here.

## Boundaries

- Follow **repo** `AGENTS.md`, `Makefile`, `README`, and CI—not generic guesses.
- **Do not** change Snowflake security settings, network rules, or warehouse admin from this skill.
- If `dbt` or credentials are missing, **say so** and do not claim validation passed.

## Discovery

Look for `dbt_project.yml`, `packages.yml`, `models/`, `Makefile`, `pyproject.toml`, or CI jobs that invoke dbt.

## Typical commands (examples only—prefer repo docs)

| Intent | Often used (verify in repo) |
| --- | --- |
| Syntax / graph | `dbt parse`, `dbt compile` |
| Dependencies | `dbt deps` when packages change |
| Tests | `dbt test` or subset flags the repo documents |
| Build | `dbt run` / `dbt build` when the user approves mutating runs |

**Makefile** wrappers (e.g. `make parse`) take precedence when documented.

## Evidence

- Summarize **which** commands ran and **high-level** outcome (pass/fail/skipped) for tickets and PRs.
- On failure, capture **actionable** error lines; do not dump full logs unless the user asks.

## Safety

- Prefer **read-only** checks (`parse`, `compile`, `test`) when the task is review-only.
- Production runs require explicit user approval per repo policy.
