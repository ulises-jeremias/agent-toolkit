---
name: management-unit-assessment
description: >-
  WHAT - Evidence-based management unit assessment for governance, delivery,
  collaboration, culture, and AI-native management readiness. Interactive and
  source-driven before any score is assigned.
---

# Management Unit Assessment (WHAT)

Use this skill to assess a management unit: project management, delivery execution, governance, stakeholder alignment, team collaboration, cultural health, and management-layer AI readiness.

Run **`project-assessment-evidence`** first and use **`project-assessment`** as the router when the assessment spans multiple units.

## Default guardrails

1. Apply **`output-handshake`** before final scorecards or reports.
2. Ask where each evidence source lives before scoring.
3. Score only indicators that match the assessment scope and available evidence.
4. Mark every score with evidence links and confidence.
5. Use **Not assessed** when evidence is missing or the indicator is out of scope.
6. For subjective indicators, request validation from the appropriate reviewer or stakeholder.

## Unit intake

Ask:

- What management scope is being assessed: whole project, squad, delivery stream, account, or another scope?
- What period should the assessment cover?
- Which methodology, workflow, and governance model is expected?
- Where are the board, backlog, planning artifacts, delivery reports, risks, retrospectives, decisions, agreements, and meeting notes?
- Where are stakeholder satisfaction, team satisfaction, and communication signals captured?
- Who should validate subjective scores?

## Indicator groups

### Governance and structure

- Methodology definition
- Workflow definition
- Issue definition
- Roles definition
- Risk management
- Progress tracking
- Continuous improvement initiatives

### Delivery and execution

- Delivery
- Agile methodology implementation
- Sprint planning effectiveness
- Backlog management
- Retrospective process
- Adaptability to change

### Collaboration and communication

- Business knowledge
- Client or stakeholder satisfaction
- Communication
- Stakeholder engagement
- Daily standup effectiveness
- Team satisfaction

### Culture and values alignment

- Raise the bar
- Do what I say
- Geek out

These indicators are sensitive and subjective. Treat them as conversation-driven evidence unless there are structured feedback artifacts. Record who validated them.

### AI-native management readiness

This does not measure AI tool usage. It measures whether management artifacts are structured enough for AI-assisted execution:

- Knowledge structure and documentation density
- Decision traceability and governance explicitness
- Workflow determinism and operational clarity
- Feedback loops and continuous learning signals
- Human signal and cultural transparency

## Scoring rules

- Use the 1 to 5 maturity scale.
- Score 1 means low, reactive, implicit, undocumented, or highly variable.
- Score 3 means defined, observable, or partially mature with consistency gaps.
- Score 5 means explicit, repeatable, measurable, and evidence-driven.
- Do not treat score 3 as average performance; it means moderate structural maturity.
- Do not average subjective indicators without explaining weighting and validation.
- For low-confidence scores, record the missing evidence and who should validate it.

## Output

Use `references/default-template.md` for the management unit scorecard.

## References

- `references/default-template.md` - default management unit template
- `references/example-team-assessment.md` — example assessment for an engineering management unit
- `project-assessment-evidence` - evidence map
- `project-assessment` - multi-unit router
- `planning` - planning and estimation evidence
- `development-workflow` - workflow, DoR, DoD, and validation evidence
- `meeting-minutes`, `decision-log`, `agreement`, `incident` - common management evidence artifacts
