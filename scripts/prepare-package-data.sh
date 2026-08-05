#!/usr/bin/env bash
# Copy monorepo capability data into packages/agent-toolkit-cli/data/ for hatch builds.
# Safe to re-run. Output directory is gitignored except .gitignore.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/packages/agent-toolkit-cli/data"
mkdir -p "$DEST"
for name in skills agents loops profiles mcp catalogs; do
  rm -rf "$DEST/$name"
  cp -a "$ROOT/$name" "$DEST/$name"
done
echo "Prepared package data under $DEST"
