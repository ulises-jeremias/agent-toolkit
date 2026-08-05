# Planning and Estimation Notes

## Scope / Goal

Sprint 24 planning for Squad 4 (platform). Focus on payment infrastructure reliability and tech debt reduction.

## Work Item Breakdown

- [x] Scope is clear and bounded.
- [x] Work is split into manageable stories/tasks/subtasks.
- [x] Items estimated at 5+ points were reviewed for splitting.
- [x] Dependencies are identified.
- [x] Acceptance criteria are clear enough for estimation.

**Note:** PAY-102 ("Refactor message consumer") was initially estimated at 8 points; after discussion, split into PAY-102a (3pts, consumer restart logic) and PAY-102b (5pts, dead-letter queue and circuit breaker).

## Estimation

**Technique used:** Planning Poker (Fibonacci)

| Item | Estimate | Rationale | Risks / Unknowns |
| --- | --- | --- | --- |
| OPS-442: Scale payment consumer | 2 | Standard infra config, no code change | None |
| PAY-102a: Consumer restart logic | 3 | Follows existing pattern for graceful shutdown | Low — well-understood problem |
| PAY-102b: Dead-letter queue + circuit breaker | 5 | New infrastructure component; testing requires staging env | Medium — staging env provisioning could slip |
| TECH-203: Confluence page audit | 1 | Documentation work, no code | None |
| TECH-204: Upgrade API gateway | 3 | Dependency update; follows migration guide | Low — similar upgrade done last quarter |

**Total:** 14 points

## Capacity Assumptions

| Factor | Notes |
| --- | --- |
| Iteration length | 2 weeks (Jan 22 – Feb 2) |
| Team availability | 4 engineers (Alice, Ben, Carmen, David) |
| Holidays / planned leave | No holidays; Ben on call Jan 25 |
| Meetings / non-development time | ~6 hours/week estimated for meetings |
| Focus factor | 0.7 (accounting for meetings, context switching) |
| Historical velocity | 15 points/sprint (last 3 sprints) |

**Effective capacity:** 4 engineers × 8 hrs/day × 10 days × 0.7 focus = 224 hours ≈ 16-18 points at historical mix

## Dependencies and Risks

**Dependencies:**
- PAY-102b requires staging environment with queue infrastructure (ticket with Infra team submitted Jan 19; response expected Jan 23)
- Confluence migration (DOC-099) may generate unplanned work for TECH-203 owners

**Risks:**
- Staging env delay: if not ready by Jan 24, PAY-102b testing cannot complete in sprint
- Mitigation: Alice to follow up with Infra on Jan 23 if no response
- Payment team may be pulled into INC response if another alert fires

## Final Planning Notes

Sprint 24 is conservative due to payment incident aftermath and Confluence migration. If staging env is ready early and no incidents, we may pick up TECH-205 from backlog.

## Review

- [x] Destination confirmed by user.
- [x] Human review required before treating this as approved.
