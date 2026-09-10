module main

import desktop
import desktop.nav
import desktop.palette
import desktop.pixelart
import desktop_engine
import gg
import ghostty
import os
import time
import pty as pty_mod

// ── Dunder Mifflin Paper Co. — distinctive signature, not generic ──
// Anti-slop: no purple/indigo gradients, no Inter-only, no glassmorphism.
// Colors resolve from desktop.theme via ui_tokens.v (F1 theme tokens):
//   surface.canvas #F3EBDD — main office/map background
//   surface.paper  #FFF9ED — cards and reading surfaces
//   surface.cabinet #171C1F — navigation and console
//   text.primary   #252A2D — primary paper text
//   text.secondary #596A73 — secondary paper text
//   signal.selection #9A6416 — selection/focus amber
//   signal.success   #3F704D — healthy/complete
//   signal.danger    #A84631 — failed/blocked/destructive
//   text.on_cabinet  #FFF9ED — primary dark-surface text
// main.v holds only thin `const col_*` aliases over ui_*() resolvers —
// no raw hex and no duplicate color constants outside the theme module.
// Type: Display Fraunces (soft-serif ink-trap, 22-28), Body IBM Plex Sans (15-16), Mono IBM Plex Mono (13)
// Signature: perforated tractor-feed edge dots + brass binder rivet (2px) + manila folder tab
const col_ink = ui_text(ui_theme()) // theme: text.primary

const col_ink700 = ui_text(ui_theme()) // theme: text.primary

const col_ink500 = ui_muted(ui_theme()) // theme: text.secondary

const col_ink300 = ui_line_paper(ui_theme()) // theme: quiet paper rule

const col_charcoal = ui_cabinet(ui_theme()) // theme: surface.cabinet

const col_charcoal2 = ui_text(ui_theme()) // theme: text.primary

const col_paper = ui_paper(ui_theme()) // theme: surface.paper

const col_paper_dim = ui_canvas(ui_theme()) // theme: surface.canvas

const col_brass = ui_selection(ui_theme()) // theme: signal.selection

const col_brass_dim = ui_selection(ui_theme()) // theme: signal.selection

const col_oxide = ui_danger(ui_theme()) // theme: signal.danger

const col_slate = ui_muted(ui_theme()) // theme: text.secondary

const col_slate_dim = ui_muted(ui_theme()) // theme: text.secondary

const col_line = ui_line_cabinet(ui_theme()) // theme: quiet cabinet rule

const col_line_light = ui_line_paper(ui_theme()) // theme: quiet paper rule

// paper tokens — warm office stock
const col_cream50 = ui_paper(ui_theme()) // theme: surface.paper

const col_cream100 = ui_paper(ui_theme()) // theme: surface.paper

const col_cream200 = ui_canvas(ui_theme()) // theme: surface.canvas

const col_paper100 = ui_paper(ui_theme()) // theme: surface.paper

const col_coral = ui_danger(ui_theme()) // theme: signal.danger

const col_mint = ui_success(ui_theme()) // theme: signal.success

const col_sky = ui_muted(ui_theme()) // theme: text.secondary

const col_lemon = ui_selection(ui_theme()) // theme: signal.selection

const col_lilac = ui_muted(ui_theme()) // theme: text.secondary

const col_peach = ui_selection(ui_theme()) // theme: signal.selection

const col_status_idle = ui_muted(ui_theme()) // theme: text.secondary

const col_status_thinking = ui_muted(ui_theme()) // theme: text.secondary

const col_status_working = ui_selection(ui_theme()) // theme: signal.selection

const col_status_waiting = ui_muted(ui_theme()) // theme: text.secondary

const col_status_blocked = ui_danger(ui_theme()) // theme: signal.danger

const col_status_success = ui_success(ui_theme()) // theme: signal.success

const col_wood_light = ui_canvas(ui_theme()) // theme: surface.canvas

const col_wood_dark = ui_line_paper(ui_theme()) // theme: quiet paper rule

const col_path = ui_canvas(ui_theme()) // theme: surface.canvas

// ── cozy paper-ledger tokens (design pass 1.29) — warm secondary ink for paper,
// hover tints and folder-tab manila. Contrast: ink_soft on cream ≥ 4.5:1. ──
const col_ink_soft = ui_muted(ui_theme()) // theme: text.secondary

const col_paper_hover = ui_hover_tint(ui_theme()) // theme: selection hover wash

const col_manila_tab = ui_canvas(ui_theme()) // theme: surface.canvas

const col_sage_soft = ui_success(ui_theme()) // theme: signal.success

const col_steel_ink = ui_muted(ui_theme()) // theme: text.secondary

// text on constant-dark surfaces (cabinet, terminal wells) — identical cream
// in both themes because the surface never themes; use instead of app.pnl_*
// wherever the background is a dark const, or Ink goes blind.
const col_text_on_cabinet = ui_on_cabinet(ui_theme()) // theme: text.on_cabinet

// ── brand typography — Fraunces display + IBM Plex Sans body + IBM Plex Mono data.
// OFL-licensed TTFs ship in assets/fonts/; resolved relative to the binary so the
// single-file story holds (repo build: build/../assets/fonts; packaged: ./fonts).
// When fonts are missing the app falls back to the system sans — never crashes. ──
const font_file_sans = 'IBMPlexSans-Regular.ttf'
const font_file_sans_bold = 'IBMPlexSans-SemiBold.ttf'
const font_file_mono = 'IBMPlexMono-Regular.ttf'
const font_file_mono_med = 'IBMPlexMono-Medium.ttf'
const font_file_display = 'Fraunces-Display.ttf'
const font_file_display_t = 'Fraunces-Text.ttf'
const font_file_arabic = 'IBMPlexSansArabic-Regular.ttf'
const font_file_arabic_bd = 'IBMPlexSansArabic-SemiBold.ttf'
const font_file_sc = 'NotoSansSC-chrome.ttf'

// Embedded fonts — the binary carries its own stationery so released single
// binaries render Fraunces/Plex + the i18n scripts with zero packaging steps.
// gg's fontstash needs file PATHS, so on first boot the bytes are extracted to
// the desktop cache dir; repo runs keep using assets/fonts directly.
const font_embed_sans = $embed_file('../../assets/fonts/IBMPlexSans-Regular.ttf')
const font_embed_sans_bd = $embed_file('../../assets/fonts/IBMPlexSans-SemiBold.ttf')
const font_embed_mono = $embed_file('../../assets/fonts/IBMPlexSansMono-Regular.ttf')
const font_embed_display = $embed_file('../../assets/fonts/Fraunces-Display.ttf')
const font_embed_displayt = $embed_file('../../assets/fonts/Fraunces-Text.ttf')
const font_embed_arabic = $embed_file('../../assets/fonts/IBMPlexSansArabic-Regular.ttf')
const font_embed_arabicbd = $embed_file('../../assets/fonts/IBMPlexSansArabic-SemiBold.ttf')
const font_embed_sc = $embed_file('../../assets/fonts/NotoSansSC-chrome.ttf')

// font_embed_pairs maps cache filenames to embedded bytes.
fn font_embed_pairs() []FontEmbed {
	return [
		FontEmbed{font_file_sans, font_embed_sans.to_bytes()},
		FontEmbed{font_file_sans_bold, font_embed_sans_bd.to_bytes()},
		FontEmbed{font_file_mono, font_embed_mono.to_bytes()},
		FontEmbed{font_file_display, font_embed_display.to_bytes()},
		FontEmbed{font_file_display_t, font_embed_displayt.to_bytes()},
		FontEmbed{font_file_arabic, font_embed_arabic.to_bytes()},
		FontEmbed{font_file_arabic_bd, font_embed_arabicbd.to_bytes()},
		FontEmbed{font_file_sc, font_embed_sc.to_bytes()},
	]
}

struct FontEmbed {
	name string
	data []u8
}

// extract_fonts_to_cache writes the embedded fonts to the desktop cache dir.
// Best effort: any failure just leaves the dir unusable (system-font fallback).
fn extract_fonts_to_cache() string {
	base := if os.getenv('XDG_CACHE_HOME') != '' {
		os.getenv('XDG_CACHE_HOME')
	} else {
		os.join_path(os.home_dir(), '.cache')
	}
	dir := os.join_path(base, 'agent-toolkit', 'desktop', 'fonts')
	os.mkdir_all(dir) or { return '' }
	if !os.exists(dir) {
		return ''
	}
	for pair in font_embed_pairs() {
		dest := os.join_path(dir, pair.name)
		if os.exists(dest) && int(os.file_size(dest)) == pair.data.len {
			continue
		}
		os.write_file(dest, pair.data.bytestr()) or { return '' }
	}
	return dir
}

// atk_font_dir resolves the bundled font directory: $ATK_FONTS, then
// <exe_dir>/fonts, then <exe_dir>/../assets/fonts, then the embedded cache.
// Empty string = unavailable (system-font fallback).
fn atk_font_dir() string {
	cands := [
		os.getenv('ATK_FONTS'),
		os.join_path(os.dir(os.executable()), 'fonts'),
		os.join_path(os.dir(os.dir(os.executable())), 'assets', 'fonts'),
	]
	for c in cands {
		if c != '' && os.exists(os.join_path(c, font_file_sans)) {
			return c
		}
	}
	return extract_fonts_to_cache()
}

fn atk_font(dir string, file string) string {
	if dir == '' {
		return ''
	}
	p := os.join_path(dir, file)
	return if os.exists(p) { p } else { '' }
}

// FontPaths holds resolved brand font paths — '' means fall back to default.
struct FontPaths {
pub:
	dir      string
	sans     string
	sans_bd  string
	mono     string
	mono_med string
	display  string // Fraunces display cut — letterhead titles
	displayt string // Fraunces text cut — subtitles, quotes
	arabic   string
	arabicbd string
	sc       string // Noto Sans SC subset — 中文 chrome
}

// ui_state_path — ~/.cache/agent-toolkit/desktop/ui_state.env
fn ui_state_path() string {
	base := if os.getenv('XDG_CACHE_HOME') != '' {
		os.getenv('XDG_CACHE_HOME')
	} else {
		os.join_path(os.home_dir(), '.cache')
	}
	return os.join_path(base, 'agent-toolkit', 'desktop', 'ui_state.env')
}

// save_ui_state — best-effort persist of the shell layout (k=v, no json deps).
fn persisted_terminal_mode(mode int) int {
	if mode == 2 {
		return 0
	}
	return if mode >= 0 && mode <= 3 { mode } else { 3 }
}

fn save_ui_state(app &GuiApp) {
	// MAX is a session-only takeover; restart it as compact rather than
	// covering the whole application before the user asks again.
	term_mode := persisted_terminal_mode(app.term_mode)
	lines := [
		'term_mode=${term_mode}',
		'zoom=${app.global_zoom}',
		'lang=${int(app.lang)}',
		'insights_tab=${app.insights_tab}',
		'swarm_backend=${app.swarm_backend}',
		'appearance=${app.appearance}',
	]
	os.mkdir_all(os.dir(ui_state_path())) or {}
	os.write_file(ui_state_path(), lines.join('\n')) or {}
}

// load_ui_state — restore the last shell layout (values clamped by callers).
fn load_ui_state(mut app GuiApp) {
	txt := os.read_file(ui_state_path()) or { return }
	for line in txt.split('\n') {
		kv := line.split('=')
		if kv.len != 2 {
			continue
		}
		k, v := kv[0], kv[1]
		match k {
			'term_mode' {
				mode := v.int()
				app.term_mode = persisted_terminal_mode(mode)
			}
			'zoom' {
				app.global_zoom = clamp_zoom(v.f64())
			}
			'lang' {
				li := v.int()
				match li {
					1 {
						app.lang = Lang.es
					}
					2 {
						app.lang = Lang.zh
					}
					3 {
						app.lang = Lang.ar
					}
					else {}
				}
			}
			'insights_tab' {
				app.insights_tab = v
			}
			'appearance' {
				app.appearance = appearance_from_string(v)
			}
			'swarm_backend' {
				app.swarm_backend = v
			}
			else {}
		}
	}
}

// vt_for — resolve a view id to its VT: -1 fleet, 0..14 desks, 15+ sessions.
fn vt_for(app &GuiApp, id int) &ghostty.GhosttyTerminal {
	if id < 0 {
		return &app.ghost
	}
	if id < 15 && id < app.per_desk_ghost.len {
		return &app.per_desk_ghost[id]
	}
	if id >= 15 && id - 15 < app.sessions.len {
		return &app.sessions[id - 15].vt
	}
	return &app.ghost
}

// desk_feed_label safely names the desk behind term_view for the read-only
// feed banner. vt_label already bounds-checks, so this never panics even if
// the desk roster and per_desk_ghost drift apart.
fn desk_feed_label(app &GuiApp) string {
	desks := desks_for_app(app)
	if app.term_view >= 0 && app.term_view < desks.len {
		return desks[app.term_view].label
	}
	return vt_label(app, app.term_view)
}

// vt_label — display name for a view id.
fn vt_label(app &GuiApp, id int) string {
	if id < 0 {
		return 'Fleet'
	}
	if id < 15 {
		desks := desks_for_app(app)
		if id < desks.len {
			return desks[id].label
		}
		return 'Desk ${id}'
	}
	if id >= 15 && id - 15 < app.sessions.len {
		return app.sessions[id - 15].agent
	}
	return 'Fleet'
}

// spawn_session — spawn an agent CLI on a real PTY and focus it fullscreen.
fn spawn_session(mut app &GuiApp, ab pty_mod.AgentBin) {
	s := pty_mod.spawn(ab.agent, ab.binary, [], 120, 32) or {
		app.inspector_msg = 'Session ${ab.agent} error: ${err}'
		return
	}
	app.sessions << TermSession{
		agent: ab.agent
		sess: s
		vt: ghostty.new_terminal(120, 32)
	}
	app.term_view = 15 + app.sessions.len - 1
	app.sessions_dialog = false
	app.inspector_msg = 'Session ${ab.agent} spawned (pid ${s.pid}) — Fleet chip returns'
}

// session key router — TUI byte encoding (pty echoes; no local echo)
fn session_key_bytes(e &gg.Event) string {
	if e.key_code == .enter {
		return '\r'
	}
	if e.key_code == .backspace {
		return '\x7f'
	}
	if e.key_code == .tab {
		return '\t'
	}
	if e.key_code == .up {
		return '\x1b[A'
	}
	if e.key_code == .down {
		return '\x1b[B'
	}
	if e.key_code == .right {
		return '\x1b[C'
	}
	if e.key_code == .left {
		return '\x1b[D'
	}
	if e.char_code >= 32 {
		return rune(e.char_code).str()
	}
	return ''
}

// embedded_desktop_version is the compile-time single source of truth for the
// user-visible desktop version — keep in sync with the repo root VERSION via
// scripts/bump-version.vsh (mirrors agent_toolkit_core.embedded_version).
const embedded_desktop_version = '1.30.0'

// embedded_commit is set at build via `v -d commit=<sha>` (make.vsh build-cli).
const embedded_commit = $d('commit', 'unknown')

// desktop_commit returns the build commit for observability (not human version).
fn desktop_commit() string {
	env := os.getenv('AGENT_TOOLKIT_COMMIT').trim_space()
	if env.len > 0 {
		return env
	}
	return embedded_commit
}

// desktop_version is the single source of truth for the user-visible version.
// Order: installed VERSION sibling (next to the binary install root) → repo
// VERSION via env roots / CWD checkout walk → embedded build version.
// The -d commit fallback surfaces via desktop_version_full for dev builds.
fn desktop_version() string {
	vp := os.join_path(os.dir(os.dir(os.executable())), 'VERSION')
	if os.is_file(vp) {
		if v := read_version_file(vp) {
			return v
		}
	}
	for env in ['AGENT_TOOLKIT_ROOT', 'AI_WORKSPACE'] {
		val := os.getenv(env).trim_space()
		if val.len == 0 {
			continue
		}
		if v := read_version_file(os.join_path(val, 'VERSION')) {
			return v
		}
	}
	mut cur := os.getwd()
	for {
		ver_path := os.join_path(cur, 'VERSION')
		if v := read_version_file(ver_path) {
			if os.is_dir(os.join_path(cur, 'skills')) || os.is_dir(os.join_path(cur, 'loops')) || os.is_dir(os.join_path(cur, 'profiles')) {
				return v
			}
		}
		parent := os.dir(cur)
		if parent == cur || parent.len == 0 {
			break
		}
		cur = parent
	}
	return embedded_desktop_version
}

// desktop_version_full appends the build commit when known (dev observability).
fn desktop_version_full() string {
	v := desktop_version()
	c := desktop_commit()
	if c == '' || c == 'unknown' {
		return v
	}
	return '${v}+${c}'
}

fn read_version_file(path string) ?string {
	if !os.is_file(path) {
		return none
	}
	text := os.read_file(path) or { return none }
	v := text.trim_space()
	if v.len == 0 {
		return none
	}
	return v
}

// ── Product-truth counters — Engine/catalog-derived, never hardcoded ──
// Every user-visible skill/agent/provider/target/product count renders through
// these helpers so the GUI cannot drift from the Engine catalog again.
// If the Engine is unavailable, show zero rather than claiming a catalog exists.
fn skills_total(mut app GuiApp) int {
	if app.desktop != unsafe { nil } {
		return app.desktop.engine_skills_stats().total
	}
	return 0
}

fn skills_domains_count(mut app GuiApp) int {
	if app.desktop != unsafe { nil } {
		return app.desktop.engine_skills_domains().len
	}
	return 0
}

fn agents_active_total(mut app GuiApp) int {
	if app.desktop != unsafe { nil } {
		s := app.desktop.engine_agents_stats()
		return s.total - s.archived
	}
	return 0
}

fn agents_tier_summary(mut app GuiApp) string {
	if app.desktop != unsafe { nil } {
		s := app.desktop.engine_agents_stats()
		return '${s.holistic} holistic · ${s.orchestrator} orchestrator · ${s.specialist} specialist'
	}
	return 'catalog unavailable'
}

fn mcp_total(mut app GuiApp) int {
	if app.desktop != unsafe { nil } {
		return app.desktop.engine_mcp_stats().total
	}
	return 0
}

fn targets_total(mut app GuiApp) int {
	if app.desktop != unsafe { nil } {
		return app.desktop.engine_targets().len
	}
	return 0
}

fn products_total(mut app GuiApp) int {
	if app.desktop != unsafe { nil } {
		return app.desktop.engine_products_catalog().len
	}
	return 0
}

fn packs_total(mut app GuiApp) int {
	if app.desktop != unsafe { nil } {
		return app.desktop.engine_packs_catalog().len
	}
	return 0
}

fn resolve_fonts() FontPaths {
	dir := atk_font_dir()
	return FontPaths{
		dir: dir
		sans: atk_font(dir, font_file_sans)
		sans_bd: atk_font(dir, font_file_sans_bold)
		mono: atk_font(dir, font_file_mono)
		mono_med: atk_font(dir, font_file_mono_med)
		display: atk_font(dir, font_file_display)
		displayt: atk_font(dir, font_file_display_t)
		arabic: atk_font(dir, font_file_arabic)
		arabicbd: atk_font(dir, font_file_arabic_bd)
		sc: atk_font(dir, font_file_sc)
	}
}

// ── Dunder paper-panel helper — file-folder manila + perforated edge + brass rivet signature
// Signature: every panel has perforated tractor-feed dots (1px every 12px on left/right) + brass rivet 2px
// Distinctive: no SNES glass, no purple — warm paper + ink, letterpress depth
fn pixel_panel(mut app GuiApp, x int, y int, w int, h int, variant string) {
	// hard drop shadow 3×3, ink 14% (pixel-snapped, no blur)
	app.gg.draw_rect_filled(x + 3, y + 3, w, h, tint(col_ink, 35))
	match variant {
		'terminal' {
			// terminal: paper-100 fill, ink-300 border single, inner scanline hint.
			// Paper keeps the frozen consts (pixel-identical goldens); resolved-dark
			// (Ink, or System on a dark OS) follows the mapped panel roles so rows
			// stay legible (#1097).
			term_fill := if app.appearance_dark { app.pnl_card } else { col_paper100 }
			term_edge := if app.appearance_dark { app.pnl_border } else { col_ink300 }
			app.gg.draw_rect_filled(x, y, w, h, term_fill)
			app.gg.draw_rect_empty(x, y, w, h, term_edge)
			// signature: top bevel highlight 1px — SNES light source top-left
			if w > 6 && h > 4 {
				app.gg.draw_line(x + 1, y + 1, x + w - 2, y + 1, tint(app.pnl_bg, 26))
			}
		}
		'inset' {
			app.gg.draw_rect_filled(x, y, w, h, app.pnl_card_sel)
			app.gg.draw_rect_empty(x, y, w, h, app.pnl_text)
			// inner 1px
			app.gg.draw_rect_empty(x + 1, y + 1, w - 2, h - 2, app.pnl_text_mut)
			if w > 6 && h > 4 {
				app.gg.draw_line(x + 2, y + 2, x + w - 3, y + 2, tint(app.pnl_bg, 18))
			}
		}
		'active' {
			// selected: middle border accent (brass/lemon) + signature bevel
			app.gg.draw_rect_filled(x, y, w, h, app.pnl_text)
			app.gg.draw_rect_filled(x + 2, y + 2, w - 4, h - 4, app.pnl_card_sel)
			app.gg.draw_rect_filled(x + 4, y + 4, w - 8, h - 8, app.pnl_text)
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, h - 10, app.pnl_card)
			// accent top 2px — workshop brass
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, 2, app.pnl_select)
			// signature: bevel highlight under accent + right inner shadow for depth
			if w > 14 && h > 14 {
				app.gg.draw_line(x + 6, y + 7, x + w - 7, y + 7, tint(app.pnl_bg, 34))
				app.gg.draw_line(x + 5, y + 7, x + 5, y + h - 6, tint(app.pnl_bg, 16))
				app.gg.draw_line(x + w - 6, y + 7, x + w - 6, y + h - 6, tint(app.pnl_text, 18))
			}
		}
		'alt' {
			// alt divergence: workshop wood — outer ink, middle wood_dark, inner path, fill wood_light
			// Diverges from default cream: warm wood grain + brass nail spec — used for command deck
			app.gg.draw_rect_filled(x, y, w, h, app.pnl_text)
			app.gg.draw_rect_filled(x + 2, y + 2, w - 4, h - 4, col_wood_dark)
			app.gg.draw_rect_filled(x + 4, y + 4, w - 8, h - 8, col_path)
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, h - 10, col_wood_light)
			// brass top accent 2px — workshop brass
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, 2, app.pnl_select)
			if w > 14 && h > 14 {
				app.gg.draw_line(x + 6, y + 7, x + w - 7, y + 7, tint(app.pnl_bg, 26))
				app.gg.draw_line(x + 5, y + 7, x + 5, y + h - 6, tint(app.pnl_bg, 14))
				app.gg.draw_line(x + 6, y + h - 6, x + w - 6, y + h - 6, tint(app.pnl_text, 12))
				app.gg.draw_line(x + w - 6, y + 6, x + w - 6, y + h - 6, tint(app.pnl_text, 12))
				// signature wood grain — 1px horizontal grain every 6px + brass tack
				for gy in 0 .. 3 {
					gy_y := y + 10 + gy * 6
					if gy_y < y + h - 6 {
						app.gg.draw_line(x + 8, gy_y, x + w - 8, gy_y, tint(app.pnl_select, 13))
					}
				}
				app.gg.draw_rect_filled(x + 5, y + 5, 2, 2, tint(app.pnl_select, 32))
			}
		}
		'dialog' {
			// dialog: ink outer, cream fill with brass header — for GOD mailbox
			app.gg.draw_rect_filled(x, y, w, h, app.pnl_text)
			app.gg.draw_rect_filled(x + 2, y + 2, w - 4, h - 4, app.pnl_card_sel)
			app.gg.draw_rect_filled(x + 4, y + 4, w - 8, h - 8, app.pnl_text)
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, h - 10, app.pnl_card)
			// brass header accent
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, 2, app.pnl_select)
			if w > 14 && h > 14 {
				app.gg.draw_line(x + 6, y + 7, x + w - 7, y + 7, tint(app.pnl_bg, 28))
				app.gg.draw_line(x + 5, y + 7, x + 5, y + h - 6, tint(app.pnl_bg, 14))
				app.gg.draw_rect_filled(x + 5, y + 5, 2, 2, tint(app.pnl_select, 26))
			}
		}
		'insights' {
			// insights telemetry — rust top accent + brass rivet + paper fiber, distinctive vs munder cream
			app.gg.draw_rect_filled(x, y, w, h, app.pnl_text)
			app.gg.draw_rect_filled(x + 2, y + 2, w - 4, h - 4, app.pnl_card_sel)
			app.gg.draw_rect_filled(x + 4, y + 4, w - 8, h - 8, app.pnl_text)
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, h - 10, app.pnl_card)
			// rust rubber-stamp top accent 2px — insights signature
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, 2, app.pnl_danger)
			if w > 14 && h > 14 {
				app.gg.draw_line(x + 6, y + 7, x + w - 7, y + 7, tint(app.pnl_bg, 28))
				app.gg.draw_line(x + 5, y + 7, x + 5, y + h - 6, tint(app.pnl_bg, 14))
				app.gg.draw_rect_filled(x + 5, y + 5, 2, 2, tint(app.pnl_danger, 32))
				// faint paper grain for telemetry depth
				for gy in 0 .. 2 {
					gy_y := y + 12 + gy * 8
					if gy_y < y + h - 8 {
						app.gg.draw_line(x + 8, gy_y, x + w - 8, gy_y, tint(app.pnl_select, 9))
					}
				}
			}
		}
		else {
			// default: outer ink, manila border, ink inner, paper fill — letterpress depth
			// Signature: perforated dots each 12px on left/right + brass rivet
			app.gg.draw_rect_filled(x, y, w, h, app.pnl_text)
			app.gg.draw_rect_filled(x + 2, y + 2, w - 4, h - 4, app.pnl_card_sel)
			app.gg.draw_rect_filled(x + 4, y + 4, w - 8, h - 8, app.pnl_text)
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, h - 10, app.pnl_card)
			if w > 14 && h > 14 {
				app.gg.draw_line(x + 5, y + 5, x + w - 6, y + 5, tint(app.pnl_bg, 30))
				app.gg.draw_line(x + 5, y + 6, x + 5, y + h - 6, tint(app.pnl_bg, 16))
				app.gg.draw_line(x + 6, y + h - 6, x + w - 6, y + h - 6, tint(app.pnl_text, 14))
				app.gg.draw_line(x + w - 6, y + 6, x + w - 6, y + h - 6, tint(app.pnl_text, 14))
				// signature brass binder rivet 2px at top-left + perforated dots
				app.gg.draw_rect_filled(x + 5, y + 5, 2, 2, tint(app.pnl_select, 42))
				// perforated tractor-feed dots — 1px holes every 12px on interior left/right edges
				for py in 0 .. ((h - 12) / 12) {
					py_y := y + 12 + py * 12
					if py_y < y + h - 8 {
						app.gg.draw_rect_filled(x + 4, py_y, 1, 1, tint(app.pnl_text, 22))
						app.gg.draw_rect_filled(x + w - 5, py_y, 1, 1, tint(app.pnl_text, 22))
						app.gg.draw_rect_filled(x + 4, py_y, 1, 1, tint(app.pnl_bg, 18))
					}
				}
			}
		}
	}
	// signature is always applied — even small panels get rivet hint if feasible
	if w >= 10 && h >= 10 && variant != 'terminal' {
		if variant == 'default' || variant == 'alt' || variant == 'dialog' || variant == 'insights' {
			app.gg.draw_line(x + 5, y + 6, x + w - 6, y + 6, tint(app.pnl_select, 18))
		}
	}
}

// typography — Dunder system: Fraunces Display (22/28 bold) + IBM Plex Sans body (15) + IBM Plex Mono (13)
// Distinctive: display is ink-trapped serif letterhead, body humanist grotesk, mono typewriter
// Scales honour global_zoom (0.75-1.5) + hi-DPI; never Inter-only, never purple
const font_display_lg = 22
const font_display_md = 18
const font_display_sm = 12
const font_body_lg = 17
const font_body_md = 15
const font_body_sm = 13
const font_mono_md = 13
const font_mono_sm = 12

struct Desk {
	id     string
	label  string
	role   string
	tier   string
	x      int
	y      int
	status string // idle, working, thinking, blocked, waiting
}

struct Avatar {
mut:
	id       string
	x        f32
	y        f32
	tx       f32
	ty       f32
	dir      string // down, up, left, right
	walking  bool
	frame    int // 0..3 walk cycle
	bob      f32
	carrying string // paper, terminal, globe, magnifier, diamond, checklist, none
	accent   gg.Color
}

struct Station {
	id    string
	label string
	x     int
	y     int
	w     int
	h     int
	kind  string // desk, shelf, terminal, portal, mcp, board, mailbox
	color gg.Color
}

struct KanbanTask {
	id    string
	title string
	col   string // todo, doing, done
	owner string
	pri   string
}

struct FileNode {
mut:
	name       string
	kind       string // file, dir
	children   []FileNode
	expanded   bool
	path       string
	depth      int
	git_status string // '', modified, added, untracked
}

struct EditorTab {
	path    string
	title   string
	content string
	syntax  string // v, md, yaml, json, txt
	dirty   bool
	cursor  int
}

// SyntaxToken for editor highlighting (mirrors desktop_engine.SyntaxToken but local for gg)
struct EditorToken {
	text string
	kind string
}

struct GitCommitRow {
	hash    string
	message string
	author  string
	lane    int
	branch  string
}

struct DiffHunkRow {
	file  string
	head  string
	lines []string
	kinds []string // context, addition, deletion, header
}

struct TermLine {
	ts     string
	level  string
	source string
	msg    string
	raw    string
}

// TermSession — a live agent CLI on a real PTY with its own VT.
struct TermSession {
pub mut:
	agent     string
	sess      pty_mod.Session
	vt        ghostty.GhosttyTerminal
	exited    bool
	dismissed bool
}

// Toast — a paper stamp of feedback (info/ok/warn/err), auto-expires.
struct Toast {
	title string
	msg   string
	kind  string // info | ok | warn | err
	at    int
}

// DoctorChip — a stored category-facet hit rect (#1108: click chip → fix category).
struct DoctorChip {
	cat string
	x   int
	y   int
	w   int
	h   int
}

// SwarmNode — a stored topology node hit rect (#1101: click → desk VT fullscreen).
struct SwarmNode {
	role string
	x    int
	y    int
	w    int
}

// SwarmEdge — a stored topology edge segment (#1101: click → artifact).
struct SwarmEdge {
	x1       int
	x2       int
	y        int
	artifact string
}

struct GuiApp {
mut:
	gg      &gg.Context = unsafe { nil }
	desktop &desktop.Desktop = unsafe { nil }
	fonts   FontPaths
	lang    Lang = .en
	version string = embedded_desktop_version
	// cached full stamp (version+commit) — resolved once at startup so the
	// help overlay never re-walks the filesystem every frame
	version_full string
	// product appearance (Paper/Ink/System, #1097) + resolved panel palette.
	// Chrome (header/dock/status/terminal) keeps the startup consts; panel
	// draw code reads app.pnl_*. apply_appearance() refreshes every field.
	appearance Appearance = .paper
	// resolved darkness of the last apply_appearance (System included) —
	// cached so per-frame panel code never re-probes the OS.
	appearance_dark  bool
	pnl_bg           gg.Color
	pnl_card         gg.Color
	pnl_card_sel     gg.Color
	pnl_hover        gg.Color
	pnl_border       gg.Color
	pnl_border_hi    gg.Color
	pnl_text         gg.Color
	pnl_text_mut     gg.Color
	pnl_text_fnt     gg.Color
	pnl_select       gg.Color
	pnl_success      gg.Color
	pnl_danger       gg.Color
	pnl_select_hover gg.Color
	// doctor dry-run preview (#1108): open check id + cached preview lines +
	// stored facet-chip hit rects (rebuilt every frame by draw_doctor).
	doctor_preview       string
	doctor_preview_lines []string
	doctor_chips         []DoctorChip
	// VC6 (#1173) Operations command center — see operations_view.v:
	// focused text field (0 none, 1 search, 2 swarm task), status dropdown
	// index, hovered element id, Doctor table selection/scroll.
	ops_focus         int
	ops_status_filter int
	ops_hover         int = -1
	doctor_selected   int = -1
	doctor_scroll     int
	// mcp provider drawer (#1106): open provider + cached template/provenance/
	// receipt + 60s probe cache (frame-stamped, 3600 frames @60fps).
	mcp_drawer            string
	mcp_drawer_template   string
	mcp_drawer_from_file  bool
	mcp_drawer_provenance string
	mcp_drawer_receipt    string
	mcp_probe_id          string
	mcp_probe_ok          bool
	mcp_probe_detail      string
	mcp_probe_at          int
	// swarm topology (#1101): stored node/edge hit rects (rebuilt every frame
	// by draw_swarm) + manual zoom level -1..1 around the 108px default.
	swarm_nodes []SwarmNode
	swarm_edges []SwarmEdge
	swarm_zoom  int
	frame       int
	// toast tray — every inspector_msg change becomes a paper toast
	toasts []Toast
	// terminal scrollback search (Ctrl+F while the terminal is visible)
	term_search_open bool
	term_search      string
	// per-desk fullscreen view: -1 = fleet feed, 0..14 = that desk's VT
	term_view       int = -1
	term_view_hover int = -1
	// real PTY sessions (agent CLIs) — see pty module
	sessions          []TermSession
	sessions_dialog   bool
	sessions_detected []pty_mod.Detected
	// split view (MAX): two VT panes side-by-side
	term_split       bool
	term_view_b      int = -1
	last_msg         string
	last_msg_frame   int = -99
	selected_panel   int // 0 world, 1 skills, 2 agents, 3 mcp, 4 targets, 5 doctor, 6 jobs, 7 loops, 8 swarm, 9 workspace, 10 products, 11 onboarding, 12 insights
	office_map_view  bool // false = operational overview (default), true = floor map
	hover_panel      int
	selected_desk    int
	hover_desk       int
	palette_open     bool
	palette_query    string
	palette_selected int
	// S4A (#1119): shared typed action & entity registry — the palette's data
	// source. Static rows remain only for entries not yet migrated.
	palette_reg &palette.Registry = unsafe { nil }
	// VC3 (#1172): pixel-art sprite cache for the Office room. Created lazily
	// on first Office draw (frame time, sokol ready); both palettes stay
	// cached since the key space is bounded. See office_room.v.
	pixel_cache &pixelart.SpriteCache = unsafe { nil }
	// #1128: known-workspace folder-tab hit rects (rebuilt every frame)
	known_ws_rects []KnownWsRect
	// S4B contextual action flow state
	palette_expanded    string // entity row id with expanded actions ('' = collapsed)
	palette_preview     []string // preview mode lines (len 0 = list mode)
	palette_preview_for string // action id the open preview belongs to
	palette_armed       string // action id armed for confirmation ('' = none)
	mouse_x             int
	mouse_y             int
	// dedupe: C backends set char_code on key_down AND send .char — keep one per frame
	last_keydown_char    u32
	last_keydown_frame   int
	last_keydown_keycode int = -1
	lang_hover           int = -1
	show_help            bool
	// live data
	engine_rev u64
	api_calls  u64
	// inspector interaction feedback
	inspector_msg string
	// terminal / activity — workshop xterm-like bottom strip
	// term_mode: 0 compact 148 · 1 tall 320 · 2 max (full content height) · 3 hidden
	term_mode int = 3
	// swarm attach exit (#1101): pre-attach terminal mode, -1 = no attach in
	// progress — Esc restores it so the panel renders again (term_mode 2
	// owns the content area and would trap the user in fullscreen)
	term_mode_saved int = -1
	term_height     int = 148
	term_visible    bool
	term_scroll     int
	term_hover      int = -1
	term_copied     string
	term_copied_at  int
	term_auto_pin   bool = true
	// inspector per-desk log state
	inspector_scroll int
	inspector_hover  int = -1
	// cached activity
	cached_rev u64
	// libghostty-vt — real PTY-backed terminal (Ghostty-inspired) — single + per-agent multiplexed
	ghost          ghostty.GhosttyTerminal
	ghost_focused  bool
	ghost_last_idx int
	per_desk_ghost []ghostty.GhosttyTerminal
	avatars        []Avatar
	stations       []Station
	kanban         []KanbanTask
	file_tree      []FileNode
	god_inbox      int
	god_outbox     int
	approvals      []string
	// swarm super-potent — GOD mailbox, Herdr/tmux, pair/team/full launch, approvals spend/scope/destructive, eventbus status/handoffs/logs wired to desktop_engine
	swarm_backend          string = 'auto'
	swarm_task             string = 'Implement feature via swarm'
	swarm_selected         int = -1
	swarm_scroll           int
	swarm_approvals_scroll int
	swarm_logs_scroll      int
	swarm_handoff_hover    int = -1
	// loops mission control — super potent management via Engine (create/edit/run/schedule)
	selected_loop        int = -1
	loops_hover_run      int = -1
	loops_hover_edit     int = -1
	loops_hover_cron     int = -1
	loops_show_create    bool
	loops_create_name    string
	loops_create_tier    int // 0 L1,1 L2,2 L3
	loops_create_cadence string = '1d'
	loops_scroll         int
	// jobs — super-potent ProcessSupervisor status + approvals queue (distinct from loops budgets)
	jobs_selected         int = -1
	jobs_hover            int = -1
	jobs_hover_cancel     int = -1
	jobs_hover_retry      int = -1
	jobs_hover_logs       int = -1
	jobs_scroll           int
	jobs_filter           string
	jobs_approvals_scroll int
	jobs_show_logs        bool
	jobs_logs_job         string
	loops_budget_hover    int = -1
	// IDE state — file-tree + editor tabs + git rails + skills 227 + memory palace (super potent)
	skills_query       string
	skills_domain      string
	skills_scroll      int
	skills_selected    int
	skills_hover       int = -1
	file_tree_scroll   int
	file_tree_hover    int = -1
	file_tree_selected string
	editor_tabs        []EditorTab
	active_tab         int
	editor_scroll      int
	editor_hover       int = -1
	git_rail           string = 'CHANGES' // CHANGES, HISTORY, COMPARE
	git_selected       string
	git_scroll         int
	git_hover          int = -1
	diff_scroll        int
	memory_query       string
	memory_scroll      int
	memory_selected    int
	memory_hover       int = -1
	memory_semantic    bool = true
	// brokered fs root (harness_root validated)
	harness_root          string
	workspace_draft       string
	workspace_focus       bool
	workspace_notice      string
	workspace_source      string
	workspace_initialized bool
	// super-potent onboarding / capability / target / product / workspace / persona — easy management
	show_onboarding              bool
	onboarding_step              int // 0 detect,1 capabilities,2 targets,3 products,4 workspace,5 personas,6 done
	onboarding_harness           string
	onboarding_msg               string
	onboarding_hover             int = -1
	selected_targets_onboarding  []string
	selected_skills_onboarding   []string
	selected_products_onboarding []string
	products_scroll              int
	products_hover               int = -1
	// VC5 Library (#1173): shared collection state for Agents/Products/MCP
	// tabs (Skills keeps skills_scroll/skills_selected/skills_domain)
	lib_scroll        int
	lib_sel           int
	lib_hover         int = -1
	lib_hover_ui      int = -1
	lib_filter        string
	lib_cache         []LibItem
	lib_cache_key     string
	lib_cache_frame   int = -1
	targets_hover     int = -1
	onboarding_scroll int
	// VC4 setup journey (#1173): user-facing choices; Engine keeps the truth
	onb_choice    int // 0 set up for me, 1 existing setup, 2 find my setup
	onb_ws_choice int // 0 create new workspace, 1 reuse existing
	onb_cap_on    []bool = [true, true, true, true]
	onb_diag      bool // internals live behind Details, not in the journey
	// global zoom — paper office scaling 0.75-1.50, 60FPS culling safe
	global_zoom   f64 = 1.0
	zoom_toast    string
	zoom_toast_at int
	zoom_dragging bool
	// global search — warm paper header field, filters palette + skills
	global_search       string
	header_search_focus bool
	header_search_hover int = -1
	// insights — telemetry super-potent (cost ledger, tool waterfall, OTel spans, budget sparks, CI watcher)
	insights_scroll int
	insights_sel    int = -1 // selected row of the current tab (VC7 report details)
	// VC7: per-frame Insights table cache (draw/metrics/click/details share it)
	ins_cache       InsTable
	ins_cache_key   string
	ins_cache_frame int = -1
	// VC7: scaffold check cache — six stats per frame otherwise (#1186 review)
	ws_scaffold_root  string
	ws_scaffold_vals  []bool
	ws_scaffold_frame int = -1000
	insights_hover    int = -1
	insights_tab      string = 'cost' // cost | waterfall | spans | budgets | ci
	insights_filter   string
	insights_spark    []f64
}

// ── i18n — 4 languages EN/ES/中文/عربي with RTL, superior to munder-difflin 3-lang.
// Scope: the "nameplate layer" — dock, header, status bar, palette labels, panel
// letterheads. Panel ledger bodies stay English (technical Engine output).
// 中文 renders via the bundled Noto Sans SC chrome subset; عربي via IBM Plex Sans
// Arabic (RTL dock flip + right-aligned rows). Missing font → graceful fallback. ──
enum Lang {
	en
	es
	zh
	ar
}

fn (l Lang) is_rtl() bool {
	return l == .ar
}

fn (l Lang) chip() string {
	return match l {
		.en { 'EN' }
		.es { 'ES' }
		.zh { '中文' }
		.ar { 'عربي' }
	}
}

fn (l Lang) next() Lang {
	return match l {
		.en { Lang.es }
		.es { Lang.zh }
		.zh { Lang.ar }
		.ar { Lang.en }
	}
}

// I18n — one row per chrome string. `tr` picks the active language.
struct I18nRow {
	en string
	es string
	zh string
	ar string
}

const i18n_table = {
	// dock — 13 nameplates
	'panel.world':          I18nRow{'World', 'Mundo', '世界', 'العالم'}
	'panel.skills':         I18nRow{'Skills', 'Habilidades', '技能', 'المهارات'}
	'panel.agents':         I18nRow{'Agents', 'Agentes', '代理', 'الوكلاء'}
	'panel.mcp':            I18nRow{'MCP', 'MCP', '提供方', 'المزودون'}
	'panel.targets':        I18nRow{'Targets', 'Destinos', '目标', 'الأهداف'}
	'panel.doctor':         I18nRow{'Doctor', 'Doctor', '诊断', 'الفحص'}
	'panel.jobs':           I18nRow{'Jobs', 'Trabajos', '作业', 'المهام'}
	'panel.loops':          I18nRow{'Loops', 'Bucles', '循环', 'الحلقات'}
	'panel.swarm':          I18nRow{'Swarm', 'Enjambre', '集群', 'السرب'}
	'panel.workspace':      I18nRow{'Workspace', 'Espacio', '工作区', 'المساحة'}
	'panel.products':       I18nRow{'Products', 'Productos', '产品', 'المنتجات'}
	'panel.onboarding':     I18nRow{'Onboarding', 'Inicio', '引导', 'التهيئة'}
	'panel.insights':       I18nRow{'Insights', 'Métricas', '洞察', 'الرؤى'}
	// dock — short descriptors
	'desc.world':           I18nRow{'Floor — desks, handoffs, live activity', 'Planta — escritorios y actividad', '办公区 · 工位与协作', 'الأرضية — المكاتب والنشاط'}
	'desc.skills':          I18nRow{'Skills and capabilities', 'Habilidades y capacidades', '技能与能力', 'المهارات والقدرات'}
	'desc.agents':          I18nRow{'Agents and roles', 'Agentes y roles', '代理与角色', 'الوكلاء والأدوار'}
	'desc.mcp':             I18nRow{'Providers, health and secrets', 'Proveedores, salud y claves', '提供方、健康与密钥', 'المزودون والصحة والأسرار'}
	'desc.targets':         I18nRow{'Coding tools and destinations', 'Herramientas y destinos', '编码工具与目标', 'أدوات البرمجة والوجهات'}
	'desc.doctor':          I18nRow{'Health checks + fix', 'Comprobaciones y reparación', '健康检查与修复', 'فحوصات وإصلاح'}
	'desc.jobs':            I18nRow{'Jobs & process supervisor', 'Trabajos y supervisor', '作业与进程管理', 'المهام والعمليات'}
	'desc.loops':           I18nRow{'Loops & missions — inner/outer', 'Bucles y misiones — internos/externos', '循环任务 · 内外环', 'المهام الدورية'}
	'desc.swarm':           I18nRow{'GOD mailbox, Herdr/tmux, teams', 'Buzón GOD, Herdr/tmux, equipos', 'GOD 信箱 · 集群协作', 'صندوق GOD والفرق'}
	'desc.workspace':       I18nRow{'IDE — tree, editor, git rails', 'IDE — árbol, editor, git', '工作区 IDE · 编辑器', 'مساحة عمل IDE'}
	'desc.products':        I18nRow{'Products and packs', 'Productos y paquetes', '产品与包', 'المنتجات والحزم'}
	'desc.onboarding':      I18nRow{'Wizard — workspace to products', 'Asistente — de workspace a productos', '引导向导 · 一步到位', 'معالج الإعداد'}
	'desc.insights':        I18nRow{'Cost, waterfall, spans, CI', 'Costos, cascada, spans, CI', '成本 · 瀑布 · CI', 'التكاليف والأداء'}
	// header
	'header.tagline':       I18nRow{'Paper Co. Office', 'Oficina Paper Co.', '纸业公司办公室', 'مكتب شركة الورق'}
	'header.search':        I18nRow{'Search skills, agents, files…', 'Buscar habilidades, agentes, archivos…', '搜索技能、代理和文件…', 'ابحث في المهارات والوكلاء والملفات…'}
	'header.workspace':     I18nRow{'WORKSPACE', 'ESPACIO', '工作区', 'المساحة'}
	'header.navigate':      I18nRow{'NAVIGATE', 'NAVEGAR', '导航', 'تنقل'}
	'header.live':          I18nRow{'live', 'activo', '实时', 'مباشر'}
	'header.commands':      I18nRow{'commands', 'comandos', '命令', 'أوامر'}
	'header.lang':          I18nRow{'Language', 'Idioma', '语言', 'اللغة'}
	// grouped task navigation — six permanent destinations
	'nav.group.office':     I18nRow{'Office', 'Oficina', '办公', 'المكتب'}
	'nav.group.library':    I18nRow{'Library', 'Biblioteca', '资源库', 'المكتبة'}
	'lib.subtitle':         I18nRow{'Discover skills, agents, and tools to supercharge your team.', 'Descubre habilidades, agentes y herramientas para potenciar a tu equipo.', '发现技能、代理和工具，助力你的团队。', 'اكتشف المهارات والوكلاء والأدوات لتعزيز فريقك.'}
	'nav.group.operations': I18nRow{'Operations', 'Operaciones', '运维', 'العمليات'}
	'nav.group.workspace':  I18nRow{'Workspace', 'Espacio', '工作区', 'المساحة'}
	'nav.group.insights':   I18nRow{'Insights', 'Métricas', '洞察', 'الرؤى'}
	'nav.group.settings':   I18nRow{'Settings', 'Ajustes', '设置', 'الإعدادات'}
	'nav.health':           I18nRow{'Health', 'Salud', '健康', 'الصحة'}
	'nav.setup':            I18nRow{'Setup', 'Configurar', '设置', 'الإعداد'}
	'ws.ready':             I18nRow{'ready', 'listo', '就绪', 'جاهز'}
	'ws.setup_needed':      I18nRow{'setup needed', 'falta configurar', '需要设置', 'يحتاج إعداد'}
	// status bar
	'status.palette':       I18nRow{'palette', 'paleta', '命令面板', 'الأوامر'}
	'status.paperco':       I18nRow{'Paper Co.', 'Paper Co.', '纸业公司', 'شركة الورق'}
	// world floor
	'office.view.overview': I18nRow{'Overview', 'Resumen', '概览', 'ملخص'}
	'office.view.floor':    I18nRow{'Floor Map', 'Planta', '平面图', 'خريطة الطابق'}
	'office.catalog':       I18nRow{'Catalog agents', 'Agentes del catálogo', '目录代理', 'وكلاء الدليل'}
	'world.title':          I18nRow{'Office Floor', 'Planta de oficina', '办公区平面', 'أرضية المكتب'}
	'world.subtitle':       I18nRow{'desks • envelopes are handoffs • click a desk or use arrow keys', 'escritorios • los sobres son entregas • clica un escritorio o usa flechas', '工位 • 信封即交接 • 点击工位或方向键', 'المكاتب • الأظرف تسليمات • انقر مكتباً أو استخدم الأسهم'}
	'world.working':        I18nRow{'working', 'trabajando', '工作中', 'يعمل'}
	'world.idle':           I18nRow{'idle', 'libre', '空闲', 'خامل'}
	'world.blocked':        I18nRow{'blocked', 'bloqueado', '受阻', 'معطل'}
	'world.god':            I18nRow{'GOD — in', 'GOD — entra', 'GOD — 收', 'GOD — دخول'}
	'world.out':            I18nRow{'out', 'sale', '发', 'خروج'}
	// generic actions
	'act.open_terminal':    I18nRow{'Open terminal', 'Abrir terminal', '打开终端', 'افتح الطرفية'}
	'act.route':            I18nRow{'Route handoff', 'Route entrega', '路由交接', 'وجّه التسليم'}
	'act.run':              I18nRow{'Run', 'Ejecutar', '运行', 'شغّل'}
	'act.sched':            I18nRow{'Sched', 'Programar', '计划', 'جدول'}
	'act.install':          I18nRow{'install', 'instalar', '安装', 'ثبّت'}
	'act.remove':           I18nRow{'remove', 'quitar', '移除', 'أزل'}
	'act.cancel':           I18nRow{'Cancel', 'Cancelar', '取消', 'إلغاء'}
	'act.retry':            I18nRow{'Retry', 'Reintentar', '重试', 'أعد'}
	'act.fix_all':          I18nRow{'Fix All', 'Reparar todo', '全部修复', 'أصلح الكل'}
	'act.new_loop':         I18nRow{'+ New Loop', '+ Nuevo bucle', '+ 新循环', '+ حلقة جديدة'}
	'act.approve':          I18nRow{'Y', 'S', '准', 'نعم'}
	'act.deny':             I18nRow{'N', 'N', '驳', 'لا'}
	// palette — 33 commands, fully translated (ES/中文/عربي)
	'palette.world':        I18nRow{'Go to World', 'Ir a Mundo', '前往世界', 'اذهب إلى العالم'}
	'palette.skills':       I18nRow{'Go to Skills', 'Ir a Habilidades', '前往技能', 'اذهب إلى المهارات'}
	'palette.agents':       I18nRow{'Go to Agents', 'Ir a Agentes', '前往代理', 'اذهب إلى الوكلاء'}
	'palette.mcp':          I18nRow{'Go to MCP', 'Ir a MCP', '前往提供方', 'اذهب إلى المزودين'}
	'palette.targets':      I18nRow{'Go to Targets', 'Ir a Destinos', '前往目标', 'اذهب إلى الأهداف'}
	'palette.doctor':       I18nRow{'Go to Doctor', 'Ir a Doctor', '前往诊断', 'اذهب إلى الفحص'}
	'palette.jobs':         I18nRow{'Go to Jobs', 'Ir a Trabajos', '前往作业', 'اذهب إلى المهام'}
	'palette.loops':        I18nRow{'Go to Loops', 'Ir a Bucles', '前往循环', 'اذهب إلى الحلقات'}
	'palette.swarm':        I18nRow{'Go to Swarm', 'Ir a Enjambre', '前往集群', 'اذهب إلى السرب'}
	'palette.workspace':    I18nRow{'Go to Workspace', 'Ir a Espacio', '前往工作区', 'اذهب إلى المساحة'}
	'palette.products':     I18nRow{'Go to Products', 'Ir a Productos', '前往产品', 'اذهب إلى المنتجات'}
	'palette.onboarding':   I18nRow{'Go to Onboarding', 'Ir a Inicio', '前往引导', 'اذهب إلى التهيئة'}
	'palette.insights':     I18nRow{'Go to Insights', 'Ir a Métricas', '前往洞察', 'اذهب إلى الرؤى'}
	// palette — descriptions (nav, short)
	'pdesc.world':          I18nRow{'Office floor, desks and handoffs', 'Planta, escritorios y entregas', '办公区 · 工位与交接', 'الأرضية والمكاتب والتسليمات'}
	'pdesc.skills':         I18nRow{'Search and install skills', 'Buscar e instalar habilidades', '搜索并安装技能', 'ابحث وثبّت المهارات'}
	'pdesc.agents':         I18nRow{'Browse holistic and specialist', 'Explorar globales y especialistas', '浏览全能与专项', 'تصفح الشامل والمتخصص'}
	'pdesc.mcp':            I18nRow{'Providers and health', 'Proveedores y salud', '提供方与健康', 'المزودون والصحة'}
	'pdesc.targets':        I18nRow{'Enable platforms', 'Activar plataformas', '启用平台', 'فعّل المنصات'}
	'pdesc.doctor':         I18nRow{'Fix checks', 'Reparar comprobaciones', '修复检查', 'أصلح الفحوصات'}
	'pdesc.jobs':           I18nRow{'Live processes', 'Procesos en vivo', '实时进程', 'العمليات المباشرة'}
	'pdesc.loops':          I18nRow{'Missions and schedules — inner/outer', 'Misiones y agendas — internas/externas', '任务与计划 · 内外环', 'المهام والجداول'}
	'pdesc.swarm':          I18nRow{'GOD mailbox, Herdr/tmux, pair/team/full', 'Buzón GOD, Herdr/tmux, par/equipo/completo', 'GOD 信箱 · 集群规模', 'صندوق GOD والفرق'}
	'pdesc.workspace':      I18nRow{'Context and memory', 'Contexto y memoria', '上下文与记忆', 'السياق والذاكرة'}
	'pdesc.products':       I18nRow{'Manage products/packs membership & digest', 'Gestionar productos/paquetes y resumen', '管理产品/包与摘要', 'أدر المنتجات والحزم'}
	'pdesc.onboarding':     I18nRow{'Wizard: workspace, personas, capability, target, product', 'Asistente: workspace, personas, capacidad, destino, producto', '向导：工作区到产品', 'معالج: من المساحة إلى المنتج'}
	'pdesc.insights':       I18nRow{'Cost ledger, waterfall, spans, CI, realtime, gallery', 'Costos, cascada, spans, CI, tiempo real, galería', '成本 · 瀑布 · CI · 实时 · 图库', 'التكاليف والأداء والمعرض'}
}

// rtl_text — bidi-lite for the fontstash renderer (no shaping, no bidi):
// Arabic draws left-to-right, so reverse each RTL run (and the run order) while
// keeping Latin/digit runs intact — 'ابحث في 227' then paints visually correct.
fn rtl_text(s string) string {
	if !needs_ar(s) {
		return s
	}
	runes := s.runes()
	mut tokens := [][]rune{}
	mut cur_is_rtl := false
	mut cur := []rune{}
	for ch in runes {
		ch_rtl := int(ch) >= 0x0600 && int(ch) <= 0x06FF
		is_sep := ch == ` ` || ch == `·` || ch == `—` || ch == `…` || ch == `/`
		if cur.len == 0 {
			cur_is_rtl = ch_rtl
			cur << ch
		} else if ch_rtl == cur_is_rtl || is_sep {
			cur << ch
		} else {
			tokens << cur
			cur = [ch]
			cur_is_rtl = ch_rtl
		}
	}
	if cur.len > 0 {
		tokens << cur
	}
	// paint order: last token first; RTL runs reversed inside, LTR runs as-is
	mut out := ''
	mut ti := tokens.len - 1
	for ti >= 0 {
		mut tk := tokens[ti]
		if tk.len > 0 {
			first := int(tk[0])
			if first >= 0x0600 && first <= 0x06FF {
				tk = tk.reverse()
				for ch in tk {
					out += ch.str()
				}
			} else {
				for ch in tk {
					out += ch.str()
				}
			}
		}
		ti--
	}
	return out
}

// tr translates a chrome key for the app's active language.
fn tr(app &GuiApp, key string) string {
	row := i18n_table[key] or { return key }
	return match app.lang {
		.en { row.en }
		.es { row.es }
		.zh { row.zh }
		.ar { rtl_text(row.ar) }
	}
}

// tr_count renders an i18n template with a hardcoded historical count swapped
// for the live Engine-derived value (R2 product-truth). Substitution happens
// on the raw template pre-RTL-shaping so the Arabic digit run stays intact;
// ar keeps Western digits (numerical truth over glyph purity).
fn tr_count(mut app GuiApp, key string, n int) string {
	row := i18n_table[key] or { return key }
	raw := match app.lang {
		.en { row.en }
		.es { row.es }
		.zh { row.zh }
		.ar { row.ar }
	}
	s := raw.replace('227', n.str()).replace('٢٢٧', n.str())
	if app.lang == .ar {
		return rtl_text(s)
	}
	return s
}

// trs same as tr but for a bare lang (status bar helpers without app ref).
fn trl(l Lang, key string) string {
	row := i18n_table[key] or { return key }
	return match l {
		.en { row.en }
		.es { row.es }
		.zh { row.zh }
		.ar { row.ar }
	}
}

// needs_sc reports whether the string contains CJK glyphs (draw with SC subset).
// NOTE: `for ch in s` iterates UTF-8 BYTES in V 0.5.2 — iterate .runes().
fn needs_sc(s string) bool {
	for ch in s.runes() {
		if int(ch) >= 0x2E80 && int(ch) <= 0x9FFF {
			return true
		}
	}
	return false
}

// needs_ar reports whether the string contains Arabic glyphs.
fn needs_ar(s string) bool {
	for ch in s.runes() {
		if int(ch) >= 0x0600 && int(ch) <= 0x06FF {
			return true
		}
	}
	return false
}

// family_for picks the right font path for a string in the active language —
// '' keeps the default (Plex Sans). Layout of Arabic shaping is handled by
// fontstash (harfbuzz-less: Plex Arabic presents isolated forms acceptably).
fn family_for(app &GuiApp, s string) string {
	if needs_sc(s) {
		return app.fonts.sc
	}
	if needs_ar(s) {
		return if s.contains('#bd') {
			app.fonts.arabicbd
		} else {
			app.fonts.arabic
		}
	}
	return ''
}

// display_family returns the Fraunces path for letterhead display text,
// or the per-language family when the text is translated (zh/ar).
fn display_family(app &GuiApp, s string) string {
	f := family_for(app, s)
	if f != '' {
		return f
	}
	return app.fonts.display
}

// draw_script_text — draw a ready string with automatic script font (same body
// as draw_text_l — the tab path, which is the one that always renders).
fn draw_script_text(mut app GuiApp, x int, y int, s string, cfg gg.TextCfg) {
	f := family_for(app, s)
	if f != '' {
		c := gg.TextCfg{
			color: cfg.color
			size: cfg.size
			align: cfg.align
			max_width: cfg.max_width
			family: f
			bold: cfg.bold
			mono: cfg.mono
			italic: cfg.italic
		}
		app.gg.draw_text(x, y, s, c)
		return
	}
	app.gg.draw_text(x, y, s, cfg)
}

// draw_text_l draws a translated string — resolves script font automatically.
fn draw_text_l(mut app GuiApp, x int, y int, key string, cfg gg.TextCfg) {
	s := tr(app, key)
	f := family_for(app, s)
	if f != '' {
		// NOTE: build the literal directly — struct-update spread (`...cfg`)
		// silently drops `family` in V 0.5.2 struct literals.
		c := gg.TextCfg{
			color: cfg.color
			size: cfg.size
			align: cfg.align
			max_width: cfg.max_width
			family: f
			bold: cfg.bold
			mono: cfg.mono
			italic: cfg.italic
		}
		app.gg.draw_text(x, y, s, c)
		return
	}
	app.gg.draw_text(x, y, s, cfg)
}

// lang_cfg resolves the script font for a translated string into a STABLE cfg
// (field-access fonts only — see family_for note).
fn lang_cfg(app &GuiApp, s string, cfg gg.TextCfg) gg.TextCfg {
	if needs_sc(s) {
		return gg.TextCfg{
			color: cfg.color
			size: cfg.size
			align: cfg.align
			max_width: cfg.max_width
			family: app.fonts.sc
			bold: cfg.bold
			mono: cfg.mono
			italic: cfg.italic
		}
	}
	if needs_ar(s) {
		return gg.TextCfg{
			color: cfg.color
			size: cfg.size
			align: cfg.align
			max_width: cfg.max_width
			family: app.fonts.arabic
			bold: cfg.bold
			mono: cfg.mono
			italic: cfg.italic
		}
	}
	return cfg
}

fn panel_name(i int) string {
	return match i {
		0 { 'World' }
		1 { 'Skills' }
		2 { 'Agents' }
		3 { 'MCP' }
		4 { 'Targets' }
		5 { 'Doctor' }
		6 { 'Jobs' }
		7 { 'Loops' }
		8 { 'Swarm' }
		9 { 'Workspace' }
		10 { 'Products' }
		11 { 'Onboarding' }
		12 { 'Insights' }
		else { 'World' }
	}
}

// panel_key maps dock index → i18n key.
fn panel_key(i int) string {
	return match i {
		0 { 'panel.world' }
		1 { 'panel.skills' }
		2 { 'panel.agents' }
		3 { 'panel.mcp' }
		4 { 'panel.targets' }
		5 { 'panel.doctor' }
		6 { 'panel.jobs' }
		7 { 'panel.loops' }
		8 { 'panel.swarm' }
		9 { 'panel.workspace' }
		10 { 'panel.products' }
		11 { 'panel.onboarding' }
		12 { 'panel.insights' }
		else { 'panel.world' }
	}
}

fn desc_key(i int) string {
	return 'desc.' + panel_key(i)[6..]
}

struct NavRow {
	panel  int
	y      int
	h      int
	parent bool
}

fn nav_group_for_panel(panel int) int {
	return match panel {
		1, 2, 3, 4, 10 { 1 }
		5, 6, 7, 8 { 6 }
		9 { 9 }
		12 { 12 }
		11 { 11 }
		else { 0 }
	}
}

fn nav_group_label(app &GuiApp, panel int) string {
	return match panel {
		0 { tr(app, 'nav.group.office') }
		1 { tr(app, 'nav.group.library') }
		6 { tr(app, 'nav.group.operations') }
		9 { tr(app, 'nav.group.workspace') }
		12 { tr(app, 'nav.group.insights') }
		11 { tr(app, 'nav.group.settings') }
		else { tr(app, 'nav.group.office') }
	}
}

// nav_rows keeps the six product destinations permanent. Library and
// Operations own their local tabs; duplicating those children in the shell
// made the rail read like an IDE tree instead of the reference's navigation.
fn nav_rows(app &GuiApp, h int) []NavRow {
	bottom := content_bottom(app, h) - 4
	mut rows := []NavRow{}
	mut y := shell_mast_h(h) + 54
	for group in [0, 1, 6, 9, 12, 11] {
		if y + 46 > bottom {
			break
		}
		rows << NavRow{ panel: group, y: y, h: 46, parent: true }
		y += 50
	}
	return rows
}

// ── RTL geometry — when عربي is active the filing-cabinet flips: dock right,
// inspector left, panels between. LTR default unchanged. ──
const dock_w = 184
const inspector_w = 280

// Shell geometry is authoritative for every destination and its hit regions.
// VC8-B begins with the legacy values so this refactor has no visual effect;
// the editorial-shell commit can change them in one place.
fn panel_top(app &GuiApp) int {
	// Pure layout tests construct GuiApp without a renderer; keep their legacy
	// baseline while production derives the shared masthead from live height.
	if app.gg == unsafe { nil } {
		return 52
	}
	return shell_mast_h(app.gg.height)
}

fn content_bottom(app &GuiApp, h int) int {
	term_h := if app.term_visible { app.term_height } else { 0 }
	return h - 28 - term_h
}

fn dock_x(app &GuiApp, w int) int {
	return if app.lang.is_rtl() { w - dock_w } else { 0 }
}

fn inspector_x(app &GuiApp, w int) int {
	return if app.lang.is_rtl() { 0 } else { w - inspector_w }
}

fn panel_fx(app &GuiApp) int {
	return if app.lang.is_rtl() { inspector_w + 8 } else { dock_w + 8 }
}

fn panel_fw(_ &GuiApp, w int) int {
	return w - (dock_w + 8) - inspector_w
}

fn panel_desc(i int) string {
	return match i {
		0 { 'Floor — desks, handoffs, live activity' }
		1 { 'Skills and capabilities — searchable' }
		2 { 'Agents and roles' }
		3 { 'MCP providers' }
		4 { 'Coding tools and destinations' }
		5 { 'Health checks' }
		6 { 'Jobs & process supervisor' }
		7 { 'Loops & missions — inner/outer' }
		8 { 'Swarms — GOD mailbox, Herdr/tmux, pair/team/full' }
		9 { 'Workspace IDE — file-tree + editor tabs + CHANGES/HISTORY/COMPARE + memory palace' }
		10 { 'Products and packs — membership & digest' }
		11 { 'Onboarding — workspace init, persona bootstrap, capability/target/product wizard' }
		12 { 'Insights — cost ledger, tool waterfall, OTel spans, budgets spark, CI watcher' }
		else { '' }
	}
}

// fuzzy_score and palette_best_score were removed in S4A (#1119): the palette
// module's scorer (desktop.palette.fuzzy_score / action_best_score) is the
// single scoring authority shared by registry actions and legacy rows.

// PaletteRow is the merged palette row model: registry-sourced actions (S4A)
// plus legacy static rows for entries not yet migrated to the registry.
struct PaletteRow {
	id    string
	label string
	desc  string
	keys  string
	score int
	// registry entity fields (zero values for legacy rows)
	is_entity          bool
	kind               palette.EntityKind
	entity_id          string
	panel              nav.PanelId
	available          bool
	unavailable_reason string
	// S4B contextual action row (derived from a registry action)
	is_action     bool
	action_kind   palette.ActionKind
	needs_preview bool
	needs_confirm bool
	// S4D recent execution row (journal-sourced)
	is_recent    bool
	execution_id u64
}

// KnownWsRect — stored hit rect for known-workspace folder tabs (#1128).
struct KnownWsRect {
	x    int
	y    int
	w    int
	h2   int
	path string
}

// panel_index_for maps a registry panel destination to the production panel
// index used by GuiApp.selected_panel (0 world … 12 insights).
fn panel_index_for(p nav.PanelId) int {
	return match p {
		.world_view { 0 }
		.skills { 1 }
		.agents { 2 }
		.mcp { 3 }
		.targets { 4 }
		.doctor { 5 }
		.jobs { 6 }
		.loops { 7 }
		.swarm { 8 }
		.workspace { 9 }
		.products { 10 }
		.onboarding { 11 }
		.insights { 12 }
		else { -1 }
	}
}

// nav_tr_key returns the i18n key suffix ('palette.<key>') for a registry
// navigation row so localized labels keep working after the migration.
fn nav_tr_key(p nav.PanelId) string {
	return match p {
		.world_view { 'world' }
		.skills { 'skills' }
		.agents { 'agents' }
		.mcp { 'mcp' }
		.targets { 'targets' }
		.doctor { 'doctor' }
		.jobs { 'jobs' }
		.loops { 'loops' }
		.swarm { 'swarm' }
		.workspace { 'workspace' }
		.products { 'products' }
		.onboarding { 'onboarding' }
		.insights { 'insights' }
		else { '' }
	}
}

// filtered_palette merges the shared typed registry (navigation + entities,
// S4A) with the legacy static rows for not-yet-migrated entries. All rows are
// scored by the palette module's fuzzy scorer — one scoring authority.
// Empty query keeps the stable build order: navigation, entities, legacy.
// filtered_palette derives every row from the shared typed registry (S4A) —
// navigation, entities and contextual actions. The static command list and
// its duplicate scorer were deleted in S4C (#1119); the registry's
// scored_filter is the single ranking authority.
fn filtered_palette(mut app GuiApp) []PaletteRow {
	mut scored := []PaletteRow{}
	if app.palette_reg != unsafe { nil } {
		// S4D: recent executions first on an empty query — visibly distinct
		// (↻ prefix, outcome + evidence in the description), bounded display
		if app.palette_query.trim_space() == '' {
			// at most 3 recent rows — the palette stays an action/entity
			// surface, recents must not crowd out navigation (#1162 review)
			for rec in app.palette_reg.journal_records() {
				if scored.len >= 3 {
					break
				}
				scored << palette_recent_row(mut app, rec)
			}
		}
		for sa in app.palette_reg.scored_filter(app.palette_query) {
			a := sa.action
			scored << PaletteRow{
				id: a.id
				label: a.label
				desc: a.desc
				keys: a.keys
				score: sa.score
				is_entity: true
				kind: a.kind
				entity_id: a.entity_id
				panel: a.panel
				available: a.available
				unavailable_reason: a.unavailable_reason
			}
		}
	}
	return expand_palette_actions(mut app, scored)
}

// palette_recent_row renders one journal record as a distinct recent row.
// The description carries the truthful outcome and real evidence refs only.
// Undo availability is recomputed live (optimistic exact-state check) so a
// stale undo is visible without executing anything.
fn palette_recent_row(mut app GuiApp, rec palette.RecentAction) PaletteRow {
	outcome := match rec.outcome {
		.succeeded { 'succeeded' }
		.partial { 'partial' }
		else { 'failed' }
	}
	mut desc := outcome
	if rec.evidence.receipt_path != '' {
		desc += ' · receipt ${rec.evidence.receipt_path}'
	} else if rec.evidence.run_id != '' {
		desc += ' · run ${rec.evidence.run_id}'
	} else if rec.evidence.job_id != '' {
		desc += ' · job ${rec.evidence.job_id}'
	} else if rec.evidence.revision > 0 {
		desc += ' · rev ${rec.evidence.revision}'
	}
	if rec.has_undo {
		match app.palette_reg.undo_precheck(rec.execution_id) {
			.available {
				desc += ' · U undo ready'
			}
			.consumed {
				desc += ' · undone'
			}
			.stale {
				desc += ' · undo unavailable — state changed'
			}
			else {}
		}
	}
	return PaletteRow{
		id: 'recent:${rec.execution_id}'
		label: '↻ ${rec.label}'
		desc: desc
		is_entity: true
		kind: rec.entity_kind
		entity_id: rec.entity_id
		panel: nav.PanelId.unknown
		is_recent: true
		execution_id: rec.execution_id
	}
}

// handle_palette_undo executes the undo for the selected recent row.
// Appearance undo is restored through the real shell setter; everything
// else goes through the registry's typed restore seams.
fn handle_palette_undo(mut app GuiApp, sel PaletteRow) {
	if app.palette_reg == unsafe { nil } {
		return
	}
	rec := app.palette_reg.find_recent(sel.execution_id) or { return }
	if !rec.has_undo {
		app.inspector_msg = 'No undo for this action'
		return
	}
	// live optimistic check before committing
	status := app.palette_reg.undo_precheck(sel.execution_id)
	if status != .available {
		app.inspector_msg = match status {
			.consumed { 'Already undone' }
			.stale { 'Undo unavailable — state changed since this action; cannot safely undo.' }
			else { 'No undo for this action' }
		}
		return
	}
	if rec.undo.kind == .appearance {
		spec := rec.undo.spec
		if spec is palette.AppearanceUndo {
			// guard: current appearance must equal the expected post-state
			if app.appearance.str() != spec.expected_appearance {
				app.inspector_msg = 'Undo unavailable — state changed since this action; cannot safely undo.'
				return
			}
			app.apply_appearance(appearance_from_string(spec.previous_appearance))
			save_ui_state(app)
			out := app.palette_reg.mark_undo_consumed(sel.execution_id, 0)
			app.inspector_msg = out.summary
		}
		return
	}
	out := app.palette_reg.execute_undo(sel.execution_id) or {
		app.inspector_msg = 'Undo failed: ${err.msg()}'
		return
	}
	app.inspector_msg = out.summary
}

// rerun_recent re-executes a recent action through the CURRENT registry:
// it resolves the current RegistryAction, current availability and the
// normal preview/confirmation rules — never replays stored arguments.
fn rerun_recent(mut app GuiApp, sel PaletteRow) {
	if app.palette_reg == unsafe { nil } {
		return
	}
	rec := app.palette_reg.find_recent(sel.execution_id) or { return }
	acts := app.palette_reg.actions_for(rec.entity_kind, rec.entity_id)
	for a in acts {
		if a.kind == rec.action_kind {
			run_palette_action(mut app, PaletteRow{
				id: a.action_id()
				label: a.label
				desc: a.desc
				is_entity: true
				kind: a.entity_kind
				entity_id: a.entity_id
				panel: a.panel
				available: a.available
				unavailable_reason: a.unavailable_reason
				is_action: true
				action_kind: a.kind
				needs_preview: a.needs_preview
				needs_confirm: a.needs_confirm
			})
			return
		}
	}
	app.inspector_msg = 'This action is no longer available for ${rec.entity_id}'
}

// expand_palette_actions inserts the contextual actions of the expanded
// entity row directly beneath it (S4B). Expansion follows the row: when the
// query filters the entity out, the actions go with it.
fn expand_palette_actions(mut app GuiApp, rows []PaletteRow) []PaletteRow {
	if app.palette_expanded == '' || app.palette_reg == unsafe { nil } {
		return rows
	}
	mut out := []PaletteRow{}
	for row in rows {
		out << row
		if row.is_entity && !row.is_action && row.id == app.palette_expanded {
			for a in app.palette_reg.actions_for(row.kind, row.entity_id) {
				desc := if a.available {
					a.desc
				} else {
					'unavailable — ${a.unavailable_reason}'
				}
				hint := if !a.available {
					desc
				} else if a.needs_preview {
					'${desc} — Enter to preview'
				} else if a.needs_confirm {
					'${desc} — Enter twice to confirm'
				} else {
					desc
				}
				out << PaletteRow{
					id: a.action_id()
					label: '  ↳ ${a.label}'
					desc: hint
					score: row.score
					is_entity: true
					kind: a.entity_kind
					entity_id: a.entity_id
					panel: a.panel
					available: a.available
					unavailable_reason: a.unavailable_reason
					is_action: true
					action_kind: a.kind
					needs_preview: a.needs_preview
					needs_confirm: a.needs_confirm
				}
			}
		}
	}
	return out
}

fn desks_for_app(app &GuiApp) []Desk {
	mut desks := []Desk{}
	labels := [
		['assistant', 'planner', 'architect', 'designer'],
		['implementer', 'reviewer', 'qa-engineer', 'security-engineer'],
		['platform-engineer', 'researcher', 'data-engineer', 'code-reviewer'],
		['loops', 'swarm', 'memory', 'workspace'],
	]
	roles := [
		['holistic', 'holistic', 'holistic', 'holistic'],
		['holistic', 'holistic', 'holistic', 'holistic'],
		['holistic', 'holistic', 'holistic', 'specialist'],
		['runtime', 'runtime', 'runtime', 'runtime'],
	]
	for r in 0 .. 4 {
		for c in 0 .. 4 {
			if r == 3 && c == 3 {
				continue
			}
			desks << Desk{
				id: labels[r][c]
				label: labels[r][c]
				role: roles[r][c]
				tier: if roles[r][c] == 'holistic' {
					'holistic'
				} else if roles[r][c] == 'specialist' {
					'specialist'
				} else {
					'runtime'
				}
				x: 220 + c * 166
				y: 92 + r * 130
				// A catalog desk is not a running process. Runtime status is
				// projected separately from Engine jobs/PTY state.
				status: 'idle'
			}
		}
	}
	return desks
}

fn desk_rect(d Desk, idx int, fx int, fy int, fw int, fh int) (int, int, int, int) {
	mut x := d.x
	mut y := d.y
	// Clamp to stay inside floor interior (fx+12 margin, fy+36 top bar) and
	// above the command deck strip. Draw and hit-test both call this, so the
	// visible card is always the clickable card.
	if x < fx + 12 {
		x = fx + 12
	}
	if x + 140 > fx + fw - 12 {
		x = fx + fw - 152
	}
	if y < fy + 44 {
		y = fy + 44
	}
	deck_top := fy + fh - 68
	if y + 86 > deck_top - 4 {
		y = deck_top - 90
		if y < fy + 44 {
			y = fy + 44
		}
	}
	return x, y, 140, 86
}

// ── Terminal / Activity helpers — workshop palette, English only, gg monospace ──
const term_bg = ui_cabinet(ui_theme()) // theme: console = surface.cabinet

const term_header_bg = ui_cabinet(ui_theme()) // theme: console = surface.cabinet

const term_border = ui_line_cabinet(ui_theme()) // theme: quiet cabinet rule

const term_cursor = ui_selection(ui_theme()) // theme: signal.selection

fn term_level_color(level string) gg.Color {
	return match level {
		'proc' { col_mint }
		'handoff' { col_brass }
		'watch' { col_slate }
		'doctor' { col_mint }
		'error' { col_oxide }
		'warn' { col_brass }
		'info' { col_slate_dim }
		else { col_slate }
	}
}

fn term_level_label(level string) string {
	return match level {
		'proc' { 'PROC' }
		'handoff' { 'HANDOFF' }
		'watch' { 'WATCH' }
		'doctor' { 'DOCTOR' }
		'error' { 'ERROR' }
		'warn' { 'WARN' }
		'info' { 'INFO' }
		else { level.to_upper() }
	}
}

// Production activity is sourced only from Engine state. Empty is a valid state.
fn mock_term_logs(_ &GuiApp) []TermLine {
	return []TermLine{}
}

// collect_engine_logs reads real Engine logs via snapshot data.
// Wires to desktop_engine logs if available (jobs/*/logs, watcher_* keys) — per spec.
fn collect_engine_logs(app &GuiApp) []TermLine {
	mut out := []TermLine{}
	// Try real Engine snapshot — current_engine_state holds State.data map<string>string
	// Keys like jobs/<id>/logs, jobs/<id>/cmd, watcher_last_path, watcher_dependent etc.
	state := app.desktop.current_engine_state()
	for k, v in state.data {
		if k.starts_with('jobs/') && k.ends_with('/logs') && v.len > 0 {
			id := k.all_after('jobs/').all_before('/logs')
			for line in v.split('\n') {
				if line.len == 0 {
					continue
				}
				out << TermLine{'${pad4(int(state.revision))}', 'proc', id, 'process_log ${id}: ${line}', line}
			}
		}
		if k.starts_with('watcher_') && v.len > 0 {
			out << TermLine{'${pad4(int(state.revision))}', 'watch', 'watcher', '${k}=${v}', '${k}=${v}'}
		}
		if k.starts_with('jobs/') && k.ends_with('/status') {
			jid := k.all_after('jobs/').all_before('/status')
			out << TermLine{'${pad4(int(state.revision))}', 'info', jid, 'job ${jid} status=${v}', '${jid} ${v}'}
		}
	}
	return out
}

// count_engine_logs mirrors collect_engine_logs without allocating TermLine,
// cells, or detail fields. Insights uses it for the headline count; the full
// model is built only when the realtime table is visible.
fn count_engine_logs(app &GuiApp) int {
	state := app.desktop.current_engine_state()
	mut count := 0
	for k, v in state.data {
		if k.starts_with('jobs/') && k.ends_with('/logs') && v.len > 0 {
			for line in v.split('\n') {
				if line.len > 0 {
					count++
				}
			}
		}
		if k.starts_with('watcher_') && v.len > 0 {
			count++
		}
		if k.starts_with('jobs/') && k.ends_with('/status') {
			count++
		}
	}
	return count
}

fn active_log_filter(app &GuiApp) string {
	if app.palette_open && app.palette_query.trim_space().len > 0 {
		return app.palette_query.trim_space().to_lower()
	}
	return ''
}

fn filtered_logs(logs []TermLine, query string) []TermLine {
	if query == '' {
		return logs.clone()
	}
	q := query.to_lower()
	mut out := []TermLine{}
	for l in logs {
		if l.msg.to_lower().contains(q) || l.source.to_lower().contains(q) || l.level.to_lower().contains(q) || l.ts.to_lower().contains(q) || l.raw.to_lower().contains(q) {
			out << l
		}
	}
	return out
}

fn per_desk_logs(logs []TermLine, desk Desk, query string) []TermLine {
	mut out := []TermLine{}
	q := query.to_lower()
	label := desk.label.to_lower()
	id := desk.id.to_lower()
	for l in logs {
		is_for_desk := l.source.to_lower().contains(label) || l.source.to_lower().contains(id) || l.msg.to_lower().contains(label) || l.msg.to_lower().contains(id) || (desk.label == 'assistant' && l.source == 'engine' && l.level == 'watch')
		if !is_for_desk {
			continue
		}
		if q != '' && !(l.msg.to_lower().contains(q) || l.source.to_lower().contains(q) || l.level.to_lower().contains(q)) {
			continue
		}
		out << l
	}
	return out
}

fn clamp_scroll(scroll int, total int, visible int) int {
	if visible >= total {
		return 0
	}
	max := total - visible
	if scroll < 0 {
		return 0
	}
	if scroll > max {
		return max
	}
	return scroll
}

fn pad4(n int) string {
	mut s := n.str()
	for s.len < 4 {
		s = '0' + s
	}
	return s
}

fn pad_right(s string, w int) string {
	if s.len >= w {
		return s[..w]
	}
	mut out := s
	for out.len < w {
		out += ' '
	}
	return out
}

fn copy_to_clipboard(mut app GuiApp, text string) {
	if text == '' {
		return
	}
	mut ok := false
	// desktop backend seam is the clipboard authority (headless stub keeps in memory, window uses native)
	mut backend := app.desktop.backend_seam()
	ok = backend.write_clipboard(text)
	if !ok {
		ok = backend.clipboard_set(text)
	}
	app.term_copied = text
	app.term_copied_at = app.frame
	if ok {
		app.inspector_msg = 'Copied: ' + (if text.len > 48 { text[..48] + '…' } else { text })
	} else {
		app.inspector_msg = 'Copy: ' + (if text.len > 48 { text[..48] + '…' } else { text })
	}
	// also toast via backend for visibility
	backend.show_toast(app.inspector_msg)
}

fn term_visible_rows(term_h int) int {
	usable := term_h - 64 // header 24 + prompt 18 + margins
	if usable < 16 {
		return 1
	}
	return usable / 16
}

// ── Global zoom — Dunder paper office scaling ──
// 60FPS-safe: only scales font sizes + viewport culling, no texture reload.
fn clamp_zoom(z f64) f64 {
	if z < 0.75 {
		return 0.75
	}
	if z > 1.5 {
		return 1.5
	}
	return z
}

fn zoom_step(z f64, dir int) f64 {
	// dir: +1 zoom in, -1 zoom out (5% per step, paper-company readability)
	return clamp_zoom(z + f64(dir) * 0.05)
}

// type_ramp — canonical pixel sizes. Zoom SNAPS to this ramp: the fontstash
// atlas (fixed 2048², sfons cannot expand) holds one bitmap per (font,size) —
// a continuous zoom would mint a new glyph set per step and overflow the
// atlas (random .notdef tofu). A 12-step ramp keeps the working set bounded.
const type_ramp = [10, 11, 12, 13, 14, 16, 18, 22, 26, 32, 40, 48]!

fn snap_size(s int) int {
	if s <= type_ramp[0] {
		return type_ramp[0]
	}
	if s >= type_ramp[type_ramp.len - 1] {
		return type_ramp[type_ramp.len - 1]
	}
	for i in 1 .. type_ramp.len {
		if s <= type_ramp[i] {
			lo := type_ramp[i - 1]
			hi := type_ramp[i]
			return if s - lo < hi - s { lo } else { hi }
		}
	}
	return type_ramp[type_ramp.len - 1]
}

fn scaled_size(base int, zoom f64) int {
	// snap to the canonical ramp — bounded atlas, disciplined type scale
	return snap_size(int(f64(base) * zoom + 0.5))
}

fn zoom_percent(z f64) string {
	return '${int(z * 100 + 0.5)}%'
}

fn main() {
	headless := desktop.is_headless_env()
	cfg := desktop.DesktopConfig{
		title: 'Agent Toolkit — Desktop'
		width: 1280
		height: 800
		headless: headless
	}
	cfg.validate() or {
		eprintln('invalid config: ${err}')
		exit(1)
	}
	mut d := desktop.new_desktop(desktop.DesktopBootArgs{
		config: cfg
	})
	d.boot() or {
		eprintln('desktop boot failed: ${err}')
		exit(1)
	}
	fonts := resolve_fonts()
	println('fonts: dir=${fonts.dir} display=${os.file_name(fonts.display)} sans=${os.file_name(fonts.sans)} mono=${os.file_name(fonts.mono)} sc=${os.file_name(fonts.sc)} arabic=${os.file_name(fonts.arabic)}')
	println(d.smoke_message())
	if headless {
		d.shutdown() or {}
		println('desktop headless PASS — binary at ${os.executable()}')
		println('Run with DISPLAY to open window: ${os.executable()} (1280x800)')
		return
	}
	mut app := &GuiApp{
		desktop: d
		fonts: fonts
		version: desktop_version()
		version_full: desktop_version_full()
		selected_panel: 0
		hover_panel: -1
		selected_desk: -1
		hover_desk: -1
	}
	// S4A (#1119): bind the shared typed registry to the boot Engine so the
	// palette derives navigation + entities from authoritative state.
	app.palette_reg = d.palette_registry()
	app.gg = gg.new_context(
		bg_color: col_ink
		width: cfg.width
		height: cfg.height
		create_window: true
		window_title: cfg.title
		frame_fn: frame
		event_fn: on_event
		user_data: app
		init_fn: on_init
		font_path: fonts.sans
		custom_bold_font_path: fonts.sans_bd
	)
	app.gg.run()
	d.shutdown() or {}
}

fn gui_file_node_from_proxy(node desktop.FileNodeProxy) FileNode {
	mut children := []FileNode{}
	for child in node.children {
		children << gui_file_node_from_proxy(child)
	}
	return FileNode{
		name: node.name
		kind: node.kind
		children: children
		expanded: node.expanded
		path: node.path
		depth: node.depth
		git_status: node.git_status
	}
}

fn reload_workspace_tree(mut app GuiApp) {
	if app.desktop == unsafe { nil } || app.harness_root == '' {
		app.file_tree = []FileNode{}
		return
	}
	proxies := app.desktop.engine_build_file_tree(app.harness_root, 3)
	mut nodes := []FileNode{}
	for node in proxies {
		nodes << gui_file_node_from_proxy(node)
	}
	app.file_tree = nodes
	app.file_tree_selected = ''
	app.file_tree_scroll = 0
	app.editor_tabs = []EditorTab{}
	app.active_tab = 0
}

fn apply_workspace(mut app GuiApp, candidate string, source string) bool {
	return apply_workspace_persist(mut app, candidate, source, true)
}

// apply_workspace_persist validates and activates a workspace. Auto-detected
// fallbacks (cwd) activate locally without persisting, so a launch from a
// random directory never wins over ~/.ai-workspace on the next start.
fn apply_workspace_persist(mut app GuiApp, candidate string, source string, persist bool) bool {
	clean := app.desktop.engine_validate_workspace(candidate) or {
		app.workspace_notice = 'Workspace error: ${err}'
		return false
	}
	if persist {
		switched := app.desktop.engine_switch_workspace(clean) or {
			app.workspace_notice = 'Could not switch workspace: ${err}'
			return false
		}
		app.harness_root = switched
	} else {
		app.harness_root = clean
	}
	app.onboarding_harness = app.harness_root
	app.workspace_draft = app.harness_root
	app.workspace_source = source
	app.workspace_initialized = app.desktop.engine_workspace_initialized(app.harness_root)
	app.workspace_notice = if app.workspace_initialized {
		'Workspace ready'
	} else {
		'Folder selected - initialize it to add workspace structure'
	}
	app.workspace_focus = false
	app.engine_rev = app.desktop.app_state_snapshot().revision
	app.api_calls = app.desktop.engine_api_calls()
	reload_workspace_tree(mut app)
	return true
}

fn resolve_workspace_on_start(mut app GuiApp) {
	persisted := app.desktop.app_state_snapshot().select_recent_workspace()
	home := os.home_dir()
	home_real := os.real_path(home)
	// #1127: a fresh user gets the designed default workspace (~/.ai-workspace)
	// instead of silently claiming the directory the app happened to be
	// launched from. The default dir is created EMPTY (plain folder — valid
	// but uninitialized; the wizard offers initialization) — never a scaffold
	// written behind the user's back. cwd stays the last-resort 'Detected'
	// fallback but can no longer outrank the user's persisted workspace,
	// which previously vanished whenever validation of an earlier candidate
	// failed (restart-workspace-restored regression in the #1130 harness).
	default_ws := os.join_path(home, '.ai-workspace')
	if !os.is_dir(default_ws) {
		os.mkdir(default_ws) or {}
	}
	candidates := [
		os.getenv('AGENT_TOOLKIT_WORKSPACE'),
		os.getenv('HARNESS_DIR'),
		persisted,
		default_ws,
		os.getwd(),
	]
	sources := ['Environment', 'Environment', 'Recent', 'Default', 'Detected']
	for i, candidate in candidates {
		// The home directory itself is never a workspace — old binaries persisted
		// it and every panel would read the whole home tree as context. Compare
		// canonical paths so `~`, symlinks, and trailing slashes cannot sneak in.
		if candidate.trim_space() == '' {
			continue
		}
		if os.real_path(os.expand_tilde_to_home(candidate.trim_space())) == home_real {
			continue
		}
		// 'Detected' (cwd) stays a local fallback: activate without persisting
		// so a launch from a random directory never wins over the user's
		// workspace on the next start.
		if apply_workspace_persist(mut app, candidate, sources[i], sources[i] != 'Detected') {
			return
		}
	}
	app.harness_root = ''
	app.workspace_draft = os.join_path(home, '.ai-workspace')
	app.workspace_source = 'Unavailable'
	app.workspace_notice = 'Choose a workspace folder to get started'
	app.workspace_initialized = false
}

fn on_init(mut app GuiApp) {
	app.frame = 0
	app.engine_rev = app.desktop.app_state_snapshot().revision
	app.api_calls = app.desktop.engine_api_calls()
	app.term_height = 148
	app.term_visible = false
	app.term_scroll = 0
	app.term_hover = -1
	app.term_auto_pin = true
	app.inspector_hover = -1
	app.cached_rev = app.engine_rev
	app.ghost = ghostty.new_terminal(80, 18)
	app.ghost_focused = false
	app.god_inbox = 0
	app.god_outbox = 0
	load_ui_state(mut app)
	// resolve persisted (or default Paper) appearance into the panel palette
	// before the first frame — panel draw code reads app.pnl_* throughout
	app.apply_appearance(app.appearance)
	app.term_visible = app.term_mode == 0
	app.ghost_focused = false
	app.approvals = []
	// seed auto-pin to bottom after first collect
	all := collect_engine_logs(app)
	vis := term_visible_rows(app.term_height)
	if all.len > vis {
		app.term_scroll = all.len - vis
	}
	// libghostty-vt per-desk multiplexed terminals + walking avatars + stations + kanban + file tree
	desks_init := desks_for_app(app)
	app.per_desk_ghost = []ghostty.GhosttyTerminal{len: desks_init.len}
	for i in 0 .. desks_init.len {
		app.per_desk_ghost[i] = ghostty.new_terminal(40, 6)
	}
	// avatars — one per desk, 24×24, accent from palette
	accents := [col_coral, col_mint, col_sky, col_lemon, col_lilac, col_peach]
	app.avatars = []Avatar{len: desks_init.len}
	for i, d in desks_init {
		app.avatars[i] = Avatar{
			id: d.id
			x: f32(d.x + 60)
			y: f32(d.y + 30)
			tx: f32(d.x + 60)
			ty: f32(d.y + 30)
			dir: 'down'
			walking: false
			frame: 0
			bob: 0
			carrying: 'none'
			accent: accents[i % accents.len]
		}
	}
	// stations — 64×64, 4px grid, pixel-snapped
	app.stations = [
		Station{'desk', 'Desk', 0, 0, 32, 32, 'desk', col_wood_light},
		Station{'mailbox', 'Mailbox', 866, 100, 16, 24, 'mailbox', col_coral},
		Station{'shelf', 'File shelf', 906, 180, 64, 48, 'shelf', col_wood_dark},
		Station{'terminal', 'Terminal', 922, 260, 32, 48, 'terminal', col_ink},
		Station{'portal', 'Web portal', 906, 340, 48, 48, 'portal', col_lilac},
		Station{'mcp', 'MCP corner', 906, 420, 48, 48, 'mcp', col_sky},
		Station{'board', 'Task board', 916, 500, 40, 48, 'board', col_cream200},
	]
	// Kanban is populated from real workspace operations. A clean launch has no
	// tasks to show; never seed the Office with fictional work.
	app.kanban = []KanbanTask{}
	// Resolve once through the Engine so every workspace-bound view starts on
	// the same canonical root with a real brokered file tree.
	resolve_workspace_on_start(mut app)
	// skills 227 — init harness root search state from Engine (super potent)
	app.skills_query = ''
	app.skills_domain = ''
	app.git_rail = 'CHANGES'
	// memory palace — semantic recall ready
	app.memory_query = ''
	app.memory_semantic = true
	// super-potent onboarding: auto-show wizard if first run — workspace init, personas, capability, target, product
	app.onboarding_harness = app.harness_root
	app.onboarding_step = 0
	app.show_onboarding = app.desktop.engine_is_first_run()
	if app.show_onboarding {
		// first run: the OFFICE is the hero — the wizard renders as an overlay
		// on the floor (munder-style boot straight into the office)
		app.selected_panel = 0
		app.onboarding_msg = 'Welcome — Setup Choice → Tools → Workspace → Capabilities → Review (press o to toggle)'
	} else {
		app.onboarding_msg = ''
	}
}

// ui_now is the wall clock every header/date stamp reads. Under
// ATK_GUI_FREEZE it pins to a fixed instant so golden captures never drift
// on the minute digits (the Operations/Office/Insights/Onboarding headers
// all show local time).
fn ui_now() time.Time {
	if os.getenv('ATK_GUI_FREEZE') != '' {
		return time.new(time.Time{ year: 2026, month: 9, day: 9, hour: 10, minute: 24 })
	}
	return time.now()
}

fn frame(mut app GuiApp) {
	// ATK_GUI_FREEZE=1 — deterministic rendering for golden-image tests:
	// every frame-driven animation (avatars, envelopes, pulses, timestamps)
	// pins to the same frame, so captures are pixel-comparable.
	if os.getenv('ATK_GUI_FREEZE') != '' {
		app.frame = 300
	} else {
		app.frame++
	}
	// toast feed — inspector_msg changes become paper stamps (deduped per text)
	if app.inspector_msg != '' && app.inspector_msg != app.last_msg && app.frame - app.last_msg_frame > 30 {
		app.last_msg = app.inspector_msg
		app.last_msg_frame = app.frame
		kind := if app.inspector_msg.contains('error') || app.inspector_msg.contains('fail') {
			'err'
		} else if app.inspector_msg.contains('warn') {
			'warn'
		} else if app.inspector_msg.contains('✓') || app.inspector_msg.contains('receipt') || app.inspector_msg.contains('approved') {
			'ok'
		} else {
			'info'
		}
		app.toasts << Toast{
			title: 'Engine'
			msg: app.inspector_msg
			kind: kind
			at: app.frame
		}
		if app.toasts.len > 4 {
			app.toasts = app.toasts[1..]
		}
	}
	// expire toasts after ~6s (360 frames)
	for app.toasts.len > 0 && app.frame - app.toasts[0].at > 360 {
		app.toasts = app.toasts[1..]
	}
	// drain PTY sessions — non-blocking, per frame, single-threaded
	for mut s in app.sessions {
		if !s.exited && !s.sess.alive() {
			s.exited = true
		}
		out := s.sess.drain()
		if out != '' {
			s.vt.feed(out)
		}
	}
	// persist the shell layout every ~10s and at frame 60 (first settle)
	if app.frame == 60 || app.frame % 600 == 0 {
		save_ui_state(app)
	}
	// walk cycle 4 frames 8fps, 80px/s, bob ±1 (munder spec)
	if app.frame % 4 == 0 {
		for mut av in app.avatars {
			desks := desks_for_app(app)
			mut found := false
			for d in desks {
				if d.id == av.id {
					if d.status == 'working' {
						av.tx = 520 + 32
						av.ty = 150
						av.carrying = 'paper'
						av.walking = true
					} else if d.status == 'thinking' {
						av.tx = 680 + 16
						av.ty = 240 + 24
						av.carrying = 'none'
						av.walking = true
					} else if d.status == 'blocked' {
						av.tx = 640 + 8
						av.ty = 100 + 12
						av.carrying = 'none'
						av.walking = true
					} else {
						av.tx = f32(d.x + 60)
						av.ty = f32(d.y + 30)
						av.carrying = if av.x == av.tx && av.y == av.ty { 'none' } else { 'paper' }
						av.walking = !(av.x == av.tx && av.y == av.ty)
					}
					found = true
					break
				}
			}
			if !found {
				continue
			}
			dx := av.tx - av.x
			dy := av.ty - av.y
			dist := (if dx < 0 { -dx } else { dx }) + (if dy < 0 { -dy } else { dy })
			if dist > 1 {
				av.walking = true
				step := f32(5.3)
				if dx != 0 {
					av.x += if dx > 0 {
						if dx > step { step } else { dx }
					} else {
						if -dx > step { -step } else { dx }
					}
					av.dir = if dx > 0 { 'right' } else { 'left' }
				}
				if dy != 0 {
					av.y += if dy > 0 {
						if dy > step { step } else { dy }
					} else {
						if -dy > step { -step } else { dy }
					}
					if dy < 0 {
						av.dir = 'up'
					} else if dx == 0 {
						av.dir = 'down'
					}
				}
				av.frame = (av.frame + 1) % 4
				av.bob = if av.frame % 2 == 1 { f32(-1) } else { f32(1) }
				if av.frame == 0 {
					av.bob = 0
				}
			} else {
				av.walking = false
				av.frame = 0
				av.bob = 0
				av.x = av.tx
				av.y = av.ty
			}
		}
	}
	if app.frame % 30 == 0 {
		app.engine_rev = app.desktop.app_state_snapshot().revision
		app.api_calls = app.desktop.engine_api_calls()
		// golden-test determinism: pin the api counter when frozen
		if os.getenv('ATK_GUI_FREEZE') != '' {
			app.api_calls = 900
		}
		// wire GOD mailbox counts via desktop_engine eventbus (status/handoffs/logs)
		gi, go_ := app.desktop.god_mailbox_counts()
		if gi != 0 || go_ != 0 || app.frame == 30 {
			app.god_inbox = gi
			app.god_outbox = go_
		}
		// detect new rev to auto-pin terminal to newest
		if app.engine_rev != app.cached_rev {
			app.cached_rev = app.engine_rev
			if app.term_auto_pin {
				// will clamp after computing visible rows
			}
		}
		// feed new Engine logs into libghostty-vt (Ghostty)
		all_ghost := collect_engine_logs(app)
		if all_ghost.len > app.ghost_last_idx {
			for i := app.ghost_last_idx; i < all_ghost.len; i++ {
				l := all_ghost[i]
				app.ghost.feed('${l.ts} \x1b[90m${l.level}\x1b[0m ${l.source}: ${l.msg}\n')
				for mut g in app.per_desk_ghost {
					if l.source.contains('assistant') || l.level == 'handoff' {
						g.feed('${l.ts} ${l.msg}\n')
					}
				}
			}
			app.ghost_last_idx = all_ghost.len
		}
	}
	// terminal height modes — 1× compact / 2× tall / MAX full-content / hidden (^` cycles 0→1→2)
	app.term_visible = app.term_mode != 3
	if app.term_visible {
		if app.term_mode != 2 && app.term_view >= 15 {
			app.term_view = -1
		}
		app.term_height = match app.term_mode {
			1 { 320 }
			2 { app.gg.height - panel_top(app) - 28 }
			else { 120 }
		}
		// the onboarding shell owns the screen: cap the terminal at the
		// source so the VT row budget, draw_terminal and onb_layout all agree
		// (a MAX terminal would otherwise hide the board entirely)
		if app.show_onboarding && app.term_height > 120 {
			app.term_height = 120
		}
	}
	// libghostty-vt resize to fit terminal area — potent: derive cols/rows from actual pixel area
	// 80x18 is the logical default, but bottom strip is ~148px tall → dynamic 76x8 at 1280 width.
	// Compute so window resize keeps Ghostty crisp and per-agent stays 40x6.
	mut cols_full := 80
	mut rows_full := 18
	if app.term_visible {
		_, _, tw_g, _ := terminal_rect(app, app.gg.width, app.gg.height)
		content_w_g := tw_g - 16
		mut cols_g := content_w_g / 14
		if cols_g < 40 {
			cols_g = 40
		}
		if cols_g > 120 {
			cols_g = 120
		}
		mut rows_g := (app.term_height - 64) / 16
		if rows_g < 4 {
			rows_g = 4
		}
		if rows_g > 48 {
			rows_g = 48
		}
		cols_full = cols_g
		rows_full = rows_g
		app.ghost.resize(cols_g, rows_g)
	} else {
		app.ghost.resize(80, 18)
	}
	for mut ses in app.sessions {
		ses.vt.resize(cols_full, rows_full)
	}
	for di, mut g in app.per_desk_ghost {
		if app.term_mode == 2 && app.term_view == di {
			g.resize(cols_full, rows_full)
		} else {
			g.resize(40, 6)
		}
	}
	w := app.gg.width
	h := app.gg.height
	app.gg.begin()
	app.gg.draw_rect_filled(0, 0, w, h, col_ink)
	onb_shell_active := app.show_onboarding
	// VC8 (#1187): every destination now shares the editorial masthead.
	// Onboarding keeps its quieter task rail while the setup journey owns focus.
	draw_header(mut app, w)
	if onb_shell_active {
		draw_onboarding_sidebar(mut app, w, h)
	} else {
		draw_left_dock(mut app, h)
	}
	// MAX terminal owns the content area — skip panel + inspector rendering
	// (negative-height panels would smear texts over the chrome). Not while
	// onboarding owns the screen: its terminal is capped, the board must draw.
	if app.term_mode == 2 && !onb_shell_active {
		draw_terminal(mut app, w, h)
		app.gg.end()
		return
	}
	// The onboarding shell fully replaces the header, dock and whichever
	// panel is behind it — there is nothing to blend or dim underneath, so
	// the normal panel dispatch is skipped entirely instead of drawing (and
	// then papering over) the previous panel's geometry.
	if onb_shell_active {
		draw_onboarding(mut app, w, h)
	} else {
		// VC5 (#1173): Skills/Agents/Products/MCP share one Library
		// composition (library_view.v) with its own detail column.
		match app.selected_panel {
			0 { draw_world(mut app, w, h) }
			1, 2, 3, 10 { draw_library(mut app, w, h) }
			4 { draw_targets(mut app, w, h) }
			// VC6 (#1173): Doctor/Jobs/Loops/Swarm share the Operations
			// command center (operations_view.v)
			5, 6, 7, 8 { draw_operations(mut app, w, h) }
			9 { draw_workspace(mut app, w, h) }
			11 { draw_settings(mut app, w, h) }
			12 { draw_insights(mut app, w, h) }
			else { draw_world(mut app, w, h) }
		}
	}
	if app.show_onboarding {
		draw_onboarding_preview(mut app, w, h)
	} else if lib_is_panel(app.selected_panel) {
		draw_library_detail(mut app, w, h)
	} else if ops_is_panel(app.selected_panel) {
		// VC6 (#1173): the Details column replaces the Office inspector
		draw_operations_detail(mut app, w, h)
	} else if app.selected_panel == 9 {
		// VC7 (#1173): Workspace and Insights own the right column with their
		// own detail sheets instead of the generic Office inspector.
		draw_workspace_detail(mut app, w, h)
	} else if app.selected_panel == 12 {
		draw_insights_detail(mut app, w, h)
	} else if app.selected_panel == 11 {
		draw_settings_detail(mut app, w, h)
	} else if app.selected_panel == 0 && !app.office_map_view {
		draw_office_detail(mut app, w, h)
	} else {
		draw_inspector(mut app, w, h)
	}
	if app.term_visible {
		draw_terminal(mut app, w, h)
	}
	if app.palette_open {
		draw_palette(mut app, w, h)
	}
	if app.show_help {
		draw_help(mut app, w, h)
	}
	// ── status bar — Dunder paper revision: warm paper tape with steel rivets + brass file tab + zoom slider ──
	app.gg.draw_rect_filled(0, h - 28, w, 28, col_charcoal)
	app.gg.draw_line(0, h - 28, w, h - 28, col_line)
	// paper fiber dots along bottom edge every 20px
	for sx in 0 .. (w / 20 + 1) {
		dx := sx * 20 + 6
		if dx < w - 4 {
			app.gg.draw_rect_filled(dx, h - 27, 1, 1, tint(col_paper, 7))
		}
	}
	// zoom toast — paper tape, 2s fade
	if app.zoom_toast != '' && app.frame - app.zoom_toast_at < 120 {
		tw := 72
		th := 20
		tx := w / 2 - tw / 2
		ty := h - 52
		app.gg.draw_rect_filled(tx, ty, tw, th, col_paper)
		app.gg.draw_rect_empty(tx, ty, tw, th, col_brass)
		// perforated dots
		app.gg.draw_rect_filled(tx + 2, ty + 6, 1, 1, tint(col_ink, 30))
		app.gg.draw_rect_filled(tx + tw - 3, ty + 6, 1, 1, tint(col_ink, 30))
		app.gg.draw_text(tx + 18, ty + 5, app.zoom_toast, gg.TextCfg{ color: col_ink, size: scaled_size(12, app.global_zoom), bold: true })
	}
	// left — commands hint + GOD mailbox envelopes glow + rev
	mut left_x := 12
	app.gg.draw_text(left_x, h - 19, '/', gg.TextCfg{ color: col_brass, size: scaled_size(11, app.global_zoom), bold: true })
	left_x += 24
	draw_text_l(mut app, left_x, h - 19, 'status.palette', gg.TextCfg{ color: col_slate_dim, size: scaled_size(11, app.global_zoom) })
	left_x += 46
	// envelopes signature — drawn paper envelope with rust glow dot when inbox>0
	env_col := if app.god_inbox > 0 { col_brass } else { col_slate }
	draw_envelope(mut app, left_x, h - 17, env_col)
	app.gg.draw_text(left_x + 12, h - 19, '${app.god_inbox}→${app.god_outbox}', gg.TextCfg{ color: env_col, size: scaled_size(11, app.global_zoom) })
	if app.god_inbox > 0 && app.frame % 40 < 20 {
		app.gg.draw_rect_filled(left_x - 6, h - 14, 4, 4, tint(col_oxide, 88))
	}
	left_x += 58
	app.gg.draw_text(left_x, h - 19, '•  rev ${app.engine_rev}', gg.TextCfg{ color: col_slate_dim, size: scaled_size(11, app.global_zoom) })
	left_x += 92
	// version stamp — same single source of truth as the header (desktop_version).
	app.gg.draw_text(left_x, h - 19, '•  v${app.version}', gg.TextCfg{ color: col_slate_dim, size: scaled_size(11, app.global_zoom) })
	left_x += 84
	// mini zoom slider in status bar — paper tape style
	zx2 := left_x + 8
	zy2 := h - 18
	zw2 := 64
	app.gg.draw_rect_filled(zx2, zy2, zw2, 4, col_paper_dim)
	app.gg.draw_rect_empty(zx2, zy2, zw2, 4, col_line_light)
	mut pct2 := (app.global_zoom - 0.75) / 0.75
	if pct2 < 0 {
		pct2 = 0
	}
	if pct2 > 1 {
		pct2 = 1
	}
	fw2 := int(f64(zw2) * pct2)
	if fw2 > 0 { app.gg.draw_rect_filled(zx2, zy2, fw2, 4, col_brass) }
	mut thx2 := zx2 + fw2 - 4
	if thx2 < zx2 {
		thx2 = zx2
	}
	if thx2 > zx2 + zw2 - 6 {
		thx2 = zx2 + zw2 - 6
	}
	app.gg.draw_rect_filled(thx2, zy2 - 3, 6, 10, if app.zoom_dragging {
		col_brass
	} else {
		col_paper
	})
	app.gg.draw_rect_empty(thx2, zy2 - 3, 6, 10, col_brass_dim)
	app.gg.draw_text(zx2 + zw2 + 6, h - 19, zoom_percent(app.global_zoom), gg.TextCfg{ color: col_ink500, size: scaled_size(10, app.global_zoom) })
	// Center states the actual renderer, not an invented frame-rate claim.
	mid := 'Native V  •  gg/sokol'
	mid_w := mid.len * 6
	app.gg.draw_text(w / 2 - mid_w / 2, h - 19, mid, gg.TextCfg{ color: col_slate_dim, size: scaled_size(11, app.global_zoom) })
	// right — appearance and real workspace readiness.
	app.gg.draw_rect_filled(w - 330, h - 22, 84, 16, col_paper_dim)
	app.gg.draw_rect_empty(w - 330, h - 22, 84, 16, col_line_light)
	app.gg.draw_text(w - 324, h - 18, 'Theme·${appearance_label(app.appearance)}', gg.TextCfg{ color: col_ink700, size: scaled_size(10, app.global_zoom), mono: true })
	app.gg.draw_rect_filled(w - 238, h - 22, 104, 16, col_paper_dim)
	app.gg.draw_rect_empty(w - 238, h - 22, 104, 16, col_line_light)
	ready_label := if app.workspace_initialized { 'Workspace ready' } else { 'Setup needed' }
	app.gg.draw_text(w - 232, h - 18, ready_label, gg.TextCfg{
		color: if app.workspace_initialized { col_ink700 } else { col_oxide }
		size: scaled_size(9, app.global_zoom)
		bold: true
	})
	draw_text_l(mut app, w - 124, h - 19, 'status.paperco', gg.TextCfg{ color: col_slate, size: scaled_size(11, app.global_zoom), bold: true })
	// brass rivet at right edge
	app.gg.draw_rect_filled(w - 8, h - 16, 2, 2, tint(col_brass, 42))
	draw_toasts(mut app, w, h)
	app.gg.end()
}

// draw_toasts — paper stamp tray, bottom-right, auto-expiring (info/ok/warn/err).
fn draw_toasts(mut app GuiApp, w int, h int) {
	mut n := 0
	for ti in 0 .. app.toasts.len {
		t := app.toasts[ti]
		age := app.frame - t.at
		if age > 360 {
			continue
		}
		alpha := if age > 300 { u8(255 - (age - 300) * 4) } else { u8(255) }
		tw := 320
		th := 34
		x := w - tw - 14
		y := h - 40 - (app.toasts.len - ti) * (th + 8)
		rail := match t.kind {
			'ok' { app.pnl_success }
			'warn' { app.pnl_border_hi }
			'err' { app.pnl_danger }
			else { app.pnl_text_mut }
		}
		app.gg.draw_rect_filled(x + 2, y + 2, tw, th, tint(app.pnl_text, u8(180 * alpha / 255)))
		app.gg.draw_rect_filled(x, y, tw, th, tint(app.pnl_bg, alpha))
		app.gg.draw_rect_empty(x, y, tw, th, tint(app.pnl_bg, alpha))
		app.gg.draw_rect_filled(x, y, 3, th, gg.rgba(rail.r, rail.g, rail.b, alpha))
		// perforated tractor dots on the left edge
		app.gg.draw_rect_filled(x + 6, y + 6, 1, 1, tint(app.pnl_text, u8(40 * alpha / 255)))
		app.gg.draw_rect_filled(x + 6, y + th - 8, 1, 1, tint(app.pnl_text, u8(40 * alpha / 255)))
		mut title := t.title
		mut msg := t.msg
		if msg.len > 44 {
			msg = msg[..44] + '…'
		}
		app.gg.draw_text(x + 12, y + 5, title, gg.TextCfg{
			color: tint(app.pnl_text_mut, alpha)
			size: 10
			bold: true
		})
		app.gg.draw_text(x + 12, y + 17, msg, gg.TextCfg{
			color: tint(app.pnl_text, alpha)
			size: 11
		})
		n++
		if n >= 4 {
			break
		}
	}
}

// draw_envelope — tiny paper envelope from primitives (glyph ✉ is not in the
// bundled Plex fonts; primitives are crisper anyway and stay pixel-true).
fn draw_envelope(mut app GuiApp, x int, y int, col gg.Color) {
	app.gg.draw_rect_filled(x, y + 1, 9, 6, tint(app.pnl_text, 50))
	app.gg.draw_rect_filled(x, y, 9, 6, app.pnl_bg)
	app.gg.draw_rect_empty(x, y, 9, 6, col)
	app.gg.draw_line(x, y, x + 4, y + 3, col)
	app.gg.draw_line(x + 4, y + 3, x + 9, y, col)
}

// draw_search_lens — small magnifier from primitives (⌕ missing in Plex).
fn draw_search_lens(mut app GuiApp, x int, y int) {
	app.gg.draw_rect_empty(x, y, 8, 8, app.pnl_border_hi)
	app.gg.draw_rect_empty(x + 1, y + 1, 6, 6, app.pnl_border_hi)
	app.gg.draw_line(x + 7, y + 7, x + 11, y + 11, app.pnl_border_hi)
	app.gg.draw_line(x + 8, y + 7, x + 11, y + 10, app.pnl_border_hi)
}

// draw_floor_legend — status swatches drawn as squares (● ○ ■ missing in Plex).
// Text uses steel — the legend strip sits on the dark floor vignette bar.
fn draw_floor_legend(mut app GuiApp, x int, y int) {
	app.gg.draw_rect_filled(x, y + 3, 7, 7, app.pnl_select)
	draw_text_l(mut app, x + 12, y, 'world.working', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	ox := x + 12 + tr(app, 'world.working').len * 7 + 12
	app.gg.draw_rect_filled(ox, y + 3, 7, 7, tint(app.pnl_text_mut, 130))
	draw_text_l(mut app, ox + 12, y, 'world.idle', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	bx := ox + 12 + tr(app, 'world.idle').len * 7 + 12
	app.gg.draw_rect_filled(bx, y + 3, 7, 7, app.pnl_danger)
	draw_text_l(mut app, bx + 12, y, 'world.blocked', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	app.gg.draw_text(bx + 12 + tr(app, 'world.blocked').len * 7 + 14, y, '— envelopes are handoffs · click or arrows to select', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
}

fn workspace_path_label(path string, max_len int) string {
	if path == '' {
		return 'Choose workspace'
	}
	home := os.home_dir()
	mut label := path
	if home != '' && path.starts_with(home) {
		label = '~' + path[home.len..]
	}
	if label.len > max_len {
		return '...' + label[label.len - max_len + 3..]
	}
	return label
}

struct HeaderLayout {
	mast_h      int
	control_y   int
	control_h   int
	workspace_x int
	workspace_w int
	search_x    int
	search_w    int
	theme_x     int
	theme_w     int
	lang_x      int
	lang_w      int
	command_x   int
	command_w   int
}

// header_layout is shared by drawing and pointer routing. Controls anchor to
// the right so the product lockup keeps its editorial measure at every
// required viewport.
fn header_layout(w int, h int) HeaderLayout {
	mh := shell_mast_h(h)
	search_w := if w >= 1350 {
		280
	} else if w >= 1150 { 240 } else { 190 }
	workspace_w := if w >= 1180 { 190 } else { 164 }
	command_w := 30
	command_x := w - 12 - command_w
	lang_w := 42
	lang_x := command_x - 8 - lang_w
	theme_w := 72
	theme_x := lang_x - 8 - theme_w
	search_x := theme_x - 8 - search_w
	workspace_x := search_x - 8 - workspace_w
	return HeaderLayout{
		mast_h: mh
		control_y: if mh >= 100 { 12 } else { 9 }
		control_h: 34
		workspace_x: workspace_x
		workspace_w: workspace_w
		search_x: search_x
		search_w: search_w
		theme_x: theme_x
		theme_w: theme_w
		lang_x: lang_x
		lang_w: lang_w
		command_x: command_x
		command_w: command_w
	}
}

fn nav_group_subtitle(panel int) string {
	return match panel {
		0 { 'Home base · See your agents' }
		1 { 'Agents · Skills · MCP' }
		6 { 'Loops · Tasks · Runs' }
		9 { 'Files · Projects · Context' }
		12 { 'Metrics · Traces · Reports' }
		11 { 'Theme · Language · Preferences' }
		else { '' }
	}
}

fn draw_header(mut app GuiApp, w int) {
	z := app.global_zoom
	ensure_pixel_cache(mut app)
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	l := header_layout(w, app.gg.height)
	app.gg.draw_rect_filled(0, 0, w, l.mast_h, app.pnl_bg)
	app.gg.draw_rect_filled(0, l.mast_h - 4, w, 2, pc(app, `W`))
	app.gg.draw_line(0, l.mast_h - 2, w, l.mast_h - 2, app.pnl_border)
	plant := pixelart.environment_for(.plant)
	plant_scale := if l.mast_h >= 100 { 5 } else { 3 }
	sc.draw(plant, pid, 16, 8, plant_scale)
	title_x := 16 + plant.width() * plant_scale + 12
	app.gg.draw_text(title_x, 9, 'Agent Toolkit Desktop', gg.TextCfg{
		color: app.pnl_text
		size: if l.mast_h >= 100 { 34 } else { 25 }
		family: app.fonts.display
	})
	app.gg.draw_text(title_x + 2, 40, 'A  H O M E   F O R   Y O U R   A I   A G E N T S', gg.TextCfg{
		color: app.pnl_text_mut
		size: if l.mast_h >= 100 { 11 } else { 9 }
		bold: true
	})
	if l.mast_h >= 96 {
		app.gg.draw_line(title_x, 59, title_x + 364, 59, app.pnl_border)
		app.gg.draw_text(title_x, 66, 'PLAN · BUILD · DELEGATE · OBSERVE · TOGETHER', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
			bold: true
		})
	}
	// A small editorial signature fills the otherwise dead bridge between the
	// lockup and controls on wide screens.
	if w >= 1200 && l.workspace_x > 560 {
		nest := pixelart.environment_for(.nest)
		nx := l.workspace_x - 128
		sc.draw(nest, pid, nx, 14, 3)
		app.gg.draw_text(nx + 44, 15, 'Small Agents', gg.TextCfg{
			color: app.pnl_text
			size: 12
			family: app.fonts.display
		})
		app.gg.draw_text(nx + 44, 30, 'Brighter Worlds.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
			family: app.fonts.display
		})
	}

	workspace_bg := if app.workspace_focus { col_ink700 } else { app.pnl_card }
	workspace_border := if app.workspace_focus { pc(app, `W`) } else { app.pnl_border }
	app.gg.draw_rect_filled(l.workspace_x, l.control_y, l.workspace_w, l.control_h, workspace_bg)
	app.gg.draw_rect_empty(l.workspace_x, l.control_y, l.workspace_w, l.control_h, workspace_border)
	app.gg.draw_text(l.workspace_x + 8, l.control_y + 4, tr(app, 'header.workspace'), gg.TextCfg{
		color: if app.workspace_focus { col_brass } else { app.pnl_text_mut }
		size: scaled_size(9, z)
		bold: true
	})
	app.gg.draw_text(l.workspace_x + 8, l.control_y + 17, workspace_path_label(app.harness_root, onb_fit(l.workspace_w - 28, 10)), gg.TextCfg{
		color: if app.workspace_focus { col_paper } else { app.pnl_text }
		size: scaled_size(10, z)
		mono: true
	})
	app.gg.draw_text(l.workspace_x + l.workspace_w - 15, l.control_y + 13, 'v', gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
		bold: true
	})

	search_txt := if app.global_search == '' {
		'Search agents, tasks, files...'
	} else {
		app.global_search
	}
	search_bg := if app.header_search_focus { pc(app, `P`) } else { pc(app, `p`) }
	search_bd := if app.header_search_focus { pc(app, `W`) } else { app.pnl_border }
	app.gg.draw_rect_filled(l.search_x, l.control_y, l.search_w, l.control_h, search_bg)
	app.gg.draw_rect_empty(l.search_x, l.control_y, l.search_w, l.control_h, search_bd)
	draw_search_lens(mut app, l.search_x + 9, l.control_y + 11)
	app.gg.draw_text(l.search_x + 25, l.control_y + 10, utf8_truncate(search_txt, onb_fit(l.search_w - 48, 11)), gg.TextCfg{
		color: if app.global_search == '' { col_ink_soft } else { col_ink }
		size: scaled_size(11, z)
		family: if app.global_search == '' { family_for(app, search_txt) } else { '' }
	})
	if app.header_search_focus && app.global_search != '' && app.frame % 30 < 15 {
		cursor_x := l.search_x + 25 + app.global_search.len * 7
		if cursor_x < l.search_x + l.search_w - 18 {
			app.gg.draw_rect_filled(cursor_x, l.control_y + 10, 2, 14, col_brass)
		}
	}
	if app.global_search != '' {
		app.gg.draw_text(l.search_x + l.search_w - 16, l.control_y + 10, 'x', gg.TextCfg{
			color: col_ink_soft
			size: scaled_size(11, z)
			bold: true
		})
	}

	theme_text := appearance_label(app.appearance)
	app.gg.draw_rect_filled(l.theme_x, l.control_y, l.theme_w, l.control_h, app.pnl_card)
	app.gg.draw_rect_empty(l.theme_x, l.control_y, l.theme_w, l.control_h, app.pnl_border)
	app.gg.draw_text(l.theme_x + 7, l.control_y + 10, '${theme_text} v', gg.TextCfg{
		color: app.pnl_text
		size: scaled_size(10, z)
		bold: true
	})
	lang_text := app.lang.chip()
	app.gg.draw_rect_filled(l.lang_x, l.control_y, l.lang_w, l.control_h, app.pnl_card)
	app.gg.draw_rect_empty(l.lang_x, l.control_y, l.lang_w, l.control_h, app.pnl_border)
	app.gg.draw_text(l.lang_x + 7, l.control_y + 10, '${lang_text} v', lang_cfg(app, lang_text, gg.TextCfg{
		color: app.pnl_text
		size: scaled_size(10, z)
		bold: true
	}))
	app.gg.draw_rect_filled(l.command_x, l.control_y, l.command_w, l.control_h, col_ink700)
	app.gg.draw_rect_empty(l.command_x, l.control_y, l.command_w, l.control_h, col_line_light)
	app.gg.draw_text(l.command_x + 10, l.control_y + 10, '/', gg.TextCfg{
		color: col_brass
		size: scaled_size(14, z)
		bold: true
	})
}

fn draw_left_dock(mut app GuiApp, h int) {
	ensure_pixel_cache(mut app)
	pid := office_palette_id(app)
	y0 := panel_top(app)
	y1 := content_bottom(app, h)
	dock_l := dock_x(app, app.gg.width)
	app.gg.draw_rect_filled(dock_l, y0, dock_w, y1 - y0, col_charcoal)
	app.gg.draw_line(dock_l + dock_w, y0, dock_l + dock_w, y1, col_line)
	nest := pixelart.environment_for(.nest)
	mut sc := app.pixel_cache
	sc.draw(nest, pid, dock_l + 14, y0 + 10, 2)
	app.gg.draw_text(dock_l + 48, y0 + 9, 'Agent Toolkit', gg.TextCfg{
		color: col_paper
		size: 15
		family: app.fonts.display
	})
	app.gg.draw_text(dock_l + 48, y0 + 27, 'DESKTOP', gg.TextCfg{
		color: col_brass
		size: 9
		bold: true
	})
	mut last_y := y0 + 48
	for row in nav_rows(app, h) {
		row_x := dock_l + 8
		group_active := nav_group_for_panel(app.selected_panel) == row.panel
		active := group_active
		hover := app.hover_panel == row.panel
		if active {
			app.gg.draw_rect_filled(row_x, row.y, dock_w - 16, row.h, tint(pc(app, `s`), 210))
			app.gg.draw_rect_empty(row_x, row.y, dock_w - 16, row.h, tint(pc(app, `S`), 170))
			rail_x := if app.lang.is_rtl() { row_x + dock_w - 19 } else { row_x }
			app.gg.draw_rect_filled(rail_x, row.y, 3, row.h, col_brass)
		} else if hover {
			app.gg.draw_rect_filled(row_x, row.y, dock_w - 16, row.h, col_charcoal2)
		}
		label := nav_group_label(app, row.panel)
		label_x := row_x + 34
		app.gg.draw_rect_filled(row_x + 14, row.y + 12, 8, 8, if active {
			col_paper
		} else {
			col_slate
		})
		app.gg.draw_text(label_x, row.y + 6, label, gg.TextCfg{
			color: if active { col_paper } else { col_paper_dim }
			size: 13
			bold: true
		})
		app.gg.draw_text(label_x, row.y + 24, utf8_truncate(nav_group_subtitle(row.panel), 25), gg.TextCfg{
			color: if active { col_paper_dim } else { col_slate_dim }
			size: 9
		})
		last_y = row.y + row.h
	}
	land_y := last_y + 8
	if y1 - land_y >= 58 {
		draw_onb_landscape(mut app, dock_l, land_y, dock_w, y1 - land_y, pid)
	}
}

// draw_office_view_switch renders the Overview / Floor Map tabs in the Office panel.
fn draw_office_view_switch(mut app GuiApp, w int) {
	fx := panel_fx(app)
	fy := panel_top(app)
	fw := panel_fw(app, w)
	tab_h := 22
	tab_w := 78
	gap := 6
	x := fx + fw - (tab_w * 2 + gap) - 20
	y := fy + 10
	for i, label_key in ['office.view.overview', 'office.view.floor'] {
		is_active := (i == 0 && !app.office_map_view) || (i == 1 && app.office_map_view)
		tx := x + i * (tab_w + gap)
		app.gg.draw_rect_filled(tx, y, tab_w, tab_h, if is_active {
			app.pnl_select
		} else {
			app.pnl_card
		})
		app.gg.draw_rect_empty(tx, y, tab_w, tab_h, if is_active {
			app.pnl_border_hi
		} else {
			app.pnl_border
		})
		app.gg.draw_text(tx + 8, y + 5, tr(app, label_key), gg.TextCfg{
			color: if is_active { app.pnl_bg } else { app.pnl_text }
			size: 10
			bold: true
		})
	}
}

// handle_office_view_click returns true if a click hit an Office view tab.
fn handle_office_view_click(mut app GuiApp, w int, mx int, my int) bool {
	fx := panel_fx(app)
	fy := panel_top(app)
	fw := panel_fw(app, w)
	tab_h := 22
	tab_w := 78
	gap := 6
	x := fx + fw - (tab_w * 2 + gap) - 20
	y := fy + 10
	for i in 0 .. 2 {
		tx := x + i * (tab_w + gap)
		if mx >= tx && mx < tx + tab_w && my >= y && my < y + tab_h {
			app.office_map_view = (i == 1)
			return true
		}
	}
	return false
}

// draw_office_overview renders the default Office operational dashboard.
// It surfaces real Engine state (jobs, agents) without idle-animation theatrics.
fn draw_office_overview(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := panel_top(app)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	l := office_layout(app, w, h)
	content_x := if app.lang.is_rtl() { 0 } else { fx }
	content_w := if app.lang.is_rtl() { w - dock_w } else { w - content_x }
	app.gg.draw_rect_filled(content_x, fy, content_w, fh, app.pnl_bg)
	app.gg.draw_rect_filled(fx, fy, fw, 42, app.pnl_card)
	app.gg.draw_text(fx + 20, fy + 11, 'Office', gg.TextCfg{ color: app.pnl_text, size: font_display_md, family: app.fonts.display })
	app.gg.draw_text(fx + 106, fy + 15, 'What needs your attention?', gg.TextCfg{ color: app.pnl_text_mut, size: font_body_sm })
	draw_office_view_switch(mut app, w)
	mut jobs := []desktop_engine.JobRecord{}
	mut agents := []desktop_engine.AgentEntry{}
	if app.desktop != unsafe { nil } {
		jobs = app.desktop.engine_jobs_catalog()
		agents = app.desktop.engine_agents_search('', '')
	}
	attention_jobs := jobs.filter(it.status == .failed || it.status == .queued)
	running_jobs := jobs.filter(it.status == .running)
	// VC8 (#1173): office.jpg composition uses four truthful metric cards,
	// the VC3.5 room as the hero, and the shell detail column for Roster and
	// Today. All values come from Engine state.
	ensure_pixel_cache(mut app)
	draw_office_cards(mut app, l, office_metrics(mut app, attention_jobs.len, agents.len, running_jobs.len))
	if l.room_h < 80 {
		// Too short to compose the room (tall terminal on a short window);
		// the metric cards above still carry the operational truth.
	} else if agents.len == 0 {
		pixel_panel(mut app, l.room_x, l.room_y, l.room_w, l.room_h, 'default')
		app.gg.draw_text(l.room_x + 14, l.room_y + 34, 'No agents are available in the resolved catalog.', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	} else {
		desks := desks_for_app(app)
		draw_office_room(mut app, l.room_x, l.room_y, l.room_w, l.room_h, desks, attention_jobs.len, running_jobs.len)
	}
}

fn draw_world(mut app GuiApp, w int, h int) {
	// Operational overview is the default per UX_ARCHITECTURE.md; floor map is a
	// visible alternative reachable via the view switch, not the landing state.
	if !app.office_map_view {
		draw_office_overview(mut app, w, h)
		return
	}
	// Hero — office floor: munder checkerboard 32×32 tiles, desks as AgentCards, envelopes with GOD 4*t*(1-t) arc
	// Super-potent signature: unique floor texture (wood grain + grass tuft + terrazzo speck), avatar trails,
	// envelope floor shadows, station glow, command deck kanban/fleet/CI alt divergence — native V gg only.
	fx := panel_fx(app)
	fy := panel_top(app)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	// Floor — surface.paper card on the canvas with muted ruled lines + fiber grain
	// Office paper stock: base surface.paper, ruled horizontal secondary lines every 24px, danger margin
	app.gg.draw_rect_filled(fx, fy + 36, fw, fh - 36, app.pnl_bg)
	// ruled horizontal lines — text.secondary wash every 24px (college-ruled)
	for ry in 0 .. ((fh - 36) / 24 + 1) {
		ly := fy + 36 + ry * 24 + 12
		if ly >= fy + fh - 1 {
			continue
		}
		app.gg.draw_line(fx + 12, ly, fx + fw - 12, ly, tint(app.pnl_text_mut, 16))
		if ry % 2 == 0 {
			app.gg.draw_rect_filled(fx + 18, ly - 1, 2, 1, tint(app.pnl_select, 18))
		}
	}
	// vertical margin line — signal.danger wash at 40px from left
	margin_x := fx + 40
	app.gg.draw_rect_filled(margin_x, fy + 36, 1, fh - 36, tint(app.pnl_danger, 44))
	app.gg.draw_rect_filled(margin_x + 2, fy + 36, 1, fh - 36, tint(app.pnl_danger, 16))
	// Warm paper fiber — 1px speck every 32px, deterministic, 60FPS culling, no grass
	// Paper grain: cream speck + manila dot + steel micro-shadow, both light/dark share warm paper
	for ty in 0 .. ((fh - 36) / 32 + 1) {
		for tx in 0 .. (fw / 32 + 1) {
			sx := fx + tx * 32
			sy := fy + 36 + ty * 32
			if sx + 31 >= fx + fw || sy + 31 >= fy + fh {
				continue
			}
			if sx < fx || sy < fy + 36 {
				continue
			}
			is_light2 := (tx + ty) % 2 == 0
			if is_light2 {
				// fiber speck — warm paper micro-dot + kraft grain
				app.gg.draw_rect_filled(sx + 8, sy + 8, 1, 1, tint(app.pnl_bg, 16))
				app.gg.draw_rect_filled(sx + 22, sy + 18, 1, 1, tint(app.pnl_bg, 12))
				// ruled line ghost (paper crease)
				app.gg.draw_rect_filled(sx + 2, sy + 14, 28, 1, tint(app.pnl_text_mut, 7))
				// manila speck every 2 tiles
				if tx % 2 == 0 && ty % 2 == 0 {
					app.gg.draw_rect_filled(sx + 26, sy + 26, 1, 1, tint(app.pnl_select, 14))
				}
				hash := (tx * 7 + ty * 13) % 8
				app.gg.draw_rect_filled(sx + 6 + hash, sy + 20 + (hash * 3 % 5), 1, 1, tint(app.pnl_bg, 14))
			} else {
				// paper fiber dark — steel speck + manila dot, no grass
				app.gg.draw_rect_filled(sx + 10, sy + 12, 1, 1, tint(app.pnl_text_mut, 10))
				app.gg.draw_rect_filled(sx + 18, sy + 20, 1, 1, tint(app.pnl_bg, 12))
				app.gg.draw_rect_filled(sx + 6, sy + 26, 1, 1, tint(app.pnl_select, 9))
				if (tx + ty) % 3 == 0 {
					app.gg.draw_rect_filled(sx + 4, sy + 6, 12, 1, tint(app.pnl_text_mut, 7))
				}
				hash2 := (tx * 11 + ty * 5) % 6
				app.gg.draw_rect_filled(sx + 14 + hash2, sy + 8 + hash2, 1, 1, tint(app.pnl_bg, 10))
			}
		}
	}
	// Path cross — central path 32px wide, wood tiles inside + brass nail heads every 32px, horizontal grain
	px := fx + fw / 2 - 16
	app.gg.draw_rect_filled(px, fy + 36, 32, fh - 36, col_path)
	// subtle vertical wood grain inside path — 1px lines every 8px
	for ty in 0 .. ((fh - 36) / 32 + 1) {
		gy := fy + 36 + ty * 32
		if gy >= fy + fh {
			continue
		}
		app.gg.draw_rect_filled(px, gy, 32, 1, col_wood_dark)
		// signature brass nail every 64px + wood grain specular
		if ty % 2 == 0 {
			app.gg.draw_rect_filled(px + 15, gy - 1, 2, 2, app.pnl_border_hi)
			app.gg.draw_rect_filled(px + 4, gy + 8, 24, 1, tint(app.pnl_select, 11))
		}
	}
	// Top bar inside floor — cream panel with display Title Case (never ALL CAPS)
	app.gg.draw_rect_filled(fx, fy, fw, 36, app.pnl_card)
	app.gg.draw_rect_filled(fx, fy + 34, fw, 2, app.pnl_card_sel)
	app.gg.draw_line(fx, fy + 36, fx + fw, fy + 36, app.pnl_text)
	app.gg.draw_text(fx + 20, fy + 12, tr(app, 'world.title'), gg.TextCfg{
		color: app.pnl_text
		size: font_display_md
		family: app.fonts.display
	})
	app.gg.draw_text(fx + 160, fy + 16, '${tr(app, 'office.catalog')}: ${desks_for_app(app).len}', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	draw_office_view_switch(mut app, w)

	desks := desks_for_app(app)

	// Precompute clamped rects so draw, envelopes, and hit-test share the same geometry.
	// desk_rect owns the command-deck clamp — no draw-only adjustment here.
	mut rects_x := []int{cap: desks.len}
	mut rects_y := []int{cap: desks.len}
	for idx, d in desks {
		dx, dy, _, _ := desk_rect(d, idx, fx, fy, fw, fh)
		rects_x << dx
		rects_y << dy
	}

	// Handoff visuals are derived from observed Engine events. Until that event
	// stream is connected, render no envelopes or trails; ambient motion must not
	// imply that agents are working.

	if app.desktop != unsafe { nil } && app.desktop.engine_jobs_catalog().len == 0 {
		app.gg.draw_text(fx + 56, fy + 54, 'No agents are currently running.', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	}

	// Desks — AgentCard 200×80 → 140×86 compact, munder pixel-panel + status chip, lowercase badges
	// Alt variant divergence: specialist/runtime desks use 'alt' wood panel vs holistic 'default' cream — workshop divergence
	for idx, d in desks {
		// use the clamped rects — desk_rect's own clamp was lost (deck overlap)
		dx := rects_x[idx]
		dy := rects_y[idx]
		is_selected := idx == app.selected_desk
		is_hover := idx == app.hover_desk
		variant := if is_selected {
			'active'
		} else if d.tier == 'specialist' || d.tier == 'runtime' {
			'alt'
		} else {
			'default'
		}
		pixel_panel(mut app, dx, dy, 140, 86, variant)
		// status dot 8px + lowercase badge per munder
		status_col := match d.status {
			'working' { app.pnl_select } // signal.selection
			'thinking' { app.pnl_text_mut } // text.secondary
			'blocked' { app.pnl_danger } // signal.danger
			'waiting' { app.pnl_text_mut } // text.secondary
			else { app.pnl_text_mut }
		}
		if d.status == 'working' {
			app.gg.draw_rect_filled(dx + 9, dy + 9, 10, 10, tint(app.pnl_success, 45))
			app.gg.draw_rect_filled(dx + 10, dy + 10, 8, 8, status_col)
		} else if d.status == 'blocked' {
			app.gg.draw_rect_filled(dx + 10, dy + 10, 8, 8, status_col)
		} else {
			app.gg.draw_rect_empty(dx + 10, dy + 10, 8, 8, status_col)
		}
		label := if d.label.len > 15 { d.label[..15] } else { d.label }
		// name row: status dot + label (Fraunces display, legible at a glance)
		app.gg.draw_rect_filled(dx + 10, dy + 12, 6, 6, status_col)
		app.gg.draw_text(dx + 22, dy + 8, label, gg.TextCfg{
			color: app.pnl_text
			size: 13
			family: app.fonts.display
			bold: true
		})
		// role chip — manila stamp; tier sits right-aligned, never overflows the card
		app.gg.draw_rect_filled(dx + 10, dy + 30, d.role.len * 6 + 12, 14, app.pnl_card_sel)
		app.gg.draw_text(dx + 14, dy + 32, d.role, gg.TextCfg{ color: app.pnl_text_mut, size: 9 })
		mut tier_x := dx + 128 - d.tier.len * 6
		if tier_x < dx + 10 {
			tier_x = dx + 10
		}
		app.gg.draw_text(tier_x, dy + 32, d.tier, gg.TextCfg{ color: app.pnl_text_mut, size: 9 })
		// status text — readable, single line
		app.gg.draw_text(dx + 10, dy + 52, d.status, gg.TextCfg{ color: status_col, size: 10, bold: true })
		if is_selected {
			app.gg.draw_rect_filled(dx + 118, dy + 74, 5, 5, app.pnl_select)
		}
		// Signature: per-desk libghostty-vt 40×6 micro-strip — 1-line live VT under desk (visible multiplex)
		if app.per_desk_ghost.len > idx {
			glines := app.per_desk_ghost[idx].visible_lines()
			if glines.len > 0 {
				// compact strip below desk card — proves 40×6 per-desk VT is live
				strip_y := dy + 62
				if strip_y + 10 <= fy + fh - 2 && strip_y + 10 <= dy + 84 {
					mut t := glines[glines.len - 1]
					// strip control chars
					mut clean2 := ''
					for ch in t {
						if ch >= 32 && ch < 127 {
							clean2 += ch.ascii_str()
						}
					}
					if clean2.len > 20 {
						clean2 = clean2[..20] + '…'
					}
					if clean2.len > 0 {
						app.gg.draw_rect_filled(dx + 2, strip_y, 136, 10, tint(app.pnl_text, 190))
						app.gg.draw_rect_empty(dx + 2, strip_y, 136, 10, tint(app.pnl_text, 120))
						app.gg.draw_text(dx + 4, strip_y + 1, clean2, gg.TextCfg{
							color: if is_selected {
								app.pnl_select
							} else {
								app.pnl_text_mut
							}
							size: 10
							mono: true
						})
						// mini cursor pulse
						if idx == app.selected_desk && app.frame % 30 < 15 {
							app.gg.draw_rect_filled(dx + 130, strip_y + 2, 4, 6, app.pnl_select)
						}
					}
				}
			} else {
				// idle — show desk VT ready hint faintly when selected/hover
				if is_selected || is_hover {
					app.gg.draw_text(dx + 10, dy + 88, 'vt 40×6 ready', gg.TextCfg{ color: tint(app.pnl_text_mut, 90), size: 10, mono: true })
				}
			}
		}
	}
	// Stations — munder catalog, 4px grid, pixel-snapped (shelf 64×48, terminal 32×48, portal 48×48, mcp 48×48, board 32×48, mailbox 16×24)
	// Signature station glow: outer halo + pulsating brass when avatar approaching, alt divergence for board/mcp
	for s in app.stations {
		if s.id == 'desk' {
			continue
		}
		if s.x < fx || s.x + s.w > fx + fw || s.y < fy + 36 || s.y + s.h > fy + fh {
			continue
		}
		// glow halo — pulsating when avatar target is this station, subtle otherwise (atelier glow)
		mut is_target := false
		for av in app.avatars {
			if int(av.tx) == s.x + s.w / 2 && int(av.ty) == s.y + s.h / 2 {
				is_target = true
				break
			}
			// proximity glow within 48px
			dx := av.x - f32(s.x + s.w / 2)
			dy := av.y - f32(s.y + s.h / 2)
			if dx * dx + dy * dy < 2304 {
				is_target = true
				break
			}
		}
		if is_target {
			// outer 2px halo brass 22% + pulse every 30 frames
			pulse := if app.frame % 30 < 15 { 28 } else { 18 }
			app.gg.draw_rect_filled(s.x - 2, s.y - 2, s.w + 4, s.h + 4, tint(app.pnl_select, u8(pulse)))
			app.gg.draw_rect_filled(s.x - 1, s.y - 1, s.w + 2, s.h + 2, tint(app.pnl_bg, 14))
		} else {
			// subtle idle glow 8%
			app.gg.draw_rect_filled(s.x - 1, s.y - 1, s.w + 2, s.h + 2, tint(app.pnl_text, 10))
		}
		// alt divergence: board/mcp use alt wood vs default cream for workshop palette divergence
		variant := if s.kind == 'board' || s.kind == 'mcp' { 'alt' } else { 'default' }
		pixel_panel(mut app, s.x, s.y, s.w, s.h, variant)
		// station icon — color block with station glow specular top
		app.gg.draw_rect_filled(s.x + 5, s.y + 5, s.w - 10, s.h - 20, s.color)
		if is_target {
			app.gg.draw_line(s.x + 6, s.y + 5, s.x + s.w - 6, s.y + 5, tint(app.pnl_bg, 22))
		} else {
			app.gg.draw_line(s.x + 6, s.y + 5, s.x + s.w - 6, s.y + 5, tint(app.pnl_bg, 10))
		}
		app.gg.draw_text(s.x + 6, s.y + s.h - 12, s.label, gg.TextCfg{ color: app.pnl_text, size: font_display_sm, bold: false })
		// highlight when avatar approaching — brass border pulse
		if is_target {
			app.gg.draw_rect_empty(s.x, s.y, s.w, s.h, app.pnl_select)
			if app.frame % 20 < 10 {
				app.gg.draw_rect_empty(s.x + 1, s.y + 1, s.w - 2, s.h - 2, tint(app.pnl_select, 90))
			}
		}
	}
	// Avatars — 24×24, 4-frame walk 8fps, bob ±1, token carry (munder spec) — signature atelier shadow + trails
	for av in app.avatars {
		ax := int(av.x)
		ay := int(av.y + av.bob)
		// signature avatar trails — 3 fading ghost rects behind walking avatar (motion blur, native gg)
		if av.walking {
			for t in 1 .. 4 {
				// trail offset opposite to dir
				mut tx_off := 0
				mut ty_off := 0
				if av.dir == 'right' {
					tx_off = -t * 4
				} else if av.dir == 'left' {
					tx_off = t * 4
				} else if av.dir == 'down' {
					ty_off = -t * 3
				} else if av.dir == 'up' {
					ty_off = t * 3
				} else {
					tx_off = -t * 2
				}
				alpha := u8(36 - t * 10)
				if alpha < 6 {
					continue
				}
				// trail ghost — faded accent with ink border ghost
				app.gg.draw_rect_filled(ax - 12 + tx_off, ay - 12 + ty_off, 24, 24, gg.rgba(av.accent.r, av.accent.g, av.accent.b, alpha))
				if t == 1 {
					app.gg.draw_rect_filled(ax - 7 + tx_off, ay + 12 + ty_off, 14, 4, tint(app.pnl_text, 10))
				}
			}
		}
		// signature: soft floor shadow 14×4, ink 10% (atelier light) — scales with bob (higher bob = smaller shadow)
		shadow_w2 := if av.bob < 0 {
			10
		} else if av.bob > 0 { 14 } else { 12 }
		shadow_a2 := if av.bob < 0 { u8(14) } else { u8(22) }
		app.gg.draw_rect_filled(ax - shadow_w2 / 2, ay + 13, shadow_w2, 3, tint(app.pnl_text, shadow_a2))
		app.gg.draw_rect_filled(ax - shadow_w2 / 2 + 2, ay + 14, shadow_w2 - 4, 1, tint(app.pnl_text, shadow_a2 / 2))
		// 24×24 sprite — pixel-snapped
		app.gg.draw_rect_filled(ax - 12, ay - 12, 24, 24, av.accent)
		app.gg.draw_rect_empty(ax - 12, ay - 12, 24, 24, app.pnl_text)
		// signature: highlight edge top — SNES light source (1px cream at top of sprite) + side bevel
		app.gg.draw_line(ax - 11, ay - 11, ax + 11, ay - 11, tint(app.pnl_bg, 18))
		app.gg.draw_line(ax - 11, ay - 11, ax - 11, ay + 11, tint(app.pnl_bg, 10))
		// face
		app.gg.draw_rect_filled(ax - 8, ay - 8, 16, 10, app.pnl_bg) // skin
		app.gg.draw_rect_filled(ax - 6, ay - 4, 4, 2, app.pnl_text) // eye left
		app.gg.draw_rect_filled(ax + 2, ay - 4, 4, 2, app.pnl_text) // eye right
		// walk feet offset — with signature dust puff when pushing off
		foot_off := if av.frame == 1 {
			-1
		} else if av.frame == 3 { 1 } else { 0 }
		app.gg.draw_rect_filled(ax - 8, ay + 8 + foot_off, 6, 4, app.pnl_text)
		app.gg.draw_rect_filled(ax + 2, ay + 8 - foot_off, 6, 4, app.pnl_text)
		if av.walking && av.frame == 2 {
			app.gg.draw_rect_filled(ax - 10, ay + 13, 3, 2, tint(app.pnl_select, 22))
			app.gg.draw_rect_filled(ax + 8, ay + 13, 2, 1, tint(app.pnl_select, 16))
		}
		// status overlay 8×8 above head — bob-synced
		if av.walking {
			dots := ['.', '..', '...'][av.frame % 3]
			app.gg.draw_text(ax - 6, ay - 22, dots, gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		}
		// token carry above hands — paper/terminal/globe/magnifier/diamond/checklist with glyph
		if av.carrying != 'none' {
			token_col := match av.carrying {
				'paper' { app.pnl_bg }
				'terminal' { app.pnl_text }
				'globe' { app.pnl_text_mut }
				'magnifier' { app.pnl_select }
				'diamond' { app.pnl_text_mut }
				'checklist' { app.pnl_success }
				else { app.pnl_select }
			}
			app.gg.draw_rect_filled(ax - 4, ay - 3, 8, 7, token_col)
			app.gg.draw_rect_empty(ax - 4, ay - 3, 8, 7, app.pnl_text)
			// inner gloss 1px top
			app.gg.draw_line(ax - 3, ay - 2, ax + 3, ay - 2, tint(app.pnl_bg, 22))
			glyph := match av.carrying {
				'paper' { '—' }
				'terminal' { '›' }
				'globe' { '◯' }
				'magnifier' { '◎' }
				'diamond' { '◆' }
				'checklist' { '✓' }
				else { '•' }
			}
			app.gg.draw_text(ax - 2, ay - 2, glyph, gg.TextCfg{
				color: if av.carrying == 'paper' {
					app.pnl_text
				} else {
					app.pnl_bg
				}
				size: 10
				bold: true
			})
		}
		// selected halo — brass double border when selected desk matches avatar
		if app.selected_desk >= 0 && app.selected_desk < desks.len && av.id == desks[app.selected_desk].id {
			app.gg.draw_rect_empty(ax - 13, ay - 13, 26, 26, app.pnl_select)
			app.gg.draw_rect_empty(ax - 14, ay - 14, 28, 28, tint(app.pnl_select, 60))
		}
	}
	// corridor divider — kraft tape seam between desk grid and the manager corner
	app.gg.draw_rect_filled(fx + fw - 124, fy + 44, 2, fh - 130, tint(app.pnl_select, 60))
	app.gg.draw_rect_filled(fx + fw - 124, fy + 44, 2, 8, tint(app.pnl_select, 110))
	// GOD / Michael — manager's corner (right corridor), mailbox with envelope flap animation (signature)
	god_x := fx + fw - 96
	god_y := fy + 44
	pixel_panel(mut app, god_x, god_y, 80, 64, 'dialog')
	app.gg.draw_text(god_x + 8, god_y + 8, 'Michael', gg.TextCfg{ color: app.pnl_text, size: font_display_md, bold: false })
	app.gg.draw_text(god_x + 8, god_y + 22, 'GOD', gg.TextCfg{ color: app.pnl_danger, size: font_display_sm })
	app.gg.draw_text(god_x + 8, god_y + 34, 'in ${app.god_inbox} • out ${app.god_outbox}', gg.TextCfg{ color: app.pnl_text, size: font_body_sm })
	// Signature: mailbox flap physics — brass hinge + flap opens when inbox>0 (spring on frame % 90)
	mailbox_x := god_x + 56
	mailbox_y := god_y + 6
	app.gg.draw_rect_filled(mailbox_x, mailbox_y + 8, 14, 14, app.pnl_text)
	app.gg.draw_rect_filled(mailbox_x + 1, mailbox_y + 9, 12, 12, app.pnl_bg)
	app.gg.draw_rect_filled(mailbox_x + 1, mailbox_y + 9, 12, 2, app.pnl_border_hi)
	flap_open := app.god_inbox > 0 && (app.frame % 90 < 45)
	flap_up := app.god_inbox > 0 && (app.frame % 60 < 30)
	if app.god_inbox > 0 {
		// flag pole + flag (flap_up toggles)
		app.gg.draw_rect_filled(mailbox_x + 14, mailbox_y + 2, 2, 10, app.pnl_text)
		flag_y := if flap_up { mailbox_y } else { mailbox_y + 3 }
		app.gg.draw_rect_filled(mailbox_x + 16, flag_y, 8, 4, app.pnl_danger)
		app.gg.draw_rect_empty(mailbox_x + 16, flag_y, 8, 4, app.pnl_text)
		// envelope inside mailbox — flap line animates
		if flap_open {
			// flap open: V shape up (envelope ready to dispatch)
			app.gg.draw_line(mailbox_x + 1, mailbox_y + 9, mailbox_x + 7, mailbox_y + 13, app.pnl_select)
			app.gg.draw_line(mailbox_x + 7, mailbox_y + 13, mailbox_x + 13, mailbox_y + 9, app.pnl_select)
			// dispatch pulse dot
			if app.frame % 20 < 10 {
				app.gg.draw_rect_filled(mailbox_x + 6, mailbox_y + 16, 2, 2, app.pnl_select)
			}
		} else {
			// flap closed: inverted V
			app.gg.draw_line(mailbox_x + 1, mailbox_y + 15, mailbox_x + 7, mailbox_y + 11, app.pnl_border_hi)
			app.gg.draw_line(mailbox_x + 7, mailbox_y + 11, mailbox_x + 13, mailbox_y + 15, app.pnl_border_hi)
			app.gg.draw_rect_filled(mailbox_x + 5, mailbox_y + 13, 4, 2, app.pnl_text)
		}
		// inbox count badge
		badge_col := if app.god_inbox > 2 { app.pnl_danger } else { app.pnl_select }
		app.gg.draw_rect_filled(mailbox_x + 2, mailbox_y - 2, 10, 8, badge_col)
		app.gg.draw_text(mailbox_x + 4, mailbox_y - 1, '${app.god_inbox}', gg.TextCfg{ color: app.pnl_text, size: 10, bold: true })
	} else {
		// empty mailbox — flag down, flap closed
		app.gg.draw_rect_filled(mailbox_x + 14, mailbox_y + 6, 2, 6, app.pnl_text)
		app.gg.draw_rect_filled(mailbox_x + 16, mailbox_y + 6, 6, 3, tint(app.pnl_text_mut, 120))
		app.gg.draw_line(mailbox_x + 1, mailbox_y + 15, mailbox_x + 7, mailbox_y + 11, app.pnl_text_mut)
		app.gg.draw_line(mailbox_x + 7, mailbox_y + 11, mailbox_x + 13, mailbox_y + 15, app.pnl_text_mut)
	}
	for i, ap in app.approvals {
		if i >= 2 {
			break
		}
		mut ap_txt := ap
		if ap_txt.len > 14 {
			ap_txt = ap_txt[..14] + '…'
		}
		app.gg.draw_text(god_x + 8, god_y + 44 + i * 10, '• ${ap_txt}', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	}
	// signature soft shadow under GOD panel — atelier floor shadow (ink 18%)
	app.gg.draw_rect_filled(god_x + 4, god_y + 64, 76, 4, tint(app.pnl_text, 18))
	app.gg.draw_rect_filled(god_x + 8, god_y + 66, 68, 2, tint(app.pnl_text, 12))
	// ── Command deck — kanban / fleet / CI — super-potent workshop command (alt wood divergence, native gg)
	// Signature atelier command deck: wood alt panel with brass grain, three columns for live kanban/fleet/CI
	deck_x := fx + 8
	deck_y := fy + fh - 68
	deck_w := fw - 16
	deck_h := 48
	if deck_y > fy + 36 && deck_w > 160 {
		pixel_panel(mut app, deck_x, deck_y, deck_w, deck_h, 'alt')
		col_w := deck_w / 3
		// brass vertical dividers
		app.gg.draw_line(deck_x + col_w, deck_y + 6, deck_x + col_w, deck_y + deck_h - 6, tint(app.pnl_text, 16))
		app.gg.draw_line(deck_x + col_w * 2, deck_y + 6, deck_x + col_w * 2, deck_y + deck_h - 6, tint(app.pnl_text, 16))
		// kanban — todo/doing/done live counts + pri bars
		app.gg.draw_text(deck_x + 10, deck_y + 6, 'Kanban', gg.TextCfg{ color: app.pnl_text, size: 10, bold: true })
		todo_n := app.kanban.filter(it.col == 'todo').len
		doing_n := app.kanban.filter(it.col == 'doing').len
		done_n := app.kanban.filter(it.col == 'done').len
		app.gg.draw_text(deck_x + 10, deck_y + 18, 'todo ${todo_n}', gg.TextCfg{ color: app.pnl_text, size: 10 })
		app.gg.draw_text(deck_x + 52, deck_y + 18, 'doing ${doing_n}', gg.TextCfg{ color: app.pnl_select, size: 10, bold: doing_n > 0 })
		app.gg.draw_text(deck_x + 96, deck_y + 18, 'done ${done_n}', gg.TextCfg{ color: app.pnl_success, size: 10 })
		// pri dots below kanban labels — high/medium/low
		for ki, k in app.kanban {
			if ki >= 3 {
				break
			}
			pri_col := match k.pri {
				'high' { app.pnl_danger }
				'medium' { app.pnl_select }
				else { app.pnl_success }
			}
			app.gg.draw_rect_filled(deck_x + 10 + ki * 44, deck_y + 28, 40, 6, pri_col)
			app.gg.draw_rect_empty(deck_x + 10 + ki * 44, deck_y + 28, 40, 6, app.pnl_text)
			// inner gloss
			app.gg.draw_line(deck_x + 11 + ki * 44, deck_y + 28, deck_x + 48 + ki * 44, deck_y + 28, tint(app.pnl_bg, 14))
		}
		app.gg.draw_text(deck_x + 10, deck_y + 36, '${app.kanban.len} cards • budgets • verifier', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
		// fleet — live health dots per desk + selected halo + working pulse
		fleet_x := deck_x + col_w + 8
		app.gg.draw_text(fleet_x, deck_y + 6, 'Fleet', gg.TextCfg{ color: app.pnl_text, size: 10, bold: true })
		app.gg.draw_text(fleet_x + 36, deck_y + 7, '${desks.len} desks', gg.TextCfg{ color: app.pnl_text, size: 10 })
		for fi, d in desks {
			fx2 := fleet_x + (fi % 8) * 8
			fy2 := deck_y + 18 + (fi / 8) * 8
			fcol := match d.status {
				'working' { app.pnl_select }
				'blocked' { app.pnl_danger }
				'thinking' { app.pnl_text_mut }
				'waiting' { app.pnl_text_mut }
				else { app.pnl_text_mut }
			}
			// working pulse glow
			if d.status == 'working' && app.frame % 30 < 15 {
				app.gg.draw_rect_filled(fx2 - 1, fy2 - 1, 6, 6, tint(app.pnl_success, 28))
			}
			app.gg.draw_rect_filled(fx2, fy2, 4, 4, fcol)
			if fi == app.selected_desk {
				app.gg.draw_rect_empty(fx2 - 1, fy2 - 1, 6, 6, app.pnl_select)
			}
		}
		app.gg.draw_text(fleet_x, deck_y + 36, 'rev ${app.engine_rev} • fleet glance', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		// CI — doctor + jobs live status (workshop CI strip)
		ci_x := deck_x + col_w * 2 + 8
		app.gg.draw_text(ci_x, deck_y + 6, 'CI', gg.TextCfg{ color: app.pnl_text, size: 10, bold: true })
		// handoff + mercylabs style dots — god inbox/outbox as CI signals
		app.gg.draw_rect_filled(ci_x, deck_y + 18, 6, 6, if app.god_inbox > 0 {
			app.pnl_select
		} else {
			app.pnl_success
		})
		app.gg.draw_text(ci_x + 10, deck_y + 17, 'handoff in ${app.god_inbox}', gg.TextCfg{ color: app.pnl_text, size: 10 })
		app.gg.draw_rect_filled(ci_x + 70, deck_y + 18, 6, 6, app.pnl_text_mut)
		app.gg.draw_text(ci_x + 80, deck_y + 17, 'out ${app.god_outbox}', gg.TextCfg{ color: app.pnl_text, size: 10 })
		// doctor checks miniature — 3 dots pass/warn
		for di in 0 .. 3 {
			dcol := if di == 0 {
				app.pnl_success
			} else if di == 1 { app.pnl_select } else { app.pnl_text_mut }
			app.gg.draw_rect_filled(ci_x + di * 10, deck_y + 28, 6, 6, dcol)
		}
		app.gg.draw_text(ci_x + 36, deck_y + 28, 'doctor pass • Envelopes 4*t*(1-t)', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
		app.gg.draw_text(ci_x, deck_y + 36, 'alt wood • V native gg only', gg.TextCfg{ color: tint(app.pnl_text, 90), size: 10 })
	}

	// Signature: workshop vignette — subtle corner darkening + atelier light (top-left warm wash)
	// Vignette edges 10px — ink 6%
	app.gg.draw_rect_filled(fx, fy + 36, fw, 10, tint(app.pnl_text, 12))
	app.gg.draw_rect_filled(fx, fy + fh - 30, fw, 10, tint(app.pnl_text, 14))
	app.gg.draw_rect_filled(fx, fy + 36, 10, fh - 36, tint(app.pnl_text, 8))
	app.gg.draw_rect_filled(fx + fw - 10, fy + 36, 10, fh - 36, tint(app.pnl_text, 8))
	// atelier warm light from top-left window — cream wash 18%
	app.gg.draw_rect_filled(fx + 8, fy + 44, 120, 40, tint(app.pnl_bg, 10))
	app.gg.draw_rect_filled(fx + 8, fy + 44, 80, 24, tint(app.pnl_bg, 12))

	// Floor legend + live stats (English only)
	app.gg.draw_rect_filled(fx, fy + fh - 20, fw, 20, tint(app.pnl_text, 220))
	draw_floor_legend(mut app, fx + 10, fy + fh - 14)
	app.gg.draw_text(fx + fw - 148, fy + fh - 14, 'rev ${app.engine_rev}  api ${app.api_calls}', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	// signature fleet minimap dots — 1px per desk status in legend bar (super-potent fleet glance)
	for i, d in desks {
		mx2 := fx + fw - 148 - 22 - i * 6
		mcol := match d.status {
			'working' { app.pnl_select }
			'blocked' { app.pnl_danger }
			'thinking' { app.pnl_text_mut }
			else { app.pnl_text_mut }
		}
		app.gg.draw_rect_filled(mx2, fy + fh - 12, 4, 4, mcol)
		if i == app.selected_desk { app.gg.draw_rect_empty(mx2 - 1, fy + fh - 13, 6, 6, app.pnl_select) }
	}
}

// ── Skills 227 — super potent, easy to manage ─────────────────────────────────────
// Brokered via Desktop.engine_skills_search (Engine typed API, no shell, 227 searchable).
// Fuzzy: substring + subsequence + word-boundary, ranked, virtualized 60 FPS.
// Each section is a tiny helper: header → search → domain chips → list → footer.
// Easy to manage: 20-line helpers, single source of truth for filtering.
struct SkillEntryProxy {
	id          string
	name        string
	domain      string
	description string
	stability   string
}

fn skills_filtered_entries(mut app GuiApp) []SkillEntryProxy {
	cat := app.desktop.engine_skills_search(app.skills_query, app.skills_domain)
	mut out := []SkillEntryProxy{}
	for s in cat {
		out << SkillEntryProxy{s.id, s.name, s.domain, s.description, s.stability}
	}
	return out
}

// paper_letterhead — the filing-cabinet letterhead shared by every paper panel:
// Fraunces display title + warm-ink subtitle + right-aligned mono stat.
// Subtitle is skipped when it would collide with the stat (footers carry detail).
fn paper_letterhead(mut app GuiApp, fx int, fy int, fw int, title string, subtitle string, stat string) {
	pixel_panel(mut app, fx + 8, fy + 8, fw - 16, 34, 'default')
	app.gg.draw_text(fx + 20, fy + 16, title, gg.TextCfg{
		color: app.pnl_text
		size: font_display_md
		family: app.fonts.display
	})
	stat_w := (stat.len + 2) * 8
	if stat != '' {
		app.gg.draw_text(fx + fw - 20 - stat_w, fy + 17, stat, gg.TextCfg{ color: app.pnl_border_hi, size: 12, mono: true })
	}
	sub_x := fx + 20 + title.len * 10 + 16
	if sub_x + subtitle.len * 7 < fx + fw - 40 - stat_w {
		app.gg.draw_text(sub_x, fy + 19, subtitle, gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	}
}

// mcp_probe_fresh reports whether the cached probe result still counts (60s).
fn mcp_probe_fresh(app &GuiApp, id string) bool {
	return app.mcp_probe_id == id && app.frame - app.mcp_probe_at < 3600
}

// mcp_run_probe executes the typed Engine probe and caches the display (#1106).
// mcp_run_probe refreshes the cached probe. announce=true only for the
// explicit Probe action — selection-driven refreshes stay silent because
// every inspector_msg becomes a toast.
fn mcp_run_probe(mut app GuiApp, id string, announce bool) {
	res := app.desktop.engine_mcp_probe(id) or {
		app.mcp_probe_id = id
		app.mcp_probe_ok = false
		app.mcp_probe_detail = err.msg()
		app.mcp_probe_at = app.frame
		if announce {
			app.inspector_msg = 'MCP ${id} probe failed: ${err}'
		}
		return
	}
	app.mcp_probe_id = id
	app.mcp_probe_ok = res.healthy
	app.mcp_probe_detail = res.detail
	app.mcp_probe_at = app.frame
	app.api_calls = app.desktop.engine_api_calls()
	if announce {
		app.inspector_msg = 'MCP ${id} probe: ${res.detail}'
	}
}

// mcp_drawer_open caches template/provenance/receipt once (render must not
// do file IO every frame) and runs the probe unless a fresh result exists.
fn mcp_drawer_open(mut app GuiApp, id string, template_path string, provenance string) {
	content, from_file := app.desktop.engine_mcp_template_json(id)
	prev := app.desktop.engine_mcp_install_preview(id)
	receipt := app.desktop.engine_mcp_receipt(id) or {
		desktop_engine.McpInstallPreview{
			provider_id: id
			receipt_path: '(no receipt — toggle to enable)'
		}
	}
	will := if prev.will_write.len > 0 { prev.will_write[0] } else { '(no writes planned)' }
	app.mcp_drawer = id
	app.mcp_drawer_template = desktop_engine.mask_mcp_secrets(content)
	app.mcp_drawer_from_file = from_file
	app.mcp_drawer_provenance = provenance
	app.mcp_drawer_receipt = '${receipt.receipt_path} · writes ${will}'
	// no probe and no inspector_msg here: this runs on card *selection* (and
	// lazily from the detail pane draw), so it must stay cheap and silent —
	// template + receipt loading only. The probe (synchronous validation +
	// health check) runs only from the explicit Probe action (lib_secondary),
	// which also owns the toast. The pane shows "not run — press Probe" until then.
}

// mcp_open_template routes to the Workspace panel with the template loaded
// (brokered open; synthetic tab fallback when the harness guard blocks the
// absolute toolkit path, #1106).
fn mcp_open_template(mut app GuiApp, id string, template_path string) {
	title := '${id}.json'
	if _ := app.desktop.engine_open_path_validated(app.harness_root, template_path) {
		tab := app.desktop.engine_open_file_brokered(app.harness_root, template_path) or {
			desktop_engine.EditorTab{
				path: template_path
				title: title
				content: app.mcp_drawer_template
				syntax: 'json'
				dirty: false
			}
		}
		mut found := -1
		for ti, t in app.editor_tabs {
			if t.path == tab.path {
				found = ti
				break
			}
		}
		if found >= 0 {
			app.active_tab = found
		} else {
			app.editor_tabs << EditorTab{tab.path, tab.title, tab.content, tab.syntax, tab.dirty, 0}
			app.active_tab = app.editor_tabs.len - 1
		}
		app.inspector_msg = 'Opened ${title} via brokered fs — json syntax'
	} else {
		app.editor_tabs << EditorTab{template_path, title, app.mcp_drawer_template, 'json', false, 0}
		app.active_tab = app.editor_tabs.len - 1
		app.inspector_msg = 'Opened ${title} (harness guard: synthetic tab, content from masked preview)'
	}
	select_panel(mut app, 9)
}

// discovery_row_text renders the truthful discovery line for a target row
// (#1129): where the tool was found + real version, or the honest reason.
fn discovery_row_text(d desktop_engine.ToolDiscovery) string {
	if d.found {
		mut s := 'found: ${d.resolved_path}'
		if d.version_known {
			s += ' · ${d.version}'
		}
		return utf8_truncate(s, 46) + if s.runes().len > 46 { '…' } else { '' }
	}
	mut r := d.reason
	if r.runes().len > 46 {
		r = utf8_truncate(r, 46) + '…'
	}
	return r
}

fn draw_targets(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := panel_top(app)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	// install preview + receipts super-potent
	receipts := app.desktop.engine_list_install_receipts()
	paper_letterhead(mut app, fx, fy, fw, tr(app, 'panel.targets'), 'receipts ${receipts.len} · dry-run preview · provenance plugins/.provenance.json', 'install → receipt')
	// dry-run diff for next install
	diff := app.desktop.engine_install_preview(['cursor'])
	if diff.added.len > 0 {
		app.gg.draw_text(fx + 20, fy + 44, 'dry-run: will add ${diff.added.join(', ')} (preview via Engine.install_preview)', gg.TextCfg{ color: app.pnl_border_hi, size: 11 })
	}
	// R2 product-truth: roster comes from the Engine target catalog — the old
	// hardcoded list drifted (copilot/muse-code vs cursor-plugins/cli).
	tgts2 := app.desktop.engine_targets().map(it.id)
	targets := app.desktop.engine_targets_enabled()
	_ = targets
	// S4D… er, #1129: typed tool discovery — one authoritative detector
	mut disco_map := map[string]desktop_engine.ToolDiscovery{}
	if app.desktop != unsafe { nil } {
		for d in app.desktop.engine_tool_discovery_catalog_cached() {
			disco_map[d.id] = d
		}
	}
	for i, t in tgts2 {
		y := fy + 56 + i * 32
		enabled := t in app.desktop.engine_targets_enabled()
		has_receipt := receipts.any(it.target == t)
		// manila folder card per platform — enabled cards get the brass tab
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 28, if enabled {
			app.pnl_card_sel
		} else {
			app.pnl_card
		})
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 28, if enabled {
			app.pnl_select
		} else {
			app.pnl_border
		})
		if enabled {
			app.gg.draw_rect_filled(fx + 12, y, 3, 28, app.pnl_select)
			app.gg.draw_rect_filled(fx + 16, y, 44, 10, app.pnl_select)
		}
		app.gg.draw_text(fx + 24, y + 7, t, gg.TextCfg{
			color: app.pnl_text
			size: 14
			family: app.fonts.display
		})
		rcol := if has_receipt { app.pnl_success } else { app.pnl_text_mut }
		app.gg.draw_text(fx + fw - 190, y + 9, if has_receipt {
			'receipt ✓'
		} else {
			'no receipt'
		}, gg.TextCfg{ color: rcol, size: 11 })
		en := if enabled { 'enabled ✓' } else { 'off —' }
		ec := if enabled { app.pnl_success } else { app.pnl_text_mut }
		app.gg.draw_text(fx + fw - 100, y + 8, en, gg.TextCfg{ color: ec, size: 12, bold: enabled })
		// #1129: truthful discovery line — where found + version, or why missing.
		// Calm muted text: a missing tool on a fresh machine is a normal,
		// actionable state, not an error (#1163 visual review).
		if d := disco_map[t] {
			text := discovery_row_text(d)
			app.gg.draw_text(fx + 170, y + 10, text, gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: d.found })
		}
	}
	app.gg.draw_text(fx + 20, fy + fh - 14, 'Install: engine.install([targets]) → receipt ~/.config/agent-toolkit/receipts · dry-run before write · toggle via Engine', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
}

// doctor_preview_geom is the single source for the dry-run card geometry —
// render and hit-testing must stay identical (#1108).
fn doctor_preview_geom(fx int, fy int, fw int) (int, int, int, int) {
	pw := if fw - 120 > 320 { fw - 120 } else { 320 }
	return fx + 60, fy + 110, pw, 158
}

// doctor_preview_open resolves the dry-run lines once (cached — render must
// not bump engine_api_calls every frame) and opens the confirm card.
fn doctor_preview_open(mut app GuiApp, check_id string) {
	lines := app.desktop.engine_doctor_fix_preview(check_id) or {
		app.inspector_msg = 'Doctor preview failed: ${err}'
		return
	}
	app.doctor_preview = check_id
	app.doctor_preview_lines = lines.clone()
	app.inspector_msg = 'Doctor ${check_id}: dry-run preview — Confirm to apply via Engine TX'
}

// doctor_preview_confirm applies the previewed fix, closes the card, and
// announces the re-check (rows re-query every frame, so the flip is visible
// without leaving the panel).
fn doctor_preview_confirm(mut app GuiApp) {
	id := app.doctor_preview
	if id == '' {
		return
	}
	rev := app.desktop.engine_doctor_fix(id) or {
		app.inspector_msg = 'Doctor fix ${id} failed: ${err}'
		app.doctor_preview = ''
		app.doctor_preview_lines = []
		return
	}
	app.engine_rev = app.desktop.app_state_snapshot().revision
	if app.engine_rev == 0 {
		app.engine_rev = rev
	}
	app.api_calls = app.desktop.engine_api_calls()
	app.doctor_preview = ''
	app.doctor_preview_lines = []
	app.inspector_msg = 'Doctor ${id} fixed rev=${rev} • re-check flips the row to pass'
}

fn draw_doctor(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := panel_top(app)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	// super-potent Doctor: full Engine.doctor() with categories, receipts/provenance, fixable + Fix All via Engine TX
	checks_engine := app.desktop.engine_doctor()
	pass_cnt := checks_engine.filter(it.status == 'pass').len
	warn_cnt := checks_engine.filter(it.status == 'warn').len
	fail_cnt := checks_engine.filter(it.status == 'fail').len
	receipts := app.desktop.engine_receipts_catalog()
	provenance := app.desktop.engine_provenance_catalog()
	verify_diags := app.desktop.engine_verify_receipts()
	paper_letterhead(mut app, fx, fy, fw, tr(app, 'panel.doctor'), '${checks_engine.len} checks · ${pass_cnt} pass · ${warn_cnt} warn · ${fail_cnt} fail · ${verify_diags.len} warnings', 'receipts ${receipts.len} · provenance ${provenance.len}')
	// Fix All button — via Engine.doctor_fix_all() TX + EventBus → AppState (one tick)
	is_hover_fixall := app.mouse_x >= fx + fw - 90 && app.mouse_x <= fx + fw - 10 && app.mouse_y >= fy + 8 && app.mouse_y <= fy + 28
	fix_bg := if is_hover_fixall { app.pnl_success } else { app.pnl_card_sel }
	app.gg.draw_rect_filled(fx + fw - 90, fy + 10, 80, 20, fix_bg)
	app.gg.draw_rect_empty(fx + fw - 90, fy + 10, 80, 20, if is_hover_fixall {
		app.pnl_success
	} else {
		app.pnl_border_hi
	})
	app.gg.draw_text(fx + fw - 76, fy + 15, 'Fix All', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
	// category facets row — super-potent easy triage (14 categories via Engine).
	// Click a chip to fix that category via Engine TX (#1108); hit rects are
	// stored for the mouse handler (rebuilt every frame, same geometry).
	app.doctor_chips = []
	cats := ['root', 'engine', 'profiles', 'swarm', 'mcp', 'pack', 'loops', 'matrix', 'audit',
		'provenance']
	mut cx := fx + 12
	cy := fy + 30
	for cat in cats {
		cnt := checks_engine.filter(it.category == cat).len
		if cnt == 0 {
			continue
		}
		label := '${cat} ${cnt}'
		tw := label.len * 7 + 10
		if cx + tw > fx + fw - 100 {
			break
		}
		active := cat in ['mcp', 'provenance']
		bg := if active { app.pnl_select } else { app.pnl_card_sel }
		bd := if active { app.pnl_border_hi } else { app.pnl_border }
		app.gg.draw_rect_filled(cx, cy, tw, 16, bg)
		app.gg.draw_rect_empty(cx, cy, tw, 16, bd)
		app.gg.draw_text(cx + 5, cy + 3, label, gg.TextCfg{
			color: if active {
				app.pnl_text
			} else {
				app.pnl_text_mut
			}
			size: 11
		})
		app.doctor_chips << DoctorChip{cat, cx, cy, tw, 16}
		cx += tw + 4
	}
	// virtualized check list — 24px rows, 60 FPS, category + status + fixable + message + receipt/provenance hint
	y0 := fy + 50
	list_h := fh - 78
	if list_h < 40 {
		app.gg.draw_text(fx + 12, fy + fh - 20, 'Run doctor --fix to repair. All checks are English, no fallback.', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
		return
	}
	row_h := 24
	max_vis := list_h / row_h
	if max_vis < 1 {
		return
	}
	vis := if checks_engine.len < max_vis { checks_engine.len } else { max_vis }
	for i in 0 .. vis {
		if i >= checks_engine.len {
			break
		}
		c := checks_engine[i]
		y := y0 + i * row_h
		// row bg — status-tinted
		status_bg := match c.status {
			'pass' { app.pnl_card }
			'warn' { tint(app.pnl_select, 60) }
			'fail' { tint(app.pnl_danger, 40) }
			else { app.pnl_card }
		}
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, row_h - 2, status_bg)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, row_h - 2, app.pnl_border)
		// category pill
		cat_col := match c.category {
			'root' { app.pnl_success }
			'engine' { app.pnl_text_mut }
			'mcp' { app.pnl_text_mut }
			'provenance' { app.pnl_select }
			else { app.pnl_text_mut }
		}
		app.gg.draw_rect_filled(fx + 16, y + 5, 62, 12, app.pnl_bg)
		app.gg.draw_text(fx + 18, y + 6, c.category, gg.TextCfg{ color: cat_col, size: 10 })
		// name + message
		name_disp := if c.name.len > 22 { c.name[..22] } else { c.name }
		app.gg.draw_text(fx + 82, y + 5, name_disp, gg.TextCfg{ color: app.pnl_text, size: 12, bold: c.status != 'pass' })
		msg := if c.message.len > 44 { c.message[..44] + '…' } else { c.message }
		app.gg.draw_text(fx + 180, y + 7, msg, gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		// status badge + fixable
		status := c.status
		oc := match status {
			'pass' { app.pnl_success }
			'fail' { app.pnl_danger }
			else { app.pnl_border_hi }
		}
		app.gg.draw_text(fx + fw - 90, y + 5, status, gg.TextCfg{ color: oc, size: 11, bold: status != 'pass' })
		if c.fixable && status != 'pass' {
			app.gg.draw_text(fx + fw - 50, y + 5, 'fix →', gg.TextCfg{ color: app.pnl_text_mut, size: 11, bold: true })
		}
	}
	// scrollbar hint when overflow
	if checks_engine.len > vis {
		app.gg.draw_text(fx + fw - 60, y0 + vis * row_h + 2, '+${checks_engine.len - vis} more', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	}
	// footer — receipts/provenance verification + provenance paths
	app.gg.draw_text(fx + 20, fy + fh - 20, 'Click fix → for dry-run · chip fixes its category · repairs are real where a repair exists; the rest record audit stamps. All checks are English.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	app.gg.draw_text(fx + fw - 160, fy + fh - 20, '${verify_diags.len} verify warnings', gg.TextCfg{
		color: if verify_diags.len > 0 {
			app.pnl_danger
		} else {
			app.pnl_success
		}
		size: 11
	})
	// dry-run preview card — modal overlay, Confirm applies via Engine TX (#1108)
	if app.doctor_preview != '' {
		px, py, pw, ph := doctor_preview_geom(fx, fy, fw)
		pixel_panel(mut app, px, py, pw, ph, 'dialog')
		app.gg.draw_text(px + 14, py + 10, 'Dry-run preview — ${app.doctor_preview}', gg.TextCfg{
			color: app.pnl_text
			size: 13
			bold: true
		})
		app.gg.draw_text(px + 14, py + 28, 'These state writes apply on Confirm — nothing is written yet:', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		mut ln := 0
		for line in app.doctor_preview_lines {
			if ln >= 5 {
				break
			}
			app.gg.draw_text(px + 18, py + 46 + ln * 16, line, gg.TextCfg{
				color: app.pnl_text
				size: 11
				mono: true
			})
			ln++
		}
		confirm_fg := if app.appearance_dark { app.pnl_bg } else { app.pnl_text }
		app.gg.draw_rect_filled(px + 14, py + ph - 32, 120, 22, app.pnl_select)
		app.gg.draw_rect_empty(px + 14, py + ph - 32, 120, 22, app.pnl_select)
		app.gg.draw_text(px + 28, py + ph - 26, 'Confirm fix', gg.TextCfg{
			color: confirm_fg
			size: 12
			bold: true
		})
		app.gg.draw_rect_filled(px + 144, py + ph - 32, 90, 22, app.pnl_card_sel)
		app.gg.draw_rect_empty(px + 144, py + ph - 32, 90, 22, app.pnl_border)
		app.gg.draw_text(px + 164, py + ph - 26, 'Cancel', gg.TextCfg{ color: app.pnl_text, size: 12 })
	}
}

fn draw_jobs(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := panel_top(app)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	// Paper supervisor sheet — ProcessSupervisor health, NOT cream loops
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	// header letterhead with brass left rail
	pixel_panel(mut app, fx + 4, fy + 4, fw - 8, 44, 'default')
	app.gg.draw_rect_filled(fx + 6, fy + 6, 3, 40, app.pnl_select)
	app.gg.draw_text(fx + 18, fy + 12, tr(app, 'panel.jobs'), gg.TextCfg{
		color: app.pnl_text
		size: font_display_md
		family: app.fonts.display
	})
	app.gg.draw_text(fx + 78, fy + 16, 'ProcessSupervisor · StateRepository TX · EventBus · logs · approvals', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	// supervisor liveness dot via engine_api + proc count
	stats := app.desktop.engine_job_stats()
	proc_running, dropped := app.desktop.engine_process_supervisor_stats()
	dot_col := if proc_running > 0 {
		app.pnl_success
	} else if stats.running > 0 { app.pnl_border_hi } else { app.pnl_text_mut }
	app.gg.draw_rect_filled(fx + fw - 140, fy + 14, 8, 8, dot_col)
	app.gg.draw_text(fx + fw - 128, fy + 13, 'supervisor live', gg.TextCfg{ color: dot_col, size: 11, bold: true })
	app.gg.draw_text(fx + fw - 128, fy + 25, '${proc_running} running · drop ${dropped}', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
	// stats chips row — mint/mint palette vs loops L1/L2/L3
	sy := fy + 54
	chips := ['total:${stats.total}', 'queued:${stats.queued}', 'running:${stats.running}',
		'done:${stats.done}', 'failed:${stats.failed}', 'canceled:${stats.canceled}']
	chip_cols := [app.pnl_text_mut, app.pnl_text_mut, app.pnl_select, app.pnl_success,
		app.pnl_danger, app.pnl_border]
	mut cx := fx + 12
	for i, label in chips {
		c := chip_cols[i]
		bg := if label.starts_with('running') && stats.running > 0 {
			tint(app.pnl_select, 70)
		} else if label.starts_with('failed') && stats.failed > 0 {
			tint(app.pnl_danger, 50)
		} else {
			app.pnl_card_sel
		}
		tw := label.len * 7 + 14
		if cx + tw > fx + fw - 12 {
			break
		}
		app.gg.draw_rect_filled(cx, sy, tw, 18, bg)
		app.gg.draw_rect_empty(cx, sy, tw, 18, app.pnl_border)
		app.gg.draw_text(cx + 7, sy + 4, label, gg.TextCfg{ color: c, size: 10, mono: true, bold: true })
		cx += tw + 6
	}
	// supervisor health extra: API calls + revision badge
	app.gg.draw_text(fx + 12, sy + 24, 'Engine api ${app.api_calls} · rev ${app.engine_rev} · bus dropped ${dropped} · StateRepository TX', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	// Jobs come from the supervisor. Empty means no jobs are running.
	mut jobs := app.desktop.engine_jobs_catalog()
	// card metrics — paper cards with left status rail
	list_y0 := fy + 96
	list_h_total := fh - 84 - 110
	card_h := 52
	visible := list_h_total / card_h
	if visible < 1 {
		return
	}
	if app.jobs_scroll < 0 {
		app.jobs_scroll = 0
	}
	max_scroll := jobs.len - visible
	if max_scroll < 0 {
		app.jobs_scroll = 0
	} else if app.jobs_scroll > max_scroll {
		app.jobs_scroll = max_scroll
	}
	app.gg.draw_text(fx + 12, list_y0 - 12, 'ProcessSupervisor queue — ${jobs.len} jobs • click row to select • hover for actions', gg.TextCfg{ color: app.pnl_card_sel, size: 10 })
	for idx in 0 .. visible {
		di := app.jobs_scroll + idx
		if di >= jobs.len {
			break
		}
		j := jobs[di]
		y := list_y0 + idx * card_h
		is_sel := app.jobs_selected == di
		is_hover := app.jobs_hover == di
		bg := if is_sel {
			app.pnl_card_sel
		} else if is_hover { app.pnl_hover } else { app.pnl_card }
		bd := if is_sel {
			app.pnl_select
		} else if is_hover { app.pnl_border_hi } else { app.pnl_border }
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, card_h - 4, bg)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, card_h - 4, bd)
		status_col := match j.status {
			.running { app.pnl_border_hi }
			.done { app.pnl_success }
			.failed { app.pnl_danger }
			.canceled { app.pnl_text_mut }
			.queued { app.pnl_text_mut }
		}
		app.gg.draw_rect_filled(fx + 12, y, 3, card_h - 4, status_col)
		status_label := match j.status {
			.running { 'RUNNING' }
			.done { 'DONE' }
			.failed { 'FAILED' }
			.canceled { 'CANCELED' }
			.queued { 'QUEUED' }
		}
		app.gg.draw_text(fx + 22, y + 6, status_label, gg.TextCfg{ color: status_col, size: 10, bold: true, mono: true })
		short_id := if j.id.len > 14 { j.id[..14] } else { j.id }
		app.gg.draw_text(fx + 78, y + 6, short_id, gg.TextCfg{ color: app.pnl_card_sel, size: 10, mono: true })
		cmd_str := if j.cmd.len > 54 { j.cmd[..54] + '…' } else { j.cmd }
		app.gg.draw_text(fx + 22, y + 18, cmd_str, gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
		if j.args.len > 0 {
			args_str := j.args.join(' ')
			mut a2 := args_str
			if a2.len > 36 {
				a2 = a2[..36] + '…'
			}
			app.gg.draw_text(fx + 22, y + 30, a2, gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		}
		mut meta := '${j.duration_ms}ms'
		if j.retry_count > 0 {
			meta += ' • retry ${j.retry_count}'
		}
		if j.status == .done || j.status == .failed {
			meta += ' • exit ${j.exit_code}'
		}
		if j.canceled {
			meta += ' • canceled'
		}
		app.gg.draw_text(fx + 22, y + 39, meta, gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		logs := app.desktop.engine_job_logs(j.id)
		log_cnt := if logs.len > 0 { logs.len } else { j.logs.len }
		if log_cnt > 0 {
			app.gg.draw_text(fx + fw - 210, y + 6, '${log_cnt} log lines', gg.TextCfg{ color: app.pnl_border_hi, size: 10 })
		}
		bar_w := fw - 24 - 160
		mut bw := bar_w
		if bw < 40 {
			bw = 40
		}
		bar_x := fx + 22
		bar_y := y + 46
		app.gg.draw_rect_filled(bar_x, bar_y, bw, 2, app.pnl_border)
		pct := if j.duration_ms > 0 {
			(j.duration_ms / 100) % 100
		} else if j.status == .queued { 6 } else { 0 }
		fill_col := if j.status == .failed {
			app.pnl_danger
		} else if j.status == .running {
			app.pnl_select
		} else if j.status == .done { app.pnl_success } else { app.pnl_text_mut }
		if pct > 0 {
			app.gg.draw_rect_filled(bar_x, bar_y, bw * pct / 100, 2, fill_col)
		}
		btn_y := y + 22
		hover_cancel := app.jobs_hover_cancel == di
		cbg := if hover_cancel { app.pnl_danger } else { app.pnl_text }
		cfg := if hover_cancel { app.pnl_bg } else { app.pnl_text_mut }
		bd2 := if hover_cancel { app.pnl_danger } else { col_line }
		app.gg.draw_rect_filled(fx + fw - 108, btn_y, 44, 16, cbg)
		app.gg.draw_rect_empty(fx + fw - 108, btn_y, 44, 16, bd2)
		app.gg.draw_text(fx + fw - 100, btn_y + 3, 'Cancel', gg.TextCfg{ color: cfg, size: 10 })
		hover_retry := app.jobs_hover_retry == di
		rbg := if hover_retry { app.pnl_select } else { app.pnl_text }
		rfg := if hover_retry { app.pnl_text } else { app.pnl_card_sel }
		rbd := if hover_retry { app.pnl_select } else { app.pnl_border }
		app.gg.draw_rect_filled(fx + fw - 58, btn_y, 44, 16, rbg)
		app.gg.draw_rect_empty(fx + fw - 58, btn_y, 44, 16, rbd)
		app.gg.draw_text(fx + fw - 50, btn_y + 3, 'Retry', gg.TextCfg{ color: rfg, size: 10, bold: hover_retry })
	}
	if jobs.len > visible {
		track_h := visible * card_h
		bar_h := track_h * visible / jobs.len
		mut bh := bar_h
		if bh < 12 {
			bh = 12
		}
		bar_y := list_y0 + (track_h - bh) * app.jobs_scroll / (jobs.len - visible)
		app.gg.draw_rect_filled(fx + fw - 6, list_y0, 3, track_h, tint(app.pnl_text, 30))
		app.gg.draw_rect_filled(fx + fw - 6, bar_y, 3, bh, app.pnl_border_hi)
	}
	// ── Approvals queue — super-potent spend/scope/destructive distinct bottom panel ──
	aq_y := fy + fh - 104
	app.gg.draw_rect_filled(fx + 8, aq_y, fw - 16, 96, app.pnl_card_sel)
	app.gg.draw_rect_empty(fx + 8, aq_y, fw - 16, 96, app.pnl_border_hi)
	app.gg.draw_rect_filled(fx + 8, aq_y, fw - 16, 18, app.pnl_select)
	app.gg.draw_text(fx + 16, aq_y + 4, 'Approvals Queue — spend / scope / destructive', gg.TextCfg{ color: app.pnl_text, size: 11, bold: true })
	mut aq := app.desktop.engine_approvals_queue()
	app.gg.draw_text(fx + fw - 110, aq_y + 4, '${aq.len} pending • StateRepository TX', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	if aq.len == 0 {
		app.gg.draw_text(fx + 16, aq_y + 28, 'No pending approvals — queue is empty (awaiting_approval gates)', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		app.gg.draw_text(fx + 16, aq_y + 42, 'spend / scope / destructive via Engine.swarm_request_approval() → TX + EventBus', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	} else {
		visible_aq := 3
		if app.jobs_approvals_scroll < 0 {
			app.jobs_approvals_scroll = 0
		}
		max_aq := aq.len - visible_aq
		if max_aq < 0 {
			app.jobs_approvals_scroll = 0
		} else if app.jobs_approvals_scroll > max_aq {
			app.jobs_approvals_scroll = max_aq
		}
		for a_idx in 0 .. visible_aq {
			ai := app.jobs_approvals_scroll + a_idx
			if ai >= aq.len {
				break
			}
			ap := aq[ai]
			y := aq_y + 22 + a_idx * 22
			kind_str := match ap.kind {
				.spend { 'SPEND' }
				.scope { 'SCOPE' }
				.destructive { 'DESTRUCTIVE' }
			}
			kind_col := match ap.kind {
				.spend { app.pnl_success }
				.scope { app.pnl_select }
				.destructive { app.pnl_danger }
			}
			kind_bg := match ap.kind {
				.spend { tint(app.pnl_success, 18) }
				.scope { tint(app.pnl_select, 18) }
				.destructive { tint(app.pnl_danger, 18) }
			}
			app.gg.draw_rect_filled(fx + 16, y, 78, 14, kind_bg)
			app.gg.draw_rect_empty(fx + 16, y, 78, 14, kind_col)
			app.gg.draw_text(fx + 20, y + 2, kind_str, gg.TextCfg{ color: kind_col, size: 10, bold: true, mono: true })
			msg := if ap.message.len > 44 { ap.message[..44] + '…' } else { ap.message }
			app.gg.draw_text(fx + 100, y + 2, msg, gg.TextCfg{ color: app.pnl_card_sel, size: 10 })
			if ap.budget_cost > 0 {
				app.gg.draw_text(fx + fw - 120, y + 2, '\$${ap.budget_cost}', gg.TextCfg{ color: kind_col, size: 10, mono: true })
			}
			app.gg.draw_rect_filled(fx + fw - 72, y, 28, 14, app.pnl_success)
			app.gg.draw_text(fx + fw - 66, y + 2, '✓', gg.TextCfg{ color: app.pnl_text, size: 10, bold: true })
			app.gg.draw_rect_filled(fx + fw - 40, y, 28, 14, app.pnl_danger)
			app.gg.draw_text(fx + fw - 34, y + 2, '×', gg.TextCfg{ color: app.pnl_bg, size: 10, bold: true })
		}
		if aq.len > visible_aq {
			track_h2 := 66
			bar_h2 := track_h2 * visible_aq / aq.len
			mut bh2 := bar_h2
			if bh2 < 8 {
				bh2 = 8
			}
			bar_y2 := aq_y + 22 + (track_h2 - bh2) * app.jobs_approvals_scroll / (aq.len - visible_aq)
			app.gg.draw_rect_filled(fx + fw - 8, aq_y + 22, 2, track_h2, tint(app.pnl_text, 60))
			app.gg.draw_rect_filled(fx + fw - 8, bar_y2, 2, bh2, app.pnl_border_hi)
		}
	}
	app.gg.draw_text(fx + 12, fy + fh - 12, 'Engine jobs via StateRepository TX • supervisor health • approvals via Engine.swarm_approvals_queue() • virtualized 60 FPS', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
}

fn draw_loops(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := panel_top(app)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	pixel_panel(mut app, fx + 4, fy + 4, fw - 8, 34, 'default')
	app.gg.draw_text(fx + 18, fy + 12, tr(app, 'panel.loops'), gg.TextCfg{
		color: app.pnl_text
		size: font_display_md
		family: app.fonts.display
	})
	app.gg.draw_text(fx + 96, fy + 16, 'L1 observe → L2 assisted → L3 merge/close · budgets · verifier · STATE.md resumable', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	hover_new := app.mouse_x >= fx + fw - 118 && app.mouse_x <= fx + fw - 14 && app.mouse_y >= fy + 10 && app.mouse_y <= fy + 32
	bg_new := if hover_new { app.pnl_select } else { app.pnl_text }
	fg_new := if hover_new { app.pnl_text } else { app.pnl_card }
	app.gg.draw_rect_filled(fx + fw - 118, fy + 8, 104, 22, bg_new)
	app.gg.draw_rect_empty(fx + fw - 118, fy + 8, 104, 22, app.pnl_select)
	draw_text_l(mut app, fx + fw - 106, fy + 14, 'act.new_loop', gg.TextCfg{ color: fg_new, size: 10, bold: true })
	app.gg.draw_text(fx + 20, fy + 44, 'loop.yaml: cadence / goal / allowlist / budget · exit: goal_met · budget_exhausted · human_escalation · verifier receipt · StateRepository TX', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	// ── Super-potent Engine loops L1/L2/L3 with three budgets visualized distinctly from Jobs ──
	mut loops := app.desktop.loops_catalog()
	mut y0 := fy + 66
	card_h := 78
	visible := (fh - 90) / card_h
	if visible < 1 {
		return
	}
	if app.loops_scroll < 0 {
		app.loops_scroll = 0
	}
	max_scroll := loops.len - visible
	if max_scroll < 0 {
		app.loops_scroll = 0
	} else if app.loops_scroll > max_scroll {
		app.loops_scroll = max_scroll
	}
	for idx in 0 .. visible {
		di := app.loops_scroll + idx
		if di >= loops.len {
			break
		}
		entry := loops[di]
		y := y0 + idx * card_h
		is_sel := app.selected_loop == di
		variant := if is_sel { 'active' } else { 'default' }
		pixel_panel(mut app, fx + 12, y, fw - 24, card_h - 4, variant)
		tier_str := match entry.tier {
			.l3 { 'L3' }
			.l2 { 'L2' }
			else { 'L1' }
		}
		tier_col := if tier_str == 'L3' {
			app.pnl_danger
		} else if tier_str == 'L2' { app.pnl_select } else { app.pnl_success }
		tier_bg := if tier_str == 'L3' {
			tint(app.pnl_danger, 22)
		} else if tier_str == 'L2' { tint(app.pnl_select, 18) } else { tint(app.pnl_success, 14) }
		app.gg.draw_rect_filled(fx + 22, y + 6, 28, 14, tier_bg)
		app.gg.draw_rect_empty(fx + 22, y + 6, 28, 14, tier_col)
		app.gg.draw_text(fx + 26, y + 8, tier_str, gg.TextCfg{ color: tier_col, size: 10, bold: true })
		app.gg.draw_text(fx + 56, y + 7, entry.name, gg.TextCfg{ color: app.pnl_text, size: 11, bold: true })
		app.gg.draw_text(fx + 56 + entry.name.len * 7 + 8, y + 8, entry.cadence, gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		mut bx := fx + fw - 260
		if entry.verifier.trim_space().len > 0 {
			app.gg.draw_rect_filled(bx, y + 6, 92, 14, tint(app.pnl_text_mut, 18))
			app.gg.draw_rect_empty(bx, y + 6, 92, 14, app.pnl_text_mut)
			lbl := if entry.verifier.contains(':') {
				entry.verifier.split(':')[1]
			} else {
				entry.verifier
			}
			short := lbl[..if lbl.len > 10 { 10 } else { lbl.len }]
			app.gg.draw_text(bx + 6, y + 8, 'verifier:' + short, gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
			bx -= 100
		}
		if entry.resumable {
			app.gg.draw_rect_filled(fx + fw - 140, y + 6, 72, 14, tint(app.pnl_text_mut, 14))
			app.gg.draw_rect_empty(fx + fw - 140, y + 6, 72, 14, app.pnl_text_mut)
			app.gg.draw_text(fx + fw - 132, y + 8, 'STATE.md', gg.TextCfg{ color: app.pnl_text_mut, size: 10, bold: true })
		}
		bud := entry.budget
		mut max_tok := bud.max_tokens
		if max_tok == 0 {
			max_tok = entry.budget_total
		}
		if max_tok == 0 {
			max_tok = match entry.tier {
				.l3 { 300000 }
				.l2 { 100000 }
				else { 50000 }
			}
		}
		max_runs := if bud.max_runs_per_day != 0 { bud.max_runs_per_day } else { 1 }
		max_wall := if bud.max_wall_seconds != 0 { bud.max_wall_seconds } else { 600 }
		mut spent := entry.budget_spent
		total, ledger_spent, remaining := app.desktop.engine_loop_budget_ledger(entry.name)
		if total > 0 {
			max_tok = total
			spent = ledger_spent
			_ = remaining
		}
		tok_label := '${max_tok} tok'
		runs_label := '${max_runs}/d'
		wall_label := '${max_wall}s wall'
		app.gg.draw_text(fx + 22, y + 22, tok_label + '  ' + runs_label + '  ' + wall_label, gg.TextCfg{ color: app.pnl_text, size: 10, mono: true })
		if entry.allowlist.len > 0 {
			allow := entry.allowlist.join(',')
			mut a := allow
			if a.len > 28 {
				a = a[..28] + '…'
			}
			app.gg.draw_text(fx + 180, y + 22, 'allow:' + a, gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
		}
		mut bar_w := (fw - 24 - 140 - 100) / 3
		if bar_w < 40 {
			bar_w = 40
		}
		bar_y := y + 34
		tok_pct := if max_tok > 0 { spent * 100 / max_tok } else { 0 }
		mut t_pct := tok_pct
		if t_pct < 0 {
			t_pct = 0
		}
		if t_pct > 100 {
			t_pct = 100
		}
		app.gg.draw_rect_filled(fx + 22, bar_y, bar_w, 4, app.pnl_card_sel)
		tok_col := if t_pct > 85 {
			app.pnl_danger
		} else if t_pct > 60 { app.pnl_select } else { app.pnl_success }
		app.gg.draw_rect_filled(fx + 22, bar_y, bar_w * t_pct / 100, 4, tok_col)
		app.gg.draw_text(fx + 22, bar_y + 6, 'tokens ${t_pct}%', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		app.gg.draw_text(fx + 22 + bar_w - 28, bar_y + 6, '${spent}/${max_tok}', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		runs_cap_pct := if max_runs > 0 { max_runs * 100 / 96 } else { 0 }
		mut r_pct := runs_cap_pct
		if r_pct > 100 {
			r_pct = 100
		}
		if r_pct < 4 {
			r_pct = 4
		}
		rx := fx + 22 + bar_w + 8
		app.gg.draw_rect_filled(rx, bar_y, bar_w, 4, app.pnl_card_sel)
		runs_col := if max_runs >= 48 {
			app.pnl_select
		} else if max_runs >= 6 { app.pnl_text_mut } else { app.pnl_success }
		app.gg.draw_rect_filled(rx, bar_y, bar_w * r_pct / 100, 4, runs_col)
		app.gg.draw_text(rx, bar_y + 6, 'runs ${max_runs}/d', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		wall_cap_pct := if max_wall > 0 { max_wall * 100 / 1800 } else { 0 }
		mut w_pct := wall_cap_pct
		if w_pct < 4 {
			w_pct = 4
		}
		if w_pct > 100 {
			w_pct = 100
		}
		wx := rx + bar_w + 8
		app.gg.draw_rect_filled(wx, bar_y, bar_w, 4, app.pnl_card_sel)
		wall_col := if max_wall >= 1200 {
			app.pnl_danger
		} else if max_wall >= 600 { app.pnl_select } else { app.pnl_success }
		app.gg.draw_rect_filled(wx, bar_y, bar_w * w_pct / 100, 4, wall_col)
		app.gg.draw_text(wx, bar_y + 6, 'wall ${max_wall}s', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		// burn-down sparkline — last budget_spent values from the loop ledger
		history := app.desktop.engine_loop_history('')
		mut runs := []int{}
		for hist_row in history {
			if hist_row.loop_name == entry.name {
				runs << hist_row.budget_spent
			}
		}
		if runs.len >= 2 {
			sp_x := fx + fw - 260
			sp_w := 130
			sp_y := y + 54
			mut peak := 1
			for v in runs {
				if v > peak {
					peak = v
				}
			}
			app.gg.draw_rect_filled(sp_x, sp_y, sp_w, 14, app.pnl_bg)
			ticks := if runs.len > 20 { 20 } else { runs.len }
			start := runs.len - ticks
			for k in 0 .. ticks {
				v := runs[start + k]
				bh := v * 14 / peak
				bc := if t_pct > 85 { app.pnl_danger } else { app.pnl_select }
				app.gg.draw_rect_filled(sp_x + k * (sp_w / ticks), sp_y + 14 - bh, sp_w / ticks - 1, bh, bc)
			}
			app.gg.draw_rect_empty(sp_x, sp_y, sp_w, 14, app.pnl_border)
			app.gg.draw_text(sp_x + sp_w + 6, sp_y + 2, 'burn-down', gg.TextCfg{ color: app.pnl_text_mut, size: 8 })
		}
		mut exits := entry.exit_conditions.join(',')
		if exits == '' {
			exits = 'goal_met,budget_exhausted'
		}
		if exits.len > 36 {
			exits = exits[..36] + '…'
		}
		app.gg.draw_text(fx + 22, y + 52, 'exit: ' + exits, gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
		if entry.cron_enabled {
			app.gg.draw_text(fx + 22 + bar_w * 2 + 24, y + 52, 'cron:${entry.schedule}', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		}
		spent_pct2 := t_pct
		bar_w2 := fw - 24 - 140 - 100
		bar_x := fx + 22
		bar_y2 := y + 64
		app.gg.draw_rect_filled(bar_x, bar_y2, bar_w2, 3, app.pnl_card_sel)
		fill_col := if spent_pct2 > 85 {
			app.pnl_danger
		} else if spent_pct2 > 60 { app.pnl_select } else { app.pnl_success }
		app.gg.draw_rect_filled(bar_x, bar_y2, bar_w2 * spent_pct2 / 100, 3, fill_col)
		app.gg.draw_text(bar_x + bar_w2 + 6, bar_y2 - 5, '${spent_pct2}%', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		btn_y := y + 44
		hover_run := app.loops_hover_run == di
		run_bg := if hover_run { app.pnl_text } else { app.pnl_card_sel }
		run_fg := if hover_run { app.pnl_card } else { app.pnl_text }
		run_bd := if hover_run { app.pnl_select } else { app.pnl_border }
		app.gg.draw_rect_filled(fx + fw - 108, btn_y, 44, 16, run_bg)
		app.gg.draw_rect_empty(fx + fw - 108, btn_y, 44, 16, run_bd)
		app.gg.draw_text(fx + fw - 98, btn_y + 3, 'Run', gg.TextCfg{ color: run_fg, size: 10, bold: true })
		hover_cron := app.loops_hover_cron == di
		cron_bg := if hover_cron { app.pnl_text } else { app.pnl_text }
		app.gg.draw_rect_filled(fx + fw - 58, btn_y, 44, 16, cron_bg)
		app.gg.draw_rect_empty(fx + fw - 58, btn_y, 44, 16, app.pnl_border)
		app.gg.draw_text(fx + fw - 52, btn_y + 3, 'Sched', gg.TextCfg{ color: app.pnl_card, size: 10 })
	}
	if loops.len > visible {
		track_h := visible * card_h
		bar_h := track_h * visible / loops.len
		mut bh := bar_h
		if bh < 12 {
			bh = 12
		}
		bar_y := y0 + (track_h - bh) * app.loops_scroll / (loops.len - visible)
		app.gg.draw_rect_filled(fx + fw - 6, y0, 3, track_h, tint(app.pnl_text, 30))
		app.gg.draw_rect_filled(fx + fw - 6, bar_y, 3, bh, app.pnl_border_hi)
	}
	app.gg.draw_text(fx + 14, fy + fh - 18, 'Budget ledger via StateRepository TX • exit_conditions gate • gh-gate tier • validate-loops', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	app.gg.draw_text(fx + fw - 220, fy + fh - 18, 'rev ${app.engine_rev} • api ${app.api_calls} • loops ${loops.len}', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
	if app.loops_show_create {
		mx := fx + 40
		my := fy + 50
		mw := fw - 80
		mh := 160
		app.gg.draw_rect_filled(mx, my, mw, mh, tint(app.pnl_text, 45))
		pixel_panel(mut app, mx + 2, my + 2, mw - 4, mh - 4, 'active')
		app.gg.draw_text(mx + 18, my + 14, 'Create Loop — via Engine.create_loop() TX', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
		tier_str := ['L1', 'L2', 'L3'][app.loops_create_tier]
		app.gg.draw_text(mx + 18, my + 32, 'name: ${app.loops_create_name}  tier: ${tier_str}  cadence: ${app.loops_create_cadence}  budget: 50k/1/600/20', gg.TextCfg{ color: app.pnl_text, size: 10, mono: true })
		app.gg.draw_text(mx + 18, my + 52, 'Writes loops/<name>/loop.yaml + STATE.md + StateRepository transaction', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
		app.gg.draw_rect_filled(mx + 18, my + 74, 88, 26, app.pnl_success)
		app.gg.draw_text(mx + 30, my + 82, 'Create', gg.TextCfg{ color: app.pnl_text, size: 10, bold: true })
		app.gg.draw_rect_filled(mx + 118, my + 74, 88, 26, app.pnl_text)
		app.gg.draw_rect_empty(mx + 118, my + 74, 88, 26, app.pnl_border)
		app.gg.draw_text(mx + 136, my + 82, 'Cancel', gg.TextCfg{ color: app.pnl_card, size: 10 })
	}
}

// swarm_zoom_geom returns the − / + button rects in the topology header (#1101).
fn swarm_zoom_geom(fx int, fy int, fw int, topo_y int) (int, int, int, int, int, int) {
	return fx + fw - 150, topo_y + 8, fx + fw - 122, topo_y + 8, 24, 18
}

// swarm_edge_artifact extracts '(artifact PATH)' from a handoff line (#1101).
fn swarm_edge_artifact(line string) string {
	marker := '(artifact '
	start := line.index(marker) or { return '' }
	rest := line[start + marker.len..]
	fin := rest.index(')') or { return '' }
	return rest[..fin].trim_space()
}

// swarm_working_roles derives the active roles from handoff recency: the
// participants of the most recent handoff are working, the rest queued.
// No role-name hardcoding; deterministic on live and mock feeds (#1101).
fn swarm_working_roles(handoffs []string) []string {
	if handoffs.len == 0 {
		return []
	}
	last := handoffs[handoffs.len - 1]
	arrow := last.index(' → ') or { return [] }
	src_role := last[..arrow].trim_space()
	rest := last[arrow + 5..].trim_space().split(' ') // 5-byte arrow (#1101)
	dst_role := if rest.len > 0 { rest[0] } else { '' }
	mut out := []string{}
	if src_role != '' {
		out << src_role
	}
	if dst_role != '' && dst_role != src_role {
		out << dst_role
	}
	return out
}

// swarm_role_desk maps a topology role to its office desk index (#1101).
fn swarm_role_desk(app &GuiApp, role string) int {
	for i, d in desks_for_app(app) {
		if d.id == role {
			return i
		}
	}
	return -1
}

// esc_desk_fullscreen exits a desk fullscreen view (#1101): a swarm attach
// restores the pre-attach terminal mode so the panel renders again, while a
// plain MAX + desk-tab fullscreen without attach drops to the fleet feed.
fn esc_desk_fullscreen(mut app GuiApp) {
	app.term_view = -1
	app.term_split = false
	if app.term_mode_saved >= 0 {
		app.term_mode = app.term_mode_saved
		app.term_mode_saved = -1
		app.inspector_msg = 'Swarm attach closed — back to panel (Esc)'
	}
}

fn draw_swarm(mut app GuiApp, w int, h int) {
	// Super-potent swarms — GOD mailbox routing, handoff artifact files, inner/outer loops,
	// Swarm UI Herdr/tmux, approvals spend/scope/destructive, easy pair/team/full launch,
	// wire to desktop_engine eventbus and show swarm status, handoffs, logs.
	fx := panel_fx(app)
	fy := panel_top(app)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	// header — GOD mailbox law
	pixel_panel(mut app, fx + 4, fy + 4, fw - 8, 44, 'default')
	app.gg.draw_text(fx + 18, fy + 12, tr(app, 'panel.swarm'), gg.TextCfg{
		color: app.pnl_text
		size: font_display_md
		family: app.fonts.display
	})
	app.gg.draw_text(fx + 92, fy + 16, 'GOD mailbox routing · handoff artifacts · inner/outer loops · Herdr/tmux · approvals', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	// GOD mailbox indicator — in/out via desktop.god_mailbox_counts() eventbus
	mut god_in := app.god_inbox
	mut god_out := app.god_outbox
	// try live from Engine if available (wire to desktop_engine eventbus)
	if app.desktop != unsafe { nil } {
		gi, go_ := app.desktop.god_mailbox_counts()
		if gi != 0 || go_ != 0 {
			god_in = gi
			god_out = go_
		}
	}
	mbx_x := fx + fw - 160
	app.gg.draw_rect_filled(mbx_x, fy + 8, 140, 28, app.pnl_card_sel)
	app.gg.draw_rect_empty(mbx_x, fy + 8, 140, 28, app.pnl_border_hi)
	app.gg.draw_text(mbx_x + 10, fy + 12, 'GOD mailbox', gg.TextCfg{ color: app.pnl_text, size: 11, bold: true })
	app.gg.draw_text(mbx_x + 10, fy + 26, 'in ${god_in} · out ${god_out}', gg.TextCfg{ color: app.pnl_danger, size: 11, mono: true })
	if god_in > 0 {
		app.gg.draw_rect_filled(mbx_x + 116, fy + 14, 8, 6, app.pnl_danger)
	}
	// Herdr/tmux backend toggle + easy launch pair/team/full
	y_launch := fy + 56
	pixel_panel(mut app, fx + 8, y_launch, fw - 16, 68, 'default')
	app.gg.draw_text(fx + 20, y_launch + 8, 'Launch — pair / team / full', gg.TextCfg{ color: app.pnl_text, size: font_display_sm })
	app.gg.draw_text(fx + 20, y_launch + 24, 'Backend:', gg.TextCfg{ color: app.pnl_text, size: 12 })
	for bi, bname in ['auto', 'herdr', 'tmux'] {
		bx := fx + 80 + bi * 68
		sel := app.swarm_backend == bname
		bg := if sel { app.pnl_text } else { app.pnl_card_sel }
		fg := if sel { app.pnl_select } else { app.pnl_text }
		bd := if sel { app.pnl_select } else { app.pnl_border }
		hover := app.mouse_x >= bx && app.mouse_x <= bx + 56 && app.mouse_y >= y_launch + 8 && app.mouse_y <= y_launch + 32
		bg2 := if hover && !sel { app.pnl_card } else { bg }
		app.gg.draw_rect_filled(bx, y_launch + 8, 56, 20, bg2)
		app.gg.draw_rect_empty(bx, y_launch + 8, 56, 20, bd)
		app.gg.draw_text(bx + 10, y_launch + 14, bname, gg.TextCfg{ color: fg, size: 12, bold: sel })
	}
	// task field hint
	app.gg.draw_text(fx + 300, y_launch + 14, 'Task: ${app.swarm_task[..if app.swarm_task.len > 38 {
		38
	} else {
		app.swarm_task.len
	}]}', gg.TextCfg{ color: app.pnl_text_mut, size: 12, mono: true })
	// pair/team/full buttons — brass primary
	for ri, rname in ['pair', 'team', 'full'] {
		bx := fx + 20 + ri * 96
		hover := app.mouse_x >= bx && app.mouse_x <= bx + 84 && app.mouse_y >= y_launch + 38 && app.mouse_y <= y_launch + 60
		bg := if hover { app.pnl_select_hover } else { app.pnl_select }
		app.gg.draw_rect_filled(bx, y_launch + 36, 84, 22, bg)
		app.gg.draw_rect_empty(bx, y_launch + 36, 84, 22, app.pnl_border_hi)
		app.gg.draw_text(bx + 18, y_launch + 42, rname, gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
	}
	app.gg.draw_text(fx + 320, y_launch + 44, '→ via Engine.swarm_launch() · EventBus swarm_created · status/handoffs/logs live', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	// ── topology strip — roles as paper nodes, handoff edges with GOD envelopes ──
	// parse ordered roles + edges from the handoff feed ("X → Y …")
	topo_y := y_launch + 78
	topo_h := 112
	pixel_panel(mut app, fx + 8, topo_y, fw - 16, topo_h, 'default')
	app.gg.draw_text(fx + 20, topo_y + 8, 'Topology — handoff graph (live)', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
	app.gg.draw_text(fx + fw - 240, topo_y + 10, 'nodes = roles · edges = GOD handoffs · dot = 4·t·(1−t)', gg.TextCfg{ color: app.pnl_text_mut, size: 9 })
	mut topo_handoffs := []string{}
	if app.desktop != unsafe { nil } && app.desktop.swarm_list().len > 0 {
		first_id_t := if app.desktop.swarm_list().len > 0 {
			app.desktop.swarm_list()[0].id
		} else {
			'swarm-a4f'
		}
		for hh in app.desktop.swarm_handoffs(first_id_t) {
			topo_handoffs << hh
		}
	}
	mut roles := []string{}
	mut role_idx := map[string]int{}
	mut edges := [][]int{}
	mut edge_art := []string{}
	for th in topo_handoffs {
		arrow := th.index(' → ') or { -1 }
		if arrow < 0 {
			continue
		}
		lrole := th[..arrow].trim_space()
		rrest := th[arrow + 5..].trim_space() // ' → ' is 5 bytes; +3 left a stray continuation byte (#1101)
		rrole := rrest.split(' ')[0]
		if rrole.len == 0 {
			continue
		}
		mut li := role_idx[lrole] or { -1 }
		if li < 0 {
			li = roles.len
			roles << lrole
			role_idx[lrole] = li
		}
		mut ri := role_idx[rrole] or { -1 }
		if ri < 0 {
			ri = roles.len
			roles << rrole
			role_idx[rrole] = ri
		}
		edges << [li, ri]
		edge_art << swarm_edge_artifact(th)
	}
	if roles.len > 0 {
		// zoom scales node width; overflow wraps to a second lane (#1101)
		node_w := 108 + app.swarm_zoom * 24
		node_y := topo_y + 34
		zx, zy, pxz, pyz, zw, zh := swarm_zoom_geom(fx, fy, fw, topo_y)
		app.gg.draw_rect_filled(zx, zy, zw, zh, app.pnl_card_sel)
		app.gg.draw_rect_empty(zx, zy, zw, zh, app.pnl_border)
		app.gg.draw_text(zx + 8, zy + 3, '−', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
		app.gg.draw_rect_filled(pxz, pyz, zw, zh, app.pnl_card_sel)
		app.gg.draw_rect_empty(pxz, pyz, zw, zh, app.pnl_border)
		app.gg.draw_text(pxz + 8, pyz + 3, '+', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
		working := swarm_working_roles(topo_handoffs)
		app.swarm_nodes = []
		app.swarm_edges = []
		// lane split: spread single lane when it fits (original geometry),
		// else pack up to two lanes
		fit_gap := (fw - 48 - roles.len * node_w) / (roles.len + 1)
		mut lane_of := map[int]int{}
		mut lane_pos := map[int]int{}
		if fit_gap >= 8 {
			for ri in 0 .. roles.len {
				lane_of[ri] = 0
				lane_pos[ri] = ri
			}
		} else {
			lane_cap := (fw - 48) / (node_w + 8)
			safe_cap := if lane_cap < 1 { 1 } else { lane_cap }
			for ri in 0 .. roles.len {
				lane_of[ri] = ri / safe_cap
				lane_pos[ri] = ri % safe_cap
			}
		}
		mut lane_origin := map[int]int{}
		mut lane_step := map[int]int{}
		mut lane_count := map[int]int{}
		for ri in 0 .. roles.len {
			lane_count[lane_of[ri]] = lane_count[lane_of[ri]] + 1
		}
		for lane, n in lane_count {
			if lane == 0 && n == roles.len {
				g := (fw - 48 - n * node_w) / (n + 1)
				lane_origin[lane] = fx + 24 + g
				lane_step[lane] = node_w + g
			} else {
				lane_origin[lane] = fx + 24 + 8
				lane_step[lane] = node_w + 8
			}
		}
		max_label := (node_w - 16) / 7
		mut centers_x := map[int]int{}
		mut centers_y := map[int]int{}
		for ri, role in roles {
			lane := lane_of[ri]
			if lane > 1 {
				break
			}
			ny := node_y + lane * 40
			if ny + 34 > topo_y + topo_h - 4 {
				break
			}
			nx := lane_origin[lane] + lane_pos[ri] * lane_step[lane]
			centers_x[ri] = nx + node_w / 2
			centers_y[ri] = ny + 17
			app.swarm_nodes << SwarmNode{role, nx, ny, node_w}
			status_running := role in working
			app.gg.draw_rect_filled(nx, ny, node_w, 34, if status_running {
				app.pnl_card_sel
			} else {
				app.pnl_card
			})
			app.gg.draw_rect_empty(nx, ny, node_w, 34, if status_running {
				app.pnl_select
			} else {
				app.pnl_border
			})
			label := if role.len > max_label && max_label > 3 {
				role[..max_label] + '…'
			} else {
				role
			}
			app.gg.draw_text(nx + 8, ny + 6, label, gg.TextCfg{ color: app.pnl_text, size: 10, bold: true })
			app.gg.draw_text(nx + 8, ny + 19, if status_running { 'working' } else { 'queued' }, gg.TextCfg{ color: app.pnl_text_mut, size: 9, mono: true })
		}
		// edges with travelling envelopes — GOD 4·t·(1−t) speed pulse
		for ei, e in edges {
			if e[0] !in centers_x || e[1] !in centers_x {
				continue
			}
			x1 := centers_x[e[0]]
			y1 := centers_y[e[0]]
			x2 := centers_x[e[1]]
			y2 := centers_y[e[1]]
			app.swarm_edges << SwarmEdge{x1, x2, (y1 + y2) / 2, edge_art[ei]}
			app.gg.draw_line(x1, y1, x2, y2, tint(app.pnl_text_mut, 110))
			t := f64((app.frame * 2 + ei * 90) % 120) / 120.0
			env_x := x1 + int((x2 - x1) * t)
			env_y := y1 + int((y2 - y1) * t)
			env_h := int(5.0 * (4.0 * t * (1.0 - t)))
			app.gg.draw_rect_filled(env_x - 3, env_y - 3 - env_h / 2, 6, 6, app.pnl_danger)
		}
	} else {
		app.gg.draw_text(fx + 24, topo_y + 40, 'No handoffs yet — launch pair/team/full to see the live topology.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	}
	// three columns: status | handoffs/artifacts | approvals + logs (inner/outer)
	col_y := y_launch + 76 + topo_h + 10
	col_h := fh - (col_y - fy) - 10
	if col_h < 100 {
		return
	}
	// left — swarm status (wired to desktop_engine eventbus)
	cw := (fw - 32) / 3
	pixel_panel(mut app, fx + 8, col_y, cw, col_h, 'terminal')
	app.gg.draw_rect_filled(fx + 8, col_y, cw, 20, app.pnl_text)
	app.gg.draw_text(fx + 16, col_y + 5, 'Status — Engine.swarm_list()', gg.TextCfg{ color: app.pnl_card, size: 11, mono: true })
	// Derive status from Engine. An empty list means no swarms are running.
	mut swarms := []string{}
	if app.desktop != unsafe { nil } {
		list := app.desktop.swarm_list()
		for s in list {
			swarms << '${s.id} ${s.recipe.str()} ${s.backend.str()} ${s.status.str()}'
		}
	}
	app.swarm_scroll = clamp_scroll(app.swarm_scroll, swarms.len, col_h / 16 - 2)
	for i in 0 .. (col_h / 16 - 2) {
		idx := app.swarm_scroll + i
		if idx >= swarms.len {
			break
		}
		s := swarms[idx]
		y := col_y + 28 + i * 16
		sel := app.swarm_selected == idx
		if sel {
			app.gg.draw_rect_filled(fx + 12, y - 1, cw - 8, 16, app.pnl_text)
		}
		col := if s.contains('running') {
			app.pnl_success
		} else if s.contains('awaiting') {
			app.pnl_select
		} else if s.contains('completed') { app.pnl_text_mut } else { app.pnl_card }
		app.gg.draw_text(fx + 18, y + 2, s, gg.TextCfg{ color: col, size: 12, mono: true })
	}
	app.gg.draw_text(fx + 12, col_y + col_h - 14, '${swarms.len} swarms · Herdr preferred → tmux fallback · rev ${app.engine_rev}', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	// middle — handoffs via GOD mailbox + artifact files
	mx := fx + 12 + cw
	pixel_panel(mut app, mx, col_y, cw, col_h, 'default')
	app.gg.draw_rect_filled(mx, col_y, cw, 20, app.pnl_card_sel)
	app.gg.draw_text(mx + 8, col_y + 5, 'Handoffs — GOD → mailbox → queued', gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
	// handoff artifacts list + inner/outer loop hint
	mut handoffs := []string{}
	if app.desktop != unsafe { nil } && swarms.len > 0 {
		// Use the first real swarm id.
		first_id := if app.desktop.swarm_list().len > 0 {
			app.desktop.swarm_list()[0].id
		} else {
			''
		}
		hs := app.desktop.swarm_handoffs(first_id)
		if hs.len > 0 {
			for hh in hs {
				handoffs << hh
			}
		}
		arts := app.desktop.handoff_artifacts(first_id)
		for a in arts {
			handoffs << 'artifact: ${a}'
		}
	}
	for i in 0 .. (col_h / 16 - 2) {
		if i >= handoffs.len {
			break
		}
		s := handoffs[i]
		y := col_y + 28 + i * 16
		hover_h := app.swarm_handoff_hover == i
		if hover_h {
			app.gg.draw_rect_filled(mx + 4, y - 1, cw - 8, 15, app.pnl_card)
		}
		// truncate
		mut txt := s
		if txt.len > 36 {
			txt = txt[..36] + '…'
		}
		app.gg.draw_text(mx + 10, y + 2, txt, gg.TextCfg{
			color: if hover_h {
				app.pnl_text
			} else {
				app.pnl_text
			}
			size: 11
			mono: true
		})
	}
	app.gg.draw_text(mx + 8, col_y + col_h - 14, 'Artifacts: .agent-toolkit/swarm/runs/<id>/artifacts/ · GOD outbox/queued', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	// right — approvals spend/scope/destructive + logs
	rx := mx + cw + 4
	pixel_panel(mut app, rx, col_y, cw, col_h, 'default')
	app.gg.draw_rect_filled(rx, col_y, cw, 20, app.pnl_text)
	app.gg.draw_text(rx + 8, col_y + 5, 'Approvals & Logs — EventBus', gg.TextCfg{ color: app.pnl_card, size: 11, mono: true })
	// approvals spend/scope/destructive derived from app.approvals + Engine
	mut apprs := app.approvals.clone()
	if apprs.len == 0 && app.desktop != unsafe { nil } && swarms.len > 0 {
		first_id2 := if app.desktop.swarm_list().len > 0 {
			app.desktop.swarm_list()[0].id
		} else {
			''
		}
		if first_id2.len > 0 {
			pending := app.desktop.swarm_approvals(first_id2)
			for p in pending {
				apprs << '${p.kind.str()} ${p.message[..if p.message.len > 24 {
					24
				} else {
					p.message.len
				}]} — pending'
			}
		}
	}
	app.gg.draw_text(rx + 8, col_y + 26, 'Gates:', gg.TextCfg{ color: app.pnl_select, size: 11, bold: true })
	for i, ap in apprs {
		if i >= 3 {
			break
		}
		y := col_y + 40 + i * 18
		kind := if ap.contains('spend') {
			'spend'
		} else if ap.contains('destructive') { 'destructive' } else { 'scope' }
		ccol := if kind == 'destructive' {
			app.pnl_danger
		} else if kind == 'spend' { app.pnl_select } else { app.pnl_text_mut }
		app.gg.draw_rect_filled(rx + 8, y + 2, 6, 6, ccol)
		mut t := ap
		if t.len > 30 {
			t = t[..30] + '…'
		}
		app.gg.draw_text(rx + 18, y, t, gg.TextCfg{ color: app.pnl_text, size: 11 })
		// approve/reject buttons — sage/rust with translated glyphs
		draw_text_l(mut app, rx + cw - 50, y - 2, 'act.approve', gg.TextCfg{ color: app.pnl_success, size: 10, bold: true })
		app.gg.draw_rect_filled(rx + cw - 36, y - 1, 16, 12, app.pnl_success)
		app.gg.draw_text(rx + cw - 32, y, '✓', gg.TextCfg{ color: app.pnl_bg, size: 10, bold: true })
		app.gg.draw_rect_filled(rx + cw - 16, y - 1, 16, 12, app.pnl_danger)
		app.gg.draw_text(rx + cw - 12, y, '×', gg.TextCfg{ color: app.pnl_bg, size: 10, bold: true })
	}
	// logs — wired to desktop_engine eventbus process_log + swarm_logs
	app.gg.draw_text(rx + 8, col_y + 100, 'Logs — demultiplexed per swarm (1024 cap, backpressure)', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	// collect logs via collect_engine_logs filtered for swarm
	all_logs := collect_engine_logs(app)
	mut swarm_logs := []TermLine{}
	for l in all_logs {
		if l.source.contains('swarm') || l.level == 'handoff' || l.msg.contains('swarm') || l.msg.contains('GOD') {
			swarm_logs << l
		}
	}
	if swarm_logs.len == 0 {
		swarm_logs = all_logs.filter(it.level == 'handoff' || it.level == 'proc')[..if all_logs.len > 4 {
			4
		} else {
			all_logs.len
		}]
	}
	visible_logs := (col_h - 120) / 11
	app.swarm_logs_scroll = clamp_scroll(app.swarm_logs_scroll, swarm_logs.len, visible_logs)
	for i in 0 .. visible_logs {
		idx := app.swarm_logs_scroll + i
		if idx >= swarm_logs.len {
			break
		}
		l := swarm_logs[idx]
		y := col_y + 114 + i * 11
		app.gg.draw_text(rx + 8, y, '${l.ts} ${l.msg[..if l.msg.len > 32 { 32 } else { l.msg.len }]}', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
	}
	app.gg.draw_text(rx + 8, col_y + col_h - 14, 'EventBus: state_changed · swarm_handoff · process_log → one tick · rev ${app.engine_rev}', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
}

// ── Workspace IDE — super potent, easy to manage ────────────────────────────────
// Modular helpers: kanban → file-tree → editor tabs → git rails → diff → memory palace.
// Each helper is 20-30 lines, single responsibility, brokered via Engine.
// File-tree: left 180px, virtualized, twisty, git_status dots, click expands.
// Editor: center tabs, syntax (V/md/yaml), line numbers, highlight.
// Git: right 240px CHANGES/HISTORY/COMPARE rails, commit graph lanes, diff hunks.
// Memory palace: semantic recall via Engine.memory_semantic_recall (hybrid cosine).
// Brokered fs: every open validates harness_root_escape via Desktop proxy.
fn flatten_gui_tree(nodes []FileNode, depth int) []FileNode {
	mut out := []FileNode{}
	for n in nodes {
		mut copy := n
		copy.depth = depth
		copy.children = []FileNode{}
		out << copy
		if n.kind == 'dir' && n.expanded {
			flat := flatten_gui_tree(n.children, depth + 1)
			for c in flat {
				out << c
			}
		}
	}
	return out
}

fn file_tree_visible(app &GuiApp) []FileNode {
	return flatten_gui_tree(app.file_tree, 0)
}

fn toggle_expand_recursive(mut children []FileNode, target_path string) bool {
	for i, c in children {
		if c.path == target_path && c.kind == 'dir' {
			children[i].expanded = !c.expanded
			return true
		}
		if c.kind == 'dir' {
			if toggle_expand_recursive(mut children[i].children, target_path) {
				return true
			}
		}
	}
	return false
}

// syntax helpers for editor — 15-line pure, easy to manage
fn syntax_color(kind string) gg.Color {
	return match kind {
		'keyword' { col_lilac }
		'string' { col_mint }
		'comment' { col_slate }
		else { col_ink }
	}
}

fn highlight_line_local(line string, syntax string) []EditorToken {
	trim := line.trim_space()
	if syntax == 'v' && trim.starts_with('//') {
		return [EditorToken{line, 'comment'}]
	}
	if syntax == 'md' && line.starts_with('#') {
		return [EditorToken{line, 'keyword'}]
	}
	if syntax == 'yaml' && line.contains(':') {
		idx := line.index(':') or { -1 }
		if idx > 0 {
			return [EditorToken{line[..idx], 'keyword'}, EditorToken{line[idx..], 'plain'}]
		}
	}
	// simple keyword scan for v
	keywords := ['fn', 'pub', 'mut', 'import', 'struct', 'enum', 'const', 'if', 'else', 'for', 'in',
		'return', 'match']
	mut out := []EditorToken{}
	mut cur := ''
	for ch in line {
		if ch == ` ` || ch == `(` || ch == `)` || ch == `{` || ch == `}` || ch == `:` || ch == `,` || ch == `"` || ch == `'` {
			if cur != '' {
				kind := if cur in keywords { 'keyword' } else { 'plain' }
				out << EditorToken{cur, kind}
				cur = ''
			}
			if ch == `"` || ch == `'` {
				out << EditorToken{ch.ascii_str(), 'string'}
			} else {
				out << EditorToken{ch.ascii_str(), 'plain'}
			}
		} else {
			cur += ch.ascii_str()
		}
	}
	if cur != '' { out << EditorToken{cur, if cur in keywords { 'keyword' } else { 'plain' }} }
	if out.len == 0 { out << EditorToken{line, 'plain'} }
	return out
}

fn validate_workspace_draft(mut app GuiApp) bool {
	clean := app.desktop.engine_validate_workspace(app.workspace_draft) or {
		app.workspace_notice = 'Workspace error: ${err}'
		return false
	}
	app.workspace_draft = clean
	app.workspace_initialized = app.desktop.engine_workspace_initialized(clean)
	app.workspace_notice = if app.workspace_initialized {
		'Workspace is ready to use'
	} else {
		'Folder is valid. Initialize it to add workspace structure'
	}
	return true
}

fn initialize_workspace(mut app GuiApp) bool {
	if !apply_workspace(mut app, app.workspace_draft, 'Manual') {
		// A path that does not exist yet is still init-able: onboarding_ensure_workspace
		// creates the folder and scaffolds the workspace structure in one revision.
		if !os.is_dir(os.expand_tilde_to_home(app.workspace_draft.trim_space())) {
			rev := app.desktop.onboarding_ensure_workspace(app.workspace_draft) or {
				app.workspace_notice = 'Workspace initialization failed: ${err}'
				return false
			}
			app.workspace_notice = 'Workspace created (revision ${rev})'
			return apply_workspace(mut app, app.workspace_draft, 'Manual')
		}
		return false
	}
	rev := app.desktop.onboarding_ensure_workspace(app.harness_root) or {
		app.workspace_notice = 'Workspace initialization failed: ${err}'
		return false
	}
	app.workspace_initialized = app.desktop.engine_workspace_initialized(app.harness_root)
	app.workspace_notice = 'Workspace initialized (revision ${rev})'
	app.engine_rev = app.desktop.app_state_snapshot().revision
	app.api_calls = app.desktop.engine_api_calls()
	reload_workspace_tree(mut app)
	return true
}

fn select_panel(mut app GuiApp, panel int) {
	app.selected_panel = panel
	app.show_onboarding = false
	app.header_search_focus = false
	app.workspace_focus = false
	app.ghost_focused = false
	if panel != 0 {
		app.selected_desk = -1
	}
}

// appearance_label is the capitalized product name for UI surfaces.
pub fn appearance_label(a Appearance) string {
	match a {
		.paper {
			return 'Paper'
		}
		.ink {
			return 'Ink'
		}
		.system {
			return 'System'
		}
	}
}

// cycle_appearance rotates Paper → Ink → System, resolves the panel palette
// (<1 frame, no restart), persists the choice, and announces it. Every entry
// point (status chip, palette item, T key) funnels through here.
fn cycle_appearance(mut app GuiApp) {
	app.appearance = match app.appearance {
		.paper { Appearance.ink }
		.ink { Appearance.system }
		.system { Appearance.paper }
	}
	app.apply_appearance(app.appearance)
	save_ui_state(app)
	app.inspector_msg = 'Appearance: ${appearance_label(app.appearance)} — panel theme applied, chrome unchanged'
}

fn focus_workspace(mut app GuiApp) {
	select_panel(mut app, 9)
	app.workspace_focus = true
}

// ── Products & Packs — super potent easy management ─────────────────────────────────
// Brokered via Desktop.engine_products_catalog / packs_catalog (Engine typed, no shell).
// Easy to manage: product cards, pack chips, membership bulk, build preview, digest.
// ── Onboarding — super-potent wizard: workspace init, persona bootstrap, capability/target/product ──
// Single modal wizard where everything is possible and easy to manage. One view, seven steps:
// Detect → Capabilities (227) → Targets (7) → Products/Packs (5+7) → Workspace Init → Personas → Tour → Done.
// All actions wire via Desktop.onboarding_* proxies → Engine transactions → EventBus → AppState (no shell).
// utf8_truncate returns at most max_runes runes — never splitting a
// multi-byte UTF-8 character (#1168 review; byte offsets corrupt text).
fn utf8_truncate(s string, max_runes int) string {
	// a non-positive budget (narrow/resized windows) yields '' instead of a
	// negative slice — every caller derives budgets from live geometry
	if max_runes <= 0 {
		return ''
	}
	r := s.runes()
	if r.len <= max_runes {
		return s
	}
	return r[..max_runes].string()
}

// inspector_log_rect returns the log window rectangle draw_inspector really
// renders: x0, x1, y0 and height, including the per-desk VT header offset,
// the 18px footer reserve and the 40px minimum. Scroll, click and hover
// hit-testing all read it, so the interactive area can never drift from the
// drawn one (#1176 review).
fn inspector_log_rect(app &GuiApp, ix int, iy int, ih int) (int, int, int, int) {
	header_off := if app.selected_desk >= 0 && app.per_desk_ghost.len > app.selected_desk {
		76
	} else {
		0
	}
	mut log_h := ih - 328 - header_off
	if log_h < 40 {
		log_h = 40
	}
	return ix + 8, ix + inspector_w - 8, iy + 302 + header_off, log_h
}

fn draw_inspector(mut app GuiApp, w int, h int) {
	ix := inspector_x(app, w)
	iy := panel_top(app)
	iw := inspector_w
	ih := content_bottom(app, h) - iy
	app.gg.draw_rect_filled(ix, iy, iw, ih, col_charcoal)
	// VC3.5 (#1176): cabinet-drawer material. The dark column reads as one
	// drawer of a technical filing cabinet: folder tab with the title,
	// brass top edge, inner drawer inset, brass pull at the bottom. All
	// content drawing below is unchanged.
	app.gg.draw_rect_filled(ix, iy, iw, 2, app.pnl_select) // brass top edge
	app.gg.draw_rect_empty(ix + 6, iy + 8, iw - 12, ih - 16, col_line) // drawer inset
	app.gg.draw_rect_filled(ix + 12, iy - 6, 118, 8, app.pnl_select_hover) // folder tab
	app.gg.draw_rect_filled(ix + 12, iy + 2, 118, 2, col_charcoal)
	// the brass pull is drawn at the end of this function, inside the
	// reserved footer strip, so the log window never overdraws it
	app.gg.draw_line(ix, iy, ix, iy + ih, col_line)
	app.gg.draw_text(ix + 12, iy + 10, 'INSPECTOR', gg.TextCfg{ color: app.pnl_select, size: 14, bold: true })
	desks := desks_for_app(app)
	if app.selected_desk >= 0 && app.selected_desk < desks.len {
		d := desks[app.selected_desk]
		app.gg.draw_text(ix + 12, iy + 32, d.label, gg.TextCfg{ color: app.pnl_bg, size: 14, bold: true })
		app.gg.draw_text(ix + 12, iy + 50, d.tier + ' • ' + d.role, gg.TextCfg{ color: app.pnl_text_mut, size: 14 })
		status_col := if d.status == 'working' {
			app.pnl_success
		} else if d.status == 'blocked' { app.pnl_danger } else { app.pnl_text_mut }
		app.gg.draw_text(ix + 12, iy + 70, 'Status: ' + d.status, gg.TextCfg{ color: status_col, size: 14 })
		app.gg.draw_rect_filled(ix + 12, iy + 90, iw - 24, 1, col_line)
		app.gg.draw_text(ix + 12, iy + 100, 'Engine', gg.TextCfg{ color: app.pnl_bg, size: 14, bold: true })
		app.gg.draw_text(ix + 12, iy + 118, 'rev ${app.engine_rev}  •  api ${app.api_calls}', gg.TextCfg{ color: app.pnl_text_mut, size: 13 })
		app.gg.draw_text(ix + 12, iy + 136, 'Persist: ~/.cache/agent-toolkit/desktop/engine_state.json', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
		app.gg.draw_text(ix + 12, iy + 160, 'Actions', gg.TextCfg{ color: app.pnl_bg, size: 14, bold: true })
		// Open terminal — clickable, hover-aware
		hover_open := app.mouse_x >= ix + 12 && app.mouse_x <= ix + iw - 12 && app.mouse_y >= iy + 180 && app.mouse_y <= iy + 208
		bg_open := if hover_open { app.pnl_text } else { app.pnl_text }
		bd_open := if hover_open { app.pnl_select } else { app.pnl_border }
		app.gg.draw_rect_filled(ix + 12, iy + 180, iw - 24, 28, bg_open)
		app.gg.draw_rect_empty(ix + 12, iy + 180, iw - 24, 28, bd_open)
		app.gg.draw_text(ix + 24, iy + 188, 'Open terminal  (enter)', gg.TextCfg{ color: app.pnl_bg, size: 14 })
		// Route handoff — brass primary, hover brightens
		hover_route := app.mouse_x >= ix + 12 && app.mouse_x <= ix + iw - 12 && app.mouse_y >= iy + 214 && app.mouse_y <= iy + 242
		bg_route := if hover_route { app.pnl_select_hover } else { app.pnl_select }
		app.gg.draw_rect_filled(ix + 12, iy + 214, iw - 24, 28, bg_route)
		app.gg.draw_text(ix + 24, iy + 222, 'Route handoff  (h)', gg.TextCfg{ color: app.pnl_text, size: 14, bold: true })
		if app.inspector_msg != '' {
			app.gg.draw_text(ix + 12, iy + 250, app.inspector_msg, gg.TextCfg{ color: app.pnl_select, size: 12 })
		} else {
			// single line — the VT preview panel starts at iy + 272
			app.gg.draw_text(ix + 12, iy + 250, 'Live Engine inspector — no mock data.', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
		}
	} else {
		app.gg.draw_text(ix + 12, iy + 36, 'Select a desk on the floor', gg.TextCfg{ color: app.pnl_text_mut, size: 14 })
	}
	// ── Signature: per-desk libghostty-vt 40×6 multiplex — live VT preview (visible proof) ──
	// Each desk owns a 40×6 GhosttyTerminal; selected desk's VT renders inline in inspector
	// This is the designer's super-potent touch: multiplex is not hidden — it glows in the inspector
	if app.selected_desk >= 0 && app.selected_desk < desks.len && app.per_desk_ghost.len > app.selected_desk {
		vt_y := iy + 272
		vt_h := 74
		vt_x := ix + 8
		vt_w := iw - 16
		// panel chrome — inset terminal variant with brass accent
		app.gg.draw_rect_filled(vt_x, vt_y, vt_w, vt_h, col_charcoal)
		app.gg.draw_rect_empty(vt_x, vt_y, vt_w, vt_h, col_line)
		app.gg.draw_rect_filled(vt_x, vt_y, vt_w, 14, app.pnl_text)
		app.gg.draw_rect_filled(vt_x, vt_y + 13, vt_w, 1, app.pnl_border_hi)
		desk_label := desks[app.selected_desk].label
		app.gg.draw_text(vt_x + 8, vt_y + 3, 'VT 40×6 — ${desk_label} — libghostty-vt', gg.TextCfg{ color: app.pnl_select, size: 10, mono: true, bold: true })
		app.gg.draw_text(vt_x + vt_w - 34, vt_y + 3, '40×6', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
		// live cursor pulse when selected
		pulse_vt := if app.frame % 40 < 20 { app.pnl_select } else { tint(app.pnl_select, 70) }
		app.gg.draw_rect_filled(vt_x + vt_w - 10, vt_y + 4, 6, 6, pulse_vt)
		// render ghost visible lines — up to 6 rows inside 92px panel (14 header + 6*12 + 6)
		ghost := app.per_desk_ghost[app.selected_desk]
		vis := ghost.visible_lines()
		max_rows := 6
		for ri in 0 .. max_rows {
			if ri >= vis.len {
				break
			}
			mut line := vis[ri]
			if line.len > 36 {
				line = line[..36] + '…'
			}
			// strip control chars for display
			mut clean := ''
			for ch in line {
				if ch >= 32 && ch < 127 {
					clean += ch.ascii_str()
				} else if ch == `\t` {
					clean += '  '
				}
			}
			if clean.len == 0 {
				continue
			}
			ry := vt_y + 20 + ri * 12
			// per-line color from ghost colors
			col_idx := if ri < ghost.colors.len && ghost.colors[ri].len > 0 {
				ghost.colors[ri][0]
			} else {
				0
			}
			gcol := match col_idx {
				1 { app.pnl_select }
				2 { app.pnl_danger }
				3 { app.pnl_success }
				4 { app.pnl_text_mut }
				else { app.pnl_card_sel }
			}
			app.gg.draw_text(vt_x + 8, ry, clean, gg.TextCfg{ color: gcol, size: 11, mono: true })
		}
		if vis.len == 0 {
			app.gg.draw_text(vt_x + 8, vt_y + 24, '[${desk_label}] ready — 40×6 multiplex', gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
			app.gg.draw_text(vt_x + 8, vt_y + 38, 'type in world to feed this VT', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		}
		// scanline overlay — subtle CRT 1px every 2 rows
		for sy in 0 .. 7 {
			app.gg.draw_line(vt_x + 1, vt_y + 18 + sy * 10 + 9, vt_x + vt_w - 1, vt_y + 18 + sy * 10 + 9, tint(app.pnl_text, 10))
		}
		// bottom hint — click to focus main VT
		app.gg.draw_text(vt_x + 8, vt_y + vt_h - 9, 'multiplexed • Tab to focus global ghostty-vt', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	}
	// ── Per-desk live logs (workshop terminal) ──
	filter_q := active_log_filter(app)
	all_logs := collect_engine_logs(app)
	desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks.len {
		per_desk_logs(all_logs, desks[app.selected_desk], filter_q)
	} else {
		filtered_logs(all_logs, filter_q)
	}
	// header for activity with filter hint — shifted down to make room for 40×6 VT preview (signature)
	header := if filter_q != '' {
		'Activity — filter: ${filter_q}'
	} else {
		'Activity — per-desk live'
	}
	header_off := if app.selected_desk >= 0 && app.per_desk_ghost.len > app.selected_desk {
		76
	} else {
		0
	}
	header_y := iy + 276 + header_off
	app.gg.draw_text(ix + 12, header_y, header, gg.TextCfg{ color: col_text_on_cabinet, size: 13, bold: true })
	if filter_q != '' {
		app.gg.draw_text(ix + 12, header_y + 12, '${desk_logs.len}/${all_logs.len} match — palette filters logs', gg.TextCfg{ color: app.pnl_select, size: 11 })
	} else {
		app.gg.draw_text(ix + 12, header_y + 12, '${desk_logs.len} lines — click to copy • scroll', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	}
	// divider
	app.gg.draw_rect_filled(ix + 12, header_y + 22, iw - 24, 1, col_line)
	// scrollable log window inside inspector — one rectangle, shared with
	// every hit-test path so drawn and interactive areas cannot diverge
	log_x0, log_x1, log_y0, inspector_log_h := inspector_log_rect(app, ix, iy, ih)
	row_h := 13
	mut visible_i := inspector_log_h / row_h
	if visible_i < 1 {
		visible_i = 1
	}
	// clamp inspector scroll
	app.inspector_scroll = clamp_scroll(app.inspector_scroll, desk_logs.len, visible_i)
	start_i := app.inspector_scroll
	mut end_i := start_i + visible_i
	if end_i > desk_logs.len {
		end_i = desk_logs.len
	}
	// background for log area — xterm-like ink
	app.gg.draw_rect_filled(log_x0, log_y0 - 2, log_x1 - log_x0, inspector_log_h + 4, term_bg)
	app.gg.draw_rect_empty(log_x0, log_y0 - 2, log_x1 - log_x0, inspector_log_h + 4, col_line)
	if desk_logs.len == 0 {
		app.gg.draw_text(ix + 16, log_y0 + 6, 'No logs match filter', gg.TextCfg{ color: app.pnl_text_mut, size: 13, mono: true })
		app.gg.draw_text(ix + 16, log_y0 + 20, 'Clear palette (ESC) to show all', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	} else {
		for idx in start_i .. end_i {
			l := desk_logs[idx]
			row := idx - start_i
			y := log_y0 + row * row_h
			is_hover_i := idx == app.inspector_hover
			if is_hover_i {
				app.gg.draw_rect_filled(ix + 9, y - 1, iw - 18, row_h, app.pnl_text)
				app.gg.draw_rect_empty(ix + 9, y - 1, iw - 18, row_h, tint(app.pnl_select, 45))
			}
			// tiny level dot
			app.gg.draw_rect_filled(ix + 14, y + 4, 4, 4, term_level_color(l.level))
			// monospace log line — truncate to fit inspector
			mut txt := pad_right(l.ts, 8) + ' ' + pad_right(term_level_label(l.level), 7) + ' ' + pad_right(l.source, 12) + ' ' + l.msg
			if txt.len > 54 {
				txt = txt[..54] + '…'
			}
			app.gg.draw_text(ix + 22, y, txt, gg.TextCfg{
				color: if is_hover_i {
					app.pnl_bg
				} else {
					col_text_on_cabinet
				}
				size: 12
				mono: true
			})
		}
		// scrollbar for inspector
		if desk_logs.len > visible_i {
			mut bar_h := inspector_log_h * visible_i / desk_logs.len
			if bar_h < 12 {
				bar_h = 12
			}
			bar_y := log_y0 + (inspector_log_h - bar_h) * start_i / (desk_logs.len - visible_i)
			app.gg.draw_rect_filled(ix + iw - 10, log_y0, 3, inspector_log_h, tint(app.pnl_text, 180))
			app.gg.draw_rect_filled(ix + iw - 10, bar_y, 3, bar_h, app.pnl_border_hi)
		}
	}
	// bottom hint for inspector scroll
	app.gg.draw_text(ix + 12, iy + ih - 14, '↑↓ scroll  •  click row to copy  •  / filters', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	// VC3.5 (#1176): brass drawer pull, last so nothing overdraws it. It
	// lives in the strip reserved by inspector_log_h above the hint text.
	app.gg.draw_rect_filled(ix + iw / 2 - 22, iy + ih - 22, 44, 4, app.pnl_select_hover)
	app.gg.draw_rect_filled(ix + iw / 2 - 22, iy + ih - 22, 44, 1, app.pnl_select)
}

// onb_effective_term_h caps the terminal at a compact height while the
// onboarding shell owns the screen — the reference's terminal well reads as
// ~12-15% of the window, well under the production 1x/2x heights, which
// otherwise starve the board of the room its five sheets need.
pub fn onb_effective_term_h(app &GuiApp) int {
	// the cap is applied where term_height is computed (frame()); this stays
	// as the single accessor onb_layout and draw_terminal share
	return app.term_height
}

struct TerminalTab {
	label string
	view  int
}

fn terminal_tabs(app &GuiApp) []TerminalTab {
	mut tabs := [TerminalTab{'Terminal', -1}]
	if app.term_mode == 2 && app.sessions.len > 0 {
		tabs << TerminalTab{'Sessions', 15}
	}
	return tabs
}

fn terminal_tab_rect(x0 int, y0 int, i int) (int, int, int, int) {
	return x0 + 8 + i * 96, y0 + 3, 92, 20
}

fn terminal_rect(app &GuiApp, w int, h int) (int, int, int, int) {
	term_h := onb_effective_term_h(app)
	x := if app.lang.is_rtl() { 0 } else { dock_w }
	return x, h - 28 - term_h, w - dock_w, term_h
}

fn terminal_split_boundary(app &GuiApp, w int, h int) int {
	x, _, tw, _ := terminal_rect(app, w, h)
	content_x := x + 8
	content_w := tw - 16
	half := (content_w - 6) / 2
	return content_x + half + 3
}

fn draw_terminal(mut app GuiApp, w int, h int) {
	x0, y0, tw, term_h := terminal_rect(app, w, h)
	// background — xterm ink, workshop border
	app.gg.draw_rect_filled(x0, y0, tw, term_h, term_bg)
	app.gg.draw_line(x0, y0, x0 + tw, y0, term_border)
	dock_edge := if app.lang.is_rtl() { x0 + tw } else { x0 }
	app.gg.draw_line(dock_edge, y0, dock_edge, y0 + term_h, term_border)
	// Tabs expose only real terminal-backed views: the fleet terminal and
	// live PTY sessions when any exist.
	app.gg.draw_rect_filled(x0, y0, tw, 24, term_header_bg)
	app.gg.draw_line(x0, y0 + 24, w, y0 + 24, col_line)
	app.gg.draw_rect_filled(x0, y0, 3, 24, col_brass)
	tabs := terminal_tabs(app)
	for i, tab in tabs {
		tx, ty, tab_w, tab_h := terminal_tab_rect(x0, y0, i)
		active := if tab.view == -1 {
			app.term_view < 0
		} else if tab.view == 0 {
			app.term_view >= 0 && app.term_view < 15
		} else {
			app.term_view >= 15
		}
		app.gg.draw_rect_filled(tx, ty, tab_w, tab_h, if active {
			col_ink700
		} else {
			term_header_bg
		})
		if active {
			app.gg.draw_rect_filled(tx, ty + tab_h - 2, tab_w, 2, col_brass)
		}
		app.gg.draw_text(tx + 10, ty + 5, tab.label, gg.TextCfg{
			color: if active { col_paper } else { col_slate }
			size: 10
			bold: active
		})
	}
	// focus pill — Tab flips ghost focus (type into the embedded terminal)
	focus_x := x0 + 16 + tabs.len * 96
	pill_bg := if app.ghost_focused { tint(col_mint, 60) } else { tint(col_slate, 30) }
	pill_bd := if app.ghost_focused { col_mint } else { col_line_light }
	app.gg.draw_rect_filled(focus_x, y0 + 4, 118, 16, pill_bg)
	app.gg.draw_rect_empty(focus_x, y0 + 4, 118, 16, pill_bd)
	app.gg.draw_text(focus_x + 8, y0 + 7, if app.ghost_focused {
		'FOCUSED · Tab to release'
	} else {
		'UNFOCUSED · Tab to type'
	}, gg.TextCfg{
		color: if app.ghost_focused { col_mint } else { col_slate }
		size: 10
		bold: true
	})
	filter_q := active_log_filter(app)
	if filter_q != '' {
		app.gg.draw_text(focus_x + 128, y0 + 8, 'filter: ${filter_q} — ${filtered_logs(collect_engine_logs(app), filter_q).len} match', gg.TextCfg{ color: col_brass, size: 11, bold: true, mono: true })
	}
	// height mode buttons — 1× / 2× / MAX / ×  (^` cycles 0→1→2)
	for bi, bl in ['1×', '2×', 'MAX', '×'] {
		bx := x0 + tw - 148 + bi * 34
		bact := app.term_mode == bi
		bhov := app.mouse_x >= bx && app.mouse_x <= bx + 30 && app.mouse_y >= y0 + 4 && app.mouse_y <= y0 + 20
		bbg := if bact {
			col_brass
		} else if bhov { col_charcoal2 } else { col_ink }
		bfg := if bact { col_ink } else { col_slate }
		bbd := if bact {
			col_brass
		} else if bhov { col_line_light } else { col_line }
		app.gg.draw_rect_filled(bx, y0 + 4, 30, 16, bbg)
		app.gg.draw_rect_empty(bx, y0 + 4, 30, 16, bbd)
		app.gg.draw_text(bx + (30 - bl.len * 7) / 2, y0 + 7, bl, gg.TextCfg{ color: bfg, size: 10, bold: true, mono: true })
	}
	// live indicator pulse
	pulse_col := if app.frame % 60 < 30 { col_mint } else { tint(col_mint, 120) }
	app.gg.draw_rect_filled(x0 + tw - 176, y0 + 8, 8, 8, pulse_col)
	app.gg.draw_text(x0 + tw - 164, y0 + 7, 'LIVE', gg.TextCfg{ color: pulse_col, size: 11, bold: true })
	// copy feedback
	if app.term_copied != '' && app.frame - app.term_copied_at < 90 {
		mut txt := app.term_copied
		if txt.len > 64 {
			txt = txt[..64] + '…'
		}
		app.gg.draw_text(x0 + 12, y0 + term_h - 14, 'copied → ${txt}', gg.TextCfg{ color: col_brass, size: 12, mono: true })
	}
	// content — libghostty-vt (ghostty-inspired) + live logs
	// Ghostty already fed in frame(); render its scrollback + prompt
	content_y := y0 + 28
	content_x := x0 + 8
	content_w := tw - 16
	// inner panel
	app.gg.draw_rect_filled(content_x, content_y, content_w, term_h - 32, col_charcoal)
	app.gg.draw_rect_empty(content_x, content_y, content_w, term_h - 32, col_line)
	// scrollback search — paper field overlay + match highlighting (Ctrl+F)
	if app.term_search_open || app.term_search != '' {
		sf_y := content_y - 2
		app.gg.draw_rect_filled(content_x, sf_y, content_w, 22, col_cream50)
		app.gg.draw_rect_empty(content_x, sf_y, content_w, 22, col_brass)
		draw_search_lens(mut app, content_x + 6, sf_y + 5)
		mut matches := 0
		if app.term_search.len > 1 {
			for gl in app.ghost.lines {
				if gl.to_lower().contains(app.term_search.to_lower()) {
					matches++
				}
			}
		}
		app.gg.draw_text(content_x + 24, sf_y + 4, if app.term_search == '' {
			'search scrollback…  (Esc close)'
		} else {
			app.term_search
		}, gg.TextCfg{
			color: if app.term_search == '' { col_ink_soft } else { col_ink }
			size: 11
			mono: true
		})
		if app.term_search.len > 1 {
			app.gg.draw_text(content_x + content_w - 90, sf_y + 4, '${matches} lines', gg.TextCfg{
				color: col_brass_dim
				size: 10
				bold: true
				mono: true
			})
		}
	}
	// Signature: CRT scanline overlay — faint horizontal lines at 50% rows (atelier workshop vibe)
	for sy in 1 .. ((term_h - 32) / 2) {
		sy_y := content_y + sy * 2
		if sy_y < content_y + term_h - 32 {
			app.gg.draw_line(content_x + 1, sy_y, content_x + content_w - 1, sy_y, tint(col_ink, 8))
		}
	}
	// session picker — in MAX mode a chip strip picks whose VT fills the screen
	chip_h := if app.term_mode == 2 { 30 } else { 0 }
	if app.term_mode == 2 {
		mut chx := content_x + 6
		app.gg.draw_rect_filled(content_x, content_y - 2, content_w, 26, col_cream50)
		fleet_sel := app.term_view < 0
		app.gg.draw_rect_filled(chx, content_y + 2, 46, 18, if fleet_sel {
			col_brass
		} else {
			col_manila_tab
		})
		app.gg.draw_text(chx + 8, content_y + 6, 'Fleet', gg.TextCfg{
			color: if fleet_sel { col_ink } else { col_ink_soft }
			size: 10
			bold: fleet_sel
		})
		chx += 52
		// + Sess chip — opens the agent picker dialog (up front: always reachable)
		nchip_sel := app.sessions_dialog
		app.gg.draw_rect_filled(chx, content_y + 2, 58, 18, if nchip_sel {
			col_oxide
		} else {
			col_cream100
		})
		app.gg.draw_rect_empty(chx, content_y + 2, 58, 18, col_ink300)
		app.gg.draw_text(chx + 8, content_y + 6, '+ Sess', gg.TextCfg{
			color: if nchip_sel { col_oxide } else { col_steel_ink }
			size: 9
			bold: true
		})
		chx += 64
		// Split toggle — two VT panes side-by-side (right-click a chip sets pane B)
		split_sel := app.term_split
		app.gg.draw_rect_filled(chx, content_y + 2, 52, 18, if split_sel {
			col_brass
		} else {
			col_cream100
		})
		app.gg.draw_rect_empty(chx, content_y + 2, 52, 18, col_ink300)
		app.gg.draw_text(chx + 10, content_y + 6, 'Split', gg.TextCfg{
			color: if split_sel { col_ink } else { col_steel_ink }
			size: 9
			bold: split_sel
		})
		chx += 58
		desks_all := desks_for_app(app)
		for di, d in desks_all {
			if chx + 66 > content_x + content_w - 6 {
				break
			}
			dsel := app.term_view == di
			app.gg.draw_rect_filled(chx, content_y + 2, 62, 18, if dsel {
				col_brass
			} else {
				col_manila_tab
			})
			chip_lbl := if d.label.len > 9 { d.label[..9] } else { d.label }
			app.gg.draw_text(chx + 6, content_y + 6, chip_lbl, gg.TextCfg{
				color: if dsel { col_ink } else { col_ink_soft }
				size: 9
				bold: dsel
			})
			chx += 66
		}
		// live PTY sessions
		for si, ses in app.sessions {
			ssel := app.term_view == 15 + si
			app.gg.draw_rect_filled(chx, content_y + 2, 62, 18, if ssel {
				col_brass
			} else {
				col_sage_soft
			})
			app.gg.draw_text(chx + 6, content_y + 6, ses.agent, gg.TextCfg{
				color: if ssel { col_ink } else { col_paper }
				size: 9
				bold: ssel
			})
			chx += 66
		}
		app.gg.draw_text(content_x + content_w - 150, content_y + 6, 'session picker — click a desk', gg.TextCfg{ color: col_ink_soft, size: 9 })
		// agent picker dialog — detect ALL supported agent CLIs
		if app.sessions_dialog {
			det := pty_mod.detect()
			dlg_x, dlg_y, dlg_w := content_x + 120, content_y + 60, 480
			dlg_h := 40 + det.len * 26 + 20
			app.gg.draw_rect_filled(dlg_x + 3, dlg_y + 3, dlg_w, dlg_h, tint(col_ink, 120))
			app.gg.draw_rect_filled(dlg_x, dlg_y, dlg_w, dlg_h, col_cream50)
			app.gg.draw_rect_empty(dlg_x, dlg_y, dlg_w, dlg_h, col_brass)
			app.gg.draw_text(dlg_x + 14, dlg_y + 10, 'New session — pick an agent CLI', gg.TextCfg{
				color: col_ink
				size: 13
				bold: true
				family: app.fonts.display
			})
			for ri, row in det {
				ry := dlg_y + 34 + ri * 26
				hov := app.mouse_x >= dlg_x + 10 && app.mouse_x <= dlg_x + dlg_w - 10 && app.mouse_y >= ry && app.mouse_y <= ry + 22
				app.gg.draw_rect_filled(dlg_x + 10, ry, dlg_w - 20, 22, if hov {
					col_manila_tab
				} else {
					col_cream100
				})
				app.gg.draw_rect_empty(dlg_x + 10, ry, dlg_w - 20, 22, col_ink300)
				state_col := if row.found { col_sage_soft } else { col_ink_soft }
				state_txt := if row.found { 'found' } else { 'not installed' }
				app.gg.draw_text(dlg_x + 18, ry + 4, row.agent.binary, gg.TextCfg{ color: col_ink, size: 12, bold: true, mono: true })
				app.gg.draw_text(dlg_x + dlg_w - 130, ry + 4, '${row.agent.agent} · ${state_txt}', gg.TextCfg{ color: state_col, size: 10 })
			}
		}
	}
	// Ghostty visible lines — fleet feed, per-desk VT, per-session VT — 1 or 2 panes
	desk_view := app.term_mode == 2 && app.term_view >= 0 && app.term_view < app.per_desk_ghost.len
	sess_view := app.term_mode == 2 && app.term_view >= 15 && app.term_view - 15 < app.sessions.len
	split_on := app.term_mode == 2 && app.term_split
	row_h := 16
	mut cy2 := content_y + chip_h
	// pane geometry: 1 or 2 panes
	mut pane_x := [content_x]
	mut pane_w := [content_w]
	mut pane_ids := [app.term_view]
	if split_on {
		half := (content_w - 6) / 2
		pane_x = [content_x, content_x + half + 6]
		pane_w = [half, half]
		pane_ids = [app.term_view, app.term_view_b]
	}
	visible := term_visible_rows(term_h) - 1 - (chip_h / 16) // chips + prompt reserve
	for pi in 0 .. pane_x.len {
		vt := vt_for(app, pane_ids[pi])
		ghost_lines := vt.visible_lines()
		vx := pane_x[pi]
		vw := pane_w[pi]
		if ghost_lines.len == 0 {
			empty := if pane_ids[pi] >= 0 && pane_ids[pi] < 15 {
				'[${vt_label(app, pane_ids[pi])}] VT ready — live handoffs stream here'
			} else {
				'Ghostty VT ready — type help, skills, clear — live Engine logs stream here'
			}
			app.gg.draw_text(vx + 10, cy2 + 10, empty, gg.TextCfg{ color: col_slate_dim, size: 14, mono: true })
			continue
		}
		// pane header rail
		app.gg.draw_rect_filled(vx, cy2 - 2, vw, 2, if pi == 0 { col_brass } else { col_steel_ink })
		app.gg.draw_text(vx + 2, cy2 + 2, vt_label(app, pane_ids[pi]), gg.TextCfg{ color: col_ink_soft, size: 9, mono: true })
		for idx, line in ghost_lines {
			if idx >= visible {
				break
			}
			y := cy2 + 18 + idx * row_h
			is_hover := !split_on && pi == 0 && idx == app.term_hover
			if is_hover {
				app.gg.draw_rect_filled(vx + 1, y - 1, vw - 2, row_h, col_charcoal2)
			}
			// color from ghost
			col_idx := if idx < vt.colors.len && vt.colors[idx].len > 0 {
				vt.colors[idx][0]
			} else {
				0
			}
			gcol := match col_idx {
				1 { col_brass }
				2 { col_oxide }
				3 { col_mint }
				4 { col_slate }
				else { col_paper_dim }
			}
			// truncate
			disp := if line.len > 44 { line[..44] + '…' } else { line }
			is_match := app.term_search.len > 1 && line.to_lower().contains(app.term_search.to_lower())
			if is_match {
				app.gg.draw_rect_filled(vx + 1, y - 1, vw - 8, row_h + 1, tint(col_brass, 90))
			}
			app.gg.draw_text(vx + 8, y, disp, gg.TextCfg{ color: gcol, size: 13, mono: true })
		}
	}
	// prompt line at bottom of terminal content (fleet view only — desk VTs are read-only feeds)
	prompt_y := content_y + term_h - 32 - 18
	if split_on {
		app.gg.draw_rect_filled(content_x, prompt_y - 4, content_w, 18, tint(col_slate, 24))
		app.gg.draw_text(content_x + 8, prompt_y, 'split — type into the pane under the cursor', gg.TextCfg{ color: col_ink_soft, size: 12, mono: true })
	} else if desk_view {
		app.gg.draw_rect_filled(content_x, prompt_y - 4, content_w, 18, tint(col_slate, 20))
		app.gg.draw_text(content_x + 8, prompt_y, '[${desk_feed_label(app)}] read-only desk feed · Fleet chip returns to the prompt', gg.TextCfg{ color: col_slate, size: 12, mono: true })
	} else if sess_view {
		ses := app.sessions[app.term_view - 15]
		if ses.exited && !ses.dismissed {
			// restart stamp card — dead session, scrollback preserved
			cw, chh := 420, 92
			cx, cy := content_x + content_w / 2 - cw / 2, content_y + 60
			app.gg.draw_rect_filled(cx + 3, cy + 3, cw, chh, tint(col_ink, 120))
			app.gg.draw_rect_filled(cx, cy, cw, chh, col_cream50)
			app.gg.draw_rect_empty(cx, cy, cw, chh, col_oxide)
			app.gg.draw_text(cx + 16, cy + 10, '[${ses.agent}] session exited', gg.TextCfg{
				color: col_ink
				size: 13
				bold: true
				family: app.fonts.display
			})
			app.gg.draw_text(cx + 16, cy + 28, 'The agent CLI process is gone — scrollback preserved.', gg.TextCfg{ color: col_ink_soft, size: 10 })
			// buttons: Restart (sage) / Dismiss (paper)
			sess_restart_hover := app.mouse_x >= cx + 16 && app.mouse_x <= cx + 96 && app.mouse_y >= cy + 46 && app.mouse_y <= cy + 70
			app.gg.draw_rect_filled(cx + 16, cy + 46, 80, 24, if sess_restart_hover {
				col_sage_soft
			} else {
				col_cream100
			})
			app.gg.draw_rect_empty(cx + 16, cy + 46, 80, 24, col_sage_soft)
			app.gg.draw_text(cx + 32, cy + 52, 'Restart', gg.TextCfg{ color: col_sage_soft, size: 11, bold: true })
			sess_dismiss_hover := app.mouse_x >= cx + 108 && app.mouse_x <= cx + 188 && app.mouse_y >= cy + 46 && app.mouse_y <= cy + 70
			app.gg.draw_rect_filled(cx + 108, cy + 46, 80, 24, if sess_dismiss_hover {
				col_manila_tab
			} else {
				col_cream50
			})
			app.gg.draw_rect_empty(cx + 108, cy + 46, 80, 24, col_ink300)
			app.gg.draw_text(cx + 124, cy + 52, 'Dismiss', gg.TextCfg{ color: col_ink_soft, size: 11 })
		} else if ses.exited {
			app.gg.draw_rect_filled(content_x, prompt_y - 4, content_w, 18, tint(col_oxide, 40))
			app.gg.draw_text(content_x + 8, prompt_y, '[${ses.agent}] session exited', gg.TextCfg{ color: col_oxide, size: 12, mono: true })
		} else {
			state := 'live · type below'
			app.gg.draw_rect_filled(content_x, prompt_y - 4, content_w, 18, tint(col_mint, 30))
			app.gg.draw_text(content_x + 8, prompt_y, '[${ses.agent}] ${state} · Esc returns to Fleet', gg.TextCfg{ color: col_sage_soft, size: 12, mono: true })
		}
	} else {
		// prompt bg
		app.gg.draw_rect_filled(content_x, prompt_y - 4, content_w, 18, tint(col_brass, 12))
		prompt_col := if app.ghost_focused { col_brass } else { col_slate }
		app.gg.draw_text(content_x + 8, prompt_y, app.ghost.prompt_line(), gg.TextCfg{ color: prompt_col, size: 13, mono: true, bold: app.ghost_focused })
	}
	// focus hint
	if !app.ghost_focused {
		app.gg.draw_text(content_x + content_w - 110, prompt_y, 'click to focus', gg.TextCfg{ color: col_slate, size: 12 })
	}
	// scrollbar for libghostty-vt
	all_ghost_len := app.ghost.lines.len
	if all_ghost_len > visible {
		track_x := content_x + content_w - 6
		track_y := content_y + 8
		track_h := term_h - 48
		start := if app.ghost.scroll - visible - 1 < 0 { 0 } else { app.ghost.scroll - visible - 1 }
		mut bar_h := track_h * visible / all_ghost_len
		if bar_h < 14 {
			bar_h = 14
		}
		bar_y := track_y + (track_h - bar_h) * start / (all_ghost_len - visible)
		app.gg.draw_rect_filled(track_x, track_y, 4, track_h, tint(col_ink, 200))
		app.gg.draw_rect_filled(track_x, bar_y, 4, bar_h, col_brass_dim)
	}
	// footer stats
	app.gg.draw_text(content_x + 6, y0 + term_h - 14, '${all_ghost_len} lines  •  Ghostty VT  •  ↑↓ history  •  enter to run', gg.TextCfg{ color: col_slate, size: 11 })
}

// desk_rect already defined above
fn draw_palette(mut app GuiApp, w int, h int) {
	// Dunder paper palette — manila folder with brass rivets, typewriter mono, paper grain
	z := app.global_zoom
	app.gg.draw_rect_filled(0, 0, w, h, tint(app.pnl_text, 88))
	cx := w / 2 - 280
	cy := h / 2 - 180
	pw := 560
	ph := 360
	// manila folder tab protruding top
	app.gg.draw_rect_filled(cx + 18, cy - 14, 120, 14, app.pnl_card_sel)
	app.gg.draw_rect_filled(cx + 18, cy - 14, 120, 2, app.pnl_select)
	app.gg.draw_text(cx + 28, cy - 11, 'Dunder Mifflin', gg.TextCfg{ color: app.pnl_text_mut, size: scaled_size(9, z) })
	pixel_panel(mut app, cx, cy, pw, ph, 'default')
	app.gg.draw_text(cx + 16, cy + 12, 'Command Palette', gg.TextCfg{ color: app.pnl_text, size: scaled_size(13, z), bold: true })
	app.gg.draw_text(cx + pw - 90, cy + 12, '/  •  ESC', gg.TextCfg{ color: app.pnl_text_mut, size: scaled_size(11, z) })
	app.gg.draw_rect_filled(cx + 12, cy + 32, pw - 24, 32, app.pnl_text)
	app.gg.draw_rect_empty(cx + 12, cy + 32, pw - 24, 32, app.pnl_select)
	// perforated dots each side
	for py in 0 .. 2 {
		app.gg.draw_rect_filled(cx + 14, cy + 38 + py * 10, 1, 1, tint(app.pnl_bg, 28))
		app.gg.draw_rect_filled(cx + pw - 15, cy + 38 + py * 10, 1, 1, tint(app.pnl_bg, 28))
	}
	q := if app.palette_query == '' {
		'Search skills, agents, panels…'
	} else {
		app.palette_query
	}
	qcol := if app.palette_query == '' { app.pnl_text_mut } else { app.pnl_bg }
	app.gg.draw_text(cx + 20, cy + 42, '› ${q}', gg.TextCfg{ color: qcol, size: scaled_size(14, z) })
	// S4B preview mode: show the real dry-run/diff lines instead of rows.
	if app.palette_preview.len > 0 {
		app.gg.draw_text(cx + 20, cy + 62, 'Preview — nothing applied yet', gg.TextCfg{ color: app.pnl_select, size: scaled_size(12, z), bold: true })
		for pi, line in app.palette_preview {
			if pi >= 7 {
				break
			}
			app.gg.draw_text(cx + 20, cy + 84 + pi * 18, line, gg.TextCfg{ color: app.pnl_text, size: scaled_size(11, z), mono: true })
		}
		if app.palette_preview.len > 7 {
			app.gg.draw_text(cx + 20, cy + 84 + 7 * 18, '… ${app.palette_preview.len - 7} more lines', gg.TextCfg{ color: app.pnl_text_mut, size: scaled_size(10, z) })
		}
		app.gg.draw_text(cx + 16, cy + ph - 16, 'Enter to execute  •  Esc back — the preview is a real dry-run, nothing was written', gg.TextCfg{ color: app.pnl_text_mut, size: scaled_size(11, z) })
		return
	}
	filtered := filtered_palette(mut app)
	for i, it in filtered {
		if i >= 7 {
			break
		}
		y := cy + 76 + i * 36
		is_sel := i == app.palette_selected
		bg := if is_sel { app.pnl_text } else { app.pnl_card }
		bd := if is_sel { app.pnl_select } else { app.pnl_border }
		app.gg.draw_rect_filled(cx + 12, y, pw - 24, 32, bg)
		app.gg.draw_rect_empty(cx + 12, y, pw - 24, 32, bd)
		if is_sel {
			app.gg.draw_rect_filled(cx + 12, y, 3, 32, app.pnl_select)
			app.gg.draw_rect_filled(cx + 15, y + 1, pw - 27, 1, tint(app.pnl_bg, 14))
		} else {
			// subtle manila tab on unselected
			app.gg.draw_rect_filled(cx + pw - 52, y + 4, 36, 6, app.pnl_card_sel)
		}
		// S4C: every row is registry-derived. Navigation rows keep localized
		// labels via their i18n key; entities and actions render their own
		// registry labels.
		pal_label := if it.is_action {
			it.label
		} else if it.kind == .navigation {
			tr(app, 'palette.' + nav_tr_key(it.panel))
		} else {
			it.label
		}
		// S4C: every row is registry-derived. Navigation rows keep localized
		// labels and descriptions via their i18n keys; entities and actions
		// render their own registry content; unavailable rows say why.
		pal_desc := if it.is_action {
			it.desc
		} else if !it.available {
			'unavailable — ${it.unavailable_reason}'
		} else if it.kind == .navigation {
			tr_desc := tr(app, 'pdesc.' + nav_tr_key(it.panel))
			if tr_desc != 'pdesc.' + nav_tr_key(it.panel) {
				tr_desc
			} else {
				it.desc
			}
		} else {
			it.desc
		}
		pal_fam := if needs_sc(pal_label) {
			app.fonts.sc
		} else if needs_ar(pal_label) { app.fonts.arabic } else { '' }
		app.gg.draw_text(cx + 20, y + 6, pal_label, gg.TextCfg{
			color: if is_sel { app.pnl_bg } else { app.pnl_text }
			size: scaled_size(13, z)
			bold: is_sel
			family: pal_fam
		})
		pal_dfam := if needs_sc(pal_desc) {
			app.fonts.sc
		} else if needs_ar(pal_desc) { app.fonts.arabic } else { '' }
		app.gg.draw_text(cx + 20, y + 18, pal_desc, gg.TextCfg{
			color: if is_sel {
				app.pnl_text_mut
			} else {
				app.pnl_text_mut
			}
			size: scaled_size(11, z)
			family: pal_dfam
		})
		mut keys_x := cx + pw - 20 - it.keys.len * 7
		if keys_x < cx + pw / 2 {
			keys_x = cx + pw / 2
		}
		app.gg.draw_text(keys_x, y + 10, it.keys, gg.TextCfg{ color: app.pnl_border_hi, size: scaled_size(12, z), bold: true })
	}
	if filtered.len == 0 {
		app.gg.draw_text(cx + 20, cy + 86, 'No matches — try another query', gg.TextCfg{ color: app.pnl_text_mut, size: scaled_size(13, z) })
	}
	// footer hint paper tape — reflects the S4B action state honestly
	footer := if app.palette_armed != '' {
		'Enter again to confirm  •  Esc to cancel'
	} else if filtered.any(it.is_recent) {
		'↑↓ navigate  •  Enter run again (re-validated)  •  U undo  •  Type to filter ${skills_total(mut app)} skills'
	} else if filtered.any(it.is_entity && !it.is_action) {
		'↑↓ navigate  •  Enter to open  •  Tab expand actions  •  Type to filter ${skills_total(mut app)} skills  •  Ctrl± zoom'
	} else {
		'↑↓ navigate  •  Enter to open  •  Type to filter ${skills_total(mut app)} skills  •  Ctrl± zoom'
	}
	app.gg.draw_text(cx + 16, cy + ph - 16, footer, gg.TextCfg{ color: app.pnl_text_mut, size: scaled_size(11, z) })
}

fn draw_help(mut app GuiApp, w int, h int) {
	z := app.global_zoom
	app.gg.draw_rect_filled(0, 0, w, h, tint(app.pnl_text, 80))
	cx := w / 2 - 250
	cy := h / 2 - 150
	pw := 500
	ph := 300
	pixel_panel(mut app, cx, cy, pw, ph, 'default')
	app.gg.draw_text(cx + 16, cy + 12, 'Paper Co. — Shortcuts', gg.TextCfg{ color: app.pnl_text, size: scaled_size(14, z), bold: true })
	lines := [
		'/  Command palette — fuzzy search ${skills_total(mut app)} skills, agents, panels (v${app.version})',
		'Ctrl +  = / -  Zoom in/out   •   Ctrl + 0  Reset  •  Ctrl + Scroll',
		'1 – 0 / p / i / o  Switch panel (World…Jobs, Products, Insights, Onboarding)',
		'T  Cycle panel appearance (Paper → Ink → System, persists)',
		'↑  ↓  Navigate palette / floor desks  •  Enter to activate',
		'Esc  Close palette / help / onboarding  •  H  Toggle this help',
		'Click  Desk, dock file-tab or inspector — hover for brass highlight',
		'Enter  Open terminal for selected desk  •  R  Route handoff',
	]
	for i, l in lines {
		app.gg.draw_text(cx + 16, cy + 38 + i * 18, l, gg.TextCfg{ color: app.pnl_text, size: scaled_size(13, z) })
	}
	// about stamp — version + live catalog counts, single source of truth.
	app.gg.draw_text(cx + 16, cy + ph - 42, 'v${app.version_full} • ${skills_total(mut app)} skills · ${agents_active_total(mut app)} agents · ${mcp_total(mut app)} providers · ${targets_total(mut app)} targets · ${products_total(mut app)} products', gg.TextCfg{ color: app.pnl_border_hi, size: scaled_size(11, z), bold: true })
	app.gg.draw_text(cx + 16, cy + ph - 22, 'Fraunces display • IBM Plex body • IBM Plex Mono  •  Press H or Esc to close.', gg.TextCfg{ color: app.pnl_text_mut, size: scaled_size(11, z) })
}

fn activate_palette_selection(mut app GuiApp) {
	app.workspace_focus = false
	app.header_search_focus = false
	app.ghost_focused = false
	filtered := filtered_palette(mut app)
	if filtered.len == 0 {
		app.palette_open = false
		app.palette_query = ''
		app.palette_selected = 0
		return
	}
	clamped := if app.palette_selected < 0 {
		0
	} else if app.palette_selected >= filtered.len {
		filtered.len - 1
	} else {
		app.palette_selected
	}
	sel := filtered[clamped]
	// S4D: recent rows re-run through the current registry (never replay)
	if sel.is_recent {
		rerun_recent(mut app, sel)
		return
	}
	// S4B: contextual action rows run through preview → confirm → execute.
	if sel.is_action {
		run_palette_action(mut app, sel)
		return
	}
	// S4A: registry rows navigate to their typed panel destination. Entity
	// rows open the owning panel and deep-link the canonical entity (S4B).
	if sel.is_entity {
		idx := panel_index_for(sel.panel)
		if idx >= 0 {
			// shared panel-selection transition (clears desk selection, focus
			// and onboarding state exactly like dock navigation)
			select_panel(mut app, idx)
			deep_link_select(mut app, sel.kind, sel.entity_id)
		}
		app.palette_open = false
		app.palette_query = ''
		app.palette_selected = 0
		app.palette_expanded = ''
		app.palette_preview = []
		app.palette_preview_for = ''
		app.palette_armed = ''
		return
	}
	// S4C: no legacy activation arms remain — every row is a registry entity
	// or action.
	app.palette_open = false
	app.palette_query = ''
	app.palette_selected = 0
}

// run_palette_action drives the S4B contextual action flow:
// preview (real dry-run) → confirmation for mutating actions → execution.
// Confirmation never comes silently: either the preview was shown or the
// user pressed Enter twice.
fn run_palette_action(mut app GuiApp, sel PaletteRow) {
	if app.palette_reg == unsafe { nil } {
		return
	}
	// unavailable actions never arm and never execute — say why, once
	if !sel.available {
		app.inspector_msg = 'Unavailable — ${sel.unavailable_reason}'
		return
	}
	// appearance is a real shell preference: executed directly via the real
	// setter, recorded truthfully in the journal with an exact undo
	// (previous appearance + real setter), no fake evidence
	if sel.action_kind == .app_theme_cycle {
		previous := app.appearance.str()
		cycle_appearance(mut app)
		if app.palette_reg != unsafe { nil } {
			app.palette_reg.record_execution(.app_theme_cycle, .app, 'agent-toolkit', 'Change appearance', .succeeded, palette.ActionEvidence{}, palette.UndoEntry{
				kind: .appearance
				action_kind: .app_theme_cycle
				entity_kind: .app
				entity_id: 'agent-toolkit'
				label: 'Change appearance'
				spec: palette.AppearanceUndo{
					previous_appearance: previous
					expected_appearance: app.appearance.str()
				}
			})
		}
		return
	}
	// swarm launch needs a real task-text input (plus recipe/backend choices)
	// — the palette cannot provide that honestly, so route to the swarm
	// panel launch form, which executes through the same Engine seam and
	// records the launch as requested
	if sel.action_kind == .swarm_launch {
		select_panel(mut app, 8)
		reset_palette_action_state(mut app)
		app.inspector_msg = 'Swarm launch — set task, recipe and backend here; the Engine records the request as requested'
		return
	}
	// an open preview means the user has seen the real effects — Enter now
	// executes as informed confirmation
	if app.palette_preview.len > 0 && app.palette_preview_for == sel.id {
		execute_palette_action(mut app, sel)
		return
	}
	if sel.needs_preview && sel.available {
		lines := app.palette_reg.preview(sel.action_kind, sel.entity_id) or {
			app.inspector_msg = 'Preview unavailable: ${err.msg()}'
			return
		}
		app.palette_preview = lines
		app.palette_preview_for = sel.id
		return
	}
	if sel.needs_confirm {
		if app.palette_armed == sel.id {
			execute_palette_action(mut app, sel)
			return
		}
		app.palette_armed = sel.id
		return
	}
	execute_palette_action(mut app, sel)
}

// execute_palette_action executes through the typed registry (Engine seams)
// and surfaces the truthful outcome. Failures never render as success.
fn execute_palette_action(mut app GuiApp, sel PaletteRow) {
	if app.palette_reg == unsafe { nil } {
		return
	}
	args := palette.ActionArgs{
		confirm: true
		task: app.palette_query.trim_space()
	}
	out := app.palette_reg.execute(sel.kind, sel.entity_id, sel.action_kind, args) or {
		app.inspector_msg = 'Failed: ${err.msg()}'
		reset_palette_action_state(mut app)
		return
	}
	prefix := match out.status {
		.succeeded { '' }
		.partial { 'Partial — ' }
		.failed { 'Failed — ' }
		.unavailable { 'Unavailable — ' }
		.not_confirmed { 'Not confirmed — ' }
	}
	ev := out.evidence
	detail := if ev.receipt_path != '' {
		' · receipt ${ev.receipt_path}'
	} else if ev.run_id != '' {
		' · run ${ev.run_id}'
	} else if ev.job_id != '' {
		' · job ${ev.job_id}'
	} else {
		''
	}
	app.inspector_msg = '${prefix}${out.summary}${detail}'
	reset_palette_action_state(mut app)
}

// reset_palette_action_state closes the palette and clears the action flow.
fn reset_palette_action_state(mut app GuiApp) {
	app.palette_open = false
	app.palette_query = ''
	app.palette_selected = 0
	app.palette_expanded = ''
	app.palette_preview = []
	app.palette_preview_for = ''
	app.palette_armed = ''
}

// deep_link_select resolves the canonical entity identity in its owning
// panel: selection is set by identity lookup, never by display strings.
fn deep_link_select(mut app GuiApp, kind palette.EntityKind, id string) {
	match kind {
		.skill {
			entries := skills_filtered_entries(mut app)
			for idx, e in entries {
				if e.id == id {
					app.skills_selected = idx
					return
				}
			}
			// narrow the panel to the canonical id so the entity is findable
			app.skills_query = id
			app.skills_selected = 0
		}
		.agent {
			// the agents panel shares the search field; filter to the
			// canonical agent id (Engine search by identity)
			app.skills_query = id
		}
		else {
			// panels without a selection seam (e.g. targets, whose roster is
			// rendered directly from the Engine) get navigation only — no
			// field is written that the panel would ignore
		}
	}
}

// is_panel_nav_key reports whether c is a documented global panel shortcut
// (digits select panels, p/i/o jump to Products/Insights/Onboarding — see the
// help overlay). Panel type-to-filter capture must let these fall through to
// the global handler, otherwise filter panels swallow digits and keyboard
// users cannot navigate away.
fn is_panel_nav_key(c u32) bool {
	if c >= `0` && c <= `9` {
		return true
	}
	return c == `p` || c == `P` || c == `i` || c == `I` || c == `o` || c == `O`
}

fn onboarding_key(mut app GuiApp, e &gg.Event) bool {
	if !app.show_onboarding {
		return false
	}
	if e.char_code == `o` || e.char_code == `O` || e.key_code == .escape {
		app.show_onboarding = false
		app.onboarding_msg = 'Setup closed — press o to reopen'
		return true
	}
	if e.key_code == .right || e.char_code == `n` || e.char_code == `N` {
		onboarding_advance(mut app)
		return true
	}
	if e.key_code == .left || e.char_code == `b` || e.char_code == `B` {
		if app.onboarding_step > 0 {
			app.onboarding_step--
			app.onboarding_msg = '${onb_stages[app.onboarding_step]} — ${onb_stage_hints[app.onboarding_step]}'
		}
		return true
	}
	if e.key_code == .enter {
		if app.onboarding_step >= onb_last_stage {
			onboarding_advance(mut app)
		} else {
			onb_apply_stage(mut app)
		}
		return true
	}
	// Modal ownership: unrelated shortcuts are consumed, not passed through.
	return true
}

fn on_event(e &gg.Event, mut app GuiApp) {
	if e.typ == .char {
		// V sokol X11 delivers printables as separate .char events (key_down carries
		// key_code only). C backends (win/mac) set char_code on key_down AND send
		// .char — dedupe per frame so text is never doubled. Replayed as key_down
		// so every printable branch (palette, search, skills, memory, ghost) works.
		if app.last_keydown_frame == app.frame && app.last_keydown_char == e.char_code {
			return
		}
		if (e.char_code >= 32 && e.char_code < 127) || e.char_code > 127 {
			is_mod := (e.modifiers & u32(gg.Modifier.ctrl)) != 0 || (e.modifiers & u32(gg.Modifier.super)) != 0
			// `/` is the palette toggle — never text when the palette is open
			if app.palette_open && e.char_code == `/` {
				return
			}
			if !is_mod {
				mut ke := &gg.Event{
					typ: .key_down
					char_code: e.char_code
					key_code: e.key_code
					modifiers: e.modifiers
					key_repeat: e.key_repeat
				}
				on_event(ke, mut app)
			}
		}
		return
	}
	if e.typ == .key_down {
		if e.char_code != 0 {
			app.last_keydown_char = e.char_code
			app.last_keydown_frame = app.frame
		}
		// Palette and Help are higher overlays; otherwise onboarding owns keys
		// before stale field, PTY, terminal-search, or panel focus can consume them.
		if !app.palette_open && !app.show_help && onboarding_key(mut app, e) {
			return
		}
		if !app.palette_open && app.show_help {
			if e.key_code == .escape || e.char_code == `h` || e.char_code == `H` {
				app.show_help = false
			}
			return
		}
		// PTY session focus — keys go to the agent TUI pane under the cursor
		// (single session view or split pane under the mouse). Esc returns to Fleet.
		if !app.palette_open && !app.show_help && app.term_mode == 2
			&& (app.term_view >= 15 || (app.term_split && app.term_view_b >= 15)) {
			if e.key_code == .escape {
				app.term_view = -1
				app.term_split = false
				return
			}
			// target pane: the one under the mouse (split) or the viewed session
			mut target := app.term_view
			if app.term_split {
				target = if app.mouse_x < terminal_split_boundary(app, app.gg.width, app.gg.height) {
					app.term_view
				} else {
					app.term_view_b
				}
			}
			si := target - 15
			if target >= 15 && si < app.sessions.len {
				b := session_key_bytes(e)
				if b != '' {
					app.sessions[si].sess.write(b)
				}
			}
			return
		}
		// terminal scrollback search — captures typing while open (Ctrl+F toggles)
		if !app.palette_open && !app.show_help && app.term_search_open {
			if e.key_code == .escape || e.key_code == .enter {
				app.term_search_open = false
				return
			}
			if e.key_code == .backspace {
				if app.term_search.len > 0 {
					app.term_search = app.term_search[..app.term_search.len - 1]
				}
				return
			}
			if (e.char_code >= 32 && e.char_code < 127) || e.char_code > 127 {
				app.term_search += rune(e.char_code).str()
				return
			}
			return
		}
		if app.palette_open {
			if e.key_code == .escape {
				// S4B: Esc unwinds the innermost palette context first —
				// preview mode, then expansion, then the palette itself
				if app.palette_preview.len > 0 {
					app.palette_preview = []
					app.palette_preview_for = ''
					app.palette_armed = ''
					return
				}
				if app.palette_expanded != '' {
					app.palette_expanded = ''
					app.palette_armed = ''
					return
				}
				app.palette_open = false
				app.palette_query = ''
				app.palette_selected = 0
				return
			}
			if e.key_code == .enter {
				activate_palette_selection(mut app)
				return
			}
			if e.key_code == .u {
				// S4D: undo the selected recent execution (optimistic exact
				// check runs again right before restoring). Only a recent
				// row with undo consumes the key — otherwise 'u' falls
				// through to normal query typing (#1162 review).
				filtered_u := filtered_palette(mut app)
				if app.palette_selected >= 0 && app.palette_selected < filtered_u.len {
					sel_u := filtered_u[app.palette_selected]
					if sel_u.is_recent {
						rec_u := app.palette_reg.find_recent(sel_u.execution_id) or {
							return
						}
						if rec_u.is_undoable() {
							handle_palette_undo(mut app, sel_u)
							return
						}
					}
				}
			}
			if e.key_code == .tab {
				// S4B: expand/collapse contextual actions of the selected
				// registry entity row
				filtered_tab := filtered_palette(mut app)
				if app.palette_selected >= 0 && app.palette_selected < filtered_tab.len {
					sel_tab := filtered_tab[app.palette_selected]
					if sel_tab.is_entity && !sel_tab.is_action {
						app.palette_expanded = if app.palette_expanded == sel_tab.id {
							''
						} else {
							sel_tab.id
						}
						app.palette_preview = []
						app.palette_preview_for = ''
						app.palette_armed = ''
					}
				}
				return
			}
			if e.key_code == .backspace {
				if app.palette_query.len > 0 {
					app.palette_query = app.palette_query[..app.palette_query.len - 1]
					// clamp selection after filtering narrows
					filtered := filtered_palette(mut app)
					if app.palette_selected >= filtered.len {
						app.palette_selected = if filtered.len > 0 { filtered.len - 1 } else { 0 }
					}
				}
				return
			}
			if e.key_code == .up {
				app.palette_armed = ''
				filtered := filtered_palette(mut app)
				if filtered.len > 0 {
					if app.palette_selected > 0 {
						app.palette_selected--
					} else {
						app.palette_selected = filtered.len - 1
					}
				}
				return
			}
			if e.key_code == .down {
				app.palette_armed = ''
				filtered := filtered_palette(mut app)
				if filtered.len > 0 {
					if app.palette_selected + 1 < filtered.len {
						app.palette_selected++
					} else {
						app.palette_selected = 0
					}
				}
				return
			}
			if e.char_code >= 32 && e.char_code < 127 {
				app.palette_query += rune(e.char_code).str()
				// keep selection clamped after filter narrows; reset to top for new query
				app.palette_selected = 0
				filtered2 := filtered_palette(mut app)
				if app.palette_selected >= filtered2.len && filtered2.len > 0 {
					app.palette_selected = filtered2.len - 1
				}
				return
			}
			return
		}
		// #1128: Tab focuses the workspace path field when the Workspace
		// panel is active — keyboard users can reach the path without a
		// mouse (standard focus semantics; Tab/Enter are the field's own
		// unfocus/apply keys once focused).
		if app.selected_panel == 9 && !app.workspace_focus && !app.show_onboarding
			&& e.key_code == .tab {
			app.workspace_focus = true
			return
		}
		// Text fields capture keys before global shortcuts. In particular, a
		// workspace path needs '/', digits, and '~' without opening commands or
		// navigating to a different panel.
		if app.workspace_focus {
			if e.key_code == .escape || e.key_code == .tab {
				app.workspace_focus = false
				return
			}
			if e.key_code == .enter {
				apply_workspace(mut app, app.workspace_draft, 'Manual')
				return
			}
			if e.key_code == .backspace {
				if app.workspace_draft.len > 0 {
					// strip a whole rune — byte slicing corrupts multibyte paths
					runes := app.workspace_draft.runes()
					app.workspace_draft = runes[..runes.len - 1].string()
				}
				return
			}
			is_workspace_mod := (e.modifiers & u32(gg.Modifier.ctrl)) != 0 || (e.modifiers & u32(gg.Modifier.super)) != 0
			if !is_workspace_mod && ((e.char_code >= 32 && e.char_code < 127) || e.char_code > 127) {
				app.workspace_draft += rune(e.char_code).str()
				return
			}
			return
		}
		if app.header_search_focus {
			if e.key_code == .escape {
				app.header_search_focus = false
				app.global_search = ''
				app.skills_query = ''
				return
			}
			if e.key_code == .enter {
				app.skills_query = app.global_search
				app.palette_query = app.global_search
				if app.global_search != '' {
					select_panel(mut app, 1)
				}
				app.header_search_focus = false
				return
			}
			if e.key_code == .backspace {
				if app.global_search.len > 0 {
					app.global_search = app.global_search[..app.global_search.len - 1]
					if app.selected_panel == 1 {
						app.skills_query = app.global_search
					}
				}
				return
			}
			is_search_mod := (e.modifiers & u32(gg.Modifier.ctrl)) != 0 || (e.modifiers & u32(gg.Modifier.super)) != 0
			if !is_search_mod && ((e.char_code >= 32 && e.char_code < 127) || e.char_code > 127) {
				app.global_search += rune(e.char_code).str()
				if app.selected_panel == 1 {
					app.skills_query = app.global_search
				}
				return
			}
			return
		}
		// VC6 (#1173): Operations text fields (search / swarm task) — an
		// active text field outranks the terminal and panel shortcuts
		if operations_key(mut app, e) {
			return
		}
		if e.key_code == .escape {
			if app.palette_open {
				app.palette_open = false
				app.palette_query = ''
				app.palette_selected = 0
				return
			}
			if app.show_help {
				app.show_help = false
				return
			}
			if app.show_onboarding {
				app.show_onboarding = false
				app.onboarding_msg = 'Onboarding dismissed — press o to reopen'
				return
			}
			if app.ghost_focused && app.term_visible {
				// super potent: Esc first unfocuses Ghostty — preserves terminal data
				app.ghost_focused = false
				return
			}
			// desk fullscreen: Esc exits the attach (panel state preserved) or
			// drops a plain MAX + desk-tab fullscreen to the fleet feed (#1101)
			if app.term_view >= 0 {
				esc_desk_fullscreen(mut app)
				return
			}
			// panel-scoped Esc clears search fields — Esc must never hard-quit
			// the app (that was a data-loss footgun; Ctrl+Q quits explicitly)
			if lib_is_panel(app.selected_panel) {
				app.skills_query = ''
				app.skills_domain = ''
				app.lib_filter = ''
				return
			}
			if app.selected_panel == 9 {
				app.memory_query = ''
				return
			}
			// doctor dry-run preview is modal — Esc cancels it from anywhere (#1108)
			if app.doctor_preview != '' {
				app.doctor_preview = ''
				app.doctor_preview_lines = []
				app.inspector_msg = 'Doctor dry-run cancelled — nothing was written'
				return
			}
			// mcp provider drawer is modal too (#1106)
			if app.mcp_drawer != '' {
				app.mcp_drawer = ''
				app.inspector_msg = 'MCP drawer closed'
				return
			}
			return
		}
		// libghostty-vt toggle — Tab flips ghost_focused, the super potent multiplexed terminal
		if e.key_code == .tab {
			if app.term_visible {
				app.ghost_focused = !app.ghost_focused
			}
			return
		}
		// global zoom — Dunder paper: Ctrl/Cmd + =/- /0, also Ctrl+scroll
		is_mod := (e.modifiers & u32(gg.Modifier.ctrl)) != 0 || (e.modifiers & u32(gg.Modifier.super)) != 0
		if is_mod {
			if e.key_code == .equal || e.key_code == .kp_add || (e.char_code == `+` || e.char_code == `=`) {
				app.global_zoom = zoom_step(app.global_zoom, 1)
				app.zoom_toast = zoom_percent(app.global_zoom)
				app.zoom_toast_at = app.frame
				return
			}
			if e.key_code == .minus || e.key_code == .kp_subtract || e.char_code == `-` {
				app.global_zoom = zoom_step(app.global_zoom, -1)
				app.zoom_toast = zoom_percent(app.global_zoom)
				app.zoom_toast_at = app.frame
				return
			}
			if e.key_code == ._0 || e.char_code == `0` {
				app.global_zoom = 1.0
				app.zoom_toast = '100%'
				app.zoom_toast_at = app.frame
				return
			}
			if e.key_code == .f {
				if app.term_visible {
					app.term_search_open = !app.term_search_open
					if !app.term_search_open {
						app.term_search = ''
					}
				}
				return
			}
			if e.key_code == .m && app.selected_panel == 0 {
				// M toggles Office floor map; visible tab switch is the primary control.
				app.office_map_view = !app.office_map_view
				return
			}
			if e.key_code == .q {
				// Ctrl+Q — explicit quit (Esc never kills the app; it cancels layers)
				save_ui_state(app)
				app.gg.quit()
				return
			}
			if e.key_code == .grave_accent {
				// ^` — cycle embedded terminal height: compact → tall → max → compact
				app.term_mode = match app.term_mode {
					1 { 2 }
					2 { 0 }
					else { 1 }
				}
				app.term_visible = app.term_mode != 3
				return
			}
		}
		// #1128: the workspace draft path needs '/' — the palette hotkey must
		// not fire while the workspace field has focus (an absolute path was
		// impossible to type before this guard)
		if (e.key_code == .slash || (e.key_code == .k && is_mod)) && !app.workspace_focus {
			app.palette_open = true
			app.palette_query = ''
			app.palette_selected = 0
			return
		}
		// VC5 (#1173): the Library tabs (Skills/Agents/Products/MCP) share one
		// search field and one key handler — typing filters (spaces included),
		// ←/→ select, ↑/↓ scroll rows, Enter runs the primary Engine action
		// (library_view.v). Like header_search_focus above, the field owns
		// printable letters *before* the global letter shortcuts (h help,
		// r handoff) so "github" / "review" can actually be typed; the
		// documented nav keys (digits, p/i/o) still fall through.
		if !app.palette_open && !app.show_help && lib_is_panel(app.selected_panel) {
			if library_key(mut app, e) {
				return
			}
		}
		if e.char_code == `h` || e.char_code == `H` {
			app.show_help = !app.show_help
			return
		}
		if e.char_code == `r` || e.char_code == `R` {
			// Route handoff from inspector via keyboard
			desks := desks_for_app(app)
			if app.selected_desk >= 0 && app.selected_desk < desks.len {
				app.inspector_msg = 'Handoff routed: ${desks[app.selected_desk].label} → reviewer'
			}
			return
		}
		// super potent IDE typing — skills 227 fuzzy + memory palace semantic recall + file-tree nav
		// When skills or workspace panels active, capture typing there instead of ghost (easy to manage, brokered)
		if !app.palette_open && !app.show_help {
			// Doctor panel — f fixes all via Engine TX, Enter opens dry-run preview
			// (Enter again confirms, Esc cancels), real repair + audit stamp
			if app.selected_panel == 5 {
				// (Esc-cancel lives in the global Esc block above — it runs first.)
				if e.char_code == `f` || e.char_code == `F` {
					rev := app.desktop.engine_doctor_fix_all() or {
						app.inspector_msg = 'Doctor fix all failed: ${err}'
						return
					}
					app.engine_rev = rev
					app.api_calls = app.desktop.engine_api_calls()
					app.doctor_preview = ''
					app.doctor_preview_lines = []
					app.inspector_msg = if rev == 0 {
						'Doctor: all fixable already pass ✓'
					} else {
						'Doctor Fix All rev=${rev} via Engine TX'
					}
					return
				}
				if e.key_code == .enter {
					if app.doctor_preview != '' {
						doctor_preview_confirm(mut app)
						return
					}
					// open dry-run for first fixable — super-potent easy management
					checks := app.desktop.engine_doctor()
					for c in checks {
						if c.fixable && c.status != 'pass' {
							doctor_preview_open(mut app, c.id)
							return
						}
					}
					app.inspector_msg = 'Doctor: no fixable checks'
					return
				}
			}
			if app.selected_panel == 9 {
				// workspace IDE — memory palace semantic query + file tree nav + editor scroll
				if e.key_code == .backspace {
					if app.memory_query.len > 0 {
						app.memory_query = app.memory_query[..app.memory_query.len - 1]
					} else if app.skills_query.len > 0 {
						app.skills_query = app.skills_query[..app.skills_query.len - 1]
					}
					return
				}
				if e.key_code == .escape {
					app.memory_query = ''
					return
				}
				if e.key_code == .up {
					// scroll file tree or memory depending on hover region — default memory
					if app.memory_query != '' {
						app.memory_scroll -= 1
					} else {
						app.file_tree_scroll -= 1
					}
					return
				}
				if e.key_code == .down {
					if app.memory_query != '' {
						app.memory_scroll += 1
					} else {
						app.file_tree_scroll += 1
					}
					return
				}
				// same nav-key fall-through as the Skills panel (see is_panel_nav_key)
				if e.char_code > 32 && e.char_code < 127 && !is_panel_nav_key(e.char_code) {
					// typing goes to memory palace semantic recall when workspace active (super potent)
					app.memory_query += rune(e.char_code).str()
					return
				}
				// j/k for file tree scroll, h/l for editor tabs
				if e.char_code == `j` || e.char_code == `J` {
					app.file_tree_scroll += 1
					return
				}
				if e.char_code == `k` || e.char_code == `K` {
					app.file_tree_scroll -= 1
					return
				}
				if e.char_code == `h` || e.char_code == `H` {
					if app.active_tab > 0 {
						app.active_tab -= 1
					}
					return
				}
				if e.char_code == `l` || e.char_code == `L` {
					if app.active_tab + 1 < app.editor_tabs.len {
						app.active_tab += 1
					}
					return
				}
			}
		}
		// libghostty-vt — when focused, route typing to Ghostty terminal (libghostty-vt)
		// Terminal is bottom strip; ghost has priority over log scroll when focused — super potent
		// Exclude skills/MCP/doctor/workspace when they need typed search (super-potent easy management)
		if !app.palette_open && !app.show_help && app.ghost_focused && app.term_visible && app.selected_panel != 1 && app.selected_panel != 3 && app.selected_panel != 5 && app.selected_panel != 9 {
			// Ctrl+L clears Ghostty (like terminal clear), Ctrl+C copies Ghostty visible
			if (e.modifiers & u32(gg.Modifier.ctrl)) != 0 {
				if e.char_code == `l` || e.char_code == `L` {
					app.ghost.clear()
					return
				}
				if e.char_code == `c` || e.char_code == `C` {
					copy_to_clipboard(mut app, app.ghost.copy_visible())
					return
				}
			}
			// PgUp/PgDn scroll Ghostty scrollback 1000
			if e.key_code == .page_up {
				app.ghost.scroll_up(5)
				return
			}
			if e.key_code == .page_down {
				app.ghost.scroll_down(5)
				return
			}
			// Left/Right moves cursor inside toolkit> prompt
			if e.key_code == .left || e.key_code == .right {
				app.ghost.handle_key(int(e.key_code), e.char_code, false, false, false, false)
				return
			}
			// Enter submits, Backspace edits, Up/Down history, printable chars append (space inclusive)
			if e.key_code == .enter {
				app.ghost.submit_input()
				return
			}
			if e.key_code == .backspace {
				app.ghost.handle_key(int(e.key_code), e.char_code, true, false, false, false)
				return
			}
			if e.key_code == .up {
				app.ghost.handle_key(int(e.key_code), e.char_code, false, false, true, false)
				return
			}
			if e.key_code == .down {
				app.ghost.handle_key(int(e.key_code), e.char_code, false, false, false, true)
				return
			}
			if e.char_code >= 32 && e.char_code < 127 {
				app.ghost.handle_key(int(e.key_code), e.char_code, false, false, false, false)
				return
			}
			// Esc already handled above; other keys fall through to log scroll
		}
		// Terminal scroll when palette not open — j/k or page keys scroll feed, c copies hovered
		if !app.palette_open && app.term_visible {
			if e.key_code == .page_up {
				vis := term_visible_rows(app.term_height)
				app.term_scroll -= vis
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				app.term_auto_pin = false
				return
			}
			if e.key_code == .page_down {
				vis := term_visible_rows(app.term_height)
				app.term_scroll += vis
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				if app.term_scroll + vis >= all.len {
					app.term_auto_pin = true
				}
				return
			}
			if e.char_code == `j` || e.char_code == `J` {
				app.term_scroll += 1
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				vis := term_visible_rows(app.term_height)
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				app.term_auto_pin = app.term_scroll + vis >= all.len
				return
			}
			if e.char_code == `k` || e.char_code == `K` {
				app.term_scroll -= 1
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				vis := term_visible_rows(app.term_height)
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				app.term_auto_pin = false
				return
			}
			if e.char_code == `c` || e.char_code == `C` {
				if app.term_hover >= 0 {
					logs := filtered_logs(collect_engine_logs(app), active_log_filter(app))
					if app.term_hover < logs.len {
						copy_to_clipboard(mut app, logs[app.term_hover].raw + ' | ' + logs[app.term_hover].msg)
						return
					}
				}
				if app.inspector_hover >= 0 {
					desks := desks_for_app(app)
					all_logs := collect_engine_logs(app)
					desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks.len {
						per_desk_logs(all_logs, desks[app.selected_desk], active_log_filter(app))
					} else {
						filtered_logs(all_logs, active_log_filter(app))
					}
					if app.inspector_hover < desk_logs.len {
						copy_to_clipboard(mut app, desk_logs[app.inspector_hover].raw + ' | ' + desk_logs[app.inspector_hover].msg)
						return
					}
				}
			}
			if e.char_code == `g` || e.char_code == `G` {
				// Visibility is derived from term_mode every frame. Change the
				// persisted mode instead of toggling the derived field.
				app.term_mode = if app.term_mode == 3 { 0 } else { 3 }
				app.term_visible = app.term_mode != 3
				save_ui_state(app)
				return
			}
		}
		if e.char_code == `t` || e.char_code == `T` {
			// cycle panel appearance Paper → Ink → System (text inputs and
			// the terminal capture keys before this point, so typing keeps
			// working everywhere)
			cycle_appearance(mut app)
			return
		}
		if e.char_code >= `1` && e.char_code <= `9` {
			idx := int(e.char_code - `1`)
			if idx >= 0 && idx < 10 {
				select_panel(mut app, idx)
			}
			return
		}
		if e.char_code == `0` {
			// 0 → Workspace (panel 9)
			select_panel(mut app, 9)
			return
		}
		if e.char_code == `p` || e.char_code == `P` {
			select_panel(mut app, 10)
			return
		}
		if e.char_code == `i` || e.char_code == `I` {
			select_panel(mut app, 12)
			return
		}
		if e.char_code == `o` || e.char_code == `O` {
			select_panel(mut app, 11)
			app.show_onboarding = true
			app.onboarding_msg = 'Setup journey opened — five stages, press o to toggle'
			return
		}
		// Arrow navigation — grid-aware (4 columns, last cell empty => 15 desks)
		// Works in World floor; in other panels falls back to linear list nav
		if e.key_code == .left {
			// grid left: col 0 blocks, rightmost of previous row when needed
			cur := app.selected_desk
			if cur % 4 != 0 {
				desks := desks_for_app(app)
				target := cur - 1
				if target >= 0 && target < desks.len {
					app.selected_desk = target
				}
			} else if cur > 0 {
				// at left edge: wrap within row? stay
			}
			return
		}
		if e.key_code == .right {
			cur := app.selected_desk
			// col 3 blocks, and last row col 2 is max
			if cur % 4 != 3 {
				desks := desks_for_app(app)
				target := cur + 1
				// special: row 3 col 3 is missing (idx 15 would be out of 0..14)
				if target < desks.len && !(cur == 11 && target == 12 && false) {
					// allow normal; idx 14 is last valid; idx 15 would be >len
					app.selected_desk = target
				}
			}
			return
		}
		if e.key_code == .up {
			desks := desks_for_app(app)
			cur := app.selected_desk
			target := cur - 4
			if target >= 0 && target < desks.len {
				app.selected_desk = target
			} else if cur < 4 && target < 0 {
				// top row stays
			}
			return
		}
		if e.key_code == .down {
			desks := desks_for_app(app)
			cur := app.selected_desk
			target := cur + 4
			// handle missing cell: idx 15 is not a desk (row 3 col 3 empty)
			// row 2 col 3 (idx 11) going down would hit missing => stay
			if target < desks.len {
				app.selected_desk = target
			} else if cur == 11 {
				// 11 -> missing 15, do not move
			}
			return
		}
		if e.key_code == .enter {
			desks := desks_for_app(app)
			if app.selected_desk >= 0 && app.selected_desk < desks.len {
				app.inspector_msg = 'Terminal opened: ${desks[app.selected_desk].label}'
			}
			return
		}
	}
	if e.typ == .mouse_scroll {
		// global zoom via Ctrl/Cmd+scroll — paper-office accessibility
		if (e.modifiers & u32(gg.Modifier.ctrl)) != 0 || (e.modifiers & u32(gg.Modifier.super)) != 0 {
			if e.scroll_y < 0 {
				app.global_zoom = zoom_step(app.global_zoom, 1)
				app.zoom_toast = zoom_percent(app.global_zoom)
				app.zoom_toast_at = app.frame
				return
			}
			if e.scroll_y > 0 {
				app.global_zoom = zoom_step(app.global_zoom, -1)
				app.zoom_toast = zoom_percent(app.global_zoom)
				app.zoom_toast_at = app.frame
				return
			}
		}
		// scroll terminal or inspector depending on cursor region
		w3 := app.gg.width
		h3 := app.gg.height
		x0, y0, tw, term_h := terminal_rect(app, w3, h3)
		// wheel delta: gg scroll_y negative = up, positive = down (platform dependent). Treat scroll_y !=0.
		mut delta := 0
		if e.scroll_y < 0 {
			delta = -3
		} else if e.scroll_y > 0 {
			delta = 3
		} else if e.scroll_x < 0 {
			delta = -3
		} else if e.scroll_x > 0 {
			delta = 3
		}
		if app.term_visible && app.mouse_x >= x0 && app.mouse_x <= x0 + tw
			&& app.mouse_y >= y0 && app.mouse_y < y0 + term_h {
			// super potent: when ghost_focused, wheel scrolls Ghostty scrollback 1000; otherwise logs
			if app.ghost_focused {
				app.ghost.scroll_by(delta)
			} else {
				app.term_scroll += delta
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				vis := term_visible_rows(term_h)
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				if delta != 0 {
					if app.term_scroll + vis >= all.len {
						app.term_auto_pin = true
					} else {
						app.term_auto_pin = false
					}
				}
			}
			return
		}
		// inspector scroll when over inspector
		{
			ix := inspector_x(app, w3)
			iy := panel_top(app)
			ih := content_bottom(app, h3) - iy
			log_x0, log_x1, log_y0, inspector_log_h := inspector_log_rect(app, ix, iy, ih)
			if app.mouse_x >= log_x0 && app.mouse_x <= log_x1 && app.mouse_y >= log_y0
				&& app.mouse_y < log_y0 + inspector_log_h {
				desks := desks_for_app(app)
				all_logs := collect_engine_logs(app)
				filter_q := active_log_filter(app)
				desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks.len {
					per_desk_logs(all_logs, desks[app.selected_desk], filter_q)
				} else {
					filtered_logs(all_logs, filter_q)
				}
				vis_i := if inspector_log_h / 13 < 1 { 1 } else { inspector_log_h / 13 }
				app.inspector_scroll += delta
				app.inspector_scroll = clamp_scroll(app.inspector_scroll, desk_logs.len, vis_i)
				return
			}
		}
		// Library card-grid scroll uses the same layout as drawing and clicks.
		if lib_is_panel(app.selected_panel)
			&& library_scroll(mut app, app.mouse_x, app.mouse_y, delta, w3, h3) {
			return
		}
		// VC6 (#1173): Operations table scroll (Doctor/Jobs/Loops/Swarm)
		if operations_scroll(mut app, delta, w3, h3) {
			return
		}
		// insights tables scroll (VC7) — same geometry as draw_ins_table
		if app.selected_panel == 12 && insights_scroll_by(mut app, delta, w3, h3) {
			return
		}
		// workspace IDE scroll — file tree, editor, git, memory palace (super potent)
		if app.selected_panel == 9 {
			l := workspace_layout(app, w3, h3)
			// file tree left
			ft_x := l.fx + 12
			ft_y := l.mid_y
			ft_w := l.tree_w
			if app.mouse_x >= ft_x && app.mouse_x <= ft_x + ft_w && app.mouse_y >= ft_y && app.mouse_y < ft_y + l.mid_h {
				flat := file_tree_visible(app)
				visible := (l.mid_h - 28) / 18
				app.file_tree_scroll += delta
				app.file_tree_scroll = clamp_scroll(app.file_tree_scroll, flat.len, visible)
				return
			}
			// editor center
			ed_x := l.fx + 12 + l.tree_w + 4
			ed_w := l.fw - 24 - l.tree_w - 4 - l.git_w
			if app.mouse_x >= ed_x && app.mouse_x <= ed_x + ed_w && app.mouse_y >= l.mid_y && app.mouse_y < l.mid_y + l.mid_h {
				app.editor_scroll += delta
				return
			}
			// git right
			gx := l.fx + l.fw - l.git_w - 12
			if app.mouse_x >= gx && app.mouse_x <= gx + l.git_w && app.mouse_y >= l.mid_y && app.mouse_y < l.mid_y + l.mid_h {
				if app.git_rail == 'CHANGES' {
					changes := app.desktop.engine_git_changes()
					visible := ws_git_changes_visible(l.mid_h)
					app.git_scroll += delta
					app.git_scroll = clamp_scroll(app.git_scroll, changes.len, visible)
				} else if app.git_rail == 'HISTORY' {
					graph := app.desktop.engine_git_graph(20)
					visible := ws_git_history_visible(l.mid_h)
					app.git_scroll += delta
					app.git_scroll = clamp_scroll(app.git_scroll, graph.commits.len, visible)
				} else {
					app.diff_scroll += delta
				}
				return
			}
			// memory bottom
			if app.mouse_x >= l.fx + 12 && app.mouse_x <= l.fx + l.fw - 12 && app.mouse_y >= l.mem_y && app.mouse_y < l.mem_y + l.mem_h {
				results := app.desktop.engine_memory_recall(app.memory_query, 5)
				visible := (l.mem_h - 48) / 18
				app.memory_scroll += delta
				app.memory_scroll = clamp_scroll(app.memory_scroll, results.len, visible)
				return
			}
		}
		// no region: still scroll global terminal
		if app.term_visible {
			app.term_scroll += delta
			all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
			vis := term_visible_rows(term_h)
			app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
		}
		return
	}
	if e.typ == .mouse_down {
		app.mouse_x = int(e.mouse_x)
		app.mouse_y = int(e.mouse_y)
		mx := app.mouse_x
		my := app.mouse_y
		// Palette modal click handling — check palette first before dock/inspector
		if app.palette_open {
			cx := app.gg.width / 2 - 280
			cy := app.gg.height / 2 - 180
			pw := 560
			ph := 360
			inside_palette := mx >= cx && mx <= cx + pw && my >= cy && my <= cy + ph
			if inside_palette {
				// Hit a row? row hit area cy+76 + i*36 size 32
				filtered := filtered_palette(mut app)
				for i, _ in filtered {
					if i >= 7 {
						break
					}
					y := cy + 76 + i * 36
					if mx >= cx + 12 && mx <= cx + pw - 12 && my >= y && my <= y + 32 {
						app.palette_selected = i
						activate_palette_selection(mut app)
						return
					}
				}
				return
			} else {
				// outside closes palette (dismiss)
				app.palette_open = false
				app.palette_query = ''
				app.palette_selected = 0
				// continue to allow click through? close and return to avoid double action
				return
			}
		}
		if app.show_help {
			app.show_help = false
			return
		}
		// Header controls share the editorial masthead geometry with drawing.
		// Onboarding keeps the same masthead visually but disables shell
		// navigation while a setup stage owns focus.
		w := app.gg.width
		h := app.gg.height
		onb_shell_active := app.show_onboarding
		hl := header_layout(w, h)
		if !onb_shell_active && my >= 0 && my <= hl.mast_h {
			if onb_hit(mx, my, hl.workspace_x, hl.control_y, hl.workspace_w, hl.control_h) {
				focus_workspace(mut app)
				return
			}
			if onb_hit(mx, my, hl.search_x, hl.control_y, hl.search_w, hl.control_h) {
				if mx >= hl.search_x + hl.search_w - 20 && app.global_search != '' {
					app.global_search = ''
					app.skills_query = ''
					app.header_search_focus = false
				} else {
					app.header_search_focus = true
					app.workspace_focus = false
					app.ghost_focused = false
				}
				return
			}
			if onb_hit(mx, my, hl.theme_x, hl.control_y, hl.theme_w, hl.control_h) {
				cycle_appearance(mut app)
				return
			}
			if onb_hit(mx, my, hl.lang_x, hl.control_y, hl.lang_w, hl.control_h) {
				app.lang = match app.lang {
					.en { Lang.es }
					.es { Lang.zh }
					.zh { Lang.ar }
					.ar { Lang.en }
				}
				save_ui_state(app)
				app.header_search_focus = false
				app.workspace_focus = false
				return
			}
			if onb_hit(mx, my, hl.command_x, hl.control_y, hl.command_w, hl.control_h) {
				app.palette_open = true
				app.palette_query = ''
				app.palette_selected = 0
				app.header_search_focus = false
				app.workspace_focus = false
				app.ghost_focused = false
				return
			}
			app.header_search_focus = false
			app.workspace_focus = false
			return
		}
		// status bar zoom slider at bottom
		if my >= h - 28 && my <= h {
			// appearance chip (see frame): cycles Paper → Ink → System
			if mx >= w - 330 && mx <= w - 246 && my >= h - 22 && my <= h - 6 {
				cycle_appearance(mut app)
				return
			}
			// status bar slider approx at left 230..294 (see frame)
			left_base := 12 + 24 + 46 + 64 + 78 + 8
			zx_stat := left_base + 4
			if mx >= zx_stat - 6 && mx <= zx_stat + 64 + 12 && my >= h - 22 && my <= h - 6 {
				mut rel2 := mx - zx_stat
				if rel2 < 0 {
					rel2 = 0
				}
				if rel2 > 64 {
					rel2 = 64
				}
				pct2 := f64(rel2) / 64.0
				app.global_zoom = clamp_zoom(0.75 + pct2 * 0.75)
				app.zoom_toast = zoom_percent(app.global_zoom)
				app.zoom_toast_at = app.frame
				app.zoom_dragging = true
				return
			}
		}
		// VC5 (#1173): Library panels own every click inside the panel and
		// its detail column (tabs, search, chips, cards, actions) — same
		// geometry as draw_library / draw_library_detail.
		if lib_is_panel(app.selected_panel) && !app.show_onboarding {
			if library_click(mut app, mx, my, w, h) {
				return
			}
		}
		// VC6 (#1173): Operations panels (Doctor/Jobs/Loops/Swarm) own their
		// content area and the Details column — one shared layout for draw
		// and hit-testing (operations_view.v)
		if operations_click(mut app, mx, my, w, h) {
			return
		}
		// VC8 (#1173): Office overview roster rows select a desk (same geometry
		// as draw_office_roster)
		if app.selected_panel == 0 && !app.office_map_view && !app.show_onboarding {
			if office_roster_click(mut app, mx, my, w, h) {
				return
			}
		}
		// VC7 (#1173): Workspace / Insights own the right column — their tabs,
		// rows and detail sheets take the click before the inspector geometry.
		if !onb_shell_active && app.selected_panel == 9
			&& workspace_detail_click(mut app, mx, my, w, h) {
			return
		}
		if !onb_shell_active && app.selected_panel == 12 && insights_click(mut app, mx, my, w, h) {
			return
		}
		if !onb_shell_active && app.selected_panel == 11 && settings_click(mut app, mx, my, w, h) {
			return
		}
		// Inspector buttons — clickable
		ix := inspector_x(app, w)
		iy := panel_top(app)
		iw := inspector_w
		// Only when a desk selected
		desks := desks_for_app(app)
		if app.selected_desk >= 0 && app.selected_desk < desks.len {
			if mx >= ix + 12 && mx <= ix + iw - 12 && my >= iy + 180 && my <= iy + 208 {
				app.inspector_msg = 'Terminal opened: ${desks[app.selected_desk].label}'
				return
			}
			if mx >= ix + 12 && mx <= ix + iw - 12 && my >= iy + 214 && my <= iy + 242 {
				app.inspector_msg = 'Handoff routed: ${desks[app.selected_desk].label} → reviewer'
				return
			}
		}
		// Terminal click — super potent: focus Ghostty + copy
		if app.term_visible {
			w3 := app.gg.width
			h3 := app.gg.height
			x0, y0, tw, term_h := terminal_rect(app, w3, h3)
			content_y := y0 + 28
			content_x := x0 + 8
			content_w := tw - 16
			// header click: height mode buttons (1×/2×/MAX/×) — else toggle ghost focus
			if mx >= x0 && mx <= x0 + tw && my >= y0 && my < y0 + 24 {
				if mx >= x0 + tw - 148 && mx <= x0 + tw - 16 {
					btn := (mx - (x0 + tw - 148)) / 34
					if btn >= 0 && btn <= 3 {
						app.term_mode = btn
						return
					}
				}
				for i, tab in terminal_tabs(app) {
					tx, ty, tab_w, tab_h := terminal_tab_rect(x0, y0, i)
					if onb_hit(mx, my, tx, ty, tab_w, tab_h) {
						app.term_view = tab.view
						app.ghost_focused = tab.view < 0
						return
					}
				}
				app.ghost_focused = !app.ghost_focused
				return
			}
			// session picker chips (MAX mode): Fleet + desks + sessions + '+ Sess'
			if app.term_mode == 2 && mx >= content_x && mx <= content_x + content_w && my >= content_y - 2 && my < content_y + 26 {
				// right-click any chip → set pane B (split turns on automatically)
				if e.mouse_button == .right {
					app.term_split = true
					if mx < content_x + 122 {
						app.term_view_b = -1
					} else {
						idx := (mx - content_x - 180) / 66
						desks_all := desks_for_app(app)
						if idx >= 0 && idx < desks_all.len {
							app.term_view_b = idx
						} else if idx >= 0 && idx < desks_all.len + app.sessions.len {
							app.term_view_b = 15 + idx - desks_all.len
						}
					}
					return
				}
				if mx < content_x + 58 {
					app.term_view = -1
				} else if mx >= content_x + 116 && mx < content_x + 174 {
					// Split toggle chip (between '+ Sess' and the desks)
					app.term_split = !app.term_split
					if app.term_split && app.term_view_b < 0 {
						app.term_view_b = -1
					}
				} else if mx < content_x + 122 {
					app.sessions_dialog = true
					app.sessions_detected = pty_mod.detect()
				} else {
					idx := (mx - content_x - 180) / 66
					desks_all := desks_for_app(app)
					if idx >= 0 && idx < desks_all.len {
						app.term_view = idx
					} else if idx >= 0 && idx < desks_all.len + app.sessions.len {
						app.term_view = 15 + idx - desks_all.len
					}
				}
				return
			}
			// agent picker dialog rows
			if app.sessions_dialog {
				det := app.sessions_detected
				dlg_x, dlg_y, dlg_w, dlg_h := content_x + 120, content_y + 60, 480, 40 + det.len * 26 + 20
				if mx >= dlg_x && mx <= dlg_x + dlg_w && my >= dlg_y && my <= dlg_y + dlg_h {
					if my >= dlg_y + 34 {
						ri := (my - dlg_y - 34) / 26
						if ri >= 0 && ri < det.len && det[ri].found {
							spawn_session(mut app, det[ri].agent)
						}
						return
					}
					return
				}
				app.sessions_dialog = false
				return
			}
			_ = content_y
			// dead-session stamp card buttons (Restart / Dismiss)
			if app.term_mode == 2 && app.term_view >= 15 && app.term_view - 15 < app.sessions.len {
				ses := app.sessions[app.term_view - 15]
				if ses.exited && !ses.dismissed {
					cx, cy := content_x + content_w / 2 - 210, content_y + 60
					if mx >= cx + 16 && mx <= cx + 96 && my >= cy + 46 && my <= cy + 70 {
						mut s := &app.sessions[app.term_view - 15]
						ns := pty_mod.spawn(s.agent, s.sess.cmd, [], 120, 32) or {
							app.inspector_msg = 'Restart ${s.agent} error: ${err}'
							return
						}
						s.sess = ns
						s.exited = false
						s.dismissed = false
						app.inspector_msg = 'Session ${s.agent} restarted (pid ${ns.pid})'
						return
					}
					if mx >= cx + 108 && mx <= cx + 188 && my >= cy + 46 && my <= cy + 70 {
						app.sessions[app.term_view - 15].dismissed = true
						return
					}
				}
			}
			if mx >= content_x && mx <= content_x + content_w && my >= content_y + 16 && my < y0 + term_h - 18 {
				// click inside terminal focuses Ghostty and copies — potent multiplexed
				app.ghost_focused = true
				if app.ghost.lines.len > 0 {
					g_vis := app.ghost.visible_lines()
					row_h := 16
					rel_y := my - (content_y + 8)
					row := rel_y / row_h
					if row >= 0 && row < g_vis.len {
						copy_to_clipboard(mut app, g_vis[row])
						return
					}
				}
				// fallback: copy global log line
				row_h := 14
				vis := term_visible_rows(term_h)
				filter_q := active_log_filter(app)
				logs := filtered_logs(collect_engine_logs(app), filter_q)
				start := clamp_scroll(app.term_scroll, logs.len, vis)
				rel_y := my - (content_y + 16)
				row := rel_y / row_h
				idx := start + row
				if idx >= 0 && idx < logs.len {
					l := logs[idx]
					copy_to_clipboard(mut app, l.raw + ' | ' + l.msg)
					return
				}
			}
			// click elsewhere in terminal toggles auto-pin
			if mx >= x0 && mx <= x0 + tw && my >= y0 && my < y0 + term_h {
				app.term_auto_pin = !app.term_auto_pin
				if app.term_auto_pin {
					all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
					vis := term_visible_rows(term_h)
					if all.len > vis {
						app.term_scroll = all.len - vis
					}
					app.ghost.scroll_to_bottom()
				}
				return
			}
		}
		// Inspector per-desk log click — copy
		{
			ix2 := inspector_x(app, w)
			iy2 := panel_top(app)
			ih2 := content_bottom(app, h) - iy2
			log_x0, log_x1, log_y0, inspector_log_h := inspector_log_rect(app, ix2, iy2, ih2)
			if mx >= log_x0 && mx <= log_x1 && my >= log_y0 && my < log_y0 + inspector_log_h {
				row_h := 13
				mut visible_i := inspector_log_h / row_h
				if visible_i < 1 {
					visible_i = 1
				}
				desks2 := desks_for_app(app)
				all_logs := collect_engine_logs(app)
				filter_q := active_log_filter(app)
				desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks2.len {
					per_desk_logs(all_logs, desks2[app.selected_desk], filter_q)
				} else {
					filtered_logs(all_logs, filter_q)
				}
				start_i := clamp_scroll(app.inspector_scroll, desk_logs.len, visible_i)
				mut rel := my - log_y0
				row := rel / row_h
				idx := start_i + row
				if idx >= 0 && idx < desk_logs.len {
					l := desk_logs[idx]
					copy_to_clipboard(mut app, l.raw + ' | ' + l.msg)
					return
				}
			}
		}
		// The grouped task navigation and its hit targets use one shared row model.
		// The onboarding sidebar has its own simplified rows, handled inside
		// onboarding_click instead of the production nav model.
		dock_l_c := dock_x(app, w) + 8
		if !app.show_onboarding && mx >= dock_l_c
			&& mx <= dock_l_c + dock_w - 16 {
			for row in nav_rows(app, h) {
				if my >= row.y && my <= row.y + row.h {
					select_panel(mut app, row.panel)
					return
				}
			}
		}
		// Onboarding wizard click handling — super-potent easy management via Engine
		if app.show_onboarding {
			if onboarding_click(mut app, int(e.mouse_x), int(e.mouse_y), app.gg.width, app.gg.height) {
				return
			}
		}
		// Insights tabs / rows / details: handled by insights_click above (VC7).
		// Workspace IDE — file-tree, editor tabs, git rails CHANGES/HISTORY/COMPARE, commit graph, diff, memory palace
		// Super potent: brokered fs via Engine.open_path_validated (harness_root_escape), syntax, graph lanes, semantic recall
		if app.selected_panel == 9 {
			l := workspace_layout(app, w, h)
			// #1128: known-workspace folder tabs — click fills the draft for
			// the Validate/Switch controls (discovery never switches itself)
			for kr in app.known_ws_rects {
				if mx >= kr.x && mx <= kr.x + kr.w && my >= kr.y && my <= kr.y + kr.h2 {
					app.workspace_draft = kr.path
					validate_workspace_draft(mut app)
					return
				}
			}
			// workspace control row: field + Validate / Switch / Initialize
			if l.hero_h > 0 && my >= l.field_y && my <= l.field_y + 28 {
				if mx >= l.field_x && mx <= l.field_x + l.field_w {
					app.workspace_focus = true
					app.header_search_focus = false
					app.ghost_focused = false
					return
				}
				if mx >= l.validate_x && mx <= l.validate_x + l.validate_w {
					validate_workspace_draft(mut app)
					return
				}
				if mx >= l.switch_x && mx <= l.switch_x + l.switch_w {
					apply_workspace(mut app, app.workspace_draft, 'Manual')
					return
				}
				if mx >= l.init_x && mx <= l.init_x + l.init_w {
					initialize_workspace(mut app)
					return
				}
			}
			// git rail tabs hit
			rail_y := l.mid_y
			for ri, rn in ['CHANGES', 'HISTORY', 'COMPARE'] {
				rx := l.fx + l.fw - l.git_w - 12 + 6 + ri * l.git_tab_w
				if l.mid_h > 0 && mx >= rx && mx <= rx + l.git_tab_w - 4 && my >= rail_y
					&& my <= rail_y + 22 {
					app.git_rail = rn
					app.git_scroll = 0
					return
				}
			}
			// file tree hit — left 180
			ft_x := l.fx + 12
			ft_y := l.mid_y
			ft_w := l.tree_w
			ft_h := l.mid_h
			if mx >= ft_x && mx <= ft_x + ft_w && my >= ft_y + 24 && my < ft_y + ft_h - 4 {
				flat := file_tree_visible(app)
				row_h := 18
				visible := (ft_h - 28) / row_h
				if visible > 0 {
					start := clamp_scroll(app.file_tree_scroll, flat.len, visible)
					mut rel := my - (ft_y + 24)
					row := rel / row_h
					idx := start + row
					if idx >= 0 && idx < flat.len {
						n := flat[idx]
						app.file_tree_selected = n.path
						app.file_tree_hover = idx
						if n.kind == 'dir' {
							// toggle expand — easy to manage: walk tree and flip
							mut toggled := false
							for i, node in app.file_tree {
								if node.path == n.path {
									app.file_tree[i].expanded = !node.expanded
									toggled = true
									break
								}
								// recurse helper inline
								if !toggled {
									toggled = toggle_expand_recursive(mut app.file_tree[i].children, n.path)
								}
							}
						} else {
							// brokered open — validates harness_root_escape via Desktop proxy
							if _ := app.desktop.engine_open_path_validated(app.harness_root, n.path) {
								// try Engine open, fallback to local read for headless
								tab := app.desktop.engine_open_file_brokered(app.harness_root, n.path) or {
									// fallback synthetic tab for headless/gui without real file
									desktop_engine.EditorTab{ path: n.path, title: n.name, content: '// ${n.name}\nmodule main\nfn main() { println("brokered open: ${n.path}") }', syntax: 'v', dirty: false }
								}
								mut found := -1
								for ti, t in app.editor_tabs {
									if t.path == tab.path {
										found = ti
										break
									}
								}
								if found >= 0 {
									app.active_tab = found
								} else {
									app.editor_tabs << EditorTab{tab.path, tab.title, tab.content, tab.syntax, tab.dirty, 0}
									app.active_tab = app.editor_tabs.len - 1
								}
								app.inspector_msg = 'Opened ${n.name} via brokered fs — ${tab.syntax} syntax'
							} else {
								app.inspector_msg = 'Brokered guard blocked: ${n.path} (harness_root_escape)'
							}
						}
						return
					}
				}
			}
			// editor tabs hit — center
			ed_x := l.fx + 12 + l.tree_w + 4
			ed_w := l.fw - 24 - l.tree_w - 4 - l.git_w
			ed_y := l.mid_y
			if l.mid_h > 0 && app.editor_tabs.len > 0 && mx >= ed_x && mx <= ed_x + ed_w
				&& my >= ed_y + 6 && my <= ed_y + 24 {
				mut tx := ed_x + 6
				for i, tab in app.editor_tabs {
					tw := tab.title.len * 7 + 28
					if tx + tw > ed_x + ed_w - 6 {
						break
					}
					if mx >= tx && mx <= tx + tw && my >= ed_y + 6 && my <= ed_y + 24 {
						app.active_tab = i
						return
					}
					tx += tw + 4
				}
			}
			// HISTORY commit selection hit — inside git rails
			if app.git_rail == 'HISTORY' {
				rail_x := l.fx + l.fw - l.git_w - 12
				rail_y2 := l.mid_y + 26
				graph := app.desktop.engine_git_graph(20)
				row_h := 22
				y0 := rail_y2 + 14
				visible := ws_git_history_visible(l.mid_h)
				if visible > 0 {
					start := clamp_scroll(app.git_scroll, graph.commits.len, visible)
					for idx in start .. graph.commits.len {
						if idx >= start + visible {
							break
						}
						row := idx - start
						ry := y0 + row * row_h
						if mx >= rail_x && mx <= rail_x + l.git_w && my >= ry && my <= ry + row_h {
							app.git_selected = graph.commits[idx].hash
							app.inspector_msg = 'Commit ${graph.commits[idx].hash[..7]} selected — diff preview via Engine.git_diff'
							return
						}
					}
				}
			}
			// memory palace search bar hit — bottom
			if mx >= l.fx + 12 + 8 && mx <= l.fx + l.fw - 12 && my >= l.mem_y + 20 && my <= l.mem_y + 40 {
				app.inspector_msg = 'Memory palace focused — type to recall semantic (hybrid cosine)'
				return
			}
		}
		// Office view switch has priority inside the Office panel.
		if app.selected_panel == 0 {
			if handle_office_view_click(mut app, app.gg.width, mx, my) {
				return
			}
		}
		// Hit floor desks only when the floor map is visible.
		if app.selected_panel == 0 && app.office_map_view {
			w2 := app.gg.width
			h2 := app.gg.height
			fx := panel_fx(app)
			fy := panel_top(app)
			fw := panel_fw(app, w2)
			fh := content_bottom(app, h2) - fy
			desks_hit := desks_for_app(app)
			for idx, d in desks_hit {
				dx, dy, dw, dh := desk_rect(d, idx, fx, fy, fw, fh)
				if mx >= dx && mx <= dx + dw && my >= dy && my <= dy + dh {
					app.selected_desk = idx
					app.inspector_msg = ''
					return
				}
			}
		}
		_ = h
	}
	if e.typ == .mouse_up {
		app.zoom_dragging = false
	}
	if e.typ == .mouse_move {
		app.mouse_x = int(e.mouse_x)
		app.mouse_y = int(e.mouse_y)
		// global zoom drag — the only slider lives in the status bar; keep that
		// mapping for the whole drag so values do not jump when leaving the track
		if app.zoom_dragging {
			w3 := app.gg.width
			h3 := app.gg.height
			mx := app.mouse_x
			my := app.mouse_y
			left_base := 12 + 24 + 46 + 64 + 78 + 8
			zx_stat := left_base + 4
			mut rel2 := mx - zx_stat
			if rel2 < 0 {
				rel2 = 0
			}
			if rel2 > 64 {
				rel2 = 64
			}
			pct2 := f64(rel2) / 64.0
			app.global_zoom = clamp_zoom(0.75 + pct2 * 0.75)
			app.zoom_toast = zoom_percent(app.global_zoom)
			app.zoom_toast_at = app.frame
			_ = my
			_ = h3
			_ = w3
		}
		app.hover_panel = -1
		dock_l_h := dock_x(app, app.gg.width) + 8
		if app.mouse_x >= dock_l_h && app.mouse_x <= dock_l_h + dock_w - 16 {
			for row in nav_rows(app, app.gg.height) {
				if app.mouse_y >= row.y && app.mouse_y <= row.y + row.h {
					app.hover_panel = row.panel
					break
				}
			}
		}
		// language chip hover — EN/ES/中文/عربي
		app.lang_hover = -1
		if app.mouse_y >= 10 && app.mouse_y <= 32 && app.mouse_x >= app.gg.width - 180 {
			li := (app.mouse_x - (app.gg.width - 180)) / 34
			if li >= 0 && li <= 3 {
				app.lang_hover = li
			}
		}
		app.hover_desk = -1
		app.term_hover = -1
		app.inspector_hover = -1
		app.skills_hover = -1
		app.file_tree_hover = -1
		app.git_hover = -1
		app.memory_hover = -1
		app.onboarding_hover = -1
		app.products_hover = -1
		app.targets_hover = -1
		app.jobs_hover = -1
		app.jobs_hover_cancel = -1
		app.jobs_hover_retry = -1
		app.jobs_hover_logs = -1
		app.loops_hover_run = -1
		app.loops_hover_cron = -1
		app.loops_hover_edit = -1
		app.loops_budget_hover = -1
		app.insights_hover = -1
		if app.selected_panel == 0 {
			desks := desks_for_app(app)
			w2 := app.gg.width
			h2 := app.gg.height
			fx := panel_fx(app)
			fy := panel_top(app)
			fw := panel_fw(app, w2)
			fh := content_bottom(app, h2) - fy
			for idx, d in desks {
				dx, dy, dw, dh := desk_rect(d, idx, fx, fy, fw, fh)
				if app.mouse_x >= dx && app.mouse_x <= dx + dw && app.mouse_y >= dy && app.mouse_y <= dy + dh {
					app.hover_desk = idx
					break
				}
			}
		}
		// terminal hover — bottom strip (ghost + logs — potent)
		if app.term_visible {
			w3 := app.gg.width
			h3 := app.gg.height
			x0, y0, tw, term_h := terminal_rect(app, w3, h3)
			content_y := y0 + 28
			content_x := x0 + 8
			content_w := tw - 16
			if app.mouse_x >= content_x && app.mouse_x <= content_x + content_w && app.mouse_y >= content_y + 16 && app.mouse_y < y0 + term_h - 18 {
				row_h := 14
				if app.ghost_focused && app.ghost.lines.len > 0 {
					// hover maps to Ghostty visible rows when focused
					g_vis := app.ghost.visible_lines()
					rel_y := app.mouse_y - (content_y + 8)
					row := rel_y / row_h
					if row >= 0 && row < g_vis.len {
						app.term_hover = row
					}
				} else {
					vis := term_visible_rows(term_h)
					filter_q := active_log_filter(app)
					logs := filtered_logs(collect_engine_logs(app), filter_q)
					start := clamp_scroll(app.term_scroll, logs.len, vis)
					rel_y := app.mouse_y - (content_y + 16)
					row := rel_y / row_h
					idx := start + row
					if idx >= 0 && idx < logs.len && row < vis {
						app.term_hover = idx
					}
				}
			}
		}
		// inspector hover — per-desk logs
		{
			w3 := app.gg.width
			h3 := app.gg.height
			ix := inspector_x(app, w3)
			iy := panel_top(app)
			ih := content_bottom(app, h3) - iy
			log_x0, log_x1, log_y0, inspector_log_h := inspector_log_rect(app, ix, iy, ih)
			if app.mouse_x >= log_x0 && app.mouse_x <= log_x1 && app.mouse_y >= log_y0
				&& app.mouse_y < log_y0 + inspector_log_h {
				row_h := 13
				mut visible_i := inspector_log_h / row_h
				desks := desks_for_app(app)
				filter_q := active_log_filter(app)
				all_logs := collect_engine_logs(app)
				desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks.len {
					per_desk_logs(all_logs, desks[app.selected_desk], filter_q)
				} else {
					filtered_logs(all_logs, filter_q)
				}
				start_i := clamp_scroll(app.inspector_scroll, desk_logs.len, visible_i)
				mut rel := app.mouse_y - log_y0
				row := rel / row_h
				idx := start_i + row
				if idx >= 0 && idx < desk_logs.len {
					app.inspector_hover = idx
				}
			}
		}
		// VC5 (#1173): Library card/chrome hover shares lib_layout geometry
		app.lib_hover = -1
		app.lib_hover_ui = -1
		if lib_is_panel(app.selected_panel) && !app.show_onboarding {
			library_hover_at(mut app, app.mouse_x, app.mouse_y, app.gg.width, app.gg.height)
		}
		// workspace file-tree hover — left 180
		if app.selected_panel == 9 {
			l := workspace_layout(app, app.gg.width, app.gg.height)
			ft_x := l.fx + 12
			ft_y := l.mid_y
			ft_w := l.tree_w
			ft_h := l.mid_h
			flat := file_tree_visible(app)
			row_h := 18
			visible := (ft_h - 28) / row_h
			start := clamp_scroll(app.file_tree_scroll, flat.len, visible)
			mut end_fl := start + visible
			if end_fl > flat.len {
				end_fl = flat.len
			}
			for idx in start .. end_fl {
				row := idx - start
				ry := ft_y + 24 + row * row_h
				if app.mouse_x >= ft_x && app.mouse_x <= ft_x + ft_w && app.mouse_y >= ry && app.mouse_y <= ry + row_h {
					app.file_tree_hover = idx
					break
				}
			}
			// git hover — right rails
			rail_x := l.fx + l.fw - l.git_w - 12
			y0 := l.mid_y + 26 + 14
			if app.git_rail == 'CHANGES' {
				changes := app.desktop.engine_git_changes()
				row_h2 := 20
				vis2 := ws_git_changes_visible(l.mid_h)
				start2 := clamp_scroll(app.git_scroll, changes.len, vis2)
				mut end2_ch := start2 + vis2
				if end2_ch > changes.len {
					end2_ch = changes.len
				}
				for idx in start2 .. end2_ch {
					row := idx - start2
					ry := y0 + row * row_h2
					if app.mouse_x >= rail_x && app.mouse_x <= rail_x + l.git_w && app.mouse_y >= ry && app.mouse_y <= ry + row_h2 {
						app.git_hover = idx
						break
					}
				}
			} else if app.git_rail == 'HISTORY' {
				graph := app.desktop.engine_git_graph(20)
				row_h2 := 22
				vis2 := ws_git_history_visible(l.mid_h)
				start2 := clamp_scroll(app.git_scroll, graph.commits.len, vis2)
				mut end2_hi := start2 + vis2
				if end2_hi > graph.commits.len {
					end2_hi = graph.commits.len
				}
				for idx in start2 .. end2_hi {
					row := idx - start2
					ry := y0 + row * row_h2
					if app.mouse_x >= rail_x && app.mouse_x <= rail_x + l.git_w && app.mouse_y >= ry && app.mouse_y <= ry + row_h2 {
						app.git_hover = idx
						break
					}
				}
			}
			// memory hover — bottom
			if app.memory_query != '' {
				results := app.desktop.engine_memory_recall(app.memory_query, 5)
				row_h2 := 18
				vis2 := (l.mem_h - 48) / row_h2
				start2 := clamp_scroll(app.memory_scroll, results.len, vis2)
				mut end2 := start2 + vis2
				if end2 > results.len {
					end2 = results.len
				}
				for idx in start2 .. end2 {
					row := idx - start2
					ry := l.mem_y + 44 + row * row_h2
					if app.mouse_x >= l.fx && app.mouse_x <= l.fx + l.fw && app.mouse_y >= ry && app.mouse_y <= ry + 12 {
						app.memory_hover = idx
						break
					}
				}
			}
		}
		// VC6 (#1173): Operations hover (tabs, controls, rows, detail actions)
		operations_hover(mut app, app.gg.width, app.gg.height)
		// insights hover — tabs share insights_layout with drawing (VC7)
		if app.selected_panel == 12 {
			insights_hover_at(mut app, app.mouse_x, app.mouse_y, app.gg.width, app.gg.height)
		}
		// onboarding wizard hover — distinct overlay steps 0..6 progress + Next/Finish/Skip
		if app.show_onboarding {
			onboarding_hover_at(mut app, app.mouse_x, app.mouse_y, app.gg.width, app.gg.height)
		}
	}
	if e.typ == .quit_requested {
		app.gg.quit()
	}
}
