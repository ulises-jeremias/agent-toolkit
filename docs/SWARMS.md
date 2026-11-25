# Swarm v1 retirement

## Current contract

Agent Toolkit no longer starts new Swarm v1 runs. Current CLI and HTTP entry
points reject `start` and `init`; new coding-agent orchestration belongs to
[Veasel Code](https://github.com/veasel-labs/veasel).

Existing Swarm records, worktrees, and branches are user-owned. No general
importer moves them to Veasel. For safe inspection, intentional stop/cancel,
and the evidence boundary, read the
[Swarm v1 retirement and data boundary](SWARM_V1_DISPOSITION.md).
