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

## Parity

Herdr and tmux share `SwarmUIBackend` interface; workflow semantics identical.
