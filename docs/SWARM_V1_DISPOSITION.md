# Swarm v1 retirement and data boundary

**Current product:** Veasel Code owns new coding-agent orchestration. Agent Toolkit is the portable capability library and CLI.

## What current builds do

Current Agent Toolkit CLI and HTTP dispatch reject Swarm v1 `start` and `init` with a `feature_frozen` result before resolving a workspace or creating a run. CI checks this behavior on Linux and macOS. Existing run inspection and legacy recovery actions remain available for user-owned state. Older published Toolkit versions may predate the guard; do not use them to create new Swarm v1 runs.

Use Veasel Code for new orchestration: <https://github.com/veasel-labs/veasel>.

## Preserve existing state

No general Swarm-to-Veasel importer exists. Keep existing `.agent-toolkit/swarm/` records, Git worktrees, branches, handoffs, artifacts, and locally modified recipes intact. Do not run `cleanup` or `prune` as part of an upgrade. Back up exact paths before user-directed recovery or removal.

For a specific old run, inspect it using commands supported by the installed version:

```sh
agent-toolkit swarm list
agent-toolkit swarm status RUN_ID
agent-toolkit swarm report RUN_ID
agent-toolkit swarm logs RUN_ID
agent-toolkit swarm artifacts RUN_ID
agent-toolkit swarm handoffs RUN_ID
```

Use `agent-toolkit swarm stop RUN_ID` or `agent-toolkit swarm cancel RUN_ID` only when intentionally stopping that existing run. Check `agent-toolkit swarm --help` first; commands vary by release. Do not assume Veasel imports the run's history or worktree.

Other historical action commands remain in the compatibility surface. Some can
change approvals, run records, worktrees, branches, or delete old state. Read the
exact command help and back up its target before use. In particular, do not run
`cleanup` or `prune` as part of an upgrade or migration.

## Recorded evidence

Agent Toolkit issue [#1676](https://github.com/ulises-jeremias/agent-toolkit/issues/1676) and Veasel issue [#629](https://github.com/veasel-labs/veasel/issues/629) are closed with evidence for the product boundary and Veasel's own orchestration workflow. They do not claim general Swarm-data migration.

The maintainer's one-host audit found a completed trace and verified that a copy matched the original before leaving the original intact. This is evidence for that host only; it does not establish the contents or migration needs of other users' records.

The former execution implementation and design notes remain in Git history. Agent Toolkit's current user documentation does not advertise Swarm v1 as a supported execution product.
