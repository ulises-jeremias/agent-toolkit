# Engineering Weekly Sync

## Meeting Details

- Date: 2024-01-22
- Time: 10:00–10:45 (UTC-5)
- Location / Link: https://meet.company.com/eng-weekly
- Facilitator / Owner: Alice Kim
- Attendees: Alice Kim, Ben Torres, Carmen Reyes, David Park, Elena Vasquez

## Source and Redaction

- Source link: https://notion.so/eng-sync-2024-01-22
- Redaction notes: None required — internal only

## Agenda

- [x] Sprint review (5 min)
- [x] Blocker escalation: payment-gateway queue depth (10 min)
- [x] Architecture review: service decomposition proposal (15 min)
- [x] AOB: Confluence migration to new instance (5 min)
- [x] Closing and action items (5 min)

## Minutes

### Discussion Points

**Sprint Review:**
- Squad 3 completed 18 story points; 2 items rolled over
- Squad 4 delivered the search performance fix ahead of schedule
- Ben noted that deployment tooling caused a 15-minute delay on the staging release

**Blocker Escalation — Payment Gateway:**
- David presented queue depth metrics: 4,200 messages pending, consumer running at 60% capacity
- Risk: message age could exceed SLA if consumer does not scale within 48 hours
- Decision: Scale consumer to 3 replicas immediately; monitor for 24 hours

**Architecture Review — Service Decomposition:**
- Carmen presented proposal to split monolith into 5 bounded contexts
- Team discussed boundaries and data ownership
- Open question: should the search domain be independently deployable?
- Action: Carmen to create ADR with three options (monolith-first, search extraction, full decomposition)

**Confluence Migration:**
- Notion being deprecated as team wiki in favor of new Confluence instance
- Migration scheduled for Feb 5–9
- All teams need to review their pages and update links

### Decisions Made

- Payment consumer scaled to 3 replicas (immediate effect)
- Search domain decomposition ADR to be drafted by Carmen (due: Jan 26)
- Confluence migration: all page owners notified by Alice by Jan 26

## Action Items

| Action Item | Responsible | Due Date | Status | Linked Task |
| --- | --- | --- | --- | --- |
| Scale payment consumer to 3 replicas | David Park | 2024-01-22 | Done | OPS-442 |
| Draft search domain ADR | Carmen Reyes | 2024-01-26 | In Progress | ARCH-018 |
| Notify team of Confluence migration | Alice Kim | 2024-01-26 | Done | DOC-099 |
| Review and update Confluence page links | All leads | 2024-02-05 | Not Started | DOC-099 |

## Parking Lot

- [ ] Deployment tooling improvement (Ben to open ticket)
- [ ] Review sprint capacity after payment incident impact (Alice, next sync)

## Review

- [ ] Destination confirmed.
- [ ] Human review required.
