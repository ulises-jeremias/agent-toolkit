# Swarm Models & Costs

## Profiles

- `economy` — cheap, fast
- `balanced` — default, mix of planning/coding/review
- `quality` — strongest reasoning for decisions
- `private` — local `ollama/*` models, no external data

## Task Classes

`planning`, `coding`, `review`, `architecture`, `hardening`, `qa`

## Mapping Example

```yaml
model_profiles:
  balanced:
    planning: anthropic/claude-sonnet-4-20250514
    coding: anthropic/claude-sonnet-4-20250514
    review: openai/gpt-4o
    architecture: anthropic/claude-sonnet-4-20250514
    hardening: openai/gpt-4o
    qa: anthropic/claude-3-5-haiku-20241022
```

Different provider for review reduces correlated mistakes.

## Discovery

```bash
agent-toolkit swarm models --runner opencode
agent-toolkit swarm models --runner opencode --profile balanced --json
# also:
opencode models
```

Validate `provider/model` format before start. Per-role override via config.

## Pricing

Pricing stored separately from recipes, updateable cache, honest unknown handling. Never silently switch to expensive model; before fallback report:

```
Current model unavailable.
Configured fallback changes estimated cost from $X to $Y.
Explicit approval required.
```

If pricing unknown: "Pricing unavailable, estimate not calculated."

## Budgets

See `SWARMS.md`. Enforcement reuses loop budget primitives where possible.

## Herdr / tmux & Runners

Model selection is runner-agnostic — any of `opencode`/`claude`/`codex`/`cursor`/`copilot`/`muse` (plus `skeleton` for offline) can host the `provider/model` chosen via profile. Herdr ([SWARM_HERDR.md](SWARM_HERDR.md)) and tmux ([SWARM_TMUX.md](SWARM_TMUX.md)) both respect the same `model_profiles` mapping via `--model-profile economy|balanced|quality|private` or per-role override; discovery `agent-toolkit swarm models --runner opencode` delegates to `opencode models` (or runner equivalent) and falls back to profile defaults offline.

## Privacy & Cleanup

- **Privacy:** pricing cache is local, no cloud upload, redacted logs; `--profile private` (`ollama/*`) keeps data on-device.
- **Cleanup:** budgets do not affect worktree cleanup semantics — dirty worktrees preserved, branches kept; `budget_exhausted` is resumable.

Related: [SWARMS.md](SWARMS.md) · [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) · [SWARM_RECIPES.md](SWARM_RECIPES.md) · [SWARM_HANDOFFS.md](SWARM_HANDOFFS.md) · [SWARM_SECURITY.md](SWARM_SECURITY.md) · [SWARM_HERDR.md](SWARM_HERDR.md) · [SWARM_TMUX.md](SWARM_TMUX.md) · [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md)

## Offline / Fake Demo

```bash
agent-toolkit swarm models --runner skeleton --profile balanced  # no binary needed
agent-toolkit swarm plan --recipe pair --runner skeleton "demo" --json  # side-effect free
agent-toolkit swarm start --runner skeleton --ui tmux "offline demo"     # no LLM, no Herdr
```

## Updating Advisor

`llm-cost-advisor` should read current availability/pricing, not hardcoded prices.
