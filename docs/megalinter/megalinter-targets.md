# MegaLinter Target Mapping — Dated 2026-08-12

**Upstream sources (2026-08-12):**
- https://megalinter.io/latest/coding-agents/ (description: "Setup, run and fix MegaLinter errors from Claude Code, Cursor, GitHub Copilot CLI, Codex, Gemini CLI, Antigravity, OpenCode and other coding agents, with token-efficient sub-agents orchestration")
- https://raw.githubusercontent.com/oxsecurity/megalinter/main/skills/README.md (2026-08-12 snapshot)
- https://raw.githubusercontent.com/oxsecurity/megalinter/main/skills/megalinter-setup/agents/INSTALL.md (2026-08-12)
- Git tags: `v10.0.0` at `15e5b45552097e318c93de385779ce3b1084052c` (2026-08-08, `gh api repos/oxsecurity/megalinter/releases/tags/v10.0.0`)

## Official skill names (current)

| Skill | Path | Purpose (upstream SKILL.md description) |
|-------|------|----------------------------------------|
| `megalinter` | `skills/megalinter/SKILL.md` | Entry point: detects state, orchestrates setup→check→fix loop until clean (≤3 iterations) |
| `megalinter-setup` | `skills/megalinter-setup/SKILL.md` | Install/upgrade via `npx mega-linter-runner --install/--upgrade`, scaffold custom flavor, install sub-agents |
| `megalinter-check` | `skills/megalinter-check/SKILL.md` | Collect errors: watch CI job (GitHub/GitLab/Azure/Bitbucket) or run locally via docker/podman, targeted re-check |
| `megalinter-fix` | `skills/megalinter-fix/SKILL.md` | Fix via per-linter guides, auto-fix first, ask for ambiguous, propose disables |

**Installation (official):**
```bash
npx skills add oxsecurity/megalinter/skills -s '*' -a claude-code -y
# or -a cursor, -a github-copilot, -a codex, -a antigravity, -a opencode, etc.
npx skills add oxsecurity/megalinter/skills -s '*' -y --copy  # auto-detect
npx skills update megalinter megalinter-setup megalinter-check megalinter-fix -y
```

**Sub-agents (shipped in `skills/megalinter-setup/agents/`):**
- `megalinter-watcher` (tools: Read,Grep,Glob,Bash, model: haiku) — watch CI job, return compact JSON, never fixes
- `megalinter-runner` (Read,Grep,Glob,Bash, haiku) — run locally, digest reports
- `megalinter-fixer` (Read,Grep,Glob,Edit,Write,Bash,WebFetch,WebSearch) — fix ONE linter, propose disables, never commits

Per `agents/INSTALL.md` (2026-08-12):
- Claude Code: `mkdir -p .claude/agents && cp <skill_dir>/agents/megalinter-*.md .claude/agents/`
- OpenCode: `.opencode/agent/` with `mode: subagent`, translate `tools` map, cheap model
- GitHub Copilot: `.github/agents/` keep `name`/`description`, drop `tools`/`model` if needed
- Codex/other: mirror pattern if platform documents sub-agent files; if only `AGENTS.md`, degrade to inline.

## Supported coding agents (as of 2026-08-12)

| Agent | Mechanism | Sub-agents | Evidence |
|-------|-----------|------------|----------|
| Claude Code | Skills + `Agent` tool | Yes (watcher/runner/fixer) | skills/README.md + coding-agents page |
| Cursor | Skills + custom agents | Yes | same |
| GitHub Copilot CLI | Skills + `.github/agents/` | Yes | agents/INSTALL.md |
| Codex | Skills + custom agents (if supported) | Conditional | INSTALL.md: "If your platform documents custom agent/subagent definition files, mirror pattern" |
| OpenCode | Skills + `.opencode/agent/` | Yes | INSTALL.md |
| Muse CLI | Skills (implied) | Unknown — listed on coding-agents page as supported | megalinter.io/latest/coding-agents/ meta description includes Gemini CLI |
| Antigravity | Skills (`-a antigravity`) | Unknown — listed in skills README | skills/README.md line: "Cursor CLI, GitHub Copilot CLI, Codex, Antigravity, OpenCode" |
| Muse Code (pi) | Not listed as supported `-a pi` target (2026-08-12) — use `--copy` auto-detect or manual | No | `npx skills add` docs list supported agents via vercel-labs/skills; `pi` not in that list as of 2026-08-12 |

**Fallback:** All targets degrade gracefully to inline sequential execution when sub-agents unavailable — workflow still completes (same ≤3 loop, same safety gates), just slower.

## Verification commands

```bash
npx skills list | grep megalinter
# Expect: megalinter, megalinter-setup, megalinter-check, megalinter-fix with Source oxsecurity/megalinter v10.0.0

ls .claude/agents/megalinter-*.md  # Claude Code sub-agents present after setup
ls .opencode/agent/megalinter-*.md # OpenCode
ls .github/agents/megalinter-*.md  # Copilot
```

## Notes

- `licence` field in each upstream SKILL.md: `MegaLinter by OX Security, Copyright 2026 - https://megalinter.io/` — not SPDX, but repo LICENSE is AGPL-3.0 (see megalinter-license.md).
- First run locally is resource-consuming: Docker image several GB, needs docker/podman responding (`timeout 10 docker info`), ask user before local vs CI (CI preferred).
