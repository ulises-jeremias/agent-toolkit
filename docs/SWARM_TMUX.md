# Swarm + tmux

tmux is the portable fallback.

## Why

Works over SSH, headless Linux, no GUI required.

## Isolated Server

- One isolated server/socket per run: `agent-toolkit-swarm-<run-id>`
- Never mutates user's normal tmux server
- Deterministic session `swarm-<run-id>`, windows per role
- Safe quoting via `shlex.quote`, runner command arrays not shell interpolation

## Usage

```bash
agent-toolkit swarm start --recipe pair --ui tmux --runner opencode "Fix bug"
agent-toolkit swarm attach RUN_ID
# Manual attach:
tmux -L agent-toolkit-swarm-RUN_ID attach -t swarm-RUN_ID

# Inspect
tmux -L agent-toolkit-swarm-RUN_ID list-windows -t swarm-RUN_ID
tmux -L agent-toolkit-swarm-RUN_ID capture-pane -p -t swarm-RUN_ID:implementer
```

## Lifecycle

- `agent-toolkit swarm stop RUN_ID` → `tmux kill-window` per role, preserve state
- `agent-toolkit swarm cleanup RUN_ID` → `tmux kill-session`, only Toolkit-owned worktrees, dirty preserved, branches kept
- `agent-toolkit swarm status RUN_ID` same semantics as Herdr

## No Domain Logic in tmux

No handoff/ budget/Git logic in tmux scripts. Orchestration stays filesystem-based.

## Control Mode

Evaluated but not required; attach directly is sufficient per spec.

## Parity (Herdr)

Herdr and tmux share `SwarmUIBackend` interface; workflow semantics identical. Herdr is recommended for rich UI ([SWARM_HERDR.md](SWARM_HERDR.md) — `herdr workspace create`, `herdr agent prompt --wait --json`, thin plugin at `integrations/herdr/agent-toolkit-swarm/`); tmux is the portable fallback described here. `--ui auto` selects Herdr when available, otherwise tmux; `--ui herdr` fails with install guidance if Herdr missing.

## Privacy, State & Offline

- **Privacy:** no telemetry; captures via `capture-pane` are local; secrets redacted.
- **State locations:** same as Herdr — `.agent-toolkit/swarm/runs/<run-id>/` (`state.json`, `trace.jsonl`, `budget.json`, `handoffs/`, `worktrees/`). See [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) for state machines and [SWARMS.md](SWARMS.md) for full file map.
- **Offline/fake demo:** `agent-toolkit swarm plan` is side-effect free; `--runner skeleton --ui tmux` works fully offline, ideal for CI:

```bash
agent-toolkit swarm plan --recipe pair --ui tmux --runner skeleton "Demo: hello endpoint" --json
agent-toolkit swarm start --runner skeleton --ui tmux "Offline demo"
```

Related: [SWARMS.md](SWARMS.md) · [SWARM_ARCHITECTURE.md](SWARM_ARCHITECTURE.md) (Mermaid diagrams) · [SWARM_HERDR.md](SWARM_HERDR.md) · [SWARM_RECIPES.md](SWARM_RECIPES.md) · [SWARM_HANDOFFS.md](SWARM_HANDOFFS.md) · [SWARM_MODELS_AND_COSTS.md](SWARM_MODELS_AND_COSTS.md) · [SWARM_SECURITY.md](SWARM_SECURITY.md) · [HOW_TO_CREATE_SWARM_RECIPE.md](HOW_TO_CREATE_SWARM_RECIPE.md)
