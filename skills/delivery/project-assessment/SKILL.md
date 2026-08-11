---
name: project-assessment
description: 'WHAT - Interactive project assessment router: define assessment scope and units, collect
  evidence through project-assessment-evidence, then delegate to technical or management unit assessment
  skills. Always evidence-based and human-reviewed.'
origin:
  type: first-party
---
# Project Assessment (WHAT)

Use this skill when the user asks for a project assessment, maturity assessment, delivery audit, technical assessment, management assessment, quality indicator review, or improvement roadmap.

This is a router skill. Keep it focused on assessment flow, gates, and delegation. Use the unit-specific skills for scoring details.

## Default guardrails

1. Apply **`output-handshake`** before producing any final assessment report, scorecard, action plan, or executive summary: ask where the artifact should live and confirm human review.
2. Apply **`project-assessment-evidence`** before scoring. Evidence may live in repositories, boards, docs, spreadsheets, dashboards, incidents, PRs, meetings, interviews, Slack, emails, or any other project system. Ask the user where to find each source.
3. Never assign a score without evidence. If evidence is missing, mark the indicator as **Not assessed** or score it with **Low confidence** and state the assumption explicitly.
4. Keep sensitive details out of reusable artifacts. Redact secrets, credentials, private customer data, and unnecessary personal data.
5. Do not mention client-specific reference examples or internal audit links in generated outputs. Use only abstracted patterns.

## Assessment flow

1. **Intake**
   - Ask the assessment purpose: baseline, periodic review, due diligence, quality improvement, delivery health check, AI-readiness review, or internal audit support.
   - Ask the assessment period and target audience.
   - Ask whether the assessment should cover management units, technical units, or both.
   - Ask which repositories, products, squads, platforms, or delivery scopes form each assessment unit.
2. **Evidence collection**
   - Delegate to **`project-assessment-evidence`**.
   - Build an evidence map before scoring.
   - Ask the user where each evidence category lives instead of assuming ClickUp or repository-only evidence.
3. **Unit assessment**
   - For technical workloads, delegate to **`technical-unit-assessment`**.
   - For project management and delivery scopes, delegate to **`management-unit-assessment`**.
   - If UI depth is required, pair the technical unit assessment with **`figma`** / **`figma-implement-design`**.
   - If repository discovery is required, pair with **`assistant`** and the repository-specific rules.
4. **Consensus and scoring**
   - Use the 1 to 5 maturity scale from the assessment indicators.
   - Treat score 3 as "defined or partially mature", not as average performance.
   - Record confidence per score: High, Medium, Low, or Not assessed.
   - For subjective indicators, ask who should validate the score and whether weights are needed.
5. **Findings and action plan**
   - Summarize strengths, risks, gaps, and opportunities.
   - Separate confirmed findings from assumptions and missing evidence.
   - Convert recommendations into actionable follow-ups only after user approval, delegating ticket creation to the relevant ticket skill.

## Required interactive questions

Ask these before creating the final assessment artifact:

- Where should the final assessment live?
- Who will review and approve it?
- What is the assessment purpose and period?
- Which management units and technical units are in scope?
- Which systems of record should be used for evidence?
- Where are the repositories, docs, boards, diagrams, CI/CD pipelines, dashboards, incident records, meeting notes, decisions, agreements, and stakeholder feedback?
- Which indicators must be skipped, weighted, or treated as out of scope?
- Which people should be interviewed or asked to validate subjective scores?

## Outputs

Typical outputs are:

- Assessment plan and scope
- Evidence map
- Unit scorecards
- Findings with evidence links
- Missing evidence register
- Risk and opportunity summary
- Recommendations and action plan
- Follow-up work item candidates

## Boundaries

- This skill does not execute ClickUp, Jira, Confluence, GitHub, GitLab, Slack, or repository commands. Delegate HOW to tool skills.
- This skill does not replace project-specific assessment procedures. If an engagement pack or repository defines stricter rules, surface the difference and follow the stricter/project-specific rule.
- This skill does not create tasks or update documents without explicit user approval.

## References

- `references/default-template.md` - default assessment report template
- `references/example-platform-assessment.md` — example assessment for a platform engineering team with full scorecard
- `project-assessment-evidence` - evidence map and source-by-source intake
- `technical-unit-assessment` - technical unit indicators and template
- `management-unit-assessment` - management unit indicators and template
- `output-handshake` - destination and human review
- `assistant` - repository discovery
- `clickup-cli`, external Jira/Confluence skills, forge skills, and Slack skills - evidence retrieval or artifact updates after approval
