module main

import desktop.theme
import gg
import os

// ── Appearance — product-level GUI theme (Paper/Ink/System, #1097) ──
// The theme MODULE stays generic (light/dark kinds, additive Ink values);
// this product layer maps user choice → concrete snapshot. Paper and Ink
// resolve to fixed snapshots; System probes the OS at startup (best-effort,
// read-only, fixed argv) and falls back to Paper when unknown.
pub enum Appearance {
	paper
	ink
	system
}

pub fn appearance_from_string(s string) Appearance {
	match s.trim_space().to_lower() {
		'ink' {
			return .ink
		}
		'system' {
			return .system
		}
		else {
			return .paper
		}
	}
}

// appearance_theme resolves a choice to a concrete snapshot (no IO except
// the System probe, which reads only files/env and never spawns a process).
pub fn appearance_theme(a Appearance) theme.Theme {
	match a {
		.paper {
			return theme.light_theme()
		}
		.ink {
			return theme.ink_theme()
		}
		.system {
			if detect_system_dark() {
				return theme.ink_theme()
			}
			return theme.light_theme()
		}
	}
}

// detect_system_dark probes the OS dark-mode preference without spawning
// child processes (Engine-authority rule: no CLI shell-outs — file/env reads
// only). Unknown, unreadable, or any failure → false (honest Paper fallback).
fn detect_system_dark() bool {
	// explicit override always wins (headless CI, user force)
	if os.getenv('ATK_APPEARANCE').trim_space().to_lower() == 'dark' {
		return true
	}
	if os.getenv('ATK_APPEARANCE').trim_space().to_lower() == 'light' {
		return false
	}
	$if linux {
		// GTK theme name convention: '*-dark' / '*:dark' (files + env, no exec)
		gtk_theme := os.getenv('GTK_THEME').trim_space().to_lower()
		if gtk_theme.ends_with('-dark') || gtk_theme.ends_with(':dark') {
			return true
		}
		settings := os.read_file(os.home_dir() + '/.config/gtk-3.0/settings.ini') or { '' }
		for line in settings.split('\n') {
			l := line.trim_space().to_lower()
			if l.starts_with('gtk-application-prefer-dark-theme') && l.contains('true') {
				return true
			}
			if l.starts_with('gtk-theme-name') && (l.contains('-dark') || l.contains(':dark')) {
				return true
			}
		}
		return false
	}
	// macOS leaves no exec-free readable signal (binary plist); fall back to
	// Paper rather than shell out to `defaults`. Documented, honest default.
	return false
}

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
		mut valid := true
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
// These take the theme as a parameter (instead of reading the ambient
// ui_theme()) so the appearance layer can resolve them per theme at switch
// time; the startup consts keep passing ui_theme() explicitly (same values).
// ui_line_paper is the quiet 1px rule on paper surfaces (replaces #D1C7B3).
pub fn ui_line_paper(t theme.Theme) gg.Color {
	return mix(ui_muted(t), ui_paper(t), 0.65)
}

// ui_line_cabinet is the 1px rule on dark cabinet surfaces (replaces #343434).
pub fn ui_line_cabinet(t theme.Theme) gg.Color {
	return mix(ui_muted(t), ui_cabinet(t), 0.40)
}

// ui_selection_hover lightens selection toward paper for hover fills so the
// hover state stays distinguishable without a second amber constant.
pub fn ui_selection_hover(t theme.Theme) gg.Color {
	return mix(ui_selection(t), ui_paper(t), 0.35)
}

// ui_hover_tint is the faint row-hover wash on paper (replaces #F0E9DA).
pub fn ui_hover_tint(t theme.Theme) gg.Color {
	return tint(ui_selection(t), 26)
}

// apply_appearance resolves a product Appearance into the app-owned panel
// palette (<1 frame, no IO) and records the choice. Panel draw code reads
// app.pnl_*; chrome (header/dock/status/terminal) keeps the startup consts.
pub fn (mut app GuiApp) apply_appearance(a Appearance) {
	app.appearance = a
	t := appearance_theme(a)
	// cache the resolved kind — per-frame panel code (pixel_panel, …) branches
	// on this instead of re-probing the OS, so System costs one probe total.
	app.appearance_dark = t.kind == .dark
	// bg and card share the sheet role today (panel background fills were
	// cream50/paper by construction); separate fields so Ink can diverge
	// them later without touching call sites.
	app.pnl_bg = ui_paper(t)
	app.pnl_card = ui_paper(t)
	app.pnl_card_sel = ui_canvas(t)
	app.pnl_hover = ui_hover_tint(t)
	app.pnl_border = ui_line_paper(t)
	app.pnl_border_hi = ui_selection(t)
	app.pnl_text = ui_text(t)
	app.pnl_text_mut = ui_muted(t)
	app.pnl_text_fnt = ui_muted(t)
	app.pnl_select = ui_selection(t)
	app.pnl_success = ui_success(t)
	app.pnl_danger = ui_danger(t)
	app.pnl_select_hover = ui_selection_hover(t)
}
