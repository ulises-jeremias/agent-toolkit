# Frequently Asked Questions

---

## General

### Is this only for Claude Code?

No. agent-toolkit supports 6 AI coding assistants:

| Tool | Plugin | npx | Manual |
|------|--------|-----|--------|
| Claude Code | Yes (recommended) | Yes | Yes |
| Cursor | Yes | Yes | Yes |
| OpenCode | No | Yes | Yes |
| GitHub Copilot | No | No | Yes |
| Windsurf | No | Yes | Yes |
| Pi Coding Agent | No | Yes | Yes |

Skills use the `SKILL.md` frontmatter-only format from the Agent Skills spec, which is designed
to be tool-agnostic. Profiles in `profiles/<tool>/` adapt the shared skills to each tool's
native configuration format. See [Profiles](Profiles) for the per-tool guide.

---

### What is the difference between agent-toolkit and agentic-workstation?

They work at different layers of the stack:

| | agent-toolkit | agentic-workstation |
|---|---|---|
| **Layer** | Distribution — skills, agents, loops, profiles, MCP templates | Runtime — harness, runners, worker processes, CI integration |
| **What it provides** | Portable capability definitions and per-tool configs | Execution infrastructure for running loops and background jobs |
| **Self-sufficient?** | Yes — works standalone with any supported AI tool | Requires a host AI tool and optionally agent-toolkit for skills |
| **Installs to** | `~/.claude/`, `~/.cursor/`, etc. | `~/.local/share/agentic-workstation/` |

agent-toolkit is the **content layer**: the skills, agent personas, loop definitions, and MCP
templates that define what an AI can do. agentic-workstation is the **execution layer**: the
harness that runs loops on schedules, manages job queues, and provides a runner hierarchy.

You do not need agentic-workstation to use agent-toolkit. The two are designed to work well
together, but agent-toolkit is fully self-sufficient on its own.

---

### Do I need to install agentic-workstation?

No. agent-toolkit works standalone. You can install it and use it with any supported AI tool
without agentic-workstation.

agentic-workstation adds value if you want to:

- Run loops on automated schedules via a background worker process
- Manage job queues with priority and retry
- Use the `devcompanion queue` pattern for deferred background work
- Have a consistent runner hierarchy across multiple AI tools

If you just want skills, agents, MCP templates, and loop definitions — agent-toolkit alone is
sufficient. Use `systemd` or `launchd` for loop scheduling (see [Loop Engineering](Loop-Engineering)).

---

### Can I use this for client projects?

Yes. There are two recommended approaches:

**Option 1: Per-project install**

Install the profile for your AI tool at the project level. This keeps the toolkit scoped to
the project and makes it explicit for the whole team:

```bash
cd /path/to/client-project
mkdir -p .claude/agents
cp ~/.agent-toolkit/profiles/claude-code/CLAUDE.md .claude/CLAUDE.md
git add .claude/ && git commit -m "chore: add agent-toolkit dev companion profile"
```

**Option 2: L3 overlay (agentic-workstation)**

If using agentic-workstation, create a client-specific overlay config that references agent-toolkit
skills with client-specific overrides. This lets you customize skill behavior per engagement without
forking the toolkit.

**Important for client work:** Before running any loop that uses AI (especially with the
agentic-workstation runner), verify the LLM policy to ensure the client's API key is used — not
your personal key or a different provider. See the [Loop Engineering](Loop-Engineering) page for
the `llm-status` verification step.

---

## Skills and Agents

### How do loops differ from regular prompts?

Three key differences:

**State** — A regular prompt starts fresh every time. A loop writes `STATE.md` checkpoints
during execution so that if it is interrupted (budget exhausted, process killed), the next run
picks up where the previous run stopped rather than restarting from scratch.

**Budget** — Regular prompts run until the AI finishes, with no explicit ceiling. Loops have
`max_tokens`, `max_wall_seconds`, and `max_runs_per_day` limits. `budget_exhausted` is a normal,
expected exit condition — not an error.

**Safety gates** — Regular prompts have no explicit guardrails. Loops declare an explicit
`allowlist` of permitted actions and a `deny` list of forbidden actions. The prompt re-states
these constraints in natural language, and the schema enforces that both lists are present.

For most interactive tasks (one-off code review, fixing a bug, drafting a PR), a regular prompt
is the right tool. Loops are for recurring, scheduled work that needs to run reliably and safely
without human supervision on every run.

---

### What is the difference between a skill trigger and an agent trigger?

Both are natural-language phrases that match the capability to the task. The difference is in
what gets invoked:

- **Skill trigger** — matches a keyword or phrase and causes the AI to follow the skill's
  step-by-step procedure. Example: the phrase "fix CI" triggers the `gh-fix-ci` skill.
- **Agent trigger** — matches a keyword or phrase (or an explicit `@mention`) and causes the
  AI to adopt the agent persona for the session. Example: `@code-reviewer review this PR` invokes
  the `code-reviewer` agent, which then conducts its review according to its own internal operating
  rules.

Skills are procedures. Agents are personas.

---

### Can a skill be used with any tool, even if its compatibility matrix says "No"?

Yes, with caveats. A skill being `supported: false` for a tool means the structured loading
mechanism is not available — not that the skill's concepts are inapplicable.

You can always:

1. Open the `SKILL.md` file and read the instructions yourself
2. Paste the relevant sections into your AI tool's chat or system prompt
3. Have the AI follow the procedure manually

The `compatibility` field reflects whether the skill loads and executes correctly through the
tool's native skill-loading mechanism. Some skills rely on features (MCP, specific API calls)
that are only available in certain tools, which is why not all skills are universally supported.

---

### Why does workspace-knowledge-sync only work in Claude Code and OpenCode?

The `workspace-knowledge-sync` skill requires a `knowledge/` directory at the workspace root
with a specific structure for storing learnings and todos across sessions. This pattern is specific
to Claude Code's workspace model (where `~/.ai-workspace/` acts as a persistent session context)
and to OpenCode's similar session persistence model.

Cursor, Windsurf, Copilot, and Pi do not have an equivalent persistent cross-session workspace
model, so the skill has no meaningful effect in those tools.

---

## MCP

### Is my API key safe when using MCP templates?

Yes, provided you follow the security guidance:

- The template files in `mcp/templates/` use `${ENV_VAR}` placeholders — they contain no real credentials.
- Your filled-in config (with real tokens) lives in `~/.config/agent-toolkit/` or your tool's
  config directory — never committed to any repository.
- The `validate-skills.sh` script scans for common token patterns and will warn if it detects
  what looks like a real credential in any tracked file.

The risk comes from accidentally committing a filled-in config. Mitigate this by:

1. Never editing templates in place — always copy to an untracked config location first
2. Adding `*mcp-config*.json` to your global `.gitignore`
3. Using fine-grained tokens with the minimum required scopes (limits blast radius if a token
   is compromised)
4. Rotating tokens periodically

---

### Can I have MCP configured globally (affecting all projects) or per-project?

Both:

**Claude Code global MCP:** `~/.claude/claude_desktop_config.json` — applies to all Claude Code
sessions on the machine.

**Claude Code per-project MCP:** `.claude/mcp.json` in the project root — applies only when
Claude Code is running in that project directory.

**Cursor:** MCP is configured in Cursor Settings → MCP (global). Per-project override is not
currently supported in Cursor's MCP UI.

For most users, global MCP configuration is sufficient. Per-project MCP is useful when different
projects use different GitHub tokens (e.g. personal projects vs. work projects) or different
Linear workspaces.

---

## Profiles and Tools

### How do I add a new tool profile?

See the [Profiles](Profiles) wiki page and the
[`docs/HOW_TO_ADD_PROFILE.md`](https://github.com/ulises-jeremias/agent-toolkit/blob/main/docs/HOW_TO_ADD_PROFILE.md)
guide in the repository.

In summary:

1. Create `profiles/<new-tool>/` directory
2. Add tool-specific config files using that tool's native format
3. Add the tool to the compatibility matrix in each relevant skill's `skill.json`
4. Document the install path in `docs/PROFILES.md` and `docs/INSTALLATION.md`
5. Add detection and copy logic to `scripts/install.sh`
6. Open a PR

---

### Can I run agent-toolkit in CI?

Yes. Common CI uses:

- **Validate skill definitions:** `bash scripts/validate-skills.sh` — exits non-zero on failure,
  human-readable error messages. Run in your repo's CI on PRs to ensure skill definitions remain valid.
- **Validate loop templates:** `bash scripts/validate-loops.sh` — same pattern.
- **Skeleton mode loop runs:** `agent-toolkit loop run <name> --no-llm` — runs the loop scaffolding
  without invoking any AI. Useful for smoke-testing loop YAML parsing in CI.

---

### My AI tool is not in the supported list. Can I still use agent-toolkit?

Probably yes, with manual setup:

1. Clone the repository: `git clone https://github.com/ulises-jeremias/agent-toolkit ~/.agent-toolkit`
2. Find the skill domains relevant to your work
3. Copy or paste `SKILL.md` content from those skills into your tool's system prompt or instruction
   file
4. Use the loop templates by running them manually with whatever AI CLI your tool provides

Skills are plain Markdown with YAML frontmatter — they work with any tool that accepts text
instructions, even if the structured loading mechanism is not available.

If your tool has a large user base and a structured skill-loading mechanism, consider contributing
a profile for it. See [Contributing](Contributing).

---

### How do I stay up to date with new skills and agents?

```bash
cd ~/.agent-toolkit
git pull
bash scripts/install.sh  # re-deploy updated profiles
```

Or with forced overwrite:

```bash
bash scripts/install.sh --force
```

Subscribe to
[GitHub Releases](https://github.com/ulises-jeremias/agent-toolkit/releases) for release notes.
The [CHANGELOG.md](https://github.com/ulises-jeremias/agent-toolkit/blob/main/CHANGELOG.md)
lists all changes by version.

---

### Why are there three OSS loops instead of one?

The three OSS loops (`oss-daily-briefing`, `oss-triage`, `oss-pr-monitor`) are split by risk tier:

- `oss-daily-briefing` (L1) — read-only. Safe to run from day one with no risk.
- `oss-triage` (L1 + limited writes) — applies labels and posts comments. Requires a week of clean
  briefing runs to validate the AI's judgment before enabling.
- `oss-pr-monitor` (L2) — merges Dependabot PRs. The highest-autonomy loop. Requires a week of
  stable triage runs before enabling.

This graduated structure lets you build confidence incrementally. You observe behavior at each tier
before granting the AI permission to act at the next tier. This is the core philosophy of the L1/L2/L3
system.

---

### What happens when a loop hits the budget ceiling?

`budget_exhausted` is a normal, expected exit condition — not an error. When a loop hits
`max_tokens` or `max_wall_seconds`:

1. The loop writes the current `STATE.md` checkpoint (if `resumable: true`)
2. The loop writes a partial `report.md` with what was processed so far
3. The loop exits with `last_run_status: partial (budget_exhausted)` in STATE.md
4. The next scheduled run reads STATE.md and picks up from `last_processed_repo`

You do not need to do anything — the loop self-heals on the next run. If a loop consistently
exhausts its budget, consider increasing `max_tokens` using the
[budget sizing formula](Loop-Engineering#budget-sizing) or splitting your ecosystem into two packs.
