# Public concept model

One mental model for Agent Toolkit's portable content and CLI. Veasel Code owns the interactive coding runtime; Agent Toolkit owns portable skills, agent definitions, MCP templates, context/workflow recipes, provenance, and compatibility tooling. Ownership **Layers** (`L1`/`L1.5`/`L3`) are separate from Loop tier **Stages** (`L1`/`L2`/`L3` mutation-safety) — see terminology note in `docs/ARCHITECTURE.md`.

## Ownership Layers (Machine → Toolkit → Workspace → Project)

| Layer | Repo / location | Role |
|-------|-----------------|------|
| **L1 — Machine** | [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation) | Machine provisioning — chezmoi, shell, packages, LLM policy |
| **L1.5 — Toolkit** | **agent-toolkit** (this repo) | Portable capabilities, provenance, compatibility, and CLI |
| **L3 — Workspace** | [agentic-harness](https://github.com/ulises-jeremias/agentic-harness) | Harness workspace — `knowledge/`, `repos/`, `projects/`, packs |
| **Project Overlay** | per-repo | Per-project overrides — `AGENTS.md`, `.cursor/rules/`, local `loops/` |

> Canonical layer responsibilities and diagram: [`docs/ARCHITECTURE.md#ownership-layers-machine--toolkit--workspace--project`](ARCHITECTURE.md#ownership-layers-machine--toolkit--workspace--project).

## Toolkit internals (L1.5) — build pipeline

| Layer | Location | What it is | When to edit |
|-------|----------|------------|--------------|
| **Canonical content** | `skills/`, `agents/`, `loops/` | Source-of-truth capability definitions | Adding or changing skills/agents/loops |
| **Products** | `distributions/products.yaml` | Named bundles of skills/agents/hooks/MCP for plugins | Shipping a marketplace plugin |
| **Compiler output** | `plugins/` | Agent Plugins `plugin.json` + `skills/` + `mcp.json` + target-native manifests + copied SKILL.md/AGENT.md | **Generated — canonical** — do not hand-edit; validated by `build --check` (ADR-003/004) + `validate-agent-plugins.py` |
| **Profiles** | `profiles/` | **Deprecated** install overlay per tool (ADR-004) — fallback only | **Not** the canonical skill SoT — prefer compiled `plugins/`; install resolution lives in `modules/agent_toolkit_core/install.v` |
| **Packs** | `packs/` | Solution-oriented README + config | **Docs-only** workflow templates; not loaded by compiler (ADR-006) |
| **Presets** | *(planned)* | Named capability sets for `agent-toolkit.yaml` projects | Future — not implemented yet |

## Portable source and CLI

Canonical content is authored in `skills/`, `agents/`, and related source
trees, composed in `distributions/products.yaml`, then compiled into validated
consumer output. The V CLI installs, inspects, and provides compatibility for
these capabilities. Its offline source-resolution contract is documented in
`docs/adrs/ADR-015-runtime-resolution.md`,
`docs/adrs/ADR-026-full-embed.md`, and
`docs/adrs/ADR-047-offline-resource-sidecar.md`.

The repository retains older workspace automation commands for workspace
users. Swarm v1 `start` and `init` are rejected by current public dispatch;
inspect and preserve existing user-owned state. Issues
[#1676](https://github.com/ulises-jeremias/agent-toolkit/issues/1676) and
[Veasel #629](https://github.com/veasel-labs/veasel/issues/629) are closed with
evidence for the product boundary and Veasel's own orchestration—not for an
automatic migration of every user's data. See the
[Swarm disposition](SWARM_V1_DISPOSITION.md) and the
[former Desktop migration map](LEGACY_DESKTOP_MIGRATION.md).

## Three kinds of packs

The word "pack" has three distinct meanings in this project. The noun is not ambiguous, but the context selects the meaning.

### 1. Solution packs (`packs/` in the toolkit repo)

Solution packs are **docs-only workflow templates** under the repository `packs/` directory. Each pack bundles related skills, agent personas, loop templates, and MCP configurations into an outcome-oriented workflow for a common team setup. Examples: `oss-maintenance`, `engineering-workflow`, `delivery-discipline`.

A solution pack is a directory with `README.md`, `config.yaml`, and optional references to loops and skills. The compiler does **not** load solution packs. `distributions/products.yaml` is the sole compiler input for marketplace plugins. See `docs/adrs/ADR-006-packs-docs-only.md`.

### 2. Workspace packs (`packs/*.yaml` in a harness workspace)

Workspace packs are **YAML context files** inside a harness workspace `packs/` directory. They carry per-client or per-project context: project names, notes, and configuration. A user loads a workspace pack with:

```bash
agent-toolkit workspace load packs/my-client.yaml
```

The pack content is surfaced by `agent-toolkit workspace context`. These packs are local to one workspace. They have no connection to the toolkit repository solution packs. Use the CLI to inspect and load a workspace pack; the former Desktop context selector is retired and is not a supported management surface. Selecting a pack does not install a capability or execute its content.

### 3. Loop `--pack` overrides (loaded by `loop run --pack`)

Loop packs are **YAML files that override loop settings at runtime**. A user passes `--pack <path>` to `agent-toolkit loop run`. The V loop runner resolves the file path from the given path or the workspace `packs/` directory, then applies the selected loop's supported fields. Parsing lives in `parse_pack_overrides` in `modules/agent_toolkit_core/loop.v`.

A loop pack file has a `loops` key mapping loop names to their override blocks:

```yaml
loops:
  oss-triage:
    enabled: false
    cadence: 12h
    budget:
      max_tokens: 30000
```

### Summary

| Noun | Location | Loaded by | Purpose |
|------|----------|-----------|---------|
| Solution pack | `packs/<name>/` (repo) | Not loaded — docs-only reference | Workflow template for a team setup |
| Workspace pack | `packs/*.yaml` (workspace) | `agent-toolkit workspace load` | Per-client context bundle |
| Loop pack | `packs/*.yaml` (workspace) | `agent-toolkit loop run --pack` | Runtime loop setting overrides |

See also: `packs/README.md` (solution packs), `workspace load` CLI help,
`modules/agent_toolkit_core/loop.v` (`parse_pack_overrides`), and
`docs/adrs/ADR-006-packs-docs-only.md`.

## People — durable workspace collaborators (not a toolkit capability plane)

> **Archive notice:** The former Desktop roster and Person Start UI are not
> current Agent Toolkit features. The schema and validator below are retained
> to preserve existing workspace data; see [People data compatibility](PEOPLE.md).

Durable People are **workspace-owned collaborators** declared in
`people/<id>.json` (`agent-toolkit/person@1`), not toolkit catalog capabilities
or runtime characters. Historical Electron builds provided roster CRUD,
reviewed Munder import, and a Start flow; those UI/runtime behaviors are
retired from Agent Toolkit. The toolkit retains canonical schemas, scaffold,
mirror sync, validator, and runtime API contracts; workspace data remains the source of truth
([docs/PEOPLE.md](PEOPLE.md), [ADR-036](adrs/ADR-036-durable-people.md)). Agent
definitions (`agents/`), agent profiles (`profiles/`), People, AgentSessions,
and temporary swarm roles stay distinct. Configuring a Person never creates a
world character; only a live runtime session associated with a project can do
that. `munder-difflin/hire@1` is a one-way reviewed import format: it never
spawns, installs code, or syncs live. Import mapping lives in
`capabilities/imports/`.

## Key rules

1. **Products compose capabilities** — edit `distributions/products.yaml`, then `build`.
2. **Plugins are compiler output** — `plugin.json` (Agent Plugins 1.0 portable for Cursor/VS Code/Copilot/Codex/Kiro) + Claude `.claude-plugin/`, Cursor `.cursor-plugin/`, etc. See `docs/AGENT_PLUGINS.md`.
3. **Profiles are a deprecated install overlay (ADR-004)** — not the canonical skill SoT; install prefers compiled `plugins/` where implemented (`modules/agent_toolkit_core/install.v`).
4. **Packs are **docs-only** bundles (ADR-006)** — they reference loops/skills but are not loaded by the compiler today.

## README / docs alignment

- Solution pack names in README match directories under `packs/` (`oss-maintenance`, not `oss-ecosystem`).
- Product descriptions in README match `distributions/products.yaml` skill/agent lists.

See also: `docs/SCOPE.md` (CLI surfaces), `packs/README.md`, `distributions/products.yaml`, `docs/adrs/ADR-004-profiles-vs-plugins.md` (profiles vs plugins deprecation timeline).

## Context budget vs execution budget

The `workspace budget` command analyzes the **context footprint** of packs,
profiles, personas, and AGENTS.md before any execution. It counts characters
and estimates tokens (chars / 4 heuristic). It warns about large sections,
duplicate blocks, and high total footprint. It needs no network or LLM.

Loop execution enforces supported token and wall-clock limits from run traces
in `modules/agent_toolkit_core/loop.v`. Historical Swarm v1 recipes declared
token, cost, concurrency, round-trip, and wall-clock budgets; Swarm v1 no longer
starts new runs and those declarations are not current Veasel controls. Check
each supported runtime's current contract before treating a budget as a
guardrail.
Context-budget analysis in `workspace.v` is a separate dimension: a small
execution budget does not protect against a large composed prompt, and a large
context footprint can degrade agent quality even when runtime limits are not
hit.

Token estimates are approximate. The heuristic (chars / 4) works for
English text. It does not replace provider tokenization for billing.
Use `workspace budget` as a pre-flight check, not as exact accounting.

## Profiles vs plugins (ADR-004)

- **Do not hand-edit `plugins/`** — it is generated by `agent-toolkit build` from `skills/` + `agents/` + `distributions/products.yaml`. CI fails on drift (`build --check`).
- **`profiles/` is a deprecated install overlay** — not the canonical skill source of truth. Add new capabilities to `skills/` / `agents/` + `distributions/products.yaml`, not to `profiles/` alone.
- **Install resolution (V):** `modules/agent_toolkit_core/install.v` (`compiled_agent_files`, `agent_dest_mappings`, `muse_skill_mappings`). Agents prefer compiled `plugins/<product>/agents/*/AGENT.md` when present, else `profiles/<tool>/agents/`. Muse skills prefer `plugins/` product skill trees, then repo `skills/`, then `profiles/muse-code`. Other tools still copy from `profiles/` for rules/config overlays. Optional override: `AGENT_TOOLKIT_INSTALL_SOURCE`.

## Third-party boundary — `plugins/` vs `skills-external/` (workstation)

- **`plugins/` is first-party-only** — only `skills/` + `agents/` curated in this repo plus `distributions/products.yaml` are compiled. Third-party npm / github / url packs (JIRA 14, Confluence 17, former `ui-ux-pro-max`) never belong in `products.yaml` or `plugins/`; that would bloat every consumer and violate vendor-neutral trust (`docs/TRUST.md`, `AGENTS.md:81`).
- **External packs live in agentic-workstation** — `home/dot_local/share/agentic-workstation/.chezmoiexternal.toml.tmpl` (`skills-external/<pack>`) + `dots-skills sync` (universal compatibility). Workstation owns opt-in (`install_skill_jira_assistant=true` → `chezmoi apply --refresh-externals`) and `.chezmoiremove` cleanup of legacy flat installs. See `agentic-workstation/docs/SKILLS.md` and `agentic-workstation/docs/AGENT_TOOLKIT.md` “Third-party boundary”.

## Swarm v1 (historical)

> **Retired from new runs:** Current Toolkit CLI and HTTP dispatch reject
> Swarm v1 `start` and `init`. The records and recovery controls are kept for
> user-owned state; they are not the target Toolkit product or Veasel runtime.

Preserve existing `.agent-toolkit/swarm/` records and worktrees. Veasel does
not automatically import Swarm history. Read the
[disposition and migration boundary](SWARM_V1_DISPOSITION.md) before handling
old records; do not use historical recipe or adapter guides as current setup
instructions.
