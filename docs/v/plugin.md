# V `plugin sync|check`

**Issue:** [#519](https://github.com/ulises-jeremias/agent-toolkit/issues/519) (EPIC 4b [#551](https://github.com/ulises-jeremias/agent-toolkit/issues/551))

Gen-surfaces copy/compare for `agent-toolkit-core` / `agents` / `forge` plugin bundles (Python `cli/plugin.py`):

- `check` — exit non-zero on drift; also verifies `.provenance.json` digests when present
- `sync` — copy canonical agents/skills into `plugins/<product>/`

**Boundary vs `build --check`:** plugin sync/check is a **directory copy** of source trees. `build --check` compiles emitters and compares generated artifacts.
