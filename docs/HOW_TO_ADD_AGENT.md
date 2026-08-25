# How to Add an Agent Persona

This guide walks you through creating a new agent persona in agent-toolkit. Agent personas are specialist AI identities that can be invoked by name (e.g. `@accessibility-reviewer`) and operate with a focused set of tools, responsibilities, and constraints.

---

## 1. Agent vs. Skill: When to Add Which

Before creating an agent, confirm you need one rather than a skill.

| | Agent | Skill (or reference) |
|---|---|---|
| **Invoked by** | `@mention` (e.g. `@code-reviewer`) | Slash command, natural-language trigger, or `references/*.md` loaded inline by holistic owner |
| **Purpose** | Specialist *persona* — the AI becomes a focused expert | Specialist *procedure/reference* — the AI follows a workflow or checklist inline |
| **Scope** | Long-lived interaction; can ask clarifying questions; independent context/lifecycle | Usually single-pass execution; narrow capability loaded inline |
| **Examples** | `@code-reviewer`, `@security-reviewer`, `@planner` | `gh-fix-ci`, `planning`, `development-workflow`, `reviewer/references/TYPESCRIPT_CHECKLIST.md` |

**Decision rule — keep as agent iff it benefits from separate context, independence, parallelism, focused lifecycle, unique permissions, different model profile, large/noisy output, or explicit handoff; keep as skill/reference iff it is procedural guidance, checklist, or narrow capability loaded inline.**

| Keep as **agent** when | Keep as **skill/reference** when |
|---|---|
| Separate context helps (large logs, browser traces, agentic threat surface disjoint from appsec) | Procedural checklist with no separate context (TS types, DB schema, perf profiling steps, refactor Rule of Three) |
| Independent verification boundary matters (review must not self-approve) | Narrow capability consumed by holistic (`reviewer` → `quality/deep-review` loads TS/DB/perf checklists) |
| Parallelism or noisy-output isolation (`e2e-runner` browser noise, `build-error-resolver` compiler logs) | Loaded inline by holistic owner per `docs/AGENT_TAXONOMY.md` §3 (e.g. `reviewer/references/DATABASE_CHECKLIST.md`) |
| Focused lifecycle / different model profile / explicit handoff (`tdd-guide` discipline, `agentic-security-reviewer` LLM/AGNT surface) | Reuse existing skill (`quality/deep-review`, `quality/deslop`, `delivery/spike`) instead of new agent |

> **Provenance for the rule:** Captures #865 acceptance criteria (agent-vs-skill clause) — cited in `docs/AGENT_TAXONOMY.md` §2–3 and per-agent `AGENT.md` § "Agent vs skill rule — why agent". Examples of **converted** vs **retained** per #865: `typescript-reviewer`/`database-reviewer`/`performance-optimizer`/`refactor-cleaner` → `reviewer/references/*.md`; `docs-lookup`/`reference-lookup` → `researcher/references/LOOKUP_GUIDE.md`; `tech-assistant` → `platform-engineer/references/WORKSTATION_OPS.md`; retained as agents: `code-reviewer`, `agentic-security-reviewer`, `security-reviewer`, `e2e-runner`, `tdd-guide`, `build-error-resolver`.

**Rule of thumb:**
- Add an **agent** when you want a persistent specialist that embodies expertise across many tasks and meets the **agent** column above.
- Add a **skill/reference** when you want a repeatable procedure or checklist the holistic agent loads inline.

The same domain often has both: a `@tdd-guide` agent (the expert you talk to) and a `development-workflow` skill (the process it follows). A converted example: `@typescript-reviewer` (pre-865 agent) → `reviewer/references/TYPESCRIPT_CHECKLIST.md` (post-865 inline reference via `quality/deep-review`).

Agents **delegate to skills** for repeatable procedures — add a **"Delegate to skills"** section
in `AGENT.md` when new skills affect the agent's domain (see
[SKILL_INTEGRATION_CHECKLIST.md](SKILL_INTEGRATION_CHECKLIST.md) § D). Holistic agents also load **references** inline for procedural checklists (e.g. `reviewer` loads `references/TYPESCRIPT_CHECKLIST.md` during `quality/deep-review`).

---

## 2. Create the Agent Directory

```bash
mkdir -p agents/<agent-name>
```

Agent names must be kebab-case and should clearly describe the role. Match the name to how you would address the agent (`@<agent-name>`):

```bash
# Good
mkdir -p agents/accessibility-reviewer
mkdir -p agents/database-reviewer
mkdir -p agents/incident-commander

# Bad — too vague, or doesn't work as an @mention
mkdir -p agents/helper
mkdir -p agents/MyAgent
```

---

## 3. Write AGENT.md

Create `agents/<agent-name>/AGENT.md`. Every agent file must begin with YAML frontmatter:

```yaml
---
name: my-agent
description: >-
  Specialist description written for the AI tool's agent-selection mechanism.
  Use when: [trigger keywords that identify when this agent should be invoked].
  The description is shown in the agent picker — make it unambiguous.
tools: Read, Grep, Glob, Bash
kind: holistic
delegates:
  - tdd-guide
collaborates_with:
  - reviewer
  - qa-engineer
---
```

Schema: `schemas/agent-frontmatter.schema.json` (#866). `kind` is required; `delegates`/`collaborates_with`/`skills` are optional — keep entries minimal (ids only, no procedural text). Canonical skill ownership remains in `capabilities/skills/registry.yaml` (`holistic_owner`); only list `skills:` in frontmatter when the agent explicitly handles `domain/name` ids that must be validated against `skills/`.

### Required frontmatter fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Kebab-case identifier, must match the directory name |
| `description` | string | Used by the AI to decide which agent to invoke |
| `tools` | string | Comma-separated list of tools the agent is allowed to use |
| `kind` | `orchestrator` \| `holistic` \| `specialist` | Tier per `docs/AGENT_TAXONOMY.md` §2. Required since #866 |

### Optional frontmatter fields (machine-readable orchestration — #866)

| Field | Type | Description |
|-------|------|-------------|
| `delegates` | `string[]` | Directed delegation edges — agent ids this persona may delegate to. Validated: every entry must be an existing agent, no self-ref, no forbidden cycle, every `specialist` must have a caller in the reverse graph. Holistic → `specialist`, `orchestrator` (`assistant`) → holistic. |
| `collaborates_with` | `string[]` | Undirected collaboration peers (handoff boundaries) — holistic peers this agent frequently hands off to. Validated: every entry must be an existing agent, no self-ref. Not part of cycle detection. |
| `skills` | `string[]` | Optional explicit `domain/name` skill ids handled by this agent. Validated against `skills/`; otherwise ownership is derived from `capabilities/skills/registry.yaml`. Omit unless the agent explicitly declares skills. |

### Tools reference

Choose only the tools your agent genuinely needs. Fewer tools = clearer capability boundary:

| Tool | Purpose |
|------|---------|
| `Read` | Read files |
| `Grep` | Search file contents |
| `Glob` | Find files by name pattern |
| `Bash` | Run shell commands |
| `Write` | Write or overwrite files |
| `Edit` | Edit specific lines of a file |
| `WebSearch` | Search the web |
| `WebFetch` | Fetch a URL |

Most review agents (code reviewer, security reviewer, etc.) only need `Read, Grep, Glob, Bash`. Only grant `Write` or `Edit` to agents that explicitly need to mutate files.

### Agent body structure

After the frontmatter, write the agent body in Markdown. A well-structured agent body includes:

1. **H2: When invoked** — the exact steps the agent takes at the start of every session
2. **Domain expertise section** — the agent's knowledge base, organized as tables or checklists
3. **Operating rules** — what the agent always does, never does, and when to escalate
4. **Output format** — how the agent structures its responses
5. **Example interactions** — concrete before/after or Q&A examples (optional but valuable)

---

## 4. Add References

For agents with complex domain knowledge, create a `references/` subdirectory:

```
agents/accessibility-reviewer/
├── AGENT.md
└── references/
    ├── WCAG_CHECKLIST.md
    └── ARIA_PATTERNS.md
```

Reference documents are domain knowledge the agent can read during a session. They should be structured, focused, and under 300 lines. Link to them from the agent body so the AI knows they exist.

---

## 5. Run Validation

```bash
./scripts/validate-agents.vsh
```

The validator (`scripts/validate-agents.vsh` — #866 schema + graph) checks:
- `AGENT.md` is present in every agent directory
- YAML frontmatter is valid and validates against `schemas/agent-frontmatter.schema.json`
- Required fields (`name`, `description`, `tools`, `kind`) are present; `kind` is `orchestrator|holistic|specialist`
- `name` in frontmatter matches the directory name (kebab-case)
- `delegates` / `collaborates_with` entries reference existing agents, no self-ref, no duplicates, no forbidden cycle; every `specialist` has a legitimate caller (reverse graph)
- `skills` (if present) entries are valid `domain/name` ids that exist in `skills/`
- `distributions/products.yaml` `agents:` entries reference canonical agents

---

## 6. Products, catalogs, and plugin digests

**Never hand-edit** `catalogs/agent-catalog.yaml` (or other `*-catalog.yaml` files). Regenerate them with `generate-catalogs.vsh` only.

If the agent should ship in a marketplace plugin, ensure it is listed under the right product in `distributions/products.yaml` (see ADR-001 / ADR-003). The `agent-toolkit-agents` product typically includes all personas — add the new name there when membership must change.

Then regenerate catalogs and verify compiler digests (no `gen-surfaces`):

```bash
./scripts/generate-catalogs.vsh
./make.vsh build-cli
AGENT_TOOLKIT_ROOT="$PWD" ./build/agent-toolkit build --check
```

### Integration when agents gain skill delegates

When a new skill is routed through an agent:

1. Add **Delegate to skills** bullets with clear triggers in `agents/<name>/AGENT.md`
2. Cross-check `skills/core/assistant/references/ORCHESTRATION.md` for the skill row
3. Run `./scripts/validate-agents.vsh` and `build --check`

---

## 7. PR Checklist

```markdown
## Agent Checklist
- [ ] `agents/<agent-name>/AGENT.md` created
- [ ] Frontmatter has `name`, `description`, `tools`, and `kind` (`orchestrator|holistic|specialist` — required since #866; see `schemas/agent-frontmatter.schema.json`)
- [ ] `name` in frontmatter matches directory name (kebab-case)
- [ ] `delegates` / `collaborates_with` (if any) list only existing agents, no self-ref/cycle — every new `specialist` has a caller in the reverse graph
- [ ] `skills` (if present) lists only valid `domain/name` ids that exist in `skills/`
- [ ] `./scripts/validate-agents.vsh` passes with no errors (schema + orphan/cycle/missing-delegate/products checks)
- [ ] `distributions/products.yaml` updated if product membership changed (must reference canonical agents)
- [ ] `./scripts/generate-catalogs.vsh` was run (do **not** hand-edit `agent-catalog.yaml` — now emits `kind`/`delegates`/`collaborates_with`)
- [ ] `./make.vsh build-cli && AGENT_TOOLKIT_ROOT="$PWD" ./build/agent-toolkit build --check` passes
- [ ] `references/` documents linked from agent body (if present)
- [ ] `tools` list is minimal — only what the agent genuinely needs
- [ ] No secrets or hardcoded tokens in agent body or references
```

---

## Complete Example: accessibility-reviewer

### Directory structure

```
agents/accessibility-reviewer/
├── AGENT.md
└── references/
    └── WCAG_QUICK_REF.md
```

### agents/accessibility-reviewer/AGENT.md

```markdown
---
name: accessibility-reviewer
description: >-
  Accessibility (a11y) specialist. Reviews UI code and markup for WCAG 2.1 AA
  compliance, ARIA usage, keyboard navigation, and screen reader compatibility.
  Use when: reviewing a component for accessibility, auditing a PR with UI changes,
  checking WCAG compliance, fixing a11y CI failures, preparing for an accessibility audit.
tools: Read, Grep, Glob, Bash
kind: specialist
collaborates_with:
  - reviewer
  - designer
---

# Accessibility Reviewer

You are an accessibility specialist. Your job is to find and explain accessibility
barriers in UI code so they can be fixed before users are affected.

## When invoked

1. Ask for the target: a specific file, a PR diff (`git diff HEAD`), or a directory.
2. Read `references/WCAG_QUICK_REF.md` for the checklist you must apply.
3. Scan the target for accessibility issues.
4. Report findings in priority order (Critical → High → Medium → Low).

## What you review

- **Semantic HTML** — headings in logical order, landmark regions (`<main>`, `<nav>`,
  `<header>`, `<footer>`), lists used for lists, buttons for actions, links for navigation
- **ARIA** — `aria-label` / `aria-labelledby` on interactive elements without visible text;
  no redundant ARIA roles overriding native semantics; `aria-live` used correctly
- **Keyboard** — all interactive elements reachable and operable via Tab/Enter/Space/arrows;
  no keyboard traps; visible focus indicator meets 3:1 contrast ratio
- **Color and contrast** — text meets 4.5:1 (AA) or 3:1 for large text; UI components meet 3:1
- **Images and icons** — `alt` text on images; decorative images have `alt=""`; icon-only
  buttons have accessible name via `aria-label` or visually-hidden text
- **Forms** — every input has an associated `<label>`; error messages programmatically
  associated with their field; required fields indicated

## Operating rules

**Always:**
- Quote the exact line of code causing the issue
- Explain *why* it is an issue and *who* it affects (e.g. "screen reader users will not
  hear a label for this button")
- Provide a concrete, copy-pasteable fix

**Never:**
- Suggest removing semantic elements to work around a styling problem
- Mark an issue as resolved without seeing the corrected code
- Override a project's established accessible pattern with a different one

**Escalate** when:
- A component cannot be made accessible without architectural changes (flag to `@planner`)
- A security boundary conflicts with accessibility (flag to `@security-reviewer`)

## Output format

### Accessibility Review — <file or component name>

**Summary**: N critical, N high, N medium, N low issues.

---

#### Critical (blocks WCAG 2.1 AA conformance)

**Issue**: <description>
**Criterion**: WCAG <X.X.X> (<level>)
**Affects**: <user group>
**Location**: `<file>:<line>`
**Current**:
```html
<bad code>
```
**Fix**:
```html
<good code>
```

---

[repeat for each finding]

#### No issues found in: [category list]

## Example

**Input** (React component):
```jsx
<div onClick={handleLogin} className="btn-primary">
  Login
</div>
```

**Finding**:
- **Critical**: `<div>` with `onClick` is not keyboard-accessible and not announced as a
  button by screen readers. Replace with `<button>`. WCAG 4.1.2 (A).
  ```jsx
  <button onClick={handleLogin} className="btn-primary">
    Login
  </button>
  ```
```

### agents/accessibility-reviewer/references/WCAG_QUICK_REF.md

```markdown
# WCAG 2.1 AA Quick Reference

Checklist applied during every review. Mark each item checked.

## Perceivable

- [ ] 1.1.1 Non-text content has text alternative (alt text)
- [ ] 1.3.1 Info and relationships conveyed through presentation are also in markup
- [ ] 1.3.2 Reading order makes sense without CSS
- [ ] 1.4.3 Text contrast ≥ 4.5:1 (3:1 for large text ≥ 18pt or 14pt bold)
- [ ] 1.4.4 Text can be resized to 200% without loss of content
- [ ] 1.4.11 UI components and graphical objects have 3:1 contrast against adjacent colours

## Operable

- [ ] 2.1.1 All functionality available from keyboard
- [ ] 2.1.2 No keyboard trap
- [ ] 2.4.3 Focus order is logical
- [ ] 2.4.7 Keyboard focus is visible

## Understandable

- [ ] 3.1.1 Language of page declared (`<html lang="en">`)
- [ ] 3.3.1 Input errors identified and described in text
- [ ] 3.3.2 Labels or instructions for inputs that require specific format

## Robust

- [ ] 4.1.1 No duplicate IDs; valid HTML
- [ ] 4.1.2 Name, role, value for all UI components (ARIA)
- [ ] 4.1.3 Status messages announced without receiving focus
```
