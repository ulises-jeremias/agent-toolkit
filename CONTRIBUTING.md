# Contributing to agent-toolkit

Thank you for your interest in contributing. This document covers everything you need to get started.

---

## Wiki mirror links

The `docs/wiki/` tree is a mirror for GitHub Wiki sync. Wiki-style `[[Page]]` links there
are intentional — see `docs/wiki/Contributing.md`. Do not rewrite them to relative markdown
as a drive-by fix.

## Prerequisites

- **Git** 2.30 or later
- **V** matching [`.v-version`](.v-version) (**0.5.2**) for the canonical CLI — `import json`, not `json2`. See [`docs/HOW_TO_DEVELOP_V.md`](docs/HOW_TO_DEVELOP_V.md)
- **Python** 3.10 or later (validation scripts, PyPI launcher tests, pre-commit); CI primary is **3.14**
- **Node.js** 18+ for the npm trampoline tests (`packages/npm/agent-toolkit-cli`); CI uses **22** (LTS) and **24** (Current)
- **uv** for the PyPI adapter under `packages/pypi/` only — see https://docs.astral.sh/uv/getting-started/installation/
- A GitHub account and a fork of this repository

The repo is **not** a uv workspace. The product CLI is `./make.vsh build-cli` → `build/agent-toolkit`.

Verify your setup:

```bash
git --version
v version                 # must match .v-version
python3 --version
uv --version
./make.vsh test
./make.vsh build-cli
./build/agent-toolkit --version
```

Install Python adapter + test tools (launcher/pytest only):

```bash
uv sync --project packages/pypi/agent-toolkit-cli --all-extras
```

---

## Smoke Test Skills and Agents

Run a mechanical integrity check on every `SKILL.md` and `AGENT.md`:

```bash
./scripts/smoke-test-skills.vsh
```

This command checks:
- YAML frontmatter parses
- Required fields (`name`, `description`) are present
- The `name` field matches the directory name
- The description is not a placeholder (TBD, TODO, etc.)
- Internal file references in markdown links resolve
- Scripts have shebang lines and executable bits

Run this before you open a pull request that touches `skills/` or `agents/`.
It runs in CI when those directories change.

---

## Validation Commands

Always run validation before opening a PR. All checks must pass. These match `.github/workflows/validate.yml`.

```bash
# Validate SKILL.md frontmatter (Agent Skills spec)
./scripts/validate-skills.vsh

# Validate AGENT.md frontmatter
./scripts/validate-agents.vsh

# Validate loop.yaml files against schemas/loop.schema.json (as CI does)
./scripts/validate-loops.vsh

# Validate marketplace manifests
./scripts/validate-manifests.vsh

# Detect plugin surface drift (canonical; no gen-surfaces)
./make.vsh build-cli
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check

# Regenerate catalogs and verify they match source files (never hand-edit *-catalog.yaml)
./scripts/generate-catalogs.vsh

# Canonical V CLI unit tests
./make.vsh test

# Adapter-only — required when changing PyPI/npm trampolines; optional otherwise
AGENT_TOOLKIT_ROOT=$PWD uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/ -v
npm test --prefix packages/npm/agent-toolkit-cli
```

Install pre-commit hooks (one-time, #274):

```bash
pip install pre-commit   # or: uv tool install pre-commit
pre-commit install
pre-commit run --all-files  # optional: run all hooks now
```

Python style for the launcher package is enforced in CI by **Ruff** (`validate.yml` → `ruff` job, blocking on PRs).
MegaLinter still runs on `main` only with `PYTHON_RUFF` set to advisory (`DISABLE_ERRORS`);
do not add a conflicting blocking MegaLinter Python config — `validate.yml` is the
single source of truth for PR style gating. Fix Ruff issues locally with:

```bash
uv run --project packages/pypi/agent-toolkit-cli --directory . ruff check --fix packages/pypi/agent-toolkit-cli/src tests scripts
uv run --project packages/pypi/agent-toolkit-cli --directory . ruff format packages/pypi/agent-toolkit-cli/src tests scripts
```

If any command exits non-zero, read the output — it will tell you which file failed and why.

---

## How to Add a Skill

1. **Check for duplicates** — search `catalogs/skill-catalog.yaml` for a skill that already covers your use case:

   ```bash
   grep -i "your-skill-topic" catalogs/skill-catalog.yaml
   ```

2. **Pick a domain** — choose the most specific domain from: `core`, `delivery`, `design`, `forge`, `integrations`, `data`, `tooling`, `ops`, `loops`, `agentic-security`, `architecture`, `cloud`, `accessibility`, `quality`. If nothing fits, open an issue to discuss adding a new domain before proceeding.

3. **Create the skill directory**:

   ```bash
   mkdir -p skills/<domain>/<skill-name>
   ```

4. **Write `SKILL.md`** with the required YAML frontmatter (see [AGENTS.md](AGENTS.md) for the full spec):

   ```markdown
   ---
   name: my-skill-name
   description: One-sentence description.
   metadata:
     author: your-github-username
     version: "1.0.0"
     tags: [tag1, tag2]
     domain: delivery
   ---

   # My Skill Name

   ...usage guide...
   ```

5. **Declare tool compatibility** in `SKILL.md` frontmatter (optional `tools:` map). Do **not** add `skill.json` — removed in v1.0.4; see `docs/MIGRATION.md`.

6. **Run validation**:

   ```bash
   ./scripts/validate-skills.vsh
   ```

7. **Regenerate catalogs**:

   ```bash
   ./scripts/generate-catalogs.vsh
   ```

8. Open a PR — see the PR checklist below.

---

## How to Add a Loop Template

Loops are defined by `loops/<loop-name>/loop.yaml` (see `docs/HOW_TO_CREATE_LOOP.md` for the full guide and `schemas/loop.schema.json` for the authoritative schema). `request.md` was the pre-v1 loop format and is no longer used — all loop content now lives in `loop.yaml`.

1. **Check existing loops** in the `loops/` directory to avoid duplication.

2. **Determine the tier** (mutation safety — cadence is separate):
   - **L1** — read-only or propose-only; no mutations
   - **L2** — PR-gated writes (comments, labels, draft PRs); merge/close forbidden
   - **L3** — allowlisted merge/close and other high-trust writes (proven loops only)

3. **Create the loop directory**:

   ```bash
   mkdir -p loops/<loop-name>
   ```

4. **Write `loops/<loop-name>/loop.yaml`** following `docs/HOW_TO_CREATE_LOOP.md` and the schema. Minimal required fields are `name`, `goal`, `request`; typical loops also set `tier`, `cadence`, `allowlist`/`deny`, `budget`, and `exit_conditions`:

   ```yaml
   name: my-loop-name
   description: "Daily L2 triage with PR-gated comments"
   tier: L2
   cadence: 1d
   goal: |
     Review open issues created in the last 24h and post triage comments.
     Do NOT merge or close.
   allowlist:
     - comment
     - label
   deny:
     - merge
     - close
     - push
     - approve
     - force-push
   exit_conditions:
     - goal_met
     - budget_exhausted
     - human_escalation
   budget:
     max_tokens: 80000
     max_runs_per_day: 1
     max_wall_seconds: 600
   verifier: null
   resumable: false
   request: |
     You are running the my-loop-name loop...
     [Full prompt — see docs/HOW_TO_CREATE_LOOP.md section 4]
   ```

   Field reference: `tier` is `L1`|`L2`|`L3`; `cadence` matches `^\d+[mhd]$` (e.g. `15m`, `1d`); `budget` may include `max_tokens`, `max_runs_per_day`, `max_wall_seconds`, `max_iterations`; `exit_conditions` values include `goal_met`, `budget_exhausted`, `human_escalation`, `max_iterations`, `no_work_found`, `error`.

5. **Validate your loop** against the schema (same check CI runs in `validate-loops`):

   ```bash
   ./scripts/validate-loops.vsh
   ```

6. Open a PR. Runtime artifacts `STATE.md` and `report.md` are written by the loop runner — do not commit them.

---

## How to Add a Profile

Profiles translate toolkit skills into tool-specific configuration.

1. **Find the right profile directory** under `profiles/<tool-name>/`.

2. **Follow the tool's format** (documented in [AGENTS.md](AGENTS.md)):
   - Claude Code: `CLAUDE.md` + `settings.json`
   - Cursor: one `.mdc` file per domain in `rules/`
   - OpenCode: `system-prompt.md` + `skills.yaml`
   - GitHub Copilot: `copilot-instructions.md` (self-contained — no external file references)
   - Windsurf: `rules.md` + optional `memories/`
   - Pi: individual `skills/<skill-name>.md` files (self-contained)
   - Muse Code: Agent Skills under `~/.config/muse/skills/` — see `profiles/muse-code/`

3. **Keep profiles thin** — profiles reference skills; they don't duplicate skill content.

4. **Test manually** if possible by loading the profile in the target tool and running a quick check.

5. Open a PR describing which tool the profile targets and what changed.

---

## Branch Naming

| Prefix | When to use |
|---|---|
| `feat/` | New skill, loop template, agent persona, or major profile addition |
| `fix/` | Bug fix in an existing skill, loop, or profile |
| `docs/` | Documentation-only change |
| `chore/` | Maintenance: dependency update, script fix, catalog regeneration |
| `schema/` | Changes to JSON schemas |

Examples:

```
feat/delivery-gh-address-comments
fix/oss-triage-missing-deny-list
docs/readme-mcp-section
chore/regenerate-catalogs
```

---

## Pull Request Checklist

Before submitting a PR, confirm the following:

- [ ] Branch name follows the naming convention above
- [ ] `./scripts/validate-skills.vsh` passes with exit 0
- [ ] `./scripts/validate-agents.vsh` passes with exit 0 (if you added/modified agents)
- [ ] Loop `loop.yaml` validates against `schemas/loop.schema.json` (if you added/modified loops) — see Validation Commands
- [ ] `./scripts/generate-catalogs.vsh` was run and catalog changes are included (if you added/modified skills/agents/loops) — never hand-edit `*-catalog.yaml`
- [ ] `./make.vsh test` passes
- [ ] `./make.vsh build-cli && AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check` passes (if you added/modified skills/agents/loops or surfaces)
- [ ] Adapter tests (pytest / `npm test`) only if you changed PyPI or npm trampolines
- [ ] `SKILL.md` frontmatter is complete (name, description, author, version, tags, domain)
- [ ] Optional `tools:` frontmatter in `SKILL.md` is accurate — only mark tools you have verified
- [ ] No deprecated `skill.json` files under `skills/`
- [ ] No secrets, API keys, or credentials in any file
- [ ] PR description explains what the skill/loop/profile does and which tools it targets
- [ ] If this is a new domain, an issue was opened and discussed before work started

---

## Commit Messages

Follow conventional commits:

```
feat(delivery): add gh-address-comments skill
fix(oss-triage): correct deny list in loop.yaml
docs(readme): expand MCP templates section
chore(catalogs): regenerate after adding security-sweep loop
```

Format: `<type>(<scope>): <short imperative description>`

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you agree to uphold its standards. Report unacceptable behavior by opening a private GitHub security advisory or contacting the maintainer directly.

---


## V modules (canonical consumer CLI)

The in-repo canonical `agent-toolkit` implementation is the V binary ([#555](https://github.com/ulises-jeremias/agent-toolkit/issues/555), [`docs/v/archive/cutover.md`](docs/v/archive/cutover.md)). PyPI is a thin launcher over GitHub Release binaries ([ADR-021](docs/adrs/ADR-021-pypi-binary.md)); there is no Python CLI fallback ([`docs/v/python-fallback.md`](docs/v/python-fallback.md)).

- Pin: root [`.v-version`](.v-version) — see [`docs/v/upgrade-policy.md`](docs/v/upgrade-policy.md)
- Layout: `modules/agent_toolkit_core` + `modules/agent_toolkit_cli` ([ADR-009](docs/adrs/ADR-009-v-module-architecture.md))
- Local toolchain: install V matching `.v-version`, then `./make.vsh test`, `./make.vsh fmt-check`, `./make.vsh build-cli` → `build/agent-toolkit`
- DEPRECATE/REMOVE advanced commands (`insights`, `release`): disposition-only in V ([ADR-012](docs/adrs/ADR-012-python-v-coexistence.md); no mixed-engine binary)

## Getting Help

- Open a [GitHub Discussion](https://github.com/ulises-jeremias/agent-toolkit/discussions) for questions about skill design, compatibility, or architecture
- Open an [issue](https://github.com/ulises-jeremias/agent-toolkit/issues) for bugs or feature requests
- For security issues, see [SECURITY.md](SECURITY.md)

## Compiler workflow

When adding a new skill, agent, or loop, verify the compiler pipeline:

```bash
# Canonical V CLI (see docs/HOW_TO_DEVELOP_V.md)
./make.vsh build-cli
./scripts/validate-skills.vsh
./scripts/validate-agents.vsh
./scripts/validate-manifests.vsh
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check

# Python adapter tests (launcher / packaging; not the product CLI)
uv sync --project packages/pypi/agent-toolkit-cli --all-extras
AGENT_TOOLKIT_ROOT=$PWD uv run --project packages/pypi/agent-toolkit-cli --directory . pytest -c tests/pytest.ini tests/ -v
```

## Adding a new compiler target

Canonical emitters live in V (`modules/agent_toolkit_core`). There is no Python compiler tree ([`docs/v/python-fallback.md`](docs/v/python-fallback.md)).

1. Add `distributions/targets/<target>.yaml` with capability declarations
2. Implement the V emitter next to existing targets in `modules/agent_toolkit_core`
3. Add V tests under `modules/` (and packaging/docs pytest under `tests/` where needed)
4. Ensure unsupported capabilities are reported explicitly (`build --check`)
