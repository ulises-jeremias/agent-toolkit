#!/usr/bin/env python3
"""ansi2png.py — render ANSI terminal output (from `tmux capture-pane -e` or
`herdr pane read`) to a PNG image using pyte (terminal emulator) + Pillow.

Usage:
    cat pane.ansi | python3 ansi2png.py > pane.png
    python3 ansi2png.py pane.ansi pane.png [--cols N] [--rows N] [--theme dark]

Palette matches agent-toolkit branding: dark #050510 background.
"""

import argparse
import sys

import pyte
from PIL import Image, ImageDraw, ImageFont

# 16-color palette (roughly matches the cyber-terminal theme of static/*.svg)
PALETTE = {
    "black": (10, 10, 32),
    "red": (255, 95, 87),
    "green": (0, 255, 136),
    "brown": (234, 179, 8),
    "blue": (0, 128, 255),
    "magenta": (153, 69, 255),
    "cyan": (0, 212, 255),
    "white": (200, 200, 232),
    "brightblack": (74, 74, 138),
    "brightred": (255, 127, 120),
    "brightgreen": (95, 255, 170),
    "brightbrown": (255, 210, 90),
    "brightblue": (120, 180, 255),
    "brightmagenta": (200, 130, 255),
    "brightcyan": (130, 235, 255),
    "brightwhite": (245, 245, 255),
}
DEFAULT_FG = (200, 200, 232)
DEFAULT_BG = (5, 5, 16)  # #050510


def resolve(color, bright_prefix="bright"):
    if not color or color == "default":
        return None
    c = color.lower()
    if c in PALETTE:
        return PALETTE[c]
    # pyte stores 256/24-bit colors as hex strings like 'aabbcc' or 'rrggbb'
    try:
        if len(c) == 6 and all(ch in "0123456789abcdef" for ch in c):
            return tuple(int(c[i : i + 2], 16) for i in (0, 2, 4))
    except Exception:
        pass
    return PALETTE.get(bright_prefix + c) or PALETTE.get(c)


def find_font(px):
    candidates = [
        "/usr/share/fonts/TTF/DejaVuSansMono.ttf",
        "/usr/share/fonts/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/TTF/DejaVuSansMono-Bold.ttf",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, px)
        except Exception:
            continue
    return ImageFont.load_default()


def render(screen, cell_w=9, cell_h=18, theme_bg=DEFAULT_BG, theme_fg=DEFAULT_FG):
    cols, rows = screen.columns, screen.lines
    W, H = cols * cell_w, rows * cell_h
    img = Image.new("RGB", (W, H), theme_bg)
    draw = ImageDraw.Draw(img)
    font = find_font(int(cell_h * 0.82))
    for y in range(rows):
        line = screen.buffer[y]
        for x in range(cols):
            ch = line[x]
            fg = resolve(ch.fg) or theme_fg
            bg = resolve(ch.bg) or theme_bg
            if ch.reverse:
                fg, bg = bg, fg
            if ch.bg and ch.bg != "default":
                draw.rectangle(
                    [x * cell_w, y * cell_h, (x + 1) * cell_w - 1, (y + 1) * cell_h - 1],
                    fill=bg,
                )
            if ch.data and ch.data != " ":
                draw.text((x * cell_w + 1, y * cell_h + 1), ch.data, fill=fg, font=font)
    return img


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("infile", nargs="?", default="-")
    ap.add_argument("outfile", nargs="?", default="-")
    ap.add_argument("--cols", type=int, default=120)
    ap.add_argument("--rows", type=int, default=40)
    ap.add_argument("--cell", type=int, default=18, help="row height in px")
    args = ap.parse_args()

    data = sys.stdin.buffer.read() if args.infile == "-" else open(args.infile, "rb").read()
    text = data.decode("utf-8", errors="replace")
    screen = pyte.Screen(args.cols, args.rows)
    stream = pyte.ByteStream(screen)
    stream.feed(text.encode("utf-8", errors="replace"))
    img = render(screen, cell_w=int(args.cell * 0.55), cell_h=args.cell)
    if args.outfile == "-":
        img.save(sys.stdout.buffer, "PNG")
    else:
        img.save(args.outfile, "PNG")


if __name__ == "__main__":
    main()
