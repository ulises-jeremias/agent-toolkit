# Compiler Guide

agent-toolkit includes a deterministic compiler that transforms canonical
skills, agents, and loops into native artifacts for each AI coding platform.

## Quick commands

```bash
# Dry-run: show what would be compiled
agent-toolkit build --target claude-code --check

# Compile for a specific target and product
agent-toolkit build --target cursor --product agent-toolkit-core

# Show changes vs currently installed bundles
agent-toolkit diff --target cursor

# List all canonical capabilities
agent-toolkit inventory

# Show platform capability matrix
agent-toolkit matrix

# Generate release artifacts (dry run — never publishes)
agent-toolkit release --dry-run --output dist/
```

## How it works

```
canonical sources
    ↓ parse (loader.py)
validated canonical IR (CanonicalGraph)
    ↓ target negotiation
target-specific IR
    ↓ render (each adapter)
native package source
    ↓ verify
CompilationResult (emitted / unsupported / warnings)
```

## Target adapters

Each target has its own adapter in `packages/pypi/agent-toolkit-cli/src/agent_toolkit/compiler/targets/`:

| Target | Adapter | Package type |
|--------|---------|-------------|
| claude-code | ClaudeCodeAdapter | plugin (.claude-plugin/) |
| cursor | CursorAdapter | plugin (.cursor-plugin/) |
| copilot-cli | CopilotCLIAdapter | plugin (plugin.json) |
| copilot-repository | CopilotRepositoryAdapter | repository-customization |
| gemini-cli | GeminiCLIAdapter | extension |
| opencode | OpenCodeAdapter | companion-assets |
| pi | PiAdapter | companion-assets |
| windsurf | WindsurfAdapter | customization-bundle |
| codex | CodexAdapter | plugin (experimental) |

## CompilationResult

Every adapter returns a `CompilationResult` that explicitly documents:

- `emitted` — capabilities successfully compiled
- `transformed` — compiled with modification (e.g. SKILL.md → TOML command)
- `omitted` — safely skipped (source file missing)
- `unsupported` — capability not supported by this target
- `warnings` — non-fatal issues
- `errors` — compilation failures

**Unsupported capabilities are never silently dropped.** The build fails
if a required capability cannot be represented for a target.

## Adding a new target

See [Contributing](Contributing) for the step-by-step guide.
