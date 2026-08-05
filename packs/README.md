# Solution Packs

Solution packs bundle related skills, agent personas, loop templates, and MCP configurations
into outcome-oriented workflows for common team setups.

## Available Packs

| Pack | Description | Status |
|------|-------------|--------|
| [oss-maintenance](oss-maintenance/) | Automate PR review, issue triage, and daily briefings across OSS repos | ✅ Ready |
| [engineering-workflow](engineering-workflow/) | End-to-end engineering delivery: planning → implementation → review → deploy | ✅ Ready (config shipped) |
| [delivery-discipline](delivery-discipline/) | Ticket hygiene, traceability, and process compliance | ✅ Ready (config shipped) |

## Using a Pack

Each pack has a `config.yaml` for customization and a `README.md` with setup instructions.

```bash
# Example: set up OSS maintenance for your repos
cp packs/oss-maintenance/config.yaml ~/.ai-workspace/packs/
# Edit repos list in config.yaml
# Then use loops/oss-pr-monitor, loops/oss-triage, loops/oss-daily-briefing
```

## Creating a Pack

A pack is a directory containing:
- `README.md` — purpose, setup, usage
- `config.yaml` — configurable parameters
- Optional: `AGENTS.md` snippet, skill list, loop references
