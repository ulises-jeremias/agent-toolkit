---
name: deep-review
description: Escalated maintainability review with a strict structural rubric. Use for deep code quality
  audit, thermo-nuclear review, architecture-heavy PR review, or when standard review is insufficient
  for structural regressions, file-size growth, or spaghetti branching.
origin:
  type: first-party
metadata:
  inspired_by:
    - repository: cursor/plugins
      path: thermos/skills/thermo-nuclear-code-quality-review
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Thermos maintainability rubric — structural simplification, file-size guardrails, spaghetti detection
---
# Deep Review

Strict maintainability review for changes where behavior correctness alone is not enough.
Pairs with the **`code-reviewer`** agent.

## When to use

- Large or structural PRs where local nits miss the real risk.
- User asks for "deep review", "thermo-nuclear review", or "maintainability audit".
- A file may cross **1000 lines** because of the diff.
- **`code-reviewer`** flags structural concerns and needs the full rubric.

## Core prompt

> Perform a deep code quality audit of the current branch's changes.
> Rethink structure to improve quality without impacting behavior.
> Be ambitious about restructuring when it deletes complexity.

## Non-negotiable standards

1. **Ambitious structural simplification** — code-judo moves that delete branches/helpers/layers.
2. **File size** — do not push a file from under 1k to over 1k lines without strong reason.
3. **No spaghetti growth** — flag ad-hoc conditionals and feature logic in shared paths.
4. **Design over "it works"** — prefer cleaner structure at same behavior.
5. **Canonical layer** — reuse existing helpers; keep logic in the right module.

## Output expectations

Prioritize: structural regressions → simplification opportunities → spaghetti → boundaries → file size.

## Agent integration

When invoked via **`@code-reviewer`**: run standard checklist first, then this rubric; elevate structural issues.

## Related skills

- **`quality/megalinter-check`** — static gates (complementary, not substitute)
