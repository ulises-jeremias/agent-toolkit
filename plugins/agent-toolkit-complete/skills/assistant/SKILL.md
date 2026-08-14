---
name: assistant
description: Assistant — on any repo, scan README→docs→AGENTS→CONTRIBUTING→PR templates→task runners→devcontainer→CI→configs
  before code; cite sources; prefer AGENTS.md for agent behavior; portable across Cursor/Copilot/Claude;
  use agent-toolkit CLI when needed.
origin:
  type: first-party
metadata:
  author: ulises-jeremias
  version: '2.1'
---
# Assistant

Organizational companion for anyone building **for ** in **any** repository (client, internal, or ``). It tells the agent **what to open first**, **why**, and **how to resolve conflicts**—without copying content that already lives in the project.

**Orchestration**

This skill is the **default orchestrator and fallback** for agent work. **Read** `references/ORCHESTRATION.md` for routing (workflows, tool skills, delegation phrasing). Use **`~/.local/share//skills/skill-catalog.yaml`** (bundled next to skills) for **domain**, **WHAT vs HOW**, **triggers**, and **`depends_on`** per skill. **Workflow skills** define phases and gates only; **tool skills** own CLI procedures—do not inline HOW steps inside workflow skills.

**Hard rules**

- Derive answers from **files in the repo** and **machine-local agent-toolkit baseline (`~/.local/share/agent-toolkit/`). **Cite paths** when you recommend workflows.
- **Do not** paraphrase long sections of README/docs into chat when a link or path is enough; **do not** invent scripts or flags that are not documented or discoverable.
- **AGENTS.md** (when present) is the **primary contract for agent behavior** in that repo; see [Agent instruction map](#agent-instruction-map) for tie-breakers with tool-specific files.

Extended path hints: `references/REPO_INSPECTION.md`. Orchestration: `references/ORCHESTRATION.md`. Starter `AGENTS.md` for new projects: `references/AGENTS_TEMPLATE.md` (and chezmoi `AGENTS.project.md.tmpl` in the baseline templates).

---

## Expected behavior

1. **On entering a task in a repo**, spend a short **discovery pass**: follow [Repository inspection order](#repository-inspection-order) before editing large areas of code.
2. **Classify** documentation you find (see [Documentation taxonomy](#documentation-taxonomy)) so you do not apply contributor-only rules to end-user docs or vice versa.
3. **Prefer official automation** from `Makefile` / `justfile` / `package.json` / CI over ad-hoc commands.
4. **When advising**, name the **source file** (“per `CONTRIBUTING.md`…”, “`.github/workflows/ci.yml` runs…”).
5. **If something is missing** (no tests doc, no AGENTS, conflicting instructions), **say so** and suggest a concrete addition—optionally offer to draft from `references/AGENTS_TEMPLATE.md`.
6. **Stay portable**: avoid recommending workflows that only work in one IDE unless the repo is explicitly single-tool.

---

## Repository inspection order

Use this **sequence** for the **opened repository root** (or the **subpackage root** you are changing in a monorepo). Skips are fine if a path does not exist—document what you skipped.

| Step | Where | What to extract |
| --- | --- | --- |
| **1** | `README.md` (root; then local README in the package you touch) | Purpose, how to run locally, stack, basic commands, high-level layout |
| **2** | `docs/`, `doc/`, `documentation/`, or project wiki mirror | Architecture, domain flows, conventions, ADRs, operational runbooks |
| **3** | `AGENTS.md` (root; if missing, `docs/AGENTS.md`) | Agent-specific rules, restrictions, repo-specific workflows |
| **4** | `CONTRIBUTING.md` (or `docs/CONTRIBUTING.md`) | Branch/commit/PR norms, quality bar, review process |
| **5** | PR templates: `.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, `.github/PULL_REQUEST_TEMPLATE/*` | Expected PR content, checklists, Definition of Done |
| **6** | `Makefile`, `justfile`, `package.json` `scripts`, `Taskfile.yml`, `mise.toml`, `pyproject.toml` scripts | **Official** build / test / lint / dev commands |
| **7** | `.devcontainer/devcontainer.json`, `compose.yaml` / `docker-compose.yml`, `Dockerfile` | How the team expects the dev environment to run |
| **8** | `.github/workflows/*`, `.gitlab-ci.yml`, `Jenkinsfile`, etc. | Mandatory checks, test matrix, deploy vs PR gates |
| **9** | Config: `tsconfig`, ESLint/Prettier/Biome, Ruff/mypy, Jest/Vitest/Playwright, etc. | Implicit style and testing conventions |
| **10** | Source tree | Implementation **after** steps 1–9 give context |

**Monorepos:** run the table for the **root** first, then repeat for the **specific package/service** directory if it has its own README, `package.json`, or CI job names that differ.

---

## Agent instruction map

These files shape **how the assistant should behave**. Discover them with **Glob**, then **Read**.

| Kind | Typical paths | Role |
| --- | --- | --- |
| **Portable agent contract** | `AGENTS.md` | **Highest priority for agent behavior** in this repo when present |
| **Cursor** | `.cursor/rules/**`, `.cursorrules` | IDE-specific; must not silently override AGENTS without acknowledgment |
| **Claude / Claude Code** | `CLAUDE.md`, `.claude/**` | Tool-specific project memory |
| **Copilot** | `.github/copilot-instructions.md`, documented Copilot instruction paths | Microsoft/GitHub-specific |
| **Gemini / Cloud Code / other** | `GEMINI.md`, vendor “cloud” or IDE instruction paths | Tool-specific; keep thin if `AGENTS.md` exists |

**If `AGENTS.md` exists:** treat it as the **single portable source of truth** for agent guardrails. Tool files should **align** with it; if they diverge, **surface the conflict** to the user and default to **AGENTS.md** unless the user says otherwise.

**If `AGENTS.md` is missing** but `.cursor/rules` or `CLAUDE.md` exist: follow those **and** suggest adding a root `AGENTS.md` that links or summarizes them for **portability** (Cursor, Copilot, Claude Code, Cloud Code, etc.).

**If only cloud / vendor markdown exists** (e.g. single-vendor “cloud” instructions): recommend evaluating **`AGENTS.md`** plus short tool stubs so the same rules travel across tools.

---

## Conflict resolution heuristics

| Situation | Resolution |
| --- | --- | --- |
| README says “run `npm start`”, `package.json` has no `start` | Trust **`package.json`**; note README drift |
| `AGENTS.md` vs `CONTRIBUTING.md` on process | **CONTRIBUTING** for human Git flow; **AGENTS** for what the **agent** may automate or touch |
| `AGENTS.md` vs `.cursor/rules` | **AGENTS.md** wins for stated agent behavior; flag contradiction |
| Local package README vs root README | **Local** for that package’s commands; **root** for global architecture |
| Docs vs code | **Docs** describe intent; if code disagrees, **report mismatch** instead of guessing which is “right” |
| CI does not run a script the README claims is mandatory | **CI config** is authoritative for merge gates; suggest doc fix |

---

## Anti-duplication and citation

- **Summarize** README/docs in your own words only when needed for the task; otherwise **point** to the file and section.
- **Never** paste entire policy documents into replies; extract **actionable** bullets and cite the path.
- When suggesting a new rule, **check** it does not duplicate `CONTRIBUTING.md` or `AGENTS.md`.
- Prefer **one** canonical place per concern (e.g. “all PR rules in template + CONTRIBUTING”).

---

## Documentation taxonomy

Use this to choose tone and strictness:

| Type | Examples | Use for |
| --- | --- | --- |
| **General / product** | Root README, user guides | What the product is, how to run it |
| **Contributors** | CONTRIBUTING, PR template, code review guide | Branches, commits, review, quality |
| **Agents** | AGENTS.md, tool instruction files | What assistants may or must not do |
| **Operational / technical** | Runbooks, ADRs, architecture under `docs/` | Deploy, incidents, technical decisions |

---

## Documentation gap signals

Flag gaps **explicitly** when you notice:

- No way to run tests or lint from documented commands.
- README references scripts that do not exist.
- CI enforces checks not mentioned for contributors.
- Multiple conflicting instruction files with no hierarchy.
- Sensitive operations (migrations, prod) undocumented.

Offer **small, copy-ready** fixes (e.g. a minimal `AGENTS.md` from `references/AGENTS_TEMPLATE.md`).

---

## workstation baseline (optional layer)

When the open repo **is** (or includes) `` / chezmoi `home/`:

- Read repo root **`AGENTS.md`**, **`docs/*.md`**, **`home/.chezmoidata/*`**, **`home/.chezmoiscripts/*.tmpl`**, **`home/dot_local/share//.chezmoiexternal.toml.tmpl`** as needed.
- For **`agent-toolkit` commands**, run `agent-toolkit --help`.

On **any** machine with the baseline applied:

- **`~/.local/share//`** — bundled skills, templates, MCP examples, `skills-registry.yaml`.
- **`skills list`**, **`doctor`**, **`loadenv`** — operational discovery.

### New Developer Onboarding

When a developer asks about **setup**, **getting started**, or **validation**:

1. **First-time setup** (cite `docs/wiki/TECHNICAL_QUICKSTART.md`):
   ```bash
   git clone git@github.com:ulises-jeremias/.git
   cd 
   chezmoi init --source=. -c ~/.config/chezmoi/.toml
   chezmoi apply --source=. -c ~/.config/chezmoi/.toml --dry-run
   chezmoi apply --source=. -c ~/.config/chezmoi/.toml
   ```

2. **Post-setup validation**:
   ```bash
   doctor
   ```
   Expected: `result: COMPLIANT`

3. **AI tools verification**:
   ```bash
   opencode --version  # or claude --version, etc.
   ls ~/.config/opencode/skills/
   ```

4. **If issues found**: Run `doctor` and address failures. For persistent issues, escalate via `update-check` and contact #tech-support.

### Helpful Commands for Developers

| Task | Command |
| --- | --- |
| Validate setup | `doctor` |
| Check updates | `update-check` |
| Update workstation | `chezmoi update && chezmoi apply --source=. -c ~/.config/chezmoi/.toml` |
| List AI skills | `skills list` |
| Sync skills | `skills sync` |
| Health check | **`triage`** (runs **`doctor`**, layout checks) |

### Where to route next (bundled HOW skills)

Use **`skill-catalog.yaml`** next to bundled skills for domains, triggers and **`depends_on`**. Prefer **one workflow driver** per task (**dev-companion** + **workflow-generic-project** for generic delivery).

| Area | Skill(s) | Notes |
| --- | --- | --- |
| GitHub PR review threads | **`gh-address-comments`** | Current-branch PR; pairs with **`github-cli-workflow`** for push/PR updates |
| GitHub Actions failures | **`gh-fix-ci`** | Fetch logs + snippet; plan before coding; pairs with **`planning`** |
| Draft PR / MR | **`github-cli-workflow`**, **`gitlab-cli-workflow`** | After **`output-handshake`** / **`pr-fallback`** when needed |
| Linear | **`linear`** | Linear MCP (OAuth); issues, cycles, docs |
| Figma | **`figma`** (entry), **`figma-implement-design`**, **`figma-code-connect-components`**, **`figma-create-design-system-rules`**, **`figma-create-new-file`** | MCP templates under `~/.local/share//mcp/figma/` |
| Figma design | **`figma`** / **`figma-implement-design`** | Design-to-code via Figma MCP; use **`figma-create-design-system-rules`** for system rules |
| Playwright | **`playwright-cli`** | CLI browser automation from the shell |
| Playwright **test** specs | **`e2e-runner`** | Not the same as **`playwright-cli`** |
| Jupyter notebooks | **`jupyter-notebook`** | Scaffold via **`newnotebook`** |
| Workstation health | **`triage`** | **`doctor`**, **`doctor --issue`** |
| Slack | **`slack-cli`**, **`slack-assistant`** | App CLI vs workspace chat |
| Tickets (external packs) | **`clickup-cli`**, **jira-***, **confluence-*** | As installed via registry / chezmoiexternal |
| Data | **`dbt-validation`**, **`snowflake-validation`** | Read-only validation patterns |

Client/account overlays live in the workspace (`~/.ai-workspace/packs/` + `knowledge/`) and should be loaded when triggered.

For AI agent assistance, invoke agents using **@mention** in your message (NOT the Task tool): **@planner** (feature planning), **@code-reviewer** (code review), **@security-reviewer** (security), **@tdd-guide** (TDD workflow), **@reference-lookup** (examples from public examples). Agents are defined in `~/.config/opencode/agents/` — they are NOT skills and must NOT be loaded via the skill tool.

---

## Organization playbooks

Client delivery workflows and the skill catalog live under **`~/.local/share//skills/`**. **Read** what is installed; do not invent URLs.

---

## Safety

- No secrets in repos; use env patterns documented for the project and `env.d` where applicable.
- Destructive or prod-affecting steps require **explicit** human confirmation unless AGENTS.md clearly authorizes them.
