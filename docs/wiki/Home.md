> **Note:** Canonical documentation lives under [`docs/`](../). This wiki may lag.

# agent-toolkit Wiki

> Composable AI capabilities for every major coding assistant — one toolkit, any tool.

agent-toolkit is a modular collection of skills, agent personas, MCP configuration templates,
and loop engineering patterns designed to work across all major AI coding assistants. Instead of
maintaining separate prompt libraries for each tool, you keep one source of truth and deploy exactly
what each tool needs.

---

## What Is Included

| Component | Count | Description |
|-----------|-------|-------------|
| Skills | 77 | Portable capability definitions (`SKILL.md`) |
| Agent personas | 17 | Tool-agnostic specialist role definitions |
| Loop templates | 10 | Recurring agentic workflows across 3 tiers |
| Plugins | 3 | Claude Code and Cursor marketplace bundles (plus experimental complete) |
| Tool profiles | 7 | Claude Code, Cursor, OpenCode, Copilot, Windsurf, Pi, Muse Code |
| MCP templates | 7 | Ready-to-use Model Context Protocol configs |
| Solution packs | 7 | Curated bundles for common team setups |

---

## Navigation

### Getting Started

- [Installation](Installation) — V CLI channels (GitHub, Homebrew, AUR, PyPI launcher, npm)
- [Profiles](Profiles) — per-tool profile index (7 supported tools)

### Reference

- [Skills Reference](Skills-Reference) — catalog pointers (77 skills)
- [Agents Reference](Agents-Reference) — catalog pointers (17 personas)
- [Loop Engineering](Loop-Engineering) — loop YAML spec, all 10 templates, checkpointing, budget sizing, scheduling
- [MCP Setup](MCP-Setup) — MCP providers with env vars and per-tool configuration

### Marketplace

- [Plugin Marketplace](Plugin-Marketplace) — Claude Code and Cursor plugin installation, plugin structure, building extensions

### Contributing

- [Contributing Guide](Contributing) — dev setup, how to add skills, agents, and loops, PR process
- [FAQ](FAQ) — common questions answered

---

## Quick Install

The product is the **native V CLI**. Then `agent-toolkit install`.

```bash
brew tap ulises-jeremias/homebrew-tap && brew install agent-toolkit
# or: yay -S agent-toolkit-bin
# or: uv tool install 'agent-toolkit-cli>=1.11.0'
# or: npm i -g agent-toolkit-cli
# GitHub Release: https://github.com/ulises-jeremias/agent-toolkit/releases/latest

agent-toolkit install
agent-toolkit doctor
```

Claude Code marketplace plugins (skills/agents only — not the full CLI):

```text
/plugin marketplace add ulises-jeremias/agent-toolkit
/plugin install agent-toolkit-core@agent-toolkit
```

Full options: [Installation](Installation) → [`docs/INSTALLATION.md`](../INSTALLATION.md).

---

## What Can I Do in 5 Minutes?

### 1. Fix a failing CI run

After installing the Claude Code plugin:

```text
"fix CI"
```

The `gh-fix-ci` skill runs automatically: it fetches the failing check logs, identifies the root
cause, and proposes a minimal fix — or opens a draft PR if the change is straightforward.

### 2. Review a PR

```text
"review the current diff"
```

The `code-reviewer` agent inspects the diff, checks for quality, security, and correctness issues,
and outputs prioritized findings with copy-pasteable fixes.

### 3. Draft a bug report

```text
"write a bug report for the login redirect issue"
```

The `bug` skill generates a structured bug report with reproduction steps, expected vs. actual
behavior, and severity classification.

### 4. Plan a feature

```text
"break down the user profile feature into tasks"
```

The `planning` skill decomposes the feature into estimated work items with dependency ordering.

### 5. Start an OSS maintenance loop

```bash
# Initialize the OSS maintenance pack
cp ~/.agent-toolkit/packs/oss-maintenance/config.yaml ~/my-ecosystem.yaml
# Edit to add your repos, then:
agent-toolkit loop run oss-daily-briefing --pack ~/my-ecosystem.yaml
```

The `oss-daily-briefing` loop produces a daily read-only briefing across all configured repos —
new PRs, issues needing attention, and CI health on main.

---

## Repository Structure

```text
agent-toolkit/
├── skills/         # 77 skills
├── agents/         # 17 agent persona definitions
├── loops/          # 10 loop engineering templates
├── profiles/       # Per-tool configurations (7 tools)
├── mcp/templates/  # 7 MCP provider config stubs
├── plugins/        # Marketplace plugin bundles
├── packs/          # 7 solution packs
├── catalogs/       # skill-catalog.yaml, agent-catalog.yaml
├── schemas/        # JSON validation schemas
├── docs/           # Documentation and how-to guides
└── scripts/        # Install and validation scripts
```

---

## Supported Tools

| Tool | Plugin | npx | Manual |
|------|--------|-----|--------|
| Claude Code | Yes (recommended) | Yes | Yes |
| Cursor | Yes | Yes | Yes |
| OpenCode | No | Yes | Yes |
| GitHub Copilot | No | No | Yes |
| Windsurf | No | Yes | Yes |
| Pi Coding Agent | No | Yes | Yes |
| Muse Code | No | Yes | Yes |

---

## License

MIT — see [LICENSE](https://github.com/ulises-jeremias/agent-toolkit/blob/main/LICENSE) for details.
