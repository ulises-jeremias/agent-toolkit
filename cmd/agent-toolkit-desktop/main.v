module main

import desktop
import desktop_engine
import gg
import ghostty
import os
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
fn save_ui_state(app &GuiApp) {
	term_mode := if app.term_mode == 0 { 0 } else { 3 }
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
				// MAX, split, modal, and terminal focus are session-only state.
				app.term_mode = if v.int() == 0 { 0 } else { 3 }
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
fn bc2(msg string) {
	mut f := os.open_file('/tmp/opencode/bc2.log', 'ab', 0o644) or { return }
	f.writeln(msg) or {}
	f.close()
}

fn spawn_session(mut app &GuiApp, ab pty_mod.AgentBin) {
	bc2('spawn:enter ${ab.agent}')
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
	bc2('spawn:done total=${app.sessions.len}')
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

struct PaletteItem {
	id    string
	label string
	desc  string
	keys  string
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
	office_map_view  bool // optional spatial view; operational overview is the default
	hover_panel      int
	selected_desk    int
	hover_desk       int
	palette_open     bool
	palette_query    string
	palette_selected int
	mouse_x          int
	mouse_y          int
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
	targets_hover                int = -1
	onboarding_scroll            int
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
	insights_hover  int = -1
	insights_tab    string = 'cost' // cost | waterfall | spans | budgets | ci
	insights_filter string
	insights_spark  []f64
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
	'panel.world':             I18nRow{'World', 'Mundo', '世界', 'العالم'}
	'panel.skills':            I18nRow{'Skills', 'Habilidades', '技能', 'المهارات'}
	'panel.agents':            I18nRow{'Agents', 'Agentes', '代理', 'الوكلاء'}
	'panel.mcp':               I18nRow{'MCP', 'MCP', '提供方', 'المزودون'}
	'panel.targets':           I18nRow{'Targets', 'Destinos', '目标', 'الأهداف'}
	'panel.doctor':            I18nRow{'Doctor', 'Doctor', '诊断', 'الفحص'}
	'panel.jobs':              I18nRow{'Jobs', 'Trabajos', '作业', 'المهام'}
	'panel.loops':             I18nRow{'Loops', 'Bucles', '循环', 'الحلقات'}
	'panel.swarm':             I18nRow{'Swarm', 'Enjambre', '集群', 'السرب'}
	'panel.workspace':         I18nRow{'Workspace', 'Espacio', '工作区', 'المساحة'}
	'panel.products':          I18nRow{'Products', 'Productos', '产品', 'المنتجات'}
	'panel.onboarding':        I18nRow{'Onboarding', 'Inicio', '引导', 'التهيئة'}
	'panel.insights':          I18nRow{'Insights', 'Métricas', '洞察', 'الرؤى'}
	// dock — short descriptors
	'desc.world':              I18nRow{'Floor — desks, handoffs, live activity', 'Planta — escritorios y actividad', '办公区 · 工位与协作', 'الأرضية — المكاتب والنشاط'}
	'desc.skills':             I18nRow{'Skills and capabilities', 'Habilidades y capacidades', '技能与能力', 'المهارات والقدرات'}
	'desc.agents':             I18nRow{'Agents and roles', 'Agentes y roles', '代理与角色', 'الوكلاء والأدوار'}
	'desc.mcp':                I18nRow{'Providers, health and secrets', 'Proveedores, salud y claves', '提供方、健康与密钥', 'المزودون والصحة والأسرار'}
	'desc.targets':            I18nRow{'Coding tools and destinations', 'Herramientas y destinos', '编码工具与目标', 'أدوات البرمجة والوجهات'}
	'desc.doctor':             I18nRow{'Health checks + fix', 'Comprobaciones y reparación', '健康检查与修复', 'فحوصات وإصلاح'}
	'desc.jobs':               I18nRow{'Jobs & process supervisor', 'Trabajos y supervisor', '作业与进程管理', 'المهام والعمليات'}
	'desc.loops':              I18nRow{'Loops & missions — inner/outer', 'Bucles y misiones — internos/externos', '循环任务 · 内外环', 'المهام الدورية'}
	'desc.swarm':              I18nRow{'GOD mailbox, Herdr/tmux, teams', 'Buzón GOD, Herdr/tmux, equipos', 'GOD 信箱 · 集群协作', 'صندوق GOD والفرق'}
	'desc.workspace':          I18nRow{'IDE — tree, editor, git rails', 'IDE — árbol, editor, git', '工作区 IDE · 编辑器', 'مساحة عمل IDE'}
	'desc.products':           I18nRow{'Products and packs', 'Productos y paquetes', '产品与包', 'المنتجات والحزم'}
	'desc.onboarding':         I18nRow{'Wizard — workspace to products', 'Asistente — de workspace a productos', '引导向导 · 一步到位', 'معالج الإعداد'}
	'desc.insights':           I18nRow{'Cost, waterfall, spans, CI', 'Costos, cascada, spans, CI', '成本 · 瀑布 · CI', 'التكاليف والأداء'}
	// header
	'header.tagline':          I18nRow{'Paper Co. Office', 'Oficina Paper Co.', '纸业公司办公室', 'مكتب شركة الورق'}
	'header.search':           I18nRow{'Search skills, agents, files…', 'Buscar habilidades, agentes, archivos…', '搜索技能、代理和文件…', 'ابحث في المهارات والوكلاء والملفات…'}
	'header.workspace':        I18nRow{'WORKSPACE', 'ESPACIO', '工作区', 'المساحة'}
	'header.navigate':         I18nRow{'NAVIGATE', 'NAVEGAR', '导航', 'تنقل'}
	'header.live':             I18nRow{'live', 'activo', '实时', 'مباشر'}
	'header.commands':         I18nRow{'commands', 'comandos', '命令', 'أوامر'}
	'header.lang':             I18nRow{'Language', 'Idioma', '语言', 'اللغة'}
	// grouped task navigation — six permanent destinations
	'nav.group.office':        I18nRow{'Office', 'Oficina', '办公', 'المكتب'}
	'nav.group.library':       I18nRow{'Library', 'Biblioteca', '资源库', 'المكتبة'}
	'nav.group.operations':    I18nRow{'Operations', 'Operaciones', '运维', 'العمليات'}
	'nav.group.workspace':     I18nRow{'Workspace', 'Espacio', '工作区', 'المساحة'}
	'nav.group.insights':      I18nRow{'Insights', 'Métricas', '洞察', 'الرؤى'}
	'nav.group.settings':      I18nRow{'Settings', 'Ajustes', '设置', 'الإعدادات'}
	'nav.health':              I18nRow{'Health', 'Salud', '健康', 'الصحة'}
	'nav.setup':               I18nRow{'Setup', 'Configurar', '设置', 'الإعداد'}
	'ws.ready':                I18nRow{'ready', 'listo', '就绪', 'جاهز'}
	'ws.setup_needed':         I18nRow{'setup needed', 'falta configurar', '需要设置', 'يحتاج إعداد'}
	// status bar
	'status.palette':          I18nRow{'palette', 'paleta', '命令面板', 'الأوامر'}
	'status.paperco':          I18nRow{'Paper Co.', 'Paper Co.', '纸业公司', 'شركة الورق'}
	'status.fps':              I18nRow{'60FPS', '60FPS', '60帧', '٦٠ إطار'}
	// world floor
	'world.title':             I18nRow{'Office Floor', 'Planta de oficina', '办公区平面', 'أرضية المكتب'}
	'world.subtitle':          I18nRow{'desks • envelopes are handoffs • click a desk or use arrow keys', 'escritorios • los sobres son entregas • clica un escritorio o usa flechas', '工位 • 信封即交接 • 点击工位或方向键', 'المكاتب • الأظرف تسليمات • انقر مكتباً أو استخدم الأسهم'}
	'world.working':           I18nRow{'working', 'trabajando', '工作中', 'يعمل'}
	'world.idle':              I18nRow{'idle', 'libre', '空闲', 'خامل'}
	'world.blocked':           I18nRow{'blocked', 'bloqueado', '受阻', 'معطل'}
	'world.god':               I18nRow{'GOD — in', 'GOD — entra', 'GOD — 收', 'GOD — دخول'}
	'world.out':               I18nRow{'out', 'sale', '发', 'خروج'}
	// generic actions
	'act.open_terminal':       I18nRow{'Open terminal', 'Abrir terminal', '打开终端', 'افتح الطرفية'}
	'act.route':               I18nRow{'Route handoff', 'Route entrega', '路由交接', 'وجّه التسليم'}
	'act.run':                 I18nRow{'Run', 'Ejecutar', '运行', 'شغّل'}
	'act.sched':               I18nRow{'Sched', 'Programar', '计划', 'جدول'}
	'act.install':             I18nRow{'install', 'instalar', '安装', 'ثبّت'}
	'act.remove':              I18nRow{'remove', 'quitar', '移除', 'أزل'}
	'act.cancel':              I18nRow{'Cancel', 'Cancelar', '取消', 'إلغاء'}
	'act.retry':               I18nRow{'Retry', 'Reintentar', '重试', 'أعد'}
	'act.fix_all':             I18nRow{'Fix All', 'Reparar todo', '全部修复', 'أصلح الكل'}
	'act.new_loop':            I18nRow{'+ New Loop', '+ Nuevo bucle', '+ 新循环', '+ حلقة جديدة'}
	'act.approve':             I18nRow{'Y', 'S', '准', 'نعم'}
	'act.deny':                I18nRow{'N', 'N', '驳', 'لا'}
	// palette — 33 commands, fully translated (ES/中文/عربي)
	'palette.world':           I18nRow{'Go to World', 'Ir a Mundo', '前往世界', 'اذهب إلى العالم'}
	'palette.skills':          I18nRow{'Go to Skills', 'Ir a Habilidades', '前往技能', 'اذهب إلى المهارات'}
	'palette.agents':          I18nRow{'Go to Agents', 'Ir a Agentes', '前往代理', 'اذهب إلى الوكلاء'}
	'palette.mcp':             I18nRow{'Go to MCP', 'Ir a MCP', '前往提供方', 'اذهب إلى المزودين'}
	'palette.targets':         I18nRow{'Go to Targets', 'Ir a Destinos', '前往目标', 'اذهب إلى الأهداف'}
	'palette.doctor':          I18nRow{'Go to Doctor', 'Ir a Doctor', '前往诊断', 'اذهب إلى الفحص'}
	'palette.jobs':            I18nRow{'Go to Jobs', 'Ir a Trabajos', '前往作业', 'اذهب إلى المهام'}
	'palette.loops':           I18nRow{'Go to Loops', 'Ir a Bucles', '前往循环', 'اذهب إلى الحلقات'}
	'palette.swarm':           I18nRow{'Go to Swarm', 'Ir a Enjambre', '前往集群', 'اذهب إلى السرب'}
	'palette.workspace':       I18nRow{'Go to Workspace', 'Ir a Espacio', '前往工作区', 'اذهب إلى المساحة'}
	'palette.products':        I18nRow{'Go to Products', 'Ir a Productos', '前往产品', 'اذهب إلى المنتجات'}
	'palette.onboarding':      I18nRow{'Go to Onboarding', 'Ir a Inicio', '前往引导', 'اذهب إلى التهيئة'}
	'palette.insights':        I18nRow{'Go to Insights', 'Ir a Métricas', '前往洞察', 'اذهب إلى الرؤى'}
	'palette.command_palette': I18nRow{'Command palette', 'Paleta de comandos', '命令面板', 'لوحة الأوامر'}
	'palette.serve':           I18nRow{'Start API server', 'Iniciar servidor API', '启动 API 服务', 'ابدأ خادم API'}
	'palette.doctor_fix':      I18nRow{'Run doctor --fix', 'Ejecutar doctor --fix', '运行 doctor --fix', 'شغّل doctor --fix'}
	'palette.install':         I18nRow{'Install profiles', 'Instalar perfiles', '安装配置', 'ثبّت الملفات'}
	'palette.install_full':    I18nRow{'Install — full', 'Instalar — completo', '安装 — 完整', 'تثبيت — كامل'}
	'palette.update':          I18nRow{'Update — agent-toolkit update', 'Actualizar — agent-toolkit update', '更新 — agent-toolkit update', 'تحديث — agent-toolkit update'}
	'palette.uninstall':       I18nRow{'Uninstall', 'Desinstalar', '卸载', 'إزالة التثبيت'}
	'palette.diff':            I18nRow{'Diff — target/product', 'Diff — destino/producto', '差异 — 目标/产品', 'فرق — هدف/منتج'}
	'palette.skills_sync':     I18nRow{'Skills — sync/validate', 'Habilidades — sinc/validar', '技能 — 同步/校验', 'المهارات — مزامنة/تحقق'}
	'palette.mcp_health':      I18nRow{'MCP — health/doctor', 'MCP — salud/doctor', '提供方 — 健康/诊断', 'المزودون — الصحة/الفحص'}
	'palette.loop_run':        I18nRow{'Loop — run/status/audit/cost', 'Bucle — ejecutar/estado/auditoría/costo', '循环 — 运行/状态/审计/成本', 'حلقة — تشغيل/حالة/تدقيق/تكلفة'}
	'palette.swarm_start':     I18nRow{'Swarm — start/list/approve', 'Enjambre — iniciar/listar/aprobar', '集群 — 启动/列表/批准', 'سرب — بدء/قائمة/موافقة'}
	'palette.workspace_sync':  I18nRow{'Workspace — sync/context', 'Espacio — sinc/contexto', '工作区 — 同步/上下文', 'المساحة — مزامنة/سياق'}
	'palette.memory':          I18nRow{'Memory — add/search/inject/todo', 'Memoria — añadir/buscar/inyectar/todo', '记忆 — 添加/搜索/注入/待办', 'الذاكرة — إضافة/بحث/حقن/مهام'}
	'palette.project_clone':   I18nRow{'Project — clone/list/scan', 'Proyecto — clonar/listar/escanear', '项目 — 克隆/列表/扫描', 'مشروع — استنساخ/قائمة/فحص'}
	'palette.devcompanion':    I18nRow{'DevCompanion — queue/status', 'DevCompanion — cola/estado', '开发伴侣 — 队列/状态', 'رفيق التطوير — قائمة/حالة'}
	'palette.insights_cli':    I18nRow{'Insights — CLI days/output', 'Métricas — días/salida CLI', '洞察 — 天数/输出 CLI', 'الرؤى — أيام/مخرجات CLI'}
	'palette.build':           I18nRow{'Build — --check', 'Compilar — --check', '构建 — --check', 'بناء — --check'}
	'palette.inventory':       I18nRow{'Inventory — audit', 'Inventario — auditoría', '清单 — 审计', 'الجرد — تدقيق'}
	'palette.completion':      I18nRow{'Completion — bash/zsh/fish', 'Autocompletado — bash/zsh/fish', '补全 — bash/zsh/fish', 'الإكمال — bash/zsh/fish'}
	'palette.cozy':            I18nRow{'Cozy — toggle warm wood', 'Cozy — madera cálida', '温馨 — 暖木切换', 'الدفء — خشب دافئ'}
	// palette — descriptions (nav, short)
	'pdesc.world':             I18nRow{'Office floor, desks and handoffs', 'Planta, escritorios y entregas', '办公区 · 工位与交接', 'الأرضية والمكاتب والتسليمات'}
	'pdesc.skills':            I18nRow{'Search and install skills', 'Buscar e instalar habilidades', '搜索并安装技能', 'ابحث وثبّت المهارات'}
	'pdesc.agents':            I18nRow{'Browse holistic and specialist', 'Explorar globales y especialistas', '浏览全能与专项', 'تصفح الشامل والمتخصص'}
	'pdesc.mcp':               I18nRow{'Providers and health', 'Proveedores y salud', '提供方与健康', 'المزودون والصحة'}
	'pdesc.targets':           I18nRow{'Enable platforms', 'Activar plataformas', '启用平台', 'فعّل المنصات'}
	'pdesc.doctor':            I18nRow{'Fix checks', 'Reparar comprobaciones', '修复检查', 'أصلح الفحوصات'}
	'pdesc.jobs':              I18nRow{'Live processes', 'Procesos en vivo', '实时进程', 'العمليات المباشرة'}
	'pdesc.loops':             I18nRow{'Missions and schedules — inner/outer', 'Misiones y agendas — internas/externas', '任务与计划 · 内外环', 'المهام والجداول'}
	'pdesc.swarm':             I18nRow{'GOD mailbox, Herdr/tmux, pair/team/full', 'Buzón GOD, Herdr/tmux, par/equipo/completo', 'GOD 信箱 · 集群规模', 'صندوق GOD والفرق'}
	'pdesc.workspace':         I18nRow{'Context and memory', 'Contexto y memoria', '上下文与记忆', 'السياق والذاكرة'}
	'pdesc.products':          I18nRow{'Manage products/packs membership & digest', 'Gestionar productos/paquetes y resumen', '管理产品/包与摘要', 'أدر المنتجات والحزم'}
	'pdesc.onboarding':        I18nRow{'Wizard: workspace, personas, capability, target, product', 'Asistente: workspace, personas, capacidad, destino, producto', '向导：工作区到产品', 'معالج: من المساحة إلى المنتج'}
	'pdesc.insights':          I18nRow{'Cost ledger, waterfall, spans, CI, realtime, gallery', 'Costos, cascada, spans, CI, tiempo real, galería', '成本 · 瀑布 · CI · 实时 · 图库', 'التكاليف والأداء والمعرض'}
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

fn nav_children(panel int) []int {
	return match panel {
		1 { [1, 2, 3, 4, 10] }
		6 { [6, 7, 8, 5] }
		11 { [11] }
		else { []int{} }
	}
}

// nav_rows keeps the six task-oriented destinations permanent while exposing
// implementation panels only in the relevant local group.
fn nav_rows(app &GuiApp, h int) []NavRow {
	term_h := if app.term_visible { app.term_height } else { 0 }
	bottom := h - 28 - term_h - 12
	active_group := nav_group_for_panel(app.selected_panel)
	mut rows := []NavRow{}
	mut y := 58
	for group in [0, 1, 6, 9, 12, 11] {
		if y + 36 > bottom {
			break
		}
		rows << NavRow{ panel: group, y: y, h: 36, parent: true }
		y += 40
		if group != active_group {
			continue
		}
		for child in nav_children(group) {
			if y + 28 > bottom {
				break
			}
			rows << NavRow{ panel: child, y: y, h: 28, parent: false }
			y += 30
		}
	}
	return rows
}

// ── RTL geometry — when عربي is active the filing-cabinet flips: dock right,
// inspector left, panels between. LTR default unchanged. ──
const dock_w = 200
const inspector_w = 300

fn dock_x(app &GuiApp, w int) int {
	return if app.lang.is_rtl() { w - dock_w } else { 0 }
}

fn inspector_x(app &GuiApp, w int) int {
	return if app.lang.is_rtl() { 0 } else { w - inspector_w }
}

fn panel_fx(app &GuiApp) int {
	return if app.lang.is_rtl() { inspector_w + 8 } else { dock_w + 8 }
}

fn panel_fw(app &GuiApp, w int) int {
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

fn palette_items() []PaletteItem {
	return [
		PaletteItem{'world', 'Go to World', 'Office floor, desks and handoffs', '1'},
		PaletteItem{'skills', 'Go to Skills', 'Search and install skills', '2'},
		PaletteItem{'agents', 'Go to Agents', 'Browse holistic and specialist', '3'},
		PaletteItem{'mcp', 'Go to MCP', 'Providers and health', '4'},
		PaletteItem{'targets', 'Go to Targets', 'Enable platforms', '5'},
		PaletteItem{'doctor', 'Go to Doctor', 'Fix checks', '6'},
		PaletteItem{'jobs', 'Go to Jobs', 'Live processes', '7'},
		PaletteItem{'loops', 'Go to Loops', 'Missions and schedules — inner/outer', '8'},
		PaletteItem{'swarm', 'Go to Swarm', 'GOD mailbox, Herdr/tmux, pair/team/full, approvals spend/scope/destructive', '9'},
		PaletteItem{'workspace', 'Go to Workspace', 'Context and memory', '0'},
		PaletteItem{'products', 'Go to Products', 'Manage products/packs membership & digest', 'p'},
		PaletteItem{'onboarding', 'Go to Onboarding', 'Super-potent wizard: workspace, personas, capability, target, product', 'o'},
		PaletteItem{'insights', 'Go to Insights', 'Telemetry — cost ledger, tool waterfall, OTel spans, budgets spark, CI watcher', 'i'},
		PaletteItem{'command_palette', 'Command palette', 'Fuzzy search ( / ) — todo administrable', '/'},
		PaletteItem{'serve', 'Start API server', 'agent-toolkit serve --port 3847', 's'},
		PaletteItem{'doctor_fix', 'Run doctor --fix', 'Repair missing profiles', 'd'},
		PaletteItem{'install', 'Install profiles', 'agent-toolkit install --dry-run', 'i'},
		// —— CLI absoluto — todo administrable desde GUI (palette + terminal) ——
		PaletteItem{'install_full', 'Install — full', 'agent-toolkit install --tools claude-code,cursor --force', 'install'},
		PaletteItem{'update', 'Update — agent-toolkit update', 'Update --check --pin', 'update'},
		PaletteItem{'uninstall', 'Uninstall', 'Uninstall --dry-run --rollback', 'uninstall'},
		PaletteItem{'diff', 'Diff — target/product', 'Compare configurations', 'diff'},
		PaletteItem{'skills_sync', 'Skills — sync/validate', 'Sync and validate the catalog', 'skills_sync'},
		PaletteItem{'mcp_health', 'MCP — health/doctor', 'Health of configured providers', 'mcp_health'},
		PaletteItem{'loop_run', 'Loop — run/status/audit/cost', 'Missions heartbeat + budgets', 'loop_run'},
		PaletteItem{'swarm_start', 'Swarm — start/list/approve', 'Launch pair/team/full, approve spend/scope', 'swarm_start'},
		PaletteItem{'workspace_sync', 'Workspace — sync/context', 'Sync knowledge + context', 'workspace_sync'},
		PaletteItem{'memory', 'Memory — add/search/inject/todo', 'Palace recall + todos', 'memory'},
		PaletteItem{'project_clone', 'Project — clone/list/scan', 'Clone and scan repos', 'project_clone'},
		PaletteItem{'devcompanion', 'DevCompanion — queue/status', 'Background queue + llm-status', 'devcompanion'},
		PaletteItem{'insights_cli', 'Insights — CLI days/output', 'Telemetry ledger CLI', 'insights_cli'},
		PaletteItem{'build', 'Build — --check', 'Package plugin and catalogs', 'build'},
		PaletteItem{'inventory', 'Inventory — audit', 'List tools', 'inventory'},
		PaletteItem{'completion', 'Completion — bash/zsh/fish', 'Shell completion', 'completion'},
		PaletteItem{'cozy', 'Cozy — toggle warm wood', 'Cozy mode: warm paper + wood + FPS 62', 'c'},
		PaletteItem{'theme', 'Theme — cycle Paper/Ink/System', 'Panel appearance, persists', 't'},
	]
}

// fuzzy_score computes match score for query against candidate string.
// Returns -1 if no match, higher is better. Case-insensitive, substring and
// subsequence aware, with bonuses for consecutive and word-boundary hits.
// Pure function, no I/O, deterministic. Mirrors desktop/palette fuzzy.
fn fuzzy_score(query string, target string) int {
	if query == '' {
		return 1000
	}
	q := query.to_lower()
	t := target.to_lower()
	if t == q {
		return 10000
	}
	if t.contains(q) {
		return 9000 - t.len
	}
	mut qi := 0
	mut score := 0
	mut consecutive := 0
	mut last_match := -1
	for ti, ch in t {
		if qi < q.len && ch == q[qi] {
			score += 10
			if last_match == ti - 1 {
				score += 5
				consecutive++
			}
			if ti == 0 || t[ti - 1] == `/` || t[ti - 1] == ` ` || t[ti - 1] == `-` || t[ti - 1] == `_` || t[ti - 1] == `:` {
				score += 8
			}
			last_match = ti
			qi++
			if qi == q.len {
				break
			}
		}
	}
	if qi != q.len {
		return -1
	}
	score -= t.len / 10
	score += consecutive * 3
	return score
}

fn palette_best_score(query string, item PaletteItem) int {
	if query == '' {
		return 1000
	}
	mut best := -1
	for field in [item.label, item.id, item.desc, item.keys] {
		s := fuzzy_score(query, field)
		if s > best {
			best = s
		}
	}
	return best
}

fn filtered_palette(query string) []PaletteItem {
	items := palette_items()
	q := query.trim_space()
	if q == '' {
		return items.clone()
	}
	struct Scored {
		item  PaletteItem
		score int
	}
	mut scored := []Scored{}
	for it in items {
		s := palette_best_score(q, it)
		if s >= 0 {
			scored << Scored{
				item: it
				score: s
			}
		}
	}
	// manual sort to avoid V3 generic monomorphize segfault (see swarm_service fix)
	for i := 1; i < scored.len; i++ {
		mut j := i
		for j > 0 && (scored[j].score > scored[j - 1].score || (scored[j].score == scored[j - 1].score && scored[j].item.label < scored[j - 1].item.label)) {
			tmp := scored[j]
			scored[j] = scored[j - 1]
			scored[j - 1] = tmp
			j--
		}
	}
	mut out := []PaletteItem{}
	for e in scored {
		out << e.item
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
					'holistic'} else if roles[r][c] == 'specialist' {
					'specialist'} else {
					'runtime'}
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

fn pad2(n int) string {
	if n < 10 {
		return '0' + n.str()
	}
	return n.str()
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
	candidates := [
		os.getenv('AGENT_TOOLKIT_WORKSPACE'),
		os.getenv('HARNESS_DIR'),
		persisted,
		os.join_path(home, '.ai-workspace'),
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
		app.onboarding_msg = 'Welcome — let’s set up your workspace, coding tools, and useful capabilities (press o to toggle)'
	} else {
		app.onboarding_msg = ''
	}
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
		app.term_height = match app.term_mode {
			1 { 320 }
			2 { app.gg.height - 44 - 28 }
			else { 148 }
		}
	}
	// libghostty-vt resize to fit terminal area — potent: derive cols/rows from actual pixel area
	// 80x18 is the logical default, but bottom strip is ~148px tall → dynamic 76x8 at 1280 width.
	// Compute so window resize keeps Ghostty crisp and per-agent stays 40x6.
	mut cols_full := 80
	mut rows_full := 18
	if app.term_visible {
		tw_g := app.gg.width - 200
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
	draw_header(mut app, w)
	draw_left_dock(mut app, h)
	// MAX terminal owns the content area — skip panel + inspector rendering
	// (negative-height panels would smear texts over the chrome)
	if app.term_mode == 2 {
		draw_terminal(mut app, w, h)
		app.gg.end()
		return
	}
	match app.selected_panel {
		0 { draw_world(mut app, w, h) }
		1 { draw_skills(mut app, w, h) }
		2 { draw_agents(mut app, w, h) }
		3 { draw_mcp(mut app, w, h) }
		4 { draw_targets(mut app, w, h) }
		5 { draw_doctor(mut app, w, h) }
		6 { draw_jobs(mut app, w, h) }
		7 { draw_loops(mut app, w, h) }
		8 { draw_swarm(mut app, w, h) }
		9 { draw_workspace(mut app, w, h) }
		10 { draw_products(mut app, w, h) }
		11 { draw_onboarding(mut app, w, h) }
		12 { draw_insights(mut app, w, h) }
		else { draw_world(mut app, w, h) }
	}
	// super-potent onboarding overlay — distinct from Products catalog; easy to manage
	if app.show_onboarding && app.selected_panel != 11 {
		draw_onboarding(mut app, w, h)
	}
	draw_inspector(mut app, w, h)
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
	// center — frame + 60FPS indicator (paper dot pulses at 60FPS)
	mid := 'frame ${app.frame}  •  60FPS'
	mid_w := mid.len * 6
	app.gg.draw_text(w / 2 - mid_w / 2, h - 19, mid, gg.TextCfg{ color: col_slate_dim, size: scaled_size(11, app.global_zoom) })
	// 60FPS dot — brass pulse every 30 frames
	fps_col := if app.frame % 30 < 15 { col_brass } else { tint(col_brass, 44) }
	app.gg.draw_rect_filled(w / 2 + mid_w / 2 + 6, h - 15, 5, 5, fps_col)
	// right — appearance chip, branch, manila tab + Paper Co.
	app.gg.draw_rect_filled(w - 330, h - 22, 84, 16, col_paper_dim)
	app.gg.draw_rect_empty(w - 330, h - 22, 84, 16, col_line_light)
	app.gg.draw_text(w - 324, h - 18, 'Theme·${appearance_label(app.appearance)}', gg.TextCfg{ color: col_ink700, size: scaled_size(10, app.global_zoom), mono: true })
	app.gg.draw_rect_filled(w - 238, h - 22, 72, 16, col_paper_dim)
	app.gg.draw_rect_empty(w - 238, h - 22, 72, 16, col_line_light)
	app.gg.draw_text(w - 230, h - 18, 'main', gg.TextCfg{ color: col_ink700, size: scaled_size(10, app.global_zoom), mono: true })
	draw_text_l(mut app, w - 160, h - 19, 'status.paperco', gg.TextCfg{ color: col_slate, size: scaled_size(11, app.global_zoom), bold: true })
	app.gg.draw_text(w - 100, h - 19, '3847', gg.TextCfg{ color: col_ink500, size: scaled_size(11, app.global_zoom), mono: true })
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

fn header_workspace_x() int {
	// 216 leaves room for the title + version stamp (v1.30.0 via desktop_version).
	return 216
}

fn header_workspace_w(w int) int {
	return if w < 1100 { 180 } else { 210 }
}

fn header_search_x(w int) int {
	return header_workspace_x() + header_workspace_w(w) + 12
}

fn header_search_w(w int) int {
	mut width := w - header_search_x(w) - 206
	if width < 160 {
		width = 160
	}
	return width
}

fn nav_child_label(app &GuiApp, panel int) string {
	return match panel {
		5 { tr(app, 'nav.health') }
		11 { tr(app, 'nav.setup') }
		else { tr(app, panel_key(panel)) }
	}
}

fn draw_header(mut app GuiApp, w int) {
	z := app.global_zoom
	app.gg.draw_rect_filled(0, 0, w, 44, col_charcoal)
	app.gg.draw_rect_filled(0, 43, w, 1, col_line)
	app.gg.draw_text(16, 12, 'Agent Toolkit', gg.TextCfg{
		color: col_paper
		size: scaled_size(font_display_md, z)
		family: app.fonts.display
	})
	// version stamp — single source of truth via desktop_version() (repo VERSION
	// at build, installed VERSION sibling, -d commit fallback for dev builds).
	app.gg.draw_text(148, 15, 'v${app.version}', gg.TextCfg{
		color: col_slate_dim
		size: scaled_size(12, z)
		bold: true
	})
	app.gg.draw_rect_filled(8, 10, 3, 3, col_brass)

	wx := header_workspace_x()
	ww := header_workspace_w(w)
	workspace_bg := if app.workspace_focus { col_ink700 } else { col_charcoal2 }
	workspace_border := if app.workspace_focus { col_brass } else { col_line }
	app.gg.draw_rect_filled(wx, 6, ww, 32, workspace_bg)
	app.gg.draw_rect_empty(wx, 6, ww, 32, workspace_border)
	app.gg.draw_text(wx, 9, tr(app, 'header.workspace'), gg.TextCfg{ color: col_brass, size: scaled_size(10, z), bold: true })
	app.gg.draw_text(wx + 8, 22, workspace_path_label(app.harness_root, 24), gg.TextCfg{
		color: col_paper
		size: scaled_size(12, z)
		mono: true
	})
	app.gg.draw_text(wx + ww - 16, 16, 'v', gg.TextCfg{ color: col_slate_dim, size: scaled_size(12, z), bold: true })

	sx_search := header_search_x(w)
	sw_search := header_search_w(w)
	search_txt := if app.global_search == '' {
		tr_count(mut app, 'header.search', skills_total(mut app))
	} else {
		app.global_search
	}
	search_bg := if app.header_search_focus { col_cream100 } else { col_paper }
	search_bd := if app.header_search_focus { col_brass } else { col_line_light }
	app.gg.draw_rect_filled(sx_search, 8, sw_search, 28, search_bg)
	app.gg.draw_rect_empty(sx_search, 8, sw_search, 28, search_bd)
	draw_search_lens(mut app, sx_search + 10, 17)
	app.gg.draw_text(sx_search + 26, 16, search_txt, gg.TextCfg{
		color: if app.global_search == '' { col_ink_soft } else { col_ink }
		size: scaled_size(12, z)
		family: if app.global_search == '' { family_for(app, search_txt) } else { '' }
	})
	if app.header_search_focus && app.global_search != '' && app.frame % 30 < 15 {
		cursor_x := sx_search + 26 + app.global_search.len * 7
		if cursor_x < sx_search + sw_search - 18 {
			app.gg.draw_rect_filled(cursor_x, 16, 2, 14, col_brass)
		}
	}
	if app.global_search != '' {
		app.gg.draw_text(sx_search + sw_search - 16, 16, 'x', gg.TextCfg{ color: col_ink_soft, size: scaled_size(12, z), bold: true })
	}

	lx := w - 180
	for li, l in [Lang.en, Lang.es, Lang.zh, Lang.ar] {
		active := app.lang == l
		label := l.chip()
		chx := lx + li * 34
		app.gg.draw_rect_filled(chx, 10, 30, 22, if active { col_brass } else { col_charcoal2 })
		app.gg.draw_rect_empty(chx, 10, 30, 22, if active { col_brass } else { col_line })
		fam := if li == 2 {
			app.fonts.sc
		} else if li == 3 { app.fonts.arabic } else { '' }
		app.gg.draw_text(chx + 6, 15, label, gg.TextCfg{
			color: if active { col_ink } else { col_slate_dim }
			size: 11
			bold: active
			family: fam
		})
	}
	cmd_x := w - 42
	app.gg.draw_rect_filled(cmd_x, 8, 30, 28, col_ink700)
	app.gg.draw_rect_empty(cmd_x, 8, 30, 28, col_line_light)
	app.gg.draw_text(cmd_x + 10, 15, '/', gg.TextCfg{ color: col_brass, size: scaled_size(14, z), bold: true })
}

fn draw_left_dock(mut app GuiApp, h int) {
	term_h := if app.term_visible { app.term_height } else { 0 }
	y0 := 45
	dock_l := dock_x(app, app.gg.width)
	app.gg.draw_rect_filled(dock_l, y0, dock_w, h - y0 - 28 - term_h, col_charcoal)
	app.gg.draw_line(dock_l + dock_w, y0, dock_l + dock_w, h - 28 - term_h, col_line)
	app.gg.draw_text(dock_l + 16, y0 + 10, tr(app, 'header.navigate'), gg.TextCfg{ color: col_brass, size: 11, bold: true })
	for row in nav_rows(app, h) {
		row_x := dock_l + 8
		group_active := nav_group_for_panel(app.selected_panel) == row.panel
		active := if row.parent { group_active } else { app.selected_panel == row.panel }
		hover := app.hover_panel == row.panel
		if active {
			app.gg.draw_rect_filled(row_x, row.y, dock_w - 16, row.h, col_ink700)
			app.gg.draw_rect_empty(row_x, row.y, dock_w - 16, row.h, col_brass)
			rail_x := if app.lang.is_rtl() { row_x + dock_w - 19 } else { row_x }
			app.gg.draw_rect_filled(rail_x, row.y, 3, row.h, col_brass)
		} else if hover {
			app.gg.draw_rect_filled(row_x, row.y, dock_w - 16, row.h, col_charcoal2)
		}
		label := if row.parent {
			nav_group_label(app, row.panel)
		} else {
			nav_child_label(app, row.panel)
		}
		label_x := if row.parent { row_x + 38 } else { row_x + 48 }
		if row.parent {
			app.gg.draw_rect_filled(row_x + 14, row.y + 14, 8, 8, if active {
				col_brass
			} else {
				col_slate
			})
		}
		app.gg.draw_text(label_x, row.y + if row.parent { 10 } else { 7 }, label, gg.TextCfg{
			color: if active { col_paper } else { col_paper_dim }
			size: if row.parent { 14 } else { 13 }
			bold: active || row.parent
		})
	}
	ready := if app.workspace_initialized {
		tr(app, 'ws.ready')
	} else {
		tr(app, 'ws.setup_needed')
	}
	app.gg.draw_text(dock_l + 16, h - 56 - term_h, workspace_path_label(app.harness_root, 22), gg.TextCfg{
		color: col_slate_dim
		size: 11
		mono: true
	})
	app.gg.draw_text(dock_l + 16, h - 42 - term_h, ready, gg.TextCfg{
		color: if app.workspace_initialized { col_mint } else { col_brass }
		size: 11
	})
}

fn draw_office_overview(mut app GuiApp, w int, h int) {
	term_h := if app.term_visible { app.term_height } else { 0 }
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	fh := h - 52 - 28 - term_h
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	app.gg.draw_rect_filled(fx, fy, fw, 42, app.pnl_card)
	app.gg.draw_text(fx + 20, fy + 11, 'Office', gg.TextCfg{ color: app.pnl_text, size: font_display_md, family: app.fonts.display })
	app.gg.draw_text(fx + 106, fy + 15, 'What needs your attention?', gg.TextCfg{ color: app.pnl_text_mut, size: font_body_sm })
	app.gg.draw_text(fx + fw - 150, fy + 15, 'Press M for floor map', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
	mut jobs := []desktop_engine.JobRecord{}
	mut agents := []desktop_engine.AgentEntry{}
	if app.desktop != unsafe { nil } {
		jobs = app.desktop.engine_jobs_catalog()
		agents = app.desktop.engine_agents_search('', '')
	}
	content_y := fy + 58
	col_w := (fw - 52) / 2
	// Attention is derived from real state. Empty means there is nothing to fix.
	pixel_panel(mut app, fx + 16, content_y, col_w, 92, 'default')
	app.gg.draw_text(fx + 30, content_y + 14, 'Needs your attention', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
	if jobs.len == 0 {
		app.gg.draw_text(fx + 30, content_y + 42, 'Nothing requires attention.', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	} else {
		app.gg.draw_text(fx + 30, content_y + 42, '${jobs.len} recorded operation(s)', gg.TextCfg{ color: app.pnl_select, size: 12, bold: true })
		app.gg.draw_text(fx + 30, content_y + 62, 'Open Operations to inspect status and recovery.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	}
	pixel_panel(mut app, fx + 28 + col_w, content_y, col_w, 92, 'default')
	app.gg.draw_text(fx + 42 + col_w, content_y + 14, 'Running now', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
	app.gg.draw_text(fx + 42 + col_w, content_y + 42, 'No agents are currently running.', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	app.gg.draw_text(fx + 42 + col_w, content_y + 62, 'Live sessions appear here when started.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	// Agent roster is useful even while idle, but status is never inferred from identity.
	list_y := content_y + 114
	pixel_panel(mut app, fx + 16, list_y, fw - 32, fh - (list_y - fy) - 18, 'default')
	app.gg.draw_text(fx + 30, list_y + 14, 'Agents', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
	app.gg.draw_text(fx + fw - 190, list_y + 15, '${agents.len} available in catalog', gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
	if agents.len == 0 {
		app.gg.draw_text(fx + 30, list_y + 48, 'No agents are available in the resolved catalog.', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	} else {
		mut x := fx + 30
		mut y := list_y + 42
		for i, agent in agents {
			if i >= 12 || y + 26 > fy + fh - 20 {
				break
			}
			app.gg.draw_rect_filled(x, y, 8, 8, app.pnl_text_mut)
			app.gg.draw_text(x + 16, y - 3, agent.id, gg.TextCfg{ color: app.pnl_text, size: 12, mono: true })
			app.gg.draw_text(x + 180, y - 3, agent.role, gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			x += 250
			if x + 220 > fx + fw - 20 {
				x = fx + 30
				y += 26
			}
		}
	}
}

fn draw_world(mut app GuiApp, w int, h int) {
	if !app.office_map_view {
		draw_office_overview(mut app, w, h)
		return
	}
	// Hero — office floor: munder checkerboard 32×32 tiles, desks as AgentCards, envelopes with GOD 4*t*(1-t) arc
	// Super-potent signature: unique floor texture (wood grain + grass tuft + terrazzo speck), avatar trails,
	// envelope floor shadows, station glow, command deck kanban/fleet/CI alt divergence — native V gg only.
	term_h_w := if app.term_visible { app.term_height } else { 0 }
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	fh := h - 52 - 28 - term_h_w
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
	app.gg.draw_text(fx + 160, fy + 16, '${desks_for_app(app).len} ${tr(app, 'world.subtitle')}', gg.TextCfg{ color: app.pnl_text_mut, size: font_body_sm })

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
	if false {
		for e in 0 .. 5 {
			a_idx := e % desks.len
			mut b_idx := (e * 7 + 3) % desks.len
			if a_idx == b_idx {
				b_idx = (b_idx + 5) % desks.len
			}
			ax := rects_x[a_idx] + 70
			ay := rects_y[a_idx] + 43
			bx := rects_x[b_idx] + 70
			by := rects_y[b_idx] + 43
			phase := (app.frame * 2 + e * 67) % 240
			progress := f32(phase) / 240.0
			if progress > 0.94 {
				continue
			}
			arc_h := f32(26)
			// GOD mailbox arc: 4*t*(1-t) * arc_h — workshop handoff law, native V only
			arc := arc_h * 4.0 * progress * (1.0 - progress)
			fx_ := f32(ax)
			fy_ := f32(ay)
			tx_ := f32(bx)
			ty_ := f32(by)
			xf := fx_ + (tx_ - fx_) * progress
			ground_y := fy_ + (ty_ - fy_) * progress
			yf := ground_y - arc
			x := int(xf)
			y := int(yf)
			// segmented arc line from source to envelope (brass, translucent)
			segments := 10
			for s in 0 .. segments {
				t0 := f32(s) / f32(segments) * progress
				t1 := f32(s + 1) / f32(segments) * progress
				x0 := int(fx_ + (tx_ - fx_) * t0)
				y0 := int(fy_ + (ty_ - fy_) * t0 - arc_h * 4.0 * t0 * (1.0 - t0))
				x1 := int(fx_ + (tx_ - fx_) * t1)
				y1 := int(fy_ + (ty_ - fy_) * t1 - arc_h * 4.0 * t1 * (1.0 - t1))
				alpha := u8(55 - s * 3)
				if alpha < 12 {
					continue
				}
				app.gg.draw_line(x0, y0, x1, y1, tint(app.pnl_select, alpha))
			}
			// trail ghosts behind envelope — 4 fading paper rectangles with brass shadow
			for t in 1 .. 5 {
				tp := progress - f32(t) * 0.045
				if tp < 0 {
					continue
				}
				tp_arc := arc_h * 4.0 * tp * (1.0 - tp)
				txf := fx_ + (tx_ - fx_) * tp
				tyf := fy_ + (ty_ - fy_) * tp - tp_arc
				alpha := u8(90 - t * 18)
				if alpha < 12 {
					continue
				}
				app.gg.draw_rect_filled(int(txf) + 2, int(tyf) + 2, 12, 6, tint(app.pnl_select, alpha / 2))
				app.gg.draw_rect_filled(int(txf), int(tyf), 12, 6, tint(app.pnl_bg, alpha))
			}
			// signature floor shadow ellipse under envelope — shrinks as arc rises (parabolic soft shadow)
			shadow_w := int(14 - arc / 3.2)
			sw := if shadow_w < 6 { 6 } else { shadow_w }
			shadow_alpha := u8(28 - int(arc * 0.7))
			sa := if shadow_alpha < 8 { u8(8) } else { shadow_alpha }
			ground_x := int(xf)
			shadow_y := int(ground_y) + 6
			if shadow_y > fy + 36 && shadow_y < fy + fh - 4 && ground_x > fx && ground_x < fx + fw {
				app.gg.draw_rect_filled(ground_x - sw / 2 + 4, shadow_y, sw, 3, tint(app.pnl_text, sa))
				app.gg.draw_rect_filled(ground_x - sw / 2 + 6, shadow_y + 1, sw - 4, 1, tint(app.pnl_text, sa / 2))
			}
			// main envelope — paper with brass shadow + mail glyph + envelope shadows (native gg)
			app.gg.draw_rect_filled(x + 1, y + 1, 18, 10, tint(app.pnl_text, 40))
			app.gg.draw_rect_filled(x + 2, y + 2, 16, 6, tint(app.pnl_text, 22))
			app.gg.draw_rect_filled(x - 1, y - 1, 18, 10, tint(app.pnl_select, 110))
			app.gg.draw_rect_filled(x, y, 16, 8, app.pnl_bg)
			// flap line — workshop envelope fold
			app.gg.draw_line(x, y, x + 8, y + 4, app.pnl_border_hi)
			app.gg.draw_line(x + 8, y + 4, x + 16, y, app.pnl_border_hi)
			// inner envelope shadow 1px bottom edge for depth
			app.gg.draw_line(x + 1, y + 7, x + 15, y + 7, tint(app.pnl_text, 12))
			if desks[a_idx].status == 'blocked' || desks[b_idx].status == 'blocked' {
				app.gg.draw_rect_filled(x + 12, y + 1, 3, 3, app.pnl_danger)
			}
		}
	}

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
								app.pnl_select} else {
								app.pnl_text_mut}
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
					app.pnl_text} else {
					app.pnl_bg}
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

fn skills_filtered_for_app(mut app GuiApp) []string {
	// Delegates to Engine (227) via Desktop proxy — no direct os/catalog read.
	// Use engine_skills_search for ranked fuzzy. An unavailable catalog is an
	// honest empty state; it must never be replaced with invented entries.
	cat := app.desktop.engine_skills_search(app.skills_query, app.skills_domain)
	mut out := []string{}
	for s in cat {
		out << s.id
	}
	return out
}

fn skills_filtered_entries(mut app GuiApp) []SkillEntryProxy {
	cat := app.desktop.engine_skills_search(app.skills_query, app.skills_domain)
	mut out := []SkillEntryProxy{}
	for s in cat {
		out << SkillEntryProxy{s.id, s.name, s.domain, s.description, s.stability}
	}
	return out
}

// draw_skills_search_bar is 20-line helper — easy to manage, brokered filter.
fn draw_skills_search_bar(mut app GuiApp, fx int, fy int, fw int) {
	app.gg.draw_rect_filled(fx + 12, fy + 48, fw - 24, 28, app.pnl_card)
	app.gg.draw_rect_empty(fx + 12, fy + 48, fw - 24, 28, app.pnl_border)
	mut q := app.skills_query
	if q == '' && app.palette_query != '' {
		q = app.palette_query
	}
	display := if q == '' {
		'Search ${skills_total(mut app)} skills — try "core", "figma", "github" (fuzzy)'
	} else {
		'filter: ${q}'
	}
	col := if q == '' { app.pnl_text_mut } else { app.pnl_text }
	app.gg.draw_text(fx + 20, fy + 56, display, gg.TextCfg{ color: col, size: 13, mono: q != '' })
	if q != '' {
		app.gg.draw_text(fx + fw - 130, fy + 56, '${skills_filtered_entries(mut app).len} match', gg.TextCfg{ color: app.pnl_border_hi, size: 12 })
	}
}

// draw_skills_domain_chips — 14 domains, easy to manage chips, one-liner per domain.
fn draw_skills_domain_chips(mut app GuiApp, fx int, fy int, fw int) {
	domains := ['all', 'core', 'delivery', 'design', 'forge', 'integrations', 'data', 'tooling',
		'ops', 'loops', 'quality', 'architecture', 'cloud', 'agentic-security']
	mut y := fy + 80
	x0 := fx + 12
	mut x := x0
	for d in domains {
		label := if d == 'all' { 'all ${skills_total(mut app)}' } else { d }
		active := (d == 'all' && app.skills_domain == '') || app.skills_domain == d
		bg := if active { app.pnl_select } else { app.pnl_card_sel }
		fg := if active { app.pnl_text } else { app.pnl_text_mut }
		bd := if active { app.pnl_border_hi } else { app.pnl_border }
		w := label.len * 7 + 16
		if x + w > fx + fw - 12 {
			// wrap to the next chip row — every domain stays reachable
			x = x0
			y += 22
		}
		app.gg.draw_rect_filled(x, y, w, 18, bg)
		app.gg.draw_rect_empty(x, y, w, 18, bd)
		app.gg.draw_text(x + 8, y + 4, label, gg.TextCfg{ color: fg, size: 12, bold: active })
		x += w + 6
	}
}

// draw_skills_list — virtualized, 24px rows, 60 FPS, hover + install action + receipts/provenance.
fn draw_skills_list(mut app GuiApp, fx int, fy int, fw int, fh int) {
	y0 := fy + 128
	list_h := fh - 142
	if list_h < 40 {
		return
	}
	entries := skills_filtered_entries(mut app)
	row_h := 28
	visible := list_h / row_h
	if visible < 1 {
		return
	}
	app.skills_scroll = clamp_scroll(app.skills_scroll, entries.len, visible)
	start := app.skills_scroll
	mut end := start + visible
	if end > entries.len {
		end = entries.len
	}
	// installed set for super-potent toggle + receipt/provenance indicators (Engine transaction state)
	installed := if app.desktop != unsafe { nil } {
		app.desktop.engine_skills_installed()
	} else {
		[]string{}
	}
	for idx in start .. end {
		s := entries[idx]
		row := idx - start
		y := y0 + row * row_h
		is_hover := idx == app.skills_hover
		is_sel := idx == app.skills_selected
		// installed → brass left accent + mint receipt dot; hover → charcoal2
		is_installed := s.id in installed
		bg := if is_sel {
			app.pnl_card_sel
		} else if is_hover { app.pnl_hover } else { app.pnl_card }
		bd := if is_sel {
			app.pnl_select
		} else if is_installed { app.pnl_success } else { app.pnl_border }
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 26, bg)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 26, bd)
		if is_sel {
			app.gg.draw_rect_filled(fx + 12, y, 3, 26, app.pnl_select)
		} else if is_installed {
			app.gg.draw_rect_filled(fx + 12, y, 3, 26, app.pnl_success)
		}
		// domain pill
		pill_col := match s.domain {
			'core' { app.pnl_success }
			'delivery' { app.pnl_text_mut }
			'design' { app.pnl_text_mut }
			'forge' { app.pnl_select }
			else { app.pnl_text_mut }
		}
		app.gg.draw_rect_filled(fx + 16, y + 7, 56, 12, app.pnl_bg)
		pill_dom := if s.domain.len > 9 { s.domain[..8] + '…' } else { s.domain }
		app.gg.draw_text(fx + 18, y + 8, pill_dom, gg.TextCfg{ color: pill_col, size: 10 })
		app.gg.draw_text(fx + 78, y + 4, s.id, gg.TextCfg{ color: app.pnl_text, size: 13, bold: is_sel })
		mut desc := s.description
		if desc.len > 48 {
			desc = desc[..48] + '…'
		}
		app.gg.draw_text(fx + 78, y + 15, desc, gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		// stability + provenance hint
		stab := if s.stability == 'beta' { 'beta' } else { 'stable' }
		stab_col := if stab == 'beta' { app.pnl_select } else { app.pnl_text_mut }
		app.gg.draw_text(fx + fw - 150, y + 6, stab, gg.TextCfg{ color: stab_col, size: 10 })
		// receipt indicator (provenance via Engine) + install/toggle action — one-click Engine TX
		if is_installed {
			app.gg.draw_text(fx + fw - 116, y + 6, 'receipt ✓', gg.TextCfg{ color: app.pnl_success, size: 10 })
			hover_install := is_hover
			action := 'remove'
			acol := if hover_install { app.pnl_danger } else { app.pnl_text_mut }
			app.gg.draw_text(fx + fw - 70, y + 7, action, gg.TextCfg{ color: acol, size: 13, bold: hover_install })
			if is_hover {
				app.gg.draw_rect_filled(fx + fw - 72, y + 18, 40, 2, tint(app.pnl_danger, 45))
			}
		} else {
			// provenance preview — source file via receipt (hover shows toggle → install)
			has_receipt := if app.desktop != unsafe { nil } {
				if _ := app.desktop.engine_skill_receipt(s.id) { true } else { false }
			} else {
				false
			}
			if has_receipt {
				app.gg.draw_text(fx + fw - 116, y + 6, 'provenance ✓', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
			}
			hover_install := is_hover
			install_col := if hover_install { app.pnl_select } else { app.pnl_text_mut }
			lbl := if hover_install { 'install →' } else { 'install' }
			app.gg.draw_text(fx + fw - 70, y + 7, lbl, gg.TextCfg{ color: install_col, size: 13, bold: hover_install })
			if is_hover {
				app.gg.draw_rect_filled(fx + fw - 72, y + 18, 40, 2, app.pnl_border_hi)
			}
		}
	}
	// scrollbar
	if entries.len > visible {
		mut bar_h := list_h * visible / entries.len
		if bar_h < 14 {
			bar_h = 14
		}
		bar_y := y0 + (list_h - bar_h) * start / (entries.len - visible)
		app.gg.draw_rect_filled(fx + fw - 8, y0, 3, list_h, tint(app.pnl_text, 180))
		app.gg.draw_rect_filled(fx + fw - 8, bar_y, 3, bar_h, app.pnl_border_hi)
	}
	if entries.len == 0 {
		app.gg.draw_text(fx + 20, y0 + 10, 'No skills match — try "core" or clear the filter (Esc)', gg.TextCfg{ color: app.pnl_text_mut, size: 13 })
	}
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

fn draw_skills(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	term_h_sk := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_sk
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	// engine stats — super-potent with receipts/provenance
	cat := app.desktop.engine_skills_search('', '')
	stats := app.desktop.engine_skills_stats()
	receipts := app.desktop.engine_receipts_catalog().filter(it.kind == 'skill')
	paper_letterhead(mut app, fx, fy, fw, tr(app, 'panel.skills'), 'fuzzy searchable · virtualized 60 FPS · receipts + provenance', '${cat.len} total · ${stats.installed} in · ${receipts.len} receipts')
	draw_skills_search_bar(mut app, fx, fy, fw)
	draw_skills_domain_chips(mut app, fx, fy, fw)
	draw_skills_list(mut app, fx, fy, fw, fh)
	// super-potent footer: domain facets + origin
	doms := app.desktop.engine_skills_domains()
	app.gg.draw_text(fx + 14, fy + fh - 16, 'Source: catalogs/skill-catalog.yaml (116) → ${skills_total(mut app)} · ${doms.len} domains · click row to install/toggle · receipts ${receipts.len} · / to palette', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
}

fn draw_agents(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	term_h_ag := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_ag
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	// super-potent header with stats + provenance (R2 product-truth: tier
	// breakdown via helper so the header can never drift from the catalog).
	paper_letterhead(mut app, fx, fy, fw, tr(app, 'panel.agents'), agents_tier_summary(mut app), 'search + tier filter · receipts via Engine')
	mut agents := app.desktop.engine_agents_search(app.skills_query, '')
	if agents.len == 0 {
		agents = [
			desktop_engine.AgentEntry{ id: 'assistant', role: 'Orchestrator', tier: 'orchestrator', description: 'assistant' },
			desktop_engine.AgentEntry{ id: 'planner', role: 'Orchestrator', tier: 'orchestrator', description: 'planner' },
		]
	}
	// fill the column from Engine search (super-potent)
	mut show := agents.clone()
	mut max_show := (fh - 70) / 34
	if max_show < 4 {
		max_show = 4
	}
	if show.len > max_show {
		show = show[..max_show]
	}
	for i, ag in show {
		y := fy + 56 + i * 34
		if y + 30 > fy + fh - 12 {
			break
		}
		is_sel := show.len > 0 && app.selected_desk >= 0 && i == app.selected_desk % show.len
		bg := if is_sel { app.pnl_card_sel } else { app.pnl_card }
		bd := if is_sel { app.pnl_select } else { app.pnl_border }
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 30, bg)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 30, bd)
		if is_sel {
			app.gg.draw_rect_filled(fx + 12, y, 3, 30, app.pnl_select)
		}
		app.gg.draw_text(fx + 24, y + 8, ag.id, gg.TextCfg{
			color: app.pnl_text
			size: 14
			family: app.fonts.display
		})
		app.gg.draw_text(fx + 24 + ag.id.len * 10 + 10, y + 10, ag.role, gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		// delegates → provenance (truncated to the badge column)
		trig_limit := if ag.triggers.len > 24 { 24 } else { ag.triggers.len }
		mut deleg := if ag.delegates_to.len > 0 {
			'→ ' + ag.delegates_to.join(',')
		} else {
			ag.triggers[..trig_limit]
		}
		if deleg.len > 34 {
			deleg = deleg[..34] + '…'
		}
		app.gg.draw_text(fx + fw - 250, y + 10, deleg, gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
		// tier badge — manila chip
		tier_col := match ag.tier {
			'orchestrator' { app.pnl_border_hi }
			'specialist' { app.pnl_danger }
			else { app.pnl_success }
		}
		app.gg.draw_rect_filled(fx + fw - 96, y + 7, 76, 16, app.pnl_bg)
		app.gg.draw_rect_empty(fx + fw - 96, y + 7, 76, 16, tier_col)
		app.gg.draw_text(fx + fw - 90, y + 10, ag.tier, gg.TextCfg{ color: tier_col, size: 10, bold: true })
	}
	app.gg.draw_text(fx + 20, fy + fh - 14, 'Provenance: agents/<id>/AGENT.md → catalogs/agent-catalog.yaml · delegation graph via assistant · / to palette', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
}

// mcp_drawer_geom is the single source for the provider drawer geometry —
// render and hit-testing must stay identical (#1106).
fn mcp_drawer_geom(fx int, fy int, fw int) (int, int, int, int) {
	pw := if fw - 120 > 360 { fw - 120 } else { 360 }
	return fx + 60, fy + 96, pw, 296
}

// mcp_probe_fresh reports whether the cached probe result still counts (60s).
fn mcp_probe_fresh(app &GuiApp, id string) bool {
	return app.mcp_probe_id == id && app.frame - app.mcp_probe_at < 3600
}

// mcp_run_probe executes the typed Engine probe and caches the display (#1106).
fn mcp_run_probe(mut app GuiApp, id string) {
	res := app.desktop.engine_mcp_probe(id) or {
		app.mcp_probe_id = id
		app.mcp_probe_ok = false
		app.mcp_probe_detail = err.msg()
		app.mcp_probe_at = app.frame
		app.inspector_msg = 'MCP ${id} probe failed: ${err}'
		return
	}
	app.mcp_probe_id = id
	app.mcp_probe_ok = res.healthy
	app.mcp_probe_detail = res.detail
	app.mcp_probe_at = app.frame
	app.api_calls = app.desktop.engine_api_calls()
	app.inspector_msg = 'MCP ${id} probe: ${res.detail}'
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
	if !mcp_probe_fresh(app, id) {
		mcp_run_probe(mut app, id)
	}
	app.inspector_msg = 'MCP ${id} drawer — masked preview · probe cached 60s'
}

// mcp_open_template routes to the Workspace panel with the template loaded
// through the Engine's brokered filesystem boundary.
fn mcp_open_template(mut app GuiApp, id string, template_path string) {
	title := '${id}.json'
	if _ := app.desktop.engine_open_path_validated(app.harness_root, template_path) {
		tab := app.desktop.engine_open_file_brokered(app.harness_root, template_path) or {
			app.inspector_msg = 'Unable to open ${title}: ${err.msg()}'
			return
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
		app.inspector_msg = 'Cannot open ${title}: brokered path validation blocked it'
	}
	select_panel(mut app, 9)
}

fn draw_mcp(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	term_h_mcp := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_mcp
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	stats := app.desktop.engine_mcp_stats()
	paper_letterhead(mut app, fx, fy, fw, tr(app, 'panel.mcp'), '${stats.healthy} healthy · ${stats.enabled} enabled · ${stats.unconfigured} unconfigured · secret guard', 'mcp/templates/<id>.json')
	// search bar — Brokered via Engine.mcp_catalog_search (fuzzy) — super potent easy management
	search_q := app.skills_query
	app.gg.draw_rect_filled(fx + 12, fy + 48, fw - 24, 26, app.pnl_card)
	app.gg.draw_rect_empty(fx + 12, fy + 48, fw - 24, 26, app.pnl_border)
	q_label := if app.selected_panel == 3 && search_q != '' {
		'filter: ${search_q}'
	} else {
		'Search MCP — try "github", "slack" (fuzzy)'
	}
	q_col := if search_q != '' && app.selected_panel == 3 {
		app.pnl_border_hi
	} else {
		app.pnl_text_mut
	}
	app.gg.draw_text(fx + 22, fy + 55, q_label, gg.TextCfg{ color: q_col, size: 12 })
	// filtered via Engine search (or all when empty)
	mut provs := if app.selected_panel == 3 && search_q != '' {
		app.desktop.engine_mcp_search(search_q)
	} else {
		app.desktop.engine_mcp_catalog()
	}
	if provs.len == 0 {
		app.gg.draw_text(fx + 20, fy + 96, 'No MCP providers are available.', gg.TextCfg{ color: app.pnl_text_mut, size: 13 })
	}
	mut y0 := fy + 84
	for i, p in provs {
		if i >= 7 {
			break
		}
		y := y0 + i * 28
		bg := if p.enabled { app.pnl_card_sel } else { app.pnl_card }
		bd := if p.enabled { app.pnl_success } else { app.pnl_border }
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 28, bg)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 28, bd)
		if p.enabled {
			app.gg.draw_rect_filled(fx + 12, y, 3, 28, app.pnl_success)
		}
		app.gg.draw_text(fx + 24, y + 7, p.id, gg.TextCfg{
			color: app.pnl_text
			size: 14
			family: app.fonts.display
		})
		// failed fresh probe replaces the name slot with the error detail (#1106)
		if mcp_probe_fresh(app, p.id) && !app.mcp_probe_ok {
			det := if app.mcp_probe_detail.len > 52 {
				app.mcp_probe_detail[..52] + '…'
			} else {
				app.mcp_probe_detail
			}
			app.gg.draw_text(fx + 24 + p.id.len * 10 + 12, y + 9, det, gg.TextCfg{
				color: app.pnl_danger
				size: 11
			})
		} else {
			app.gg.draw_text(fx + 24 + p.id.len * 10 + 12, y + 9, p.name, gg.TextCfg{
				color: app.pnl_text_mut
				size: 12
			})
		}
		health := match p.health {
			'healthy' { '✓ healthy' }
			'warn' { '! warn' }
			'error' { '× error' }
			else { '· idle' }
		}
		hcol := if p.health == 'healthy' {
			app.pnl_success
		} else if p.health == 'warn' {
			app.pnl_select
		} else if p.health == 'error' { app.pnl_danger } else { app.pnl_text_mut }
		app.gg.draw_text(fx + fw - 170, y + 8, health, gg.TextCfg{ color: hcol, size: 12, bold: p.health == 'healthy' })
		// provenance + receipt path + toggle action — one-click Engine TX
		app.gg.draw_text(fx + fw - 90, y + 8, if p.enabled { 'toggle off' } else { 'toggle on' }, gg.TextCfg{
			color: if p.enabled {
				app.pnl_text_mut} else {
				app.pnl_border_hi}
			size: 12
			bold: !p.enabled
		})
	}
	// footer — receipts verification + provenance + secret guard + install preview (super-potent)
	verify := app.desktop.engine_verify_receipts().filter(it.path.contains('mcp'))
	app.gg.draw_text(fx + 20, fy + fh - 28, 'MCP config: mcp/templates/<id>.json via Engine upsert (TX) · secret guard blocks raw ghp_/sk- → \${ENV_VAR} · provenance verified', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	app.gg.draw_text(fx + 20, fy + fh - 14, 'Click a row for masked drawer · toggle on the right · ${verify.len} receipt warnings · Enter toggles first provider', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	// provider drawer — modal card, masked template + probe + open-template (#1106)
	if app.mcp_drawer != '' {
		dx, dy, dw, dh := mcp_drawer_geom(fx, fy, fw)
		pixel_panel(mut app, dx, dy, dw, dh, 'dialog')
		app.gg.draw_text(dx + 14, dy + 10, 'MCP — ${app.mcp_drawer}', gg.TextCfg{
			color: app.pnl_text
			size: 14
			bold: true
		})
		src := if app.mcp_drawer_from_file {
			'template file'
		} else {
			'defaults (no template file)'
		}
		app.gg.draw_text(dx + 14, dy + 30, '${src} · secrets masked · provenance ${app.mcp_drawer_provenance}', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		mut ln2 := 0
		for raw_line in app.mcp_drawer_template.split('\n') {
			if ln2 >= 7 {
				break
			}
			line := if raw_line.len > 86 { raw_line[..86] + '…' } else { raw_line }
			app.gg.draw_text(dx + 18, dy + 48 + ln2 * 14, line, gg.TextCfg{
				color: app.pnl_text
				size: 11
				mono: true
			})
			ln2++
		}
		app.gg.draw_text(dx + 14, dy + 152, 'receipt: ${app.mcp_drawer_receipt}', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		prow_col := if mcp_probe_fresh(app, app.mcp_drawer) && !app.mcp_probe_ok {
			app.pnl_danger
		} else if mcp_probe_fresh(app, app.mcp_drawer) {
			app.pnl_success
		} else {
			app.pnl_text_mut
		}
		prow := if mcp_probe_fresh(app, app.mcp_drawer) {
			'probe: ${app.mcp_probe_detail}'
		} else {
			'probe: press Probe (cached 60s)'
		}
		app.gg.draw_text(dx + 14, dy + 168, prow, gg.TextCfg{ color: prow_col, size: 11 })
		btn_fg := if app.appearance_dark { app.pnl_bg } else { app.pnl_text }
		app.gg.draw_rect_filled(dx + 14, dy + dh - 32, 110, 22, app.pnl_select)
		app.gg.draw_rect_empty(dx + 14, dy + dh - 32, 110, 22, app.pnl_select)
		app.gg.draw_text(dx + 40, dy + dh - 26, 'Probe', gg.TextCfg{
			color: btn_fg
			size: 12
			bold: true
		})
		app.gg.draw_rect_filled(dx + 134, dy + dh - 32, 150, 22, app.pnl_card_sel)
		app.gg.draw_rect_empty(dx + 134, dy + dh - 32, 150, 22, app.pnl_border)
		app.gg.draw_text(dx + 148, dy + dh - 26, 'Open template', gg.TextCfg{
			color: app.pnl_text
			size: 12
		})
		app.gg.draw_rect_filled(dx + 294, dy + dh - 32, 80, 22, app.pnl_card_sel)
		app.gg.draw_rect_empty(dx + 294, dy + dh - 32, 80, 22, app.pnl_border)
		app.gg.draw_text(dx + 314, dy + dh - 26, 'Close', gg.TextCfg{ color: app.pnl_text, size: 12 })
	}
}

fn draw_targets(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	term_h_tg := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_tg
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
	fy := 52
	fw := panel_fw(app, w)
	term_h_do := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_do
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
				app.pnl_text} else {
				app.pnl_text_mut}
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
	app.gg.draw_text(fx + 20, fy + fh - 20, 'Click fix → for dry-run · chip fixes its category · receipts/provenance verified. All checks are English, no fallback.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	app.gg.draw_text(fx + fw - 160, fy + fh - 20, '${verify_diags.len} verify warnings', gg.TextCfg{
		color: if verify_diags.len > 0 {
			app.pnl_danger} else {
			app.pnl_success}
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
	fy := 52
	fw := panel_fw(app, w)
	term_h_jo := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_jo
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
	jobs := app.desktop.engine_jobs_catalog()
	// card metrics — paper cards with left status rail
	list_y0 := fy + 96
	list_h_total := fh - 84 - 110
	card_h := 52
	visible := list_h_total / card_h
	if visible < 1 {
		return
	}
	if jobs.len == 0 {
		app.gg.draw_text(fx + 18, list_y0 + 22, 'No jobs are currently running.', gg.TextCfg{ color: app.pnl_text_mut, size: 13 })
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
	fy := 52
	fw := panel_fw(app, w)
	term_h_lo := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_lo
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
// No role-name hardcoding; derives participants from recorded handoffs (#1101).
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
	fy := 52
	fw := panel_fw(app, w)
	term_h_sw := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_sw
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
				app.pnl_text} else {
				app.pnl_text}
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

// draw_kanban is a compact project snapshot inside Workspace.
fn draw_kanban(mut app GuiApp, fx int, y0 int, fw int) {
	h := 108
	pixel_panel(mut app, fx + 12, y0, fw - 24, h, 'default')
	app.gg.draw_text(fx + 24, y0 + 8, 'Kanban', gg.TextCfg{ color: app.pnl_text, size: font_display_sm })
	app.gg.draw_text(fx + 80, y0 + 9, 'todo • doing • done — budgets • verifier', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	colw := (fw - 48) / 3
	for ci, cname in ['todo', 'doing', 'done'] {
		cx := fx + 20 + ci * (colw + 4)
		app.gg.draw_rect_filled(cx, y0 + 24, colw, 14, app.pnl_card_sel)
		app.gg.draw_text(cx + 4, y0 + 27, cname, gg.TextCfg{ color: app.pnl_text, size: 11, bold: true })
		app.gg.draw_text(cx + colw - 14, y0 + 27, '${app.kanban.filter(it.col == cname).len}', gg.TextCfg{ color: app.pnl_text, size: 11 })
	}
	for t in app.kanban {
		ci := if t.col == 'todo' {
			0
		} else if t.col == 'doing' { 1 } else { 2 }
		cx := fx + 20 + ci * (colw + 4)
		mut idx_in_col := 0
		for o in app.kanban {
			if o.col == t.col && o.id < t.id { idx_in_col++ }
		}
		y := y0 + 40 + idx_in_col * 28
		if y + 24 > y0 + h - 6 {
			continue
		}
		pri_col := match t.pri {
			'high' { app.pnl_danger }
			'medium' { app.pnl_select }
			else { app.pnl_success }
		}
		app.gg.draw_rect_filled(cx, y, colw, 24, app.pnl_card)
		app.gg.draw_rect_empty(cx, y, colw, 24, app.pnl_text)
		app.gg.draw_rect_filled(cx, y, 4, 24, pri_col)
		app.gg.draw_text(cx + 8, y + 4, t.title, gg.TextCfg{ color: app.pnl_text, size: 11 })
		app.gg.draw_text(cx + 8, y + 14, t.owner, gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	}
}

// draw_file_tree_panel — left 180px, twisty, git dot, virtualized, hover, brokered.
fn draw_file_tree_panel(mut app GuiApp, x int, y int, w int, h int) {
	pixel_panel(mut app, x, y, w, h, 'terminal')
	app.gg.draw_rect_filled(x, y, w, 20, app.pnl_text)
	app.gg.draw_text(x + 8, y + 5, 'File Tree', gg.TextCfg{ color: app.pnl_card, size: 12, bold: true })
	// brass micro-label on the dark band in Paper; ink text on the light band in Ink (#1097)
	brokered_col := if app.appearance_dark { app.pnl_bg } else { app.pnl_border_hi }
	app.gg.draw_text(x + w - 56, y + 6, 'brokered', gg.TextCfg{ color: brokered_col, size: 10 })
	flat := file_tree_visible(app)
	row_h := 18
	visible := (h - 28) / row_h
	if visible < 1 {
		return
	}
	app.file_tree_scroll = clamp_scroll(app.file_tree_scroll, flat.len, visible)
	start := app.file_tree_scroll
	mut end := start + visible
	if end > flat.len {
		end = flat.len
	}
	for idx in start .. end {
		n := flat[idx]
		row := idx - start
		ry := y + 24 + row * row_h
		hover := idx == app.file_tree_hover
		sel := n.path == app.file_tree_selected
		if hover { app.gg.draw_rect_filled(x + 2, ry - 1, w - 4, row_h, app.pnl_hover) }
		if sel {
			app.gg.draw_rect_filled(x + 2, ry - 1, w - 4, row_h, tint(app.pnl_select, 70))
			app.gg.draw_rect_empty(x + 2, ry - 1, w - 4, row_h, app.pnl_border_hi)
		}
		// twisty for dirs
		indent := n.depth * 12
		if n.kind == 'dir' {
			tw := if n.expanded { '-' } else { '+' }
			app.gg.draw_text(x + 6 + indent, ry + 2, tw, gg.TextCfg{ color: app.pnl_text_mut, size: 12, bold: true })
		} else {
			app.gg.draw_text(x + 6 + indent, ry + 2, '·', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
		}
		icon := if n.kind == 'dir' {
			'+'
		} else if n.name.ends_with('.v') {
			'V'
		} else if n.name.ends_with('.md') { 'm' } else { '·' }
		app.gg.draw_text(x + 18 + indent, ry + 2, icon, gg.TextCfg{ color: app.pnl_border_hi, size: 11 })
		name_col := if sel {
			app.pnl_text
		} else if n.kind == 'dir' { app.pnl_text } else { app.pnl_text_mut }
		lbl := if n.name.len > 16 { n.name[..16] } else { n.name }
		app.gg.draw_text(x + 30 + indent, ry + 3, lbl, gg.TextCfg{ color: name_col, size: 12, mono: n.kind == 'file' })
		if n.git_status != '' {
			dot_col := if n.git_status == 'modified' { app.pnl_select } else { app.pnl_success }
			app.gg.draw_rect_filled(x + w - 14, ry + 6, 6, 6, dot_col)
		}
	}
	if flat.len > visible {
		mut bar_h := (h - 28) * visible / flat.len
		if bar_h < 10 {
			bar_h = 10
		}
		bar_y := y + 24 + (h - 28 - bar_h) * start / (flat.len - visible)
		app.gg.draw_rect_filled(x + w - 4, y + 24, 2, h - 28, tint(app.pnl_text, 120))
		app.gg.draw_rect_filled(x + w - 4, bar_y, 2, bar_h, app.pnl_border_hi)
	}
	if flat.len == 0 {
		app.gg.draw_text(x + 8, y + 30, 'No files — check harness_root', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	}
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

// draw_editor_panel — center tabs + syntax highlighted content + line numbers
fn draw_editor_panel(mut app GuiApp, x int, y int, w int, h int) {
	pixel_panel(mut app, x, y, w, h, 'default')
	// tab bar
	tab_h := 28
	app.gg.draw_rect_filled(x + 1, y + 1, w - 2, tab_h, app.pnl_card_sel)
	if app.editor_tabs.len == 0 {
		app.gg.draw_text(x + 12, y + 10, 'Editor — open a file from tree (brokered fs)', gg.TextCfg{ color: app.pnl_text_mut, size: 13 })
		app.gg.draw_text(x + 12, y + tab_h + 12, 'No tabs • brokered via Engine.open_path_validated → harness_root_escape guard', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
		return
	}
	mut tx := x + 6
	for i, tab in app.editor_tabs {
		active := i == app.active_tab
		bg := if active { app.pnl_card } else { app.pnl_card_sel }
		bd := if active { app.pnl_select } else { app.pnl_border }
		tw := tab.title.len * 7 + 28
		if tx + tw > x + w - 6 {
			break
		}
		app.gg.draw_rect_filled(tx, y + 6, tw, 18, bg)
		app.gg.draw_rect_empty(tx, y + 6, tw, 18, bd)
		if active { app.gg.draw_rect_filled(tx, y + 6, tw, 2, app.pnl_select) }
		app.gg.draw_text(tx + 8, y + 10, tab.title, gg.TextCfg{
			color: if active {
				app.pnl_text} else {
				app.pnl_text}
			size: 12
			bold: active
		})
		if tab.dirty {
			app.gg.draw_text(tx + tw - 14, y + 8, '•', gg.TextCfg{ color: app.pnl_danger, size: 13 })
		}
		tx += tw + 4
	}
	// content area with line numbers + syntax
	content_y := y + tab_h + 4
	content_h := h - tab_h - 8
	if content_h < 20 {
		return
	}
	active := if app.active_tab >= 0 && app.active_tab < app.editor_tabs.len {
		app.editor_tabs[app.active_tab]
	} else {
		EditorTab{}
	}
	lines := active.content.split_into_lines()
	row_h := 14
	visible := content_h / row_h
	if visible < 1 {
		return
	}
	app.editor_scroll = clamp_scroll(app.editor_scroll, lines.len, visible)
	start := app.editor_scroll
	mut end := start + visible
	if end > lines.len {
		end = lines.len
	}
	app.gg.draw_rect_filled(x + 4, content_y, w - 8, content_h, app.pnl_bg)
	app.gg.draw_rect_empty(x + 4, content_y, w - 8, content_h, app.pnl_border)
	for idx in start .. end {
		line := lines[idx]
		row := idx - start
		ly := content_y + 4 + row * row_h
		// line number gutter 32px
		app.gg.draw_rect_filled(x + 4, ly - 1, 32, row_h, app.pnl_card_sel)
		app.gg.draw_text(x + 10, ly, '${idx + 1:3d}', gg.TextCfg{ color: app.pnl_text_mut, size: 12, mono: true })
		tokens := highlight_line_local(line, active.syntax)
		mut cx := x + 40
		for tok in tokens {
			col := syntax_color(tok.kind)
			app.gg.draw_text(cx, ly, tok.text, gg.TextCfg{ color: col, size: 13, mono: true })
			cx += tok.text.len * 6
			if cx > x + w - 8 {
				break
			}
		}
	}
	if lines.len > visible {
		mut bar_h := content_h * visible / lines.len
		if bar_h < 12 {
			bar_h = 12
		}
		bar_y := content_y + (content_h - bar_h) * start / (lines.len - visible)
		app.gg.draw_rect_filled(x + w - 6, content_y, 2, content_h, tint(app.pnl_text, 80))
		app.gg.draw_rect_filled(x + w - 6, bar_y, 2, bar_h, app.pnl_border_hi)
	}
	app.gg.draw_text(x + 8, y + h - 14, '${active.syntax} • ${lines.len} lines • brokered fs • ${if active.dirty {
		'dirty'
	} else {
		'clean'
	}}', gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
}

// draw_git_rails_panel — right 240px CHANGES/HISTORY/COMPARE + commit graph + diff
fn draw_git_rails_panel(mut app GuiApp, x int, y int, w int, h int) {
	pixel_panel(mut app, x, y, w, h, 'terminal')
	// rail tabs
	app.gg.draw_rect_filled(x, y, w, 22, app.pnl_text)
	for ri, rn in ['CHANGES', 'HISTORY', 'COMPARE'] {
		active := app.git_rail == rn
		rx := x + 6 + ri * 78
		bg := if active { app.pnl_select } else { col_charcoal }
		// gold tab needs ink text in Ink; charcoal chips keep muted in both (#1097)
		fg := if active {
			if app.appearance_dark { app.pnl_bg } else { app.pnl_text }
		} else {
			app.pnl_text_mut
		}
		app.gg.draw_rect_filled(rx, y + 4, 74, 14, bg)
		app.gg.draw_rect_empty(rx, y + 4, 74, 14, if active { app.pnl_select } else { col_line })
		app.gg.draw_text(rx + 10, y + 7, rn, gg.TextCfg{ color: fg, size: 11, bold: active })
	}
	y0 := y + 26
	inner_h := h - 30
	if inner_h < 30 {
		return
	}
	if app.git_rail == 'CHANGES' {
		changes := app.desktop.engine_git_changes()
		app.gg.draw_text(x + 8, y0, '${changes.len} changed • staged flag • brokered', gg.TextCfg{ color: app.pnl_text, size: 11 })
		row_h := 20
		visible := (inner_h - 20) / row_h
		if visible < 1 {
			return
		}
		app.git_scroll = clamp_scroll(app.git_scroll, changes.len, visible)
		start := app.git_scroll
		mut end := start + visible
		if end > changes.len {
			end = changes.len
		}
		for idx in start .. end {
			c := changes[idx]
			row := idx - start
			ry := y0 + 14 + row * row_h
			hover := idx == app.git_hover
			if hover { app.gg.draw_rect_filled(x + 4, ry - 1, w - 8, row_h, app.pnl_card_sel) }
			status_col := match c.status {
				'modified' { app.pnl_select }
				'added' { app.pnl_success }
				'deleted' { app.pnl_danger }
				else { app.pnl_text_mut }
			}
			app.gg.draw_rect_filled(x + 8, ry + 6, 8, 8, status_col)
			app.gg.draw_text(x + 20, ry + 3, c.path.all_after_last('/'), gg.TextCfg{ color: app.pnl_text, size: 12, mono: true })
			app.gg.draw_text(x + 20, ry + 12, c.path, gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
			staged := if c.staged { 'staged' } else { 'unstaged' }
			app.gg.draw_text(x + w - 50, ry + 5, staged, gg.TextCfg{
				color: if c.staged {
					app.pnl_success} else {
					app.pnl_text_mut}
				size: 11
			})
		}
		if changes.len > visible {
			mut bar_h := (inner_h - 20) * visible / changes.len
			if bar_h < 10 {
				bar_h = 10
			}
			bar_y := y0 + 14 + (inner_h - 20 - bar_h) * app.git_scroll / (changes.len - visible)
			app.gg.draw_rect_filled(x + w - 4, y0 + 14, 2, inner_h - 20, tint(app.pnl_text, 80))
			app.gg.draw_rect_filled(x + w - 4, bar_y, 2, bar_h, app.pnl_border_hi)
		}
	} else if app.git_rail == 'HISTORY' {
		graph := app.desktop.engine_git_graph(20)
		app.gg.draw_text(x + 8, y0, 'commit graph • ${graph.commits.len} commits • lanes ${graph.max_lane + 1}', gg.TextCfg{ color: app.pnl_text, size: 11 })
		row_h := 22
		visible := (inner_h - 40) / row_h
		if visible < 1 {
			return
		}
		app.git_scroll = clamp_scroll(app.git_scroll, graph.commits.len, visible)
		start := app.git_scroll
		mut end := start + visible
		if end > graph.commits.len {
			end = graph.commits.len
		}
		for idx in start .. end {
			c := graph.commits[idx]
			lane := graph.lanes[idx]
			row := idx - start
			ry := y0 + 14 + row * row_h
			hover := idx == app.git_hover
			sel := c.hash == app.git_selected
			if hover { app.gg.draw_rect_filled(x + 4, ry - 1, w - 8, row_h, app.pnl_card_sel) }
			if sel { app.gg.draw_rect_empty(x + 4, ry - 1, w - 8, row_h, app.pnl_select) }
			// lane dot
			dot_x := x + 12 + lane * 10
			app.gg.draw_rect_filled(dot_x, ry + 7, 8, 8, app.pnl_text_mut)
			app.gg.draw_rect_empty(dot_x, ry + 7, 8, 8, app.pnl_text)
			if c.parents.len > 1 { app.gg.draw_rect_filled(dot_x + 4, ry + 3, 2, 4, app.pnl_select) }
			app.gg.draw_text(x + 44, ry + 2, c.hash[..7], gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
			msg := if c.message.len > 28 { c.message[..28] + '…' } else { c.message }
			app.gg.draw_text(x + 44, ry + 12, msg, gg.TextCfg{ color: app.pnl_text, size: 11 })
			app.gg.draw_text(x + w - 46, ry + 2, c.author, gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
			if c.refs.len > 0 {
				app.gg.draw_text(x + w - 46, ry + 12, c.refs[0], gg.TextCfg{ color: app.pnl_success, size: 10 })
			}
		}
		// diff preview below graph
		diff_y := y0 + 14 + visible * row_h + 6
		if diff_y + 40 < y + h - 4 {
			app.gg.draw_rect_filled(x + 4, diff_y, w - 8, 1, app.pnl_card_sel)
			app.gg.draw_text(x + 8, diff_y + 4, 'Diff preview — select commit for hunks', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			if app.git_selected != '' {
				hunks := app.desktop.engine_git_diff(app.git_selected)
				if hunks.len > 0 {
					app.gg.draw_text(x + 8, diff_y + 16, '${hunks[0].file}  +${hunks[0].new_count} -${hunks[0].old_count}', gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
				}
			}
		}
	} else { // COMPARE
		app.gg.draw_text(x + 8, y0, 'COMPARE • HEAD~1..HEAD • diff hunks', gg.TextCfg{ color: app.pnl_text, size: 11 })
		hunks := app.desktop.engine_git_compare('HEAD~1', 'HEAD')
		row_h := 14
		visible := (inner_h - 20) / row_h
		if visible < 1 {
			return
		}
		app.diff_scroll = clamp_scroll(app.diff_scroll, 20, visible)
		mut line_no := 0
		for hunk in hunks {
			if line_no >= visible {
				break
			}
			app.gg.draw_text(x + 8, y0 + 14 + line_no * row_h, '— ${hunk.file}', gg.TextCfg{ color: app.pnl_border_hi, size: 11, mono: true })
			line_no++
			for line in hunk.lines {
				if line_no >= visible {
					break
				}
				kind := line.kind
				col := match kind {
					.addition { app.pnl_success }
					.deletion { app.pnl_danger }
					.header { app.pnl_text_mut }
					else { app.pnl_text_mut }
				}
				prefix := match kind {
					.addition { '+' }
					.deletion { '-' }
					else { ' ' }
				}
				txt := prefix + line.text
				disp := if txt.len > 36 { txt[..36] + '…' } else { txt }
				app.gg.draw_text(x + 12, y0 + 14 + line_no * row_h, disp, gg.TextCfg{ color: col, size: 11, mono: true })
				line_no++
			}
		}
	}
}

// draw_memory_palace_panel — bottom semantic recall, hybrid cosine + token overlap
fn draw_memory_palace_panel(mut app GuiApp, x int, y int, w int, h int) {
	pixel_panel(mut app, x, y, w, h, 'inset')
	app.gg.draw_text(x + 8, y + 6, 'Memory Palace — semantic recall', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
	mode := if app.memory_semantic { 'semantic' } else { 'keyword' }
	app.gg.draw_text(x + w - 80, y + 6, mode, gg.TextCfg{ color: app.pnl_select, size: 11 })
	// search bar
	app.gg.draw_rect_filled(x + 8, y + 20, w - 16, 20, app.pnl_card)
	app.gg.draw_rect_empty(x + 8, y + 20, w - 16, 20, app.pnl_text)
	q := if app.memory_query == '' {
		'Search palace — try "brokered fs" or "git rails" (semantic)'
	} else {
		app.memory_query
	}
	col := if app.memory_query == '' { app.pnl_text_mut } else { app.pnl_text }
	app.gg.draw_text(x + 14, y + 26, q, gg.TextCfg{ color: col, size: 12 })
	if app.memory_query != '' {
		results := app.desktop.engine_memory_recall(app.memory_query, 5)
		row_h := 18
		visible := (h - 48) / row_h
		if visible < 1 {
			return
		}
		app.memory_scroll = clamp_scroll(app.memory_scroll, results.len, visible)
		start := app.memory_scroll
		mut end := start + visible
		if end > results.len {
			end = results.len
		}
		for idx in start .. end {
			r := results[idx]
			row := idx - start
			ry := y + 44 + row * row_h
			hover := idx == app.memory_hover
			if hover { app.gg.draw_rect_filled(x + 10, ry - 1, w - 20, row_h, app.pnl_card_sel) }
			pct := int(r.score * 100)
			app.gg.draw_text(x + 14, ry + 2, '${pct}%', gg.TextCfg{
				color: if pct > 70 {
					app.pnl_success} else {
					app.pnl_text_mut}
				size: 11
				bold: pct > 70
			})
			title := if r.entry.title.len > 28 {
				r.entry.title[..28] + '…'
			} else {
				r.entry.title
			}
			app.gg.draw_text(x + 46, ry + 2, title, gg.TextCfg{ color: app.pnl_text, size: 11 })
			snip := if r.snippet.len > 32 { r.snippet[..32] + '…' } else { r.snippet }
			app.gg.draw_text(x + 46, ry + 10, snip, gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
		}
		if results.len == 0 {
			app.gg.draw_text(x + 14, y + 44, 'No semantic hits — try "skills" or "file tree"', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
		}
	} else {
		entries := app.desktop.engine_memory_entries()
		app.gg.draw_text(x + 14, y + 44, '${entries.len} palace nodes • hybrid cosine 16-dim hashed embedding', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		app.gg.draw_text(x + 14, y + 56, 'Brokered via Engine.memory_semantic_recall • token overlap • 60 FPS virtualized', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	}
}

struct WorkspaceLayout {
	fx         int
	fy         int
	fw         int
	fh         int
	control_y  int
	field_x    int
	field_y    int
	field_w    int
	validate_x int
	switch_x   int
	init_x     int
	kanban_y   int
	mid_y      int
	mid_h      int
	mem_y      int
	mem_h      int
}

// workspace_layout is shared by drawing and pointer handling. Keeping the
// geometry in one place prevents a visual reflow from moving the hit targets.
fn workspace_layout(app &GuiApp, w int, h int) WorkspaceLayout {
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	term_h := if app.term_visible { app.term_height } else { 0 }
	fh := h - fy - 28 - term_h
	control_y := fy + 48
	init_x := fx + fw - 82
	switch_x := init_x - 66
	validate_x := switch_x - 72
	field_x := fx + 24
	field_y := control_y + 26
	mut field_w := validate_x - field_x - 8
	if field_w < 120 {
		field_w = 120
	}
	kanban_y := fy + 124
	mid_y := kanban_y + 108 + 12
	mem_h := 92
	mut mid_h := fy + fh - mid_y - mem_h - 12
	if mid_h < 120 {
		mid_h = 120
	}
	return WorkspaceLayout{
		fx: fx
		fy: fy
		fw: fw
		fh: fh
		control_y: control_y
		field_x: field_x
		field_y: field_y
		field_w: field_w
		validate_x: validate_x
		switch_x: switch_x
		init_x: init_x
		kanban_y: kanban_y
		mid_y: mid_y
		mid_h: mid_h
		mem_y: mid_y + mid_h + 6
		mem_h: mem_h
	}
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
	app.show_onboarding = panel == 11
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

fn draw_workspace(mut app GuiApp, w int, h int) {
	l := workspace_layout(app, w, h)
	app.gg.draw_rect_filled(l.fx, l.fy, l.fw, l.fh, app.pnl_bg)
	paper_letterhead(mut app, l.fx, l.fy, l.fw, tr(app, 'panel.workspace'), 'Files, project context, and memory for the active workspace', app.workspace_source)
	control_y := l.control_y
	control_h := 68
	pixel_panel(mut app, l.fx + 12, control_y, l.fw - 24, control_h, 'default')
	app.gg.draw_text(l.fx + 24, control_y + 8, 'ACTIVE WORKSPACE', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
	state_label := if app.workspace_initialized { 'Ready' } else { 'Needs setup' }
	state_col := if app.workspace_initialized { app.pnl_success } else { app.pnl_border_hi }
	app.gg.draw_text(l.fx + l.fw - 104, control_y + 8, state_label, gg.TextCfg{ color: state_col, size: 12, bold: true })
	field_bg := if app.workspace_focus { app.pnl_bg } else { app.pnl_card }
	field_bd := if app.workspace_focus { app.pnl_select } else { app.pnl_border }
	app.gg.draw_rect_filled(l.field_x, l.field_y, l.field_w, 28, field_bg)
	app.gg.draw_rect_empty(l.field_x, l.field_y, l.field_w, 28, field_bd)
	path_label := workspace_path_label(app.workspace_draft, 64)
	app.gg.draw_text(l.field_x + 8, l.field_y + 7, path_label, gg.TextCfg{ color: app.pnl_text, size: 12, mono: true })
	if app.workspace_focus && app.frame % 30 < 15 {
		cursor_x := l.field_x + 8 + path_label.len * 7
		if cursor_x < l.field_x + l.field_w - 4 {
			app.gg.draw_rect_filled(cursor_x, l.field_y + 6, 2, 16, app.pnl_select)
		}
	}
	for action in [
		['Validate', '${l.validate_x}', 'validate'],
		['Switch', '${l.switch_x}', 'switch'],
		['Initialize', '${l.init_x}', 'init'],
	] {
		x := action[1].int()
		is_init := action[2] == 'init'
		bg := if is_init && !app.workspace_initialized { app.pnl_select } else { app.pnl_text }
		fg := if is_init && !app.workspace_initialized { app.pnl_text } else { app.pnl_bg }
		app.gg.draw_rect_filled(x, l.field_y, if is_init { 58 } else { 64 }, 28, bg)
		app.gg.draw_rect_empty(x, l.field_y, if is_init { 58 } else { 64 }, 28, app.pnl_border_hi)
		app.gg.draw_text(x + 7, l.field_y + 8, action[0], gg.TextCfg{ color: fg, size: 11, bold: true })
	}
	if app.workspace_notice != '' {
		app.gg.draw_text(l.fx + 24, control_y + 56, app.workspace_notice, gg.TextCfg{
			color: if app.workspace_notice.contains('error') || app.workspace_notice.contains('Could not') {
				app.pnl_danger} else {
				app.pnl_text_mut}
			size: 11
		})
	}
	// The project snapshot stays below the workspace control so the selected
	// path is visible before any file or memory data is interpreted.
	draw_kanban(mut app, l.fx, l.kanban_y, l.fw)
	// middle IDE: file tree | editor | git rails
	// left file tree 180
	draw_file_tree_panel(mut app, l.fx + 12, l.mid_y, 180, l.mid_h)
	// center editor
	editor_w := l.fw - 24 - 180 - 4 - 240
	draw_editor_panel(mut app, l.fx + 12 + 180 + 4, l.mid_y, editor_w, l.mid_h)
	// right git rails 240
	draw_git_rails_panel(mut app, l.fx + l.fw - 240 - 12, l.mid_y, 240, l.mid_h)
	// bottom memory palace semantic recall
	draw_memory_palace_panel(mut app, l.fx + 12, l.mem_y, l.fw - 24, l.mem_h)
}

// ── Products & Packs — super potent easy management ─────────────────────────────────
// Brokered via Desktop.engine_products_catalog / packs_catalog (Engine typed, no shell).
// Easy to manage: product cards, pack chips, membership bulk, build preview, digest.
fn draw_products(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	term_h_pd := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_pd
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	prods := app.desktop.engine_products_catalog()
	packs := app.desktop.engine_packs_catalog()
	installed := app.desktop.engine_skills_installed()
	preview := skills_total(mut app).str()
	paper_letterhead(mut app, fx, fy, fw, tr(app, 'panel.products'), '${prods.len} products · ${packs.len} packs · ${installed.len} skills installed · docs-only per ADR-006', 'digest ${preview}')
	// product cards
	card_y0 := fy + 48
	card_h := 52
	visible := (fh - 70) / card_h
	if visible < 1 {
		return
	}
	app.products_scroll = clamp_scroll(app.products_scroll, prods.len, visible)
	start := app.products_scroll
	mut end := start + visible
	if end > prods.len {
		end = prods.len
	}
	for idx in start .. end {
		p := prods[idx]
		row := idx - start
		y := card_y0 + row * card_h
		hover := idx == app.products_hover
		bg := if hover { app.pnl_card } else { app.pnl_bg }
		bd := if hover { app.pnl_select } else { app.pnl_border }
		pixel_panel(mut app, fx + 12, y, fw - 24, card_h - 6, 'default')
		app.gg.draw_rect_filled(fx + 14, y + 2, fw - 28, card_h - 10, bg)
		app.gg.draw_rect_empty(fx + 14, y + 2, fw - 28, card_h - 10, bd)
		app.gg.draw_text(fx + 22, y + 8, p.id, gg.TextCfg{ color: app.pnl_text, size: 14, bold: true, mono: true })
		app.gg.draw_text(fx + 22, y + 22, p.name, gg.TextCfg{ color: app.pnl_text, size: 12 })
		mut desc := p.description
		if desc.len > 42 {
			desc = desc[..42] + '…'
		}
		app.gg.draw_text(fx + 22, y + 34, desc, gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		// skill count pill
		scnt := p.skill_ids.len
		app.gg.draw_rect_filled(fx + fw - 118, y + 6, 52, 14, app.pnl_card_sel)
		app.gg.draw_text(fx + fw - 114, y + 8, '${scnt} skills', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
		// Install + Manage — super-potent easy management, distinct install per product
		hover_install := hover
		ibg := if hover_install { app.pnl_select } else { app.pnl_text }
		app.gg.draw_rect_filled(fx + fw - 160, y + 26, 56, 16, ibg)
		app.gg.draw_rect_empty(fx + fw - 160, y + 26, 56, 16, app.pnl_select)
		app.gg.draw_text(fx + fw - 152, y + 29, 'Install', gg.TextCfg{
			color: if hover_install {
				app.pnl_text} else {
				app.pnl_card}
			size: 11
			bold: hover_install
		})
		hover_manage := hover
		mbg := if hover_manage { app.pnl_text } else { app.pnl_text }
		app.gg.draw_rect_filled(fx + fw - 90, y + 26, 56, 16, mbg)
		app.gg.draw_text(fx + fw - 82, y + 29, 'Manage', gg.TextCfg{ color: app.pnl_card, size: 11, bold: hover_manage })
	}
	if prods.len > visible {
		track_h := visible * card_h
		bar_h := track_h * visible / prods.len
		mut bh := bar_h
		if bh < 12 {
			bh = 12
		}
		bar_y := card_y0 + (track_h - bh) * start / (prods.len - visible)
		app.gg.draw_rect_filled(fx + fw - 6, card_y0, 3, track_h, tint(app.pnl_text, 30))
		app.gg.draw_rect_filled(fx + fw - 6, bar_y, 3, bh, app.pnl_border_hi)
	}
	// packs chips below cards or at bottom if many
	// packs right after the real card count — no dead gap
	pack_y := card_y0 + prods.len * card_h + 10
	if pack_y + 22 < fy + fh - 14 {
		app.gg.draw_text(fx + 20, pack_y, 'Packs — docs-only, toggle to enable (Engine.set_pack_enabled):', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		mut px := fx + 20
		for pk in packs {
			label := pk.id
			active := pk.id in app.desktop.engine_packs_catalog().map(it.id) // docs-only packs; enable via Engine
			bg := if active { app.pnl_select } else { app.pnl_card_sel }
			fg := if active { app.pnl_text } else { app.pnl_text_mut }
			w2 := label.len * 7 + 16
			if px + w2 > fx + fw - 14 {
				break
			}
			app.gg.draw_rect_filled(px, pack_y + 14, w2, 18, bg)
			app.gg.draw_rect_empty(px, pack_y + 14, w2, 18, app.pnl_border)
			app.gg.draw_text(px + 8, pack_y + 18, label, gg.TextCfg{ color: fg, size: 11 })
			px += w2 + 6
		}
	}
	app.gg.draw_text(fx + 20, fy + fh - 14, 'Products compose skills via distributions/products.yaml — build --check validates · packs docs-only ADR-006', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
}

// ── Onboarding — super-potent wizard: workspace init, persona bootstrap, capability/target/product ──
// Single modal wizard where everything is possible and easy to manage. One view, seven steps:
// Detect → Capabilities (227) → Targets (7) → Products/Packs (5+7) → Workspace Init → Personas → Tour → Done.
// All actions wire via Desktop.onboarding_* proxies → Engine transactions → EventBus → AppState (no shell).
fn draw_onboarding(mut app GuiApp, w int, h int) {
	term_h_on := if app.term_visible { app.term_height } else { 0 }
	// overlay dim if showing as modal over world, otherwise full panel when selected_panel==11
	is_overlay := app.show_onboarding && app.selected_panel != 11
	if is_overlay {
		app.gg.draw_rect_filled(0, 44, w, h - 44 - 28 - term_h_on, tint(app.pnl_text, 55))
	}
	mut fx := if is_overlay { 240 } else { 208 }
	fy := 52
	mut fw := if is_overlay { w - 480 } else { w - 208 - 300 }
	if fw < 520 {
		fw = if is_overlay { 640 } else { w - 208 - 300 }
		fx = if is_overlay { (w - fw) / 2 } else { 208 }
	}
	mut fh := h - 52 - 28 - term_h_on
	if fh < 400 {
		fh = 400
	}
	// panel chrome
	app.gg.draw_rect_filled(fx, fy, fw, fh, tint(app.pnl_text, 18))
	pixel_panel(mut app, fx, fy, fw, fh, 'default')
	// header — Dunder paper envelope with GOD mailbox glow (signature).
	// Paper keeps the inverted ink band; resolved-dark keeps a dark band so
	// every header/tab role holds ≥4.5:1 (#1097).
	ob_band := if app.appearance_dark { app.pnl_card_sel } else { app.pnl_text }
	ob_title := if app.appearance_dark { app.pnl_text } else { app.pnl_card }
	app.gg.draw_rect_filled(fx, fy, fw, 36, ob_band)
	// warm paper fiber header texture — faint speck every 40px
	for sx in 0 .. (fw / 40 + 1) {
		app.gg.draw_rect_filled(fx + 12 + sx * 40, fy + 8, 1, 1, tint(app.pnl_bg, 8))
	}
	app.gg.draw_text(fx + 14, fy + 9, tr(app, 'panel.onboarding'), gg.TextCfg{
		color: ob_title
		size: font_display_md
		family: app.fonts.display
	})
	app.gg.draw_text(fx + 150, fy + 13, 'workspace · coding tools · ${skills_total(mut app)} capabilities · ${products_total(mut app)} products', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	// signature envelope + GOD mailbox glow — paper envelope on header right
	env_x := fx + fw - 140
	env_y := fy + 8
	// GOD mailbox glow pulse (rust)
	if app.frame % 40 < 20 {
		app.gg.draw_rect_filled(env_x - 4, env_y - 2, 24, 20, tint(app.pnl_danger, 18))
	}
	app.gg.draw_rect_filled(env_x, env_y, 20, 14, app.pnl_bg)
	app.gg.draw_rect_empty(env_x, env_y, 20, 14, app.pnl_border)
	app.gg.draw_line(env_x, env_y, env_x + 10, env_y + 7, app.pnl_border_hi)
	app.gg.draw_line(env_x + 10, env_y + 7, env_x + 20, env_y, app.pnl_border_hi)
	if app.god_inbox > 0 {
		app.gg.draw_rect_filled(env_x + 14, env_y - 3, 6, 6, app.pnl_danger)
	}
	if is_overlay {
		// X close
		app.gg.draw_rect_filled(fx + fw - 32, fy + 6, 24, 24, app.pnl_text)
		app.gg.draw_rect_empty(fx + fw - 32, fy + 6, 24, 24, app.pnl_border)
		ob_x_col := if app.appearance_dark { app.pnl_bg } else { app.pnl_text_mut }
		app.gg.draw_text(fx + fw - 24, fy + 11, '×', gg.TextCfg{ color: ob_x_col, size: 16, bold: true })
	}
	// live status via Engine (typed, no shell)
	mut status_is_first := true
	mut pending := []string{}
	mut harness_root := app.onboarding_harness
	mut installed_cnt := 0
	mut enabled_targets := []string{}
	mut persona_cnt := 0
	mut workspace_exists := false
	mut revision := u64(0)
	if app.desktop != unsafe { nil } {
		st := app.desktop.onboarding_status(app.harness_root)
		status_is_first = st.is_first_run
		pending = st.pending_items.clone()
		harness_root = if app.onboarding_harness != '' {
			app.onboarding_harness
		} else {
			st.harness_root
		}
		installed_cnt = st.installed_count
		enabled_targets = st.enabled_targets.clone()
		persona_cnt = st.persona_count
		workspace_exists = st.workspace_exists
		revision = st.revision
		_ = st
	}
	// step tabs — 7 steps, pixel-snapped
	steps := ['Welcome', 'Capabilities', 'Coding tools', 'Products', 'Workspace', 'Team roles',
		'Ready']
	y_tabs := fy + 40
	mut tab_x := fx + 10
	for si, sname in steps {
		active := si == app.onboarding_step
		bg := if active {
			app.pnl_select
		} else if si < app.onboarding_step { app.pnl_success } else { app.pnl_text }
		// light-on-dark in Paper; dark text on the light chips/select in Ink (#1097)
		tab_fg := if active || si < app.onboarding_step {
			if app.appearance_dark { app.pnl_bg } else { app.pnl_text }
		} else {
			if app.appearance_dark { app.pnl_bg } else { app.pnl_text_mut }
		}
		bd := if active { app.pnl_select } else { col_line }
		tw := sname.len * 7 + 16
		if tab_x + tw > fx + fw - 10 {
			break
		}
		app.gg.draw_rect_filled(tab_x, y_tabs, tw, 18, bg)
		app.gg.draw_rect_empty(tab_x, y_tabs, tw, 18, bd)
		app.gg.draw_text(tab_x + 8, y_tabs + 4, sname, gg.TextCfg{ color: tab_fg, size: 11, bold: active })
		if si < app.onboarding_step {
			app.gg.draw_text(tab_x + tw - 12, y_tabs + 4, '✓', gg.TextCfg{ color: tab_fg, size: 11, bold: true })
		}
		tab_x += tw + 4
	}
	// status bar below tabs
	y_status := y_tabs + 24
	pill_col := if status_is_first { app.pnl_danger } else { app.pnl_success }
	pill_bg := if status_is_first { tint(app.pnl_danger, 18) } else { tint(app.pnl_success, 14) }
	app.gg.draw_rect_filled(fx + 10, y_status, 110, 16, pill_bg)
	app.gg.draw_rect_empty(fx + 10, y_status, 110, 16, pill_col)
	app.gg.draw_text(fx + 14, y_status + 3, if status_is_first {
		'First Run'
	} else {
		'Onboarded ✓'
	}, gg.TextCfg{ color: pill_col, size: 11, bold: true })
	app.gg.draw_text(fx + 130, y_status + 3, 'rev ${revision} • api ${app.api_calls} • ${installed_cnt} skills • ${enabled_targets.len} targets • ${persona_cnt} personas • ${if workspace_exists {
		'workspace ✓'
	} else {
		'workspace …'
	}}', gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
	if pending.len > 0 {
		app.gg.draw_text(fx + 14, y_status + 20, 'Pending: ${pending.join(' • ')}', gg.TextCfg{ color: app.pnl_danger, size: 11 })
	} else {
		app.gg.draw_text(fx + 14, y_status + 20, 'All gaps closed — ready for tour.', gg.TextCfg{ color: app.pnl_success, size: 11 })
	}
	// harness path row — brokered fs validated
	y_harness := y_status + 38
	app.gg.draw_text(fx + 10, y_harness, 'Workspace location:', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
	mut harness_display := if harness_root == '' { app.harness_root } else { harness_root }
	if harness_display == '' {
		harness_display = (if app.desktop != unsafe { nil } {
			app.desktop.onboarding_status('').harness_root
		} else {
			''
		})
		if harness_display == '' {
			harness_display = '/tmp/agent-toolkit-workspace'
		}
	}
	disp := if harness_display.len > 54 {
		'…' + harness_display[harness_display.len - 54..]
	} else {
		harness_display
	}
	app.gg.draw_rect_filled(fx + 64, y_harness - 2, fw - 180, 18, app.pnl_card)
	app.gg.draw_rect_empty(fx + 64, y_harness - 2, fw - 180, 18, app.pnl_border)
	app.gg.draw_text(fx + 70, y_harness + 1, disp, gg.TextCfg{ color: app.pnl_text, size: 12, mono: true })
	app.gg.draw_text(fx + fw - 100, y_harness + 1, if workspace_exists {
		'exists ✓'
	} else {
		'not yet'
	}, gg.TextCfg{ color: if workspace_exists { app.pnl_success } else { app.pnl_text_mut }, size: 11 })
	// per-step content — super-potent easy management, everything possible
	content_y := y_harness + 24
	content_h := fh - (content_y - fy) - 52
	if content_h < 120 {
		return
	}
	match app.onboarding_step {
		0 { // Detect — toolkit root, tier, resolve_paths, env precedence
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Welcome — check your environment', gg.TextCfg{ color: app.pnl_text, size: 14, bold: true })
			paths := if app.desktop != unsafe { nil } {
				app.desktop.engine_resolve_paths()
			} else {
				[]string{}
			}
			root_str := if paths.len > 0 {
				paths[0]
			} else {
				'AGENT_TOOLKIT_ROOT → XDG → embedded → FHS'
			}
			tier_str := if paths.len > 1 { paths[1] } else { 'tier: embedded' }
			app.gg.draw_text(fx + 20, content_y + 28, 'Toolkit Root:', gg.TextCfg{ color: app.pnl_text, size: 12 })
			app.gg.draw_text(fx + 20, content_y + 40, root_str, gg.TextCfg{ color: app.pnl_text, size: 12, mono: true })
			app.gg.draw_text(fx + 20, content_y + 56, tier_str, gg.TextCfg{ color: app.pnl_text_mut, size: 12, mono: true })
			app.gg.draw_text(fx + 20, content_y + 74, 'Agent Toolkit found its resources and can work offline from this location.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			app.gg.draw_text(fx + 20, content_y + 90, '${if status_is_first { '!' } else { '·' }} is_first_run=${status_is_first}   doctor checks via Engine.doctor() typed', gg.TextCfg{
				color: if status_is_first {
					app.pnl_danger} else {
					app.pnl_success}
				size: 12
				mono: true
			})
			app.gg.draw_text(fx + 20, content_y + 110, 'Next: choose useful capabilities and where your coding tools should use them.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			// environment stamp grid — the office at a glance
			stamps := [
				['Capabilities', '${installed_cnt} / ${skills_total(mut app)} installed'],
				['Targets', '${enabled_targets.len} / ${targets_total(mut app)} enabled'],
				['Personas', '${persona_cnt} bootstrapped'],
				['Workspace', if workspace_exists { 'initialized ✓' } else { 'not initialized' }],
			]
			stamp_y := content_y + 134
			for si, st in stamps {
				sx := fx + 20 + si * ((fw - 60) / 4)
				sw := (fw - 60) / 4 - 10
				app.gg.draw_rect_filled(sx, stamp_y, sw, 54, app.pnl_card)
				app.gg.draw_rect_empty(sx, stamp_y, sw, 54, app.pnl_border)
				app.gg.draw_rect_filled(sx, stamp_y, sw, 10, app.pnl_card_sel)
				app.gg.draw_text(sx + 8, stamp_y + 16, st[0], gg.TextCfg{
					color: app.pnl_text
					size: 12
					bold: true
					family: app.fonts.display
				})
				app.gg.draw_text(sx + 8, stamp_y + 34, st[1], gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			}
			// pending checklist — what the wizard still has to do
			pend_y := stamp_y + 66
			app.gg.draw_text(fx + 20, pend_y, 'Pending — ${pending.len} items', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
			for pi, pitem in pending {
				if pi >= 5 {
					app.gg.draw_text(fx + 34, pend_y + 18 + 5 * 16, '+${pending.len - 5} more — continue the steps above', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
					break
				}
				app.gg.draw_rect_filled(fx + 24, pend_y + 20 + pi * 16, 8, 8, app.pnl_danger)
				app.gg.draw_text(fx + 38, pend_y + 16 + pi * 16, pitem, gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			}
			if pending.len == 0 {
				app.gg.draw_text(fx + 24, pend_y + 18, 'All set — your workspace and selected tools are ready. Press Ready.', gg.TextCfg{ color: app.pnl_success, size: 11 })
			}
		}
		1 { // Capabilities — searchable 227 via Engine, bulk install
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Choose capabilities — ${skills_total(mut app)} available', gg.TextCfg{ color: app.pnl_text, size: 14, bold: true })
			q := app.skills_query
			disp_q := if q == '' {
				'Search capabilities by name or topic'
			} else {
				'filter: ${q} • ${app.desktop.engine_skills_search(q, '').len} match'
			}
			app.gg.draw_rect_filled(fx + 20, content_y + 28, fw - 40, 20, app.pnl_card)
			app.gg.draw_rect_empty(fx + 20, content_y + 28, fw - 40, 20, app.pnl_text)
			app.gg.draw_text(fx + 26, content_y + 33, disp_q, gg.TextCfg{
				color: if q == '' {
					app.pnl_text_mut} else {
					app.pnl_text}
				size: 12
			})
			// chips
			domains := ['core', 'delivery', 'design', 'forge', 'loops', 'quality']
			mut x2 := fx + 20
			for d in domains {
				active := app.skills_domain == d
				bg := if active { app.pnl_select } else { app.pnl_card_sel }
				fg2 := if active { app.pnl_text } else { app.pnl_text_mut }
				tw2 := d.len * 7 + 12
				app.gg.draw_rect_filled(x2, content_y + 52, tw2, 16, bg)
				app.gg.draw_rect_empty(x2, content_y + 52, tw2, 16, app.pnl_border)
				app.gg.draw_text(x2 + 6, content_y + 55, d, gg.TextCfg{ color: fg2, size: 11 })
				x2 += tw2 + 4
			}
			// filtered list preview — top 6 via Engine
			entries := if app.desktop != unsafe { nil } {
				app.desktop.engine_skills_search(q, app.skills_domain)
			} else {
				[]desktop_engine.SkillEntry{}
			}
			list_y := content_y + 74
			for i in 0 .. 6 {
				if i >= entries.len {
					break
				}
				s := entries[i]
				y := list_y + i * 16
				sel := s.id in app.selected_skills_onboarding
				bg2 := if sel { app.pnl_select } else { app.pnl_bg }
				app.gg.draw_rect_filled(fx + 20, y, fw - 40, 14, bg2)
				app.gg.draw_text(fx + 24, y + 2, s.id, gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
				app.gg.draw_text(fx + fw - 90, y + 2, s.domain, gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			}
			app.gg.draw_text(fx + 20, content_y + content_h - 36, 'Select useful capabilities, review the changes, then install them together.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			// install 5 button
			hov := app.onboarding_hover == 1
			app.gg.draw_rect_filled(fx + fw - 120, content_y + content_h - 54, 96, 20, if hov {
				app.pnl_text
			} else {
				app.pnl_select
			})
			app.gg.draw_text(fx + fw - 108, content_y + content_h - 49, 'Install 5', gg.TextCfg{
				color: if hov {
					app.pnl_card} else {
					app.pnl_text}
				size: 12
				bold: true
			})
			app.gg.draw_text(fx + 20, content_y + content_h - 54, 'Installed: ${installed_cnt} skills', gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
		}
		2 { // Targets — toggles via Engine over the live catalog roster
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Choose coding tools — ${targets_total(mut app)} detected', gg.TextCfg{ color: app.pnl_text, size: 14, bold: true })
			tgts := if app.desktop != unsafe { nil } {
				app.desktop.engine_targets().map(it.id)
			} else {
				[]string{}
			}
			for i, t in tgts {
				y := content_y + 30 + i * 20
				enabled := t in enabled_targets
				hov2 := app.targets_hover == i
				bg3 := if enabled { app.pnl_text } else { app.pnl_card_sel }
				fg3 := if enabled { app.pnl_card } else { app.pnl_text_mut }
				app.gg.draw_rect_filled(fx + 20, y, fw - 40, 16, bg3)
				app.gg.draw_rect_empty(fx + 20, y, fw - 40, 16, if hov2 {
					app.pnl_select
				} else {
					app.pnl_border
				})
				app.gg.draw_text(fx + 26, y + 3, t, gg.TextCfg{ color: fg3, size: 12, mono: true })
				app.gg.draw_text(fx + fw - 80, y + 3, if enabled {
					'enabled ✓'
				} else {
					'off -'
				}, gg.TextCfg{ color: if enabled { app.pnl_success } else { app.pnl_text_mut }, size: 11 })
			}
			// bulk enable all / minimal
			app.gg.draw_rect_filled(fx + 20, content_y + content_h - 40, 90, 18, app.pnl_card_sel)
			app.gg.draw_text(fx + 28, content_y + content_h - 36, 'Enable 3', gg.TextCfg{ color: app.pnl_text, size: 11, bold: true })
			app.gg.draw_rect_filled(fx + 118, content_y + content_h - 40, 90, 18, app.pnl_text)
			app.gg.draw_text(fx + 126, content_y + content_h - 36, 'Enable All', gg.TextCfg{ color: app.pnl_card, size: 11 })
			diff := if app.desktop != unsafe { nil } {
				app.desktop.engine_targets_enabled().len
			} else {
				enabled_targets.len
			}
			_ = diff
			app.gg.draw_text(fx + 20, content_y + content_h - 56, 'Enable where Agent Toolkit should make capabilities available. Review before saving.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		}
		3 { // Products / Packs — membership & digest
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Ready-made bundles — ${products_total(mut app)} products · ${packs_total(mut app)} packs', gg.TextCfg{ color: app.pnl_text, size: 14, bold: true })
			prods := if app.desktop != unsafe { nil } {
				app.desktop.engine_products_catalog()
			} else {
				[]desktop_engine.ProductEntry{}
			}
			packs := if app.desktop != unsafe { nil } {
				app.desktop.engine_packs_catalog()
			} else {
				[]desktop_engine.PackEntry{}
			}
			// R2 product-truth: render the full Engine products catalog (5), no cap.
			for i, p in prods {
				y := content_y + 30 + i * 20
				app.gg.draw_rect_filled(fx + 20, y, fw - 40, 16, app.pnl_card)
				app.gg.draw_text(fx + 26, y + 3, p.id, gg.TextCfg{ color: app.pnl_text, size: 12, mono: true })
				app.gg.draw_text(fx + fw - 80, y + 3, '${p.skill_ids.len} skills', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			}
			mut px := fx + 20
			py := content_y + 30 + prods.len * 20 + 6
			app.gg.draw_text(fx + 20, py, 'Packs docs-only (ADR-006):', gg.TextCfg{ color: app.pnl_text, size: 11 })
			for pk in packs {
				label := pk.id
				tw3 := label.len * 7 + 12
				if px + tw3 > fx + fw - 20 {
					break
				}
				app.gg.draw_rect_filled(px, py + 12, tw3, 14, app.pnl_card_sel)
				app.gg.draw_text(px + 6, py + 14, label, gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
				px += tw3 + 4
			}
			preview := skills_total(mut app).str()
			_ = preview
			app.gg.draw_text(fx + 20, content_y + content_h - 36, 'Preview: build_preview() → plugins-digest • membership via update_product_membership in one TX', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		}
		4 { // Workspace init — harness scaffold
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Create your Agent Toolkit workspace', gg.TextCfg{ color: app.pnl_text, size: 14, bold: true })
			app.gg.draw_text(fx + 20, content_y + 30, 'Target: ${harness_display}', gg.TextCfg{ color: app.pnl_text, size: 12, mono: true })
			app.gg.draw_text(fx + 20, content_y + 46, 'Creates a safe managed home for capabilities, projects, context, and settings.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			status_col2 := if workspace_exists { app.pnl_success } else { app.pnl_select }
			app.gg.draw_text(fx + 20, content_y + 62, if workspace_exists {
				'✓ Workspace exists — ready'
			} else {
				'○ Not yet — click Init Workspace'
			}, gg.TextCfg{ color: status_col2, size: 12, bold: true })
			// init button
			hov_init := app.onboarding_hover == 4
			app.gg.draw_rect_filled(fx + 20, content_y + 82, 130, 24, if hov_init {
				app.pnl_text
			} else {
				app.pnl_select
			})
			app.gg.draw_text(fx + 36, content_y + 89, 'Init Workspace', gg.TextCfg{
				color: if hov_init {
					app.pnl_card} else {
					app.pnl_text}
				size: 13
				bold: true
			})
			app.gg.draw_rect_filled(fx + 158, content_y + 82, 140, 24, app.pnl_card_sel)
			app.gg.draw_text(fx + 168, content_y + 89, 'Init + Personas', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
			if app.onboarding_msg != '' {
				app.gg.draw_text(fx + 20, content_y + 114, app.onboarding_msg, gg.TextCfg{ color: app.pnl_border_hi, size: 11, mono: true })
			}
			app.gg.draw_text(fx + 20, content_y + content_h - 30, 'Via Engine.onboarding_ensure_workspace(path) + StateRepository TX → EventBus → AppState (no shell, brokered fs)', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
		}
		5 { // Personas — bootstrap 4 persona markdowns
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Optional team roles', gg.TextCfg{ color: app.pnl_text, size: 14, bold: true })
			personas := ['implementer', 'reviewer', 'researcher', 'architect']
			for i, pers in personas {
				y := content_y + 32 + i * 22
				done := i < persona_cnt
				bg4 := if done { app.pnl_success } else { app.pnl_card_sel }
				fg4 := if done { app.pnl_text } else { app.pnl_text_mut }
				app.gg.draw_rect_filled(fx + 20, y, fw - 40, 16, bg4)
				app.gg.draw_rect_empty(fx + 20, y, fw - 40, 16, app.pnl_border)
				app.gg.draw_text(fx + 26, y + 3, pers, gg.TextCfg{ color: fg4, size: 12, mono: true })
				app.gg.draw_text(fx + fw - 80, y + 3, if done { 'ready ✓' } else { 'pending' }, gg.TextCfg{
					color: if done {
						app.pnl_text} else {
						app.pnl_text_mut}
					size: 11
				})
			}
			app.gg.draw_text(fx + 20, content_y + 128, 'Add reusable roles for how you plan, build, review, and research.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			hov_boot := app.onboarding_hover == 5
			app.gg.draw_rect_filled(fx + 20, content_y + 148, 130, 22, if hov_boot {
				app.pnl_text
			} else {
				app.pnl_select
			})
			app.gg.draw_text(fx + 32, content_y + 154, 'Bootstrap Personas', gg.TextCfg{
				color: if hov_boot {
					app.pnl_card} else {
					app.pnl_text}
				size: 12
				bold: true
			})
			app.gg.draw_text(fx + 20, content_y + content_h - 30, 'Via Engine.onboarding_ensure_personas(harness) → personas/*.md scaffold + TX revision bump', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
		}
		6 { // Done — tour + complete
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'You are ready to work', gg.TextCfg{ color: app.pnl_text, size: 14, bold: true })
			app.gg.draw_text(fx + 20, content_y + 30, '1 → World (floor, GOD mailbox)   2 → Skills (${skills_total(mut app)} fuzzy)   3 → Agents (${agents_active_total(mut app)})   4 → Targets (${targets_total(mut app)})', gg.TextCfg{ color: app.pnl_text, size: 12 })
			app.gg.draw_text(fx + 20, content_y + 46, '5 → Doctor (receipts)  6 → Jobs  7 → Loops (inner/outer)  8 → Swarm (pair/team/full)  9 → Workspace IDE  P → Products', gg.TextCfg{ color: app.pnl_text, size: 12 })
			app.gg.draw_text(fx + 20, content_y + 64, 'All panels via single Engine — no shell, every mutation is a StateRepository Transaction → EventBus → AppState.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			hov_done := app.onboarding_hover == 6
			app.gg.draw_rect_filled(fx + 20, content_y + 84, 110, 22, if hov_done {
				app.pnl_text
			} else {
				app.pnl_success
			})
			app.gg.draw_text(fx + 34, content_y + 90, 'Complete ✓', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
			app.gg.draw_rect_filled(fx + 138, content_y + 84, 110, 22, app.pnl_card_sel)
			app.gg.draw_text(fx + 150, content_y + 90, 'Back to World', gg.TextCfg{ color: app.pnl_text, size: 12 })
			app.gg.draw_text(fx + 20, content_y + 112, 'On close, onboarding_completed=true persisted — next boot skips wizard (reset via onboarding_reset).', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		}
		else {}
	}
	// footer nav — Back / Next / Complete + progress
	tab_w := fw - 20
	app.gg.draw_rect_filled(fx + 10, fy + fh - 36, tab_w, 26, col_charcoal)
	// progress dots 7
	dots_x := fx + 14
	for di in 0 .. 7 {
		dcol := if di == app.onboarding_step {
			app.pnl_select
		} else if di < app.onboarding_step { app.pnl_success } else { col_line }
		app.gg.draw_rect_filled(dots_x + di * 14, fy + fh - 26, 8, 8, dcol)
	}
	app.gg.draw_text(dots_x + 7 * 14 + 8, fy + fh - 26, 'step ${app.onboarding_step + 1}/7 • rev ${revision} • api ${app.api_calls}', gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
	// Skip — super-potent easy management, distinct overlay skips wizard without persisting complete
	hov_skip := app.onboarding_hover == 12
	app.gg.draw_rect_filled(fx + fw - 294, fy + fh - 32, 56, 20, if hov_skip {
		app.pnl_danger
	} else {
		app.pnl_text
	})
	app.gg.draw_rect_empty(fx + fw - 294, fy + fh - 32, 56, 20, if hov_skip {
		app.pnl_danger
	} else {
		app.pnl_border
	})
	app.gg.draw_text(fx + fw - 284, fy + fh - 27, 'Skip', gg.TextCfg{
		color: if hov_skip {
			app.pnl_card} else if app.appearance_dark {
			// light button needs ink text in Ink (#1097)
			app.pnl_bg} else {
			app.pnl_text_mut}
		size: 12
	})
	// Back
	if app.onboarding_step > 0 {
		hov_back := app.onboarding_hover == 10
		app.gg.draw_rect_filled(fx + fw - 220, fy + fh - 32, 64, 20, if hov_back {
			app.pnl_text
		} else {
			app.pnl_text
		})
		app.gg.draw_rect_empty(fx + fw - 220, fy + fh - 32, 64, 20, app.pnl_border)
		app.gg.draw_text(fx + fw - 206, fy + fh - 27, 'Back', gg.TextCfg{ color: app.pnl_card, size: 12 })
	}
	// Next / Finish — steps 0..6 distinct progress
	is_last := app.onboarding_step == 6
	hov_next := app.onboarding_hover == 11
	next_bg := if is_last {
		app.pnl_success
	} else if hov_next { app.pnl_select } else { app.pnl_text }
	// Next text was identical to its button fill (blind in Paper, light-on-light
	// in Ink): default state uses light card text on the dark button in Paper
	// and ink text on the light button in Ink; hover/finish keep dark text on
	// gold/green in both (#1097).
	mut next_fg := if app.appearance_dark { app.pnl_bg } else { app.pnl_card }
	if hov_next && !is_last {
		next_fg = if app.appearance_dark { app.pnl_bg } else { app.pnl_text }
	}
	if is_last {
		next_fg = if app.appearance_dark { app.pnl_bg } else { app.pnl_text }
	}
	next_label := if is_last { 'Finish' } else { 'Next →' }
	app.gg.draw_rect_filled(fx + fw - 148, fy + fh - 32, 72, 20, next_bg)
	app.gg.draw_rect_empty(fx + fw - 148, fy + fh - 32, 72, 20, app.pnl_select)
	app.gg.draw_text(fx + fw - 132, fy + fh - 27, next_label, gg.TextCfg{ color: next_fg, size: 12, bold: true })
	if app.onboarding_msg != '' {
		app.gg.draw_text(fx + 110, fy + fh - 26, app.onboarding_msg[..if app.onboarding_msg.len > 48 {
			48
		} else {
			app.onboarding_msg.len
		}], gg.TextCfg{ color: app.pnl_select, size: 11 })
	}
}

// ── Insights — telemetry super-potent: cost ledger, tool waterfall, OTel spans, budgets spark, CI watcher ──
// Superior to munder-difflin: combines munder's cost ledger + tool waterfall + CI watcher in one paper-telemetry
// surface, plus budget sparks (402x per-swarm logistic chaos) and OTel spans with Dunder rust/brass paper.
// VJOBS=2 safe: all data via Desktop typed Engine APIs (no shell), 60 FPS retained, headless ATK_GUI_HEADLESS.
fn draw_insights(mut app GuiApp, w int, h int) {
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	term_h_in := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_in
	app.gg.draw_rect_filled(fx, fy, fw, fh, app.pnl_bg)
	paper_letterhead(mut app, fx, fy, fw, tr(app, 'panel.insights'), 'Usage, budgets, operations, and observed activity', 'Engine · no shell')
	// tabs — cost | waterfall | spans | budgets | ci | realtime | gallery (7, web parity + 2)
	tabs := ['cost', 'waterfall', 'spans', 'budgets', 'ci', 'realtime', 'gallery']
	tab_labels := ['Cost', 'Waterfall', 'Spans', 'Budgets', 'CI', 'Realtime', 'Gallery']
	tab_x0 := fx + 16
	tab_w := 84
	for i, t in tabs {
		x := tab_x0 + i * (tab_w + 6)
		y := fy + 48
		active := app.insights_tab == t
		hover := app.insights_hover == i
		bg := if active {
			app.pnl_text
		} else if hover { app.pnl_card_sel } else { app.pnl_card }
		bd := if active { app.pnl_select } else { app.pnl_border }
		fg := if active { app.pnl_card } else { app.pnl_text_mut }
		app.gg.draw_rect_filled(x, y, tab_w, 22, bg)
		app.gg.draw_rect_empty(x, y, tab_w, 22, bd)
		if active {
			app.gg.draw_rect_filled(x, y, tab_w, 2, app.pnl_select)
		}
		app.gg.draw_text(x + 10, y + 5, tab_labels[i], gg.TextCfg{ color: fg, size: 11, bold: active })
	}
	// content area
	cy0 := fy + 76
	ch := fh - 76 - 16
	pixel_panel(mut app, fx + 8, cy0, fw - 16, ch, 'default')
	inner_x := fx + 20
	inner_y := cy0 + 12
	inner_w := fw - 40
	if app.insights_tab == 'cost' {
		// Cost ledger — swarm runs + loop token usage + job costs
		app.gg.draw_text(inner_x, inner_y, 'Cost Ledger — recorded usage by run and job', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
		app.gg.draw_text(inner_x, inner_y + 18, 'Live Engine: swarm pair/team/full + loops max_tokens/max_wall_seconds + jobs budget', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		// swarm runs
		swarms := if app.desktop != unsafe { nil } {
			app.desktop.swarm_list()
		} else {
			[]desktop_engine.SwarmRun{}
		}
		jobs := if app.desktop != unsafe { nil } {
			app.desktop.engine_jobs_catalog()
		} else {
			[]desktop_engine.JobRecord{}
		}
		mut y := inner_y + 40
		// header row paper tape
		app.gg.draw_rect_filled(inner_x, y, inner_w, 16, app.pnl_card_sel)
		app.gg.draw_text(inner_x + 6, y + 3, 'Run / Job', gg.TextCfg{ color: app.pnl_text, size: 11, bold: true })
		app.gg.draw_text(inner_x + 160, y + 3, 'Recipe / Status', gg.TextCfg{ color: app.pnl_text, size: 11 })
		app.gg.draw_text(inner_x + 320, y + 3, 'Cost / Tokens', gg.TextCfg{ color: app.pnl_text, size: 11 })
		app.gg.draw_text(inner_x + 460, y + 3, 'Budget', gg.TextCfg{ color: app.pnl_text, size: 11 })
		y += 20
		mut row := 0
		for r in swarms {
			if y + 16 > cy0 + ch - 20 {
				break
			}
			bg2 := if row % 2 == 0 { app.pnl_card } else { app.pnl_bg }
			app.gg.draw_rect_filled(inner_x, y, inner_w, 16, bg2)
			app.gg.draw_text(inner_x + 6, y + 3, r.id[..if r.id.len > 14 { 14 } else { r.id.len }], gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
			app.gg.draw_text(inner_x + 160, y + 3, '${r.recipe.str()} • ${r.status.str()}', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			app.gg.draw_text(inner_x + 320, y + 3, '\$${r.budget_spent} / ${r.budget_total}', gg.TextCfg{ color: app.pnl_danger, size: 11, mono: true })
			// budget spark mini bar
			pct := if r.budget_total > 0 { f64(r.budget_spent) / f64(r.budget_total) } else { 0.0 }
			mut bar_w := int(84 * pct)
			if bar_w > 84 {
				bar_w = 84
			}
			app.gg.draw_rect_filled(inner_x + 460, y + 5, 84, 6, app.pnl_border)
			if bar_w > 0 {
				bar_col := if pct > 0.9 {
					app.pnl_danger
				} else if pct > 0.7 { app.pnl_select } else { app.pnl_success }
				app.gg.draw_rect_filled(inner_x + 460, y + 5, bar_w, 6, bar_col)
			}
			y += 18
			row++
		}
		for j in jobs {
			if y + 16 > cy0 + ch - 20 {
				break
			}
			if j.id.len < 2 {
				continue
			}
			bg2 := if row % 2 == 0 { app.pnl_card } else { app.pnl_bg }
			app.gg.draw_rect_filled(inner_x, y, inner_w, 16, bg2)
			app.gg.draw_text(inner_x + 6, y + 3, j.id[..if j.id.len > 14 { 14 } else { j.id.len }], gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
			app.gg.draw_text(inner_x + 160, y + 3, 'job • ${j.status}', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			app.gg.draw_text(inner_x + 320, y + 3, 'exit ${j.exit_code}', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
			y += 18
			row++
		}
		if swarms.len == 0 && jobs.len == 0 {
			app.gg.draw_text(inner_x + 6, y + 4, 'No runs yet — launch via Swarm (pair/team/full) or Loops. Cost will appear here durably.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		}
		// footer spark seed
		app.gg.draw_text(inner_x, cy0 + ch - 18, 'Ledger persisted via StateRepository + EventBus • VJOBS=2 distinct-until-changed', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	} else if app.insights_tab == 'waterfall' {
		app.gg.draw_text(inner_x, inner_y, 'Tool Waterfall — measured spans by agent', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
		app.gg.draw_text(inner_x, inner_y + 18, 'Each agent row: tool spans as brass/steel bars on paper timeline — zoomed 18px rows, mono gutter', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		y0 := inner_y + 44
		agents := if app.desktop != unsafe { nil } {
			app.desktop.engine_agents_search('', '')
		} else {
			[]desktop_engine.AgentEntry{}
		}
		mut ay := y0
		for idx, a in agents {
			if ay + 20 > cy0 + ch - 24 {
				break
			}
			if idx > 7 {
				break
			}
			app.gg.draw_text(inner_x, ay + 3, a.id[..if a.id.len > 12 { 12 } else { a.id.len }], gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
			// Tool spans are drawn only when the Engine exposes measured spans.
			// Agent identity alone is not evidence that a tool call occurred.
			app.gg.draw_text(inner_x + inner_w - 80, ay + 3, a.tier, gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
			ay += 20
		}
		if agents.len == 0 {
			app.gg.draw_text(inner_x, y0 + 4, 'No agents are available in the resolved catalog.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		} else {
			app.gg.draw_text(inner_x + 110, y0 + 4, 'No measured tool spans yet.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		}
		app.gg.draw_text(inner_x, cy0 + ch - 18, 'Waterfall 60 FPS — retained geometry, viewport culling, text measurement via vglyph', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	} else if app.insights_tab == 'spans' {
		app.gg.draw_text(inner_x, inner_y, 'OTel Spans — live collection when telemetry is available', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
		mut y := inner_y + 40
		spans := if app.desktop != unsafe { nil } {
			app.desktop.engine_job_stats()
		} else {
			desktop_engine.JobStats{}
		}
		pids, drops := app.desktop.engine_process_supervisor_stats()
		app.gg.draw_text(inner_x + 6, y, 'Jobs: pids=${pids} drops=${drops} total=${spans.total} running=${spans.running} failed=${spans.failed}', gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
		y += 20
		app.gg.draw_text(inner_x + 6, y + 4, 'Measured spans will appear after a real job, loop, or swarm emits telemetry.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		app.gg.draw_text(inner_x, cy0 + ch - 18, 'Spans via EventBus process_log • durable ledger • no shell exec', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	} else if app.insights_tab == 'budgets' {
		app.gg.draw_text(inner_x, inner_y, 'Budgets — swarm + loops ledger (pair/team/full 900k/1.2M + per-loop max_tokens)', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
		loops := if app.desktop != unsafe { nil } {
			app.desktop.engine_loop_history('')
		} else {
			[]desktop_engine.LoopHistory{}
		}
		mut y := inner_y + 40
		app.gg.draw_text(inner_x + 6, y + 4, 'No budget measurements yet.', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		y += 22
		if loops.len > 0 {
			app.gg.draw_text(inner_x + 6, y + 10, 'Recent loop history: ${loops.len} entries', gg.TextCfg{ color: app.pnl_text, size: 12, bold: true })
			y += 30
			for hi, hrow in loops {
				if hi >= 8 || y + 16 > cy0 + ch - 40 {
					break
				}
				bg2 := if hi % 2 == 0 { app.pnl_card } else { app.pnl_bg }
				app.gg.draw_rect_filled(inner_x, y, inner_w, 16, bg2)
				app.gg.draw_text(inner_x + 6, y + 3, hrow.loop_name, gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
				app.gg.draw_text(inner_x + 160, y + 3, '${hrow.status} · exit ${hrow.exit_condition}', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
				app.gg.draw_text(inner_x + 340, y + 3, '${hrow.budget_spent} tok · ${hrow.duration_ms}ms', gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
				app.gg.draw_text(inner_x + inner_w - 90, y + 3, hrow.run_id, gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
				y += 18
			}
		}
		app.gg.draw_text(inner_x, cy0 + ch - 18, 'Budgets enforced via StateRepository • logistic 4*t*(1-t) GOD priority • VJOBS=2 serialized', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	} else if app.insights_tab == 'ci' {
		app.gg.draw_text(inner_x, inner_y, 'CI Watcher — observed workflow status', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
		app.gg.draw_text(inner_x, inner_y + 18, 'Watches .github/workflows/validate.yml via StateWatcher + PollingWatcher — no refresh', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
		mut y := inner_y + 42
		// CI jobs matrix (paper tape). A workflow name is not a result; show
		// neutral state until a connected provider reports an observation.
		jobs_ci := ['validate (VJOBS=2)', 'megalinter', 'check-planes', 'check-surface', 'catalogs',
			'provenance', 'build-cli']
		for i, j in jobs_ci {
			if y + 16 > cy0 + ch - 24 {
				break
			}
			bg2 := if i % 2 == 0 { app.pnl_card } else { app.pnl_bg }
			app.gg.draw_rect_filled(inner_x, y, inner_w, 16, bg2)
			status := 'Not observed'
			scol := app.pnl_text_mut
			app.gg.draw_text(inner_x + 6, y + 3, j, gg.TextCfg{ color: app.pnl_text, size: 11, mono: true })
			app.gg.draw_text(inner_x + inner_w - 80, y + 3, status, gg.TextCfg{ color: scol, size: 11 })
			y += 18
		}
		app.gg.draw_text(inner_x, cy0 + ch - 18, 'CI watcher debounced 16ms distinct-until-changed • bottom terminal streams live logs', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
	} else if app.insights_tab == 'realtime' {
		draw_insights_realtime(mut app, cy0, ch, inner_x, inner_y, inner_w)
	} else if app.insights_tab == 'gallery' {
		draw_insights_gallery(mut app, cy0, ch, inner_x, inner_y, inner_w)
	} else {
		app.gg.draw_text(inner_x, inner_y + 20, 'Select a tab above — Cost, Waterfall, Spans, Budgets, CI, Realtime, Gallery', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
	}
}

// draw_insights_realtime — live EventBus feed + GOD envelope flow (6th tab, native parity with web)
fn draw_insights_realtime(mut app GuiApp, cy0 int, ch int, inner_x int, inner_y int, inner_w int) {
	app.gg.draw_text(inner_x, inner_y, 'Realtime — EventBus live feed (swarm_handoff · state_changed · process_log)', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
	app.gg.draw_text(inner_x, inner_y + 18, 'GOD envelopes ${app.god_inbox} in · ${app.god_outbox} out · rev ${app.engine_rev} · api ${app.api_calls} — one tick, no polling', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	// GOD flow meter reflects observed envelopes only; zero is a valid idle state.
	app.gg.draw_rect_filled(inner_x, inner_y + 36, inner_w, 10, app.pnl_card)
	if app.god_inbox > 0 || app.god_outbox > 0 {
		app.gg.draw_rect_filled(inner_x, inner_y + 36, inner_w / 3, 10, tint(app.pnl_select, 110))
	}
	app.gg.draw_rect_empty(inner_x, inner_y + 36, inner_w, 10, app.pnl_border)
	app.gg.draw_text(inner_x + inner_w - 110, inner_y + 37, 'Observed flow', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
	// live feed — engine log collector, newest last
	all_logs := collect_engine_logs(app)
	mut y := inner_y + 58
	avail := cy0 + ch - 40 - y
	mut vis := avail / 17
	if vis < 1 {
		vis = 1
	}
	mut start := all_logs.len - vis
	if start < 0 {
		start = 0
	}
	for idx in start .. all_logs.len {
		l := all_logs[idx]
		row := idx - start
		yy := y + row * 17
		bg2 := if row % 2 == 0 { app.pnl_card } else { app.pnl_bg }
		app.gg.draw_rect_filled(inner_x, yy, inner_w, 16, bg2)
		app.gg.draw_rect_filled(inner_x + 4, yy + 5, 5, 5, term_level_color(l.level))
		app.gg.draw_text(inner_x + 16, yy + 2, l.ts, gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
		app.gg.draw_text(inner_x + 90, yy + 2, l.source, gg.TextCfg{ color: app.pnl_text_mut, size: 11, mono: true })
		mut msg := l.msg
		if msg.len > 52 {
			msg = msg[..52] + '…'
		}
		app.gg.draw_text(inner_x + 170, yy + 2, msg, gg.TextCfg{ color: app.pnl_text, size: 11 })
	}
	app.gg.draw_text(inner_x, cy0 + ch - 22, 'Feed via desktop_engine EventBus · durable receipts · VJOBS=2 serialized', gg.TextCfg{ color: app.pnl_text_mut, size: 10 })
}

// draw_insights_gallery — the living stationery style-guide (7th tab: brand + tokens)
fn draw_insights_gallery(mut app GuiApp, cy0 int, ch int, inner_x int, inner_y int, inner_w int) {
	app.gg.draw_text(inner_x, inner_y, 'Gallery — the Paper Co. design system, live from tokens', gg.TextCfg{ color: app.pnl_text, size: 13, bold: true })
	app.gg.draw_text(inner_x, inner_y + 18, 'filing-cabinet: canvas #F3EBDD · paper #FFF9ED · cabinet #171C1F · selection #9A6416', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	// palette swatches — paint chips (paper-sample card)
	swatch_names := ['paper', 'cream', 'manila', 'kraft', 'steel', 'ink', 'rust', 'brass', 'sage']
	swatch_cols := [app.pnl_bg, app.pnl_bg, app.pnl_card_sel, app.pnl_border, app.pnl_text_mut,
		app.pnl_text, app.pnl_danger, app.pnl_select, app.pnl_success]
	dark_swatches := ['ink', 'rust', 'brass']
	mut sx := inner_x
	mut sy := inner_y + 44
	for i in 0 .. swatch_names.len {
		if i == 5 {
			sx = inner_x
			sy += 64
		}
		app.gg.draw_rect_filled(sx, sy, 74, 44, swatch_cols[i])
		app.gg.draw_rect_empty(sx, sy, 74, 44, app.pnl_border)
		swatch_txt_col := if swatch_names[i] in dark_swatches { app.pnl_bg } else { app.pnl_text }
		app.gg.draw_text(sx + 6, sy + 30, swatch_names[i], gg.TextCfg{
			color: swatch_txt_col
			size: 10
			bold: true
		})
		sx += 80
	}
	// type specimens
	ty := sy + 84
	app.gg.draw_text(inner_x, ty, 'Fraunces Display — letterheads & headlines 22', gg.TextCfg{
		color: app.pnl_text
		size: 22
		family: app.fonts.display
	})
	app.gg.draw_text(inner_x, ty + 34, 'IBM Plex Sans — body copy 15, the humanist grotesk of the office memo.', gg.TextCfg{ color: app.pnl_text, size: 15 })
	app.gg.draw_text(inner_x, ty + 58, 'IBM Plex Mono — receipts, logs, 13px typewriter', gg.TextCfg{ color: app.pnl_text_mut, size: 13, mono: true })
	// components row — buttons + rivet card
	comp_y := ty + 92
	app.gg.draw_rect_filled(inner_x, comp_y, 96, 22, app.pnl_select)
	app.gg.draw_text(inner_x + 24, comp_y + 5, 'Primary', gg.TextCfg{ color: app.pnl_text, size: 11, bold: true })
	app.gg.draw_rect_filled(inner_x + 108, comp_y, 96, 22, app.pnl_bg)
	app.gg.draw_rect_empty(inner_x + 108, comp_y, 96, 22, app.pnl_border)
	app.gg.draw_text(inner_x + 130, comp_y + 5, 'Paper', gg.TextCfg{ color: app.pnl_text_mut, size: 11 })
	app.gg.draw_rect_filled(inner_x + 216, comp_y, 96, 22, app.pnl_card_sel)
	app.gg.draw_rect_empty(inner_x + 216, comp_y, 96, 22, app.pnl_border_hi)
	app.gg.draw_text(inner_x + 240, comp_y + 5, 'Manila', gg.TextCfg{ color: app.pnl_text, size: 11 })
	app.gg.draw_rect_filled(inner_x + 324, comp_y, 96, 22, app.pnl_danger)
	app.gg.draw_text(inner_x + 348, comp_y + 5, 'Rust', gg.TextCfg{ color: app.pnl_bg, size: 11, bold: true })
	// rivet card specimen
	rc_x := inner_x + inner_w - 190
	app.gg.draw_rect_filled(rc_x, comp_y - 6, 180, 66, app.pnl_card)
	app.gg.draw_rect_empty(rc_x, comp_y - 6, 180, 66, app.pnl_border)
	app.gg.draw_rect_filled(rc_x + 6, comp_y, 6, 6, tint(app.pnl_select, 180))
	app.gg.draw_rect_filled(rc_x + 168, comp_y, 6, 6, tint(app.pnl_select, 180))
	app.gg.draw_text(rc_x + 20, comp_y + 12, 'Rivet card', gg.TextCfg{
		color: app.pnl_text
		size: 14
		family: app.fonts.display
	})
	app.gg.draw_text(rc_x + 20, comp_y + 30, 'perforated feed strip', gg.TextCfg{ color: app.pnl_text_mut, size: 10, mono: true })
	gallery_note := 'tokens: theme/tokens.v · Fraunces + IBM Plex OFL in assets/fonts · 4-lang EN/ES/中文/عربي'
	app.gg.draw_text(inner_x, cy0 + ch - 22, gallery_note, lang_cfg(app, gallery_note, gg.TextCfg{ color: app.pnl_text_mut, size: 10 }))
}

fn draw_inspector(mut app GuiApp, w int, h int) {
	term_h_i := if app.term_visible { app.term_height } else { 0 }
	ix := inspector_x(app, w)
	iy := 52
	iw := 300
	ih := h - 52 - 28 - term_h_i
	app.gg.draw_rect_filled(ix, iy, iw, ih, col_charcoal)
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
			app.gg.draw_text(ix + 12, iy + 250, 'This is the live Engine inspector. No mock —', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
			app.gg.draw_text(ix + 12, iy + 262, 'reads from desktop_engine snapshot.', gg.TextCfg{ color: app.pnl_text_mut, size: 12 })
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
	// scrollable log window inside inspector
	mut inspector_log_h := ih - 310 - header_off
	if inspector_log_h < 40 {
		inspector_log_h = 40
	}
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
	log_y0 := iy + 302 + header_off
	// background for log area — xterm-like ink
	app.gg.draw_rect_filled(ix + 8, log_y0 - 2, iw - 16, inspector_log_h + 4, term_bg)
	app.gg.draw_rect_empty(ix + 8, log_y0 - 2, iw - 16, inspector_log_h + 4, col_line)
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
					app.pnl_bg} else {
					col_text_on_cabinet}
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
}

fn draw_terminal(mut app GuiApp, w int, h int) {
	term_h := app.term_height
	y0 := h - 28 - term_h
	x0 := 200
	tw := w - 200
	// background — xterm ink, workshop border
	app.gg.draw_rect_filled(x0, y0, tw, term_h, term_bg)
	app.gg.draw_line(x0, y0, w, y0, term_border)
	app.gg.draw_line(x0, y0, x0, y0 + term_h, term_border)
	// header bar — charcoal with brass accent — libghostty-vt
	app.gg.draw_rect_filled(x0, y0, tw, 24, term_header_bg)
	app.gg.draw_line(x0, y0 + 24, w, y0 + 24, col_line)
	app.gg.draw_rect_filled(x0, y0, 3, 24, col_brass)
	app.gg.draw_text(x0 + 12, y0 + 7, 'GHOSTTY VT', gg.TextCfg{ color: col_paper, size: 13, bold: true, mono: true })
	app.gg.draw_text(x0 + 100, y0 + 8, 'claude · opencode · fleet — \\`help · \\`clear', gg.TextCfg{ color: col_slate, size: 11, mono: true })
	// focus pill — Tab flips ghost focus (type into the embedded terminal)
	focus_x := x0 + 320
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
	filtered := filtered_palette(app.palette_query)
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
		pal_label := tr(app, 'palette.' + it.id)
		// R2 product-truth: CLI-action rows render live Engine counts, never
		// the hardcoded historical numbers in palette_items().
		pal_desc := if it.id == 'skills_sync' {
			'Sync and validate ${skills_total(mut app)} skills'
		} else if it.id == 'mcp_health' {
			'Health of ${mcp_total(mut app)} providers'
		} else if tr(app, 'pdesc.' + it.id) != 'pdesc.' + it.id {
			tr(app, 'pdesc.' + it.id)
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
				app.pnl_text_mut} else {
				app.pnl_text_mut}
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
	// footer hint paper tape
	app.gg.draw_text(cx + 16, cy + ph - 16, '↑↓ navigate  •  Enter to open  •  Type to filter ${skills_total(mut app)} skills  •  Ctrl± zoom', gg.TextCfg{ color: app.pnl_text_mut, size: scaled_size(11, z) })
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
	filtered := filtered_palette(app.palette_query)
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
	// navigating anywhere via palette dismisses the onboarding overlay
	if sel.id in ['world', 'skills', 'agents', 'mcp', 'targets', 'doctor', 'jobs', 'loops', 'swarm',
		'workspace', 'products', 'onboarding', 'insights'] {
		app.show_onboarding = sel.id == 'onboarding'
	}
	match sel.id {
		'world' {
			app.selected_panel = 0
		}
		'skills' {
			app.selected_panel = 1
		}
		'agents' {
			app.selected_panel = 2
		}
		'mcp' {
			app.selected_panel = 3
		}
		'targets' {
			app.selected_panel = 4
		}
		'doctor' {
			app.selected_panel = 5
		}
		'jobs' {
			app.selected_panel = 6
		}
		'loops' {
			app.selected_panel = 7
		}
		'swarm' {
			app.selected_panel = 8
		}
		'workspace' {
			app.selected_panel = 9
		}
		'workspace_sync' {
			app.selected_panel = 9
			app.inspector_msg = 'Workspace — pick or edit the path here; Validate checks it, Switch activates it'
		}
		'products' {
			app.selected_panel = 10
		}
		'onboarding' {
			app.selected_panel = 11
		}
		'insights' {
			app.selected_panel = 12
		}
		'serve' {
			app.inspector_msg = 'Serve: agent-toolkit serve --port 3847'
		}
		'theme' {
			cycle_appearance(mut app)
		}
		'doctor_fix' {
			app.selected_panel = 5
			app.inspector_msg = 'Doctor fix: running checks…'
		}
		'install' {
			app.selected_panel = 1
			app.inspector_msg = 'Install: agent-toolkit install --dry-run'
		}
		else {}
	}
	app.palette_open = false
	app.palette_query = ''
	app.palette_selected = 0
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
		// PTY session focus — keys go to the agent TUI pane under the cursor
		// (single session view or split pane under the mouse). Esc returns to Fleet.
		if app.term_mode == 2 && (app.term_view >= 15 || (app.term_split && app.term_view_b >= 15)) {
			if e.key_code == .escape {
				app.term_view = -1
				app.term_split = false
				return
			}
			// target pane: the one under the mouse (split) or the viewed session
			mut target := app.term_view
			if app.term_split {
				// split boundary ≈ mid content (pane A 208.., pane B ..1280)
				target = if app.mouse_x < app.gg.width / 2 + 100 {
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
		if app.term_search_open {
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
				app.palette_open = false
				app.palette_query = ''
				app.palette_selected = 0
				return
			}
			if e.key_code == .enter {
				activate_palette_selection(mut app)
				return
			}
			if e.key_code == .backspace {
				if app.palette_query.len > 0 {
					app.palette_query = app.palette_query[..app.palette_query.len - 1]
					// clamp selection after filtering narrows
					filtered := filtered_palette(app.palette_query)
					if app.palette_selected >= filtered.len {
						app.palette_selected = if filtered.len > 0 { filtered.len - 1 } else { 0 }
					}
				}
				return
			}
			if e.key_code == .up {
				filtered := filtered_palette(app.palette_query)
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
				filtered := filtered_palette(app.palette_query)
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
				filtered2 := filtered_palette(app.palette_query)
				if app.palette_selected >= filtered2.len && filtered2.len > 0 {
					app.palette_selected = filtered2.len - 1
				}
				return
			}
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
			if app.selected_panel in [1, 3] {
				app.skills_query = ''
				app.skills_domain = ''
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
		if e.key_code == .slash || (e.key_code == .k && is_mod) {
			app.palette_open = true
			app.palette_query = ''
			app.palette_selected = 0
			return
		}
		if e.char_code == `h` || e.char_code == `H` {
			app.show_help = !app.show_help
			return
		}
		if e.char_code == `r` || e.char_code == `R` {
			// Handoff requires a real Engine operation; do not claim routing here.
			desks := desks_for_app(app)
			if app.selected_desk >= 0 && app.selected_desk < desks.len {
				app.inspector_msg = 'Handoff unavailable: no active Engine operation for ${desks[app.selected_desk].label}'
			}
			return
		}
		// super potent IDE typing — skills 227 fuzzy + memory palace semantic recall + file-tree nav
		// When skills or workspace panels active, capture typing there instead of ghost (easy to manage, brokered)
		if !app.palette_open && !app.show_help {
			if app.selected_panel == 1 {
				// skills 227 search — backspace, escape clears, arrows scroll, printable appends
				if e.key_code == .backspace {
					if app.skills_query.len > 0 {
						app.skills_query = app.skills_query[..app.skills_query.len - 1]
					}
					app.skills_scroll = 0
					return
				}
				if e.key_code == .escape {
					app.skills_query = ''
					app.skills_domain = ''
					return
				}
				if e.key_code == .up {
					app.skills_scroll -= 1
					return
				}
				if e.key_code == .down {
					app.skills_scroll += 1
					return
				}
				if e.key_code == .enter {
					entries := skills_filtered_entries(mut app)
					if app.skills_selected >= 0 && app.skills_selected < entries.len {
						sel := entries[app.skills_selected]
						// super-potent: Enter toggles via Engine TX (install/remove) + receipt/provenance — one-click easy management
						if app.desktop != unsafe { nil } {
							rev := app.desktop.engine_toggle_skill(sel.id) or {
								app.inspector_msg = 'Skill ${sel.id} error: ${err}'
								return
							}
							installed_now := sel.id in app.desktop.engine_skills_installed()
							app.engine_rev = app.desktop.app_state_snapshot().revision
							if app.engine_rev == 0 {
								app.engine_rev = rev
							}
							app.api_calls = app.desktop.engine_api_calls()
							action := if installed_now { 'installed' } else { 'removed' }
							app.inspector_msg = 'Skill ${sel.id} ${action} rev=${rev} • receipt + provenance via Engine TX ✓'
						} else {
							app.inspector_msg = 'Skill ${sel.id} selected — install via Engine'
						}
					}
					return
				}
				// space also toggles when row selected — easy management
				if e.char_code == ` ` {
					entries := skills_filtered_entries(mut app)
					if app.skills_selected >= 0 && app.skills_selected < entries.len {
						sel := entries[app.skills_selected]
						if app.desktop != unsafe { nil } {
							rev := app.desktop.engine_toggle_skill(sel.id) or {
								app.inspector_msg = 'Skill ${sel.id} error: ${err}'
								return
							}
							installed_now := sel.id in app.desktop.engine_skills_installed()
							app.engine_rev = rev
							app.api_calls = app.desktop.engine_api_calls()
							action := if installed_now { 'installed' } else { 'removed' }
							app.inspector_msg = 'Skill ${sel.id} ${action} rev=${rev} • Engine TX'
							return
						}
					}
				}
				// MCP panel shares skills_query — when in MCP panel, arrows scroll and Enter toggles provider
				if app.selected_panel == 3 && e.key_code == .enter {
					q := app.skills_query
					provs := if q != '' {
						app.desktop.engine_mcp_search(q)
					} else {
						app.desktop.engine_mcp_catalog()
					}
					if provs.len > 0 {
						// toggle first filtered or selected? use 0 for super-potent easy management
						p := provs[0]
						rev := app.desktop.engine_mcp_toggle(p.id) or {
							app.inspector_msg = 'MCP ${p.id} toggle failed: ${err}'
							return
						}
						app.engine_rev = rev
						app.api_calls = app.desktop.engine_api_calls()
						app.inspector_msg = 'MCP ${p.id} toggled rev=${rev} • secret guard + provenance verified'
						return
					}
				}
				// documented panel shortcuts fall through to the global handler —
				// the Skills panel must not swallow digits/p/i/o into the filter
				if e.char_code > 32 && e.char_code < 127 && !is_panel_nav_key(e.char_code) {
					app.skills_query += rune(e.char_code).str()
					app.skills_scroll = 0
					return
				}
			}
			// MCP panel — shares skills_query fuzzy search, Enter toggles via Engine TX (super-potent)
			if app.selected_panel == 3 {
				if e.key_code == .backspace {
					if app.skills_query.len > 0 {
						app.skills_query = app.skills_query[..app.skills_query.len - 1]
					}
					return
				}
				if e.key_code == .escape {
					app.skills_query = ''
					return
				}
				if e.key_code == .enter {
					q := app.skills_query
					provs := if q != '' {
						app.desktop.engine_mcp_search(q)
					} else {
						app.desktop.engine_mcp_catalog()
					}
					if provs.len > 0 {
						p := provs[0]
						rev := app.desktop.engine_mcp_toggle(p.id) or {
							app.inspector_msg = 'MCP ${p.id} toggle failed: ${err}'
							return
						}
						app.engine_rev = rev
						app.api_calls = app.desktop.engine_api_calls()
						app.inspector_msg = 'MCP ${p.id} toggled rev=${rev} • secret guard + provenance verified • Engine TX'
						return
					}
				}
				// same nav-key fall-through as the Skills panel (see is_panel_nav_key)
				if e.char_code > 32 && e.char_code < 127 && !is_panel_nav_key(e.char_code) {
					app.skills_query += rune(e.char_code).str()
					return
				}
			}
			// Doctor panel — f fixes all via Engine TX, Enter opens dry-run preview
			// (Enter again confirms, Esc cancels), receipts/provenance verified
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
				// toggle terminal visibility
				app.term_visible = !app.term_visible
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
		if e.char_code == `m` || e.char_code == `M` {
			if app.selected_panel == 0 {
				app.office_map_view = !app.office_map_view
				app.inspector_msg = if app.office_map_view {
					'Floor map view enabled'
				} else {
					'Office overview enabled'
				}
			}
			return
		}
		if e.char_code == `o` || e.char_code == `O` {
			// super-potent: toggle onboarding wizard overlay / panel 11
			if app.show_onboarding && app.selected_panel == 11 {
				app.show_onboarding = false
			} else {
				select_panel(mut app, 11)
				app.onboarding_msg = 'Onboarding wizard toggled via o — 7 steps ready'
			}
			return
		}
		// onboarding wizard next/back when overlay visible (n/b, arrows, enter)
		if app.show_onboarding || app.selected_panel == 11 {
			if e.key_code == .right || e.char_code == `n` || e.char_code == `N` {
				if app.onboarding_step < 6 {
					app.onboarding_step++
					app.onboarding_msg = 'Step ${app.onboarding_step + 1}/7'
				} else {
					// complete onboarding via Engine
					if app.desktop != unsafe { nil } {
						rev := app.desktop.onboarding_complete(app.harness_root) or {
							app.onboarding_msg = 'complete failed: ${err}'
							0
						}
						if rev > 0 {
							app.show_onboarding = false
							app.selected_panel = 0
							app.onboarding_msg = 'Onboarding complete rev=${rev} ✓'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
				}
				return
			}
			if e.key_code == .left || e.char_code == `b` || e.char_code == `B` {
				if app.onboarding_step > 0 {
					app.onboarding_step--
					app.onboarding_msg = 'Step ${app.onboarding_step + 1}/7'
				}
				return
			}
			if e.key_code == .enter {
				// per-step enter triggers super-potent action
				match app.onboarding_step {
					4 {
						// workspace init
						harness := if app.onboarding_harness != '' {
							app.onboarding_harness
						} else {
							app.harness_root
						}
						rev := app.desktop.onboarding_ensure_workspace(harness) or {
							app.onboarding_msg = 'workspace init failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Workspace initialized rev=${rev} — harness ${harness}'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					5 {
						harness := if app.onboarding_harness != '' {
							app.onboarding_harness
						} else {
							app.harness_root
						}
						rev := app.desktop.onboarding_ensure_personas(harness) or {
							app.onboarding_msg = 'personas failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Personas bootstrapped rev=${rev} ✓'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					1 {
						// capability bulk install 5 via Engine
						cand := app.desktop.engine_skills_search(app.skills_query, app.skills_domain)
						mut ids := []string{}
						for i in 0 .. 5 {
							if i >= cand.len {
								break
							}
							ids << cand[i].id
						}
						if ids.len > 0 {
							rev := app.desktop.onboarding_bulk_install_skills(ids) or {
								app.onboarding_msg = 'capability bulk failed: ${err}'
								0
							}
							if rev > 0 {
								app.onboarding_msg = 'Installed ${ids.len} skills rev=${rev}'
								app.engine_rev = app.desktop.app_state_snapshot().revision
								app.api_calls = app.desktop.engine_api_calls()
							}
						}
					}
					2 {
						// targets bulk enable minimal 3
						ids := ['claude-code', 'opencode', 'cli']
						rev := app.desktop.onboarding_set_targets_bulk(ids) or {
							app.onboarding_msg = 'targets failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Targets enabled ${ids.join(',')} rev=${rev}'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					3 {
						rev := app.desktop.onboarding_set_products_bulk([
							'agent-toolkit-core',
						]) or {
							app.onboarding_msg = 'products failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Products set rev=${rev}'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					else {}
				}
				return
			}
			if e.key_code == .escape {
				app.show_onboarding = false
				app.onboarding_msg = 'Onboarding closed — press o to reopen'
				return
			}
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
		term_h := app.term_height
		y0 := h3 - 28 - term_h
		x0 := 200
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
		if app.term_visible && app.mouse_x >= x0 && app.mouse_x <= w3 && app.mouse_y >= y0 && app.mouse_y < y0 + term_h {
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
			term_h_ii := if app.term_visible { app.term_height } else { 0 }
			ix := w3 - 300
			iy := 52
			ih := h3 - 52 - 28 - term_h_ii
			log_y0 := iy + 302
			inspector_log_h := ih - 310
			if app.mouse_x >= ix && app.mouse_x <= w3 && app.mouse_y >= log_y0 && app.mouse_y < log_y0 + inspector_log_h {
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
		// skills virtualized scroll — 227 list
		if app.selected_panel == 1 {
			fx := 208
			fy := 52
			fw := w3 - 208 - 300
			term_h_sk := if app.term_visible { app.term_height } else { 0 }
			fh := h3 - 52 - 28 - term_h_sk
			y0_sk := fy + 102
			list_h := fh - 126
			if app.mouse_x >= fx + 12 && app.mouse_x <= fx + fw - 12 && app.mouse_y >= y0_sk && app.mouse_y < y0_sk + list_h {
				entries := skills_filtered_entries(mut app)
				visible := list_h / 28
				app.skills_scroll += delta
				app.skills_scroll = clamp_scroll(app.skills_scroll, entries.len, visible)
				return
			}
		}
		// jobs scroll — ProcessSupervisor queue distinct from loops budgets
		if app.selected_panel == 6 {
			fx := 208
			fy := 52
			fw := w3 - 208 - 300
			term_h_j := if app.term_visible { app.term_height } else { 0 }
			fh := h3 - 52 - 28 - term_h_j
			list_y0 := fy + 84
			list_h_total := fh - 84 - 110
			card_h := 52
			jobs := app.desktop.engine_jobs_catalog()
			visible := list_h_total / card_h
			aq_y := fy + fh - 104
			// if over approvals queue bottom, scroll that instead
			if app.mouse_x >= fx + 8 && app.mouse_x <= fx + fw - 8 && app.mouse_y >= aq_y && app.mouse_y < aq_y + 96 {
				aq := app.desktop.engine_approvals_queue()
				mut total := aq.len
				if total == 0 {
					total = app.approvals.len
				}
				app.jobs_approvals_scroll += delta
				app.jobs_approvals_scroll = clamp_scroll(app.jobs_approvals_scroll, total, 3)
				return
			}
			if app.mouse_x >= fx + 12 && app.mouse_x <= fx + fw - 12 && app.mouse_y >= list_y0 && app.mouse_y < list_y0 + list_h_total {
				app.jobs_scroll += delta
				app.jobs_scroll = clamp_scroll(app.jobs_scroll, jobs.len, visible)
				return
			}
		}
		// loops scroll — budgets L1/L2/L3 cream distinct from jobs dark
		if app.selected_panel == 7 {
			fx_l := 208
			fy_l := 52
			fw_l := w3 - 208 - 300
			term_h_l := if app.term_visible { app.term_height } else { 0 }
			fh_l := h3 - 52 - 28 - term_h_l
			ly0 := fy_l + 66
			card_h_l := 78
			mut loops := app.desktop.loops_catalog()
			visible_l := (fh_l - 90) / card_h_l
			if app.mouse_x >= fx_l + 12 && app.mouse_x <= fx_l + fw_l - 12 && app.mouse_y >= ly0 && app.mouse_y < ly0 + visible_l * card_h_l {
				app.loops_scroll += delta
				app.loops_scroll = clamp_scroll(app.loops_scroll, loops.len, visible_l)
				return
			}
		}
		// workspace IDE scroll — file tree, editor, git, memory palace (super potent)
		if app.selected_panel == 9 {
			l := workspace_layout(app, w3, h3)
			// file tree left
			ft_x := l.fx + 12
			ft_y := l.mid_y
			ft_w := 180
			if app.mouse_x >= ft_x && app.mouse_x <= ft_x + ft_w && app.mouse_y >= ft_y && app.mouse_y < ft_y + l.mid_h {
				flat := file_tree_visible(app)
				visible := (l.mid_h - 28) / 18
				app.file_tree_scroll += delta
				app.file_tree_scroll = clamp_scroll(app.file_tree_scroll, flat.len, visible)
				return
			}
			// editor center
			ed_x := l.fx + 12 + 180 + 4
			ed_w := l.fw - 24 - 180 - 4 - 240
			if app.mouse_x >= ed_x && app.mouse_x <= ed_x + ed_w && app.mouse_y >= l.mid_y && app.mouse_y < l.mid_y + l.mid_h {
				app.editor_scroll += delta
				return
			}
			// git right
			gx := l.fx + l.fw - 240 - 12
			if app.mouse_x >= gx && app.mouse_x <= gx + 240 && app.mouse_y >= l.mid_y && app.mouse_y < l.mid_y + l.mid_h {
				if app.git_rail == 'CHANGES' {
					changes := app.desktop.engine_git_changes()
					visible := (l.mid_h - 20) / 20
					app.git_scroll += delta
					app.git_scroll = clamp_scroll(app.git_scroll, changes.len, visible)
				} else if app.git_rail == 'HISTORY' {
					graph := app.desktop.engine_git_graph(20)
					visible := (l.mid_h - 40) / 22
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
				filtered := filtered_palette(app.palette_query)
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
		// Header controls share the same geometry as draw_header.
		w := app.gg.width
		h := app.gg.height
		if my >= 0 && my <= 44 {
			wx := header_workspace_x()
			ww := header_workspace_w(w)
			if mx >= wx && mx <= wx + ww && my >= 6 && my <= 38 {
				focus_workspace(mut app)
				return
			}
			sx := header_search_x(w)
			sw := header_search_w(w)
			if mx >= sx && mx <= sx + sw && my >= 8 && my <= 36 {
				if mx >= sx + sw - 20 && app.global_search != '' {
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
			for idx, lang in [Lang.en, Lang.es, Lang.zh, Lang.ar] {
				chip_x := w - 180 + idx * 34
				if mx >= chip_x && mx <= chip_x + 30 && my >= 10 && my <= 32 {
					app.lang = lang
					app.header_search_focus = false
					app.workspace_focus = false
					return
				}
			}
			if mx >= w - 42 && mx <= w - 12 && my >= 8 && my <= 36 {
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
		// Inspector buttons — clickable
		ix := inspector_x(app, w)
		iy := 52
		iw := 300
		// Only when a desk selected
		desks := desks_for_app(app)
		if app.selected_desk >= 0 && app.selected_desk < desks.len {
			if mx >= ix + 12 && mx <= ix + iw - 12 && my >= iy + 180 && my <= iy + 208 {
				app.term_visible = true
				app.term_mode = 1
				app.ghost_focused = true
				app.inspector_msg = 'Terminal opened: ${desks[app.selected_desk].label}'
				return
			}
			if mx >= ix + 12 && mx <= ix + iw - 12 && my >= iy + 214 && my <= iy + 242 {
				app.inspector_msg = 'Handoff unavailable: no active Engine operation for ${desks[app.selected_desk].label}'
				return
			}
		}
		// Help overlay click dismiss
		if app.show_help {
			app.show_help = false
			return
		}
		// Terminal click — super potent: focus Ghostty + copy
		if app.term_visible {
			w3 := app.gg.width
			h3 := app.gg.height
			term_h := app.term_height
			y0 := h3 - 28 - term_h
			x0 := 200
			tw := w3 - 200
			content_y := y0 + 28
			content_x := x0 + 8
			content_w := tw - 16
			// header click: height mode buttons (1×/2×/MAX/×) — else toggle ghost focus
			if mx >= x0 && mx <= w3 && my >= y0 && my < y0 + 24 {
				if mx >= x0 + tw - 148 && mx <= x0 + tw - 16 {
					btn := (mx - (x0 + tw - 148)) / 34
					if btn >= 0 && btn <= 3 {
						app.term_mode = btn
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
			if mx >= x0 && mx <= w3 && my >= y0 && my < y0 + term_h {
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
			term_h_ii := if app.term_visible { app.term_height } else { 0 }
			ix2 := inspector_x(app, w)
			iy2 := 52
			ih2 := h - 52 - 28 - term_h_ii
			log_y0 := iy2 + 302
			inspector_log_h := ih2 - 310
			if mx >= ix2 + 8 && mx <= ix2 + 300 - 8 && my >= log_y0 && my < log_y0 + inspector_log_h {
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
		dock_l_c := dock_x(app, w) + 8
		if mx >= dock_l_c && mx <= dock_l_c + dock_w - 16 {
			for row in nav_rows(app, h) {
				if my >= row.y && my <= row.y + row.h {
					select_panel(mut app, row.panel)
					return
				}
			}
		}
		// Onboarding wizard click handling — super-potent easy management via Engine
		if app.show_onboarding || app.selected_panel == 11 {
			w2 := app.gg.width
			h2 := app.gg.height
			term_h_on := if app.term_visible { app.term_height } else { 0 }
			is_overlay := app.show_onboarding && app.selected_panel != 11
			mut fx := if is_overlay { 240 } else { 208 }
			mut fw := if is_overlay { w2 - 480 } else { w2 - 208 - 300 }
			if fw < 520 {
				fw = if is_overlay { 640 } else { w2 - 208 - 300 }
				fx = if is_overlay { (w2 - fw) / 2 } else { 208 }
			}
			fy := 52
			mut fh2 := h2 - 52 - 28 - term_h_on
			if fh2 < 400 {
				fh2 = 400
			}
			mut fh := fh2
			// close X in overlay
			if is_overlay && mx >= fx + fw - 32 && mx <= fx + fw - 8 && my >= fy + 6 && my <= fy + 30 {
				app.show_onboarding = false
				app.onboarding_msg = 'Onboarding closed via ×'
				return
			}
			// step tabs 0..6 at fy+40
			y_tabs := fy + 40
			mut tab_x := fx + 10
			for si in 0 .. 7 {
				sname := ['Detect', 'Capabilities', 'Targets', 'Products', 'Workspace', 'Personas',
					'Done'][si]
				tw := sname.len * 7 + 16
				if tab_x + tw > fx + fw - 10 {
					break
				}
				if mx >= tab_x && mx <= tab_x + tw && my >= y_tabs && my <= y_tabs + 18 {
					app.onboarding_step = si
					app.onboarding_msg = 'Step ${si + 1}/7 selected'
					return
				}
				tab_x += tw + 4
			}
			// footer Back / Next
			if app.onboarding_step > 0 && mx >= fx + fw - 220 && mx <= fx + fw - 156 && my >= fy + fh - 32 && my <= fy + fh - 12 {
				app.onboarding_step--
				app.onboarding_msg = 'Back to step ${app.onboarding_step + 1}/7'
				return
			}
			if mx >= fx + fw - 148 && mx <= fx + fw - 76 && my >= fy + fh - 32 && my <= fy + fh - 12 {
				if app.onboarding_step < 6 {
					app.onboarding_step++
					app.onboarding_msg = 'Next to step ${app.onboarding_step + 1}/7'
				} else {
					rev := app.desktop.onboarding_complete(app.harness_root) or {
						app.onboarding_msg = 'complete failed: ${err}'
						0
					}
					if rev > 0 {
						app.show_onboarding = false
						app.selected_panel = 0
						app.onboarding_msg = 'Onboarding complete rev=${rev} ✓'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
				}
				return
			}
			// Skip — dismiss overlay without persisting complete (super-potent)
			if mx >= fx + fw - 294 && mx <= fx + fw - 238 && my >= fy + fh - 32 && my <= fy + fh - 12 {
				app.show_onboarding = false
				if app.selected_panel == 11 {
					app.selected_panel = 0
				}
				app.onboarding_msg = 'Onboarding skipped — press o to reopen'
				return
			}
			// per-step action buttons
			y_harness := fy + 40 + 24 + 38
			content_y := y_harness + 24
			// Workspace step 4 init buttons
			if app.onboarding_step == 4 {
				if mx >= fx + 20 && mx <= fx + 150 && my >= content_y + 82 && my <= content_y + 106 {
					harness := if app.onboarding_harness != '' {
						app.onboarding_harness
					} else {
						app.harness_root
					}
					rev := app.desktop.onboarding_ensure_workspace(harness) or {
						app.onboarding_msg = 'workspace init failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'Workspace initialized rev=${rev}'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
				if mx >= fx + 158 && mx <= fx + 298 && my >= content_y + 82 && my <= content_y + 106 {
					harness := if app.onboarding_harness != '' {
						app.onboarding_harness
					} else {
						app.harness_root
					}
					rev := app.desktop.onboarding_init_with_templates(harness, true) or {
						app.onboarding_msg = 'init+personas failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'Workspace+Personas rev=${rev} ✓'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
			}
			if app.onboarding_step == 5 {
				if mx >= fx + 20 && mx <= fx + 150 && my >= content_y + 148 && my <= content_y + 170 {
					harness := if app.onboarding_harness != '' {
						app.onboarding_harness
					} else {
						app.harness_root
					}
					rev := app.desktop.onboarding_ensure_personas(harness) or {
						app.onboarding_msg = 'personas failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'Personas bootstrapped rev=${rev} ✓'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
			}
			if app.onboarding_step == 1 {
				// Install 5 button at content_y+content_h-54 96x20 fw-120
				content_h := fh - (content_y - fy) - 52
				if mx >= fx + fw - 120 && mx <= fx + fw - 24 && my >= content_y + content_h - 54 && my <= content_y + content_h - 34 {
					cand := app.desktop.engine_skills_search(app.skills_query, app.skills_domain)
					mut ids := []string{}
					for i in 0 .. 5 {
						if i >= cand.len {
							break
						}
						ids << cand[i].id
					}
					if ids.len > 0 {
						rev := app.desktop.onboarding_bulk_install_skills(ids) or {
							app.onboarding_msg = 'bulk install failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Installed ${ids.len} skills rev=${rev}'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					return
				}
			}
			if app.onboarding_step == 2 {
				mut fh2b := fh
				content_h := fh2b - (content_y - fy) - 52
				if mx >= fx + 20 && mx <= fx + 110 && my >= content_y + content_h - 40 && my <= content_y + content_h - 22 {
					ids := ['claude-code', 'opencode', 'cli']
					rev := app.desktop.onboarding_set_targets_bulk(ids) or {
						app.onboarding_msg = 'targets failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'Targets minimal rev=${rev}'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
				if mx >= fx + 118 && mx <= fx + 208 && my >= content_y + content_h - 40 && my <= content_y + content_h - 22 {
					// R2 product-truth: enable-all covers the Engine catalog roster.
					ids := app.desktop.engine_targets().map(it.id)
					rev := app.desktop.onboarding_set_targets_bulk(ids) or {
						app.onboarding_msg = 'targets all failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'All ${ids.len} targets rev=${rev}'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
			}
			if app.onboarding_step == 3 {
				mut fh2c := fh
				content_h := fh2c - (content_y - fy) - 52
				_ = content_h
				// any click in products content advances? handle via next
			}
			if app.onboarding_step == 6 {
				if mx >= fx + 20 && mx <= fx + 130 && my >= content_y + 84 && my <= content_y + 106 {
					rev := app.desktop.onboarding_complete(app.harness_root) or {
						app.onboarding_msg = 'complete failed: ${err}'
						0
					}
					if rev > 0 {
						app.show_onboarding = false
						app.selected_panel = 0
						app.onboarding_msg = 'Onboarding complete rev=${rev} ✓ — welcome to Workshop'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
				if mx >= fx + 138 && mx <= fx + 248 && my >= content_y + 84 && my <= content_y + 106 {
					app.show_onboarding = false
					app.selected_panel = 0
					app.onboarding_msg = 'Back to World'
					return
				}
			}
		}
		// Products catalog — distinct overlay with install buttons, super-potent easy management via Engine
		if app.selected_panel == 10 {
			// products cards: Install at fw-160, Manage at fw-90 — distinct from onboarding
			w2p := app.gg.width
			h2p := app.gg.height
			term_h_p := if app.term_visible { app.term_height } else { 0 }
			fx_p := 208
			fy_p := 52
			fw_p := w2p - 208 - 300
			fh_p := h2p - 52 - 28 - term_h_p
			card_y0 := fy_p + 48
			card_h := 52
			visible_p := (fh_p - 70) / card_h
			if visible_p > 0 {
				prods_p := app.desktop.engine_products_catalog()
				start_p := clamp_scroll(app.products_scroll, prods_p.len, visible_p)
				mut end_p := start_p + visible_p
				if end_p > prods_p.len {
					end_p = prods_p.len
				}
				for idx in start_p .. end_p {
					row := idx - start_p
					y := card_y0 + row * card_h
					// Install button hit — distinct install per product via Engine bulk
					if mx >= fx_p + fw_p - 160 && mx <= fx_p + fw_p - 104 && my >= y + 26 && my <= y + 42 {
						p := prods_p[idx]
						rev := app.desktop.onboarding_set_products_bulk([p.id]) or {
							app.onboarding_msg = 'products install failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Product ${p.id} installed rev=${rev} ✓'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
						app.products_hover = idx
						return
					}
					// Manage button hit — shows provenance receipt (super-potent)
					if mx >= fx_p + fw_p - 90 && mx <= fx_p + fw_p - 34 && my >= y + 26 && my <= y + 42 {
						p := prods_p[idx]
						app.inspector_msg = 'Manage ${p.id}: ${p.provenance} • receipt ${p.receipt_path}'
						app.products_hover = idx
						return
					}
					// card body click selects hover for keyboard/drag feedback
					if mx >= fx_p + 14 && mx <= fx_p + fw_p - 14 && my >= y + 2 && my <= y + 46 {
						app.products_hover = idx
					}
				}
			}
		}
		// Skills panel — domain chips + virtualized list install (227 searchable, brokered via Engine TX, receipts/provenance)
		if app.selected_panel == 1 {
			fx := 208
			fy := 52
			fw := w - 208 - 300
			// domain chips hit at fy+80 — 14 domains, one-click filter via Engine fuzzy
			domains := ['all', 'core', 'delivery', 'design', 'forge', 'integrations', 'data',
				'tooling', 'ops', 'loops', 'quality', 'architecture', 'cloud', 'agentic-security']
			y_chip := fy + 80
			mut chip_x := fx + 12
			for d in domains {
				label := if d == 'all' { 'all ${skills_total(mut app)}' } else { d }
				wc := label.len * 7 + 16
				if chip_x + wc > fx + fw - 12 {
					break
				}
				if mx >= chip_x && mx <= chip_x + wc && my >= y_chip && my <= y_chip + 18 {
					app.skills_domain = if d == 'all' { '' } else { d }
					app.skills_scroll = 0
					app.skills_selected = 0
					app.inspector_msg = if d == 'all' {
						'Filter: all ${skills_total(mut app)} skills'
					} else {
						'Filter: ${d} domain via Engine.skills_search'
					}
					return
				}
				chip_x += wc + 6
			}
			// list rows at fy+102 — virtualized 60 FPS, install/remove via Engine Transaction + receipt/provenance display
			y0 := fy + 102
			entries := skills_filtered_entries(mut app)
			row_h := 28
			visible := (h - 52 - 28 - (if app.term_visible { app.term_height } else { 0 }) - 126) / row_h
			if visible > 0 {
				start := clamp_scroll(app.skills_scroll, entries.len, visible)
				mut end_sk := start + visible
				if end_sk > entries.len {
					end_sk = entries.len
				}
				for idx in start .. end_sk {
					row := idx - start
					y := y0 + row * row_h
					if mx >= fx + 12 && mx <= fx + fw - 12 && my >= y && my <= y + 24 {
						app.skills_selected = idx
						// install/remove on right side — super-potent one-click Engine TX (no shell)
						if mx >= fx + fw - 80 {
							sel := entries[idx]
							if app.desktop != unsafe { nil } {
								// toggle via Engine: installs if missing, removes if present → StateRepository TX + receipt + provenance
								rev := app.desktop.engine_toggle_skill(sel.id) or {
									app.inspector_msg = 'Skill ${sel.id} error: ${err}'
									return
								}
								// receipt + provenance after toggle for display parity (provenance via Engine receipt verified)
								receipt_exists := if _ := app.desktop.engine_skill_receipt(sel.id) {
									true
								} else {
									false
								}
								_ = receipt_exists
								installed_now := sel.id in app.desktop.engine_skills_installed()
								app.engine_rev = app.desktop.app_state_snapshot().revision
								if app.engine_rev == 0 {
									app.engine_rev = rev
								}
								app.api_calls = app.desktop.engine_api_calls()
								action := if installed_now { 'installed' } else { 'removed' }
								app.inspector_msg = 'Skill ${sel.id} ${action} rev=${rev} • receipt provenance ✓ • Engine TX'
							} else {
								app.inspector_msg = 'Skill install queued: ${sel.id} via Engine transaction'
							}
						} else {
							sel := entries[idx]
							// show receipt/provenance for selected even without toggle
							if app.desktop != unsafe { nil } {
								if r := app.desktop.engine_skill_receipt(sel.id) {
									app.inspector_msg = 'Receipt: ${r.skill_id} ${r.installed_at} digest=${r.digest} • provenance verified'
								} else {
									app.inspector_msg = 'Selected ${sel.id} — click install → Engine TX + receipt ~/.config/agent-toolkit/receipts'
								}
							}
						}
						return
					}
				}
			}
			// search bar click focuses — brokered 227 fuzzy searchable
			if mx >= fx + 12 && mx <= fx + fw - 12 && my >= fy + 48 && my <= fy + 76 {
				app.palette_open = false
				app.inspector_msg = 'Skills search focused — type to filter ${skills_total(mut app)} (fuzzy substring+subsequence+word-boundary via Engine)'
				return
			}
		}
		// MCP panel — super-potent easy management: search fuzzy, toggle via Engine TX, secret guard, provenance + receipt display
		if app.selected_panel == 3 {
			fx_m := 208
			fy_m := 52
			fw_m := w - 208 - 300
			// provider drawer is modal: Probe / Open template / Close first (#1106)
			if app.mcp_drawer != '' {
				dx, dy, _, dh := mcp_drawer_geom(panel_fx(app), fy_m, panel_fw(app, w))
				if mx >= dx + 14 && mx <= dx + 124 && my >= dy + dh - 32 && my <= dy + dh - 10 {
					mcp_run_probe(mut app, app.mcp_drawer)
					return
				}
				if mx >= dx + 134 && mx <= dx + 284 && my >= dy + dh - 32 && my <= dy + dh - 10 {
					mut tpath := ''
					for p in app.desktop.engine_mcp_catalog() {
						if p.id == app.mcp_drawer {
							tpath = p.template_path
							break
						}
					}
					did := app.mcp_drawer
					mcp_open_template(mut app, did, tpath)
					return
				}
				if mx >= dx + 294 && mx <= dx + 374 && my >= dy + dh - 32 && my <= dy + dh - 10 {
					app.mcp_drawer = ''
					app.inspector_msg = 'MCP drawer closed'
					return
				}
				return
			}
			// search bar hit — mirrors draw_mcp (fx+12, fy+48, fw-24, 26)
			if mx >= fx_m + 12 && mx <= fx_m + fw_m - 12 && my >= fy_m + 48 && my <= fy_m + 74 {
				app.inspector_msg = 'MCP search focused — fuzzy via Engine.mcp_catalog_search (try github, slack)'
				return
			}
			// provider rows mirror draw_mcp (y0 = fy+84, 28px, 7 rows); the old
			// fy+58 origin misaligned clicks by a full row (#1106)
			y0_m := fy_m + 84
			search_q := if app.selected_panel == 3 { app.skills_query } else { '' }
			provs_m := if search_q != '' {
				app.desktop.engine_mcp_search(search_q)
			} else {
				app.desktop.engine_mcp_catalog()
			}
			for i, p in provs_m {
				if i >= 7 {
					break
				}
				y := y0_m + i * 28
				if mx >= fx_m + 12 && mx <= fx_m + fw_m - 12 && my >= y && my <= y + 24 {
					// right toggle hit
					if mx >= fx_m + fw_m - 100 {
						if app.desktop != unsafe { nil } {
							rev := app.desktop.engine_mcp_toggle(p.id) or {
								app.inspector_msg = 'MCP ${p.id} toggle failed: ${err} (secret guard? use \${ENV_VAR})'
								return
							}
							prov_json := app.desktop.engine_mcp_provenance_json(p.id)
							app.engine_rev = app.desktop.app_state_snapshot().revision
							if app.engine_rev == 0 {
								app.engine_rev = rev
							}
							app.api_calls = app.desktop.engine_api_calls()
							app.inspector_msg = 'MCP ${p.id} toggled rev=${rev} • ${prov_json} • Engine TX provenance verified'
						}
					} else {
						// row body → masked drawer (#1106)
						mcp_drawer_open(mut app, p.id, p.template_path, p.provenance)
					}
					return
				}
			}
		}
		// Doctor panel — Fix All + per-check fix via Engine TX, receipts/provenance verification display
		if app.selected_panel == 5 {
			fx_d := 208
			fy_d := 52
			fw_d := w - 208 - 300
			// dry-run preview is modal: Confirm/Cancel first (#1108)
			if app.doctor_preview != '' {
				px, py, _, ph := doctor_preview_geom(panel_fx(app), fy_d, panel_fw(app, w))
				if mx >= px + 14 && mx <= px + 134 && my >= py + ph - 32 && my <= py + ph - 10 {
					doctor_preview_confirm(mut app)
					return
				}
				if mx >= px + 144 && mx <= px + 234 && my >= py + ph - 32 && my <= py + ph - 10 {
					app.doctor_preview = ''
					app.doctor_preview_lines = []
					app.inspector_msg = 'Doctor dry-run cancelled — nothing was written'
					return
				}
				return
			}
			// Fix All hit
			if mx >= fx_d + fw_d - 90 && mx <= fx_d + fw_d - 10 && my >= fy_d + 8 && my <= fy_d + 28 {
				if app.desktop != unsafe { nil } {
					rev := app.desktop.engine_doctor_fix_all() or {
						app.inspector_msg = 'Doctor fix all failed: ${err}'
						return
					}
					app.engine_rev = app.desktop.app_state_snapshot().revision
					if app.engine_rev == 0 {
						app.engine_rev = rev
					}
					app.api_calls = app.desktop.engine_api_calls()
					app.doctor_preview = ''
					app.doctor_preview_lines = []
					app.inspector_msg = if rev == 0 {
						'Doctor: all fixable already pass ✓'
					} else {
						'Doctor Fix All rev=${rev} — receipts/provenance verified via Engine TX'
					}
				}
				return
			}
			// facet-chip hit — fix that category via Engine TX (#1108)
			for chip in app.doctor_chips {
				if mx >= chip.x && mx <= chip.x + chip.w && my >= chip.y && my <= chip.y + chip.h {
					rev := app.desktop.engine_doctor_fix_category(chip.cat) or {
						app.inspector_msg = 'Doctor category fix ${chip.cat} failed: ${err}'
						return
					}
					app.engine_rev = app.desktop.app_state_snapshot().revision
					if app.engine_rev == 0 {
						app.engine_rev = rev
					}
					app.api_calls = app.desktop.engine_api_calls()
					app.inspector_msg = if rev == 0 {
						'Doctor ${chip.cat}: nothing fixable — all pass ✓'
					} else {
						'Doctor ${chip.cat} fixed rev=${rev} via Engine TX'
					}
					return
				}
			}
			// per-check fix hit — rows at fy+50, 24px. The visible-row cap must
			// mirror draw_doctor exactly (list_h = fh-78, 24px rows); a fixed
			// cap leaves deep rows unclickable and risks matching unrendered
			// rows against footer pixels (#1108).
			term_h_d := if app.term_visible { app.term_height } else { 0 }
			fh_d := h - 52 - 28 - term_h_d
			list_h_d := fh_d - 78
			max_vis_d := if list_h_d < 40 { 0 } else { list_h_d / 24 }
			y0_d := fy_d + 50
			checks_d := app.desktop.engine_doctor()
			for i, c in checks_d {
				if i >= max_vis_d {
					break
				}
				y := y0_d + i * 24
				if mx >= fx_d + 12 && mx <= fx_d + fw_d - 12 && my >= y && my <= y + 22 {
					if c.fixable && c.status != 'pass' {
						// click on fix badge → dry-run preview, Confirm applies (#1108)
						if mx >= fx_d + fw_d - 60 {
							doctor_preview_open(mut app, c.id)
							return
						}
					}
					app.inspector_msg = 'Doctor ${c.id} [${c.category}] ${c.status}: ${c.message} • fixable=${c.fixable} • receipts/provenance'
					return
				}
			}
		}
		// Swarm topology — node click attaches the desk VT fullscreen, edge click
		// shows the handoff artifact (copied), −/+ zoom node size (#1101)
		if app.selected_panel == 8 {
			fx_s := panel_fx(app)
			fy_s := 52
			fw_s := panel_fw(app, w)
			topo_y_s := fy_s + 56 + 78
			zx, zy, pxz, pyz, zw, zh := swarm_zoom_geom(fx_s, fy_s, fw_s, topo_y_s)
			if mx >= zx && mx <= zx + zw && my >= zy && my <= zy + zh {
				if app.swarm_zoom > -1 {
					app.swarm_zoom--
				}
				app.inspector_msg = 'Swarm topology zoom ${app.swarm_zoom}'
				return
			}
			if mx >= pxz && mx <= pxz + zw && my >= pyz && my <= pyz + zh {
				if app.swarm_zoom < 1 {
					app.swarm_zoom++
				}
				app.inspector_msg = 'Swarm topology zoom ${app.swarm_zoom}'
				return
			}
			for n in app.swarm_nodes {
				if mx >= n.x && mx <= n.x + n.w && my >= n.y && my <= n.y + 34 {
					di := swarm_role_desk(app, n.role)
					if di < 0 {
						app.inspector_msg = 'Swarm ${n.role}: no office desk to attach'
						return
					}
					if app.term_mode_saved < 0 {
						app.term_mode_saved = app.term_mode
					}
					app.term_view = di
					app.term_mode = 2
					app.term_visible = true
					app.inspector_msg = 'Swarm ${n.role} attached — desk ${di} VT fullscreen (Esc exits)'
					return
				}
			}
			for ed in app.swarm_edges {
				lo := if ed.x1 < ed.x2 { ed.x1 } else { ed.x2 }
				hi := if ed.x1 > ed.x2 { ed.x1 } else { ed.x2 }
				if mx >= lo - 4 && mx <= hi + 4 && my >= ed.y - 6 && my <= ed.y + 6 {
					if ed.artifact == '' {
						app.inspector_msg = 'Swarm edge: no artifact recorded on this handoff'
					} else {
						copy_to_clipboard(mut app, ed.artifact)
						app.inspector_msg = 'Swarm edge artifact: ${ed.artifact} (copied)'
					}
					return
				}
			}
		}
		// Jobs — ProcessSupervisor queue click: select + Cancel/Retry + logs + approvals approve/reject
		if app.selected_panel == 6 {
			fx := 208
			fy := 52
			fw := w - 208 - 300
			term_h_j := if app.term_visible { app.term_height } else { 0 }
			fh := h - 52 - 28 - term_h_j
			list_y0 := fy + 84
			list_h_total := fh - 84 - 110
			card_h := 52
			jobs := app.desktop.engine_jobs_catalog()
			visible := list_h_total / card_h
			if visible > 0 {
				start := clamp_scroll(app.jobs_scroll, jobs.len, visible)
				mut end_j := start + visible
				if end_j > jobs.len {
					end_j = jobs.len
				}
				for idx in start .. end_j {
					row := idx - start
					y := list_y0 + row * card_h
					if mx >= fx + 12 && mx <= fx + fw - 12 && my >= y && my <= y + card_h - 4 {
						app.jobs_selected = idx
						// button hits
						if mx >= fx + fw - 108 && mx <= fx + fw - 64 && my >= y + 22 && my <= y + 38 {
							// Cancel via Engine
							j := jobs[idx]
							_ := app.desktop.engine_cancel_job(j.id) or {
								app.inspector_msg = 'Job cancel failed: ${err.msg()}'
								return
							}
							app.inspector_msg = 'Job canceled: ${j.id}'
							return
						}
						if mx >= fx + fw - 58 && mx <= fx + fw - 14 && my >= y + 22 && my <= y + 38 {
							j := jobs[idx]
							new_id := app.desktop.engine_retry_job(j.id) or {
								app.inspector_msg = 'Job retry failed: ${err.msg()}'
								return
							}
							app.inspector_msg = 'Job retried: ${j.id} → ${new_id}'
							return
						}
						app.inspector_msg = 'Job selected: ${jobs[idx].id} • ${jobs[idx].cmd}'
						return
					}
				}
			}
			// approvals queue bottom approve/reject
			aq_y := fy + fh - 104
			if mx >= fx + 8 && mx <= fx + fw - 8 && my >= aq_y + 22 && my < aq_y + 22 + 66 {
				aq := app.desktop.engine_approvals_queue()
				mut total := aq.len
				if total == 0 {
					total = app.approvals.len
				}
				visible_aq := 3
				start_a := clamp_scroll(app.jobs_approvals_scroll, total, visible_aq)
				for a_idx in 0 .. visible_aq {
					ai := start_a + a_idx
					if ai >= total {
						break
					}
					y := aq_y + 22 + a_idx * 22
					if my >= y && my <= y + 14 {
						if mx >= fx + fw - 72 && mx <= fx + fw - 44 && my >= y && my <= y + 14 {
							app.inspector_msg = 'Approval approved: gate ${ai} (spend/scope/destructive) via Engine TX'
							return
						}
						if mx >= fx + fw - 40 && mx <= fx + fw - 12 && my >= y && my <= y + 14 {
							app.inspector_msg = 'Approval rejected: gate ${ai} via Engine TX'
							return
						}
					}
				}
			}
		}
		// Insights — telemetry tabs: cost | waterfall | spans | budgets | ci | realtime | gallery
		if app.selected_panel == 12 {
			fx_i := panel_fx(app)
			fy_i := 52
			tabs_i := ['cost', 'waterfall', 'spans', 'budgets', 'ci', 'realtime', 'gallery']
			for i in 0 .. tabs_i.len {
				x := fx_i + 16 + i * (84 + 6)
				y := fy_i + 48
				if mx >= x && mx <= x + 84 && my >= y && my <= y + 22 {
					app.insights_tab = tabs_i[i]
					app.inspector_msg = 'Insights → ${tabs_i[i]} • telemetry via Engine (no shell)'
					return
				}
			}
		}
		// Loops — budgets L1/L2/L3 missions: select + Run + Sched + New
		if app.selected_panel == 7 {
			fx := 208
			fy := 52
			fw := w - 208 - 300
			term_h_l := if app.term_visible { app.term_height } else { 0 }
			fh := h - 52 - 28 - term_h_l
			// new loop button
			if mx >= fx + fw - 118 && mx <= fx + fw - 14 && my >= fy + 10 && my <= fy + 32 {
				app.loops_show_create = !app.loops_show_create
				if app.loops_show_create {
					app.loops_create_name = 'new-loop-${app.frame % 100}'
					app.loops_create_tier = 0
					app.loops_create_cadence = '1d'
				}
				return
			}
			// create modal buttons
			if app.loops_show_create {
				mx2 := fx + 40
				my2 := fy + 50
				_ := fw - 80
				// Create
				if mx >= mx2 + 18 && mx <= mx2 + 106 && my >= my2 + 74 && my <= my2 + 100 {
					name := app.loops_create_name.trim_space()
					if name == '' {
						app.inspector_msg = 'Enter a loop name before creating it'
						return
					}
					tier_s := ['L1', 'L2', 'L3'][app.loops_create_tier]
					_ := app.desktop.engine_create_loop(name, tier_s, app.loops_create_cadence, '') or {
						app.inspector_msg = 'Loop could not be created: ${err.msg()}'
						return
					}
					app.inspector_msg = 'Loop created: ${name} ${tier_s} ${app.loops_create_cadence}'
					app.loops_show_create = false
					return
				}
				if mx >= mx2 + 118 && mx <= mx2 + 206 && my >= my2 + 74 && my <= my2 + 100 {
					app.loops_show_create = false
					return
				}
			}
			mut loops := app.desktop.loops_catalog()
			y0 := fy + 66
			card_h := 78
			visible := (fh - 90) / card_h
			if visible > 0 {
				start := clamp_scroll(app.loops_scroll, loops.len, visible)
				mut end_l := start + visible
				if end_l > loops.len {
					end_l = loops.len
				}
				for idx in start .. end_l {
					row := idx - start
					y := y0 + row * card_h
					if mx >= fx + 12 && mx <= fx + fw - 12 && my >= y && my <= y + card_h - 4 {
						app.selected_loop = idx
						// Run button
						if mx >= fx + fw - 108 && mx <= fx + fw - 64 && my >= y + 44 && my <= y + 60 {
							entry := loops[idx]
							job_id := app.desktop.engine_run_loop(entry.name) or {
								app.inspector_msg = 'Loop run failed: ${err.msg()}'
								return
							}
							app.inspector_msg = 'Loop started: ${entry.name} → ${job_id}'
							return
						}
						if mx >= fx + fw - 58 && mx <= fx + fw - 14 && my >= y + 44 && my <= y + 60 {
							entry := loops[idx]
							new_enabled := !entry.cron_enabled
							_ := app.desktop.engine_toggle_loop_cron(entry.name, new_enabled) or {
								app.inspector_msg = 'Loop schedule failed: ${err.msg()}'
								return
							}
							app.inspector_msg = 'Loop schedule ${if new_enabled {
								'enabled'
							} else {
								'paused'
							}}: ${entry.name}'
							return
						}
						app.inspector_msg = 'Loop selected: ${loops[idx].name} • L${loops[idx].tier.str().to_upper()} • ${loops[idx].budget.max_tokens} tok • ${loops[idx].budget.max_runs_per_day}/d • ${loops[idx].budget.max_wall_seconds}s'
						return
					}
				}
			}
		}
		// Workspace IDE — file-tree, editor tabs, git rails CHANGES/HISTORY/COMPARE, commit graph, diff, memory palace
		// Super potent: brokered fs via Engine.open_path_validated (harness_root_escape), syntax, graph lanes, semantic recall
		if app.selected_panel == 9 {
			l := workspace_layout(app, w, h)
			// workspace control row: field + Validate / Switch / Initialize
			if my >= l.field_y && my <= l.field_y + 28 {
				if mx >= l.field_x && mx <= l.field_x + l.field_w {
					app.workspace_focus = true
					app.header_search_focus = false
					app.ghost_focused = false
					return
				}
				if mx >= l.validate_x && mx <= l.validate_x + 64 {
					validate_workspace_draft(mut app)
					return
				}
				if mx >= l.switch_x && mx <= l.switch_x + 64 {
					apply_workspace(mut app, app.workspace_draft, 'Manual')
					return
				}
				if mx >= l.init_x && mx <= l.init_x + 58 {
					initialize_workspace(mut app)
					return
				}
			}
			// git rail tabs hit
			rail_y := l.mid_y
			for ri, rn in ['CHANGES', 'HISTORY', 'COMPARE'] {
				rx := l.fx + l.fw - 240 - 12 + 6 + ri * 78
				if mx >= rx && mx <= rx + 74 && my >= rail_y && my <= rail_y + 22 {
					app.git_rail = rn
					app.git_scroll = 0
					return
				}
			}
			// file tree hit — left 180
			ft_x := l.fx + 12
			ft_y := l.mid_y
			ft_w := 180
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
								tab := app.desktop.engine_open_file_brokered(app.harness_root, n.path) or {
									app.inspector_msg = 'Unable to open ${n.name}: ${err.msg()}'
									return
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
			ed_x := l.fx + 12 + 180 + 4
			ed_w := l.fw - 24 - 180 - 4 - 240
			ed_y := l.mid_y
			if app.editor_tabs.len > 0 && mx >= ed_x && mx <= ed_x + ed_w && my >= ed_y + 6 && my <= ed_y + 24 {
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
				rail_x := l.fx + l.fw - 240 - 12
				rail_y2 := l.mid_y + 26
				graph := app.desktop.engine_git_graph(20)
				row_h := 22
				y0 := rail_y2 + 14
				visible := (l.mid_h - 40) / row_h
				if visible > 0 {
					start := clamp_scroll(app.git_scroll, graph.commits.len, visible)
					for idx in start .. graph.commits.len {
						if idx >= start + visible {
							break
						}
						row := idx - start
						ry := y0 + row * row_h
						if mx >= rail_x && mx <= rail_x + 240 && my >= ry && my <= ry + row_h {
							app.git_selected = graph.commits[idx].hash
							hunks := app.desktop.engine_git_diff(app.git_selected)
							app.inspector_msg = if hunks.len > 0 {
								'Commit ${graph.commits[idx].hash[..7]} selected — ${hunks.len} diff hunks'
							} else {
								'Commit ${graph.commits[idx].hash[..7]} selected — diff unavailable from the workspace adapter'
							}
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
		// Hit floor desks only in world panel — uses desk_rect so draw and hit-test agree
		if app.selected_panel == 0 {
			w2 := app.gg.width
			h2 := app.gg.height
			fx := panel_fx(app)
			fy := 52
			fw := panel_fw(app, w2)
			term_h_d := if app.term_visible { app.term_height } else { 0 }
			fh := h2 - 52 - 28 - term_h_d
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
			term_h_mm := if app.term_visible { app.term_height } else { 0 }
			fx := 208
			fy := 52
			fw := w2 - 208 - 300
			fh := h2 - 52 - 28 - term_h_mm
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
			term_h := app.term_height
			y0 := h3 - 28 - term_h
			x0 := 200
			tw := w3 - 200
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
			term_h_ii := if app.term_visible { app.term_height } else { 0 }
			ix := inspector_x(app, w3)
			iy := 52
			ih := h3 - 52 - 28 - term_h_ii
			log_y0 := iy + 302
			inspector_log_h := ih - 310
			if inspector_log_h >= 40 && app.mouse_x >= ix + 8 && app.mouse_x <= ix + 300 - 8 && app.mouse_y >= log_y0 && app.mouse_y < log_y0 + inspector_log_h {
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
		// skills hover — 227 list rows hover
		if app.selected_panel == 1 {
			fx := 208
			fy := 52
			fw := app.gg.width - 208 - 300
			y0 := fy + 102
			row_h := 28
			term_h_sk := if app.term_visible { app.term_height } else { 0 }
			fh := app.gg.height - 52 - 28 - term_h_sk
			list_h := fh - 126
			visible := list_h / row_h
			entries := skills_filtered_entries(mut app)
			start := clamp_scroll(app.skills_scroll, entries.len, visible)
			mut end_en := start + visible
			if end_en > entries.len {
				end_en = entries.len
			}
			for idx in start .. end_en {
				row := idx - start
				y := y0 + row * row_h
				if app.mouse_x >= fx + 12 && app.mouse_x <= fx + fw - 12 && app.mouse_y >= y && app.mouse_y <= y + 24 {
					app.skills_hover = idx
					break
				}
			}
		}
		// workspace file-tree hover — left 180
		if app.selected_panel == 9 {
			l := workspace_layout(app, app.gg.width, app.gg.height)
			ft_x := l.fx + 12
			ft_y := l.mid_y
			ft_w := 180
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
			rail_x := l.fx + l.fw - 240 - 12
			y0 := l.mid_y + 26 + 14
			if app.git_rail == 'CHANGES' {
				changes := app.desktop.engine_git_changes()
				row_h2 := 20
				vis2 := (l.mid_h - 20) / row_h2
				start2 := clamp_scroll(app.git_scroll, changes.len, vis2)
				mut end2_ch := start2 + vis2
				if end2_ch > changes.len {
					end2_ch = changes.len
				}
				for idx in start2 .. end2_ch {
					row := idx - start2
					ry := y0 + row * row_h2
					if app.mouse_x >= rail_x && app.mouse_x <= rail_x + 240 && app.mouse_y >= ry && app.mouse_y <= ry + row_h2 {
						app.git_hover = idx
						break
					}
				}
			} else if app.git_rail == 'HISTORY' {
				graph := app.desktop.engine_git_graph(20)
				row_h2 := 22
				vis2 := (l.mid_h - 40) / row_h2
				start2 := clamp_scroll(app.git_scroll, graph.commits.len, vis2)
				mut end2_hi := start2 + vis2
				if end2_hi > graph.commits.len {
					end2_hi = graph.commits.len
				}
				for idx in start2 .. end2_hi {
					row := idx - start2
					ry := y0 + row * row_h2
					if app.mouse_x >= rail_x && app.mouse_x <= rail_x + 240 && app.mouse_y >= ry && app.mouse_y <= ry + row_h2 {
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
		// products catalog hover — Install/Manage distinct from onboarding
		if app.selected_panel == 10 {
			fx := 208
			fy := 52
			fw := app.gg.width - 208 - 300
			term_h_p := if app.term_visible { app.term_height } else { 0 }
			fh := app.gg.height - 52 - 28 - term_h_p
			card_y0 := fy + 48
			card_h := 52
			visible := (fh - 70) / card_h
			if visible > 0 {
				prods := app.desktop.engine_products_catalog()
				start := clamp_scroll(app.products_scroll, prods.len, visible)
				mut end_p := start + visible
				if end_p > prods.len {
					end_p = prods.len
				}
				for idx in start .. end_p {
					row := idx - start
					y := card_y0 + row * card_h
					if app.mouse_x >= fx + 12 && app.mouse_x <= fx + fw - 12 && app.mouse_y >= y + 2 && app.mouse_y <= y + 46 {
						app.products_hover = idx
						break
					}
				}
			}
		}
		// jobs hover — ProcessSupervisor queue distinct dark cards
		if app.selected_panel == 6 {
			fx := 208
			fy := 52
			fw := app.gg.width - 208 - 300
			term_h_j := if app.term_visible { app.term_height } else { 0 }
			fh := app.gg.height - 52 - 28 - term_h_j
			list_y0 := fy + 84
			card_h := 52
			mut jobs := app.desktop.engine_jobs_catalog()
			if jobs.len == 0 {
				jobs = [
					desktop_engine.JobRecord{ id: 'job-7f3a-build-cli', cmd: '', args: [], status: .done },
					desktop_engine.JobRecord{ id: 'job-9c1e-test-desktop', cmd: '', args: [], status: .running },
					desktop_engine.JobRecord{ id: 'job-a2ff-serve', cmd: '', args: [], status: .running },
					desktop_engine.JobRecord{ id: 'job-4d2a-loop-daily', cmd: '', args: [], status: .queued },
				]
			}
			list_h_total := fh - 84 - 110
			visible := list_h_total / card_h
			if visible > 0 {
				start := clamp_scroll(app.jobs_scroll, jobs.len, visible)
				mut end_j := start + visible
				if end_j > jobs.len {
					end_j = jobs.len
				}
				for idx in start .. end_j {
					row := idx - start
					y := list_y0 + row * card_h
					if app.mouse_x >= fx + 12 && app.mouse_x <= fx + fw - 12 && app.mouse_y >= y && app.mouse_y <= y + card_h - 4 {
						app.jobs_hover = idx
						// button hovers
						if app.mouse_x >= fx + fw - 108 && app.mouse_x <= fx + fw - 64 && app.mouse_y >= y + 22 && app.mouse_y <= y + 38 {
							app.jobs_hover_cancel = idx
						}
						if app.mouse_x >= fx + fw - 58 && app.mouse_x <= fx + fw - 14 && app.mouse_y >= y + 22 && app.mouse_y <= y + 38 {
							app.jobs_hover_retry = idx
						}
						break
					}
				}
			}
		}
		// loops hover — budgets L1/L2/L3 cream pixel distinct from jobs dark
		if app.selected_panel == 7 {
			fx := 208
			fy := 52
			fw := app.gg.width - 208 - 300
			term_h_l := if app.term_visible { app.term_height } else { 0 }
			fh := app.gg.height - 52 - 28 - term_h_l
			y0 := fy + 66
			card_h := 78
			mut loops := app.desktop.loops_catalog()
			visible := (fh - 90) / card_h
			if visible > 0 {
				start := clamp_scroll(app.loops_scroll, loops.len, visible)
				mut end_l := start + visible
				if end_l > loops.len {
					end_l = loops.len
				}
				for idx in start .. end_l {
					row := idx - start
					y := y0 + row * card_h
					if app.mouse_x >= fx + 12 && app.mouse_x <= fx + fw - 12 && app.mouse_y >= y && app.mouse_y <= y + card_h - 4 {
						app.loops_hover_run = idx
						// cron btn
						if app.mouse_x >= fx + fw - 58 && app.mouse_x <= fx + fw - 14 && app.mouse_y >= y + 44 && app.mouse_y <= y + 60 {
							app.loops_hover_cron = idx
						} else if app.mouse_x >= fx + fw - 108 && app.mouse_x <= fx + fw - 64 && app.mouse_y >= y + 44 && app.mouse_y <= y + 60 {
							// keep run hover already
						} else {
							app.loops_hover_cron = -1
						}
						if app.mouse_x >= fx + 22 && app.mouse_x <= fx + 22 + (fw - 24 - 140 - 100) / 3 && app.mouse_y >= y + 34 && app.mouse_y <= y + 44 {
							app.loops_budget_hover = idx
						}
						break
					}
				}
			}
			// new loop button
			if app.mouse_x >= fx + fw - 118 && app.mouse_x <= fx + fw - 14 && app.mouse_y >= fy + 10 && app.mouse_y <= fy + 32 {
				app.loops_hover_run = -2
			}
		}
		// insights hover — telemetry tabs
		if app.selected_panel == 12 {
			fx_i2 := 208
			fy_i2 := 52
			for i in 0 .. 5 {
				x := fx_i2 + 16 + i * (92 + 6)
				y := fy_i2 + 48
				if app.mouse_x >= x && app.mouse_x <= x + 92 && app.mouse_y >= y && app.mouse_y <= y + 20 {
					app.insights_hover = i
					break
				}
			}
		}
		// onboarding wizard hover — distinct overlay steps 0..6 progress + Next/Finish/Skip
		if app.show_onboarding || app.selected_panel == 11 {
			w2o := app.gg.width
			h2o := app.gg.height
			term_h_o := if app.term_visible { app.term_height } else { 0 }
			is_overlay_o := app.show_onboarding && app.selected_panel != 11
			mut fx_o := if is_overlay_o { 240 } else { 208 }
			mut fw_o := if is_overlay_o { w2o - 480 } else { w2o - 208 - 300 }
			if fw_o < 520 {
				fw_o = if is_overlay_o { 640 } else { w2o - 208 - 300 }
				fx_o = if is_overlay_o { (w2o - fw_o) / 2 } else { 208 }
			}
			fy_o := 52
			fh_o := h2o - 52 - 28 - term_h_o
			// footer Skip/Back/Next hover — 12/10/11 distinct
			if app.mouse_x >= fx_o + fw_o - 294 && app.mouse_x <= fx_o + fw_o - 238 && app.mouse_y >= fy_o + fh_o - 32 && app.mouse_y <= fy_o + fh_o - 12 {
				app.onboarding_hover = 12
			} else if app.onboarding_step > 0 && app.mouse_x >= fx_o + fw_o - 220 && app.mouse_x <= fx_o + fw_o - 156 && app.mouse_y >= fy_o + fh_o - 32 && app.mouse_y <= fy_o + fh_o - 12 {
				app.onboarding_hover = 10
			} else if app.mouse_x >= fx_o + fw_o - 148 && app.mouse_x <= fx_o + fw_o - 76 && app.mouse_y >= fy_o + fh_o - 32 && app.mouse_y <= fy_o + fh_o - 12 {
				app.onboarding_hover = 11
			} else if app.onboarding_step == 4 && app.mouse_x >= fx_o + 20 && app.mouse_x <= fx_o + 150 && app.mouse_y >= fy_o + 40 + 24 + 38 + 24 + 82 && app.mouse_y <= fy_o + 40 + 24 + 38 + 24 + 106 {
				app.onboarding_hover = 4
			} else if app.onboarding_step == 5 && app.mouse_x >= fx_o + 20 && app.mouse_x <= fx_o + 150 && app.mouse_y >= fy_o + 40 + 24 + 38 + 24 + 148 && app.mouse_y <= fy_o + 40 + 24 + 38 + 24 + 170 {
				app.onboarding_hover = 5
			} else if app.onboarding_step == 6 && app.mouse_x >= fx_o + 20 && app.mouse_x <= fx_o + 130 && app.mouse_y >= fy_o + 40 + 24 + 38 + 24 + 84 && app.mouse_y <= fy_o + 40 + 24 + 38 + 24 + 106 {
				app.onboarding_hover = 6
			} else if app.onboarding_step == 1 {
				// Install 5 hover inside onboarding capabilities step
				fy_tabs := fy_o + 40
				y_harness := fy_tabs + 24 + 38
				content_y := y_harness + 24
				content_h := fh_o - (content_y - fy_o) - 52
				if app.mouse_x >= fx_o + fw_o - 120 && app.mouse_x <= fx_o + fw_o - 24 && app.mouse_y >= content_y + content_h - 54 && app.mouse_y <= content_y + content_h - 34 {
					app.onboarding_hover = 1
				}
			}
		}
	}
	if e.typ == .quit_requested {
		app.gg.quit()
	}
}
