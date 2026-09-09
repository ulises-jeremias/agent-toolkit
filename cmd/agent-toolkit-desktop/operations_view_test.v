module main

import desktop_engine

// VC6 (#1173) — Operations command center: geometry sharing, truthful empty
// states, and the Engine → row projection helpers.

fn test_ops_tab_panel_mapping() {
	assert ops_tab_for_panel(6) == 0 // Jobs
	assert ops_tab_for_panel(7) == 1 // Loops
	assert ops_tab_for_panel(8) == 2 // Swarms
	assert ops_tab_for_panel(5) == 3 // Doctor
	assert ops_tab_for_panel(0) == -1
	assert ops_is_panel(5) && ops_is_panel(8)
	assert !ops_is_panel(1) && !ops_is_panel(11)
	for i, p in ops_tab_panels {
		assert ops_tab_for_panel(p) == i
	}
	assert ops_tab_labels.len == 4 && ops_tab_marks.len == 4 && ops_detail_titles.len == 4
}

fn test_ops_layout_shares_geometry_and_collapses_floor() {
	mut app := &GuiApp{}
	app.selected_panel = 6
	l := ops_layout(app, 1280, 800)
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
	x3, _, w3, _ := ops_card_rect(l, 3)
	assert x3 + w3 <= l.fx + l.fw
	// tabs sit inside the right column
	tx, _, tw, _ := ops_tab_rect(l, 3)
	assert tx + tw <= l.right_x + l.right_w
	// narrow window: the floor collapses before the table loses rows, cards
	// reflow to two per row, the table takes the full width
	app.selected_panel = 5
	n := ops_layout(app, 900, 620)
	assert n.floor_w == 0
	assert n.right_x == n.fx + 12
	assert n.cards_n == 2
	assert ops_visible_rows(n) >= 3
	// Doctor/Swarms carry a strip; Jobs/Loops do not
	assert n.strip_h > 0
	app.selected_panel = 7
	assert ops_layout(app, 900, 620).strip_h == 0
}

fn test_ops_rows_are_never_fabricated_without_engine() {
	mut app := &GuiApp{}
	for tab in 0 .. 4 {
		assert ops_rows(mut app, tab).len == 0
	}
	assert ops_metrics(mut app).len == 0
	assert ops_actions(mut app, 0, 0).len == 0
	// selection is revalidated against the real list length
	app.jobs_selected = 3
	assert ops_selected(app, 0, 0) == -1
	assert ops_selected(app, 0, 4) == 3
	app.doctor_selected = 0
	assert ops_selected(app, 3, 0) == -1
}

fn test_ops_filter_and_search() {
	rows := [
		OpsRow{0, 'job-a', ['build cli', 'job-a', 'running', '10:22', '2m 14s'], 'running', false},
		OpsRow{1, 'job-b', ['test desktop', 'job-b', 'failed', '10:25', '4s'], 'failed', false},
		OpsRow{2, 'job-c', ['serve', 'job-c', 'queued', '—', '—'], 'queued', false},
	]
	assert ops_apply_filter(rows, '', '').len == 3
	assert ops_apply_filter(rows, '', 'failed').len == 1
	assert ops_apply_filter(rows, 'DESKTOP', '').len == 1
	assert ops_apply_filter(rows, 'job-', 'queued')[0].idx == 2
	assert ops_apply_filter(rows, 'nothing', '').len == 0
	// dropdown index wraps per tab and index 0 is always "all"
	assert ops_filter_key(0, 0) == ''
	assert ops_filter_key(0, 1) == 'running'
	labels, keys := ops_filter_options(0)
	assert labels.len == keys.len
	assert ops_filter_key(0, keys.len) == ''
	assert ops_filter_label(1, 1) == 'Scheduled'
	assert ops_filter_key(3, 3) == 'fail'
}

fn test_ops_formatting_is_honest_about_missing_values() {
	assert ops_fmt_duration(0) == '—'
	assert ops_fmt_duration(-5) == '—'
	assert ops_fmt_duration(850) == '850ms'
	assert ops_fmt_duration(4000) == '4s'
	assert ops_fmt_duration(137000) == '2m 17s'
	assert ops_fmt_duration(3720000) == '1h 02m'
	assert ops_fmt_started(0) == '—'
	assert ops_fmt_started(1700000000).len > 0
	assert ops_job_status_key(.running) == 'running'
	assert ops_job_status_key(.canceled) == 'canceled'
	assert ops_swarm_status_key(.awaiting_approval) == 'awaiting'
	assert ops_tier_label(.l3) == 'L3'
}

fn test_ops_job_name_from_command() {
	j := desktop_engine.JobRecord{
		id: 'job-7f3a'
		cmd: '/usr/bin/agent-toolkit loop run daily-triage'
	}
	assert ops_job_name(j) == 'agent-toolkit loop'
	bare := desktop_engine.JobRecord{
		id: 'job-9c1e'
		cmd: 'v'
		args: ['test', 'modules/desktop']
	}
	assert ops_job_name(bare) == 'v test'
	empty := desktop_engine.JobRecord{
		id: 'job-x'
	}
	assert ops_job_name(empty) == 'job-x'
}

fn test_ops_pill_labels_are_textual() {
	app := &GuiApp{}
	for key in ['running', 'queued', 'done', 'failed', 'canceled', 'pass', 'warn', 'fail', 'scheduled',
		'on_demand', 'awaiting', 'pending'] {
		label, _ := ops_pill(app, key)
		assert label.len > 0, 'status ${key} needs a text label (never color-only)'
	}
	// the Doctor "fail" and job "failed" share the rust semantic
	l1, c1 := ops_pill(app, 'fail')
	l2, c2 := ops_pill(app, 'failed')
	assert l1 == l2 && c1 == c2
}

fn test_ops_detail_anchors_stay_inside_column() {
	mut app := &GuiApp{}
	app.selected_panel = 8
	l := ops_layout(app, 1280, 800)
	for n in 1 .. 4 {
		for i in 0 .. n {
			ax, ay, aw, ah := ops_action_rect(l, i, n)
			assert ax >= l.side_x && ax + aw <= l.side_x + l.side_w
			assert ay + ah <= l.side_y + l.side_h
		}
	}
	_, ry, _, _ := ops_related_rect(l, 1)
	_, ay0, _, _ := ops_action_rect(l, 0, 1)
	assert ry > ay0
	_, apy, _, _ := ops_approval_rect(l, 2)
	assert apy < ay0
	assert ops_detail_content_bottom(l) < apy
}
