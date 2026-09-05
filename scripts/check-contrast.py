#!/usr/bin/env python3
"""Contrast gate for the Paper/Ink GUI themes (#1097).

Reads the token hex values from modules/desktop/theme/tokens.v and asserts
WCAG 2.1 contrast ratios for every text role on every surface role, in both
themes. Text roles must clear 4.5:1; failures fail the gate (exit 1).

Usage: python3 scripts/check-contrast.py
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TOKENS = REPO / "modules" / "desktop" / "theme" / "tokens.v"

TEXT_ROLES = ["text_primary", "text_secondary"]
SURFACE_ROLES = ["surface_canvas", "surface_paper"]


def parse_theme(src: str, fn_name: str) -> dict[str, str]:
    m = re.search(r"pub fn " + fn_name + r"\(\) ColorTokens \{(.*?)\n\}", src, re.S)
    if not m:
        raise SystemExit(f"cannot find {fn_name} in tokens.v")
    return dict(re.findall(r"(\w+):\s*'(#[0-9A-Fa-f]{6})'", m.group(1)))


def luminance(hexcode: str) -> float:
    rgb = [int(hexcode[i : i + 2], 16) / 255.0 for i in (1, 3, 5)]

    def lin(c: float) -> float:
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (lin(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(fg: str, bg: str) -> float:
    l1, l2 = luminance(fg), luminance(bg)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def main() -> int:
    src = TOKENS.read_text()
    themes = {"paper": parse_theme(src, "light_colors"), "ink": parse_theme(src, "ink_colors")}
    failures = 0
    for name, colors in themes.items():
        for text_role in TEXT_ROLES:
            for surface_role in SURFACE_ROLES:
                r = ratio(colors[text_role], colors[surface_role])
                status = "OK  " if r >= 4.5 else "FAIL"
                if r < 4.5:
                    failures += 1
                print(f"{status} {name:6} {text_role:15} on {surface_role:15} {r:5.2f}:1")
    if failures:
        print(f"{failures} pair(s) below 4.5:1")
        return 1
    print("contrast gate PASS — all text roles >= 4.5:1")
    return 0


if __name__ == "__main__":
    sys.exit(main())
