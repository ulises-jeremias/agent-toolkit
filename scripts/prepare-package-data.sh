#!/usr/bin/env bash
# Copy monorepo capability data into the publishable package tree for hatch builds.
# Safe to re-run. Destination contents are gitignored except .gitignore.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/packages/agent-toolkit-cli/src/agent_toolkit/data"
mkdir -p "$DEST"
for name in skills agents loops profiles mcp catalogs distributions packs; do
  rm -rf "$DEST/$name"
  cp -a "$ROOT/$name" "$DEST/$name"
done
echo "Prepared package data under $DEST"
