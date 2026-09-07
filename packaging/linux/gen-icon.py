#!/usr/bin/env python3
"""Deterministic Paper Co. launcher icon generator (#1057/#1116).

Renders the agent-toolkit-desktop icon from a fixed 32x32 pixel grid —
an ink-outlined manila envelope with a brass seal on a warm paper tile —
in the established pixel-art language (docs/desktop/DESIGN.md).

Outputs nearest-neighbour PNGs at standard hicolor sizes plus one
scalable SVG. Stdlib only; fully deterministic (no randomness, no fonts).
"""
import struct
import sys
import zlib
from pathlib import Path

W = H = 32
TRANSPARENT = (0, 0, 0, 0)
PAPER = (246, 239, 227, 255)      # warm paper tile
PAPER_EDGE = (229, 217, 195, 255) # subtle tile edge
MANILA = (217, 183, 121, 255)     # envelope body
MANILA_DARK = (201, 164, 95, 255) # envelope flap
BRASS = (154, 100, 22, 255)       # seal
INK = (37, 42, 45, 255)           # outline

SIZE_TAG = "agent-toolkit-desktop"
SIZES = [16, 24, 32, 48, 64, 128, 256, 512]


def in_rounded(x, y, x0, y0, x1, y1, r):
    if x < x0 or x > x1 or y < y0 or y > y1:
        return False
    # corner circle centers
    for cx, cy in ((x0 + r, y0 + r), (x1 - r, y0 + r), (x0 + r, y1 - r), (x1 - r, y1 - r)):
        in_corner_zone = (x < x0 + r or x > x1 - r) and (y < y0 + r or y > y1 - r)
        if in_corner_zone:
            if (x - cx) ** 2 + (y - cy) ** 2 > r * r:
                return False
    return True


def build_grid():
    g = [[TRANSPARENT] * W for _ in range(H)]
    # rounded paper tile (1..30) — gentle r=3 cut-corner style
    for y in range(H):
        for x in range(W):
            if in_rounded(x, y, 1, 1, 30, 30, 3):
                g[y][x] = PAPER
    # envelope rect (4,8)-(27,24) — larger envelope, tighter composition
    ex0, ey0, ex1, ey1 = 4, 8, 27, 24
    for y in range(ey0, ey1 + 1):
        for x in range(ex0, ex1 + 1):
            g[y][x] = MANILA
    # flap: darker region above the fold, connected 2px ink fold edges
    cx = 15.5
    for y in range(ey0 + 1, ey1):
        t = (y - ey0) / (ey1 - ey0)
        lx = ex0 + 1 + t * (cx - (ex0 + 1))
        rx = ex1 - 1 - t * ((ex1 - 1) - cx)
        for x in range(ex0 + 1, ex1):
            if lx - 0.6 <= x <= rx + 0.6:
                g[y][x] = MANILA_DARK
        # connected fold edges (2px wide, rounded to the grid)
        for side, edge in (("l", lx), ("r", rx)):
            xi = int(round(edge))
            if side == "r":
                xi = min(xi, ex1 - 2)
            else:
                xi = max(xi, ex0 + 1)
            g[y][xi] = INK
            g[y][xi + 1 if side == "l" else xi - 1] = INK
    # envelope ink outline
    for x in range(ex0, ex1 + 1):
        g[ey0][x] = INK
        g[ey1][x] = INK
    for y in range(ey0, ey1 + 1):
        g[y][ex0] = INK
        g[y][ex1] = INK
    # brass seal (3x3) centered under the fold
    for y in range(18, 21):
        for x in range(14, 17):
            g[y][x] = BRASS
    g[19][15] = PAPER  # tiny highlight dot on the seal
    return g


def scale_nearest(g, size):
    fx, fy = W / size, H / size
    out = []
    for y in range(size):
        row = []
        sy = min(H - 1, int(y * fy))
        for x in range(size):
            sx = min(W - 1, int(x * fx))
            row.append(g[sy][sx])
        out.append(row)
    return out


def write_png(path, grid):
    h, w = len(grid), len(grid[0])
    raw = b""
    for row in grid:
        raw += b"\x00" + b"".join(struct.pack("4B", *px) for px in row)

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    Path(path).write_bytes(png)


def write_svg(path, grid):
    # merge horizontal runs; 1 svg unit per source pixel, viewBox 0 0 W H
    rects = []
    for y, row in enumerate(grid):
        x = 0
        while x < W:
            c = row[x]
            if c == TRANSPARENT:
                x += 1
                continue
            x0 = x
            while x < W and row[x] == c:
                x += 1
            rects.append(f'<rect x="{x0}" y="{y}" width="{x - x0}" height="1" fill="rgb({c[0]},{c[1]},{c[2]})"/>')
    body = "\n".join(rects)
    Path(path).write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" '
        f'shape-rendering="crispEdges" width="{W}" height="{H}">\n{body}\n</svg>\n'
    )


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent / "icons"
    out.mkdir(parents=True, exist_ok=True)
    grid = build_grid()
    for s in SIZES:
        write_png(out / f"{SIZE_TAG}-{s}.png", scale_nearest(grid, s))
    write_svg(out / f"{SIZE_TAG}-scalable.svg", grid)
    print(f"icons written to {out}: {', '.join(str(s) for s in SIZES)} + scalable.svg")


if __name__ == "__main__":
    main()
