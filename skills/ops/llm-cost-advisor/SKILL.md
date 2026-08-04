---
name: llm-cost-advisor
description: >-
  WHAT — Recommend the most cost-effective LLM provider for a given task type.
  Shows estimated cost per run across available providers and integrates with
  dots-devcompanion llm-status to show what is actually available.
metadata:
  author: ulises-jeremias
  version: "1.0"
  tags: [llm, cost, provider, optimization]
---

# LLM Cost Advisor (WHAT)

Recommend the right provider for the task at hand — balancing quality, cost, and privacy.

## When to use

- User asks "which model should I use for X?"
- Before scheduling expensive loops (pr-babysitter, ci-sweeper)
- When dev-companion jobs are unexpectedly expensive
- When choosing between local and cloud providers for sensitive work

## Out of scope

- Does NOT configure providers — that's done via env vars and `dots-loadenv`
- Does NOT run LLM calls — it advises, the runner executes

## Workflow

**Step 1 — Check available providers:**

```bash
dots-devcompanion llm-status
```

**Step 2 — Classify the task:**

| Task type | Recommended tier | Why |
|-----------|-----------------|-----|
| Interactive code review, planning, debugging | Claude Sonnet / GPT-4o | Reasoning quality matters |
| Batch labeling, summarization, triage | Claude Haiku / GPT-4o-mini | High volume, lower stakes |
| Private/sensitive codebase work | Ollama or OpenCode | Stays local, zero cost |
| Loop L1 (observation only) | Haiku / GPT-4o-mini | Low stakes, runs daily |
| Loop L2 (PR creation) | Sonnet | Creates external artifacts |
| Loop L3 (unattended) | Sonnet + verifier | Autonomous — quality critical |

**Step 3 — Show cost estimate:**

| Provider | Model | Est. per run | Monthly (1/day) | Monthly (96/day) |
|----------|-------|-------------|-----------------|-----------------|
| Anthropic | claude-3-5-sonnet | ~$0.05 | ~$1.50 | ~$144 |
| Anthropic | claude-3-haiku | ~$0.005 | ~$0.15 | ~$14.40 |
| OpenAI | gpt-4o | ~$0.04 | ~$1.20 | ~$115 |
| OpenAI | gpt-4o-mini | ~$0.003 | ~$0.09 | ~$8.64 |
| Ollama | (local) | $0 | $0 | $0 |
| OpenCode | (local) | $0 | $0 | $0 |

*Estimates based on ~2K input + ~1K output tokens per typical run.*

**Step 4 — Recommend with reasoning:**

Give a clear recommendation: "For daily CNA issue triage (L1, observation only), use
claude-3-haiku — ~$0.15/month vs $1.50/month for Sonnet, with no quality difference
for labeling and summarization tasks."

## Budget gate reminder

If the user is setting up loops, remind them to add `limits.max_cost_usd` to their job
definitions to enable the runner's hard budget enforcement:

```json
"limits": {
  "timeout_sec": 300,
  "max_cost_usd": 0.50
}
```

## Anti-patterns

- Do not recommend cloud providers for repos marked confidential — suggest Ollama/OpenCode
- Do not recommend Haiku for L3 unattended loops — quality failures cascade
- Do not skip the `llm-status` check — recommend only available providers
