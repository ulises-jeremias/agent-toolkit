# Contributing to agent-toolkit

Thank you for your interest in contributing. This document covers everything you need to get started.

---

## Prerequisites

- **Git** 2.30 or later
- **Python** 3.10 or later (used by validation scripts)
- **uv** (recommended) — see https://docs.astral.sh/uv/getting-started/installation/
- A GitHub account and a fork of this repository

Verify your setup:

```bash
git --version
python3 --version
uv --version
```

Install workspace dependencies (first time or after pulling):

```bash
uv sync --all-extras
```

---

## Smoke Test Skills and Agents

Run a mechanical integrity check on every `SKILL.md` and `AGENT.md`:

```bash
python3 scripts/smoke-test-skills.py
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
python3 scripts/validate-skills.py

# Validate AGENT.md frontmatter
python3 scripts/validate-agents.py

# Validate loop.yaml files against schemas/loop.schema.json (as CI does)
python3 - <<'PY'
import json, sys, yaml
from pathlib import Path
from jsonschema import validate, ValidationError
schema = json.loads(Path("schemas/loop.schema.json").read_text())
errors = []
for f in sorted(Path("loops").rglob("loop.yaml")):
    d = yaml.safe_load(f.read_text())
    try:
        validate(d, schema)
        print(f"  OK: {f}")
    except ValidationError as e:
        errors.append(f"  FAIL: {f}: {e.message}")
        print(f"  FAIL: {f}: {e.message}", file=sys.stderr)
if errors:
    sys.exit(1)
print(f"All {len(list(Path('loops').rglob('loop.yaml')))} loop template(s) valid.")
PY

# Validate marketplace manifests
python3 scripts/validate-manifests.py

# Detect plugin surface drift
python3 scripts/gen-surfaces.py --check

# Regenerate catalogs and verify they match source files
python3 scripts/generate-catalogs.py

# Full test suite (CI parity)
AGENT_TOOLKIT_ROOT=$PWD uv run pytest tests/ -v
```

Install pre-commit hooks (one-time, #274):

```bash
pip install pre-commit   # or: uv tool install pre-commit
pre-commit install
pre-commit run --all-files  # optional: run all hooks now
```

Python style is enforced in CI by **Ruff** (`validate.yml` → `ruff` job, blocking on PRs).
MegaLinter still runs on `main` only with `PYTHON_RUFF` set to advisory (`DISABLE_ERRORS`);
do not add a conflicting blocking MegaLinter Python config — `validate.yml` is the
single source of truth for PR style gating. Fix Ruff issues locally with:

```bash
uv run ruff check --fix packages/agent-toolkit-cli/src tests
uv run ruff format packages/agent-toolkit-cli/src tests
```

Type checking is incremental and **warn-only** in CI (`mypy` job, `continue-on-error: true`).
Only `agent_toolkit.compiler` and `agent_toolkit.installer` are checked initially
(`follow_imports=skip`, narrow allowlist, see `pyproject.toml` `[tool.mypy]` and
`validate.yml` `mypy` job). Do not add `# type: ignore` sprees — fix types properly.

If any command exits non-zero, read the output — it will tell you which file failed and why.

---

## How to Add a Skill

1. **Check for duplicates** — search `catalogs/skill-catalog.yaml` for a skill that already covers your use case:

   ```bash
   grep -i "your-skill-topic" catalogs/skill-catalog.yaml
   ```

2. **Pick a domain** — choose the most specific domain from: `core`, `delivery`, `design`, `forge`, `integrations`, `data`, `tooling`, `ops`, `loops`. If nothing fits, open an issue to discuss adding a new domain before proceeding.

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
   python3 scripts/validate-skills.py
   ```

7. **Regenerate catalogs**:

   ```bash
   python3 scripts/generate-catalogs.py
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
   python3 - <<'PY'
   import json, yaml
   from pathlib import Path
   from jsonschema import validate
   schema = json.loads(Path("schemas/loop.schema.json").read_text())
   d = yaml.safe_load(Path("loops/<loop-name>/loop.yaml").read_text())
   validate(d, schema)
   print("Valid: loops/<loop-name>/loop.yaml")
   PY
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
- [ ] `python3 scripts/validate-skills.py` passes with exit 0
- [ ] `python3 scripts/validate-agents.py` passes with exit 0 (if you added/modified agents)
- [ ] Loop `loop.yaml` validates against `schemas/loop.schema.json` (if you added/modified loops) — see Validation Commands
- [ ] `python3 scripts/generate-catalogs.py` was run and catalog changes are included (if you added/modified skills/agents/loops)
- [ ] `python3 scripts/gen-surfaces.py --check` passes (if you added/modified skills/agents/loops or surfaces)
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

## Getting Help

- Open a [GitHub Discussion](https://github.com/ulises-jeremias/agent-toolkit/discussions) for questions about skill design, compatibility, or architecture
- Open an [issue](https://github.com/ulises-jeremias/agent-toolkit/issues) for bugs or feature requests
- For security issues, see [SECURITY.md](SECURITY.md)

## Compiler workflow

When adding a new skill, agent, or loop, verify the compiler pipeline:

```bash
# Sync workspace deps first
uv sync --all-extras

# Validate your changes
python3 scripts/validate-skills.py
python3 scripts/validate-agents.py
python3 scripts/validate-manifests.py
python3 scripts/gen-surfaces.py --check

# Run the compiler in check mode
uv run agent-toolkit build --check

# Check for drift vs installed bundles
uv run agent-toolkit diff

# Run all tests including contract tests
AGENT_TOOLKIT_ROOT=$PWD uv run pytest tests/ -v
```

## Adding a new compiler target

1. Create `packages/agent-toolkit-cli/src/agent_toolkit/compiler/targets/<target>.py` extending `TargetAdapter`
2. Register the adapter in `packages/agent-toolkit-cli/src/agent_toolkit/cli/build.py`
3. Add contract tests under `tests/compiler/`
4. Add `distributions/targets/<target>.yaml` with capability declarations
5. Write contract tests in `tests/compiler/test_<target>_adapter.py`
6. Ensure `CompilationResult` always reports unsupported capabilities explicitly
