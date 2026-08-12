# Code-Quality Pack — docs-only

Curated for code-quality per #390: MegaLinter + CodeQL + CI.

## Components
- **Skills:** megalinter (oxsecurity/megalinter v10.0.0 external, AGPL-3.0, distribution external), codeql (first-party, 5 modes), gh-fix-ci, inventory
- **Agents:** code-reviewer
- **Loops:** ci-sweeper (optional)

## Setup
```bash
cp packs/code-quality/config.yaml ~/.ai-workspace/packs/code-quality.yaml
```

## Workflow
megalinter (orchestrator v10) → codeql (5 modes) → gh-fix-ci → inventory → PR.

## Trust
megalinter external (AGPL-3.0, redistribution_allowed false, not vendor) + codeql first-party → pack trust_tier: reviewed (external pinned, not vendored).
