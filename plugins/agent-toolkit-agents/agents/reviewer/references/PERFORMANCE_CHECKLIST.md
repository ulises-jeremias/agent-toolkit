# Performance Optimization Checklist — from `performance-optimizer` specialist (archived #865)

> **Provenance:** Migrated from `agents/performance-optimizer/AGENT.md` (pre-865). Converted to reference per agent-vs-skill rule: procedural profiling checklist — load inline via `reviewer` / `quality/deep-review` or `architect` / `delivery/technical-unit-assessment`. See `docs/AGENT_TAXONOMY.md` §3/§8.

Distinct from type/schema specialists — this checklist is measurement-driven profiling. Invoke via holistic owner; do not invoke as standalone specialist.

## When to apply
- Benchmark regression, slow endpoint/query, bundle/memory leak, `qa-engineer` flags hot-path scan or `quality/blast-radius` risk

## Workflow (measure first, optimize second)
1. Establish baseline metric and target (latency, TTFB, LCP, CLS, QPS, heap, bundle KB)
2. Identify bottleneck with evidence (profiler, `EXPLAIN ANALYZE`, ORM log, trace)
3. Apply minimum change to hit target
4. Verify with same measurement

## Bottlenecks by area

**Frontend** — re-renders (React Profiler), bundle (webpack-bundle-analyzer), blocking resources (LCP/CLS), images/fonts
**Backend** — N+1, sync I/O on hot path, leaks (heap snapshot), pool exhaustion
**Database** — missing predicate index, full scan, JOIN/query shape, lock contention
**Algorithm** — O(n²) vs O(n log n), redundant loop work, wrong data structure

## Safe optimizations (reach for first)
- Caching: memoization, Redis, HTTP cache headers
- Lazy loading + code splitting
- Predicate indexes
- Batch over one-by-one
- Connection pooling

## Output
1. Current metric (measured) 2. Bottleneck + evidence 3. Fix + expected impact 4. How to verify 5. Trade-offs (memory vs CPU, complexity vs speed)

## Caller / handoff
- **Caller:** `reviewer` via `quality/deep-review` / `quality/blast-radius`, or `architect` via `delivery/technical-unit-assessment`
- **Handoff:** `qa-engineer` for E2E/browser verification; `implementer` applies fix; never claim improvement without re-measurement
