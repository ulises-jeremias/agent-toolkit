# Engineering Workflow Pack

End-to-end engineering delivery workflow covering planning, implementation, review, and deployment.

## Components

- **Skills**: workflow-generic-project, development-workflow, gh-contribution-planner
- **Agents**: architect, planner, code-reviewer, security-reviewer
- **Loops**: pr-babysitter (L2), ci-sweeper (L2)

## Setup

```bash
cp packs/engineering-workflow/config.yaml ~/.ai-workspace/packs/engineering-workflow.yaml
# Edit enabled skills, agents, or loop cadence as needed
cp -r loops/pr-babysitter loops/ci-sweeper ~/.ai-workspace/loops/
```

## Status

✅ Ready — usable `config.yaml` shipped. See [packs/README.md](../README.md) for pack conventions.
