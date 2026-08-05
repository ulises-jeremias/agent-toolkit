# Contributing to agent-toolkit

Thank you for your interest in contributing. This document covers everything you need to get started.

---

## Prerequisites

- **Git** 2.30 or later
- **Bash** 5.0 or later (macOS ships with Bash 3; install via Homebrew: `brew install bash`)
- **Python** 3.10 or later (used by validation scripts)
- **jq** 1.6 or later (used by catalog generation scripts)
- A GitHub account and a fork of this repository

Verify your setup:

```bash
git --version
bash --version
python3 --version
jq --version
```

---

## Validation Commands

Always run validation before opening a PR. All checks must pass.

```bash
# Validate all skill manifests against the JSON schema
bash scripts/validate-skills.sh

# Validate all loop template frontmatter
bash scripts/validate-loops.sh

# Regenerate catalogs and verify they match source files
bash scripts/build-catalog.sh
```

If any script exits non-zero, read the output carefully — it will tell you which file failed and why.

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

5. **Write `skill.json`** with the compatibility matrix:

   ```json
   {
     "name": "my-skill-name",
     "version": "1.0.0",
     "description": "One-sentence description matching SKILL.md.",
     "source": "skills/delivery/my-skill-name",
     "author": "your-github-username",
     "tags": ["tag1", "tag2"],
     "compatibility": {
       "claude-code": true,
       "cursor": true,
       "opencode": true,
       "copilot": false,
       "windsurf": true,
       "pi": false
     }
   }
   ```

6. **Run validation**:

   ```bash
   bash scripts/validate-skills.sh
   ```

7. **Regenerate catalogs**:

   ```bash
   bash scripts/build-catalog.sh
   ```

8. Open a PR — see the PR checklist below.

---

## How to Add a Loop Template

1. **Check existing loops** in the `loops/` directory to avoid duplication.

2. **Determine the tier** (mutation safety — cadence is separate):
   - **L1** — read-only or propose-only; no mutations
   - **L2** — PR-gated writes (comments, labels, draft PRs); merge/close forbidden
   - **L3** — allowlisted merge/close and other high-trust writes (proven loops only)

3. **Create the loop directory**:

   ```bash
   mkdir -p loops/<loop-name>
   ```

4. **Write `request.md`** with the required YAML frontmatter:

   ```markdown
   ---
   name: my-loop-name
   tier: L2
   cadence: "0 8 * * *"
   goal: "Daily summary of repository activity."
   allowlist:
     - github
   deny:
     - file_write
   budget:
     tokens: 40000
     duration_minutes: 8
   resumable: false
   ---

   [Prompt body here]
   ```

5. **Write `report.md`** — define the output structure your loop will populate.

6. **Write `runbook.md`** — cover: what the loop does, how to trigger it manually, how to interpret output, common failure modes, escalation path.

7. **Run loop validation**:

   ```bash
   bash scripts/validate-loops.sh
   ```

8. Open a PR.

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
- [ ] `bash scripts/validate-skills.sh` passes with exit 0
- [ ] `bash scripts/validate-loops.sh` passes with exit 0 (if you added/modified loops)
- [ ] `bash scripts/build-catalog.sh` was run and catalog changes are included in the commit
- [ ] `SKILL.md` frontmatter is complete (name, description, author, version, tags, domain)
- [ ] `skill.json` compatibility matrix is accurate — only mark `true` for tools you have verified
- [ ] No secrets, API keys, or credentials in any file
- [ ] PR description explains what the skill/loop/profile does and which tools it targets
- [ ] If this is a new domain, an issue was opened and discussed before work started

---

## Commit Messages

Follow conventional commits:

```
feat(delivery): add gh-address-comments skill
fix(oss-triage): correct deny list in request.md
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
# Validate your changes
python3 scripts/validate-skills.py
python3 scripts/validate-manifests.py
python3 scripts/gen-surfaces.py --check

# Run the compiler in check mode
agent-toolkit build --check

# Check for drift vs installed bundles
agent-toolkit diff

# Run all tests including contract tests
PYTHONPATH=src pytest tests/ -v
```

## Adding a new compiler target

1. Create `packages/agent-toolkit-cli/src/agent_toolkit/compiler/targets/<target>.py` extending `TargetAdapter`
2. Register the adapter in `packages/agent-toolkit-cli/src/agent_toolkit/cli/build.py`
3. Add contract tests under `tests/compiler/`
4. Add `distributions/targets/<target>.yaml` with capability declarations
5. Write contract tests in `tests/compiler/test_<target>_adapter.py`
6. Ensure `CompilationResult` always reports unsupported capabilities explicitly
