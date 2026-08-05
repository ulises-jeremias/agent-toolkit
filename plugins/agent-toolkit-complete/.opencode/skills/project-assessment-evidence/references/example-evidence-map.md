# Project Assessment Evidence Map

## Scope

- Assessment: Q1 2024 Engineering Platform Assessment
- Period: 2024-01-01 to 2024-03-31
- Units covered: Platform Engineering, Frontend, Backend, Data
- Systems of record: Linear (work), GitHub (code), Jira (delivery), Confluence (docs)
- Source precedence rules: Primary — repo configs and CI; Secondary — linear and docs; Tertiary — interviews

## Evidence Ledger

| ID | Evidence area | Source type | Source link or location | Owner | Freshness | Related indicators | Strength | Confidence | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E-001 | Work tracking | Linear boards | Platform Squad workspace | Alice Kim | Current | Delivery, Methodology | Direct | High | All platform work in Linear |
| E-002 | Repository | GitHub org | github.com/acme/platform | David Park | Current | Code quality, CI/CD, Architecture | Direct | High | 14 repos assessed |
| E-003 | Documentation | Confluence | /eng/platform/docs | Carmen Reyes | 2 weeks old | Docs density, Decision traceability | Direct | Medium | Some pages outdated |
| E-004 | CI/CD | GitHub Actions | .github/workflows in repos | David Park | Current | Pipeline, Deployment, Security | Direct | High | All repos have CI |
| E-005 | Observability | Datadog | dashboards/engineering | SRE team | Current | Monitoring, Incidents | Direct | High | Dashboards linked |
| E-006 | Decisions | Notion | /decisions/architecture | Elena Vasquez | 1 month old | Decision traceability | Indirect | Medium | Decisions exist, not always linked |
| E-007 | Interviews | Notes | /evidence/interviews-2024-q1 | Alice Kim | 2 weeks old | All indicators | Direct | Medium | 6 engineers interviewed |
| E-008 | Stakeholder feedback | Intercom | NPS dashboard Q1 | PM lead | Quarterly | Client satisfaction | Indirect | Low | No direct engineering signal |

## Missing Evidence Register

| Missing evidence | Indicators impacted | Why it matters | Suggested source or owner | Required before scoring? |
| --- | --- | --- | --- | --- |
| Direct stakeholder satisfaction for Platform team | Stakeholder engagement | Quarterly NPS too lagged for actionable feedback | PM to schedule 1:1 with product leads | No (can score 3 as placeholder) |

## Conflicts and Validation Needs

| Topic | Conflicting sources | Proposed validator | Status |
| --- | --- | --- | --- |
| Deployment frequency: Jira reports weekly; GitHub Actions logs show bi-weekly | David Park to reconcile | Pending — David to audit actual deploy timestamps | Pending |
| Documentation freshness: Confluence shows pages from 2023; engineers claim docs are current | Carmen to update Confluence or note which pages are maintained | Carmen | In Progress |

## Assumptions

- Assumption: GitHub Actions logs reflect actual deployment events, not just CI runs
  - Evidence gap: No separate deployment log to cross-reference
  - Impact: Deployment frequency indicator may be inflated if CI = deploy
  - Validation needed: David to confirm pipeline stages and actual prod deploy events
- Assumption: Intercom NPS reflects platform team contribution (not overall product NPS)
  - Evidence gap: No segment for platform vs feature work
  - Impact: Scores may mask platform-specific issues
  - Validation needed: PM to provide breakdown if available
