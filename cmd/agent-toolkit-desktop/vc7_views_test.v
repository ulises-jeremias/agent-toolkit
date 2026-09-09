module main

import desktop
import os
import time

// VC7 (#1173) — Workspace / Insights / Settings convergence: geometry shared
// between drawing and hit-testing, truthful scaffold checks, and the
// preferences sheet wired to the real state fields.

fn vc7_tmp(label string) string {
	tmp := os.join_path(os.temp_dir(), 'atk-vc7-${label}-${os.getpid()}-${time.now().unix_nano()}')
	os.mkdir_all(tmp) or { panic(err.msg()) }
	return tmp
}

// ── Workspace layout ────────────────────────────────────────────────────────

fn test_workspace_layout_controls_never_overlap() {
	for dims in [[1280, 800], [1024, 640], [1600, 900], [900, 600]] {
		for term in [true, false] {
			app := &GuiApp{
				selected_panel: 9
				term_visible: term
				term_height: 148
			}
			l := workspace_layout(app, dims[0], dims[1])
			assert l.field_x + l.field_w <= l.validate_x, 'field must end before Validate at ${dims}'
			assert l.validate_x + l.validate_w <= l.switch_x, 'Validate must end before Switch at ${dims}'
			assert l.switch_x + l.switch_w <= l.init_x, 'Switch must end before Initialize at ${dims}'
			if l.scene_w > 0 {
				assert l.init_x + l.init_w <= l.scene_x, 'buttons must not run into the scene at ${dims}'
				assert l.scene_x + l.scene_w <= l.fx + l.fw, 'scene inside the panel at ${dims}'
			} else {
				assert l.init_x + l.init_w <= l.fx + l.fw - 12, 'buttons inside the sheet at ${dims}'
			}
			assert l.hero_y + l.hero_h <= l.known_y, 'hero above known workspaces at ${dims}'
			assert l.known_y + l.known_h <= l.mid_y, 'known workspaces above the IDE at ${dims}'
			assert l.mid_h >= 100, 'IDE block keeps a usable minimum height at ${dims}'
			assert l.tree_w >= 140, 'the file tree column is always present at ${dims}'
			if l.fw >= 500 {
				assert l.git_w >= 180 && l.git_tab_w > 0, 'git rails present at ${dims}'
			}
			editor_w := l.fw - 24 - l.tree_w - 4 - l.git_w
			assert editor_w >= 150, 'editor keeps a readable width at ${dims}: ${editor_w}'
			if l.git_w > 0 {
				assert 6 + 3 * l.git_tab_w <= l.git_w, 'three git tabs fit their rail at ${dims}'
			}
			assert l.mem_y + l.mem_h <= l.fy + l.fh, 'memory strip inside the panel at ${dims}'
		}
	}
}

fn test_workspace_layout_compact_drops_scene() {
	small := &GuiApp{
		selected_panel: 9
		term_visible: true
		term_height: 148
	}
	l := workspace_layout(small, 1024, 640)
	assert l.compact, '1024x640 with a compact terminal is the compact composition'
	assert l.scene_w == 0, 'compact never squeezes the illustration'
	big := &GuiApp{
		selected_panel: 9
	}
	lb := workspace_layout(big, 1280, 800)
	assert !lb.compact
	assert lb.scene_w > 0, 'the hero scene appears when the width affords it'
}

// ── scaffold truth ──────────────────────────────────────────────────────────

fn test_ws_scaffold_present_reads_real_directories() {
	tmp := vc7_tmp('scaffold')
	defer {
		os.rmdir_all(tmp) or {}
	}
	os.mkdir_all(os.join_path(tmp, 'knowledge')) or { panic(err.msg()) }
	os.write_file(os.join_path(tmp, 'AGENTS.md'), '# contract\n') or { panic(err.msg()) }
	// a FILE named packs must not count as the packs/ directory
	os.write_file(os.join_path(tmp, 'packs'), '') or { panic(err.msg()) }
	present := ws_scaffold_present(tmp)
	assert present.len == ws_scaffold_names.len
	assert present[0], 'knowledge/ exists'
	assert !present[1], 'personas/ missing'
	assert !present[2], 'packs is a file, not the packs/ directory'
	assert !present[3] && !present[4], 'repos/ and projects/ missing'
	assert present[5], 'AGENTS.md exists'
}

fn test_ws_scaffold_present_unknown_root_is_empty_not_missing() {
	assert ws_scaffold_present('').len == 0, 'no root → unknown, never "missing"'
	assert ws_scaffold_present('/definitely/not/a/dir/${os.getpid()}').len == 0
}

fn test_ws_state_label_follows_engine_truth() {
	none_app := &GuiApp{}
	l0, _ := ws_state_label(none_app)
	assert l0 == 'No workspace'
	ready := &GuiApp{
		harness_root: '/tmp'
		workspace_initialized: true
	}
	l1, _ := ws_state_label(ready)
	assert l1 == 'Ready'
	folder := &GuiApp{
		harness_root: '/tmp'
	}
	l2, _ := ws_state_label(folder)
	assert l2 == 'Needs setup'
}

// ── Insights layout + rows ──────────────────────────────────────────────────

fn test_insights_tabs_do_not_overlap_and_fit() {
	for dims in [[1280, 800], [1024, 640], [1600, 900]] {
		app := &GuiApp{
			selected_panel: 12
			term_visible: true
			term_height: 148
		}
		l := insights_layout(app, dims[0], dims[1])
		mut prev_end := l.fx
		for i in 0 .. insights_tabs.len {
			x, y, w, h := insights_tab_rect(l, i)
			assert x >= prev_end, 'tab ${i} overlaps its neighbour at ${dims}'
			assert y == l.tab_y && h == l.tab_h
			prev_end = x + w
		}
		assert prev_end <= l.fx + l.fw, 'seven tabs fit inside the panel at ${dims}'
		assert l.content_y + l.content_h <= l.fy + l.fh
		assert insights_rows_visible(l) >= 1
	}
}

fn test_insights_table_without_engine_is_empty_and_honest() {
	mut app := &GuiApp{
		selected_panel: 12
	}
	for tab in insights_tabs {
		t := insights_table(mut app, tab, 600)
		assert t.rows.len == 0, 'no Engine → no rows for ${tab}'
		if tab != 'gallery' {
			assert t.empty != '', '${tab} needs its honest empty sentence'
		}
	}
}

fn test_insights_click_selects_tab_and_row() {
	tmp := vc7_tmp('insights')
	os.setenv('XDG_CACHE_HOME', tmp, true)
	mut d := desktop.new_desktop(desktop.DesktopBootArgs{
		config: desktop.DesktopConfig{
			headless: true
		}
		persist_path: os.join_path(tmp, 'state.json')
	})
	d.boot() or { panic(err.msg()) }
	defer {
		d.shutdown() or {}
		os.rmdir_all(tmp) or {}
	}
	mut app := &GuiApp{
		desktop: d
		selected_panel: 12
		insights_sel: 3
	}
	w, h := 1280, 800
	l := insights_layout(app, w, h)
	// tab switch resets selection + scroll
	x, y, tw, th := insights_tab_rect(l, 1)
	assert insights_click(mut app, x + tw / 2, y + th / 2, w, h)
	assert app.insights_tab == 'waterfall'
	assert app.insights_sel == -1, 'switching tabs must drop the previous row selection'
	// waterfall rows are the catalog agents — selecting the first row toggles
	t := insights_table(mut app, 'waterfall', l.inner_w)
	if t.rows.len > 0 {
		assert insights_click(mut app, l.inner_x + 10, l.rows_y + 4, w, h)
		assert app.insights_sel == 0, 'first visible row selected'
		assert insights_click(mut app, l.inner_x + 10, l.rows_y + 4, w, h)
		assert app.insights_sel == -1, 'clicking the selected row again deselects'
	}
	// the right column is consumed (never falls through to the inspector)
	assert insights_click(mut app, inspector_x(app, w) + 20, 300, w, h)
	// the dock is not ours
	assert !insights_click(mut app, 20, 300, w, h)
}

// ── Preferences sheet ───────────────────────────────────────────────────────

fn test_preferences_click_mutates_real_state_fields() {
	tmp := vc7_tmp('prefs')
	os.setenv('XDG_CACHE_HOME', tmp, true)
	defer {
		os.rmdir_all(tmp) or {}
	}
	mut app := &GuiApp{
		selected_panel: 9
		term_mode: 0
		global_zoom: 1.0
	}
	x, y, w := 1000, 300, 284
	// Appearance → Ink
	sx, sy, sw, sh := prefs_seg_rect(x, y, w, 0, 1, 3)
	assert preferences_click(mut app, x, y, w, sx + sw / 2, sy + sh / 2)
	assert app.appearance == .ink
	assert app.appearance_dark
	// Language → ES
	sx1, sy1, sw1, sh1 := prefs_seg_rect(x, y, w, 1, 1, 4)
	assert preferences_click(mut app, x, y, w, sx1 + sw1 / 2, sy1 + sh1 / 2)
	assert app.lang == .es
	// Terminal → hidden (Off)
	sx2, sy2, sw2, sh2 := prefs_seg_rect(x, y, w, 2, 3, 4)
	assert preferences_click(mut app, x, y, w, sx2 + sw2 / 2, sy2 + sh2 / 2)
	assert app.term_mode == 3 && !app.term_visible
	// Zoom + then Reset
	sx3, sy3, sw3, sh3 := prefs_seg_rect(x, y, w, 3, 2, 3)
	assert preferences_click(mut app, x, y, w, sx3 + sw3 / 2, sy3 + sh3 / 2)
	assert app.global_zoom > 1.0
	rx, ry, rw, rh := prefs_seg_rect(x, y, w, 3, 1, 3)
	assert preferences_click(mut app, x, y, w, rx + rw / 2, ry + rh / 2)
	assert app.global_zoom == 1.0
	// outside the sheet is not ours
	assert !preferences_click(mut app, x, y, w, x - 10, y - 10)
	// persisted through the existing ui_state.env path
	saved := os.read_file(ui_state_path()) or { '' }
	assert saved.contains('appearance=ink'), 'ui_state.env must record the appearance: ${saved}'
	assert saved.contains('lang=1'), 'ui_state.env must record the language: ${saved}'
}

fn test_preferences_segments_stay_inside_sheet() {
	x, y, w := 0, 0, 284
	h := prefs_sheet_height()
	for r in 0 .. prefs_rows.len {
		n := prefs_row_segments(r).len
		for i in 0 .. n {
			sx, sy, sw, sh := prefs_seg_rect(x, y, w, r, i, n)
			assert sx >= x + prefs_label_w
			assert sx + sw <= x + w
			assert sy + sh <= y + h
		}
	}
}

fn test_ws_detail_layout_drops_sections_from_the_bottom() {
	tall := &GuiApp{
		selected_panel: 9
	}
	d := ws_detail_layout(tall, 1280, 800)
	assert d.prefs_y > 0, 'preferences fit in a full-height column'
	assert d.quote_y > d.prefs_y, 'quote sits under preferences'
	short := &GuiApp{
		selected_panel: 9
		term_visible: true
		term_height: 320
	}
	ds := ws_detail_layout(short, 1024, 640)
	assert ds.prefs_y == 0, 'a short column drops the preferences sheet instead of overlapping'
	assert ds.quote_y == 0, 'and the editorial card'
	// whatever still fits must end inside the column; the scaffold checklist
	// (the primary truth) is always present
	limit := ds.iy + ds.ih - 8
	assert ds.scaffold_y + 22 + ws_scaffold_names.len * 17 <= limit
	if ds.seed_y > 0 {
		assert ds.seed_y + 54 <= limit
	}
	if ds.editor_y > 0 {
		assert ds.editor_y + 50 <= limit
	}
	if ds.git_y > 0 {
		assert ds.git_y + 50 <= limit
	}
}
