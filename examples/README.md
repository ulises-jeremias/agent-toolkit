# Examples

This directory contains self-contained, real-world examples showing how to use agent-toolkit in specific scenarios. Each example includes all configuration, commands, and expected output needed to reproduce the setup.

---

## Examples

### oss-maintenance

**Setting up the OSS maintenance pack for a multi-repo GitHub presence.**

Covers: configuring the OSS ecosystem pack, running the first loop at L1, reading the daily briefing report, graduating to L2 for automated triage, and estimating monthly token costs at 10/20/40-repo scale.

Best for: maintainers of open source projects with multiple repositories who want automated issue triage, PR monitoring, and daily briefings without manual checks.

Path: `examples/oss-maintenance/`

---

### project-onboarding

**Adding agent-toolkit to an existing project as a new team member.**

Covers: installing the Claude Code profile, adding Cursor rules, committing `copilot-instructions.md`, and verifying the setup with `doctor.sh`.

Best for: engineers joining a project that uses agent-toolkit, or project leads who want to onboard their team onto the toolkit's agents and skills.

Path: `examples/project-onboarding/`

---

## How to Use These Examples

Each example directory contains its own `README.md` with:

1. **Prerequisites** — what you need installed before starting
2. **Configuration** — what to edit in the toolkit files
3. **Step-by-step commands** — copy-paste ready
4. **Expected output** — what success looks like
5. **Troubleshooting** — common failure modes and fixes

Start with `oss-maintenance` if you are setting up automation for the first time. Start with `project-onboarding` if you are adding toolkit support to an existing team workflow.

---

## Contributing an Example

Examples live next to the code they demonstrate. A good example:

- Solves a real problem that comes up repeatedly
- Is self-contained — a reader should not need to read other examples first
- Shows realistic configuration, not just the happy path
- Includes cost estimates when the example involves token-consuming loops

To add an example: create `examples/<name>/README.md` and open a PR. No code files are required — examples are documentation-first.
