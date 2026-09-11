#!/usr/bin/env -S v run
// check-contrast.vsh — contrast gate for the Paper/Ink GUI themes, #1097
// (V port of scripts/check-contrast.py).
//
// Reads the token hex values from modules/desktop/theme/tokens.v and asserts
// WCAG 2.1 contrast ratios for every text role on every surface role, in both
// themes. Text roles must clear 4.5:1; failures fail the gate (exit 1).
//
// Usage: v run scripts/check-contrast.vsh
import math
import os

const text_roles = ['text_primary', 'text_secondary']
const surface_roles = ['surface_canvas', 'surface_paper']

// parse_theme extracts `name: '#rrggbb'` pairs from one
// `pub fn <fn_name>() ColorTokens { ... }` block in tokens.v.
fn parse_theme(src string, fn_name string) map[string]string {
	mut colors := map[string]string{}
	marker := 'pub fn ${fn_name}() ColorTokens {'
	start := src.index(marker) or { return colors }
	body := src[start + marker.len..]
	end := body.index('\n}') or { body.len }
	for line in body[..end].split('\n') {
		// strip // comments so disabled tokens never count
		code := line.split('//')[0]
		colon := code.index(':') or { continue }
		name := code[..colon].trim_space()
		rest := code[colon + 1..].trim_space().trim("'").trim('"')
		if name == '' || rest.len != 7 || !rest.starts_with('#') {
			continue
		}
		mut hex_ok := true
		for ch in rest[1..] {
			if !ch.is_hex_digit() {
				hex_ok = false
				break
			}
		}
		if hex_ok {
			colors[name] = rest
		}
	}
	return colors
}

fn channel_lin(v f64) f64 {
	return if v <= 0.03928 { v / 12.92 } else { math.pow((v + 0.055) / 1.055, 2.4) }
}

fn hex_pair(pair string) f64 {
	mut v := 0
	for ch in pair {
		v *= 16
		if ch >= `0` && ch <= `9` {
			v += int(ch - `0`)
		} else if ch >= `a` && ch <= `f` {
			v += int(ch - `a`) + 10
		} else if ch >= `A` && ch <= `F` {
			v += int(ch - `A`) + 10
		}
	}
	return f64(v)
}

fn luminance(hexcode string) f64 {
	r := channel_lin(hex_pair(hexcode[1..3].to_lower()) / 255.0)
	g := channel_lin(hex_pair(hexcode[3..5].to_lower()) / 255.0)
	b := channel_lin(hex_pair(hexcode[5..7].to_lower()) / 255.0)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
}

fn ratio(fg string, bg string) f64 {
	l1 := luminance(fg)
	l2 := luminance(bg)
	hi := if l1 > l2 { l1 } else { l2 }
	lo := if l1 > l2 { l2 } else { l1 }
	return (hi + 0.05) / (lo + 0.05)
}

fn run() int {
	root := os.dir(os.dir(os.real_path(@FILE)))
	src := os.read_file(os.join_path(root, 'modules', 'desktop', 'theme', 'tokens.v')) or {
		eprintln('cannot read modules/desktop/theme/tokens.v: ${err}')
		return 1
	}
	themes := {
		'paper': parse_theme(src, 'light_colors')
		'ink':   parse_theme(src, 'ink_colors')
	}
	if themes['paper'].len == 0 {
		eprintln('cannot find light_colors in tokens.v')
		return 1
	}
	if themes['ink'].len == 0 {
		eprintln('cannot find ink_colors in tokens.v')
		return 1
	}
	pad := fn (s string, w int) string {
		if s.len >= w {
			return s
		}
		return s + ' '.repeat(w - s.len)
	}
	// pad_left formats a ratio like Python's {r:5.2f} (width 5, right-aligned)
	pad_left := fn (r f64, w int) string {
		num := '${r:.2f}'
		if num.len >= w {
			return num
		}
		return ' '.repeat(w - num.len) + num
	}
	mut failures := 0
	for name in ['paper', 'ink'] {
		colors := themes[name].clone()
		for text_role in text_roles {
			for surface_role in surface_roles {
				r := ratio(colors[text_role], colors[surface_role])
				status := if r >= 4.5 { 'OK  ' } else { 'FAIL' }
				if r < 4.5 {
					failures++
				}
				println('${status} ${pad(name, 6)} ${pad(text_role, 15)} on ${pad(surface_role, 15)} ${pad_left(r, 5)}:1')
			}
		}
	}
	if failures > 0 {
		println('${failures} pair(s) below 4.5:1')
		return 1
	}
	println('contrast gate PASS — all text roles >= 4.5:1')
	return 0
}

fn main() {
	exit(run())
}
