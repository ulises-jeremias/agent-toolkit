#!/usr/bin/env bash
# Copy a native V binary into the PyPI package tree for platform wheels (ADR-021 / #535).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/packages/pypi/agent-toolkit-cli/src/agent_toolkit/bin"
mkdir -p "$DEST"
SRC="${AGENT_TOOLKIT_NATIVE_BIN:-}"
if [[ -z "$SRC" ]]; then
  for cand in "$ROOT/build/agent-toolkit" "$ROOT/build/agent-toolkit-v" "$ROOT/build/agent-toolkit.exe"; do
    if [[ -f "$cand" ]]; then
      SRC="$cand"
      break
    fi
  done
fi
if [[ -z "$SRC" || ! -f "$SRC" ]]; then
  echo "prepare-native-bin: no binary (set AGENT_TOOLKIT_NATIVE_BIN or make build-cli)" >&2
  exit 1
fi
if [[ "$SRC" == *.exe ]]; then
  OUT="$DEST/agent-toolkit.exe"
else
  OUT="$DEST/agent-toolkit"
fi
cp -f "$SRC" "$OUT"
chmod +x "$OUT" 2>/dev/null || true
echo "Copied $SRC → $OUT"
