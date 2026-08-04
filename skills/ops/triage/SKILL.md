---
name: triage
description: Workstation health triage — validate tooling, directory layout, and run dots-doctor with remediation suggestions.
metadata:
  author: ulises-jeremias
  version: "1.1"
---

# Workstation Triage ()

Use when the user reports workstation issues, install problems, tool failures, or needs a health check before starting work.

## Prerequisites

Run this skill on the **local workstation** where the user is experiencing issues. Do not run it on a remote server unless the user confirms the remote has the setup.

Verify `dots-doctor` is installed:

```bash
command -v dots-doctor
```

If missing, install via chezmoi (`chezmoi apply`) or direct installation.

## Output modes

Use the mode that matches the user's need:

| Mode | Command | When to use |
|------|---------|-------------|
| **Colored** (default) | `dots-doctor` | Interactive terminal session — human-readable colored output |
| **Markdown** | `dots-doctor --issue` | GitHub issues, Slack threads, tickets — paste-ready block |
| **JSON** | `dots-doctor --json` | Automation scripts, CI parsing — single-line machine-readable |

### Markdown output (`--issue`)

Always use `dots-doctor --issue` (not the default) when the output will be shared in:
- GitHub issues or PR comments
- Slack messages
- Support tickets
- Any written async communication

### JSON output (`--json`)

Use `dots-doctor --json` only when:
- A script or automation pipeline needs to parse the result
- You need a single-line summary for programmatic handling
- Requires `python3` in PATH

## Profile and check groups

The doctor's behavior is controlled by `~/.config//profile.env`. Checks can be selectively enabled/disabled via environment variables:

| Variable | Default | Effect |
|----------|---------|--------|
| `DOTS_WORKSTATION_DOCTOR_GROUP_CORE` | `true` | Core tools: `git`, `curl`, `wget`, `jq`, `rg`, `fd`, `zsh`, `gh` |
| `DOTS_WORKSTATION_DOCTOR_GROUP_NODE` | `true` | Node.js: `fnm`, `node` |
| `DOTS_WORKSTATION_DOCTOR_GROUP_PYTHON` | `true` | Python: `uv`, `python3` |
| `DOTS_WORKSTATION_DOCTOR_GROUP_DOCKER` | `true` | Docker: `docker` |
| `DOTS_WORKSTATION_DOCTOR_GROUP_AI` | `true` | LLM API key presence flags (ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY) |
| `DOTS_WORKSTATION_DOCTOR_GROUP_SKILLS_PRODUCTIVITY` | `false` | Optional productivity tool group |
| `DOTS_WORKSTATION_DOCTOR_SKILL_JIRA` | `false` | JIRA skill integration check |
| `DOTS_WORKSTATION_DOCTOR_SKILL_CONFLUENCE` | `false` | Confluence skill integration check |

> **Note:** Profile variables are read from `~/.config//profile.env`. If the file is missing, defaults apply.

## Directory checks

The doctor validates the presence and structure of:
- `~/.local/share//prompts`
- `~/.local/share//skills`
- `~/.local/share//templates`
- `~/.local/share//mcp/github`
- `~/.local/share//mcp/clickup`
- `~/.local/share//mcp/notion`
- `~/.local/share//mcp/slack`

## Remediation guidance

Propose fixes in order of lowest risk first:

1. **Missing directories** → run `chezmoi apply` to bootstrap the full installation
2. **Missing commands** → use the respective skill's installation instructions (e.g., `uv` via `curl -LsSf https://astral.sh/uv/install.sh`)
3. **Auth failures** → run `gh auth login`, `clickup auth login`, or `glab auth login` as appropriate
4. **Profile/group mismatches** → edit `~/.config//profile.env` and run `chezmoi apply`
5. **API key missing** → guide user to set the appropriate env var in their shell profile

## Common issues

### dots-doctor exits 1 (NON-COMPLIANT)

Run with `--issue` to get the full markdown checklist. Address failures in this order:
1. Install any missing core commands
2. Run `chezmoi apply` to restore directory structure
3. Re-authenticate CLIs (`gh`, `clickup`, `glab`)
4. Verify `~/.config//profile.env` matches the intended profile

### dots-doctor --json requires python3

If `python3` is not available, fall back to `dots-doctor --issue` and parse the markdown manually.

### dots-doctor: Missing dependency: easyoptions.sh

The `easyoptions.sh` library is missing from `~/.local/lib/`. Re-run `chezmoi apply` to restore it, or check if the installation is incomplete.

## Skill boundaries

- This skill **does not fix issues automatically** — it diagnoses and proposes remediation steps.
- This skill **does not modify** `profile.env` or authentication state — user must approve and execute fixes.
- For **chezmoi-managed configuration issues**, pair with the **`dev-companion`** or direct chezmoi guidance.
- For **CI/build failures** on a project repo, use **`build-error-resolver`** instead of this skill.

## References

- `dots-doctor --help` — full option list
- `~/.config//profile.env` — check group configuration
- `~/.local/lib//easy-options/easyoptions.sh` — dependency library
