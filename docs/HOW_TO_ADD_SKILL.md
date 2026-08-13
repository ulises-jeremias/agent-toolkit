# How to Add a Skill

This guide walks you through adding a new skill to agent-toolkit from scratch. A skill is a portable, self-contained capability definition that tells an AI coding assistant what to do in a specific situation. Skills live under `skills/<domain>/<skill-name>/` and consist of exactly one required file: `SKILL.md`.

---

## 1. Choose the Right Domain

Skills are organized into domains that reflect the type of work they support:

| Domain | Purpose | Examples |
|--------|---------|---------|
| `core` | Orchestration, session management, handshake primitives | `assistant`, `output-handshake`, `onboarding` |
| `delivery` | Software-delivery lifecycle (PRD → ADR → work items → PR) | `adr`, `planning`, `development-workflow` |
| `design` | UI/UX and Figma integration | `figma-implement-design`, `figma-create-design-system-rules` |
| `forge` | Version-control forge automation (GitHub, GitLab) | `github-cli-workflow`, `gh-fix-ci` |
| `integrations` | Third-party platform connectors | `slack-cli`, `linear`, `clickup-cli` |
| `data` | Data platform validation | `dbt-validation`, `snowflake-validation` |
| `tooling` | Developer tooling (Jupyter, Playwright, etc.) | `jupyter-notebook`, `playwright-cli` |
| `ops` | Operational and health-check utilities | `triage`, `llm-cost-advisor` |
| `loops` | Recurring automation loop management | `loop-runner` |

**Decision rule**: choose the domain whose existing skills feel most similar to yours. If your skill tells an agent *how* to operate a CLI or API, it's likely `forge`, `integrations`, or `tooling`. If it tells an agent *what to do* during a project phase, it's likely `delivery` or `core`.

---

## 2. Create the Directory

```bash
# Replace <domain> and <skill-name> with your values
mkdir -p skills/<domain>/<skill-name>
```

Skill names must be kebab-case and match the `name` field in the frontmatter exactly.

```bash
# Good
mkdir -p skills/forge/changelog-generator
mkdir -p skills/delivery/git-conventional-commits

# Bad — do not use underscores or uppercase
mkdir -p skills/forge/Changelog_Generator
```

---

## 3. Write SKILL.md

Create `skills/<domain>/<skill-name>/SKILL.md`. Every skill file must begin with YAML frontmatter enclosed in `---` delimiters:

```yaml
---
name: my-skill
description: >-
  HOW — Clear description of what this skill does and when to use it.
  Include trigger keywords so the AI knows when to invoke this skill
  (e.g. "write changelog", "generate release notes", "format commits").
metadata:
  author: your-github-username
  version: "1.0"
compatibility: Optional — any tool requirements (e.g. "requires gh CLI >= 2.40")
---
```

### Required frontmatter fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Kebab-case identifier, must match the directory name |
| `description` | string | Short summary used for skill selection by the AI |

### Optional but recommended frontmatter fields

| Field | Type | Description |
|-------|------|-------------|
| `metadata.author` | string | Your GitHub username |
| `metadata.version` | string | Semantic version (e.g. `"1.0"`) |
| `compatibility` | string | Human-readable note about caveats or prerequisites |

### Description format convention

Prefix the description with the responsibility type:

- `HOW —` for tool skills that know how to operate a specific CLI or API
- `WHAT —` for workflow skills that know what to do at each project phase

The description is used by AI orchestrators to select the right skill. Write it as if you're answering the question: *"When should an agent use this skill?"*

### Skill body

After the frontmatter, write the skill body in Markdown. A well-structured skill body includes:

1. **H1 heading** — skill name and one-line purpose
2. **Capabilities table** — what the skill can do (rows) vs. what it cannot (negatives if relevant)
3. **Step-by-step procedure** — numbered steps the agent must follow
4. **Output format** — how results should be structured
5. **Safety rules** — explicit list of things the skill must never do
6. **Checklist** — final verification items before handing off

---

## 4. Add Optional References

For skills with complex domain knowledge, create a `references/` subdirectory alongside `SKILL.md`. Reference files are plain Markdown documents that the skill body can link to:

```
skills/forge/changelog-generator/
├── SKILL.md
└── references/
    ├── CONVENTIONAL_COMMITS.md
    └── KEEPACHANGELOG_FORMAT.md
```

Reference files are not loaded automatically — the skill body must explicitly tell the AI when to read them. Keep references focused and short (under 200 lines each).

---

## 5. Run Validation

```bash
python3 scripts/validate-skills.py
```

The validator checks:
- `SKILL.md` is present in every skill directory
- YAML frontmatter is valid
- Required fields (`name`, `description`) are present
- `name` in frontmatter matches the directory name

Fix any reported errors before proceeding.

---

## 6. Update catalogs/skills-layout.json

If your skill should appear in a plugin bundle (most skills should), it must be listed in `distributions/products.yaml` (see ADR-001 and ADR-003).

The compiler is the source of truth. Run the canonical **V** build check (not `uv run agent-toolkit` — there is no product uv workspace):

```bash
make build-cli
AGENT_TOOLKIT_ROOT="$PWD" ./build/agent-toolkit build --check
python3 scripts/gen-surfaces.py --check
```

See [`docs/HOW_TO_DEVELOP_V.md`](HOW_TO_DEVELOP_V.md).

---

## 7. Update catalogs/skill-catalog.yaml

Add your skill's routing metadata to `catalogs/skill-catalog.yaml` so orchestrators can route to it correctly:

```yaml
- name: changelog-generator
  domain: forge
  responsibility: HOW
  role: changelog_and_release_notes
  triggers:
    - generate changelog
    - write release notes
    - what changed in this release
    - CHANGELOG.md
  depends_on: []
```

---

## 8. Open a PR

Use the standard PR workflow. Include this checklist in your PR description:

```markdown
## Skill Checklist
- [ ] `skills/<domain>/<skill-name>/SKILL.md` created
- [ ] Frontmatter has `name` and `description`
- [ ] `name` in frontmatter matches directory name
- [ ] `python3 scripts/validate-skills.py` passes with no errors
- [ ] Registered in `catalogs/skills-layout.json` (correct group)
- [ ] Registered in `catalogs/skill-catalog.yaml` (with triggers)
- [ ] `make build-cli && AGENT_TOOLKIT_ROOT="$PWD" ./build/agent-toolkit build --check` passes
- [ ] `python3 scripts/gen-surfaces.py --check` passes
- [ ] No secrets or hardcoded tokens in skill body
- [ ] `references/` documents linked from skill body (if present)
```

---

## Complete Example: git-conventional-commits

This is a production-quality skill you can use as a template.

### Directory structure

```
skills/forge/git-conventional-commits/
├── SKILL.md
└── references/
    └── COMMIT_TYPES.md
```

### skills/forge/git-conventional-commits/SKILL.md

```markdown
---
name: git-conventional-commits
description: >-
  HOW — Write and validate git commit messages following the Conventional Commits
  specification. Use when: writing a commit message, reviewing commit history,
  squashing commits before a PR, enforcing commit conventions in CI.
metadata:
  author: ulises-jeremias
  version: "1.0"
compatibility: Requires git. No additional CLIs needed.
---

# git-conventional-commits (HOW)

Enforces the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
specification when writing or reviewing commit messages.

## Capabilities

| Can do | Cannot do |
|--------|-----------|
| Write well-formed commit messages | Rewrite already-pushed history |
| Validate a commit message against the spec | Override project-level commit hooks |
| Squash and reformat commits before merge | Bypass `--no-verify` unless asked |
| Suggest the correct type and scope | |

## Commit message format

```text
<type>(<scope>): <description>

[optional body]

[optional footer(s)]
```

**Rules:**
- `type` must be one of the types in `references/COMMIT_TYPES.md`
- `scope` is optional; use the affected component or package name
- `description` is lowercase, imperative mood, no trailing period
- Body wraps at 72 characters
- Footer uses `BREAKING CHANGE:` for breaking API changes
- Footer uses `Fixes #123` or `Closes #123` to close issues

## Step-by-step procedure

1. **Determine the type** — read `references/COMMIT_TYPES.md` and pick the
   type that best describes the intent of the change, not the mechanism.
   When in doubt: `feat` for user-visible additions, `fix` for bug fixes,
   `chore` for maintenance, `refactor` for restructuring without behavior change.

2. **Determine the scope** — optional. Use the directory name, package name, or
   module that changed. Omit if the change is cross-cutting.

3. **Write the description** — one line, 72 chars max, imperative mood:
   "add retry logic" not "added retry logic" or "adding retry logic".

4. **Write the body** — only if the description alone is insufficient to
   explain *why* the change was made. Explain motivation, not mechanics.

5. **Add footers** — add `Closes #<n>` for related issues. Add
   `BREAKING CHANGE: <description>` for API breaks.

6. **Validate** — confirm the message matches the format above before committing.

## Examples

```text
feat(auth): add OAuth2 PKCE flow

Implements the authorization code flow with PKCE for public clients
that cannot safely store a client secret. Required for mobile and SPA
integrations.

Closes #412
```

```text
fix(cli): handle empty config file without panic

Previously, an empty config.yaml caused an index-out-of-bounds panic
on startup. Now returns a clear error message with remediation steps.

Closes #389
```

```text
chore(deps): update pyyaml from 6.0.1 to 6.0.2
```

## Safety rules

- Never use `git commit --no-verify` without explicit user approval
- Never rewrite commits that have already been pushed to a shared branch
- If the project has a `commitlint` config, defer to it — do not override it

## Checklist

- [ ] Type selected from the approved list
- [ ] Description is imperative mood and under 72 characters
- [ ] Body explains *why*, not *what*
- [ ] Breaking changes declared in footer
- [ ] Related issues referenced in footer
```

### skills/forge/git-conventional-commits/references/COMMIT_TYPES.md

```markdown
# Conventional Commit Types

| Type | When to use |
|------|-------------|
| `feat` | A new feature visible to users or API consumers |
| `fix` | A bug fix |
| `docs` | Documentation changes only |
| `style` | Formatting, whitespace — no logic change |
| `refactor` | Code restructuring — no behavior change, no bug fix |
| `perf` | Performance improvement |
| `test` | Adding or correcting tests |
| `build` | Changes to build system, dependencies, or toolchain |
| `ci` | Changes to CI configuration files and scripts |
| `chore` | Maintenance tasks that don't fit above categories |
| `revert` | Reverts a previous commit |
```
