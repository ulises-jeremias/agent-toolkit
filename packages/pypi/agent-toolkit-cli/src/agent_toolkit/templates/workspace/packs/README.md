# Context Packs

Packs bundle context for a specific client, project, or domain.

## Usage

```bash
agent-toolkit workspace context load packs/my-client.yaml
```

## Structure

```yaml
# packs/my-client.yaml
name: my-client
description: Context for MyClient engagement
repos:
  - owner/repo1
  - owner/repo2
env:
  JIRA_PROJECT: MYPROJ
notes: |
  Key conventions and decisions for this client.
```
