# Skill Integration Checklist

**Mandatory** for every PR that adds or materially modifies a skill (#2–#8, #12 in Epic #743).
Copy this checklist into the PR body and mark each item.

Governance context: [UPSTREAM_VS_FIRST_PARTY.md](UPSTREAM_VS_FIRST_PARTY.md).

---

## A. Canonical skill source

- [ ] `skills/<domain>/<name>/SKILL.md` with valid frontmatter (`./scripts/validate-skills.vsh`)
- [ ] `catalogs/skills-layout.json` — skill name in the correct domain group
- [ ] **If upstream:** `LICENSE`, `UPSTREAM.md`, `origin.type: upstream`, lock entry, `python3 scripts/provenance.py check`
- [ ] **If first-party:** `origin.type: first-party`; if ideas absorbed → `metadata.inspired_by[]`

---

## B. Catalogs and products (generated)

- [ ] `distributions/products.yaml` — skill in correct product(s)
- [ ] `./scripts/generate-catalogs.vsh` → `skill-catalog.yaml` updated
- [ ] `./scripts/generate-skill-matrix.vsh` if product membership changed
- [ ] `./make.vsh build-cli && AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check`

---

## C. Orchestration routing (hand-edited)

- [ ] `skills/core/assistant/references/ORCHESTRATION.md` — new row or cross-skill note
- [ ] `skills/core/assistant/SKILL.md` — "Where to route next" table if high-traffic skill
- [ ] `skills/core/dev-companion/SKILL.md` — delegation row if delivery/forge relevant
- [ ] `catalogs/skill-catalog.yaml` — verify `triggers` / description after regenerate

---

## D. Agent wiring

Update canonical agents in `agents/` (compiler emits to plugins/profiles):

| Skill domain | Agents |
|--------------|--------|
| `quality/unslop`, `quality/deslop` | `code-reviewer` (+ `reviewer` + `reviewer/references/REFACTOR_CHECKLIST.md` archived #865), `assistant` |
| `quality/blast-radius` | `architect`, `planner`, `code-reviewer` |
| `tooling/cli-for-agents` | `assistant`, `build-error-resolver` (if CLI-related) |
| `forge/fix-merge-conflicts` | `assistant`; dev-companion → forge row |
| `forge/gh-fix-ci` (enhanced) | verify CI checklist in agent/delegation context |
| `quality/deep-review` | `code-reviewer` — when to escalate |

Per agent, add **"Delegate to skills"** section with triggers.

**Profiles legacy** (`profiles/cursor/rules/`): prefer `agents/` + `build --check`; do not hand-edit
duplicates unless compiler does not emit yet.

---

## E. Plugin / tool surfaces (via build)

After `build --check`:

- [ ] `plugins/<product>/skills/<name>/SKILL.md` copied
- [ ] `plugins/<product>/AGENTS.md` lists skill under Available Skills
- [ ] `.cursor-plugin/plugin.json` coherent (post compiler parity work)
- [ ] OpenCode / Copilot targets emitted if product includes the skill

---

## F. Human docs

- [ ] [docs/SKILLS.md](SKILLS.md) — domain count/examples if changed
- [ ] [docs/wiki/Plugin-Marketplace.md](wiki/Plugin-Marketplace.md) — if new product
- [ ] [CHANGELOG.md](../CHANGELOG.md) — user-facing entry
- [ ] **If upstream:** [docs/UPSTREAM.md](UPSTREAM.md) regenerated (`python3 scripts/provenance.py docs`)

---

## G. Verification commands

```bash
./scripts/validate-skills.vsh
./scripts/validate-agents.vsh          # if agents/ touched
python3 scripts/validate-upstream.py --check   # if upstream
python3 scripts/provenance.py check            # if upstream
./scripts/generate-catalogs.vsh --check
./scripts/generate-skill-matrix.vsh --check    # if products.yaml changed
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit build --check
AGENT_TOOLKIT_ROOT=$PWD ./build/agent-toolkit inventory
```
