# V `project` command family

**Issue:** [#522](https://github.com/ulises-jeremias/agent-toolkit/issues/522) (EPIC 5 [#462](https://github.com/ulises-jeremias/agent-toolkit/issues/462), disposition [#560](https://github.com/ulises-jeremias/agent-toolkit/issues/560) **PORT**)

Repo index matching Python `cli/project.py` (**PORT**; do not MERGE with `workspace`):

- `init` — create `repos/github.com/` and `projects/`, append `.gitignore`
- `clone owner/repo [--ssh]` — git/`gh` clone via ProcessService (no shell); symlink under `projects/`
- `list` — symlink status (`ok` / `broken`)
- `add <path>` / `remove <name>` — symlink only; never delete the clone
- `scan` — linked / broken / unlinked summary

Discovery uses `find_workspace_root` (#520 / #207). `projects.yaml` is updated on clone/add. No tmux/Herdr.
