# V `inventory` command

**Issue:** [#503](https://github.com/ulises-jeremias/agent-toolkit/issues/503)

Read-only listing of `skills/**/SKILL.md`, `agents/*`, and `distributions/products.yaml`. Human output matches the Python header/counts contract; `--json` emits `CommandResult` with `skills_count` / `agents_count` / `products_count`. Does not use the compiler loader ([#507](https://github.com/ulises-jeremias/agent-toolkit/issues/507)).
