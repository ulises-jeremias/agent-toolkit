# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

<!-- markdownlint-disable MD024 -->
## [Unreleased]

### Added
- **Swarm orchestration** — new `agent-toolkit swarm` CLI (ADR-008) with backend-neutral orchestration (Herdr recommended, tmux fallback), recipes `pair`/`team`/`full` (lazy/elastic, `pair→team→full` promotion), Git worktree isolation per writer, durable filesystem handoffs (artifact/commit/feedback/decision_request), commit-based code transfer, human approval gates, budgets (tokens/cost/wall-clock/concurrency/round-trips), model profiles (`economy`/`balanced`/`quality`/`private`), runner abstraction (OpenCode primary), OpenCode per-role agent generation, Herdr plugin (`integrations/herdr/agent-toolkit-swarm`), and docs (`docs/SWARMS.md`, `SWARM_ARCHITECTURE.md`, etc.).

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