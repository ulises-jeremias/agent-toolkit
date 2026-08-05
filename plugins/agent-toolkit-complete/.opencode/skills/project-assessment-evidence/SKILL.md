---
name: project-assessment-evidence
description: >-
  WHAT - Interactive evidence intake for project assessments. Ask the user where
  each evidence source lives, build an evidence map, track missing evidence,
  assumptions, freshness, and confidence before any scoring happens.
---

# Project Assessment Evidence (WHAT)

Use this skill before scoring a project assessment. It turns scattered project knowledge into a structured evidence map.

This skill is intentionally interactive. Evidence can be outside ClickUp and outside the repository. Ask for source locations instead of assuming where they live.

## Default behavior

1. Ask the user for the systems of record and evidence locations.
2. Collect source links, paths, owners, dates, and freshness for each evidence item.
3. Mark evidence quality: Direct, Indirect, Interview-only, Stale, Missing, or Not applicable.
4. Record confidence for each evidence item: High, Medium, Low, or Not assessed.
5. Do not score indicators. Return the evidence map to **`project-assessment`**, **`technical-unit-assessment`**, or **`management-unit-assessment`**.

## Evidence intake questions

Ask only the questions relevant to the assessment scope, but cover each required source class before scoring.

### Scope and systems

- What project, product, platform, squad, or delivery scope is being assessed?
- What period should evidence cover?
- What are the official systems of record?
- Which sources should be considered authoritative when sources conflict?

### Delivery and management evidence

- Where is the project board or backlog?
- Where are epics, stories, tasks, bugs, incidents, and subtasks tracked?
- Where are sprint plans, delivery reports, retrospectives, risks, and OIRs?
- Where are PRDs, TRDs, ADRs, decisions, agreements, and meeting minutes stored?
- Where can stakeholder feedback, client satisfaction signals, and team health signals be found?
- Who should validate subjective management indicators?

### Technical evidence

- Where are the repositories and deployment manifests?
- Where are architecture diagrams, API docs, runbooks, and operations docs?
- Where are CI/CD pipelines, deployment history, and release notes?
- Where are test reports, coverage data, quality gates, and static analysis outputs?
- Where are observability dashboards, alerts, logs, incident records, and postmortems?
- Where are security, compliance, access control, secrets management, and dependency signals?
- For data systems, where are lineage, data quality checks, orchestration, schemas, business rules, and consumption docs?
- For UI/UX, where are design files, UX research, accessibility reports, performance reports, screenshots, recordings, or product analytics?

### Interviews and validation

- Who should be interviewed or asked for context?
- Which questions must be answered by humans because no artifact exists?
- Which scores require cross-review or consensus?

## Evidence quality rules

- Prefer direct artifacts over recollection.
- Treat interview notes as valid evidence only when clearly labeled as interview evidence.
- Do not use stale evidence without marking freshness risk.
- If an indicator has conflicting evidence, record both sources and request validation.
- If no evidence is available, record **Missing evidence** and avoid pretending certainty.

## Output

Return an evidence map with:

- Source type
- Source link or location
- Owner or contact
- Freshness
- Related indicators
- Evidence strength
- Confidence
- Notes and limitations

## References

- `references/default-template.md` - evidence map template
- `references/example-evidence-map.md` — example evidence map for a multi-team engineering assessment
- `project-assessment` - assessment router
- `technical-unit-assessment` - technical scoring
- `management-unit-assessment` - management scoring
- `output-handshake` - destination and review for final artifacts
