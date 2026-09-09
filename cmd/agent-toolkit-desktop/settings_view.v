module main

import gg
import desktop.pixelart

// VC7 (#1173) — Preferences sheet.
//
// The dock's "Settings" destination maps to the setup (onboarding) shell;
// there is no separate preferences page and this pass does not invent one
// (no Models, no fabricated options). This sheet exposes ONLY the settings
// that already exist in GuiApp today — appearance, language, terminal
// height mode, zoom — wired to the same state fields the header chips,
// status bar and keyboard shortcuts mutate, and persisted through the
// existing ui_state.env path (save_ui_state). It is mounted in the
// Workspace details column, where it fits the "most technical destination".

const prefs_rows = ['Appearance', 'Language', 'Terminal', 'Zoom']

const prefs_row_h = 30

const prefs_label_w = 84

// prefs_sheet_height is the sheet's fixed height so column layouts can
// decide whether it fits before drawing.
fn prefs_sheet_height() int {
	return 34 + prefs_rows.len * prefs_row_h + 8
}

// prefs_seg_rect returns segment i of n in row r: chips share the width to
// the right of the label, flush with the sheet's inner edge.
fn prefs_seg_rect(x int, y int, w int, r int, i int, n int) (int, int, int, int) {
	sx := x + prefs_label_w + 8
	sw := w - prefs_label_w - 20
	seg := sw / n
	return sx + i * seg, y + 34 + r * prefs_row_h, seg - 3, 22
}

fn prefs_row_segments(r int) []string {
	return match r {
		0 { ['Paper', 'Ink', 'System'] }
		1 { ['EN', 'ES', '中文', 'عربي'] }
		2 { ['1×', '2×', 'MAX', 'Off'] }
		else { ['−', 'Reset', '+'] }
	}
}

fn prefs_active_segment(app &GuiApp, r int) int {
	return match r {
		0 { int(app.appearance) }
		1 { int(app.lang) }
		2 { app.term_mode }
		else { -1 }
	}
}

fn draw_preferences_sheet(mut app GuiApp, x int, y int, w int) {
	ensure_pixel_cache(mut app)
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	h := prefs_sheet_height()
	paper_sheet(mut app, x, y, w, h)
	sc.draw(pixelart.environment_for(.gear), pid, x + 10, y + 6, 2)
	app.gg.draw_text(x + 40, y + 6, 'Preferences', gg.TextCfg{
		color: app.pnl_text
		size: 15
		family: app.fonts.display
	})
	app.gg.draw_text(x + 40, y + 22, 'saved to ui_state.env', gg.TextCfg{
		color: app.pnl_text_mut
		size: 9
	})
	for r, label in prefs_rows {
		ry := y + 34 + r * prefs_row_h
		app.gg.draw_text(x + 10, ry + 5, label, gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		segs := prefs_row_segments(r)
		active := prefs_active_segment(app, r)
		for i, seg in segs {
			sx, sy, sw, sh := prefs_seg_rect(x, y, w, r, i, segs.len)
			on := i == active
			hover := onb_hit(app.mouse_x, app.mouse_y, sx, sy, sw, sh)
			app.gg.draw_rect_filled(sx, sy, sw, sh, if on {
				app.pnl_text
			} else if hover {
				app.pnl_card_sel
			} else {
				pc(app, `p`)
			})
			app.gg.draw_rect_empty(sx, sy, sw, sh, if on {
				app.pnl_text
			} else {
				tint(pc(app, `W`), 90)
			})
			if on {
				app.gg.draw_rect_filled(sx, sy + sh - 2, sw, 2, app.pnl_success)
			}
			txt := if r == 3 && i == 1 { zoom_percent(app.global_zoom) } else { seg }
			cfg := lang_cfg(app, txt, gg.TextCfg{
				color: if on { app.pnl_bg } else { app.pnl_text }
				size: 10
				bold: on
			})
			tw := txt.runes().len * 5 // glyphs, not bytes (中文 / عربي)
			app.gg.draw_text(sx + (sw - tw) / 2, sy + 5, txt, cfg)
		}
	}
}

// preferences_click applies a segment click. Every branch funnels through
// the same mutation points the rest of the shell uses, then persists.
fn preferences_click(mut app GuiApp, x int, y int, w int, mx int, my int) bool {
	for r in 0 .. prefs_rows.len {
		segs := prefs_row_segments(r)
		for i in 0 .. segs.len {
			sx, sy, sw, sh := prefs_seg_rect(x, y, w, r, i, segs.len)
			if !onb_hit(mx, my, sx, sy, sw, sh) {
				continue
			}
			match r {
				0 {
					a := match i {
						1 { Appearance.ink }
						2 { Appearance.system }
						else { Appearance.paper }
					}
					app.apply_appearance(a)
					app.inspector_msg = 'Appearance: ${appearance_label(a)} — panel theme applied'
				}
				1 {
					app.lang = match i {
						1 { Lang.es }
						2 { Lang.zh }
						3 { Lang.ar }
						else { Lang.en }
					}
					app.header_search_focus = false
					app.workspace_focus = false
					app.inspector_msg = 'Language: ${app.lang.chip()}'
				}
				2 {
					// same modes as the terminal header buttons (1× / 2× / MAX / hidden);
					// save_ui_state persists compact/hidden only — MAX is session-only
					app.term_mode = i
					app.term_visible = app.term_mode != 3
					app.inspector_msg = 'Terminal: ${segs[i]}'
				}
				else {
					app.global_zoom = match i {
						0 { zoom_step(app.global_zoom, -1) }
						2 { zoom_step(app.global_zoom, 1) }
						else { 1.0 }
					}
					app.zoom_toast = zoom_percent(app.global_zoom)
					app.zoom_toast_at = app.frame
				}
			}
			save_ui_state(app)
			return true
		}
	}
	return false
}
