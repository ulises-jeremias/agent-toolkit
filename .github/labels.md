# Issue labels

Issue templates reference GitHub labels that must exist on the repository.
Maintainers create or update labels with `gh label create` (see commands below).

| Label | Color | Used by | Description |
|-------|-------|---------|-------------|
| `agent-request` | `#0E8A16` | [agent-request.yml](ISSUE_TEMPLATE/agent-request.yml) | Request for a new agent persona |
| `enhancement` | (default) | agent-request, feature-request | New feature or improvement |
| `bug` | (default) | bug-report.yml | Something isn't working |
| `documentation` | (default) | documentation.yml | Documentation improvements |

## Create or refresh template labels

```bash
gh label create agent-request --description "Request for a new agent persona" --color "0E8A16" --force
```

When adding a new issue template label, update this file and run the corresponding
`gh label create` command so new issues apply labels successfully.
