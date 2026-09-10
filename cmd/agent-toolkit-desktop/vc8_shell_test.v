module main

import gg

// VC8 (#1187): shared editorial-shell geometry, truthful Settings routing,
// and terminal tabs backed only by available views.

fn test_shell_masthead_is_responsive_and_bounded() {
	assert shell_mast_h(640) == 83
	assert shell_mast_h(800) == 104
	assert shell_mast_h(900) == 117
	assert shell_mast_h(480) == 78
	assert shell_mast_h(1200) == 128
}

fn test_header_controls_do_not_overlap_at_required_widths() {
	for dims in [[1024, 640], [1280, 800], [1440, 900]] {
		l := header_layout(dims[0], dims[1])
		assert l.workspace_x >= 430
		assert l.workspace_x + l.workspace_w < l.search_x
		assert l.search_x + l.search_w < l.theme_x
		assert l.theme_x + l.theme_w < l.lang_x
		assert l.lang_x + l.lang_w < l.command_x
		assert l.command_x + l.command_w <= dims[0] - 12
		assert l.control_y + l.control_h < l.mast_h
	}
}

fn test_primary_navigation_has_six_two_line_rows() {
	app := &GuiApp{
		selected_panel: 0
	}
	rows := nav_rows(app, 640)
	assert rows.len == 6
	for i, row in rows {
		assert row.parent
		assert row.h == 46
		assert nav_group_subtitle(row.panel) != ''
		if i > 0 {
			assert rows[i - 1].y + rows[i - 1].h < row.y
		}
	}
}

fn test_primary_navigation_stays_reachable_with_tall_terminal() {
	for dims in [[1280, 800], [1024, 640]] {
		app := &GuiApp{
			selected_panel: 0
			term_visible: true
			term_mode: 1
			term_height: 320
		}
		rows := nav_rows(app, dims[1])
		assert rows.len == 6
		bottom := content_bottom(app, dims[1]) - 4
		for i, row in rows {
			assert row.y >= shell_mast_h(dims[1])
			assert row.y + row.h <= bottom + 4
			if i > 0 {
				assert rows[i - 1].y < row.y
			}
		}
	}
}

fn test_primary_navigation_stays_on_dock_in_short_viewport_with_tall_terminal() {
	// #1191 review: at 1024x480 the raw 320px terminal leaves no dock room;
	// the dock keeps room for the six rows instead of collapsing with the
	// panels (draw, click and hover share nav_rows, so containment covers
	// all three; panels keep suppressing via content_bottom).
	app := &GuiApp{
		selected_panel: 0
		term_visible: true
		term_mode: 1
		term_height: 320
	}
	h := 480
	rows := nav_rows(app, h)
	assert rows.len == 6
	y0 := panel_top(app)
	y1 := dock_bottom(app, h)
	assert y1 > y0
	// the terminal keeps its user-set height; only the dock reserves room
	assert content_bottom(app, h) < y1
	for i, row in rows {
		assert row.y >= y0
		assert row.y + row.h <= y1
		if i > 0 {
			assert rows[i - 1].y < row.y
		}
	}
}

fn test_suppressed_insights_controls_stay_inert() {
	mut app := &GuiApp{
		selected_panel: 12
		term_visible: true
		term_mode: 1
		term_height: 320
		insights_tab: 'cost'
		insights_sel: -1
	}
	w, h := 1024, 480
	l := insights_layout(app, w, h)
	assert l.tab_h == 0
	clicked := insights_click(mut app, l.tab_x0 + 10, l.tab_y + 10, w, h)
	assert !clicked
	assert app.insights_sel == -1
}

fn test_settings_is_a_destination_not_implicit_onboarding() {
	mut app := &GuiApp{
		selected_panel: 0
		show_onboarding: true
	}
	select_panel(mut app, 11)
	assert app.selected_panel == 11
	assert !app.show_onboarding
}

fn test_terminal_tabs_only_include_available_views() {
	app := &GuiApp{}
	tabs := terminal_tabs(app)
	assert tabs.len == 1
	assert tabs[0].label == 'Terminal'
	assert tabs[0].view == -1
}

fn test_session_tab_requires_max_terminal_mode() {
	compact := &GuiApp{
		term_mode: 0
		sessions: [TermSession{}]
	}
	assert terminal_tabs(compact).len == 1
	max := &GuiApp{
		term_mode: 2
		sessions: [TermSession{}]
	}
	assert terminal_tabs(max).len == 2
	assert terminal_tabs(max)[1].label == 'Sessions'
}

fn test_onboarding_consumes_destination_shortcuts() {
	mut app := &GuiApp{
		selected_panel: 11
		show_onboarding: true
		workspace_focus: true
		header_search_focus: true
		term_search_open: true
		term_mode: 2
		term_view: 15
		sessions: [TermSession{}]
	}
	e := &gg.Event{
		typ: .key_down
		char_code: u32(`1`)
	}
	on_event(e, mut app)
	assert app.show_onboarding
	assert app.selected_panel == 11
}

fn test_help_consumes_stale_field_input() {
	mut app := &GuiApp{
		selected_panel: 9
		show_help: true
		workspace_focus: true
		workspace_draft: '/before'
	}
	e := &gg.Event{
		typ: .key_down
		char_code: u32(`x`)
	}
	on_event(e, mut app)
	assert app.show_help
	assert app.workspace_draft == '/before'
}

fn test_help_consumes_pointer_before_destination_controls() {
	mut app := &GuiApp{
		selected_panel: 1
		show_help: true
	}
	e := &gg.Event{
		typ: .mouse_down
		mouse_x: 400
		mouse_y: 300
	}
	on_event(e, mut app)
	assert !app.show_help
	assert app.selected_panel == 1
}

fn test_terminal_geometry_mirrors_around_the_dock() {
	ltr := &GuiApp{
		term_height: 120
	}
	lx, ly, lw, lh := terminal_rect(ltr, 1024, 640)
	assert lx == dock_w
	assert ly == 492
	assert lw == 1024 - dock_w
	assert lh == 120
	rtl := &GuiApp{
		lang: .ar
		term_height: 120
	}
	rx, ry, rw, rh := terminal_rect(rtl, 1024, 640)
	assert rx == 0
	assert ry == ly
	assert rw == lw
	assert rh == lh
	assert terminal_split_boundary(ltr, 1024, 640) - terminal_split_boundary(rtl, 1024, 640) == dock_w
}

fn test_terminal_persistence_keeps_tall_but_not_max() {
	assert persisted_terminal_mode(0) == 0
	assert persisted_terminal_mode(1) == 1
	assert persisted_terminal_mode(2) == 0
	assert persisted_terminal_mode(3) == 3
	assert persisted_terminal_mode(99) == 3
}

fn test_compact_tall_terminal_preserves_bounded_settings_and_insights() {
	app := &GuiApp{
		selected_panel: 12
		term_visible: true
		term_mode: 1
		term_height: 320
	}
	il := insights_layout(app, 1024, 640)
	assert il.fy == shell_mast_h(640)
	assert il.metric_h == 0
	assert il.content_h >= 100
	sl := settings_layout(app, 1024, 640)
	assert sl.fy == shell_mast_h(640)
	assert sl.prefs_y + prefs_sheet_height() <= content_bottom(app, 640)
}

fn test_short_tall_terminal_suppresses_insights_controls() {
	app := &GuiApp{
		selected_panel: 12
		term_visible: true
		term_mode: 1
		term_height: 320
	}
	l := insights_layout(app, 1024, 480)
	assert l.fh >= 0
	assert l.metric_h == 0
	assert l.tab_h == 0
	assert l.content_h == 0
}

fn test_short_tall_terminal_suppresses_operations_controls() {
	app := &GuiApp{
		selected_panel: 6
		term_visible: true
		term_mode: 1
		term_height: 320
	}
	l := ops_layout(app, 1024, 640)
	assert l.body_h == 0
	assert l.tab_h == 0
	assert l.ctl_h == 0
	assert l.table_h == 0
}

fn test_shell_geometry_mirrors_in_rtl() {
	ltr := &GuiApp{}
	rtl := &GuiApp{
		lang: .ar
	}
	assert dock_x(ltr, 1280) == 0
	assert inspector_x(ltr, 1280) == 1280 - inspector_w
	assert dock_x(rtl, 1280) == 1280 - dock_w
	assert inspector_x(rtl, 1280) == 0
	assert panel_fw(ltr, 1280) == panel_fw(rtl, 1280)
}

fn test_destination_layouts_use_production_masthead_height() {
	mut library_app := &GuiApp{
		selected_panel: 1
	}
	assert lib_layout(mut library_app, 1024, 640).fy == shell_mast_h(640)
	operations_app := &GuiApp{
		selected_panel: 6
	}
	assert ops_layout(operations_app, 1024, 640).fy == shell_mast_h(640)
	workspace_app := &GuiApp{
		selected_panel: 9
	}
	assert workspace_layout(workspace_app, 1024, 640).fy == shell_mast_h(640)
}

fn test_settings_layout_stays_inside_shell_content() {
	for dims in [[1024, 640], [1280, 800], [1440, 900]] {
		app := &GuiApp{
			selected_panel: 11
		}
		l := settings_layout(app, dims[0], dims[1])
		assert l.prefs_x >= l.fx
		assert l.prefs_x + l.prefs_w <= l.fx + l.fw
		assert l.setup_y >= l.prefs_y + prefs_sheet_height()
		assert l.setup_y + l.setup_h <= content_bottom(app, dims[1])
	}
}

fn test_office_metrics_span_center_and_detail_columns() {
	app := &GuiApp{}
	l := office_layout(app, 1280, 800)
	first_x, _, first_w, _ := office_card_rect(l, 0)
	last_x, _, last_w, _ := office_card_rect(l, 3)
	assert first_x == l.cards_x
	assert last_x + last_w == l.cards_x + l.cards_w
	assert last_x + last_w > inspector_x(app, 1280)
	assert l.room_w == panel_fw(app, 1280) - 32
}
