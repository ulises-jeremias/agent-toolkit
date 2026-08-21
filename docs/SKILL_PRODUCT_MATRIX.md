# Skill → Product → Target Membership Matrix

> Generated from `distributions/products.yaml` — do not hand-edit. Run `./scripts/generate-skill-matrix.vsh` to regenerate, or `./scripts/generate-skill-matrix.vsh --check` in CI.

_Generated from 4 products × 84 skills × 17 agents._

## Products and targets

| Product | Stability | Targets | Skills | Agents |
|---------|-----------|---------|--------|--------|
| `agent-toolkit-core` | stable | claude-code, cursor, requires, security | 6 | 1 |
| `agent-toolkit-agents` | stable | claude-code, cursor | 0 | 17 |
| `agent-toolkit-forge` | stable | claude-code, cursor | 7 | 0 |
| `agent-toolkit-complete` | experimental | — | 84 | 0 |

## Skills → Products

| Skill | Products | Targets (via products) |
|-------|----------|------------------------|
| `accessibility/review` | `agent-toolkit-complete` | — |
| `agentic-security/mcp-audit` | `agent-toolkit-complete` | — |
| `agentic-security/owasp-agentic-review` | `agent-toolkit-complete` | — |
| `agentic-security/supply-chain-audit` | `agent-toolkit-complete` | — |
| `agentic-security/threat-modeling` | `agent-toolkit-complete` | — |
| `architecture/c4-model` | `agent-toolkit-complete` | — |
| `cloud/aws-well-architected-review` | `agent-toolkit-complete` | — |
| `cloud/cloud-design-patterns` | `agent-toolkit-complete` | — |
| `core/assistant` | `agent-toolkit-complete`, `agent-toolkit-core` | claude-code, cursor, requires, security |
| `core/dev-companion` | `agent-toolkit-complete`, `agent-toolkit-core` | claude-code, cursor, requires, security |
| `core/onboarding` | `agent-toolkit-complete`, `agent-toolkit-core` | claude-code, cursor, requires, security |
| `core/output-handshake` | `agent-toolkit-complete`, `agent-toolkit-core` | claude-code, cursor, requires, security |
| `core/pr-fallback` | `agent-toolkit-complete`, `agent-toolkit-core` | claude-code, cursor, requires, security |
| `core/project` | `agent-toolkit-complete` | — |
| `core/workspace` | `agent-toolkit-complete` | — |
| `core/workspace-knowledge-sync` | `agent-toolkit-complete`, `agent-toolkit-core` | claude-code, cursor, requires, security |
| `data/dbt-validation` | `agent-toolkit-complete` | — |
| `data/snowflake-validation` | `agent-toolkit-complete` | — |
| `delivery/adr` | `agent-toolkit-complete` | — |
| `delivery/agreement` | `agent-toolkit-complete` | — |
| `delivery/bug` | `agent-toolkit-complete` | — |
| `delivery/decision-log` | `agent-toolkit-complete` | — |
| `delivery/development-workflow` | `agent-toolkit-complete` | — |
| `delivery/epic` | `agent-toolkit-complete` | — |
| `delivery/incident` | `agent-toolkit-complete` | — |
| `delivery/management-unit-assessment` | `agent-toolkit-complete` | — |
| `delivery/meeting-minutes` | `agent-toolkit-complete` | — |
| `delivery/planning` | `agent-toolkit-complete` | — |
| `delivery/prd` | `agent-toolkit-complete` | — |
| `delivery/project-assessment` | `agent-toolkit-complete` | — |
| `delivery/project-assessment-evidence` | `agent-toolkit-complete` | — |
| `delivery/spike` | `agent-toolkit-complete` | — |
| `delivery/task` | `agent-toolkit-complete` | — |
| `delivery/technical-unit-assessment` | `agent-toolkit-complete` | — |
| `delivery/trd` | `agent-toolkit-complete` | — |
| `delivery/user-story` | `agent-toolkit-complete` | — |
| `delivery/work-item` | `agent-toolkit-complete` | — |
| `delivery/workflow-client-bootstrap` | `agent-toolkit-complete` | — |
| `delivery/workflow-generic-project` | `agent-toolkit-complete` | — |
| `design/design-assessment` | `agent-toolkit-complete` | — |
| `design/design-improvement` | `agent-toolkit-complete` | — |
| `design/figma` | `agent-toolkit-complete` | — |
| `design/figma-code-connect-components` | `agent-toolkit-complete` | — |
| `design/figma-create-design-system-rules` | `agent-toolkit-complete` | — |
| `design/figma-create-new-file` | `agent-toolkit-complete` | — |
| `design/figma-implement-design` | `agent-toolkit-complete` | — |
| `design/frontend-design` | `agent-toolkit-complete` | — |
| `design/frontend-design-review` | `agent-toolkit-complete` | — |
| `design/web-design-guidelines` | `agent-toolkit-complete` | — |
| `forge/gh-address-comments` | `agent-toolkit-complete`, `agent-toolkit-forge` | claude-code, cursor |
| `forge/gh-contribution-planner` | `agent-toolkit-complete`, `agent-toolkit-forge` | claude-code, cursor |
| `forge/gh-fix-ci` | `agent-toolkit-complete`, `agent-toolkit-forge` | claude-code, cursor |
| `forge/github-cli-workflow` | `agent-toolkit-complete`, `agent-toolkit-forge` | claude-code, cursor |
| `forge/gitlab-cli-workflow` | `agent-toolkit-complete`, `agent-toolkit-forge` | claude-code, cursor |
| `forge/workflow-client-bootstrap` | `agent-toolkit-complete`, `agent-toolkit-forge` | claude-code, cursor |
| `forge/workflow-generic-project` | `agent-toolkit-complete`, `agent-toolkit-forge` | claude-code, cursor |
| `forge/worktree` | `agent-toolkit-complete` | — |
| `integrations/clickup-cli` | `agent-toolkit-complete` | — |
| `integrations/linear` | `agent-toolkit-complete` | — |
| `integrations/mcp` | `agent-toolkit-complete` | — |
| `integrations/slack-assistant` | `agent-toolkit-complete` | — |
| `integrations/slack-cli` | `agent-toolkit-complete` | — |
| `loops/loop-runner` | `agent-toolkit-complete` | — |
| `ops/docs-generator` | `agent-toolkit-complete` | — |
| `ops/llm-cost-advisor` | `agent-toolkit-complete` | — |
| `ops/swarm` | `agent-toolkit-complete` | — |
| `ops/swarm-handoff` | `agent-toolkit-complete` | — |
| `ops/swarm-observer` | `agent-toolkit-complete` | — |
| `ops/triage` | `agent-toolkit-complete` | — |
| `quality/blast-radius` | `agent-toolkit-complete` | — |
| `quality/codeql` | `agent-toolkit-complete` | — |
| `quality/deslop` | `agent-toolkit-complete` | — |
| `quality/megalinter` | `agent-toolkit-complete` | — |
| `quality/megalinter-check` | `agent-toolkit-complete` | — |
| `quality/megalinter-fix` | `agent-toolkit-complete` | — |
| `quality/megalinter-setup` | `agent-toolkit-complete` | — |
| `quality/unslop` | `agent-toolkit-complete` | — |
| `tooling/chrome-devtools` | `agent-toolkit-complete` | — |
| `tooling/cli-for-agents` | `agent-toolkit-complete` | — |
| `tooling/herdr` | `agent-toolkit-complete` | — |
| `tooling/inventory` | `agent-toolkit-complete` | — |
| `tooling/jupyter-notebook` | `agent-toolkit-complete` | — |
| `tooling/mermaid` | `agent-toolkit-complete` | — |
| `tooling/playwright-cli` | `agent-toolkit-complete` | — |

## Agents → Products

| Agent | Products | Targets (via products) |
|-------|----------|------------------------|
| `agentic-security-reviewer` | `agent-toolkit-agents` | claude-code, cursor |
| `architect` | `agent-toolkit-agents` | claude-code, cursor |
| `assistant` | `agent-toolkit-agents` | claude-code, cursor |
| `build-error-resolver` | `agent-toolkit-agents` | claude-code, cursor |
| `client-workflow-bootstrap` | `agent-toolkit-agents` | claude-code, cursor |
| `code-reviewer` | `agent-toolkit-agents`, `agent-toolkit-core` | claude-code, cursor, requires, security |
| `database-reviewer` | `agent-toolkit-agents` | claude-code, cursor |
| `docs-lookup` | `agent-toolkit-agents` | claude-code, cursor |
| `e2e-runner` | `agent-toolkit-agents` | claude-code, cursor |
| `performance-optimizer` | `agent-toolkit-agents` | claude-code, cursor |
| `planner` | `agent-toolkit-agents` | claude-code, cursor |
| `refactor-cleaner` | `agent-toolkit-agents` | claude-code, cursor |
| `reference-lookup` | `agent-toolkit-agents` | claude-code, cursor |
| `security-reviewer` | `agent-toolkit-agents` | claude-code, cursor |
| `tdd-guide` | `agent-toolkit-agents` | claude-code, cursor |
| `tech-assistant` | `agent-toolkit-agents` | claude-code, cursor |
| `typescript-reviewer` | `agent-toolkit-agents` | claude-code, cursor |

## How to read

- A skill appears in a marketplace plugin when its product is built for that target (`agent-toolkit build --product <id> --target <target>`).
- `_uncovered_` means the skill/agent is not in any stable product yet — it exists canonically but is not shipped. See Wave 5 curation for promotion decisions.
- Verify membership locally via `agent-toolkit inventory` (canonical counts) or `./scripts/generate-skill-matrix.vsh --check`.

## See also

- `distributions/products.yaml` — source of truth
- `agent-toolkit inventory` — CLI inventory
- `agent-toolkit build --check` — drift check
