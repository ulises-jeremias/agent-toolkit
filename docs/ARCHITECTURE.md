# Architecture

agent-toolkit is organized around three layers that compose to form a complete AI capability stack for any project or team.

**Canonical CLI:** native **V 0.5.2** (`import json`, not json2). Build with `./make.vsh build-cli` → `build/agent-toolkit`. PyPI/`uv`/`npm` are distribution adapters over that binary. See [`docs/HOW_TO_DEVELOP_V.md`](HOW_TO_DEVELOP_V.md) and [`docs/v/README.md`](v/README.md).

---

## Three-Layer Model

### L1 — Workstation / Installer

The outermost layer is the installer or workstation harness that provisions agent-toolkit onto a machine. This layer is responsible for:

- Cloning or updating the toolkit repository
- Running `agent-toolkit install` (canonical **V** CLI from GitHub Release, Homebrew, AUR `agent-toolkit-bin`, PyPI launcher, or npm — ADR-021. `scripts/install.sh` is a deprecated legacy fallback — see ADR-007) to copy profiles/plugins to the right tool-specific locations
- Managing credentials and environment variables (but never storing secrets in this repo)
- Scheduling recurring loops via a cron or loop-runner daemon

This layer is typically managed by a separate bootstrapping tool (such as a dotfiles manager or a workstation provisioner). agent-toolkit itself does not own this layer — it provides the V CLI, profiles, and a deprecated install-script fallback.

### L1.5 — agent-toolkit (this repo)

The middle layer is agent-toolkit itself. It is the single source of truth for:

- **Skills** — portable capability definitions that work across all supported AI tools
- **Agent personas** — tool-agnostic role definitions (architect, code-reviewer, etc.)
- **Profiles** — tool-specific configuration files generated from the skill and agent definitions
- **Loops** — recurring agentic workflow templates with budgets and safety gates
- **MCP templates** — Model Context Protocol configuration stubs for external services
- **Packs** — curated bundles that combine skills and loops for a specific outcome

This layer is meant to be stable and opinionated. Changes here propagate to every project that uses the toolkit.

### L3 — Project Overlays

The innermost layer is the project- or client-specific customization layer. Each project can:

- Override or extend profile configurations (e.g. add project-specific rules to `.cursor/rules/`)
- Define a project-level `AGENTS.md` or `.claude/CLAUDE.md` that overrides toolkit defaults
- Add project-local loops in a `loops/` directory
- Compose a project pack that references toolkit skills plus local additions

Project overlays never modify the toolkit itself. They sit on top and take precedence for that project only.

---

## How the Layers Interact

```
┌─────────────────────────────────────────────┐
│  L1 — Workstation / Installer               │
│  (chezmoi, bootstrap script, cron runner)   │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │  L1.5 — agent-toolkit (this repo)    │  │
│  │                                       │  │
│  │  skills/   profiles/   loops/         │  │
│  │  agents/   mcp/        packs/         │  │
│  │                                       │  │
│  │  ┌─────────────────────────────────┐  │  │
│  │  │  L3 — Project Overlay           │  │  │
│  │  │                                 │  │  │
│  │  │  .claude/CLAUDE.md              │  │  │
│  │  │  .cursor/rules/project.mdc      │  │  │
│  │  │  loops/my-loop/loop.yaml        │  │  │
│  │  │  packs/my-pack.yaml             │  │  │
│  │  └─────────────────────────────────┘  │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

Precedence (highest to lowest): Project overlay > agent-toolkit defaults > tool built-ins.

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

Profiles reference skills but do not duplicate them. The install script copies profiles to the locations each tool expects.

> **Note (ADR-004):** `profiles/` is deprecated as the marketplace delivery path. `plugins/` is now the generated output of `agent-toolkit build` (from `distributions/products.yaml` + `skills/`/`agents/`). `plugins/` must not be hand-edited (CI `build --check` enforces this). The installer prefers compiled `plugins/` via `installer/sources.py` and falls back to `profiles/` only when `plugins/` is absent. Add new capabilities to `skills/` + `products.yaml`, not to `profiles/` alone.

### Loops

A loop is a recurring agentic workflow with a declared goal, safety gates, and a token budget. Each loop lives in `loops/<name>/loop.yaml` and contains:

- `goal` — what the loop is trying to accomplish
- `allowlist` / `deny` — explicit lists of permitted and forbidden actions
- `budget` — maximum tokens, runs per day, and wall-clock seconds
- `exit_conditions` — when the loop should stop (goal met, budget exhausted, human escalation)
- `request` — the prompt template the loop runner executes

Loops follow a three-tier model (L1/L2/L3) based on the risk level of their actions. See [LOOPS.md](LOOPS.md) for details.

### Packs

A pack bundles skills, agents, and loops into an outcome-oriented workflow. A pack is a `pack.yaml` file (or directory with a `README.md` and `config.yaml`) that declares which skills to activate, which loops to enable, and any configuration overrides. **Packs are docs-only** (ADR-006): they are not loaded by `agent-toolkit build`; product composition lives in `distributions/products.yaml`.

Packs are the recommended entry point for teams. Instead of picking individual skills, you load a pack and get a coherent setup for your context (OSS maintainer, startup delivery team, data platform, etc.).

### Swarms

Swarms coordinate multiple coding-agent sessions with worktree isolation and durable handoffs. See `docs/SWARMS.md` and `docs/SWARM_ARCHITECTURE.md`. Orchestration engine + UI backends (Herdr/tmux) + runner adapters (OpenCode etc.) with filesystem state authoritative, commit-based handoffs, human gates, and budgets. Details in ADR-008.

---


## Repository Structure

Counts: 77 skills (14 domains), 17 agents, 10 loops, 7 packs, 7 MCP templates, 7 profiles. Live inventory: `agent-toolkit inventory` / `catalogs/`.

```
agent-toolkit/
├── skills/                      # 77 SKILL.md trees (14 domains)
│   ├── core/  delivery/  design/  forge/  integrations/
│   ├── data/  tooling/  ops/  loops/
│   ├── agentic-security/  architecture/  cloud/
│   └── accessibility/  quality/
├── agents/                      # 17 personas (incl. agentic-security-reviewer)
├── profiles/                    # claude-code, cursor, opencode, copilot,
│                                # windsurf, pi, muse-code
├── loops/                       # 10 loop.yaml templates
├── mcp/templates/               # 7 providers (incl. chrome-devtools)
├── packs/                       # 7 docs-only packs (ADR-006)
├── catalogs/                    # generated skill/agent catalogs
├── schemas/
├── modules/                     # V CLI (canonical product)
├── packages/                    # pypi/ + npm/ adapters
├── distribution/                # channel contracts (not Formula/PKGBUILD copies)
├── docs/
└── scripts/                     # validate-*, gen-surfaces, bump-version
                                 # install.sh is deprecated (ADR-007)
```

---

## Python package map (migration)

The in-tree Python package layout and I/O vs process classification used to
drive V waves: [`docs/v/python-architecture-map.md`](v/python-architecture-map.md)
([#477](https://github.com/ulises-jeremias/agent-toolkit/issues/477)). Product
commands `agent-toolkit` / `agent-toolkit-cli` exec the native V binary
([ADR-021](adrs/ADR-021-pypi-binary.md)).

## Design Decisions

**One source, many targets.** Skills are written once and deployed to every supported AI tool. This avoids the drift that happens when teams maintain separate prompt libraries per tool.

**Explicit over implicit.** Every skill declares its compatibility, requirements, and triggers. Every loop declares its allowed and denied actions. Nothing is assumed.

**Layered override.** Project-specific instructions always win over toolkit defaults. The toolkit provides sensible defaults; projects add context.

**Safety by default.** Loops ship with conservative budgets and explicit deny lists. Escalation is always a valid exit condition. No loop auto-merges to main branches by default.

**No secrets in this repo.** MCP templates use `${ENV_VAR}` placeholders. Profile files contain no credentials. The install script reads from environment variables or prompts the user.
