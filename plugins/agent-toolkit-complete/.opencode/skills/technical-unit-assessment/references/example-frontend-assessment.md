# Technical Unit Assessment — Frontend Engineering

## Review

- Destination: /docs/assessments/2024-q1/frontend
- Human reviewer: Frontend Lead
- Assessment status: Draft

## Unit Summary

- Unit name: Frontend Engineering
- Unit type: Frontend
- Assessment period: 2024-01-01 to 2024-03-31
- Repositories / systems: github.com/acme/web-app, github.com/acme/mobile-app, github.com/acme/component-library
- Documentation: Confluence /eng/frontend + README in each repo
- Decision ownership: Frontend lead (Marcus) + tech leads (2)
- Overall technical health: 3.5 / 5
- Key strengths: Component library adoption, accessibility compliance, CI coverage
- Key risks or gaps: Test coverage below target, performance regression on bundle size
- General confidence level: Medium-High

## Evidence Summary

| Evidence area | Source link or location | Freshness | Confidence | Notes |
| --- | --- | --- | --- | --- |
| Repositories | GitHub org | Current | High | 3 main repos; all have CI |
| Documentation | Confluence /eng/frontend | 1 month | Medium | README good; Confluence pages mixed freshness |
| CI/CD | GitHub Actions | Current | High | All repos have CI; staging auto-deploy |
| Observability / incidents | Datadog + Sentry | Current | High | Error tracking in Sentry; RUM in Datadog |
| Architecture / decisions | Notion /decisions/frontend | 2 months | Medium | ADRs exist; not all linked to work |
| Interviews / validation | 4 engineers | 1 week | Medium | Cross-section: junior to senior |

## Scorecard

### General Technical Indicators

| Indicator | Score | Confidence | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Code quality | 4 | High | PR review samples, ESLint compliance | Consistent style; some tech debt in legacy components |
| Deployment tools | 4 | High | GitHub Actions, Vercel | Staging auto-deploy; prod requires approval |
| Development experience | 4 | Medium | DX survey, engineer feedback | Hot reload fast; local env setup ~20 min |
| Monitoring and observability | 4 | High | Datadog RUM, Sentry | Error tracking comprehensive |
| Security awareness | 3 | Medium | Dependabot alerts, SAST | Weekly triage; no automated DAST |
| Technical debt volume | 3 | High | GitHub insights, backlog | Known items; no dedicated sprint for reduction |
| Workflow definition | 4 | High | Linear + Notion | DoR/DoD defined and followed |
| Testing | 3 | Medium | Coverage reports, CI | ~62% coverage; below 70% target |

### Frontend Indicators

| Indicator | Score | Confidence | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Responsiveness | 4 | High | Tested on BrowserStack | All breakpoints covered |
| Accessibility | 4 | High | axe-core reports, manual audit | WCAG 2.1 AA; audit done quarterly |
| Performance | 3 | Medium | Lighthouse, bundle analysis | LCP 2.8s (target <2.5s); bundle grew 18% this quarter |
| UI/UX design | 4 | High | Design system adoption | Component library at 85% reuse |
| Frontend testing coverage | 3 | Medium | Coverage reports | 62% (target 70%); integration gaps |
| Frontend dependency management | 4 | High | Dependabot, Renovate | Updates automated; major version manually reviewed |

### AI-Native Structural Readiness

| Indicator | Score | Confidence | Evidence | Notes |
| --- | --- | --- | --- | --- |
| Codebase explicitness | 4 | High | Repo structure, README | Clear component boundaries; TypeScript strict |
| Deterministic build | 4 | High | CI logs, Docker | Reproducible; cache hit rate >75% |
| Observability | 4 | High | Datadog RUM | Page performance, Core Web Vitals tracked |
| Testability | 3 | Medium | Coverage, test patterns | Component tests strong; page-level integration weak |
| Dependency transparency | 4 | High | Dependabot, bundle analysis | SBOM generated monthly |

## Findings

### Strengths

- Finding: Component library has high adoption (85%) and reduces duplicated effort across projects.
  - Evidence: Confluence adoption metrics, PR samples
  - Confidence: High

### Risks and Gaps

- Finding: Bundle size grew 18% in Q1, impacting performance scores.
  - Evidence: Lighthouse trending, bundle analysis reports
  - Impact: LCP regressed from 2.3s to 2.8s; mobile users affected
  - Confidence: High

- Finding: Integration test coverage is insufficient for page-level flows.
  - Evidence: Coverage reports show component tests at 78%, integration at 41%
  - Impact: 2 regressions escaped to staging in Q1
  - Confidence: Medium

### Missing Evidence

- Evidence needed: Direct user feedback on dashboard performance
  - Indicator impacted: Performance (user perception)
  - Suggested source: PM to provide session recordings or NPS comments

## Recommendations

| Priority | Recommendation | Linked finding | Suggested follow-up |
| --- | --- | --- | --- |
| High | Investigate bundle size growth and revert or justify large additions | Bundle size regression | Marcus to lead bundle audit by April 1 |
| Medium | Add Playwright tests for critical user flows | Integration test gap | 3 critical paths to cover first |
| Low | Evaluate code splitting strategy for routes | Bundle size | Audit lazy-loaded routes and shared chunk sizes |

## Assumptions and Limitations

- Assumption: Bundle growth is from new dependencies added this quarter, not existing code
- Limitation: Lighthouse runs on simulated throttling; may not reflect real user conditions

## Validation

- Subjective scores validated by: 4 engineers (self-assessment + lead review)
- Scores needing follow-up: Performance (3) — Lighthouse not sufficient; need field data
- Consensus notes: All engineers agreed integration test gap is priority to address
