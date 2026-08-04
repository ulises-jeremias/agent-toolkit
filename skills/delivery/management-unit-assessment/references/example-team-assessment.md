# Management Unit Assessment

## Review

- Destination: /docs/assessments/2024-q1/management-review
- Human reviewer: Director of Engineering
- Assessment status: Draft

## Unit Summary

- Management scope: Squads 3, 4, and 5 (embedded product teams)
- Assessment period: 2024-01-01 to 2024-03-31
- Systems of record: Linear (work items), Notion (decisions), Jira (reporting)
- Methodology / workflow expected: scrum with 2-week sprints; DoR and DoD defined per squad
- Overall management health: Moderate — strong delivery, weak risk visibility
- Key strengths: Sprint planning is consistent; retrospectives produce action items
- Key risks or gaps: Risks logged but not escalated proactively; dependency tracking inconsistent
- General confidence level: Medium-High

## Evidence Summary

| Evidence area | Source link or location | Freshness | Confidence | Notes |
| --- | --- | --- | --- | --- |
| Board / backlog | Linear → Team Workspaces | Current | High | Most work tracked |
| Planning / estimation | Linear sprint reports | Current | High | Velocity visible |
| Delivery reports | Jira delivery dashboards | Weekly | Medium | Reports lag by 1 week |
| Risks / issues / OIRs | Notion risk register | Updated ad hoc | Medium | Not all risks current |
| Retrospectives / improvements | Linear cycle retrospectives | Current | High | Actions tracked |
| Decisions / agreements | Notion decisions page | Current | Medium | Not linked to tasks |
| Meeting notes / interviews | Notion meeting templates | Variable | Low | Many meetings unrecorded |
| Stakeholder feedback | Intercom NPS surveys | Quarterly | Low | No direct feedback loop to squad |
| Team satisfaction signals | Weekly pulse surveys | Weekly | Medium | Response rate declining |

## Scorecard

### Governance and Structure

| Indicator | Score | Confidence | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Methodology definition | 4 | High | Linear + Notion | Scrum defined but sprint ceremonies inconsistently attended |
| Workflow definition | 3 | High | Notion workflow doc | DoR/DoD exist; not enforced on all work items |
| Issue definition | 3 | Medium | Jira + Linear | Issues opened but severity not consistently applied |
| Roles definition | 4 | High | Org chart | Clear ownership, sometimes overlaps on cross-team work |
| Risk management | 2 | Medium | Notion risk register | Risks identified but escalation threshold unclear |
| Progress tracking | 4 | High | Linear + Jira | Real-time in Linear; reporting in Jira lags |
| Continuous improvement initiatives | 3 | Medium | Retros | Actions exist; follow-through not tracked |

### Delivery and Execution

| Indicator | Score | Confidence | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Delivery | 4 | High | Jira delivery dashboard | 91% on-time in Q1 |
| Agile methodology implementation | 3 | High | Linear cycles | Ceremonies happen but value questionable |
| Sprint planning effectiveness | 4 | High | Linear planning view | Scope respected; capacity considered |
| Backlog management | 3 | Medium | Linear backlog | Grooming inconsistent; old items accumulate |
| Retrospective process | 4 | High | Linear retros | Action items created; owner and due date sometimes missing |
| Adaptability to change | 3 | Medium | Jira history | Responds to scope changes but unplanned work disrupts sprints |

### Collaboration and Communication

| Indicator | Score | Confidence | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Business knowledge | 4 | High | Interview with PM | PM shares context early; some tech debt from missing context |
| Client or stakeholder satisfaction | 3 | Low | NPS only quarterly | No direct feedback loop; reliance on PM secondhand |
| Communication | 3 | Medium | Slack + Linear | Status updates adequate; decisions not always communicated |
| Stakeholder engagement | 3 | Medium | Meeting attendance | Key stakeholders attend reviews; some absenteeism |
| Daily standup effectiveness | 3 | Medium | Observation | Often runs 15+ minutes; parking lot items not always resolved |
| Team satisfaction | 3 | Medium | Weekly pulse | Score 3.8/5; declining response rate signals disengagement |

### Culture and Values Alignment

| Indicator | Score | Confidence | Evidence | Validator | Notes |
| --- | --- | --- | --- | --- | --- |
| Raise the bar | 3 | Medium | Code review samples | PRs merged with minor comments; no pattern of pushing back |
| Do what I say | 4 | High | Jira promises | Commitments generally kept; delays communicated |
| Geek out | 3 | Low | No innovation time tracked | No dedicated innovation time; ad hoc experimentation |

### AI-Native Management Readiness

| Indicator | Score | Confidence | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Knowledge structure and documentation density | 3 | Medium | Notion pages | Decisions captured; ADRs not linked to work items |
| Decision traceability and governance explicitness | 2 | Medium | Notion decisions | Decisions exist but no link to impact or task |
| Workflow determinism and operational clarity | 3 | High | Linear + Notion | Workflows defined; exceptions not tracked |
| Feedback loops and continuous learning signals | 2 | Low | Weekly pulse | Pulse exists but action on signals is inconsistent |
| Human signal and cultural transparency | 3 | Medium | Team retros | Retros surface issues but resolution not always visible |

## Findings

### Strengths

- Finding: Sprint planning is reliable and respected.
  - Evidence: 91% on-time delivery; velocity variance under 15%
  - Confidence: High

### Risks and Gaps

- Finding: Risk register not actively maintained or escalated.
  - Evidence: 3 risks identified in Q4 2023 still listed as "open" with no update since January
  - Impact: Leadership blind to actual blockers; may miss escalation window
  - Confidence: Medium

### Missing Evidence

- Evidence needed: Direct stakeholder satisfaction interviews
  - Indicator impacted: Client/stakeholder satisfaction
  - Suggested source or validator: Product leadership, quarterly business review notes

## Recommendations

| Priority | Recommendation | Linked finding | Suggested follow-up |
| --- | --- | --- | --- |
| High | Escalate risk register review to monthly leadership sync | Risk register gaps | PM to present risk register monthly |
| Medium | Add decision links to Linear work items | Decision traceability | Use Linear custom field for ADR reference |
| Low | Reinstate weekly team pulse with action tracking | Team satisfaction signals | HR to present pulse results and actions quarterly |

## Assumptions and Limitations

- Assumption: Jira reporting lag is due to manual process, not systemic underreporting
- Limitation: Stakeholder satisfaction relies on quarterly NPS; no real-time signal available

## Validation

- Subjective scores validated by: Squad leads (self-assessment)
- Scores needing follow-up: Risk management (2) — recommend external review
- Consensus notes: All squad leads agreed risk escalation was the primary gap
