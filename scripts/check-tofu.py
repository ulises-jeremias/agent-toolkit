#!/usr/bin/env python3
"""check-tofu.py — tofu detector for desktop golden fixtures (#1111).

Two deterministic guards (no OCR heuristics):

1. Bundled-fonts proof: the app must have booted with the EMBEDDED fonts
   (``fonts: dir=...assets/fonts`` in tests/golden-app.log). System fallback
   fonts change glyph metrics and are the actual tofu vector for the CJK and
   Arabic chrome — a capture without this line proves nothing.
2. Fixture sanity: all 26 fixtures (paper + ink) must exist and exceed a
   minimum byte size, catching black/empty/truncated captures.

Usage: python3 scripts/check-tofu.py
Exit status is non-zero with a diagnostic on the first failure.
"""

import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAPER = [f'tests/golden/panel-{i:02d}.png' for i in range(10)]
PAPER += ['tests/golden/panel-products.png', 'tests/golden/panel-insights.png',
          'tests/golden/panel-onboarding.png']
INK = ['tests/golden/ink/' + os.path.basename(p) for p in PAPER]
MIN_BYTES = 20 * 1024


def fail(msg: str) -> int:
    print(f'TOFU FAIL: {msg}')
    return 1


def main() -> int:
    log = os.path.join(ROOT, 'tests', 'golden-app.log')
    try:
        with open(log, encoding='utf-8', errors='replace') as fh:
            app_log = fh.read()
    except OSError:
        return fail(f'app log missing: {log} (run scripts/golden.sh first)')
    font_lines = [line for line in app_log.splitlines() if 'fonts: dir=' in line]
    if not font_lines:
        return fail('no "fonts: dir=" line in app log — capture did not prove bundled fonts')
    if not any(line.split('fonts: dir=', 1)[1].split()[0].rstrip('/').endswith('assets/fonts')
               for line in font_lines):
        return fail(f'fonts not bundled: {font_lines[-1][:160]}')
    print(f'tofu fonts OK — {font_lines[-1][:120]}')
    missing = []
    tiny = []
    for rel in PAPER + INK:
        path = os.path.join(ROOT, rel)
        if not os.path.isfile(path):
            missing.append(rel)
            continue
        if os.path.getsize(path) < MIN_BYTES:
            tiny.append(f'{rel} ({os.path.getsize(path)}B)')
    if missing:
        return fail(f'{len(missing)} fixtures missing: {missing[:5]}')
    if tiny:
        return fail(f'{len(tiny)} fixtures suspiciously small: {tiny[:5]}')
    print(f'tofu fixtures OK — {len(PAPER) + len(INK)} present, all >= {MIN_BYTES}B')
    print('TOFU PASS')
    return 0


if __name__ == '__main__':
    sys.exit(main())
