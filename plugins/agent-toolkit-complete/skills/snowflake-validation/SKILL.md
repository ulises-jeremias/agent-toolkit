---
name: snowflake-validation
description: >-
  HOW — Read-only Snowflake validation patterns: use repo-documented CLI (snowflake/sql) or SQL checks.
  Never claim success without working credentials and evidence.
---

# Snowflake validation (HOW)

Use when the task or repo requires **Snowflake** verification. Client workflows may delegate here alongside **dbt-validation**.

## Boundaries

- **Read-only** validation unless the user and repo explicitly authorize DDL/DML.
- **Never** claim “Snowflake validation passed” or “query succeeded” without **credentials** and **observed outputs** (or explicit statement that checks were skipped).
- **Do not** rotate keys, change roles, or alter security objects from this skill unless the repo’s `AGENTS.md` clearly authorizes it and the user approves.

## Discovery

Read repo docs for: connection method (env vars, `profiles.yml`, SSO), Snowflake **SQL** or **Snowflake CLI** (`snow`) usage, and warehouse/database/schema defaults.

## Patterns

| Situation | Action |
| --- | --- |
| Credentials available | Run minimal **SELECT** statements or documented smoke queries; record that they were executed |
| Snowflake CLI documented | Use repo’s exact commands; check `snow --help` for current subcommands |
| No credentials | State **skipped** in Jira/PR; list what would be validated when access exists |
| dbt + Snowflake | Coordinate with **dbt-validation**; Snowflake may be exercised indirectly via dbt |

## Evidence

- For each run: **what** ran (object or test name), **environment** (non-secret), **result** (row count, success/failure).
- Redact account identifiers if the user requests privacy in chat.

## Safety

- No secrets in tickets, PRs, or command lines in logs pasted to chat—use env vars and documented patterns only.
