# Portable goals (v1)

Agent Toolkit Goal v1 is an offline contract for a bounded objective. It records authorized repositories, acceptance criteria, deadline, budgets, delivery mode, and a dependency graph of tasks. Each task names its repository, pinned base SHA, allowed paths, recipe, runner, and verifier. The contract does not run tasks or create external effects.

Validate and plan with the native CLI:

```sh
agent-toolkit goal validate tests/fixtures/goals/minimal.yaml
agent-toolkit goal export tests/fixtures/goals/minimal.yaml > goal.json
agent-toolkit goal plan tests/fixtures/goals/minimal.yaml
agent-toolkit goal recipes
```

The schemas are `schemas/goal-v1.schema.json` and `schemas/goal-evidence-v1.schema.json`. `goal export` emits the complete normalized Goal v1 JSON manifest for admission by Veasel. The native offline validator additionally checks repository authorization, dependency references and cycles, and evidence-to-task/base-SHA consistency. A receipt names a candidate SHA, execution mode (`fixture`, `hermetic`, or `real`), environment, verifier identity/version, result, and SHA-256 evidence digests. `fixture` is synthetic evaluation data and must never count as evidence that workers, providers, or product workflows actually ran. `hermetic` and `real` describe actual executions; a verifier must still state what environment it observed. Any later candidate SHA requires a new receipt.

Built-in recipe definitions under `recipes/goals/` provide portable checklists for research, bug, feature, migration, and release work. Evaluation fixtures belong in `tests/fixtures/goals/`; keep synthetic data clearly labeled and never imply that a sample receipt or objective represents a real execution.
