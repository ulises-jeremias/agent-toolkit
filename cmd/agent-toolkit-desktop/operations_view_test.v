module main

import desktop_engine

// Operations command center: geometry sharing, truthful empty
// states, and the Engine → row projection helpers.

fn test_operations_tab_panel_mapping() {
	assert operations_tab_for_panel(6) == 0 // Jobs
	assert operations_tab_for_panel(7) == 1 // Loops
	assert operations_tab_for_panel(8) == 2 // Swarms
	assert operations_tab_for_panel(5) == 3 // Doctor
	assert operations_tab_for_panel(0) == -1
	assert operations_is_panel(5) && operations_is_panel(8)
	assert !operations_is_panel(1) && !operations_is_panel(11)
	for i, p in operations_tab_panels {
		assert operations_tab_for_panel(p) == i
	}
	assert operations_tab_labels.len == 4 && operations_tab_marks.len == 4 && operations_detail_titles.len == 4
}

fn test_operations_layout_shares_geometry_and_collapses_floor() {
	mut app := &GuiApp{}
	app.selected_panel = 6
	l := operations_layout(app, 1280, 800)
	// panel and detail column agree with the shell constants
	assert l.fx == panel_fx(app) && l.fw == panel_fw(app, 1280)
	assert l.side_x == inspector_x(app, 1280) && l.side_w == inspector_w
	// the floor and the table never overlap, both stay inside the panel
	assert l.floor_w > 0
	assert l.floor_x + l.floor_w < l.right_x
	assert l.right_x + l.right_w <= l.fx + l.fw
	assert l.table_y + l.table_h <= l.fy + l.fh
	// four cards on one row at the canonical width
	assert l.cards_n == 4
	x3, _, w3, _ := operations_card_rect(l, 3)
	assert x3 + w3 <= l.fx + l.fw
	// tabs sit inside the right column
	tx, _, tw, _ := operations_tab_rect(l, 3)
	assert tx + tw <= l.right_x + l.right_w
	// narrow window: the floor collapses before the table loses rows, cards
	// reflow to two per row, the table takes the full width
	app.selected_panel = 5
	n := operations_layout(app, 900, 620)
	assert n.floor_w == 0
	assert n.right_x == n.fx + 12
	assert n.cards_n == 2
	assert operations_visible_rows(n) >= 3
	// Doctor/Swarms carry a strip; Jobs/Loops do not
	assert n.strip_h > 0
	app.selected_panel = 7
	assert operations_layout(app, 900, 620).strip_h == 0
}

fn test_operations_rows_are_never_fabricated_without_engine() {
	mut app := &GuiApp{}
	for tab in 0 .. 4 {
		assert operations_rows(mut app, tab).len == 0
	}
	assert operations_metrics(mut app).len == 0
	assert operations_actions(mut app, 0, 0).len == 0
	// selection is revalidated against the real list length
	app.jobs_selected = 3
	assert operations_selected(app, 0, 0) == -1
	assert operations_selected(app, 0, 4) == 3
	app.doctor_selected = 0
	assert operations_selected(app, 3, 0) == -1
}

fn test_operations_filter_and_search() {
	rows := [
		OperationsRow{0, 'job-a', ['build cli', 'job-a', 'running', '10:22', '2m 14s'], 'running', false},
		OperationsRow{1, 'job-b', ['test desktop', 'job-b', 'failed', '10:25', '4s'], 'failed', false},
		OperationsRow{2, 'job-c', ['serve', 'job-c', 'queued', '—', '—'], 'queued', false},
	]
	assert operations_apply_filter(rows, '', '').len == 3
	assert operations_apply_filter(rows, '', 'failed').len == 1
	assert operations_apply_filter(rows, 'DESKTOP', '').len == 1
	assert operations_apply_filter(rows, 'job-', 'queued')[0].idx == 2
	assert operations_apply_filter(rows, 'nothing', '').len == 0
	// dropdown index wraps per tab and index 0 is always "all"
	assert operations_filter_key(0, 0) == ''
	assert operations_filter_key(0, 1) == 'running'
	labels, keys := operations_filter_options(0)
	assert labels.len == keys.len
	assert operations_filter_key(0, keys.len) == ''
	assert operations_filter_label(1, 1) == 'Scheduled'
	assert operations_filter_key(3, 3) == 'fail'
}

fn test_operations_formatting_is_honest_about_missing_values() {
	assert format_duration_ms(0) == '—'
	assert format_duration_ms(-5) == '—'
	assert format_duration_ms(850) == '850ms'
	assert format_duration_ms(4000) == '4s'
	assert format_duration_ms(137000) == '2m 17s'
	assert format_duration_ms(3720000) == '1h 02m'
	assert format_started_time(0) == '—'
	assert format_started_time(1700000000).len > 0
	assert job_status_key(.running) == 'running'
	assert job_status_key(.canceled) == 'canceled'
	assert swarm_status_key(.awaiting_approval) == 'awaiting'
	assert loop_tier_label(.l3) == 'L3'
}

fn test_operations_job_name_from_command() {
	j := desktop_engine.JobRecord{
		id: 'job-7f3a'
		cmd: '/usr/bin/agent-toolkit loop run daily-triage'
	}
	assert job_display_name(j) == 'agent-toolkit loop'
	bare := desktop_engine.JobRecord{
		id: 'job-9c1e'
		cmd: 'v'
		args: ['test', 'modules/desktop']
	}
	assert job_display_name(bare) == 'v test'
	empty := desktop_engine.JobRecord{
		id: 'job-x'
	}
	assert job_display_name(empty) == 'job-x'
}

fn test_operations_pill_labels_are_textual() {
	app := &GuiApp{}
	for key in ['running', 'queued', 'done', 'failed', 'canceled', 'pass', 'warn', 'fail', 'scheduled',
		'on_demand', 'awaiting', 'pending'] {
		label, _ := operations_pill(app, key)
		assert label.len > 0, 'status ${key} needs a text label (never color-only)'
	}
	// the Doctor "fail" and job "failed" share the rust semantic
	l1, c1 := operations_pill(app, 'fail')
	l2, c2 := operations_pill(app, 'failed')
	assert l1 == l2 && c1 == c2
}

fn test_operations_detail_anchors_stay_inside_column() {
	mut app := &GuiApp{}
	app.selected_panel = 8
	l := operations_layout(app, 1280, 800)
	for n in 1 .. 4 {
		for i in 0 .. n {
			ax, ay, aw, ah := operations_action_rect(l, i, n)
			assert ax >= l.side_x && ax + aw <= l.side_x + l.side_w
			assert ay + ah <= l.side_y + l.side_h
		}
	}
	_, ry, _, _ := operations_related_rect(l, 1)
	_, ay0, _, _ := operations_action_rect(l, 0, 1)
	assert ry > ay0
	_, apy, _, _ := operations_approval_rect(l, 2)
	assert apy < ay0
	assert operations_detail_content_bottom(l) < apy
}
