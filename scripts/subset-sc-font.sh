#!/usr/bin/env bash
# subset-sc-font.sh — build assets/fonts/NotoSansSC-chrome.ttf
#
# The desktop GUI ships a tiny CJK subset so the 中文 i18n chrome renders without
# a 10 MB system font. The subset is derived from every CJK codepoint that occurs
# in cmd/agent-toolkit-desktop/main.v (i18n table), plus CJK punctuation, so new
# translated strings are covered by simply re-running this script.
#
# Requirements: python3 -m fontTools (pip install fonttools) and the variable
# source font (downloaded automatically into /tmp).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN="$ROOT/cmd/agent-toolkit-desktop/main.v"
OUT="$ROOT/assets/fonts/NotoSansSC-chrome.ttf"
SRC="${SC_FONT_SRC:-/tmp/opencode/NotoSansSC-var.ttf}"
PY="${PYTHON:-python3}"

if ! "$PY" -c 'import fontTools' >/dev/null 2>&1; then
	echo "error: fontTools not available — run: python3 -m venv .venv && .venv/bin/pip install fonttools" >&2
	exit 1
fi

if [ ! -f "$SRC" ]; then
	mkdir -p "$(dirname "$SRC")"
	echo "downloading Noto Sans SC (variable) → $SRC"
	curl -sL -o "$SRC" "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"
fi

# Collect CJK chars from the GUI source (i18n table) + a safe punctuation set.
CHARS="$("$PY" - "$MAIN" <<'EOF'
import sys
text = open(sys.argv[1], encoding='utf-8').read()
chars = {c for c in text if 0x2E80 <= ord(c) <= 0x9FFF or 0xFF00 <= ord(c) <= 0xFFEF}
chars |= set('，。、·（）「」：；！？—…％×÷（）　0123456789')
print(''.join(sorted(chars)))
EOF
)"

if [ -z "$CHARS" ]; then
	echo "error: no CJK chars found in $MAIN" >&2
	exit 1
fi
echo "subsetting ${#CHARS} codepoints → $OUT"

UNICODES="$("$PY" -c "import sys; print(','.join(str(ord(c)) for c in sys.argv[1]))" "$CHARS")"

# Instance the variable font at wght=450 (UI-regular+) then subset.
"$PY" -m fontTools.varLib.instancer "$SRC" wght=450 -o /tmp/opencode/NotoSansSC-450.ttf
"$PY" -m fontTools.subset /tmp/opencode/NotoSansSC-450.ttf \
	--unicodes="$("$PY" -c "import sys; print(','.join('%04X' % ord(c) for c in sys.argv[1]))" "$CHARS")" \
	--layout-features='' --no-hinting --desubroutinize \
	--output-file="$OUT"

ls -la "$OUT"
