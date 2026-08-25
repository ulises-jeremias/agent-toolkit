# Architecture

agent-toolkit sits in a four-layer ownership stack and, within its own layer, separates two conceptual **planes** that share one codebase and one release artifact.

**Canonical CLI:** native **V 0.5.2** (`import json`, not json2). Build with `./make.vsh build-cli` → `build/agent-toolkit`. PyPI/`uv`/`npm` are distribution adapters over that binary. See [`docs/HOW_TO_DEVELOP_V.md`](HOW_TO_DEVELOP_V.md) and [`docs/v/README.md`](v/README.md).

---

## Ownership Layers (Machine → Toolkit → Workspace → Project)

Ownership is layered; each layer is managed by a different repo. Toolkit layers use `L1`/`L1.5`/`L3` labels (stable since early docs); **Loop tiers `L1`/`L2`/`L3` are mutation-safety *Stages* in the Loop Engineering discipline, not ownership Layers** — see note below.

| Layer | Repo | Role |
|-------|------|------|
| **L1 — Machine** | [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation) | Machine provisioning — chezmoi, shell, packages, LLM policy |
| **L1.5 — Toolkit** | **agent-toolkit** (this repo) | Capability distribution + runtime harness — skills, agents, MCP, plugins, loops, workspace/memory/projects/devcompanion/swarm |
| **L3 — Workspace** | [agentic-harness](https://github.com/ulises-jeremias/agentic-harness) | AI workspace scaffold — `knowledge/`, `repos/`, `projects/`, packs, persona handoffs |
| **Project Overlay** | per-repo | Per-project overrides — `AGENTS.md`, `.cursor/rules/project.mdc`, local `loops/` |

### L1 — Machine / Workstation

The outermost layer provisions the machine and installs the toolkit. It is responsible for:

- Cloning or updating the toolkit repository
- Running `agent-toolkit install` (canonical **V** CLI from GitHub Release, Homebrew, AUR `agent-toolkit-bin`, PyPI launcher, or npm — ADR-021; ADR-007 removed the bash install wrappers) to copy profiles/plugins to the right tool-specific locations
- Managing credentials and environment variables (but never storing secrets in this repo)
- Scheduling recurring loops via a cron or loop-runner daemon

This layer is typically managed by a separate bootstrapping tool (such as a dotfiles manager or a workstation provisioner). agent-toolkit itself does not own this layer — it provides the V CLI and profiles.

### L1.5 — Toolkit (this repo)

The middle layer is agent-toolkit itself. It owns **two planes without splitting code or releases** — see [Two Planes](#two-planes-within-the-toolkit-l15--capability-vs-runtime) below. At a high level it is the single source of truth for both planes (details in plane table).

This layer is meant to be stable and opinionated. Changes here propagate to every workspace and project that uses the toolkit via `AGENT_TOOLKIT_ROOT` / embedded data.

### L3 — Workspace (Harness)

The harness workspace is the multi-repo overlay that consumes the toolkit's runtime commands (`workspace`, `memory`, `project`, `loop`, `devcompanion`, `swarm`). It provides `knowledge/`, `repos/`, `projects/`, `packs/*.yaml` context bundles, and persona handoff state. See [agentic-harness](https://github.com/ulises-jeremias/agentic-harness).

### Project Overlay

The innermost layer is the per-project customization. Each project can:

- Override or extend profile configurations (e.g. add project-specific rules to `.cursor/rules/`)
- Define a project-level `AGENTS.md` or `.claude/CLAUDE.md` that overrides toolkit defaults
- Add project-local loops in a `loops/` directory
- Compose a project pack that references toolkit skills plus local additions

Project overlays never modify the toolkit itself. They sit on top and take precedence for that project only.

> **Terminology note — Stages vs Layers:** Loop tiers `L1` (observe/propose), `L2` (controlled mutations), `L3` (high-autonomy merge/close) are **Stages** in the Loop Engineering discipline (and similarly `L0`–`L3` in Context/Harness/Loop Engineering). They describe mutation safety, not ownership. Ownership **Layers** are `L1` Machine / `L1.5` Toolkit / `L3` Workspace + Project Overlay. Never use `L1`/`L2`/`L3` to mean both — say "Tier L1 loop" vs "Layer L1 machine".

---

## Two Planes within the Toolkit (L1.5 — Capability vs Runtime)

The toolkit layer itself separates two conceptual planes that **share one repo, one V binary, and one release** — no code split. The distinction clarifies what is *distributed* vs what is *executed* and how data is resolved at runtime.

| Plane | Owns | Key dirs / contracts | Runtime resolution |
|-------|------|----------------------|--------------------|
| **Capability Plane** | What is *distributed* to AI tools — portable capabilities and their compiled artifacts | `skills/` + `agents/` (SoT), `distributions/products.yaml` (composition), `plugins/` (compiler output, canonical — ADR-004), `profiles/` (**deprecated** install overlay, fallback only), `mcp/templates/` + `mcp/registry/`, `packs/` (docs-only, ADR-006) | Authoritative data lives **embedded** in the binary payload (`modules/agent_toolkit_core/embedded_data.v`, `+4.8M` ELF) plus FHS `/usr/share` sidecar compat — see **ADR-026** (Full-Embed). Build verifies with `agent-toolkit build --check`. |
| **Runtime Plane** | What is *executed* from a harness workspace — automation, memory, and orchestration that consumes Capability data | `workspace` / `memory` / `project` / `loop` / `devcompanion` / `swarm` commands; `serve` programmatic API surface over both planes (TUI retired, ADR-030); `| Resolves toolkit data via ordered tiers `AGENT_TOOLKIT_ROOT` → `XDG` → **embedded `3a`** → FHS `3b` → sidecar `3c` → checkout → CWD (sanitized against harness `knowledge/`). Offline never downloads — see **ADR-015** (Runtime Resolution, amends ADR-005) and **ADR-026** `paths.v` tiers / `data_io.v` abstraction. |

**Without splitting code:** Both planes are built by the same `make.vsh build-cli` (`gen-embedded` → `build/agent-toolkit`) and shipped in the same GitHub Release / Homebrew / AUR / PyPI / npm / Docker artifacts (ADR-018/021/023/024/025). The split is documentary: capability edits go to `skills/` + `products.yaml` then `build`; runtime is exercised from a harness via `agent-toolkit loop run …` etc. References: **ADR-015** runtime order and **ADR-026** full-embed (supersedes ADR-011) — see `docs/adrs/ADR-015-runtime-resolution.md` and `docs/adrs/ADR-026-full-embed.md`.

---

## How the Layers Interact

```
┌─────────────────────────────────────────────────────┐
│  L1 — Machine / Workstation                         │
│  (chezmoi, bootstrap script, LLM policy)            │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  L1.5 — Toolkit (this repo) — two planes     │  │
│  │  Capability: skills/agents/plugins/profiles/  │  │
│  │              mcp/packs/distributions          │  │
│  │  Runtime:    workspace/memory/project/loop/   │  │
│  │              devcompanion/swarm + serve API   │  │
│  │                                               │  │
│  │  ┌───────────────────────────────────────┐   │  │
│  │  │  L3 — Workspace (Harness)             │   │  │
│  │  │  knowledge/ repos/ projects/ packs/   │   │  │
│  │  │                                       │   │  │
│  │  │  ┌─────────────────────────────────┐ │   │  │
│  │  │  │  Project Overlay                │ │   │  │
│  │  │  │  AGENTS.md / .cursor/rules/     │ │   │  │
│  │  │  │  loops/my-loop/loop.yaml        │ │   │  │
│  │  │  └─────────────────────────────────┘ │   │  │
│  │  └───────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

Precedence (highest to lowest): Project overlay > Workspace harness > Toolkit defaults (Capability + Runtime) > tool built-ins.

---

## Core Concepts

### Skills

A skill is a self-contained capability definition that tells an AI tool what to do in a specific situation. Every skill is a directory containing a single `SKILL.md` file — the human-readable (and AI-readable) prompt body, written in Markdown with YAML frontmatter declaring `name`, `description`, `tools`, `triggers`, and `requires`.

No `skill.json` is required. Skills follow the [Agent Skills spec](https://github.com/vercel-labs/skills) (`SKILL.md` frontmatter only). See `docs/MIGRATION.md` for notes on retiring legacy `skill.json` files.

Skills are portable: the same skill directory can be referenced by Claude Code, Cursor, OpenCode, Windsurf, GitHub Copilot, and Pi Coding Agent. Each tool reads the file format it understands.

Skills are grouped into domains (see `skills/`) and published individually or as part of packs.

### Profiles

A profile is the tool-specific configuration that wires skills into an AI tool. Because each tool has a different configuration format, agent-toolkit ships a separate profile for each:

- `profiles/claude-code/` — `CLAUDE.md` (system prompt) + `settings.json` (plugins and agents)
- `profiles/cursor/` — `.mdc` rule files for Cursor's Rules for AI feature
- `profiles/opencode/` — `opencode.json` + agent overlay files
- `profiles/copilot/` — `copilot-instructions.md` for GitHub Copilot
- `profiles/windsurf/` — rule files + `memories/global_rules.md`
- `profiles/pi/` — skill files for Pi Coding Agent

Profiles reference skills but do not duplicate them. `agent-toolkit install` (`modules/agent_toolkit_core/install.v`) copies profile overlays and/or compiled plugin agents into the locations each tool expects.

> **Note (ADR-004):** `profiles/` is a **deprecated install overlay**, not the canonical skill source of truth. `plugins/` is generated by `agent-toolkit build` from `distributions/products.yaml` + `skills/` / `agents/` and must not be hand-edited (`build --check` enforces digests). Install resolution is implemented in `modules/agent_toolkit_core/install.v`: compiled agent `AGENT.md` under `plugins/` is preferred when present; otherwise the installer copies from `profiles/<tool>/`. Muse skill install prefers `plugins/` then `skills/` then `profiles/muse-code`. Add new capabilities to `skills/` + `products.yaml`, not to `profiles/` alone.

### Loops

A loop is a recurring agentic workflow with a declared goal, safety gates, and a token budget. Each loop lives in `loops/<name>/loop.yaml` and contains:

- `goal` — what the loop is trying to accomplish
- `allowlist` / `deny` — explicit lists of permitted and forbidden actions
- `budget` — maximum tokens, runs per day, and wall-clock seconds
- `exit_conditions` — when the loop should stop (goal met, budget exhausted, human escalation)
- `request` — the prompt template the loop runner executes

Loops follow a three-tier **Stage** model (Tier L1 / L2 / L3) based on mutation risk — **Stages, not ownership Layers**. See [LOOPS.md](LOOPS.md) for details. Terminology note in [Ownership Layers](#ownership-layers-machine--toolkit--workspace--project) applies.

### Packs

A pack bundles skills, agents, and loops into an outcome-oriented workflow. A pack is a `pack.yaml` file (or directory with a `README.md` and `config.yaml`) that declares which skills to activate, which loops to enable, and any configuration overrides. **Packs are docs-only** (ADR-006): they are not loaded by `agent-toolkit build`; product composition lives in `distributions/products.yaml`.

Packs are the recommended entry point for teams. Instead of picking individual skills, you load a pack and get a coherent setup for your context (OSS maintainer, startup delivery team, data platform, etc.).

### Swarms

Swarms coordinate multiple coding-agent sessions with worktree isolation and durable handoffs. See `docs/SWARMS.md` and `docs/SWARM_ARCHITECTURE.md`. Orchestration engine + UI backends (Herdr/tmux) + runner adapters (OpenCode etc.) with filesystem state authoritative, commit-based handoffs, human gates, and budgets. Details in ADR-008.

---


## Repository Structure

Live inventory is `agent-toolkit inventory` / `catalogs/` — do not hardcode counts in docs (historical snapshot: ~85 skills / 14 domains, 25 agents = 11 holistic + orchestrator + 13 specialists, 10 loops, 7 packs, 7 MCP providers).

```
agent-toolkit/
├── skills/                      # SKILL.md trees by domain (see inventory)
│   ├── core/  delivery/  design/  forge/  integrations/
│   ├── data/  tooling/  ops/  loops/
│   ├── agentic-security/  architecture/  cloud/
│   └── accessibility/  quality/
├── agents/                      # personas: 11 holistic + orchestrator + 13 specialists (see docs/AGENT_TAXONOMY.md)
├── plugins/                     # compiler output — canonical (do not hand-edit; build --check)
├── profiles/                    # deprecated install overlay (ADR-004; fallback only)
├── distributions/               # products.yaml — product composition SoT
├── loops/                       # loop.yaml templates (see inventory)
├── mcp/templates/               # providers (incl. chrome-devtools)
├── mcp/registry/                # provider registry
├── packs/                       # docs-only packs (ADR-006)
├── catalogs/                    # generated skill/agent/loop catalogs
├── schemas/
├── modules/                     # V CLI (canonical product)
├── packages/                    # pypi/ + npm/ adapters
├── distribution/                # channel contracts (not Formula/PKGBUILD copies)
├── docs/                        # AGENT_TAXONOMY.md — canonical holistic roster + migration map + routing self-tests
└── scripts/                     # validate-*, generate-catalogs, bump-version
```

### Holistic agent taxonomy — canonical

Eleven holistic roles own every skill's `holistic_owner` in `capabilities/skills/registry.yaml` (85 skills, no orphans). **Optimize for cognitive simplicity, useful context isolation, and independent verification — not fewest agents, not one-per-skill.** Full roster: [`docs/AGENT_TAXONOMY.md`](AGENT_TAXONOMY.md).

| Tier | Agents | How to invoke |
|------|--------|---------------|
| Orchestrator | `assistant` (default), `client-workflow-bootstrap` (meta-generator → packs/knowledge) | Implicit + `@assistant` / `@client-workflow-bootstrap` |
| Holistic (daily) | `planner`, `architect`, `designer`, `implementer`, `reviewer`, `qa-engineer`, `security-engineer`, `platform-engineer`, `researcher`, `data-engineer` (conditional) | `@planner`, `@architect`, `@designer`, … per `assistant` routing |
| Specialist (opt-in) | `code-reviewer`, `security-reviewer`, `agentic-security-reviewer`, `tdd-guide`, `e2e-runner`, `refactor-cleaner`, `build-error-resolver`, `tech-assistant`, + `database-reviewer`/`performance-optimizer`/`typescript-reviewer`/`docs-lookup`/`reference-lookup` (merging — see taxonomy) | Invoked by holistic owner when `specialist_justified: true` in registry |

For full migration decisions per legacy agent and 20 simulated routing tasks: `docs/AGENT_TAXONOMY.md` §3/§6. Proportional delegation examples (tiny change vs UI feature vs cross-system vs security-sensitive): `docs/AGENT_TAXONOMY.md` §5.

---

## Python package map (migration)

The in-tree Python package layout and I/O vs process classification used to
drive V waves: [`docs/v/archive/python-architecture-map.md`](v/archive/python-architecture-map.md)
([#477](https://github.com/ulises-jeremias/agent-toolkit/issues/477)). Product
commands `agent-toolkit` / `agent-toolkit-cli` exec the native V binary
([ADR-021](adrs/ADR-021-pypi-binary.md)).

## Design Decisions

**One source, many targets.** Skills are written once and deployed to every supported AI tool. This avoids the drift that happens when teams maintain separate prompt libraries per tool.

**Explicit over implicit.** Every skill declares its compatibility, requirements, and triggers. Every loop declares its allowed and denied actions. Nothing is assumed.

**Layered override.** Project-specific instructions always win over toolkit defaults. The toolkit provides sensible defaults; projects add context.

**Safety by default.** Loops ship with conservative budgets and explicit deny lists. Escalation is always a valid exit condition. No loop auto-merges to main branches by default.

**No secrets in this repo.** MCP templates use `${ENV_VAR}` placeholders. Profile files contain no credentials. The install script reads from environment variables or prompts the user.
