# How to Add an Agent Persona

This guide walks you through creating a new agent persona in agent-toolkit. Agent personas are specialist AI identities that can be invoked by name (e.g. `@accessibility-reviewer`) and operate with a focused set of tools, responsibilities, and constraints.

---

## 1. Agent vs. Skill: When to Add Which

Before creating an agent, confirm you need one rather than a skill.

| | Agent | Skill |
|---|---|---|
| **Invoked by** | `@mention` (e.g. `@code-reviewer`) | Slash command or natural language trigger |
| **Purpose** | Specialist *persona* — the AI becomes a focused expert | Specialist *procedure* — the AI follows a workflow |
| **Scope** | Long-lived interaction; can ask clarifying questions | Usually single-pass execution |
| **Examples** | `@code-reviewer`, `@security-reviewer`, `@planner` | `gh-fix-ci`, `planning`, `development-workflow` |

**Rule of thumb:**
- Add an **agent** when you want a persistent specialist that embodies expertise across many tasks.
- Add a **skill** when you want a repeatable procedure the AI executes step by step.

The same domain often has both: a `@tdd-guide` agent (the expert you talk to) and a `development-workflow` skill (the process it follows).

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
---
```

### Required frontmatter fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Kebab-case identifier, must match the directory name |
| `description` | string | Used by the AI to decide which agent to invoke |
| `tools` | string | Comma-separated list of tools the agent is allowed to use |

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

The validator checks:
- `AGENT.md` is present in every agent directory
- YAML frontmatter is valid
- Required fields (`name`, `description`, `tools`) are present
- `name` in frontmatter matches the directory name

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

---

## 7. PR Checklist

```markdown
## Agent Checklist
- [ ] `agents/<agent-name>/AGENT.md` created
- [ ] Frontmatter has `name`, `description`, and `tools`
- [ ] `name` in frontmatter matches directory name
- [ ] `./scripts/validate-agents.vsh` passes with no errors
- [ ] `distributions/products.yaml` updated if product membership changed
- [ ] `./scripts/generate-catalogs.vsh` was run (do **not** hand-edit `agent-catalog.yaml`)
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
