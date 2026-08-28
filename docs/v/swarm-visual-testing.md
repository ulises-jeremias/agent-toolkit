# Swarm Visual Testing — tmux + herdr, screenshots, live attach

How to prove — with visual evidence — that `agent-toolkit swarm` actually opens
real agent instances (opencode, claude, …) in **tmux** and **herdr**, that they
are alive, and that a human can watch them in real time.

Harness: [`scripts/swarm-visual/swarm-visual-test.sh`](../../scripts/swarm-visual/swarm-visual-test.sh)
Renderer: [`scripts/swarm-visual/ansi2png.py`](../../scripts/swarm-visual/ansi2png.py)

## What "the instance opened" means (3 evidence layers)

| Layer | Probe | Pass condition |
|---|---|---|
| **Process** | `tmux list-panes -s -F '#{pane_current_command}'` · `herdr pane process-info` | the running binary is `opencode` / `claude` |
| **UI alive** | `tmux capture-pane` / `herdr pane read` contains the runtime's TUI | banner/interaction visible; screen changes across frames |
| **Visual** | PNG renders + timeline GIF from a continuous `pipe-pane` log | artifacts you can look at |

CI already covers structure (`swarm-e2e`, headless + skeleton). Visual/live
phases run **locally** — they need a herdr server and LLM credentials.

## Setup (once)

```bash
uv venv scripts/swarm-visual/.venv   # gitignored — pyte + pillow only
uv pip install --python scripts/swarm-visual/.venv pyte pillow
./make.vsh build-cli                 # build/agent-toolkit
herdr status                         # server running? (T3/T6 need it)
```

Playground: the harness creates `/tmp/opencode/swarm-visual/playground` (a real
git repo — swarm requires git for worktrees) on first run.

## Phases

| Phase | Backend | Runner | Recipe | Proves | Cost |
|---|---|---|---|---|---|
| `T1` | tmux | skeleton | pair | socket + session + **one window per role**, waiting script, PNGs | ~1 min, $0 |
| `T2` | tmux | opencode | pair | **opencode alive** in panes: process probe + TUI captures | ~2 min |
| `T3` | herdr | skeleton | pair | workspace `swarm-<id>` + panes per role + `pane read` snapshots | ~1 min, $0 |
| `T4` | tmux | claude | pair | **claude code alive**, same capture pipeline | ~2 min |
| `T5` | both | — | pair | `swarm attach` blocks (live session) — human verification | manual |
| `T6` | herdr | opencode | **full** | 6 roles, 60+ PNGs, teardown clean | ~5 min |

```bash
scripts/swarm-visual/swarm-visual-test.sh --phase T1          # structure, $0
scripts/swarm-visual/swarm-visual-test.sh --phase T2 --frames 12
scripts/swarm-visual/swarm-visual-test.sh --phase T3
scripts/swarm-visual/swarm-visual-test.sh --phase T5          # then: agent-toolkit swarm attach <run-id>
```

Success criteria (asserted per phase): `SC1` window/pane-per-role inventory ·
`SC2` runtime process visible · `SC3` runtime text/banner in captures ·
`SC4` ≥1 PNG + `timeline.gif` · `SC6` teardown leaves nothing (`swarm prune`
dry-run clean). Results land in `artifacts/<ts>-<phase>-<backend>-<runner>/report.json`.

## How the capture pipeline works

1. `swarm start --json` spawns the UI **without** the blocking attach (attach
   still spawns; `--json` only skips the terminal hand-off).
2. **tmux**: `pipe-pane` records every window into `<role>.log` continuously —
   TUIs draw on the alternate screen, so a single `capture-pane` can miss the
   UI; the continuous log is the source of truth. `ansi2png.py` replays the log
   through pyte and renders PNG (agent-toolkit dark palette).
3. **herdr**: `herdr pane read <PANE_ID> --source visible` snapshots each pane
   of the swarm workspace (resolved via `workspace list` by label
   `swarm-<run-id>`); same renderer.
4. PNG frames are stitched into `timeline.gif` (ffmpeg) — visual proof of
   liveness without a TTY.
5. Teardown (`trap EXIT`): `swarm stop` + `cleanup` + `prune --force` +
   `tmux kill-server` + `herdr workspace close`. Idempotent.

## Bugs this harness caught (and fixed)

- **tmux backend never created a session** — `swarm start --backend tmux` only
  tried to attach. Now `spawn_tmux_session` creates the socket, the session and
  one window per role, launching the same runner surface as herdr.
- **`os.execvp` argv[0] duplication** — V's `execvp(prog, args)` prepends
  `prog` to argv itself; passing `'tmux'` again made tmux parse `"tmux"` as the
  command → `unknown command: tmux`, breaking every attach.
- **`herdr workspace open` does not exist** (herdr 0.8) — attach now resolves
  the workspace id by label and runs `herdr workspace focus <ws-id>`.

## Notes

- `opencode --prompt` runs the task and exits when done — liveness windows are
  bounded by the task duration; the harness uses a longer task for live phases.
- Keep `VJOBS=2` when re-running `./make.vsh test` on laptops.
- CI stays headless: these phases require a real backend (tmux/herdr) and LLM
  credentials; do not wire them into `Required CI`.
