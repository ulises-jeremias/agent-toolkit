# Agents Reference

Agent personas are specialist AI identities that can be invoked by name and operate with a
focused set of tools, responsibilities, and constraints. There are 16 agent personas in
agent-toolkit.

---

## Agent vs. Skill: What Is the Difference?

Both agents and skills extend what an AI assistant can do, but they serve different purposes:

| | Agent | Skill |
|---|---|---|
| **Invoked by** | `@mention` (e.g. `@code-reviewer`) | Slash command or natural language trigger |
| **Purpose** | Specialist *persona* — the AI becomes a focused expert | Specialist *procedure* — the AI follows a workflow |
| **Scope** | Long-lived interaction; can ask clarifying questions | Usually single-pass execution |
| **Examples** | `@code-reviewer`, `@security-reviewer`, `@planner` | `gh-fix-ci`, `planning`, `development-workflow` |

**Rule of thumb:**

- Use an **agent** when you want a persistent specialist that embodies expertise across many tasks.
  You are having a conversation with a role.
- Use a **skill** when you want a repeatable procedure the AI executes step by step.
  You are running a defined workflow.

The same domain often has both: a `@tdd-guide` agent (the expert you talk to) and a
`development-workflow` skill (the process it follows).

---

## AGENT.md Frontmatter Spec

Every agent file begins with YAML frontmatter. Validated by `scripts/validate-agents.py`.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Kebab-case identifier. Must match the directory name and be usable as an `@mention` |
| `description` | string | Yes | Used by the AI to select which agent to invoke. Include trigger keywords |
| `tools` | string | Yes | Comma-separated list of tools the agent is allowed to use |

**Tools available to agents:**

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

Most review agents only need `Read, Grep, Glob, Bash`. Only grant `Write` or `Edit` to agents
that explicitly need to mutate files.

---

## How to Invoke Agents

### Claude Code

Invoke agents using `@mention` in your message:

```text
@code-reviewer review this PR
@architect design a service for X
@planner break down this feature
```

Agents are defined in `~/.claude/agents/` (global) or `.claude/agents/` (project-level). Claude
Code loads all `.md` files from these directories at session start.

### OpenCode

Agents are available in `~/.config/opencode/agents/`. Invoke them by name in OpenCode's agent
selector or via mention in the chat interface.

### Cursor

Cursor does not natively support agent personas. Use the domain `.mdc` rule files instead —
they encode the agent expertise as rules applied to all Cursor interactions. See [Profiles](Profiles)
for Cursor setup.

### Other tools

For Windsurf, Pi, and GitHub Copilot, agent personas are encoded in the profile's instruction
files rather than as separately invokable entities. The expertise is baked into the system prompt.

---

## All 16 Agents

### Orchestration Domain

#### architect

**Role:** System design and architecture decisions

**Description:** Software architecture and system design specialist. Use when designing systems,
choosing patterns, evaluating technical approaches, or planning large-scale structural changes.

**Triggers:**

- System or service design task
- Architecture decision needed
- Evaluate technical tradeoffs
- Design distributed system component
- Choose between competing implementation strategies

**Tools:** `Read, Grep, Glob, Bash`

**Handoffs:** `planner` (for task breakdown), `code-reviewer` (for implementation review),
`security-reviewer` (for security implications)

**Example prompt:**

```text
@architect design a caching layer for our API that handles 10k rps
```

The architect will read the existing codebase, propose 2-3 options with explicit tradeoffs,
recommend one approach with rationale, identify risks, and outline concrete next steps.

---

#### assistant

**Role:** Primary orchestrator and fallback

**Description:** General-purpose AI assistant. Default entry point when no specialized agent is
obvious. Handles repo inspection, convention verification, and multi-agent coordination.

**Triggers:**

- Default entry point when no specialized agent is obvious
- Repo inspection and convention verification
- Multi-agent coordination across domains
- Ambiguous or cross-cutting tasks

**Tools:** `Read, Grep, Glob, Bash, Write, Edit`

**Handoffs:** `architect`, `planner`, `code-reviewer`, `security-reviewer`, `docs-lookup`,
`tech-assistant`

**Example prompt:**

```text
@assistant inspect this repo and tell me the conventions
```

---

#### planner

**Role:** Feature and iteration planning

**Description:** Planning specialist for feature breakdown, sprint capacity, estimation, and
dependency mapping.

**Triggers:**

- Feature breakdown into tasks or stories
- Sprint or iteration capacity planning
- Estimation and story-point assignment
- Dependency mapping for a delivery unit

**Tools:** `Read, Grep, Glob, Bash`

**Handoffs:** `code-reviewer`, `architect`

**Example prompt:**

```text
@planner break down the payment integration feature into stories with estimates
```

---

#### client-workflow-bootstrap

**Role:** Client project onboarding

**Description:** Generates client-specific workflow skill pairs for new client project onboarding.
Creates a delivery workflow tailored to the client's stack and conventions.

**Triggers:**

- Onboard a new client project
- Bootstrap workflow skill pair for a client
- Generate client-specific delivery conventions

**Tools:** `Read, Grep, Glob, Bash, Write`

**Handoffs:** `assistant`, `planner`

---

### Review Domain

#### code-reviewer

**Role:** Code quality and correctness review

**Description:** Expert code review specialist. Proactively reviews code for quality, security,
and maintainability. Use immediately after writing or modifying any significant code.

**Triggers:**

- Review a diff or PR for correctness
- Identify dead code, duplication, or complexity
- Validate implementation against requirements
- Post-implementation quality gate

**Tools:** `Read, Grep, Glob, Bash`

**Handoffs:** None (terminal — posts findings, does not delegate)

**Example prompt:**

```text
@code-reviewer review the current diff
```

Output format:

```text
Critical (block merge): ...
Warning (should fix): ...
Suggestion (consider): ...
```

---

#### database-reviewer

**Role:** Database schema and query review

**Description:** Database specialist for schema migrations, SQL query performance, index design,
and Supabase RLS policy audits.

**Triggers:**

- Review database schema migration
- Evaluate SQL query performance
- PostgreSQL index or constraint review
- Supabase RLS policy audit

**Tools:** `Read, Grep, Glob, Bash`

**Handoffs:** None

**Example prompt:**

```text
@database-reviewer review this migration adding the orders table
```

---

#### performance-optimizer

**Role:** Performance analysis and recommendations

**Description:** Performance specialist for profiling slow code paths, identifying memory and CPU
bottlenecks, and benchmarking competing implementations.

**Triggers:**

- Profile slow code path or query
- Identify memory or CPU bottlenecks
- Benchmark comparison between implementations
- Performance regression investigation

**Tools:** `Read, Grep, Glob, Bash`

**Handoffs:** None

**Example prompt:**

```text
@performance-optimizer the checkout endpoint is slow — find the bottleneck
```

---

#### security-reviewer

**Role:** Security vulnerability audit

**Description:** Security specialist for vulnerability audits, secret detection, injection
prevention, and dependency vulnerability assessment. Covers OWASP and CVE-related patterns.

**Triggers:**

- Security audit of code or configuration
- Check for secrets, injections, or insecure patterns
- OWASP or CVE-related review
- Dependency vulnerability assessment

**Tools:** `Read, Grep, Glob, Bash`

**Handoffs:** None

**Example prompt:**

```text
@security-reviewer audit the authentication module
```

---

#### typescript-reviewer

**Role:** TypeScript type safety review

**Description:** TypeScript specialist for type safety audits, strict mode compliance, generics
review, and JS-to-TS migration assessment.

**Triggers:**

- TypeScript or JavaScript type audit
- Strict mode compliance check
- Type inference or generics review
- JS-to-TS migration review

**Tools:** `Read, Grep, Glob, Bash`

**Handoffs:** None

**Example prompt:**

```text
@typescript-reviewer check the new API client types for correctness
```

---

### Design Domain

#### tech-assistant

**Role:** Technical procedures and references

**Description:** Technical guidance specialist for questions about internal technical procedures,
architecture references, infrastructure, and internal runbooks.

**Triggers:**

- Questions about internal technical procedures
- Architecture or infrastructure references
- Career development or training plans
- Lookup of internal runbooks

**Tools:** `Read, Grep, Glob, Bash, WebSearch, WebFetch`

**Handoffs:** `architect`, `docs-lookup`, `reference-lookup`

---

### Testing Domain

#### e2e-runner

**Role:** Playwright end-to-end test execution

**Description:** End-to-end testing specialist. Runs and writes Playwright tests, reproduces UI
regressions with automation, and validates user flows against live environments.

**Triggers:**

- Run or write Playwright end-to-end tests
- Reproduce a UI regression with automation
- Validate user flows against a live environment
- Set up Playwright test suite from scratch

**Tools:** `Read, Grep, Glob, Bash, Write, Edit`

**Handoffs:** None

**Example prompt:**

```text
@e2e-runner write a test for the checkout flow
```

---

#### tdd-guide

**Role:** Test-driven development coach

**Description:** TDD specialist. Guides the red-green-refactor cycle, analyzes coverage gaps, and
scaffolds unit and integration tests.

**Triggers:**

- Write tests before implementation
- TDD cycle: red → green → refactor
- Coverage gap analysis
- Unit or integration test scaffolding

**Tools:** `Read, Grep, Glob, Bash, Write, Edit`

**Handoffs:** None

**Example prompt:**

```text
@tdd-guide help me TDD the new email validation function
```

---

### Ops Domain

#### build-error-resolver

**Role:** Build and type error triage

**Description:** Build failure specialist. Diagnoses compilation errors, type errors, CI lint
failures, and package install errors.

**Triggers:**

- Build fails with compilation or type errors
- CI fails on lint or type check step
- npm, pnpm, or yarn install errors
- TypeScript or bundler error diagnosis

**Tools:** `Read, Grep, Glob, Bash`

**Handoffs:** None

**Example prompt:**

```text
@build-error-resolver the TypeScript build is failing — fix it
```

---

#### docs-lookup

**Role:** Documentation and API reference search

**Description:** Documentation specialist. Fetches current library or framework docs, API syntax,
version migration guides, and SDK configuration references.

**Triggers:**

- Fetch current library or framework docs
- API usage syntax or version migration
- SDK setup or configuration reference
- "How do I use X in Y version?"

**Tools:** `Read, Grep, Glob, Bash, WebSearch, WebFetch`

**Handoffs:** None

**Example prompt:**

```text
@docs-lookup how do I configure streaming in the Anthropic SDK v0.26?
```

---

#### reference-lookup

**Role:** Public example and pattern search

**Description:** Pattern search specialist. Finds real-world implementation examples, community
patterns, and open-source references for a given problem.

**Triggers:**

- Find real-world implementation examples
- Locate community patterns for a problem
- Compare approaches across open-source projects
- Validate a design against public references

**Tools:** `Read, Grep, Glob, Bash, WebSearch, WebFetch`

**Handoffs:** None

---

#### refactor-cleaner

**Role:** Dead code removal and simplification

**Description:** Refactoring specialist. Removes dead and unused code, simplifies complex
functions, consolidates duplicate logic, and cleans up after feature flag removal.

**Triggers:**

- Remove dead or unused code
- Simplify overly complex function or module
- Consolidate duplicate logic
- Cleanup after feature flag removal

**Tools:** `Read, Grep, Glob, Bash, Write, Edit`

**Handoffs:** None

**Example prompt:**

```text
@refactor-cleaner clean up the legacy payment code — the old Stripe v2 integration is no longer used
```

---

## Agent Catalog

The full agent routing table lives in [`catalogs/agent-catalog.yaml`](https://github.com/ulises-jeremias/agent-toolkit/blob/main/catalogs/agent-catalog.yaml).
This file is the source of truth for which agent handles which task and which agents an agent
delegates to after completing its work.

---

## Adding a New Agent

See [Contributing](Contributing) for the full walkthrough, including the PR checklist and a
complete example (`accessibility-reviewer`).

Quick summary:

1. Create `agents/<agent-name>/AGENT.md` with required frontmatter (`name`, `description`, `tools`)
2. Write the agent body: when invoked, domain expertise, operating rules, output format
3. Run `python3 scripts/validate-agents.py`
4. Register in `catalogs/agent-catalog.yaml`
5. Run `python3 scripts/gen-surfaces.py --check` to verify plugin sync
6. Open a PR
