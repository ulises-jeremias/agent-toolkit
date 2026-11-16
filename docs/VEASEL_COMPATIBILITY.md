# Veasel compatibility and Desktop retirement policy

Cross-repo epic: [veasel-labs/veasel#689](https://github.com/veasel-labs/veasel/issues/689) ·
Tracking issue: [#1804](https://github.com/ulises-jeremias/agent-toolkit/issues/1804) ·
Decision: ADR-0001 in `veasel-labs/veasel` (`docs/adr/0001-one-product-one-runtime.md`).

## What stays here

Agent Toolkit remains the canonical home for portable Skills, agents,
MCP configuration, context packs, workflow recipes, the CLI, and its
distribution (npm/PyPI/AUR/Homebrew/Docker). Nothing about existing
installs changes: `agent-toolkit` CLI commands, catalogs
(`capabilities/`, `skills/`, `agents/`, `packs/`, `schemas/`) and install
receipts keep working exactly as before.

## What moves, and when Desktop retires

The Desktop's Focus session runtime and World GUI are being migrated
copy-first into Veasel (Focus GUI copy: veasel-labs/veasel PR for issue
#692; provider adapters: veasel issue #691). The standalone Desktop in
this repo retires **only after all of the following are true**:

1. Veasel GUI reaches Focus parity on the canonical Veasel
   session/event API (same sessions visible in TUI and GUI).
2. Compatibility shims in this repo redirect Desktop-era entry points
   to the Veasel GUI and are shipped in a released version.
3. Packaged installers for the Veasel GUI are verified on Linux,
   macOS, and Windows.

Until then the Desktop stays fully supported, and the stacked Desktop
Rescue work (#1775, PRs #1783–#1803) is preserved — nothing is closed
or deleted as part of the consolidation without a documented successor
(see the triage ledger in veasel-labs/veasel `docs/consolidation/`).

## Shim contract (to implement under #1804)

- `agent-toolkit` CLI: unchanged. A future `desktop` verb may print a
  pointer to the Veasel GUI once condition 1 holds; it must never break
  scripts (exit 0 with guidance, or the legacy behaviour behind a flag).
- Desktop data (`userData/focus-journals`, workspace
  `.agent-toolkit/focus/` journals) migrates reversibly: the Veasel
  importer reads the JSONL journal format; originals are never deleted
  by the importer.
- Skills/agents/packs consumed by Veasel are read from this repo's
  canonical Markdown/YAML/JSON — no format fork.
