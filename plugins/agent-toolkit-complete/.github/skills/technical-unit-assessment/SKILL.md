---
name: technical-unit-assessment
description: WHAT - Evidence-based technical unit assessment for repositories, platforms, frontend, backend,
  infrastructure, data, UI/UX, and AI-native structural readiness.
origin:
  type: first-party
---
# Technical Unit Assessment (WHAT)

Assess a technical unit: frontend app, backend API, data platform, infrastructure/IaC scope,
mobile app, AI/ML pipeline, or another technical workload.

Run **`project-assessment-evidence`** first.
Use **`project-assessment`** as the router for multi-unit assessments.

## Out of scope

- Does NOT score indicators without evidence — mark as **Not assessed**
- Does NOT make technical decisions — scores inform, humans decide
- Does NOT produce final report without **`output-handshake`**

## Unit intake

Ask before scoring:
- Unit name and type (frontend / backend / infra / data / mobile / AI)
- Repositories, services, infrastructure scopes, or pipelines included
- Technical decision ownership (team, client, shared, unknown)
- Assessment period
- Authoritative systems for code, docs, CI/CD, incidents, observability, security

## Workflow

1. Run **`project-assessment-evidence`** to build evidence map
2. Select indicator groups matching the unit type (see `references/indicator-groups.md`)
3. Score only indicators with evidence; mark rest as **Not assessed**
4. Note confidence and missing evidence per score
5. Apply **`output-handshake`** before final scorecard

## Scoring rules

Use the 1–5 scale from `references/indicator-groups.md`. Do not average unrelated indicators
without explaining weighting. Request validator for subjective scores.

## References

- `references/indicator-groups.md` — all indicator groups + scoring scale + AI-native readiness
- `references/default-template.md` — technical unit scorecard template
- `references/example-frontend-assessment.md` — example assessment for a frontend team

## Delegates to

| Need | Skill |
|------|-------|
| Evidence intake | **`project-assessment-evidence`** |
| Multi-unit routing | **`project-assessment`** |
| Deep UI/UX review | **`figma`** / **`figma-implement-design`** |
| Repo discovery | **`assistant`** |
| Final output gate | **`output-handshake`** |
