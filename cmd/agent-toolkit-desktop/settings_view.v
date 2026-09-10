module main

import gg
import desktop.pixelart

// Preferences sheet.
//
// Settings is a real destination and setup is an explicit overlay journey.
// This sheet exposes ONLY the settings
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
	draw_paper_sheet(mut app, x, y, w, h)
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
			hover := rect_contains(app.mouse_x, app.mouse_y, sx, sy, sw, sh)
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
			if !rect_contains(mx, my, sx, sy, sw, sh) {
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

struct SettingsLayout {
	fx       int
	fy       int
	fw       int
	fh       int
	prefs_x  int
	prefs_y  int
	prefs_w  int
	setup_y  int
	setup_h  int
	button_x int
	button_y int
	button_w int
	button_h int
}

fn settings_layout(app &GuiApp, w int, h int) SettingsLayout {
	fx := panel_fx(app)
	fy := shell_mast_h(h)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	prefs_x := fx + 16
	prefs_y := fy + if fh < 240 { 40 } else { 58 }
	prefs_w := fw - 32
	setup_y := prefs_y + prefs_sheet_height() + 12
	setup_h := content_bottom(app, h) - setup_y - 12
	button_w := 146
	return SettingsLayout{
		fx: fx
		fy: fy
		fw: fw
		fh: fh
		prefs_x: prefs_x
		prefs_y: prefs_y
		prefs_w: prefs_w
		setup_y: setup_y
		setup_h: setup_h
		button_x: prefs_x + 14
		button_y: setup_y + 76
		button_w: button_w
		button_h: 26
	}
}

// draw_settings promotes the real preferences into their own product
// destination. It exposes only state GuiApp can actually mutate and keeps the
// setup journey as an explicit action rather than conflating Settings with it.
fn draw_settings(mut app GuiApp, w int, h int) {
	l := settings_layout(app, w, h)
	app.gg.draw_rect_filled(l.fx, l.fy, l.fw, l.fh, app.pnl_bg)
	app.gg.draw_text(l.fx + 18, l.fy + 8, 'Settings', gg.TextCfg{
		color: app.pnl_text
		size: 24
		family: app.fonts.display
	})
	if l.fh >= 240 {
		app.gg.draw_text(l.fx + 18, l.fy + 35, 'Appearance, language, terminal and workspace setup', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	}
	if l.prefs_y + prefs_sheet_height() > content_bottom(app, h) {
		return
	}
	draw_preferences_sheet(mut app, l.prefs_x, l.prefs_y, l.prefs_w)
	if l.setup_h < 58 {
		return
	}
	draw_paper_sheet(mut app, l.prefs_x, l.setup_y, l.prefs_w, l.setup_h)
	st := app.desktop.onboarding_status(app.harness_root)
	app.gg.draw_text(l.prefs_x + 14, l.setup_y + 12, 'Workspace setup', gg.TextCfg{
		color: app.pnl_text
		size: 15
		family: app.fonts.display
	})
	state := if st.completed { 'Complete' } else { '${st.pending_items.len} steps pending' }
	app.gg.draw_text(l.prefs_x + 14, l.setup_y + 34, state, gg.TextCfg{
		color: if st.completed { app.pnl_success } else { app.pnl_select }
		size: 11
		bold: true
	})
	app.gg.draw_text(l.prefs_x + 14, l.setup_y + 52, utf8_truncate(if app.harness_root == '' {
		'No active workspace selected'
	} else {
		app.harness_root
	}, text_fit_chars(l.prefs_w - 32, 10)), gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
		mono: true
	})
	if l.setup_h >= 150 {
		// Static workshop scenery gives Preferences the same physical world as
		// Office and Onboarding without claiming runtime activity.
		scene_x := l.prefs_x + l.prefs_w * 42 / 100
		draw_onboarding_scene(mut app, scene_x, l.setup_y + 12, l.prefs_x + l.prefs_w - 14 - scene_x, l.setup_h - 24, office_palette_id(app))
	}
	if l.setup_h >= 102 {
		hover := rect_contains(app.mouse_x, app.mouse_y, l.button_x, l.button_y, l.button_w, l.button_h)
		app.gg.draw_rect_filled(l.button_x, l.button_y, l.button_w, l.button_h, if hover {
			app.pnl_select_hover
		} else {
			app.pnl_select
		})
		app.gg.draw_text(l.button_x + 16, l.button_y + 6, 'Open setup journey', gg.TextCfg{
			color: app.pnl_bg
			size: 11
			bold: true
		})
	}
}

fn draw_settings_detail(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	ix := inspector_x(app, w)
	iy := panel_top(app)
	ih := content_bottom(app, h) - iy
	app.gg.draw_rect_filled(ix, iy, inspector_w, ih, app.pnl_card)
	app.gg.draw_line(ix, iy, ix, iy + ih, app.pnl_border)
	if ih < 80 {
		return
	}
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	gear := pixelart.environment_for(.gear)
	sc.draw(gear, pid, ix + 18, iy + 18, 4)
	app.gg.draw_text(ix + 82, iy + 20, 'Your desk, your way.', gg.TextCfg{
		color: app.pnl_text
		size: 17
		family: app.fonts.display
	})
	app.gg.draw_text(ix + 18, iy + 78, 'Current preferences', gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
		bold: true
	})
	rows := [
		'Appearance  ${appearance_label(app.appearance)}',
		'Language    ${app.lang.chip()}',
		'Terminal    ${prefs_row_segments(2)[app.term_mode]}',
		'Zoom        ${zoom_percent(app.global_zoom)}',
	]
	for i, row in rows {
		app.gg.draw_text(ix + 18, iy + 100 + i * 22, row, gg.TextCfg{
			color: app.pnl_text
			size: 11
			mono: true
		})
	}
	if ih > 410 {
		nook_y := iy + 220
		nook_h := ih - 300
		draw_paper_sheet(mut app, ix + 12, nook_y, inspector_w - 24, nook_h)
		shelf := pixelart.environment_for(.shelf)
		couch := pixelart.environment_for(.couch)
		lamp := pixelart.environment_for(.lamp)
		plant := pixelart.environment_for(.plant)
		sc.draw(shelf, pid, ix + 24, nook_y + 14, 3)
		sc.draw(couch, pid, ix + 82, nook_y + nook_h - couch.height() * 3 - 14, 3)
		sc.draw(lamp, pid, ix + inspector_w - 62, nook_y + 18, 3)
		sc.draw(plant, pid, ix + inspector_w - 58, nook_y + nook_h - plant.height() * 3 - 10, 3)
		draw_paper_quote(mut app, ix + 12, iy + ih - 70, inspector_w - 24, '"Good tools make', 'brighter builders."', '— Hornero')
	} else if ih > 260 {
		plant := pixelart.environment_for(.plant)
		sc.draw(plant, pid, ix + inspector_w / 2 - plant.width() * 3 / 2, iy + ih - plant.height() * 3 - 24, 3)
	}
}

fn settings_click(mut app GuiApp, mx int, my int, w int, h int) bool {
	l := settings_layout(app, w, h)
	if l.prefs_y + prefs_sheet_height() <= content_bottom(app, h)
		&& preferences_click(mut app, l.prefs_x, l.prefs_y, l.prefs_w, mx, my) {
		return true
	}
	if l.setup_h >= 102 && rect_contains(mx, my, l.button_x, l.button_y, l.button_w, l.button_h) {
		app.show_onboarding = true
		app.onboarding_msg = 'Setup journey opened — five stages, press o to toggle'
		return true
	}
	return rect_contains(mx, my, inspector_x(app, w), panel_top(app), inspector_w, content_bottom(app, h) - panel_top(app))
}
