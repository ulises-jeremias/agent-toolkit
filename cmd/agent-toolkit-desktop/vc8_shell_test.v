module main

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
