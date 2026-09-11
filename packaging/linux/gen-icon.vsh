#!/usr/bin/env -S v run
// Deterministic Paper Co. launcher icon generator (#1057/#1116).
//
// Renders the agent-toolkit-desktop icon from a fixed 32x32 pixel grid —
// an ink-outlined manila envelope with a brass seal on a warm paper tile —
// in the established pixel-art language (docs/desktop/DESIGN.md).
//
// Outputs nearest-neighbour PNGs at standard hicolor sizes plus one
// scalable SVG. Stdlib only (`compress.zlib`, `hash.crc32`); fully
// deterministic (no randomness, no fonts).
//
// Fidelity note: the SVG is byte-identical to the retired gen-icon.py.
// PNG bytes may differ (V's deflate encoder is not zlib level 9) but decode
// to identical pixels — the equivalence proof decodes both and compares
// buffers (see PR description). Committed icons are NOT regenerated here.
//
// Usage: ./packaging/linux/gen-icon.vsh [OUT_DIR]   (default: packaging/linux/icons)

import compress.zlib
import hash.crc32
import math
import os

const w = 32
const h = 32
const size_tag = 'agent-toolkit-desktop'
const sizes = [16, 24, 32, 48, 64, 128, 256, 512]

struct Pixel {
	r u8
	g u8
	b u8
	a u8
}

const transparent = Pixel{0, 0, 0, 0}
const paper = Pixel{246, 239, 227, 255} // warm paper tile
const manila = Pixel{217, 183, 121, 255} // envelope body
const manila_dark = Pixel{201, 164, 95, 255} // envelope flap
const brass = Pixel{154, 100, 22, 255} // seal
const ink = Pixel{37, 42, 45, 255} // outline

fn in_rounded(x int, y int, x0 int, y0 int, x1 int, y1 int, r int) bool {
	if x < x0 || x > x1 || y < y0 || y > y1 {
		return false
	}
	// Test ONLY the relevant corner's circle — testing all four rejects
	// valid corner pixels against the opposite corners (#1165 review).
	cx := if x < x0 + r { x0 + r } else if x > x1 - r { x1 - r } else { x }
	cy := if y < y0 + r { y0 + r } else if y > y1 - r { y1 - r } else { y }
	if (x < x0 + r || x > x1 - r) && (y < y0 + r || y > y1 - r) {
		dx := x - cx
		dy := y - cy
		return dx * dx + dy * dy <= r * r
	}
	return true
}

fn build_grid() [][]Pixel {
	mut g := [][]Pixel{len: h, init: []Pixel{len: w, init: transparent}}
	// rounded paper tile (1..30) — gentle r=3 cut-corner style
	for y in 0 .. h {
		for x in 0 .. w {
			if in_rounded(x, y, 1, 1, 30, 30, 3) {
				g[y][x] = paper
			}
		}
	}
	// envelope rect (4,8)-(27,24) — larger envelope, tighter composition
	ex0, ey0, ex1, ey1 := 4, 8, 27, 24
	for y in ey0 .. ey1 + 1 {
		for x in ex0 .. ex1 + 1 {
			g[y][x] = manila
		}
	}
	// flap: darker region above the fold, connected 2px ink fold edges
	cx := 15.5
	for y in ey0 + 1 .. ey1 {
		t := f64(y - ey0) / f64(ey1 - ey0)
		lx := f64(ex0 + 1) + t * (cx - f64(ex0 + 1))
		rx := f64(ex1 - 1) - t * (f64(ex1 - 1) - cx)
		for x in ex0 + 1 .. ex1 {
			if f64(x) >= lx - 0.6 && f64(x) <= rx + 0.6 {
				g[y][x] = manila_dark
			}
		}
		// connected fold edges (2px wide, rounded to the grid).
		// No exact-.5 values occur here (proven: 21k mod 32 never hits 16
		// for the y range), so int(math.round()) matches Python round().
		for side in ['l', 'r'] {
			edge := if side == 'l' { lx } else { rx }
			mut xi := int(math.round(edge))
			if side == 'r' {
				if xi > ex1 - 2 {
					xi = ex1 - 2
				}
			} else {
				if xi < ex0 + 1 {
					xi = ex0 + 1
				}
			}
			g[y][xi] = ink
			if side == 'l' {
				g[y][xi + 1] = ink
			} else {
				g[y][xi - 1] = ink
			}
		}
	}
	// envelope ink outline
	for x in ex0 .. ex1 + 1 {
		g[ey0][x] = ink
		g[ey1][x] = ink
	}
	for y in ey0 .. ey1 + 1 {
		g[y][ex0] = ink
		g[y][ex1] = ink
	}
	// brass seal (3x3) centered under the fold
	for y in 18 .. 21 {
		for x in 14 .. 17 {
			g[y][x] = brass
		}
	}
	g[19][15] = paper // tiny highlight dot on the seal
	return g
}

fn scale_nearest(g [][]Pixel, size int) [][]Pixel {
	fx := f64(w) / f64(size)
	fy := f64(h) / f64(size)
	mut out := [][]Pixel{len: size}
	for y in 0 .. size {
		mut row := []Pixel{len: size}
		mut sy := int(f64(y) * fy)
		if sy > h - 1 {
			sy = h - 1
		}
		for x in 0 .. size {
			mut sx := int(f64(x) * fx)
			if sx > w - 1 {
				sx = w - 1
			}
			row[x] = g[sy][sx]
		}
		out[y] = row
	}
	return out
}

fn u32be(v u32) []u8 {
	return [u8(v >> 24), u8((v >> 16) & 0xFF), u8((v >> 8) & 0xFF), u8(v & 0xFF)]
}

// chunk builds a PNG chunk (CRC covers tag+data, like PNG).
fn chunk(tag string, data []u8) []u8 {
	mut c := u32be(u32(data.len))
	c << tag.bytes()
	c << data
	mut crc_input := tag.bytes()
	crc_input << data
	c << u32be(crc32.sum(crc_input))
	return c
}

fn write_png(path string, grid [][]Pixel) {
	hh := grid.len
	ww := grid[0].len
	mut raw := []u8{}
	for row in grid {
		raw << 0
		for p in row {
			raw << [p.r, p.g, p.b, p.a]
		}
	}
	idat := zlib.compress(raw) or {
		eprintln('zlib compress failed: ${err}')
		exit(1)
	}
	mut png := '\x89PNG\r\n\x1a\n'.bytes()
	png << chunk('IHDR', [u8(ww >> 24), u8((ww >> 16) & 0xFF), u8((ww >> 8) & 0xFF), u8(ww & 0xFF), u8(hh >> 24), u8((hh >> 16) & 0xFF), u8((hh >> 8) & 0xFF), u8(hh & 0xFF),
		8, 6, 0, 0, 0])
	png << chunk('IDAT', idat)
	png << chunk('IEND', []u8{})
	os.write_file_array(path, png) or {
		eprintln('cannot write ${path}: ${err}')
		exit(1)
	}
}

fn write_svg(path string, grid [][]Pixel) {
	// merge horizontal runs; 1 svg unit per source pixel, viewBox 0 0 W H
	mut rects := []string{}
	for y, row in grid {
		mut x := 0
		for x < w {
			c := row[x]
			if c == transparent {
				x++
				continue
			}
			x0 := x
			for x < w && row[x] == c {
				x++
			}
			rects << '<rect x="${x0}" y="${y}" width="${x - x0}" height="1" fill="rgb(${c.r},${c.g},${c.b})"/>'
		}
	}
	body := rects.join('\n')
	os.write_file(path, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${w} ${h}" shape-rendering="crispEdges" width="${w}" height="${h}">\n${body}\n</svg>\n') or {
		eprintln('cannot write ${path}: ${err}')
		exit(1)
	}
}

fn repo_root() string {
	mut d := os.dir(@FILE)
	// packaging/linux/ -> repo root
	d = os.dir(d)
	d = os.dir(d)
	if os.is_file(os.join_path(d, 'VERSION')) {
		return d
	}
	return os.getwd()
}

fn main() {
	// os.args[0] is always the compiled binary path (`v run` compiles the
	// script next to its source); some V versions additionally pass the
	// script path next. Drop both — only real user args remain.
	mut args := os.args.clone()
	if args.len > 0 {
		args = args[1..].clone()
	}
	if args.len > 0 && args[0].ends_with('.vsh') {
		args = args[1..].clone()
	}
	root := repo_root()
	out := if args.len > 0 { args[0] } else { os.join_path(root, 'packaging', 'linux', 'icons') }
	os.mkdir_all(out) or {
		eprintln('cannot create ${out}: ${err}')
		exit(1)
	}
	grid := build_grid()
	for s in sizes {
		write_png(os.join_path(out, '${size_tag}-${s}.png'), scale_nearest(grid, s))
	}
	write_svg(os.join_path(out, '${size_tag}-scalable.svg'), grid)
	mut size_strs := []string{}
	for s in sizes {
		size_strs << '${s}'
	}
	println('icons written to ${out}: ${size_strs.join(', ')} + scalable.svg')
}
