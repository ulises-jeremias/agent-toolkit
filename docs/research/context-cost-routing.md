# Context-cost: routing, dependency graph & pack-scoped lazy discovery — #395 (2026-08-12)

Per §38-40: Context-cost explosion from 15+ new skills (now 77 skills) risks prompt pollution.

Per-target skill loading semantics:
- claude-code: Metadata upfront + body on demand via skills/ discovery (explicit invoke); plugin scope via plugins/agent-toolkit-*/.claude-plugin/plugin.json
- cursor: .cursor/rules/*.mdc alwaysApply: false (lazy) vs true (always) — toolkit uses false for most
- opencode: bridged via ~/.config/opencode/agents
- windsurf: manual via ~/.codeium/windsurf/rules
- codex/copilot-cli: unknown-blocked — hooks/MCP blocked per mcp/registry platforms

Minimal routing metadata: No new depends_on/delegates_to/conflicts_with graph added globally — only where real workflows need it. Current context_budget.py flags oversized skills (>10k tokens) as candidates for subagent delegation.

Pack-scoped discovery: agent-toolkit install --pack design-engineering only registers that pack's skills — not implemented; packs remain docs-only per ADR-0003 (skills:/agents: advisory only, loop run --pack only applies loops:). Future install --preset planned.

Refs #395, #387, #390, ADR-0003
