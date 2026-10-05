# Desktop user journeys

Status: acceptance journeys for the shipping Electron Desktop. The executable
coverage ledger is [`workflows.yaml`](workflows.yaml). These journeys are desired
outcomes, not claims that every step is implemented.

| Journey | Required path and outcome |
|---|---|
| Clean first-time user | Open installed app → understand purpose → create workspace → detect tools → choose useful skills → review destinations → install → validate → useful Attention view. No terminal setup or sibling repo. |
| Existing Agent Toolkit user | Find existing setup → explain detected configuration and installed artifacts → use in place → validate. Preserve customization. |
| Existing workspace/harness user | Classify environment → explain compatibility and proposed adapter changes → preview → explicitly use in place or copy/import → validate without overwriting user files. |
| Capability discovery | Search by task/tool → filter actual catalog → inspect description, provenance, dependencies and verified compatibility → choose relevant action. |
| Skill install | Select skills and coding tools → choose scope → preview conflicts/files → apply → observe real artifacts/receipt → retry partial failure or undo verified changes. |
| Project Copilot instructions | Select one linked project → review the exact repository file and contents → preserve conflicts → explicitly install → inspect receipt → remove only the unchanged receipt-owned file. |
| Coding-agent integration | Detect catalog-supported executable with bounded search → choose executable if missing → enable integration → preview/apply → verify → repair or rollback. |
| MCP setup | Find provider → enter secrets into the OS-backed Desktop credential store → preview/apply provider configuration → validate/probe → restart the supervised backend to apply credentials → explain failure and repair. Fail closed without a secure OS keyring; never return saved values to the renderer or write them to MCP configuration. |
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

The backend must classify existing workspaces before Desktop offers in-place use,
adoption, copy, import, or migration. A directory containing one familiar file is
not automatically a valid managed workspace. Never overwrite foreign files as a
side effect of opening a workspace.
