# Desktop user journeys

These are acceptance journeys, not current feature claims. Each must cover success,
empty/loading/error states and safe recovery through the production native UI.
See [workflow coverage](WORKFLOW_COVERAGE.md) for current evidence.

| Journey | Required path and outcome |
|---|---|
| Clean first-time user | Open installed app → understand purpose → create workspace → detect tools → choose useful skills → review destinations → install → validate → useful Office. No terminal setup or sibling repo. |
| Existing Agent Toolkit user | Find existing setup → explain detected configuration and installed artifacts → use in place → validate. Preserve customization. |
| Existing workspace/harness user | Classify environment → explain compatibility and proposed adapter changes → preview → explicitly use in place or copy/import → validate without overwriting user files. |
| Capability discovery | Search by task/tool → filter actual catalog → inspect description, provenance, dependencies and verified compatibility → choose relevant action. |
| Skill install | Select skills and coding tools → choose scope → preview conflicts/files → apply → observe real artifacts/receipt → retry partial failure or undo verified changes. |
| Coding-agent integration | Detect catalog-supported executable with bounded search → choose executable if missing → enable integration → preview/apply → verify → repair or rollback. |
| MCP setup | Find provider → explain requirements → enter masked configuration → preview safe changes → apply → probe → explain failure and repair. Never show secrets in logs or previews. |
| Target setup | Explain where skills become available → select tool and scope → show compatibility evidence → install → inspect actual receipt → rollback. Use "coding tools" before "targets". |
| Job operation | Configure real operation → review → start → observe logs/status/duration → cancel, retry or inspect failure. Spawn failure never becomes running. |
| Loop operation | Select template → configure schedule/budget → preview → run or enable → observe next/previous runs → pause/resume → recover failure. |
| Swarm operation | Choose recipe/project/agents → preview scope/budget → launch → observe real topology, handoffs, artifacts and approvals → attach session → cancel/recover. |
| Doctor repair | Run checks → understand issue/impact/what remains safe → preview repair → apply → verify → undo when supported or follow recovery guidance. |
| Terminal lifecycle | Create or attach → type → split/switch/focus → resize/search/select/copy/paste → observe exit → dismiss or explicitly restart. Global shortcuts do not consume input. |
| Workspace switching | Choose validated workspace → explain active work/session implications → switch atomically → see correct context → recover invalid destination without losing current context. |
| Failure recovery | Explain what failed, what changed and what remains safe → offer recommended retry/repair/undo → expose technical detail on request. Preserve user content and report partial success. |

## Workspace vocabulary and safety

- **Use in place / reference:** use the selected environment at its existing path;
  no copy or ownership transfer. Say which optional changes are proposed.
- **Adopt:** register an existing environment for management after an explicit
  compatibility check and reviewed changes. Do not imply arbitrary overwrite rights.
- **Copy:** duplicate selected content into a new location; retain the source.
- **Import:** ingest selected configuration/content with explicit mappings and
  conflict rules. Show whether content is copied or referenced.
- **Migrate:** transform a versioned format with a backup and recovery plan.

One Engine classifier must distinguish managed Agent Toolkit, existing Agent
Toolkit, My AI Workspace-style, harness-compatible, arbitrary project and
invalid/legacy environments. Existing heuristics are inconsistent. The minimum
managed workspace schema and transactional scaffold remain release-blocking work.
Do not call an arbitrary cwd a valid workspace because it contains one directory.

Executable discovery must not source arbitrary shell startup files. Search bounded
catalog-supported locations and allow explicit selection of an executable. Explain
what was found and distinguish detected, configured, enabled and verified states.

## Acceptance personas

| Persona | Special acceptance condition |
|---|---|
| A: clean machine | Fresh HOME/XDG and launcher-like PATH; no checkout resources |
| B: Cursor only | Detect existing tool without requiring Agent Toolkit knowledge |
| C: Claude Code + custom skills | Preserve custom skills and explain conflicts |
| D: existing CLI user | GUI observes real existing install state |
| E: git-managed advanced workspace | Preserve Git history, files and uncommitted work |
| F: harness-compatible setup | Optional adapter with explicit compatibility boundaries |
| G: broken/legacy workspace | Diagnose without falsely declaring ready or overwriting data |
| H: multiple workspaces | Isolate state, operations and session ownership on switch |
