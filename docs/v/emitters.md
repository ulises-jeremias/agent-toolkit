# V Tier-1 target emitters

**Issue:** [#509](https://github.com/ulises-jeremias/agent-toolkit/issues/509)

Emits Cursor (`.cursor-plugin/`), Claude Code (`.claude-plugin/`), and OpenCode (`.opencode/` + `opencode.json`) plugin surfaces from a `CanonicalGraph` product selection. Copies `SKILL.md` / `AGENT.md` (+ skill `references/`), writes pretty-printed manifests, and attaches `.provenance.json`. Hooks/MCP registries remain unsupported until a later slice (reported in `unsupported`).
