# Architecture

Agent Toolkit is the portable capability library and native CLI within a four-layer ownership stack. It distributes skills, agent definitions, MCP templates, context, workflow recipes, provenance, and compatibility tooling. **Veasel Code** is the supported coding application and owns interactive coding sessions, provider execution, approvals, and shared TUI/Desktop history.

**Canonical CLI:** native **V**, using the immutable compiler/toolchain inputs recorded by `.github/actions/setup-v`. The repository selects the `master` toolchain in `.v-version`; the currently pinned compiler commit reports `V 0.5.2 c0e47bf`. Build with `VJOBS=2 ./make.vsh build-cli` → `build/agent-toolkit`. PyPI/`uv`/`npm` are distribution adapters over that binary. See [`docs/HOW_TO_DEVELOP_V.md`](HOW_TO_DEVELOP_V.md) and [`docs/v/README.md`](v/README.md).

---

## Ownership Layers (Machine → Toolkit → Workspace → Project)

Ownership is layered; each layer is managed by a different repo. Toolkit layers use `L1`/`L1.5`/`L3` labels (stable since early docs); **Loop tiers `L1`/`L2`/`L3` are mutation-safety *Stages* in the Loop Engineering discipline, not ownership Layers** — see note below.

| Layer | Repo | Role |
|-------|------|------|
| **L1 — Machine** | [agentic-workstation](https://github.com/ulises-jeremias/agentic-workstation) | Machine provisioning — chezmoi, shell, packages, LLM policy |
| **L1.5 — Toolkit** | **agent-toolkit** (this repo) | Portable skills, agents, MCP templates, workflows, provenance, and their CLI/distribution |
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

The middle layer is Agent Toolkit: portable content, distribution, provenance, compatibility, and CLI commands. This repository does not own a supported coding Desktop, provider-session runtime, or Veasel's interactive session history. Swarm v1 `start` and `init` are rejected by current CLI and HTTP dispatch; historical run inspection and recovery controls remain available for user-owned state.

This layer is meant to be stable and opinionated. Changes here propagate to every workspace and project that uses the toolkit via `AGENT_TOOLKIT_ROOT` / embedded data.

### L3 — Workspace (Harness)

The harness workspace is the multi-repo overlay that consumes Toolkit CLI commands for workspace context and local automation. It provides `knowledge/`, `repos/`, `projects/`, `packs/*.yaml` context bundles, and persona handoff state. It does not define or replace Veasel's coding-session runtime. See [agentic-harness](https://github.com/ulises-jeremias/agentic-harness).

### Project Overlay

The innermost layer is the per-project customization. Each project can:

- Override or extend profile configurations (e.g. add project-specific rules to `.cursor/rules/`)
- Define a project-level `AGENTS.md` or `.claude/CLAUDE.md` that overrides toolkit defaults
- Add project-local loops in a `loops/` directory
- Compose a project pack that references toolkit skills plus local additions

Project overlays never modify the toolkit itself. They sit on top and take precedence for that project only.

> **Terminology note — Stages vs Layers:** Loop tiers `L1` (observe/propose), `L2` (controlled mutations), `L3` (high-autonomy merge/close) are **Stages** in the Loop Engineering discipline (and similarly `L0`–`L3` in Context/Harness/Loop Engineering). They describe mutation safety, not ownership. Ownership **Layers** are `L1` Machine / `L1.5` Toolkit / `L3` Workspace + Project Overlay. Never use `L1`/`L2`/`L3` to mean both — say "Tier L1 loop" vs "Layer L1 machine".

---

## Portable content and CLI boundaries

Agent Toolkit distributes portable content and provides CLI commands to install, inspect, and automate that content. It is not a coding-session runtime.

| Area | Owns | Key dirs / contracts | Resolution |
|-------|------|----------------------|--------------------|
| **Portable content** | Capabilities distributed to coding tools and compiled artifacts | `skills/` + `agents/` (source), `distributions/products.yaml` (composition), `plugins/` (generated output), `profiles/` (deprecated install overlay), `mcp/templates/` + `mcp/registry/`, `packs/` (docs-only) | Content is embedded or resolved from the verified offline sidecar; build checks use `agent-toolkit build --check`. |
| **CLI and compatibility** | Installation, discovery, validation, and local workspace automation over Toolkit content | V CLI, core and local API. Existing commands include workspace/memory/project/loop and `serve`. Swarm v1 retains limited history inspection and recovery controls; new runs are rejected. | Source data resolves through `AGENT_TOOLKIT_ROOT` → XDG → embedded/FHS sidecar → checkout. See ADR-015, ADR-026, and ADR-047. |

The V CLI and its distribution adapters provide the supported portable Toolkit interface. The existence of workspace automation or a local HTTP API does not make it Veasel's session backend. Source resolution is offline and documented in [ADR-015](adrs/ADR-015-runtime-resolution.md), [ADR-026](adrs/ADR-026-full-embed.md), and [ADR-047](adrs/ADR-047-offline-resource-sidecar.md).

**Swarm v1 is retired from new runs.** Current public dispatch rejects `start` and `init`; history and explicit recovery controls remain so users can inspect or stop existing user-owned runs. Agent Toolkit #1676 and Veasel #629 are closed with evidence for the product boundary and Veasel's own orchestration behavior. That evidence does not mean every user's Swarm data is imported. Keep old records intact and consult the [migration boundary](SWARM_V1_DISPOSITION.md) before any manual cleanup.

### Veasel Code owns the coding application

Veasel Code is the supported coding product. Its terminal interface and
Electron Desktop are designed to use the canonical Veasel V backend, provider
configuration, authorization model, and persisted session history. Desktop
Focus and optional World are views over that runtime; packaged shared-session
acceptance remains tracked in [Veasel #550](https://github.com/veasel-labs/veasel/issues/550).
This repository does not implement a second coding-session engine or GUI.

Agent Toolkit remains independently useful as a portable capability library
and CLI. Its `serve` API supports Toolkit operations; it is not the backend for
Veasel Code. The former Electron app (`apps/desktop/`) has been retired and
removed from `main` (preserved in Git history). New graphical product work
belongs in [Veasel Code](https://github.com/veasel-labs/veasel). See
[`docs/VEASEL_COMPATIBILITY.md`](VEASEL_COMPATIBILITY.md) for the retirement
and user-data boundary.

### Internal module boundaries and import rules (#982)

```text
portable source ───────► agent_toolkit_core ◄────── agent_toolkit_server
skills/ agents/          Toolkit operations         local API adapter
profiles/ plugins/               ▲
mcp/ packs/                       │
                                  └──────── agent_toolkit_cli
                                            CLI adapter
```

**Allowed import edges:**

- `agent_toolkit_cli` → `agent_toolkit_core` ✅ (CLI dispatches to Toolkit operations)
- `agent_toolkit_server` → `agent_toolkit_core` ✅ (local API wraps Toolkit operations)
- `agent_toolkit_core` → portable content / `distributions/*` ✅ (reads catalogs, resolves skills)
- `agent_toolkit_core` → `agent_toolkit_cli` ❌ **forbidden** (no circular import)
- `agent_toolkit_core` → `agent_toolkit_server` / `veb` ❌ **forbidden** where it would couple core to server frameworks
- `skills/` / `agents/` / `distributions/` → `agent_toolkit_core` ❌ **forbidden** (portable content is data, not executable Toolkit code)
- `plugins/` is output only; never import from it

**Enforcement:** the `check-planes` job in `.github/workflows/validate.yml` prevents core code from importing CLI or server adapters. `VJOBS=2 ./make.vsh vet` also runs as part of that gate. This is an internal code boundary, not a second product-runtime architecture. See `scripts/` and `make.vsh`.

**File size ≠ automatic split:** `modules/agent_toolkit_core/mcp.v` / `swarm.v` are large but not automatically split. Create focused refactoring issues only where coupling materially hurts security/testability (e.g. circular import, untestable side effect) — not “file is large”. See ADR-009, ADR-027.

**No premature split, no TUI revival:** #279 remains open as RFC — no repository split without accepted ADR. TUI stays retired per ADR-030 (git history preserves it; do not revive). Speculative rewrite epics or repo splits without an accepted ADR are out of scope.

---

## How the Layers Interact

```
┌─────────────────────────────────────────────────────┐
│  L1 — Machine / Workstation                         │
│  (chezmoi, bootstrap script, LLM policy)            │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │  L1.5 — Toolkit (this repo)                   │  │
│  │  Portable skills/agents/MCP/workflow content  │  │
│  │  CLI install, compatibility and automation    │  │
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

Precedence (highest to lowest): Project overlay > Workspace harness > Toolkit portable defaults > tool built-ins.

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

### Swarm v1 history

Current public CLI/API dispatch rejects new Swarm v1 runs. Retained history
inspection and explicit recovery controls exist only for old user-owned state;
they are not the target Agent Toolkit architecture. The migration boundary is
documented in [SWARM_V1_DISPOSITION.md](SWARM_V1_DISPOSITION.md). Historical
design details remain in Git history and short archived-link pages.

---

## Repository Structure

Live inventory is `agent-toolkit inventory` / `catalogs/` — do not hardcode counts in docs (historical snapshot: ~103+ skills / 14 domains, **18 agents post-#865 = 11 holistic + 2 orchestrators + 6 specialists; 7 specialists archived to `references/`** — was 25 = 11+2+13, 10 loops, 7 packs, 7 MCP providers).

```
agent-toolkit/
├── skills/                      # SKILL.md trees by domain (see inventory)
│   ├── core/  delivery/  design/  forge/  integrations/
│   ├── data/  tooling/  ops/  loops/
│   ├── agentic-security/  architecture/  cloud/
│   └── accessibility/  quality/
├── agents/                      # personas: 11 holistic + 2 orchestrators + 6 specialists (18, post-#865 — 7 archived to references/ per docs/AGENT_TAXONOMY.md §3/§8)
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

Eleven holistic roles own every skill's `holistic_owner` in `capabilities/skills/registry.yaml` (103+ skills, no orphans). **Optimize for cognitive simplicity, useful context isolation, and independent verification — not fewest agents, not one-per-skill.** Full roster: [`docs/AGENT_TAXONOMY.md`](AGENT_TAXONOMY.md) — **#865 final = 18 personas** (was 25; 7 archived to `references/`).

| Tier | Agents | How to invoke |
|------|--------|---------------|
| Orchestrator | `assistant` (default), `client-workflow-bootstrap` (meta-generator → packs/knowledge) | Implicit + `@assistant` / `@client-workflow-bootstrap` |
| Holistic (daily) | `planner`, `architect`, `designer`, `implementer`, `reviewer`, `qa-engineer`, `security-engineer`, `platform-engineer`, `researcher`, `data-engineer` (conditional) | `@planner`, `@architect`, `@designer`, … per `assistant` routing |
| Specialist (opt-in, 6 retained) | `code-reviewer` (backs `reviewer`), `security-reviewer` + `agentic-security-reviewer` (backs `security-engineer`), `e2e-runner` (backs `qa-engineer`), `tdd-guide` (backs `implementer`), `build-error-resolver` (backs `platform-engineer`) | Invoked by holistic owner when `specialist_justified: true` in registry or task explicitly warrants tight technique |
| Archived → `references/` (7, provenance) | `typescript-reviewer`/`database-reviewer`/`performance-optimizer`/`refactor-cleaner` → `reviewer/references/*.md`; `docs-lookup`+`reference-lookup` → `researcher/references/LOOKUP_GUIDE.md`; `tech-assistant` → `platform-engineer/references/WORKSTATION_OPS.md` | Procedural checklists, narrow capabilities loaded inline by holistic owner per `#865` agent-vs-skill rule (see `docs/HOW_TO_ADD_AGENT.md` & `docs/AGENT_TAXONOMY.md` §3/§8) |

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
