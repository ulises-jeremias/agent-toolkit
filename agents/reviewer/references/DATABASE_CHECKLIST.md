# Database Review Checklist — from `database-reviewer` specialist (archived #865)

> **Provenance:** Migrated from `agents/database-reviewer/AGENT.md` (pre-865). Converted to reference per agent-vs-skill rule: procedural schema/query/migration checklist — load inline via `reviewer` / `quality/deep-review` / `delivery/technical-unit-assessment`. See `docs/AGENT_TAXONOMY.md` §3/§8.

Distinct from `data-engineer` (dbt/Snowflake pipeline validation) — this checklist is schema + query + ORM review. Invoke via `reviewer` or `architect`; do not invoke as standalone specialist.

## When to apply
- New migration, Prisma/Drizzle/TypeORM model, or index change
- Reviewer flags N+1, missing constraint, or hot-path scan
- `architect` TRD involves storage/boundaries

## Checklist

**Schema design**
- [ ] 3NF unless intentionally denormalized with comment
- [ ] Correct types — avoid blanket `TEXT`/`VARCHAR`; use enums where appropriate
- [ ] Constraints: `NOT NULL`, `UNIQUE`, `FK`, `CHECK`
- [ ] Naming: `snake_case`, plural tables

**Query optimization**
- [ ] Index matches predicate — check `EXPLAIN ANALYZE`
- [ ] No N+1 in ORM (eager vs lazy)
- [ ] JOIN strategy + selectivity verified
- [ ] Pagination: keyset preferred over `LIMIT/OFFSET` for large sets
- [ ] No full scan on hot path

**Migrations**
- [ ] Production-safe (avoid long locks, `CONCURRENTLY` where needed)
- [ ] Reversible
- [ ] Backfill strategy for large tables
- [ ] Zero-downtime pattern (expand→backfill→contract)

**ORM (Prisma / Drizzle / TypeORM)**
- [ ] Eager vs lazy loading correct
- [ ] Transaction scope/isolation correct
- [ ] Pool config sane

## Output
Explain issue → show problematic SQL/schema → provide optimized version → note production/deploy concerns. Cite `file:line` from schema/migration.

## Caller / handoff
- **Caller:** `reviewer` via `quality/deep-review` / `quality/blast-radius`, or `architect` via `delivery/technical-unit-assessment`
- **Handoff:** `data-engineer` if pipeline test needed; `qa-engineer` for E2E/migration verification; `implementer` applies fix
