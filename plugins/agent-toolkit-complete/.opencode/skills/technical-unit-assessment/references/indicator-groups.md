# Technical Unit Assessment — Indicator Groups Reference

Use only the groups that match the unit being assessed.

## General technical indicators

Repository links, unit type, unit name, documentation links, technical decision responsibility,
code quality, deployment tools, development experience, monitoring and observability,
security awareness, technical debt volume, workflow definition, testing.

## Frontend indicators

Frontend languages, responsiveness, accessibility, performance, UI/UX design,
frontend testing coverage, frontend dependency management.

## Backend indicators

Backend frameworks and libraries, API documentation, databases and storage, backend languages,
backend testing coverage, API versioning, scalability, error handling, backend dependency management.

## Cloud infrastructure and DevSecOps indicators

Security testing, compliance, CI/CD, Infrastructure as Code, automated environment bootstrapping,
environment consistency and isolation, secrets management, role-based access control,
backup/retention/recovery, disaster recovery and resilience, infrastructure monitoring,
pipeline infrastructure monitoring, cost monitoring and budget controls,
incident response and postmortems, continuous security.

## Cloud data engineering indicators

Data sources, data architecture documentation, data modeling and schema management,
pipeline orchestration and reliability, data quality management, data lineage and traceability,
storage strategy and optimization, data governance and access control, security and compliance,
monitoring and observability for data pipelines, scalability and performance,
testing and validation coverage for data workflows, documentation of business rules and metrics,
data delivery and consumption readiness.

## UI/UX indicators

User interface design, responsiveness, accessibility, user-centered design,
usability, visual aesthetics. For deep UI review, delegate to **`ui-ux-pro-max`**.

## AI-native structural readiness

Measures whether AI assistance can safely understand and modify the system — NOT tool usage:

- Codebase explicitness and architectural clarity
- Deterministic build and delivery systems
- Observability and operational transparency
- Testability and validation density
- Dependency and change impact transparency

## Scoring scale

| Score | Meaning |
|-------|---------|
| 1 | Low, reactive, implicit, undocumented, or highly variable |
| 2 | Emerging — some awareness but inconsistent |
| 3 | Defined, observable, or partially mature with consistency gaps |
| 4 | Managed — consistent, measured, improving |
| 5 | Explicit, repeatable, measurable, and evidence-driven |

Mark **Not assessed** when evidence is missing or the indicator is out of scope.
Do not average unrelated indicators without explaining weighting.
For subjective scores, request a validator and record consensus status.
