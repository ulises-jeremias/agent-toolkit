---
name: deep-review
description: Evidence-based deep code review rubric — severity + confidence findings across maintainability, correctness, security, performance, and testing. Push for ambitious structural simplification (code judo), not just local cleanup. Escalate hands-on triage to the code-reviewer agent.
origin:
  type: first-party
metadata:
  inspired_by:
    - repository: cursor/plugins
      path: cursor-team-kit/skills/thermo-nuclear-code-quality-review
      ref: 60c641e4fad674784b30abcf9f8915dea39df38d
      note: Ambitious structural-simplification rubric (code judo), 1000-line file boundary, anti-spaghetti-conditional growth, type/boundary cleanliness, canonical-layer placement, atomic orchestration
---

# Deep Review

A strict, evidence-cited code review rubric for when a change needs more than a
surface checklist. It pushes the reviewer to be **ambitious about structure** —
not merely to identify local cleanup, but to find "code judo" moves: restructurings
that preserve behavior while making the implementation dramatically simpler, smaller,
and more direct.

## When to use

- The user asks for a "deep review", "deep code quality audit", "thermo-nuclear review",
  "harsh maintainability review", or "review for abstraction quality".
- A PR touches large files, shared layers, or risk-prone abstractions.
- The `code-reviewer` agent flags that a change needs structural (not stylistic) feedback.

## Review contract

Findings carry **severity** and **confidence**, each with an evidence citation
(file:line or diff hunk) — no ungrounded opinions:

- **Severity:** `critical` (block merge) · `warning` (should fix) · `suggestion` (consider).
- **Confidence:** `high` (certain from the evidence) · `medium` (likely, needs a look) · `low` (hypothesis).

## Baseline prompt

> Perform a deep code quality audit of the current branch's changes.
> Rethink how to structure / implement the changes to meaningfully improve code quality without impacting behavior.
> Work to improve abstractions, modularity, reduce spaghetti code, improve succinctness and legibility.
> Be ambitious — if there is a clear path to improving the implementation that involves restructuring, pursue it.
> Be extremely thorough and rigorous. Measure twice, cut once.

## Non-negotiable standards

1. **Be ambitious about structural simplification.** Do not stop at "this could be
   cleaner". Look for opportunities to reframe the change so whole branches, helpers,
   modes, conditionals, or layers disappear. Prefer the solution that makes the code
   feel inevitable in hindsight. If there is a path to delete complexity rather than
   rearrange it, push hard for that path.

2. **Do not let a PR push a file over 1000 lines without a very strong reason.** Treat
   this as a strong smell. Prefer extracting helpers, subcomponents, or modules. If the
   diff crosses the threshold, ask whether the code should be decomposed first.

3. **Do not allow random spaghetti growth.** Be highly suspicious of new ad-hoc
   conditionals, scattered special cases, or one-off branches inserted into unrelated
   flows. Prefer pushing logic into a dedicated abstraction, helper, state machine, or
   policy object instead of tangling an existing path.

4. **Bias toward cleaning the design, not just accepting working code.** If behavior
   can stay the same while structure becomes meaningfully cleaner, push for the cleaner
   version. Do not rubber-stamp "it works" implementations that leave the codebase messier.

5. **Prefer direct, boring, maintainable code over hacky or magical code.** Flag thin
   abstractions, identity wrappers, or pass-through helpers that add indirection without
   buying clarity. Be skeptical of generic mechanisms that hide simple data-shape assumptions.

6. **Push hard on type and boundary cleanliness.** Question unnecessary optionality,
   `any`/`unknown`, or cast-heavy code when a clearer type boundary could exist. Prefer
   explicit typed models over loosely-shaped ad-hoc objects. Flag silent fallbacks that
   paper over an unclear invariant.

7. **Keep logic in the canonical layer and reuse existing helpers.** Call out feature
   logic leaking into shared paths or implementation details leaking through APIs. Prefer
   existing canonical utilities over bespoke one-offs.

8. **Treat unnecessary sequential orchestration and non-atomic updates as design smells.**
   If independent work is serialized for no good reason, ask whether the flow should run in
   parallel. If related updates can leave state half-applied, push for a more atomic structure.

## Primary review questions

For every meaningful change, ask:

- Is there a "code judo" move that would make this dramatically simpler?
- Can this change be reframed so fewer concepts, branches, or helper layers are needed?
- Does this improve or worsen the local architecture?
- Did a previously cohesive module become more coupled, more stateful, or harder to scan?
- Is this logic living in the right file and layer?
- Did this change enlarge a file or component past a healthy size boundary?
- Are there repeated conditionals that signal a missing model or missing helper?
- Is the implementation direct and legible, or does it rely on special cases and incidental control flow?
- Is this abstraction actually earning its keep, or is it just a wrapper?
- Did the diff introduce casts, optionality, or ad-hoc object shapes that obscure the real invariant?
- Is this logic living in the canonical layer, or did the diff leak details across a boundary?
- Is this orchestration more sequential or less atomic than it needs to be?

## What to flag aggressively

- A complicated implementation where a cleaner reframing could delete whole categories of complexity.
- Refactors that move code around but fail to reduce the concepts a reader must hold in their head.
- A file crossing 1000 lines due to the PR, especially if the new code could be split out.
- New conditionals bolted onto unrelated code paths.
- One-off booleans, nullable modes, or flags that complicate existing control flow.
- Feature-specific logic leaking into general-purpose modules.
- Generic "magic" handling that hides simple structure.
- Thin wrappers or identity abstractions that add indirection without simplifying anything.
- Unnecessary casts, `any`, `unknown`, or optional params that muddy the real contract.
- Copy-pasted logic instead of extracted helpers.
- Narrow edge-case handling implemented in the middle of an already busy function.
- Refactors that technically pass tests but make the code less modular or less readable.
- "Temporary" branching that is likely to become permanent debt.
- Bespoke helpers where the codebase already has a canonical utility.
- Logic added in the wrong layer/package.
- Sequential async flow where independent work could stay simpler with parallel execution.
- Partial-update logic that leaves state less atomic than necessary.

## Preferred remedies

- Delete a whole layer of indirection rather than polishing it.
- Reframe the state model so conditionals disappear instead of getting centralized.
- Change the ownership boundary so the feature becomes a natural extension of an existing abstraction.
- Turn special-case logic into a simpler default flow with fewer exceptions.
- Extract a helper or pure function.
- Split a large file into smaller focused modules.

## Output format

Group findings by severity, each with a confidence tag and an evidence citation:

```
**🚨 Critical** (block merge)
- [high] `src/foo.v:120` — <finding + code judo suggestion>
**⚠️ Warning** (should fix)
- [medium] `src/bar.ts:45-60` — <finding + remedy>
**💡 Suggestion** (consider)
- [low] — <opportunity>
```

End with a one-line verdict: **merge**, **merge with follow-up**, or **block**.

## Escalation

When findings require hands-on triage — reading the full context of modified files,
checking related tests, or proposing exact patches — delegate to the **`code-reviewer`**
agent rather than duplicating its checklist here.
