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

## Updating Advisor

`llm-cost-advisor` should read current availability/pricing, not hardcoded prices.
