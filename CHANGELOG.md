# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

<!-- markdownlint-disable MD024 -->
## [Unreleased]

- **Feat** — V `build --check` Tier-1 dry-run + plugins/ skill/agent drift detection (Closes #510)
- **Feat** — V Tier-1 target emitters (cursor, claude-code, opencode) with provenance (Closes #509)
- **Feat** — V provenance emission compatible with Python `.provenance.json` schema (Closes #508)
- **Feat** — V capability loader + product selection from `distributions/products.yaml` (Closes #507)
- **Docs** — ADR-016 versioning during Python→V migration: major at cutover, not experimental binary (Closes #495)
- **Feat** — V content sync/download client (GitHub release data; offline never networks; staging validation) (Closes #557)
- **Feat** — V content cache service (XDG hit/miss/offline; no network) (Closes #556)
- **Feat** — V `doctor` read-only + `--json` with engine/version/platform (Closes #505)
- **Feat** — V `inventory` lists skills/agents/products from the toolkit tree (Closes #503)
- **Feat** — V `matrix` prints the platform capability matrix (Closes #504)
- **Feat** — V `version` / `--version` resolves from VERSION file (fallback synced via bump-version) (Closes #502)
- **Feat** — V toolkit root resolution per ADR-015 (env override → XDG → embedded → checkout → CWD; offline never downloads) (Closes #506)
- **Test** — Python↔V golden CLI parity harness + CI seed job (Closes #548)
- **Feat** — experimental V CLI dispatcher + `make build-cli` (`build/agent-toolkit-v`) (Closes #553)
- **Feat** — V structured CommandResult + CLI human/JSON/quiet renderers (Closes #501)
- **Feat** — V shared HTTP/network client (offline short-circuit, TLS, checksum hook) (Closes #558)
- **Feat** — V process service (no-shell spawn, cwd/env/timeout/capture) (Closes #500)
- **Feat** — V filesystem service (XDG paths, join, atomic write) (Closes #499)
- **Feat** — V domain error model + CLI exit-code mapping (ADR-010 classes) (Closes #498)
- **Docs** — vlib/cli spike matrix vs CLI contract; GO with thin exit/completion wrapper (Closes #554)
- **Chore** — Makefile `fmt`/`fmt-check`/`vet`/`test`/`build` for V modules (Closes #497)
- **Chore** — pin V compiler via `.v-version` (0.5.2) + upgrade policy (Closes #496)
- **Docs** — configuration/env precedence contract (`flags > env > config > defaults`) + `AGENT_TOOLKIT_*` inventory (Closes #559)
- **Docs** — machine-readable CLI contract manifest (`docs/compatibility/cli-contract.yaml`) (Closes #549)
- **Docs** — Python↔V golden CLI parity harness design (taxonomy EXACT/NORMALIZED/SCHEMA/SEMANTIC/BEHAVIORAL; no harness code) (Closes #476)
- **Docs** — ADR-015 runtime resolution (amends ADR-005 for V binary hybrid packaging) (Closes #547)
- **Docs** — ADR-014 schema validation: typed validators in core + Python bridge only during parity (Closes #546)
- **Docs** — ADR-013 YAML strategy: use `vlib/yaml` for toolkit config; no custom general YAML parser (Closes #483)
- **Docs** — ADR-012 Python/V coexistence via experimental V binary; Python remains canonical until cutover (Closes #482)
- **Fixed** — `agent-toolkit update` honors `AGENT_TOOLKIT_OFFLINE` and maps download `OSError` to skippable errors (CI flake)
- **Docs** — ADR-011 hybrid capability packaging (embedded baseline + external override); resolution order remains ADR-005/#547 (Closes #481)
- **Docs** — ADR-010 CLI/core boundary: structured domain results; CLI renders human/JSON; exit-code classes (Closes #480)
- **Docs** — ADR-009 V module architecture: `agent_toolkit_core` + `agent_toolkit_cli` (no premature server/TUI stubs) (Closes #479)

## [1.10.0] — 2026-08-12

### Added
- **Providers** — capability provider abstraction WHAT vs HOW (Closes #386), audit 8 candidates + 5 ADOPT via hierarchy (Refs #393), curated agentic-security/code-quality/architecture/design-engineering packs (Closes #390)
- **Design** — Vercel web-design-guidelines + Microsoft frontend-design-review dual-source pinning (Closes #372, #391), design-assessment orchestration (Closes #373), browser-grounded design-improvement iteration (Closes #374), Chrome DevTools MCP provider (Closes #375)
- **A11y & Figma** — WCAG 2.2 AA accessibility review (Closes #377), Figma ecosystem audit (Closes #376)
- **Security** — MCP config + implementation audit (Closes #379), OWASP agentic review (Closes #380), STRIDE threat-modeling + agentic threats (Closes #381)
- **Quality** — MegaLinter coding-agent orchestration v10 (Closes #382), CodeQL operational workflow (Closes #383), cloud Well-Architected + Mermaid/C4 diagrams (Closes #384, #385)
- **Governance** — upstream provenance schema/trust tiers + validate-upstream (Closes #364), external provenance lock + integrity validation (Closes #370), supply-chain audit skill (Closes #378), update discovery for provenance lock (Closes #428), ADRs 0004/0005
- **CLI** — `doctor` provenance/pack/MCP + matrix + context-cost + audit surface (Closes #387, #388, Refs #395, Closes #397), skill-catalog 73→77 + pack validation (Closes #390, #451, #450)

### Fixed
- **CI green** — MegaLinter PYTHON_RUFF + v10.0.0 alignment + `providers.yaml` empty-line fix (Closes #453, #454), Required CI aggregate gate, branch protection `Required CI` (app_id 15368) enforcement
- **Swarm** — tear down tmux server on cleanup to stop orphan-socket leak
- **Workspace/Packs** — validate nested packs, warn on unknown profile keys, regenerate catalogs

### Changed
- **Docs** — addyosmani documentation-and-adrs vs adr/docs-generator diff (Closes #394), third-party UI UX Pro Max as optional external (REJECT vendoring) per #392

## [1.9.0] — 2026-08-10

### Added
- **Agent Plugins 1.0** portable plugin standard — every plugin in `plugins/` now ships as `plugin.json` (`$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`) + `skills/` + `mcp.json` for Cursor, VS Code, GitHub Copilot, ChatGPT/Codex, Kiro. Dual emit keeps `.claude-plugin/plugin.json` for Claude Code (which does not yet support the spec). See `docs/AGENT_PLUGINS.md`, `plugins/README.md`, and `schemas/agent-plugins/1.0.0/`. Compiler target `agent-plugins`, validator `scripts/validate-agent-plugins.py`, and CI job `validate-agent-plugins` added; `scripts/bump-version.py` now preserves `$schema`/`extensions`.

### Changed
- **Docs** — `docs/COMPATIBILITY.md` clarifies Claude legacy-only and adds VS Code/Kiro + dedicated Agent Plugins 1.0 subsection; `docs/TARGETS.md` adds Agent Plugins 1.0 row to capability matrix.

## [1.8.4] — 2026-08-07

### Fixed
- **Swarm interactive bootstrap** — when `swarm start` is run without a prompt (`--recipe full --ui herdr --runner claude --attach`), the first agent now does only a very brief context analysis (runs `agent-toolkit workspace context` if inside a workspace like `~/.ai-workspace`, otherwise brief `README`/`git status` check) and stays on standby awaiting the user's first request. Applies `assistant` discovery + `workflow-generic-project` (plan -> approval -> implement -> draft PR) once the task arrives. Prevents the planner from inventing work.

## [1.8.3] — 2026-08-06

### Fixed
- **CI ruff format** — run `uv run ruff format` on `tests/test_swarm_cli.py` after `pytest.skip` line wrap (fixes Validate `Ruff format check` failure on 1.8.2).

## [1.8.2] — 2026-08-06

### Fixed
- **CI macos tmux** — make `test_swarm_auto_fallback_to_tmux` skip when neither herdr nor tmux is available on runner (fixes 1 failure on macos-latest).

## [1.8.1] — 2026-08-06

### Fixed
- **CI portability** — fix `tests/test_swarm_cli.py` hardcoded `/home/ulisesjcf/...` project path to `Path(__file__).resolve().parents[1]` so `uv run --project` works on any runner (fixes Validate `test_swarm_cli` 9 failures on Python 3.13).

## [1.8.0] — 2026-08-06

### Added
- **Swarm skills (Herdr-first)** — 4 new swarm-focused skills: `swarm` (launcher via `agent-toolkit swarm start --recipe pair/team/full --ui herdr/tmux --runner opencode/claude --model-profile balanced/economy --attach "task"` with eager windows `Waiting for handoff: <pred> -> <role>` and `_user_shell()` `zsh` detection), `swarm-observer` (monitor `status/handoffs/logs/attach` and recover `worktree_failed`/`headless` fallback), `swarm-handoff` (artifact/commit file handoffs with worktree-per-writer and promotion), `herdr` (Herdr workspace/tab/pane management) and `worktree` (Git worktree isolation). All validated via `muse skills validate` and `agent-toolkit skills validate` (61 total) and integrated with `code-reviewer`/`security-reviewer`/`github-cli-workflow`/`output-handshake`.
- **Workspace orchestration skills** — `workspace` (stateless `~/.ai-workspace` `workspace context` + `memory inject/todo` + packs), `project` (`project clone/list` multi-repo), `mcp` (`mcp setup/list/doctor`), and `inventory` (`inventory/matrix/skills list` discovery). Completes end-to-end DX: `workspace` → `project` → `swarm` → `handoff` → `promote` → `github-cli-workflow`.
- **Skill catalog growth** — total 52 → 61 skills across 9 domains; `agent-toolkit-complete` now includes all 9 new skills; badges, `catalogs/skill-catalog.yaml`, `catalogs/skills-layout.json`, and `docs/SKILL_PRODUCT_MATRIX.md` regenerated; `README.md`, `packages/agent-toolkit-cli/README.md`, `docs/GETTING_STARTED.md`, `docs/TROUBLESHOOTING.md`, `docs/wiki/Home.md` updated.

### Fixed
- **Docs 100% current** — regenerated catalogs (`scripts/generate-catalogs.py`, `prepare-package-data.sh`, `generate-skill-matrix.py`), fixed stale `skills-52` badges and `50 skills` assertions, and ensured `agent-toolkit install` deploys 61 skills to `~/.config/muse/skills` and `~/.agents/skills`.

## [1.7.2] — 2026-08-06

### Fixed
- **Swarm workspace UX polish** — fix `swarm list` duplicate entries when aggregating from `~/.ai-workspace`, make `swarm status/stop/cleanup/attach/report/artifacts/handoffs/logs` workspace-aware via `find_run_dir_by_id` (works from `~/.ai-workspace` without `--workspace` and with `--workspace OWNER/REPO`/`-C`), and ensure prompt autodetect works for all Create-Node-App aliases. Ensures `agent-toolkit swarm start "Fix https://github.com/Create-Node-App/..."` from workspace root creates worktree in correct repo with isolated tmux `-L agent-toolkit-swarm-<id>` N-windows like `swarm-forge` `./swarm`.

## [1.7.1] — 2026-08-06

### Added
- **Swarm prompt autodetect + workspace UX** — `agent-toolkit swarm start/plan` now autodetects repo from prompt (`https://github.com/OWNER/REPO`, `OWNER/REPO#123`, aliases `create-node-app`/`cna-templates` → `Create-Node-App/...`) and resolves to `~/.ai-workspace/repos/github.com/OWNER/REPO`, so `agent-toolkit swarm start "Fix https://github.com/Create-Node-App/create-node-app/issues/240"` works from `~/.ai-workspace` without `--workspace`/`--issue` flags (like `swarm-forge` `./swarm` but better: backend-neutral Herdr/tmux, isolated worktrees, handoffs). Adds `--workspace`/`--repo`/`-C` to `plan`/`start` and workspace-aware `list`/`status` (`list_all_runs`/`find_run_dir_by_id` aggregating across clones). Inspired by swarm-forge patterns (window-per-role tmux, worktrees, handoffs) clean-room.

## [1.7.0] — 2026-08-06

### Added
- **Swarm orchestration** — new `agent-toolkit swarm` CLI (ADR-008) with backend-neutral orchestration (Herdr recommended, tmux fallback), recipes `pair`/`team`/`full` (lazy/elastic, `pair→team→full` promotion), Git worktree isolation per writer, durable filesystem handoffs (artifact/commit/feedback/decision_request), commit-based code transfer, human approval gates, budgets (tokens/cost/wall-clock/concurrency/round-trips), model profiles (`economy`/`balanced`/`quality`/`private`), runner abstraction (OpenCode primary, Muse/Claude/Codex/Cursor/Copilot), OpenCode per-role agent generation, Herdr backend (JSON CLI) + tmux backend (isolated socket `agent-toolkit-swarm-<run-id>`), Herdr plugin (`integrations/herdr/agent-toolkit-swarm`), and docs (`docs/SWARMS.md`, `SWARM_ARCHITECTURE.md`, `SWARM_RECIPES.md`, `SWARM_HANDOFFS.md`, `SWARM_MODELS_AND_COSTS.md`, `SWARM_HERDR.md`, `SWARM_TMUX.md`, `SWARM_SECURITY.md`, `HOW_TO_CREATE_SWARM_RECIPE.md`) with Mermaid diagrams and offline `--runner skeleton` demo. Complete cross-repo integration: Workstation provision (tmux/Herdr) and Harness reference workspace.

## [1.6.0] — 2026-08-06

### Added

- **Loop `list` command** — `agent-toolkit loop list` (alias `ls`) lists detected loops in the same places `loop run <name>` searches (`workspace/loops/` → bundled `data/loops/`), showing `source`, `tier`, `cadence`.

## [1.5.1] — 2026-08-06

### Fixed

- **Release 1.5.0 plugin bundles**: sync `plugins/*/.claude-plugin|*.cursor-plugin|*.codex-plugin|gemini-extension|pi-package|.provenance` versions to `1.5.1` — fixes `test_diff_no_changes_returns_0` (Validate `diff`).

## [1.5.0] — 2026-08-06

### Added

- **Muse Code support (Meta, <https://developer.meta.com/ai/products/muse-code/>)** — new `muse-code` build target (`muse` alias) via `MuseCodeAdapter` (`packages/agent-toolkit-cli/src/agent_toolkit/compiler/targets/muse_code.py`) registered in `capabilities/targets/registry.yaml` (stable). `agent-toolkit build --target muse-code` and `install --tools muse-code` now deploy 50 skills to `~/.config/muse/skills/<name>/SKILL.md` plus `.agents/skills` (universal fallback) per Agent Skills spec (`muse skills import --from claude`). New profile `profiles/muse-code/README.md` and docs `README.md`.

## [1.0.1] — 2026-08-04

### Fixed

- Publish agent-toolkit-cli to PyPI (release.yml was missing build + publish steps in v1.0.0)
- SVG animations: replace CSS @keyframes with native SVG <animate> (GitHub strips CSS)
- Banner SVG: fix text overlap between title and right panel (shift from x=575 to x=530)
- CLI wheel install: shared _paths.py resolves toolkit root correctly in all install modes
- CI: remove pytest || true so test failures block the pipeline

## [1.0.2] — 2026-08-04

### Fixed

- release.yml now correctly builds wheel and publishes to PyPI

## [1.0.3] — 2026-08-04

### Fixed

- release.yml YAML syntax fixed for GitHub Actions validator

## [1.0.4] — 2026-08-04

### Fixed

- **Wheel install**: data files (profiles/, loops/, skills/, etc.) now packed inside
  the wheel at `agent_toolkit/data/` — works correctly with pip, uvx, and brew
- `_paths.py`: resolve data from `importlib.resources` and direct package path
  before falling back to walking up the filesystem (which breaks in uvx cache)
- Added `agent-toolkit-cli` as script alias so `uvx agent-toolkit-cli` works

## [1.0.5] — 2026-08-04

### Fixed

- loop runner: resolve toolkit root from package data dir before CWD fallback,
  preventing it from picking up the user's ai-workspace loops when run via uvx/pip

## [1.0.6] — 2026-08-04

### Fixed

- **CRITICAL**: Local `toolkit_root()` in cli/install.py, doctor.py, mcp.py, skills.py,
  plugin.py was defined *after* the import from `_paths.py`, shadowing it — so the
  correct resolution logic was never called in wheel/uvx installs
- Removed module-level `TOOLKIT_DIR: Path = toolkit_root()` (evaluated at import time,
  crashed before any function ran) — replaced with lazy `toolkit_root()` per call site

## [1.0.7] — 2026-08-04

### Fixed

- `skills list`: now correctly parses YAML block scalars (>-, |-) in SKILL.md descriptions
  — all 52 skill descriptions now display properly instead of showing ">-"
- `install` command: Copilot prompt no longer blocks in non-interactive/dry-run mode
  (stdin.isatty() check; skips automatically in CI, pipes, --dry-run)
- `pyproject.toml`: added agent-toolkit-cli script alias so `uvx agent-toolkit-cli` works

## [1.0.8] — 2026-08-04

### Fixed

- Copilot never auto-installed during `install` auto-detect — always requires `--tools copilot` (it needs a project path)
- CI integration tests: use relative file paths instead of /tmp (cross-platform)
- CI integration tests: fix Windows runner compatibility

## [1.0.9] — 2026-08-04

### Fixed

- Windows compatibility: `os.getuid()` doesn't exist on Windows — wrapped in try/except
  so `agent-toolkit doctor` no longer crashes on Windows runners

## [1.0.10] — 2026-08-04

### Fixed

- `loop run` now works from pip/uvx installs — `loop-gh-gate` (the gh CLI
  security shim) is now included in the wheel at `agent_toolkit/loop/loop-gh-gate`
- Windows compatibility: `os.getuid()` wrapped in try/except AttributeError

### Added

- uv workspace structure: `packages/agent-toolkit-cli/` — ready for future packages
  (`agent-toolkit-server`, `agent-toolkit-mcp`, etc.)
- Root `pyproject.toml` with `[tool.uv.workspace]` and shared dev tooling

## [1.1.0] — 2026-08-04

### Added — Full workspace capability

agent-toolkit is now a complete workspace toolkit. Every capability from
~/.ai-workspace and agentic-harness is available as a CLI subcommand:

**`agent-toolkit workspace`** — Workspace scaffolding and session context
- `workspace init [--dir PATH]` — scaffold harness workspace (AGENTS.md, knowledge/, packs/, personas/, loops/, projects/, repos/)
- `workspace context` — session state snapshot for AI session start
- `workspace sync` — sync loop escalations into knowledge todos

**`agent-toolkit memory`** — Persistent knowledge base (replaces bin/assistant-memory)
- `memory add --type <learning|process|todo> "content"` — add to knowledge base
- `memory search "query"` — search all knowledge files
- `memory inject` — output full knowledge context block for AI session
- `memory review` — show stale entries
- `memory todo` — list pending todos

**`agent-toolkit project`** — Project clone and symlink manager (replaces bin/project-indexer)
- `project clone owner/repo` — clone + symlink into projects/
- `project list` — list indexed projects
- `project add <path>` — symlink existing repo
- `project remove <name>` — remove symlink
- `project scan` — consistency check

**`agent-toolkit devcompanion`** — Background job queue (replaces bin/devcompanion)
- `devcompanion queue <project> [--request "..."] [--template NAME]` — queue a job
- `devcompanion run-once [--no-llm]` — execute oldest pending job
- `devcompanion status` — show all jobs
- `devcompanion done <job-id>` — mark job complete
- `devcompanion sync-todos` — sync plan.md todos to knowledge

**`agent-toolkit insights`** — AI tool usage analytics (replaces bin/tool-insights)
- `insights opencode` — OpenCode sessions from SQLite DB
- `insights cursor` — Cursor agent transcripts
- `insights claude` — Claude Code sessions
- `insights all` — aggregate across all tools

**Templates** — workspace scaffold templates bundled in the wheel
- 12 CLI modules, 42 template files (AGENTS.md, personas, knowledge, etc.)
- `agent-toolkit workspace init` = what agentic-harness now scaffolds from

**Profile updates** — Claude Code, Cursor, OpenCode, Windsurf profiles updated with
agent-toolkit CLI reference and session-start protocol

### Changed

- agentic-harness: bin/workspace-context and bin/assistant-memory are now
  thin wrappers that delegate to agent-toolkit CLI

## [1.2.0] — 2026-08-05

### Added — Native multi-runtime compiler platform (Phases 3-7)

The canonical compiler pipeline now generates native artifacts for 9 AI coding targets:

**Compiler targets:**
- Claude Code (plugin — .claude-plugin/) — stable GA
- Cursor IDE/CLI (plugin — .cursor-plugin/) — stable GA
- GitHub Copilot CLI (plugin — plugin.json) — stable GA
- GitHub Copilot Repository (.github/ assets) — stable GA
- Gemini CLI (extension — gemini-extension.json + commands.toml) — stable GA
- OpenCode (companion-assets — .opencode/) — stable
- Pi Coding Agent (companion-assets — pi-package.json) — stable
- Windsurf/Devin (customization-bundle — rules + AGENTS.md) — accurately labeled (no marketplace)
- OpenAI Codex (plugin — .codex-plugin/) — experimental

**Canonical compiler pipeline:**
- `distributions/products.yaml` — declarative product catalog
- `src/agent_toolkit/compiler/` — model, loader, targets/
- `agent-toolkit build` — compile to any target
- `agent-toolkit diff` — show changes vs installed
- `agent-toolkit inventory` — list all capabilities
- `agent-toolkit matrix` — platform capability matrix
- `agent-toolkit release --dry-run` — generate dist/ artifacts + checksums

**MCP and hooks:**
- `mcp/registry/` — canonical registry for 6 providers (github, slack, notion, linear, figma, clickup)
- `capabilities/hooks/` — canonical hook definitions with platform parity matrix
- `schemas/hook.schema.yaml` — JSON Schema for hook definitions

**Testing (227 tests):**
- Contract tests for all 9 compiler adapters
- Golden/snapshot tests for deterministic output
- Security tests: path traversal, secret redaction
- Installer receipt tests
- MCP registry tests
- Hook registry tests
- Provenance/diff tests

**Docs:**
- `docs/TARGETS.md` — honest capability matrix for all 9 targets
- `docs/research/` — platform capability matrix, source ledger, audit
- `docs/adrs/` — ADR-001 (canonical IR), ADR-002 (Windsurf bundle)
- `docs/security/` — threat model

### Security

- Removed `skipDangerousModePermissionPrompt` from Claude Code profile
- Replaced private LAN URLs in OpenCode profile with portable defaults
- Updated schema `$id` to remove stale agentic-workstation references

### Added — Loop runners, memory review, and consumer polish

- Loop runners: Cursor Agent CLI, GitHub Copilot CLI (`copilot -p`), OpenAI Codex (`codex exec`)
- `loop run --runner` / `AGENT_TOOLKIT_LOOP_RUNNER` for explicit runner selection
- `memory review` — duplicates, contradictions, stale/orphan detection with `--fix`
- Installer receipts, safe JSON merge, update/uninstall, profile sanitization
- README Key Concepts table; Windsurf rule parity with Cursor
- Blocking YAML lint in validate CI; docs/TARGETS and trust boundary guides

## [Unreleased]

### Added
- **Agent Plugins 1.0** portable plugin standard — every plugin in `plugins/` now ships as `plugin.json` (`$schema: https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`) + `skills/` + `mcp.json` for Cursor, VS Code, GitHub Copilot, ChatGPT/Codex, Kiro. Dual emit keeps `.claude-plugin/plugin.json` for Claude Code (which does not yet support the spec). See `docs/AGENT_PLUGINS.md`, `plugins/README.md`, and `schemas/agent-plugins/1.0.0/`. Compiler target `agent-plugins`, validator `scripts/validate-agent-plugins.py`, and CI job `validate-agent-plugins` added; `scripts/bump-version.py` now preserves `$schema`/`extensions`.


## [1.2.2] — 2026-08-05

### Changed

- Publish an elevated `packages/agent-toolkit-cli/README.md` to PyPI (parity with the monorepo root README: install, CLI surfaces, tool matrix, ecosystem)

## [1.2.1] — 2026-08-05

### Fixed

- `loop status` falls back to bundled templates when no workspace instances exist (uvx/pip installs)
- Release CI: `uv sync --package agent-toolkit-cli --extra all` and current SBOM action pins

---

[Unreleased]: https://github.com/ulises-jeremias/agent-toolkit/compare/v1.2.2...HEAD
[1.2.2]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.2.2
[1.2.1]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.2.1
[1.2.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.2.0
[1.1.0]: https://github.com/ulises-jeremias/agent-toolkit/releases/tag/v1.1.0