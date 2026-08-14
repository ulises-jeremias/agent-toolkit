---
name: megalinter
description: MegaLinter coding-agent orchestration — discover config, run/check (CI watch or local Docker), classify findings, apply safe fixes, targeted re-check (bounded 3 iterations), report remaining. Consumes official oxsecurity/megalinter skills externally pinned at v10.0.0.
origin:
  type: upstream
sources:
  - id: orchestrator
    repository: oxsecurity/megalinter
    path: skills/megalinter/SKILL.md
    ref: v10.0.0
    commit: 15e5b45552097e318c93de385779ce3b1084052c
    license: AGPL-3.0
  - id: setup
    repository: oxsecurity/megalinter
    path: skills/megalinter-setup/SKILL.md
    ref: v10.0.0
    commit: 15e5b45552097e318c93de385779ce3b1084052c
    license: AGPL-3.0
  - id: check
    repository: oxsecurity/megalinter
    path: skills/megalinter-check/SKILL.md
    ref: v10.0.0
    commit: 15e5b45552097e318c93de385779ce3b1084052c
    license: AGPL-3.0
  - id: fix
    repository: oxsecurity/megalinter
    path: skills/megalinter-fix/SKILL.md
    ref: v10.0.0
    commit: 15e5b45552097e318c93de385779ce3b1084052c
    license: AGPL-3.0
trust:
  tier: reviewed
  reviewed_at: '2026-08-12'
  reviewed_by: ulises-jeremias
  reviewed_provenance: sha256:a261350125bc434d73807cadb9f4616219e0266369887895f95b076c13e0c95c
maintenance:
  status: active
  last_activity: '2026-08-08'
  last_checked: '2026-08-12'
distribution:
  mode: external
  redistribution_allowed: false
security:
  scripts: false
  shell: true
  network: true
  requires_secrets: false
  mcp: []
  hooks: []
  dangerous_permissions: []
  cve_policy: not-applicable
---

# MegaLinter — External Pinned Coding-Agent Orchestration

Consume **official** MegaLinter coding-agent skills externally pinned, not rewritten.

> **Upstream:** `oxsecurity/megalinter` **v10.0.0** (`15e5b45552097e318c93de385779ce3b1084052c`, 2026-08-08) — AGPL-3.0. Skills: `megalinter` (orchestrator), `megalinter-setup`, `megalinter-check`, `megalinter-fix` + sub-agents `megalinter-watcher`/`megalinter-runner`/`megalinter-fixer`. Installed via `npx skills add oxsecurity/megalinter/skills -s '*' -a <agent> -y`. See `references/megalinter-targets.md` for dated evidence (2026-08-12) and `references/megalinter-license.md` for AGPL analysis.

**Do not vendor or paraphrase upstream SKILL.md.** This Toolkit capability is a thin, governed declaration → provenance lock → adapter. The workflow below mirrors upstream `megalinter` orchestrator (setup → check → fix → re-check ≤3 iterations) and maps it to Toolkit product/target constraints.

## Installation (external, pinned)

```bash
# Install or refresh official skills externally (per target)
npx skills add oxsecurity/megalinter/skills -s '*' -a claude-code -y
npx skills add oxsecurity/megalinter/skills -s '*' -a cursor -y
npx skills add oxsecurity/megalinter/skills -s '*' -a github-copilot -y
npx skills add oxsecurity/megalinter/skills -s '*' -a codex -y
npx skills add oxsecurity/megalinter/skills -s '*' -a opencode -y
# Or auto-detect installed agents:
npx skills add oxsecurity/megalinter/skills -s '*' -y --copy
```

Verify pin:
```bash
npx skills list | grep megalinter
# Should show Source: oxsecurity/megalinter — version v10.0.0 / commit 15e5b45
```

Update: `npx skills update megalinter megalinter-setup megalinter-check megalinter-fix -y` (skills) + refresh sub-agents per `megalinter-setup/agents/INSTALL.md` (copy `.claude/agents/megalinter-*.md` etc.). Do not use bare `npx skills update` (updates unrelated skills).

Container/runtime (when running locally):
```bash
npx mega-linter-runner --install --no-prompt --flavor <flavor> --setup-ci <ci> --fix
# Flavor/version follows MEGALINTER_VERSION in .mega-linter.yml
# Docker image: ghcr.io/oxsecurity/megalinter:v10 (config digest sha256:939058f3ed31803e12583365e7126eacfb356724bf003fd29e96a93948aa2d33, see references/megalinter-images.md for tag+digest and multi-arch notes)
# npm runner: mega-linter-runner@10.0.0 (sha512:yQOyD8/MTeZ35MveiE6Stoj0/FgIGkV7jok3VriFI+VP30LouWYlohFWVbaUJm+8/gmwT2NxA6pCcSdFsZ7xkA==)
```

## Workflow (mirrors upstream orchestrator, Toolkit-gated)

```
DISCOVER CONFIG
      ↓
RUN / CHECK (CI watch preferred; local Docker fallback)
      ↓
CLASSIFY FINDINGS (blocking ❌ vs non-blocking ⚠️)
      ↓
SAFE FIXES (auto-fixable first)
      ↓
TARGETED RE-CHECK (only failing linters/files, parallel ≤4)
      ↓
bounded iteration ≤3
      ↓
remaining findings (report, do not force-push default branch)
```

1. **Discover config:** Check `.mega-linter.yml` + CI workflow (`.github/workflows/mega-linter.yml` etc.). If missing → delegate to `megalinter-setup` via external skill (always via `npx mega-linter-runner --install` / `--upgrade`, never hand-write `.mega-linter.yml`).
2. **Run / Check:** Prefer **CI watch** if a MegaLinter job exists for branch/PR (no Docker needed, no GB download). Else **local** via `npx mega-linter-runner` (requires docker/podman actually responding — probe `timeout 10 docker info`, install/start if missing). Collect per-linter elapsed times and console tips (performance warnings, `[Activation]`, deprecations). Output contract JSON: `{status, linters: [{key, errors, fixable, blocking, files, samples}], slow_linters, tips, job_url?, auto_fix_commit?}`.
3. **Classify:** Blocking ❌ (fails job) first, non-blocking ⚠️ (`DISABLE_ERRORS`) mention only.
4. **Safe fixes:** For each failing linter, load its fix guide lazily (`linters/<key>.md` via upstream `megalinter-fix`). Order: auto-fixable via `npx mega-linter-runner --linter <KEY> --fix [files]` (if engine available) → manual per-rule fixes (consult rule docs) → web-search rule docs if uncovered → ask user for ambiguous/false-positive. **Never** guess suppression syntax.
5. **Safety gating:** Safe deterministic auto-fixes → apply automatically. Ambiguous semantic changes, rule/linter disabling, security suppression → **ask user confirmation**. Disabling hierarchy: inline comment → linter config → `<KEY>_FILTER_REGEX_EXCLUDE` → `<KEY>_DISABLE_ERRORS: true` → `DISABLE_LINTERS` (last resort). Never disable without confirmation. Never commit or push on the default branch — create `megalinter/fix-<topic>` branch first. Never push to the default branch without confirmation. Never `git push --force` (never --force); only exception is amending MegaLinter auto-fix commit `[MegaLinter] Apply linters fixes` with `🤖` prefix via `--force-with-lease` to re-trigger CI (see upstream `megalinter-check` auto-fix handling, with 5 preconditions).
6. **Targeted re-check:** After fixes, re-run only previously-failing linters/files in parallel (`npx mega-linter-runner --linter <KEY> -e JSON_REPORTER=true <files>`), capped 4 concurrent. Each run ≤10 min, full run ≤30 min, with orphan-container cleanup after kill.
7. **Bounded iteration:** Repeat fix → re-check ≤3 times total. If errors remain, stop and report remaining + recommendation (manual fix, disable rule, disable linter). Relay `slow_linters` performance suggestions (e.g., `ADDITIONAL_EXCLUDED_DIRECTORIES`, `FILTER_REGEX_EXCLUDE`, flavor change) even on green runs — never auto-apply.

## Cross-agent mapping (dated 2026-08-12, sources: megalinter.io/latest/coding-agents/, oxsecurity/megalinter/skills/README.md, agents/INSTALL.md)

| Target | MegaLinter official mechanism | Toolkit adapter |
|--------|-------------------------------|-----------------|
| **Claude Code** | Agent Skills (`npx skills add ... -a claude-code`) + sub-agents `.claude/agents/megalinter-watcher`/`runner`/`fixer` (model `haiku` for watcher/runner) | Native — install skills + copy sub-agents per `agents/INSTALL.md` |
| **Cursor** | Skills (`-a cursor`) + custom agents (Cursor supports agent definitions) | Native — same as Claude, target `.cursor` |
| **GitHub Copilot CLI** | Skills (`-a github-copilot`) + custom agents `.github/agents/` (keep `name`/`description`, drop `tools`/`model` if needed) | Native — install + adapt frontmatter |
| **OpenCode** | Skills (`-a opencode`) + sub-agents `.opencode/agent/` (`mode: subagent`, translate `tools` map, cheap model) | Native — as above |
| **Codex** | Skills (`-a codex`) + custom sub-agents (if platform documents `AGENTS.md` sub-agents, mirror Claude pattern; if only `AGENTS.md`, degrade) | Native / fallback — inline if no sub-agent file support |
| **Muse Code (pi)** | No native skill/sub-agent support documented (as of 2026-08-12) — `npx skills add ... -a pi` not listed; use `--copy` detection or manual | Fallback — sequential inline execution (no sub-agents), same workflow |
| **Antigravity** | Listed as supported in skills README (`antigravity`) | Native — `npx skills add ... -a antigravity` |

**Sub-agent optimization:** When `megalinter-watcher`/`runner`/`fixer` are installed and target supports `Agent`/`Task` tool, delegate CI watch to `megalinter-watcher`, local runs to `megalinter-runner`, and fan out one `megalinter-fixer` per failing linter in parallel. Otherwise degrade gracefully to inline (same steps, sequential).

**Fallback:** All targets support sequential inline (no sub-agents) — workflow still completes, just slower and with larger context.

## Safety semantics (Toolkit mapping)

| Upstream rule | Toolkit enforcement |
|---------------|---------------------|
| Safe auto-fixes only | Auto-fixable linters via `mega-linter-runner --fix` → auto-apply |
| Ambiguous / false-positive | Ask via `AskUserQuestion`, propose `proposed_disable` but never apply |
| Disabling linter/rule | Always ask, hierarchy narrowest-first |
| Default branch mutation | Never commit/push to `main`/`master`; create branch, ask before push |
| Force-push | Never force-push; never --force; only `--force-with-lease` for amending `[MegaLinter] Apply linters fixes` when 5 preconditions hold (tip is auto-fix, not already 🤖, LOCAL_AHEAD==0, clean tree, not default branch without ask) |
| Loop bound | ≤3 iterations |

## Dogfooding in this repo

This repo already uses MegaLinter:
- `.mega-linter.yml` (local) — 6 linters, `VALIDATE_ALL_CODEBASE: false`
- `.github/workflows/mega-linter.yml` (CI) — `oxsecurity/megalinter@v9` (prior), `ENABLE_LINTERS: YAML_YAMLLINT, JSON_JSONLINT, MARKDOWN_MARKDOWNLINT, BASH_SHELLCHECK, PYTHON_RUFF, REPOSITORY_SECRETLINT, REPOSITORY_CHECKOV` (CI-only), `DISABLE_ERRORS` for markdown/ruff/checkov.

The coding-agent capability helps:
- `megalinter-setup` to upgrade `.mega-linter.yml` / CI to v10 (via `npx mega-linter-runner --upgrade --no-prompt` + `ghcr.io` prefix migration) when user asks,
- `megalinter-check` to watch PR job or run locally (CI preferred to avoid GB download),
- `megalinter-fix` to fix safe findings.

It does **not** force every consumer repo to adopt MegaLinter — setup is opt-in.

## References

- `references/megalinter-targets.md` — dated target matrix + install verification (2026-08-12)
- `references/megalinter-license.md` — AGPL-3.0 analysis (what is redistributed vs referenced, obligations, why external)
- `references/megalinter-images.md` — Docker tag + digest (`ghcr.io/oxsecurity/megalinter:v10` config digest `sha256:9390...`, npm `mega-linter-runner@10.0.0` integrity) and multi-arch manifest-list notes
- Upstream: https://megalinter.io/latest/coding-agents/, https://github.com/oxsecurity/megalinter (v10.0.0, 2026-08-08), https://megalinter.io/latest/install-agent-skills/
