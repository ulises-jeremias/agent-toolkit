# V `memory` command family

**Issue:** [#521](https://github.com/ulises-jeremias/agent-toolkit/issues/521) (EPIC 5 [#462](https://github.com/ulises-jeremias/agent-toolkit/issues/462), disposition [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) **PORT**)

Persistent markdown knowledge base matching Python `cli/memory.py`:

- `add --type learning|process|todo` — append table row / process section / pending checkbox (atomic write)
- `search` — case-insensitive scan of `knowledge/**/*.md`
- `inject` — session block (todos, recent learnings, process index)
- `review [--fix] [--stale-after N]` — duplicates (normalized equality/overlap), orphan path refs, stale+missing refs; exit 1 when issues found
- `todo [--done]` — list unchecked (and optionally completed) items

Discovery uses `find_workspace_root` (#520 / #207). Format stays compatible with existing `knowledge/` trees. No tmux/Herdr.
