module main

import desktop.theme
import gg

// ── F1 theme bridge — the ONLY path from theme tokens to renderer color ──
// The renderer (main.v) must not contain raw hex or duplicate color constants:
// every color below resolves from theme.ColorTokens. main.v keeps thin
// `const col_*` aliases (the compiler requires consts for the shared palette),
// each initialized from one of these resolvers.
//
// Active snapshot: Paper (plan section 8). Ink/Night Shift flips in ui_theme()
// once the appearance toggle lands; dark roles already exist in tokens.v.

// ui_theme returns the active design-system snapshot (Paper by default).
fn ui_theme() theme.Theme {
	return theme.light_theme()
}

// hex_to_gg parses '#RRGGBB' into an opaque gg.Color.
// Malformed input (wrong shape OR non-hex digits — V's string.u32()
// returns 0 on bad digits) falls back to opaque magenta so token typos
// scream instead of rendering as a subtle near-black.
fn hex_to_gg(hex string) gg.Color {
	if hex.len == 7 && hex[0] == `#` {
		valid := true
		for i in 1 .. 7 {
			c := hex[i]
			if !(c >= `0` && c <= `9`) && !(c >= `a` && c <= `f`) && !(c >= `A` && c <= `F`) {
				valid = false
				break
			}
		}
		if valid {
			r := u8(('0x' + hex[1..3]).u32())
			g := u8(('0x' + hex[3..5]).u32())
			b := u8(('0x' + hex[5..7]).u32())
			return gg.rgb(r, g, b)
		}
	}
	return gg.rgb(u8(255), u8(0), u8(255))
}

// mix blends two resolved colors (t in 0..1 toward b). Used only to derive
// quiet structural tones (hairlines, hover) from the approved roles —
// no new hues enter the renderer through this path.
fn mix(a gg.Color, b gg.Color, t f32) gg.Color {
	cl := if t < 0.0 {
		0.0
	} else if t > 1.0 {
		1.0
	} else {
		t
	}
	return gg.rgb(u8(f32(a.r) + (f32(b.r) - f32(a.r)) * cl), u8(f32(a.g) + (f32(b.g) - f32(a.g)) * cl), u8(f32(a.b) + (f32(b.b) - f32(a.b)) * cl))
}

// tint re-bases an already-resolved token color at a new alpha for washes,
// grain, shadows, and highlights. Hue always comes from the theme.
pub fn tint(c gg.Color, alpha u8) gg.Color {
	return gg.Color{
		r: c.r
		g: c.g
		b: c.b
		a: alpha
	}
}

// ── Canonical bridge: theme.Theme → gg.Color, one fn per plan section 8 role ──
pub fn ui_canvas(t theme.Theme) gg.Color {
	return hex_to_gg(t.colors.surface_canvas)
}

pub fn ui_paper(t theme.Theme) gg.Color {
	return hex_to_gg(t.colors.surface_paper)
}

pub fn ui_cabinet(t theme.Theme) gg.Color {
	return hex_to_gg(t.colors.surface_cabinet)
}

pub fn ui_text(t theme.Theme) gg.Color {
	return hex_to_gg(t.colors.text_primary)
}

pub fn ui_muted(t theme.Theme) gg.Color {
	return hex_to_gg(t.colors.text_secondary)
}

pub fn ui_selection(t theme.Theme) gg.Color {
	return hex_to_gg(t.colors.signal_selection)
}

pub fn ui_success(t theme.Theme) gg.Color {
	return hex_to_gg(t.colors.signal_success)
}

pub fn ui_danger(t theme.Theme) gg.Color {
	return hex_to_gg(t.colors.signal_danger)
}

pub fn ui_on_cabinet(t theme.Theme) gg.Color {
	return hex_to_gg(t.colors.text_on_cabinet)
}

// ── Derived structural tones (theme-resolved mixes, no new hues) ──
// ui_line_paper is the quiet 1px rule on paper surfaces (replaces #D1C7B3).
pub fn ui_line_paper() gg.Color {
	return mix(ui_muted(ui_theme()), ui_paper(ui_theme()), 0.65)
}

// ui_line_cabinet is the 1px rule on dark cabinet surfaces (replaces #343434).
pub fn ui_line_cabinet() gg.Color {
	return mix(ui_muted(ui_theme()), ui_cabinet(ui_theme()), 0.40)
}

// ui_selection_hover lightens selection toward paper for hover fills so the
// hover state stays distinguishable without a second amber constant.
pub fn ui_selection_hover() gg.Color {
	return mix(ui_selection(ui_theme()), ui_paper(ui_theme()), 0.35)
}

// ui_hover_tint is the faint row-hover wash on paper (replaces #F0E9DA).
pub fn ui_hover_tint() gg.Color {
	return tint(ui_selection(ui_theme()), 26)
}
