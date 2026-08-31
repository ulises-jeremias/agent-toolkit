# Codex Profile

[OpenAI Codex](https://developers.openai.com/codex) — experimental target (`maturity: experimental` in `capabilities/targets/registry.yaml`).

## Status

Experimental. Codex marketplace submission is pending OpenAI authorization. Skills are delivered via compiled plugins (`agent-toolkit build --target codex`), not hand-maintained profile files.

## Installation

```bash
# Via agent-toolkit (builds plugin bundle)
agent-toolkit build --target codex
# Output: plugins/<product>/ for Codex marketplace

# Manual
# Copy compiled plugin/skills from plugins/ after build
```

## References

- `capabilities/targets/registry.yaml` (codex adapter)
- `docs/COMPATIBILITY.md` (Codex row)
- `docs/certification/codex.md`
