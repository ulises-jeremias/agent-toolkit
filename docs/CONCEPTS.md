# Public concept model

One mental model for how agent-toolkit pieces fit together. Within the toolkit layer, two conceptual **planes** share one repo and one V binary — see [Two Planes](#two-planes-within-the-toolkit-l15--capability-vs-runtime) below. Ownership **Layers** (`L1`/`L1.5`/`L3`) are separate from Loop tier **Stages** (`L1`/`L2`/`L3` mutation-safety) — see terminology note in `docs/ARCHITECTURE.md`.

## Ownership Layers (Machine → Toolkit → Workspace → Project)

| Layer | Repo / location | Role |
|-------|-----------------|------|
| **L1 — Machine** | [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation) | Machine provisioning — chezmoi, shell, packages, LLM policy |
| **L1.5 — Toolkit** | **agent-toolkit** (this repo) | Capability + Runtime planes (see below) |
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

## Two Planes within the Toolkit (L1.5 — Capability vs Runtime)

No code split — one repo, one `build/agent-toolkit` binary, one Release. Canonical definition: [`docs/ARCHITECTURE.md#two-planes-within-the-toolkit-l15--capability-vs-runtime`](ARCHITECTURE.md#two-planes-within-the-toolkit-l15--capability-vs-runtime) — **Capability** (what is distributed: `skills/`/`agents/` → `distributions/products.yaml` → `plugins/`) vs **Runtime** (what is executed: `workspace`/`memory`/`project`/`loop`/`swarm`).

Summary: Capability data is **embedded** in the binary (`embedded_data.v`, ADR-026) and resolved via `AGENT_TOOLKIT_ROOT` → `XDG` → `embedded` → `FHS` (ADR-015/026). See `docs/adrs/ADR-015-runtime-resolution.md` and `docs/adrs/ADR-026-full-embed.md`.

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

The pack content is surfaced by `agent-toolkit workspace context`. These packs are local to one workspace. They have no connection to the toolkit repository solution packs.

### 3. Loop `--pack` overrides (loaded by `loop run --pack`)

Loop packs are **YAML files that override loop settings at runtime**. A user passes `--pack <path>` to `agent-toolkit loop run`. The pack resolves relative to the workspace `packs/` directory. The loader (`loop/pack.py`) merges enabled, cadence, budget, tier, and other fields from the pack into the loop meta before the loop runs.

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

See also: `packs/README.md` (solution packs), `workspace load` CLI help, `loop/pack.py` (override logic), `docs/adrs/ADR-006-packs-docs-only.md`.

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

Execution budget (`loop/budget.py`, `swarm/budget.py`) measures runtime
token/cost/wall-clock usage during or after model invocation. Context
budget and execution budget are separate dimensions. A small execution
budget does not protect against a large composed prompt. A large context
footprint can degrade agent quality even when runtime limits are not hit.

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

## Swarms (ADR-008)

Swarms extend the layer model with backend-neutral multi-agent orchestration:

- **Conceptual architecture:** orchestration engine owns *what* work exists (recipes, roles, handoffs, budgets, worktrees, human gates); UI backends (Herdr recommended, tmux fallback, headless) only display sessions; runner adapters (OpenCode primary, plus Muse/Claude/Codex/Cursor/Copilot, and `skeleton` for offline demo) only run agents. Filesystem state under `.agent-toolkit/swarm/runs/<run-id>/` is authoritative.
- **Repo ownership:** `agent-toolkit` owns runtime (engine, CLI, recipes, handoff/budget/worktree logic, runner + Herdr/tmux adapters). [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation) installs dependencies (`agent_swarms.enabled=true` → tmux, Herdr, `herdr integration install opencode`). [agentic-harness](https://github.com/ulises-jeremias/agentic-harness) demonstrates usage. See [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md).
- **Recipes & elastic promotion:** `pair` (implementer → reviewer → human), `team` (planner → implementer → reviewer → architect → human, plan gate), `full` (… → refactorer → hardener → qa → human). Lazy creation — only ready roles start. `pair → team → full` promotion preserves run ID, branches, artifacts, budget, trace. See [SWARM_RECIPES.md](SWARM_RECIPES.md).
- **Worktrees & handoffs:** one isolated worktree per writer on `agent-toolkit-swarm/<run-id>/<role>`; code moves only via validated full 40-char SHAs. Durable filesystem queue `handoffs/{outbox,queued,active,completed,failed}/`. See [SWARM_HANDOFFS.md](SWARM_HANDOFFS.md).
- **Budgets, model profiles, permissions, gates:** semantic profiles `economy`/`balanced`/`quality`/`private` map task classes `planning`/`coding`/`review`/`architecture`/`hardening`/`qa` to `provider/model` (discover via `opencode models` / `swarm models`). Pricing stored separately, unknown honestly reported. Budgets: tokens/cost/wall-clock/concurrency/round-trips/per-role. Permissions: planner `read-only`, implementer `writer`, reviewer `reviewer-writer`, integrator `merge: ask`; deny `external_directory`/`push`/`release`/`base-merge` by default. Human gates: plan, architecture, cost escalation, final integration. See [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) and [SWARM_SECURITY.md](SWARM_SECURITY.md).
- **State locations, privacy, cleanup:** `run.yaml`, `state.json` (versioned, atomic), `trace.jsonl`, `budget.json`, `ownership.json`, `approvals.json`, `artifacts/`, `handoffs/`, `prompts/`, `runner/opencode/agents/` per run. No cloud/telemetry/transcript by default; secrets redacted (`sanitize_args`), generic UI wake-ups only. `swarm stop` preserves state; `swarm cleanup` removes only Toolkit-owned worktrees, refuses dirty without `--force`, never deletes branches/user worktrees.
- **Herdr plugin & tmux fallback:** thin Herdr plugin at `integrations/herdr/agent-toolkit-swarm/` (actions Start Pair/Team/Full, Open Status/Handoffs/Report, Pause/Resume/Stop/Clean Up) delegates to `agent-toolkit swarm`. `--ui auto` → Herdr → tmux; `--ui herdr` fails with install guidance if missing; `--ui tmux` uses isolated server `agent-toolkit-swarm-<run-id>` with `shlex.quote` safety. See [SWARM_HERDR.md](SWARM_HERDR.md) and [SWARM_TMUX.md](SWARM_TMUX.md).
- **Offline/fake demo:** `swarm plan` is side-effect free; `--runner skeleton` (always available) and `--ui tmux` work fully offline for exploration/CI. Pricing fallback is explicit and requires approval.
- **Extension guide:** add recipes under `~/.config/agent-toolkit/swarm/recipes/` or `.agent-toolkit/swarm/recipes/`, map roles to personas in `agents/` and `model_profile` to task classes, validate with `validate_recipe()`. See [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md). Mermaid diagrams for ecosystem boundaries, runtime layers, pair/team/full, handoff state machine, run state machine, and Herdr/tmux adapter separation live in [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md).
