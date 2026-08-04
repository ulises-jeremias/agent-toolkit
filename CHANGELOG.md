# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.1] — 2026-08-04

### Fixed
- Publish agent-toolkit-cli to PyPI (release.yml was missing build + publish steps in v1.0.0)
- SVG animations: replace CSS @keyframes with native SVG <animate> (GitHub strips CSS)
- Banner SVG: fix text overlap between title and right panel (shift from x=575 to x=530)
- CLI wheel install: shared _paths.py resolves toolkit root correctly in all install modes
- CI: remove pytest || true so test failures block the pipeline

## [Unreleased]

### Added

- Initial toolkit release with 53+ skills across 9 domains (core, delivery, design, forge, integrations, data, tooling, ops, loops)
- Agent personas for all major AI coding tools: architect, planner, code-reviewer, security-reviewer, performance-optimizer, tdd-guide, refactor-cleaner, docs-lookup
- Profiles for Claude Code, Cursor, OpenCode, GitHub Copilot, Windsurf, and Pi Coding Agent
- 10 loop engineering templates including OSS maintenance patterns:
  - `oss-pr-monitor` (L1) — monitor open PRs across OSS repos
  - `oss-triage` (L1) — triage new issues and apply labels
  - `oss-daily-briefing` (L2) — daily activity summary across tracked repos
  - `dependency-drift` (L2) — detect and PR outdated dependencies
  - `ci-health` (L1) — watch CI status and auto-diagnose failures
  - `release-notes` (L3) — draft release notes from merged PRs
  - `security-sweep` (L2) — vulnerability scan across repos
  - `codeowner-review` (L2) — remind code owners of pending reviews
  - `stale-branch-cleanup` (L3) — identify and archive stale branches
  - `contributor-digest` (L3) — generate weekly contributor activity digest
- MCP configuration templates for 6 services: GitHub, Slack, Notion, Linear, Figma, ClickUp
- Solution packs: `oss-ecosystem`, `startup-delivery`, `enterprise-ops`, `data-platform`
- JSON schemas for skill and loop validation (`schemas/skill.schema.json`, `schemas/loop.schema.json`)
- `catalogs/skill-catalog.yaml` — machine-readable index of all skills
- `catalogs/agent-catalog.yaml` — machine-readable index of all agent personas
- `scripts/validate-skills.sh` — validates all skill.json manifests against schema
- `scripts/validate-loops.sh` — validates all loop frontmatter against schema
- `scripts/build-catalog.sh` — regenerates skill and agent catalogs
- `scripts/install.sh` — quick-setup installer for all supported tools
- `AGENTS.md` — AI agent contract with authoring specs for skills, loops, and profiles
- `CONTRIBUTING.md` — contributor guide with step-by-step instructions
- `SECURITY.md` — security policy including private disclosure process
- GitHub Actions CI workflow for automated skill and loop validation on every push and PR

---

[Unreleased]: https://github.com/ulises-jeremias/agent-toolkit/compare/HEAD...HEAD
