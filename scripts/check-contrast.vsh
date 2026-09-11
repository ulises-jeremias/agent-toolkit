#!/usr/bin/env -S v run
// Contrast gate for the Paper/Ink GUI themes (#1097).
//
// Reads the token hex values from modules/desktop/theme/tokens.v and asserts
// WCAG 2.1 contrast ratios for every text role on every surface role, in both
// themes. Text roles must clear 4.5:1; failures fail the gate (exit 1).
//
// Usage: ./scripts/check-contrast.vsh   (from repo root or any subdir)

import math
import os

const text_roles = ['text_primary', 'text_secondary']
const surface_roles = ['surface_canvas', 'surface_paper']

fn repo_root() string {
	mut d := os.dir(@FILE)
	// scripts/ -> repo root
	d = os.dir(d)
	if os.is_file(os.join_path(d, 'VERSION')) {
		return d
	}
	return os.getwd()
}

fn is_word(s string) bool {
	if s.len == 0 {
		return false
	}
	for c in s {
		if !(c.is_alnum() || c == `_`) {
			return false
		}
	}
	return true
}

fn is_hex6(s string) bool {
	if s.len != 7 || s[0] != `#` {
		return false
	}
	for c in s[1..] {
		if !c.is_hex_digit() {
			return false
		}
	}
	return true
}

// parse_theme extracts `name: '#RRGGBB'` pairs from a `pub fn <name>() ColorTokens`
// block, mirroring the retired check-contrast.py regex
// `(\w+):\s*'(#[0-9A-Fa-f]{6})'` scoped to the first `\n}` terminator.
fn parse_theme(src string, fn_name string) map[string]string {
	mut colors := map[string]string{}
	marker := 'pub fn ${fn_name}() ColorTokens {'
	start := src.index(marker) or { return colors }
	rest := src[start + marker.len..]
	end := rest.index('\n}') or { return colors }
	for line in rest[..end].split_into_lines() {
		parts := line.split(':')
		if parts.len < 2 {
			continue
		}
		name := parts[0].trim_space()
		val := parts[1..].join(':').trim_space()
		// val is `'#RRGGBB'` (9 chars); store `#RRGGBB` like the old regex group.
		if is_word(name) && val.len == 9 && val[0] == `'` && val[8] == `'` && is_hex6(val[1..8]) {
			colors[name] = val[1..8]
		}
	}
	return colors
}

fn linearize(c f64) f64 {
	return if c <= 0.03928 { c / 12.92 } else { math.pow((c + 0.055) / 1.055, 2.4) }
}

fn luminance(hexcode string) f64 {
	r := int(hexcode[1..3].parse_uint(16, 8) or { 0 }) / 255.0
	g := int(hexcode[3..5].parse_uint(16, 8) or { 0 }) / 255.0
	b := int(hexcode[5..7].parse_uint(16, 8) or { 0 }) / 255.0
	return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
}

fn ratio(fg string, bg string) f64 {
	l1 := luminance(fg)
	l2 := luminance(bg)
	hi := if l1 > l2 { l1 } else { l2 }
	lo := if l1 < l2 { l1 } else { l2 }
	return (hi + 0.05) / (lo + 0.05)
}

fn pad(s string, width int) string {
	if s.len >= width {
		return s
	}
	return s + ' '.repeat(width - s.len)
}

// pad_left prepends spaces (Python `{r:5.2f}`-style numeric padding).
fn pad_left(s string, width int) string {
	if s.len >= width {
		return s
	}
	return ' '.repeat(width - s.len) + s
}

fn main() {
	tokens_path := os.join_path(repo_root(), 'modules', 'desktop', 'theme', 'tokens.v')
	src := os.read_file(tokens_path) or {
		eprintln('cannot read ${tokens_path}: ${err}')
		exit(1)
	}
	themes := {
		'paper': parse_theme(src, 'light_colors')
		'ink':   parse_theme(src, 'ink_colors')
	}
	mut failures := 0
	for name, colors in themes {
		for text_role in text_roles {
			for surface_role in surface_roles {
				fg := colors[text_role] or {
					eprintln('cannot find ${text_role} in ${name} theme')
					exit(1)
				}
				bg := colors[surface_role] or {
					eprintln('cannot find ${surface_role} in ${name} theme')
					exit(1)
				}
				r := ratio(fg, bg)
				status := if r >= 4.5 { 'OK  ' } else { 'FAIL' }
				if r < 4.5 {
					failures++
				}
				// Python used `{r:5.2f}` — left-pad the fixed-point form to width 5.
				ratio_s := '${r:.2f}'
				println('${status} ${pad(name, 6)} ${pad(text_role, 15)} on ${pad(surface_role, 15)} ${pad_left(ratio_s, 5)}:1')
			}
		}
	}
	if failures > 0 {
		println('${failures} pair(s) below 4.5:1')
		exit(1)
	}
	println('contrast gate PASS — all text roles >= 4.5:1')
}
