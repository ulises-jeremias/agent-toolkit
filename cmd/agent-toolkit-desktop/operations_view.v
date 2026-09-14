module main

import gg
import time
import desktop.pixelart
import desktop.runtime.swarm as swarm_rt
import desktop_engine

// Operations: the operational command center.
//
// Canonical visual reference: docs/desktop/assets/design/operations.jpg with
// concept-board.jpg as the shell/material authority. The four Operations
// panels (Doctor 5, Jobs 6, Loops 7, Swarm 8) share one composition: an
// editorial header band, four metric cards, the pixel-art Operations Floor on the left,
// a tabbed dense table on the right, and a "Details" column that replaces the
// Office inspector while an Operations panel is selected.
//
// Truth rules (DESIGN.md §4, §10 Operations):
// - every number, row and status comes from Engine records (jobs catalog,
//   loops catalog, swarm runs, doctor checks). Idle machines show 0 and an
//   honest empty state — nothing is invented to look busy;
// - the Floor is environment: catalog agents sit idle at desks; only the real
//   running-job count flips agents to the running variant;
// - progress bars are omitted because the Engine has no measured fraction;
// - actions execute through the Engine (cancel/retry/run/schedule/launch/
//   approve/fix) and report the actual result. Nothing is drawn that has no
//   real handler behind it.
//
// One layout struct per frame (OperationsLayout) drives drawing, hover, click and
// scroll so hit-testing can never drift from the pixels.

// ── tabs ────────────────────────────────────────────────────────────────────

const operations_tab_labels = ['Jobs', 'Loops', 'Swarms', 'Doctor']

const operations_tab_panels = [6, 7, 8, 5]

const operations_tab_marks = [pixelart.EnvironmentAsset.play_mark, .calendar_mark, .swarm_mark, .alert_mark]

const operations_detail_titles = ['Job Details', 'Loop Details', 'Swarm Details', 'Check Details']

const operations_search_hints = ['Search jobs…', 'Search loops…', 'Search swarms…', 'Search checks…']

// operations_tab_for_panel maps a nav panel id to its Operations tab (0..3), or -1.
fn operations_tab_for_panel(panel int) int {
	for i, p in operations_tab_panels {
		if p == panel {
			return i
		}
	}
	return -1
}

// operations_is_panel reports whether the panel belongs to Operations.
fn operations_is_panel(panel int) bool {
	return operations_tab_for_panel(panel) >= 0
}

// ── layout ──────────────────────────────────────────────────────────────────

// OperationsLayout is computed once per frame and shared by draw, hover, click and
// scroll. Rects with w == 0 or h == 0 are absent at this window size.
struct OperationsLayout {
	tab     int
	fx      int
	fy      int
	fw      int
	fh      int
	head_y  int
	head_h  int
	cards_y int
	card_h  int
	cards_n int // cards per row: 4, or 2 when the panel is narrow
	body_y  int
	body_h  int
	floor_x int
	floor_y int
	floor_w int // 0 → the floor collapses (task completion first)
	floor_h int
	right_x int
	right_w int
	tab_y   int
	tab_h   int
	ctl_y   int
	ctl_h   int
	strip_y int
	strip_h int // launch strip (Swarms) / repair strip (Doctor), else 0
	table_y int
	table_h int
	hdr_h   int
	row_h   int
	topo_y  int
	topo_h  int // Swarms handoff topology under the table, 0 when absent
	side_x  int
	side_y  int
	side_w  int
	side_h  int
	compact bool
}

fn operations_layout(app &GuiApp, w int, h int) OperationsLayout {
	tab := operations_tab_for_panel(app.selected_panel)
	fx := panel_fx(app)
	fy := shell_mast_h(h)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	compact := fh < 420 || fw < 640
	head_y := fy + 8
	head_h := if compact { 54 } else { 72 }
	cards_n := if fw >= 640 { 4 } else { 2 }
	card_h := if compact { 56 } else { 68 }
	cards_y := head_y + head_h + 8
	cards_rows := if cards_n == 4 { 1 } else { 2 }
	body_y := cards_y + cards_rows * card_h + (cards_rows - 1) * 10 + 12
	body_h_raw := fy + fh - 10 - body_y
	body_h := if body_h_raw > 0 { body_h_raw } else { 0 }
	has_body := body_h >= 60
	// the floor is secondary environmental detail: it collapses before the
	// table loses a single readable row (DESIGN.md §16)
	mut floor_w := 0
	if fw >= 720 && body_h >= 220 {
		floor_w = fw * 40 / 100
		if floor_w > 440 {
			floor_w = 440
		}
	}
	floor_x := fx + 12
	right_x := if floor_w > 0 { floor_x + floor_w + 14 } else { fx + 12 }
	right_w := fx + fw - 12 - right_x
	tab_h := if has_body { 30 } else { 0 }
	ctl_h := if has_body { 26 } else { 0 }
	// Slice B (#1229): Jobs carries a spawn strip (command + Spawn); Swarms
	// keeps the launch strip, Doctor the repair strip. Loops has no strip —
	// loop creation lives in the detail column so empty catalogs can create.
	strip_h := if has_body && (tab == 0 || tab == 2 || tab == 3) { 34 } else { 0 }
	tab_y := body_y
	ctl_y := tab_y + tab_h + 6
	strip_y := ctl_y + ctl_h + 6
	table_y := strip_y + strip_h + if strip_h > 0 { 6 } else { 0 }
	table_h_raw := fy + fh - 10 - table_y
	mut table_h := if has_body && table_h_raw > 0 { table_h_raw } else { 0 }
	mut topo_h := 0
	if tab == 2 && table_h > 250 && app.swarm_nodes.len > 0 {
		topo_h = 96
		table_h -= topo_h + 8
	}
	topo_y := table_y + table_h + 8
	return OperationsLayout{
		tab: tab
		fx: fx
		fy: fy
		fw: fw
		fh: fh
		head_y: head_y
		head_h: head_h
		cards_y: cards_y
		card_h: card_h
		cards_n: cards_n
		body_y: body_y
		body_h: body_h
		floor_x: floor_x
		floor_y: body_y
		floor_w: floor_w
		floor_h: body_h
		right_x: right_x
		right_w: right_w
		tab_y: tab_y
		tab_h: tab_h
		ctl_y: ctl_y
		ctl_h: ctl_h
		strip_y: strip_y
		strip_h: strip_h
		table_y: table_y
		table_h: table_h
		hdr_h: 22
		row_h: 26
		topo_y: topo_y
		topo_h: topo_h
		side_x: inspector_x(app, w)
		side_y: fy
		side_w: inspector_w
		side_h: fh
		compact: compact
	}
}

// ── shared rects (draw == hit) ──────────────────────────────────────────────

fn operations_card_rect(l OperationsLayout, i int) (int, int, int, int) {
	gap := 10
	cw := (l.fw - 24 - (l.cards_n - 1) * gap) / l.cards_n
	col := i % l.cards_n
	row := i / l.cards_n
	return l.fx + 12 + col * (cw + gap), l.cards_y + row * (l.card_h + gap), cw, l.card_h
}

fn operations_tab_rect(l OperationsLayout, i int) (int, int, int, int) {
	tw := if l.right_w >= 420 { 96 } else { l.right_w / 4 }
	return l.right_x + i * tw, l.tab_y, tw, l.tab_h
}

fn operations_search_rect(l OperationsLayout) (int, int, int, int) {
	fw := operations_filter_w(l)
	return l.right_x, l.ctl_y, l.right_w - fw - 8, l.ctl_h
}

fn operations_filter_w(l OperationsLayout) int {
	return if l.right_w >= 420 { 130 } else { 104 }
}

fn operations_filter_rect(l OperationsLayout) (int, int, int, int) {
	fw := operations_filter_w(l)
	return l.right_x + l.right_w - fw, l.ctl_y, fw, l.ctl_h
}

// operations_visible_rows is the number of table rows that fit under the header.
fn operations_visible_rows(l OperationsLayout) int {
	// 18px reserved under the last row for the 'a–b of N' footer note
	n := (l.table_h - l.hdr_h - 22) / l.row_h
	return if n < 0 { 0 } else { n }
}

fn operations_row_rect(l OperationsLayout, vis int) (int, int, int, int) {
	return l.right_x, l.table_y + l.hdr_h + 2 + vis * l.row_h, l.right_w, l.row_h
}

// swarm launch strip: task field, three backend chips, three recipe buttons
fn operations_task_rect(l OperationsLayout) (int, int, int, int) {
	mut tw := l.right_w - 3 * 54 - 3 * 62 - 24
	if tw < 120 {
		tw = 120
	}
	return l.right_x, l.strip_y + 4, tw, l.strip_h - 8
}

fn operations_backend_rect(l OperationsLayout, i int) (int, int, int, int) {
	_, _, tw, _ := operations_task_rect(l)
	return l.right_x + tw + 8 + i * 54, l.strip_y + 5, 50, l.strip_h - 10
}

fn operations_recipe_rect(l OperationsLayout, i int) (int, int, int, int) {
	_, _, tw, _ := operations_task_rect(l)
	return l.right_x + tw + 8 + 3 * 54 + 8 + i * 62, l.strip_y + 4, 58, l.strip_h - 8
}

// doctor repair strip: Fix All + category chips (stored in app.doctor_chips)
fn operations_fixall_rect(l OperationsLayout) (int, int, int, int) {
	return l.right_x, l.strip_y + 4, 72, l.strip_h - 8
}

// topology zoom buttons (− / +) in the strip header
fn operations_zoom_rects(l OperationsLayout) (int, int, int, int, int, int) {
	return l.right_x + l.right_w - 56, l.topo_y + 4, l.right_x + l.right_w - 28, l.topo_y + 4, 24, 18
}

// detail column geometry — fixed anchors so draw and click agree regardless
// of how many fact rows the selected record carries
fn operations_action_rect(l OperationsLayout, i int, n int) (int, int, int, int) {
	gap := 6
	bw := (l.side_w - 24 - (n - 1) * gap) / n
	return l.side_x + 12 + i * (bw + gap), l.side_y + l.side_h - 82, bw, 28
}

fn operations_related_rect(l OperationsLayout, i int) (int, int, int, int) {
	return l.side_x + 12 + i * ((l.side_w - 24) / 2), l.side_y + l.side_h - 40, (l.side_w - 24) / 2, 20
}

// approvals (Swarms) live above the action row, max three rows
fn operations_approval_rect(l OperationsLayout, i int) (int, int, int, int) {
	return l.side_x + 12, l.side_y + l.side_h - 82 - 12 - (3 - i) * 22, l.side_w - 24, 20
}

// tasks (Swarms) live above the approvals strip, max four mixed rows:
// queued first with a Complete button, then done. No drag/drop theater —
// every transition is the queued→completed Engine seam with a receipt.
fn operations_board_rect(l OperationsLayout, i int) (int, int, int, int) {
	_, ay, _, _ := operations_approval_rect(l, 0)
	return l.side_x + 12, ay - 30 - (4 - i) * 22, l.side_w - 24, 20
}

fn operations_board_done_rect(l OperationsLayout, i int) (int, int, int, int) {
	x, y, w, h := operations_board_rect(l, i)
	return x + w - 70, y, 70, h
}

fn rect_contains(mx int, my int, x int, y int, w int, h int) bool {
	return w > 0 && h > 0 && mx >= x && mx < x + w && my >= y && my < y + h
}

// ── data model ──────────────────────────────────────────────────────────────

// OperationsRow is one table row projected from an Engine record. idx points back
// into the unfiltered Engine list (selection stays stable while filtering).
struct OperationsRow {
	idx     int
	id      string
	cells   []string
	status  string // semantic key, see operations_pill
	fixable bool
}

// OperationsColumns describes the per-tab table: headers, relative widths and which
// column renders as a status pill.
struct OperationsColumns {
	headers    []string
	weights    []int
	status_idx int
}

fn operations_columns(tab int) OperationsColumns {
	return match tab {
		0 {
			OperationsColumns{['Name', 'ID', 'Status', 'Started', 'Elapsed'], [34, 18, 16, 16, 16], 2}
		}
		1 {
			OperationsColumns{['Name', 'Tier', 'Cadence', 'Schedule', 'Last run'], [30, 9, 13, 26, 22], 3}
		}
		2 {
			OperationsColumns{['Name', 'Recipe', 'Backend', 'Status', 'Started'], [34, 14, 16, 20, 16], 3}
		}
		else {
			OperationsColumns{['Check', 'Category', 'Status', 'Message', 'Fix'], [26, 16, 14, 36, 8], 2}
		}
	}
}

// operations_filter_options returns the status dropdown entries per tab. Entry 0 is
// always "All"; the rest are semantic status keys with display labels.
fn operations_filter_options(tab int) ([]string, []string) {
	return match tab {
		0 {
			['All statuses', 'Running', 'Queued', 'Done', 'Failed', 'Canceled'], ['', 'running',
				'queued', 'done', 'failed', 'canceled']
		}
		1 {
			['All loops', 'Scheduled', 'On demand'], ['', 'scheduled', 'on_demand']
		}
		2 {
			['All statuses', 'Running', 'Awaiting', 'Pending', 'Completed', 'Failed'], ['', 'running',
				'awaiting', 'pending', 'completed', 'failed']
		}
		else {
			['All checks', 'Pass', 'Warn', 'Fail'], ['', 'pass', 'warn', 'fail']
		}
	}
}

// operations_filter_key resolves the active dropdown index to a status key ('' = all).
fn operations_filter_key(tab int, idx int) string {
	_, keys := operations_filter_options(tab)
	if keys.len == 0 {
		return ''
	}
	i := ((idx % keys.len) + keys.len) % keys.len
	return keys[i]
}

fn operations_filter_label(tab int, idx int) string {
	labels, _ := operations_filter_options(tab)
	i := ((idx % labels.len) + labels.len) % labels.len
	return labels[i]
}

// format_duration_ms renders milliseconds the way the reference does
// ("4m 37s") — '—' when nothing was measured.
fn format_duration_ms(ms int) string {
	if ms <= 0 {
		return '—'
	}
	if ms < 1000 {
		return '${ms}ms'
	}
	s := ms / 1000
	if s < 60 {
		return '${s}s'
	}
	m := s / 60
	if m < 60 {
		return '${m}m ${s % 60:02d}s'
	}
	return '${m / 60}h ${m % 60:02d}m'
}

// format_started_time renders a unix timestamp as a local clock (today) or a
// short date + clock; 0 means the record never started ('—').
fn format_started_time(unix i64) string {
	if unix <= 0 {
		return '—'
	}
	t := time.unix(unix).local()
	now := ui_now()
	clock := '${t.hour:02d}:${t.minute:02d}'
	if t.ymmdd() == now.ymmdd() {
		return clock
	}
	return '${t.smonth()} ${t.day} ${clock}'
}

// job_status_key maps the Engine enum to the semantic status key.
fn job_status_key(s desktop_engine.JobStatus) string {
	return match s {
		.running { 'running' }
		.queued { 'queued' }
		.done { 'done' }
		.failed { 'failed' }
		.canceled { 'canceled' }
	}
}

fn swarm_status_key(s desktop_engine.SwarmRunStatus) string {
	return match s {
		.requested { 'requested' }
		.pending { 'pending' }
		.running { 'running' }
		.awaiting_approval { 'awaiting' }
		.completed { 'completed' }
		.failed { 'failed' }
		.canceled { 'canceled' }
	}
}

fn loop_tier_label(t desktop_engine.LoopTier) string {
	return match t {
		.l1 { 'L1' }
		.l2 { 'L2' }
		.l3 { 'L3' }
	}
}

// job_display_name gives a job a human name: the command's last path segment
// plus its first argument — the id stays in its own column.
fn job_display_name(j desktop_engine.JobRecord) string {
	mut base := j.cmd.trim_space()
	if base == '' {
		return j.id
	}
	first := base.split(' ')[0]
	seg := first.split('/')
	mut name := seg[seg.len - 1]
	rest := base.all_after(first).trim_space()
	if rest != '' {
		name += ' ' + rest.split(' ')[0]
	} else if j.args.len > 0 {
		name += ' ' + j.args[0]
	}
	return name
}

// operations_rows projects the active tab's Engine records into table rows. No
// fallbacks, no placeholders: an empty Engine list is an empty table.
fn operations_rows(mut app GuiApp, tab int) []OperationsRow {
	mut rows := []OperationsRow{}
	if app.desktop == unsafe { nil } {
		return rows
	}
	match tab {
		0 {
			for i, j in app.desktop.engine_jobs_catalog() {
				short := if j.id.len > 14 { j.id[..14] } else { j.id }
				rows << OperationsRow{
					idx: i
					id: j.id
					cells: [job_display_name(j), short, job_status_key(j.status),
						format_started_time(j.started_at), format_duration_ms(j.duration_ms)]
					status: job_status_key(j.status)
				}
			}
		}
		1 {
			for i, e in app.desktop.loops_catalog() {
				sched := if e.cron_enabled { 'scheduled' } else { 'on_demand' }
				last := if e.last_run.trim_space() != '' { e.last_run } else { '—' }
				rows << OperationsRow{
					idx: i
					id: e.name
					cells: [e.name, loop_tier_label(e.tier), e.cadence, sched, last]
					status: sched
				}
			}
		}
		2 {
			for i, s in app.desktop.swarm_list() {
				rows << OperationsRow{
					idx: i
					id: s.id
					cells: [s.id, s.recipe.str(), s.backend.str(), swarm_status_key(s.status),
						format_started_time(s.created_at)]
					status: swarm_status_key(s.status)
				}
			}
		}
		else {
			for i, c in app.desktop.engine_doctor() {
				st := if c.status == 'ok' { 'pass' } else { c.status }
				fix := if c.fixable && st != 'pass' { 'fix →' } else { '' }
				rows << OperationsRow{
					idx: i
					id: c.id
					cells: [c.name, c.category, st, c.message, fix]
					status: st
					fixable: c.fixable && st != 'pass'
				}
			}
		}
	}
	return rows
}

// operations_apply_filter keeps rows matching the search text (any cell) and the
// status key ('' keeps everything).
fn operations_apply_filter(rows []OperationsRow, query string, status_key string) []OperationsRow {
	q := query.trim_space().to_lower()
	mut out := []OperationsRow{}
	for r in rows {
		if status_key != '' && r.status != status_key {
			continue
		}
		if q != '' {
			mut hit := false
			for c in r.cells {
				if c.to_lower().contains(q) {
					hit = true
					break
				}
			}
			if !hit && !r.id.to_lower().contains(q) {
				continue
			}
		}
		out << r
	}
	return out
}

// operations_selected returns the selected index (into the unfiltered list) for the
// tab, or -1. Selection is revalidated against the current length so a
// stale index never reads past the Engine list.
fn operations_selected(app &GuiApp, tab int, total int) int {
	sel := match tab {
		0 { app.jobs_selected }
		1 { app.selected_loop }
		2 { app.swarm_selected }
		else { app.doctor_selected }
	}
	return if sel >= 0 && sel < total { sel } else { -1 }
}

fn operations_set_selected(mut app GuiApp, tab int, idx int) {
	match tab {
		0 {
			app.jobs_selected = idx
		}
		1 {
			app.selected_loop = idx
		}
		2 {
			app.swarm_selected = idx
		}
		else {
			app.doctor_selected = idx
		}
	}
}

fn operations_scroll_of(app &GuiApp, tab int) int {
	return match tab {
		0 { app.jobs_scroll }
		1 { app.loops_scroll }
		2 { app.swarm_scroll }
		else { app.doctor_scroll }
	}
}

fn operations_set_scroll(mut app GuiApp, tab int, v int) {
	match tab {
		0 {
			app.jobs_scroll = v
		}
		1 {
			app.loops_scroll = v
		}
		2 {
			app.swarm_scroll = v
		}
		else {
			app.doctor_scroll = v
		}
	}
}

// ── metric cards: real counts + truthful sub-lines ──────────────────────────

struct OperationsMetric {
	mark  pixelart.EnvironmentAsset
	value int
	label string
	sub   string
	alert bool // rust accent when the number means trouble
}

fn operations_metrics(mut app GuiApp) []OperationsMetric {
	mut out := []OperationsMetric{}
	if app.desktop == unsafe { nil } {
		return out
	}
	stats := app.desktop.engine_job_stats()
	jobs_sub := if stats.running == 0 {
		if stats.total == 0 { 'No jobs running' } else { '${stats.total} in the queue history' }
	} else {
		'${stats.queued} queued · ${stats.done} done'
	}
	out << OperationsMetric{.play_mark, stats.running, 'Running jobs', jobs_sub, false}
	loops := app.desktop.loops_catalog()
	scheduled := loops.filter(it.cron_enabled).len
	loops_sub := if loops.len == 0 {
		'No loop templates found'
	} else if scheduled == 0 {
		'No loops scheduled · ${loops.len} on demand'
	} else {
		'${loops.len - scheduled} on demand'
	}
	out << OperationsMetric{.calendar_mark, scheduled, 'Scheduled loops', loops_sub, false}
	swarms := app.desktop.swarm_list()
	active := swarms.filter(it.status == .running || it.status == .awaiting_approval).len
	swarm_sub := if swarms.len == 0 {
		'No swarm sessions'
	} else if active == 0 {
		'None active'
	} else {
		'${active} active'
	}
	out << OperationsMetric{.swarm_mark, swarms.len, 'Swarm sessions', swarm_sub, false}
	checks := app.desktop.engine_doctor()
	fail := checks.filter(it.status == 'fail').len
	warn := checks.filter(it.status == 'warn').len
	issues := fail + warn
	doc_sub := if checks.len == 0 {
		'No checks reported'
	} else if issues == 0 {
		'${checks.len} checks pass'
	} else {
		'${fail} fail · ${warn} warn'
	}
	out << OperationsMetric{.alert_mark, issues, 'Doctor issues', doc_sub, issues > 0}
	return out
}

// ── material helpers ────────────────────────────────────────────────────────
// (the paper surface draw_paper_sheet lives once in workspace_view.v.)

// operations_pc resolves a palette key without requiring the GPU sprite cache, so
// pure helpers (pills) stay testable headless; at frame time it is the same
// authored palette pc() reads.
fn operations_pc(app &GuiApp, k u8) gg.Color {
	if app.pixel_cache != unsafe { nil } {
		return pc(app, k)
	}
	c := pixelart.palette_for(office_palette_id(app)).rgba(k)
	return gg.Color{
		r: c[0]
		g: c[1]
		b: c[2]
		a: 255
	}
}

// operations_pill resolves a semantic status key to (label, color). Status is never
// color-only: the label is always drawn next to the dot.
fn operations_pill(app &GuiApp, status string) (string, gg.Color) {
	return match status {
		'running' { 'Running', app.pnl_success }
		'queued' { 'Queued', operations_pc(app, `C`) }
		'pending', 'requested' { 'Pending', operations_pc(app, `C`) }
		'awaiting' { 'Awaiting', app.pnl_select }
		'paused' { 'Paused', app.pnl_select }
		'warn' { 'Warn', app.pnl_select }
		'done', 'completed' { 'Done', app.pnl_text_mut }
		'pass' { 'Pass', app.pnl_success }
		'fail', 'failed' { 'Failed', operations_pc(app, `a`) }
		'canceled' { 'Canceled', app.pnl_text_mut }
		'scheduled' { 'Scheduled', app.pnl_success }
		'on_demand' { 'On demand', app.pnl_text_mut }
		else { status, app.pnl_text_mut }
	}
}

fn operations_draw_pill(mut app GuiApp, x int, y int, status string, max_w int) {
	label, col := operations_pill(app, status)
	mut pw := label.len * 7 + 22
	if pw > max_w && max_w > 30 {
		pw = max_w
	}
	app.gg.draw_rect_filled(x, y, pw, 18, tint(col, 42))
	app.gg.draw_rect_empty(x, y, pw, 18, tint(col, 140))
	app.gg.draw_rect_filled(x + 6, y + 6, 6, 6, col)
	app.gg.draw_text(x + 16, y + 3, utf8_truncate(label, (pw - 18) / 7), gg.TextCfg{
		color: if app.appearance_dark { app.pnl_text } else { mix(col, app.pnl_text, 0.45) }
		size: 11
		bold: true
	})
}

// operations_button draws a quiet paper button; primary gets the brass fill.
fn operations_button(mut app GuiApp, x int, y int, w int, h int, label string, hover bool, primary bool, danger bool) {
	bg := if danger {
		if hover { pc(app, `a`) } else { tint(pc(app, `a`), 60) }
	} else if primary {
		if hover { app.pnl_select_hover } else { app.pnl_select }
	} else {
		if hover { app.pnl_hover } else { app.pnl_card_sel }
	}
	bd := if danger {
		pc(app, `a`)
	} else if primary {
		app.pnl_select
	} else {
		app.pnl_border
	}
	fg := if danger && hover {
		pc(app, `e`)
	} else if primary && !app.appearance_dark {
		app.pnl_text
	} else {
		app.pnl_text
	}
	app.gg.draw_rect_filled(x, y, w, h, bg)
	app.gg.draw_rect_empty(x, y, w, h, bd)
	tw := label.len * 7
	tx := x + if tw + 8 < w { (w - tw) / 2 } else { 6 }
	app.gg.draw_text(tx, y + (h - 14) / 2, utf8_truncate(label, (w - 8) / 7), gg.TextCfg{
		color: fg
		size: 12
		bold: primary || danger
	})
}

// operations_field draws a text field (search / task) with placeholder and caret.
fn operations_field(mut app GuiApp, x int, y int, w int, h int, value string, hint string, focused bool, lens bool) {
	app.gg.draw_rect_filled(x, y, w, h, app.pnl_bg)
	app.gg.draw_rect_empty(x, y, w, h, if focused { app.pnl_success } else { app.pnl_border })
	mut tx := x + 8
	if lens {
		draw_search_lens(mut app, x + 8, y + (h - 12) / 2)
		tx = x + 26
	}
	shown := if value == '' { hint } else { value }
	max_c := (x + w - tx - 6) / 7
	app.gg.draw_text(tx, y + (h - 14) / 2, utf8_truncate(shown, max_c), gg.TextCfg{
		color: if value == '' { app.pnl_text_mut } else { app.pnl_text }
		size: 12
	})
	if focused && app.frame % 30 < 15 {
		shown_len := if value.len > max_c { max_c } else { value.len }
		cx := tx + shown_len * 7 + 1
		app.gg.draw_rect_filled(cx, y + 6, 1, h - 12, app.pnl_text)
	}
}

// draw_check_glyph and text_fit_chars live once in onboarding_view.v.

// ── drawing: panel ──────────────────────────────────────────────────────────

// draw_operations is the shared panel body for Doctor/Jobs/Loops/Swarm.
fn draw_operations(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	l := operations_layout(app, w, h)
	app.gg.draw_rect_filled(l.fx, l.fy, l.fw, l.fh, app.pnl_bg)
	draw_operations_header(mut app, l)
	draw_operations_cards(mut app, l)
	if l.body_h < 60 {
		return
	}
	stats_running, stats_attention := operations_floor_counts(mut app)
	if l.floor_w > 0 {
		draw_operations_floor(mut app, l.floor_x, l.floor_y, l.floor_w, l.floor_h, stats_running, stats_attention)
	}
	draw_operations_tabs(mut app, l)
	draw_operations_controls(mut app, l)
	if l.tab == 0 {
		draw_operations_spawn_strip(mut app, l)
	} else if l.tab == 2 {
		draw_operations_launch_strip(mut app, l)
	} else if l.tab == 3 {
		draw_operations_repair_strip(mut app, l)
	}
	draw_operations_table(mut app, l)
	if l.tab == 2 {
		draw_operations_topology(mut app, l)
	}
	if l.tab == 3 && app.doctor_preview != '' {
		draw_operations_doctor_preview(mut app, l)
	}
}

// operations_floor_counts returns the real running and attention job counts that
// dress the floor (running agents, board plate). Zero means calm.
fn operations_floor_counts(mut app GuiApp) (int, int) {
	if app.desktop == unsafe { nil } {
		return 0, 0
	}
	jobs := app.desktop.engine_jobs_catalog()
	return jobs.filter(it.status == .running).len, jobs.filter(it.status == .failed
		|| it.status == .queued).len
}

fn draw_operations_header(mut app GuiApp, l OperationsLayout) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	big := l.head_h >= 70
	gear := pixelart.environment_for(.gear_mark)
	gs := if big { 3 } else { 2 }
	gx := l.fx + 16
	gy := l.head_y + (l.head_h - gear.height() * gs) / 2
	// two meshed gears — the reference's operations glyph
	sc.draw(gear, pid, gx, gy, gs)
	if big {
		sc.draw(gear, pid, gx + gear.width() * gs - 10, gy + gear.height() * gs - 26, 2)
	}
	tx := gx + gear.width() * gs + (if big { 26 } else { 14 })
	app.gg.draw_text(tx, l.head_y + (if big { 8 } else { 4 }), 'Operations', gg.TextCfg{
		color: app.pnl_text
		size: if big { 27 } else { 22 }
		family: app.fonts.display
	})
	if l.fw > 520 {
		app.gg.draw_text(tx, l.head_y + (if big { 44 } else { 32 }), 'Observe, control, and keep your agents at work.', gg.TextCfg{
			color: app.pnl_text_mut
			size: if big { 13 } else { 11 }
		})
	}
	// real local date and time + a small house/tree vignette on the right
	if l.fw > 700 {
		now := ui_now()
		stamp := '${now.weekday_str()}, ${now.smonth()} ${now.day}, ${now.year}'
		clock := '${now.hour:02d}:${now.minute:02d}'
		vig_w := if big { 92 } else { 0 }
		right := l.fx + l.fw - 16 - vig_w
		app.gg.draw_text(right - stamp.len * 7, l.head_y + (if big { 10 } else { 6 }), stamp, gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		app.gg.draw_text(right - clock.len * 13, l.head_y + (if big { 28 } else { 22 }), clock, gg.TextCfg{
			color: app.pnl_text
			size: if big { 26 } else { 20 }
			family: app.fonts.display
		})
		if big {
			// vignette: sage lawn, plant "tree", the hornero nest as the house
			vx := l.fx + l.fw - 12 - vig_w
			vy := l.head_y + 6
			vh := l.head_h - 12
			app.gg.draw_rect_filled(vx, vy, vig_w, vh, tint(pc(app, `s`), 60))
			app.gg.draw_rect_filled(vx, vy + vh - 14, vig_w, 14, pc(app, `f`))
			app.gg.draw_rect_filled(vx, vy + vh - 6, vig_w, 6, pc(app, `F`))
			plant := pixelart.environment_for(.plant)
			nest := pixelart.environment_for(.nest)
			sc.draw(plant, pid, vx + 6, vy + vh - 14 - plant.height() * 2 + 8, 2)
			sc.draw(nest, pid, vx + vig_w - nest.width() * 2 - 8, vy + vh - 12 - nest.height() * 2 + 4, 2)
			app.gg.draw_rect_empty(vx, vy, vig_w, vh, tint(pc(app, `W`), 90))
		}
	}
}

fn draw_operations_cards(mut app GuiApp, l OperationsLayout) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	metrics := operations_metrics(mut app)
	for i, m in metrics {
		cx, cy, cw, ch := operations_card_rect(l, i)
		draw_paper_sheet(mut app, cx, cy, cw, ch)
		accent := if m.alert { pc(app, `a`) } else { app.pnl_success }
		app.gg.draw_rect_filled(cx, cy, 3, ch, tint(accent, 170))
		mark := pixelart.environment_for(m.mark)
		ms := if ch >= 64 { 3 } else { 2 }
		sc.draw(mark, pid, cx + 14, cy + (ch - mark.height() * ms) / 2, ms)
		tx := cx + 14 + mark.width() * ms + 12
		num := '${m.value}'
		// number / label / sub-fact stacked (operations.jpg) — the label is
		// never truncated: it owns its own line instead of fighting the number
		app.gg.draw_text(tx, cy + 4, num, gg.TextCfg{
			color: if m.alert { pc(app, `a`) } else { app.pnl_text }
			size: 22
			family: app.fonts.display
		})
		app.gg.draw_text(tx, cy + 30, m.label, gg.TextCfg{
			color: app.pnl_text
			size: 13
			bold: true
		})
		if ch >= 66 {
			app.gg.draw_text(tx, cy + ch - 18, utf8_truncate(m.sub, text_fit_chars(cx + cw - tx - 8, 11)), gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
		}
	}
}

fn draw_operations_tabs(mut app GuiApp, l OperationsLayout) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	// tab rail baseline
	app.gg.draw_rect_filled(l.right_x, l.tab_y + l.tab_h - 1, l.right_w, 1, tint(pc(app, `W`), 90))
	for i, label in operations_tab_labels {
		tx, ty, tw, th := operations_tab_rect(l, i)
		active := i == l.tab
		hover := app.operations_hover == 1 + i
		if active {
			app.gg.draw_rect_filled(tx, ty, tw, th - 1, pc(app, `P`))
			app.gg.draw_rect_filled(tx, ty + th - 3, tw, 3, app.pnl_success)
		} else if hover {
			app.gg.draw_rect_filled(tx, ty, tw, th - 1, app.pnl_hover)
		}
		mark := pixelart.environment_for(operations_tab_marks[i])
		mx := tx + 10
		sc.draw(mark, pid, mx, ty + (th - 12) / 2 - 1, 1)
		app.gg.draw_text(mx + 18, ty + (th - 15) / 2, label, gg.TextCfg{
			color: if active { app.pnl_text } else { app.pnl_text_mut }
			size: 13
			bold: active
		})
	}
}

fn draw_operations_controls(mut app GuiApp, l OperationsLayout) {
	sx, sy, sw, sh := operations_search_rect(l)
	operations_field(mut app, sx, sy, sw, sh, app.jobs_filter, operations_search_hints[l.tab], app.operations_focus == 1, true)
	fx, fy, fw, fh := operations_filter_rect(l)
	hover := app.operations_hover == 11
	app.gg.draw_rect_filled(fx, fy, fw, fh, if hover { app.pnl_hover } else { app.pnl_card_sel })
	app.gg.draw_rect_empty(fx, fy, fw, fh, app.pnl_border)
	label := operations_filter_label(l.tab, app.operations_status_filter)
	app.gg.draw_text(fx + 8, fy + (fh - 14) / 2, utf8_truncate(label, (fw - 26) / 7), gg.TextCfg{
		color: app.pnl_text
		size: 12
	})
	// chevron from pixel runs
	cxv := fx + fw - 14
	cyv := fy + fh / 2 - 2
	app.gg.draw_rect_filled(cxv, cyv, 2, 2, app.pnl_text_mut)
	app.gg.draw_rect_filled(cxv + 2, cyv + 2, 2, 2, app.pnl_text_mut)
	app.gg.draw_rect_filled(cxv + 4, cyv, 2, 2, app.pnl_text_mut)
}

// draw_operations_launch_strip is the real swarm launch affordance: editable task,
// backend choice, and pair/team/full — all executing Engine.swarm_launch.
fn draw_operations_launch_strip(mut app GuiApp, l OperationsLayout) {
	tx, ty, tw, th := operations_task_rect(l)
	operations_field(mut app, tx, ty, tw, th, app.swarm_task, 'Task for the swarm…', app.operations_focus == 2, false)
	for i, bname in ['auto', 'herdr', 'tmux'] {
		bx, by, bw, bh := operations_backend_rect(l, i)
		if bx + bw > l.right_x + l.right_w {
			break
		}
		sel := app.swarm_backend == bname
		hover := app.operations_hover == 20 + i
		app.gg.draw_rect_filled(bx, by, bw, bh, if sel {
			pc(app, `P`)
		} else if hover {
			app.pnl_hover
		} else {
			app.pnl_card_sel
		})
		app.gg.draw_rect_empty(bx, by, bw, bh, if sel { app.pnl_success } else { app.pnl_border })
		app.gg.draw_text(bx + (bw - bname.len * 7) / 2, by + (bh - 14) / 2, bname, gg.TextCfg{
			color: app.pnl_text
			size: 12
			bold: sel
		})
	}
	for i, rname in ['pair', 'team', 'full'] {
		rx, ry, rw, rh := operations_recipe_rect(l, i)
		if rx + rw > l.right_x + l.right_w {
			break
		}
		operations_button(mut app, rx, ry, rw, rh, rname, app.operations_hover == 24 + i, true, false)
	}
}

// draw_operations_repair_strip carries Doctor's real repair actions: Fix All and the
// per-category chips (each fixes its category through the Engine).
fn draw_operations_repair_strip(mut app GuiApp, l OperationsLayout) {
	fx, fy, fw, fh := operations_fixall_rect(l)
	operations_button(mut app, fx, fy, fw, fh, 'Fix All', app.operations_hover == 30, true, false)
	app.doctor_chips = []
	if app.desktop == unsafe { nil } {
		return
	}
	checks := app.desktop.engine_doctor()
	cats := ['root', 'engine', 'profiles', 'swarm', 'mcp', 'pack', 'loops', 'matrix', 'audit',
		'provenance']
	mut cx := fx + fw + 10
	cy := l.strip_y + 7
	for cat in cats {
		cnt := checks.filter(it.category == cat).len
		if cnt == 0 {
			continue
		}
		label := '${cat} ${cnt}'
		tw := label.len * 7 + 12
		if cx + tw > l.right_x + l.right_w {
			break
		}
		bad := checks.filter(it.category == cat && it.status != 'pass' && it.status != 'ok').len
		hover := app.operations_hover == 40 + app.doctor_chips.len
		app.gg.draw_rect_filled(cx, cy, tw, 20, if hover { app.pnl_hover } else { app.pnl_card_sel })
		app.gg.draw_rect_empty(cx, cy, tw, 20, if bad > 0 { app.pnl_select } else { app.pnl_border })
		app.gg.draw_text(cx + 6, cy + 3, label, gg.TextCfg{
			color: if bad > 0 { app.pnl_text } else { app.pnl_text_mut }
			size: 11
		})
		app.doctor_chips << DoctorChip{cat, cx, cy, tw, 20}
		cx += tw + 6
	}
}

// operations_spawn_rect reserves the job command field inside the tab-0 strip.
fn operations_spawn_rect(l OperationsLayout) (int, int, int, int) {
	mut fw := l.right_w - 72 - 12
	if fw < 120 {
		fw = 120
	}
	return l.right_x, l.strip_y + 4, fw, l.strip_h - 8
}

// operations_spawn_button_rect places the Spawn button right of the field.
fn operations_spawn_btn_rect(l OperationsLayout) (int, int, int, int) {
	fx, fy, fw, fh := operations_spawn_rect(l)
	return fx + fw + 8, fy, 72, fh
}

// draw_operations_spawn_strip is the real job spawn affordance: editable
// command plus a Spawn button executing Desktop.engine_spawn_job.
fn draw_operations_spawn_strip(mut app GuiApp, l OperationsLayout) {
	fx, fy, fw, fh := operations_spawn_rect(l)
	operations_field(mut app, fx, fy, fw, fh, app.ops_job_spawn, 'Spawn job: command…', app.operations_focus == 3, false)
	bx, by, bw, bh := operations_spawn_btn_rect(l)
	if bx + bw > l.right_x + l.right_w {
		return // undrawn = inert (same overflow guard as other strips)
	}
	operations_button(mut app, bx, by, bw, bh, 'Spawn', app.operations_hover == 32, true, false)
}

// operations_click_spawn_strip routes tab-0 strip hits: field focus + Spawn.
fn operations_click_spawn_strip(mut app GuiApp, l OperationsLayout, mx int, my int) bool {
	fx, fy, fw, fh := operations_spawn_rect(l)
	if rect_contains(mx, my, fx, fy, fw, fh) {
		app.operations_focus = 3
		app.header_search_focus = false
		app.workspace_focus = false
		app.ghost_focused = false
		return true
	}
	bx, by, bw, bh := operations_spawn_btn_rect(l)
	if bx + bw > l.right_x + l.right_w {
		return false
	}
	if rect_contains(mx, my, bx, by, bw, bh) {
		operations_spawn_submit(mut app)
		return true
	}
	return false
}

fn draw_operations_table(mut app GuiApp, l OperationsLayout) {
	if l.table_h < l.hdr_h + l.row_h {
		return
	}
	draw_paper_sheet(mut app, l.right_x, l.table_y, l.right_w, l.table_h)
	cols := operations_columns(l.tab)
	all := operations_rows(mut app, l.tab)
	rows := operations_apply_filter(all, app.jobs_filter, operations_filter_key(l.tab, app.operations_status_filter))
	// column geometry: weights share the width left of the ⋯ column
	act_w := 28
	avail := l.right_w - 16 - act_w
	mut wsum := 0
	for wt in cols.weights {
		wsum += wt
	}
	mut col_x := []int{}
	mut col_w := []int{}
	mut cx := l.right_x + 8
	for wt in cols.weights {
		cw := avail * wt / wsum
		col_x << cx
		col_w << cw
		cx += cw
	}
	// header
	hy := l.table_y
	app.gg.draw_rect_filled(l.right_x + 1, hy + 1, l.right_w - 2, l.hdr_h, tint(pc(app, `m`), 70))
	for i, hd in cols.headers {
		app.gg.draw_text(col_x[i] + 4, hy + 5, utf8_truncate(hd, (col_w[i] - 6) / 7), gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
			bold: true
		})
	}
	app.gg.draw_rect_filled(l.right_x + 1, hy + l.hdr_h, l.right_w - 2, 1, tint(pc(app, `W`), 70))
	if rows.len == 0 {
		draw_operations_empty(mut app, l, all.len)
		return
	}
	visible := operations_visible_rows(l)
	if visible == 0 {
		return
	}
	start := clamp_scroll(operations_scroll_of(app, l.tab), rows.len, visible)
	operations_set_scroll(mut app, l.tab, start)
	sel := operations_selected(app, l.tab, all.len)
	for vi in 0 .. visible {
		ri := start + vi
		if ri >= rows.len {
			break
		}
		r := rows[ri]
		rx, ry, rw, rh := operations_row_rect(l, vi)
		is_sel := r.idx == sel
		is_hover := app.operations_hover == 100 + vi
		if is_sel {
			app.gg.draw_rect_filled(rx + 1, ry, rw - 2, rh, tint(app.pnl_success, 60))
			app.gg.draw_rect_filled(rx + 1, ry, 3, rh, app.pnl_success)
		} else if is_hover {
			app.gg.draw_rect_filled(rx + 1, ry, rw - 2, rh, app.pnl_hover)
		} else if vi % 2 == 1 {
			app.gg.draw_rect_filled(rx + 1, ry, rw - 2, rh, tint(pc(app, `m`), 22))
		}
		for ci, cell in r.cells {
			if ci >= col_x.len {
				break
			}
			if ci == cols.status_idx {
				operations_draw_pill(mut app, col_x[ci] + 2, ry + 4, r.status, col_w[ci] - 6)
				continue
			}
			fix_col := l.tab == 3 && ci == 4
			mono := (l.tab == 0 && ci == 1) || (l.tab == 1 && ci == 2)
			app.gg.draw_text(col_x[ci] + 4, ry + 6, utf8_truncate(cell, (col_w[ci] - 6) / (if mono {
				7
			} else {
				6
			})), gg.TextCfg{
				color: if ci == 0 {
					app.pnl_text
				} else if fix_col {
					app.pnl_select
				} else {
					app.pnl_text_mut
				}
				size: 12
				bold: ci == 0 || fix_col
				mono: mono
			})
		}
		// ⋯ (three pixel dots — the brand fonts carry no dependable glyph)
		// marks that the row opens in the detail column
		for d in 0 .. 3 {
			app.gg.draw_rect_filled(rx + rw - act_w + 8 + d * 5, ry + rh / 2 - 1, 2, 2, app.pnl_text_mut)
		}
	}
	if rows.len > visible {
		track_y := l.table_y + l.hdr_h + 2
		track_h := visible * l.row_h
		mut bh := track_h * visible / rows.len
		if bh < 12 {
			bh = 12
		}
		by := track_y + (track_h - bh) * start / (rows.len - visible)
		app.gg.draw_rect_filled(l.right_x + l.right_w - 5, track_y, 3, track_h, tint(app.pnl_text, 24))
		app.gg.draw_rect_filled(l.right_x + l.right_w - 5, by, 3, bh, app.pnl_border_hi)
		app.gg.draw_text(l.right_x + 8, l.table_y + l.table_h - 16, '${start + 1}–${start + visible} of ${rows.len}', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
	}
}

// draw_operations_empty is the truthful empty state: a paper sheet with a small
// scene and the real way to create work — never a placeholder row.
fn draw_operations_empty(mut app GuiApp, l OperationsLayout, total int) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	ex := l.right_x + 24
	ey := l.table_y + l.hdr_h + 16
	ew := l.right_w - 48
	eh := l.table_h - l.hdr_h - 32
	if eh < 70 || ew < 160 {
		return
	}
	app.gg.draw_rect_filled(ex, ey, ew, eh, tint(pc(app, `m`), 40))
	app.gg.draw_rect_empty(ex, ey, ew, eh, tint(pc(app, `W`), 60))
	filtered := total > 0
	mut head := ''
	mut copy := ''
	mut hint := ''
	if filtered {
		head = 'No rows match'
		copy = 'Clear the search or choose another status to see all ${total}.'
	} else {
		match l.tab {
			0 {
				head = 'No jobs yet'
				copy = 'Jobs appear here when a loop run or a swarm launch starts work.'
				hint = 'Launch via Swarms → pair · team · full, or Loops → Run'
			}
			1 {
				head = 'No loop templates'
				copy = 'The resolved catalog has no loops/<name>/loop.yaml.'
			}
			2 {
				head = 'No swarm sessions yet'
				copy = 'Set a task above and launch pair, team or full.'
			}
			else {
				head = 'No checks reported'
				copy = 'The Engine returned no doctor checks for this workspace.'
			}
		}
	}
	// scene: desk with a terminal, a plant, and the wall clock — a quiet
	// station waiting for work
	scene_h := if eh >= 170 { 84 } else { 56 }
	s := if scene_h >= 84 { 3 } else { 2 }
	desk := pixelart.environment_for(.desk)
	term := pixelart.environment_for(.terminal)
	plant := pixelart.environment_for(.plant)
	clock := pixelart.environment_for(.wall_clock)
	gw := desk.width() * s + plant.width() * s + 8
	gx := ex + (ew - gw) / 2
	base := ey + 10 + scene_h
	sc.draw(desk, pid, gx, base - desk.height() * s, s)
	sc.draw(term, pid, gx + (desk.width() - term.width()) * s / 2, base - desk.height() * s - term.height() * s + 4 * s, s)
	sc.draw(plant, pid, gx + desk.width() * s + 8, base - plant.height() * s, s)
	sc.draw(clock, pid, gx + desk.width() * s + 12, base - desk.height() * s - term.height() * s - 6, 2)
	ty := base + 12
	app.gg.draw_text(ex + (ew - head.len * 8) / 2, ty, head, gg.TextCfg{
		color: app.pnl_text
		size: 16
		family: app.fonts.display
	})
	if ty + 40 < ey + eh {
		cw := utf8_truncate(copy, text_fit_chars(ew - 24, 12))
		app.gg.draw_text(ex + (ew - cw.len * 6) / 2, ty + 22, cw, gg.TextCfg{
			color: app.pnl_text_mut
			size: 12
		})
	}
	if hint != '' && ty + 58 < ey + eh {
		hw := utf8_truncate(hint, text_fit_chars(ew - 24, 11))
		app.gg.draw_text(ex + (ew - hw.len * 6) / 2, ty + 40, hw, gg.TextCfg{
			color: app.pnl_success
			size: 11
			bold: true
		})
	}
}

// draw_operations_topology renders the swarm handoff graph under the table when a
// run exists; nodes/edges hit-rects are stored for the click handler exactly
// as before (#1101 behaviour preserved).
fn draw_operations_topology(mut app GuiApp, l OperationsLayout) {
	mut handoffs := []string{}
	if app.desktop != unsafe { nil } {
		list := app.desktop.swarm_list()
		sel := operations_selected(app, 2, list.len)
		pick := if sel >= 0 { sel } else { 0 }
		if list.len > 0 {
			handoffs = app.desktop.swarm_handoffs(list[pick].id)
		}
	}
	mut roles := []string{}
	mut role_idx := map[string]int{}
	mut edges := [][]int{}
	mut edge_art := []string{}
	for th in handoffs {
		arrow := th.index(' → ') or { -1 }
		if arrow < 0 {
			continue
		}
		lrole := th[..arrow].trim_space()
		rrole := th[arrow + 5..].trim_space().split(' ')[0]
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
	app.swarm_nodes = []
	app.swarm_edges = []
	if roles.len == 0 || l.topo_h == 0 {
		// no strip this frame; operations_layout re-reads swarm_nodes next frame
		if roles.len > 0 {
			// first frame with handoffs: reserve the strip by seeding one node
			app.swarm_nodes << SwarmNode{roles[0], 0, 0, 0}
		}
		return
	}
	draw_paper_sheet(mut app, l.right_x, l.topo_y, l.right_w, l.topo_h)
	app.gg.draw_text(l.right_x + 10, l.topo_y + 6, 'Handoff topology', gg.TextCfg{
		color: app.pnl_text
		size: 12
		bold: true
	})
	zx, zy, pxz, pyz, zw, zh := operations_zoom_rects(l)
	operations_button(mut app, zx, zy, zw, zh, '−', app.operations_hover == 50, false, false)
	operations_button(mut app, pxz, pyz, zw, zh, '+', app.operations_hover == 51, false, false)
	working := swarm_live_roles(handoffs, swarm_session_roles(app))
	node_w := 96 + app.swarm_zoom * 24
	node_h := 30
	lane_cap := (l.right_w - 16) / (node_w + 8)
	safe_cap := if lane_cap < 1 { 1 } else { lane_cap }
	mut centers_x := map[int]int{}
	mut centers_y := map[int]int{}
	for ri, role in roles {
		lane := ri / safe_cap
		if lane > 1 {
			break
		}
		nx := l.right_x + 8 + (ri % safe_cap) * (node_w + 8)
		ny := l.topo_y + 28 + lane * (node_h + 6)
		if ny + node_h > l.topo_y + l.topo_h - 4 {
			break
		}
		centers_x[ri] = nx + node_w / 2
		centers_y[ri] = ny + node_h / 2
		app.swarm_nodes << SwarmNode{role, nx, ny, node_w}
		running := role in working
		app.gg.draw_rect_filled(nx, ny, node_w, node_h, if running {
			tint(app.pnl_success, 50)
		} else {
			app.pnl_card_sel
		})
		app.gg.draw_rect_empty(nx, ny, node_w, node_h, if running {
			app.pnl_success
		} else {
			app.pnl_border
		})
		app.gg.draw_text(nx + 8, ny + 4, utf8_truncate(role, (node_w - 16) / 7), gg.TextCfg{
			color: app.pnl_text
			size: 11
			bold: true
		})
		app.gg.draw_text(nx + 8, ny + 17, if running { 'working' } else { 'idle' }, gg.TextCfg{
			color: app.pnl_text_mut
			size: 9
			mono: true
		})
	}
	for ei, e in edges {
		if e[0] !in centers_x || e[1] !in centers_x {
			continue
		}
		x1, y1, x2, y2 := centers_x[e[0]], centers_y[e[0]], centers_x[e[1]], centers_y[e[1]]
		app.swarm_edges << SwarmEdge{x1, x2, (y1 + y2) / 2, edge_art[ei]}
		app.gg.draw_line(x1, y1, x2, y2, tint(app.pnl_text_mut, 110))
	}
}

// draw_operations_doctor_preview is the dry-run confirm card (#1108) — same
// geometry helper as before so the keyboard path (Enter confirms) matches.
fn draw_operations_doctor_preview(mut app GuiApp, l OperationsLayout) {
	px, py, pw, ph := doctor_preview_geom(l.fx, l.fy, l.fw)
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
	for ln, line in app.doctor_preview_lines {
		if ln >= 5 {
			break
		}
		app.gg.draw_text(px + 18, py + 46 + ln * 16, utf8_truncate(line, (pw - 36) / 7), gg.TextCfg{
			color: app.pnl_text
			size: 11
			mono: true
		})
	}
	operations_button(mut app, px + 14, py + ph - 32, 120, 22, 'Confirm fix', false, true, false)
	operations_button(mut app, px + 144, py + ph - 32, 90, 22, 'Cancel', false, false, false)
}

// ── the Operations Floor ────────────────────────────────────────────────────

// draw_operations_floor composes the command-center room inside a wood frame:
// title plate on the wall, checklist board, wall clock, windows, a server
// rack, workstations with monitors and idle catalog agents, a rug, plants,
// lamp and a framed sign. `running` real Engine jobs flip that many agents to
// the running variant; `attention` dresses the board plate. Static, no motion.
fn draw_operations_floor(mut app GuiApp, x int, y int, w int, h int, running int, attention int) {
	ensure_pixel_cache(mut app)
	pid := office_palette_id(app)
	mut sc := app.pixel_cache
	s := if w < 340 { 2 } else { 3 }
	ink := app.appearance_dark
	// wood frame
	app.gg.draw_rect_filled(x + 3, y + 4, w, h, tint(col_ink, 40))
	app.gg.draw_rect_filled(x, y, w, h, pc(app, `W`))
	app.gg.draw_rect_empty(x, y, w, h, pc(app, `k`))
	ix := x + 6
	iy := y + 6
	iw := w - 12
	ih := h - 12
	// wall band + plank floor (same material grammar as the Office room)
	wall_h := 22 * s + 14
	wall_col := mix(pc(app, `p`), pc(app, `m`), 0.30)
	floor_col := if ink {
		mix(pc(app, `S`), pc(app, `w`), 0.22)
	} else {
		mix(pc(app, `w`), pc(app, `p`), 0.62)
	}
	seam_col := if ink {
		mix(floor_col, pc(app, `k`), 0.40)
	} else {
		mix(pc(app, `W`), floor_col, 0.50)
	}
	floor_hi := if ink {
		mix(floor_col, pc(app, `w`), 0.10)
	} else {
		mix(floor_col, pc(app, `p`), 0.22)
	}
	app.gg.draw_rect_filled(ix, iy, iw, ih, floor_col)
	app.gg.draw_rect_filled(ix, iy, iw, wall_h, wall_col)
	app.gg.draw_rect_filled(ix, iy + wall_h - 4, iw, 4, pc(app, `W`))
	ph := 6 * s
	mut py := iy + wall_h + ph
	mut row_i := 0
	for py < iy + ih {
		if row_i % 2 == 1 {
			app.gg.draw_rect_filled(ix, py - ph, iw, ph, floor_hi)
		}
		app.gg.draw_rect_filled(ix, py, iw, 1, seam_col)
		mut jx := ix + if row_i % 2 == 0 { 0 } else { 13 * s }
		for jx < ix + iw {
			app.gg.draw_rect_filled(jx, py - ph + 1, 1, ph - 1, seam_col)
			jx += 26 * s
		}
		py += ph
		row_i++
	}
	app.gg.draw_rect_filled(ix, iy + ih - 4, iw, 4, pc(app, `W`))
	base := iy + wall_h - 4

	// title plate — the room names itself, like the reference
	app.gg.draw_text(ix + 12, iy + 8, 'Operations Floor', gg.TextCfg{
		color: pc(app, `k`)
		size: 16
		family: app.fonts.display
	})
	app.gg.draw_text(ix + 12, iy + 28, 'Agents at work, everywhere.', gg.TextCfg{
		color: mix(pc(app, `k`), pc(app, `W`), 0.45)
		size: 10
	})
	// wall: plant · checklist board · clock · window(s) · picture
	board := pixelart.environment_for(.checklist_board)
	clock := pixelart.environment_for(.wall_clock)
	window := pixelart.environment_for(.window)
	picture := pixelart.environment_for(.picture)
	plant := pixelart.environment_for(.plant)
	title_w := 'Operations Floor'.len * 9 + 16
	mut wx := ix + title_w
	if wx + board.width() * s < ix + iw - 40 {
		sc.draw(board, pid, wx, base - board.height() * s, s)
		att := if attention == 0 { 'board · clear' } else { 'board · ${attention} open' }
		zone_plate(mut app, wx, base + 10, att, if attention == 0 {
			app.pnl_text_mut
		} else {
			app.pnl_select
		})
		wx += board.width() * s + 6 * s
	}
	if wx + clock.width() * 2 < ix + iw - 20 {
		sc.draw(clock, pid, wx, iy + 10, 2)
		wx += clock.width() * 2 + 4 * s
	}
	if wx + window.width() * s < ix + iw - 30 {
		sc.draw(window, pid, wx, base - window.height() * s, s)
		wx += window.width() * s + 4 * s
	}
	if wx + picture.width() * 2 < ix + iw - 16 {
		sc.draw(picture, pid, wx, base - picture.height() * 2 - 8, 2)
	}

	// floor props: server rack + monitor tower (right wall), lamp (left),
	// rug (center), sign plate (bottom right), plants
	rack := pixelart.environment_for(.server_rack)
	tower := pixelart.environment_for(.monitor_tower)
	lamp := pixelart.environment_for(.lamp)
	rug := pixelart.environment_for(.rug)
	desk := pixelart.environment_for(.desk)
	term := pixelart.environment_for(.terminal)
	chair := pixelart.environment_for(.chair)
	floor_y := iy + wall_h
	rack_x := ix + iw - 10 - rack.width() * s
	rack_y := floor_y + 6
	sc.draw(rack, pid, rack_x, rack_y, s)
	if rack_y + rack.height() * s + tower.height() * s + 40 < iy + ih {
		sc.draw(tower, pid, rack_x, rack_y + rack.height() * s + 24, s)
	}
	sc.draw(lamp, pid, ix + 10, floor_y + 6, s)
	sc.draw(plant, pid, ix + 10, iy + ih - 10 - plant.height() * s, s)
	// framed sign plate on the wall band's right end (a wall object, so it
	// never shares y with the desk rows or the footer note)
	sign_l1 := 'STEADY HANDS'
	sign_l2 := 'CLEAR LOGS'
	sw_ := sign_l1.len * 7 + 20
	sh_ := 30
	sgx := ix + iw - 10 - sw_
	sgy := iy + 6
	if sgx > wx + 8 {
		app.gg.draw_rect_filled(sgx + 2, sgy + 2, sw_, sh_, pc(app, `W`))
		app.gg.draw_rect_filled(sgx, sgy, sw_, sh_, pc(app, `p`))
		app.gg.draw_rect_empty(sgx, sgy, sw_, sh_, pc(app, `W`))
		app.gg.draw_text(sgx + 10, sgy + 4, sign_l1, gg.TextCfg{
			color: pc(app, `k`)
			size: 10
			bold: true
		})
		app.gg.draw_text(sgx + 10, sgy + 16, sign_l2, gg.TextCfg{
			color: pc(app, `k`)
			size: 10
			bold: true
		})
	}

	// workstations: rows of desk pods between the lamp and the rack
	desks := desks_for_app(app)
	workspace_x := ix + 14 + lamp.width() * s + 8
	workspace_w := rack_x - 12 - workspace_x
	dw := desk.width() * s
	aw := pixelart.agent_for_state(.idle).width() * s
	ah := pixelart.agent_for_state(.idle).height() * s
	cell_h := ah - 4 + desk.height() * s + chair.height() * s + 8
	// the wall plates ('board · clear') hang 18px into the floor: reserve it
	grid_top := floor_y + 8 + 18
	avail_h := (iy + ih - 26) - grid_top
	if workspace_w < dw + 8 || avail_h < cell_h || desks.len == 0 {
		return
	}
	per_row := (workspace_w + 6 * s) / (dw + 6 * s)
	rows := avail_h / cell_h
	capacity := per_row * rows
	shown_n := if desks.len < capacity { desks.len } else { capacity }
	used_rows := (shown_n + per_row - 1) / per_row
	step := if used_rows > 0 && avail_h / used_rows < cell_h * 2 {
		avail_h / used_rows
	} else {
		cell_h
	}
	total_w := per_row * dw + (per_row - 1) * 6 * s
	grid_x := workspace_x + (workspace_w - total_w) / 2
	// rug under the first row anchors the cluster
	rug_s := if rug.width() * s <= workspace_w { s } else { 2 }
	sc.draw(rug, pid, workspace_x + (workspace_w - rug.width() * rug_s) / 2, grid_top + (used_rows - 1) * step + ah - 8, rug_s)
	mut shown := 0
	for i in 0 .. shown_n {
		r := i / per_row
		c := i % per_row
		cx := grid_x + c * (dw + 6 * s)
		cy := grid_top + r * step
		if cy + cell_h > iy + ih - 26 {
			break
		}
		// running agents come from the real running-job count, nothing else
		state := if i < running {
			pixelart.AgentVisualState.running
		} else {
			pixelart.AgentVisualState.idle
		}
		agent := pixelart.with_identity(pixelart.agent_for_state(state), i % 3)
		sc.draw(agent, pid, cx + (dw - aw) / 2, cy, s)
		desk_y := cy + ah - 4
		sc.draw(desk, pid, cx, desk_y, s)
		sc.draw(term, pid, cx + (dw - term.width() * s) / 2, desk_y + 2, s)
		if i % 2 == 0 {
			app.gg.draw_rect_filled(cx + 4, desk_y + 3, 2 * s, 3 * s, pc(app, `P`))
		} else {
			app.gg.draw_rect_filled(cx + 4, desk_y + 3, 3 * s, 2 * s, pc(app, `m`))
		}
		sc.draw(chair, pid, cx + (dw - chair.width() * s) / 2, desk_y + desk.height() * s + 2, s)
		shown++
	}
	note := if running > 0 {
		'${running} running · ${shown} of ${desks.len} desks'
	} else {
		'${shown} of ${desks.len} catalog desks · idle'
	}
	app.gg.draw_text(ix + 12 + plant.width() * s + 4, iy + ih - 18, note, gg.TextCfg{
		color: if running > 0 { app.pnl_success } else { app.pnl_text_mut }
		size: 10
	})
}

// ── detail column (replaces the Office inspector on Operations panels) ──────

// OperationsAction is a real Engine action drawn in the detail column.
struct OperationsAction {
	label   string
	kind    string // cancel | retry | logs | run | schedule | fix | copy
	primary bool
	danger  bool
}

// operations_actions lists only the actions that exist for the selected record.
fn operations_actions(mut app GuiApp, tab int, sel int) []OperationsAction {
	mut out := []OperationsAction{}
	if app.desktop == unsafe { nil } || sel < 0 {
		return out
	}
	match tab {
		0 {
			jobs := app.desktop.engine_jobs_catalog()
			if sel >= jobs.len {
				return out
			}
			j := jobs[sel]
			if j.status == .queued || j.status == .running {
				out << OperationsAction{'Cancel', 'cancel', false, true}
			}
			if j.status == .failed || j.status == .canceled || j.status == .done {
				out << OperationsAction{'Retry', 'retry', true, false}
			}
			logs := app.desktop.engine_job_logs(j.id)
			if logs.len > 0 || j.logs.len > 0 {
				out << OperationsAction{if app.jobs_show_logs && app.jobs_logs_job == j.id {
					'Hide logs'
				} else {
					'Open logs'
				}, 'logs', false, false}
			}
		}
		1 {
			// Slice B (#1229): creation owns its own buttons inside the
			// create block (it must work with an empty catalog, where no
			// action row renders), so the action row stays empty while open.
			if app.loops_show_create {
				return out
			}
			loops := app.desktop.loops_catalog()
			if sel >= loops.len {
				return out
			}
			out << OperationsAction{'Run', 'run', true, false}
			out << OperationsAction{if loops[sel].cron_enabled { 'Unschedule' } else { 'Schedule' }, 'schedule', false, false}
			out << OperationsAction{'New…', 'new', false, false}
			out << OperationsAction{'Delete', 'delete', false, true}
		}
		2 {
			list := app.desktop.swarm_list()
			if sel >= list.len {
				return out
			}
			s := list[sel]
			// Slice B (#1229): run control wired to real Engine operations.
			// Pause/steer/halt are omitted — the Engine proves no such
			// operation (backend dependency, not a UI gap).
			if app.ops_guide_run == s.id {
				out << OperationsAction{'Queue guidance', 'queue', true, false}
				out << OperationsAction{'Close guide', 'guide', false, false}
				return out
			}
			if ops_swarm_is_active(s.status) {
				out << OperationsAction{'Stop', 'stop', false, true}
			}
			tgt := ops_promote_target(s.recipe.str())
			if tgt != '' && (s.status == .running || s.status == .awaiting_approval) {
				out << OperationsAction{'Promote → ${tgt}', 'promote', true, false}
			}
			if ops_swarm_is_terminal(s.status) && app.desktop.swarm_pruned_at(s.id) == '' {
				out << OperationsAction{'Prune', 'prune', false, false}
			}
			out << OperationsAction{'Guide…', 'guide', false, false}
			out << OperationsAction{'Copy id', 'copy', false, false}
		}
		else {
			checks := app.desktop.engine_doctor()
			if sel >= checks.len {
				return out
			}
			c := checks[sel]
			if c.fixable && c.status != 'pass' && c.status != 'ok' {
				out << OperationsAction{'Preview fix', 'fix', true, false}
			}
			out << OperationsAction{'Copy message', 'copy', false, false}
		}
	}
	return out
}

// ops_swarm_is_active reports whether a swarm run still accepts run control.
fn ops_swarm_is_active(status desktop_engine.SwarmRunStatus) bool {
	return status == .running || status == .awaiting_approval
}

// ops_swarm_is_terminal reports whether a swarm run reached a final state.
fn ops_swarm_is_terminal(status desktop_engine.SwarmRunStatus) bool {
	return status == .completed || status == .failed || status == .canceled
}

// ops_promote_target names the next recipe a run can promote to (pair→team→
// full), or '' when the recipe is already maximal or unknown.
fn ops_promote_target(recipe string) string {
	if recipe == 'pair' {
		return 'team'
	}
	if recipe == 'team' {
		return 'full'
	}
	return ''
}

// loop_entry_canonical renders a loop entry as the canonical text the Engine
// validator parses. Values come from the recorded entry — never invented.
fn loop_entry_canonical(e desktop_engine.LoopEntry) string {
	return 'name: ${e.name}\ntier: ${e.tier}\ncadence: ${e.cadence}\ngoal: ${e.goal}\nbudget_max_tokens: ${e.budget_total}\n'
}

// ── guidance composer ───────────────────────────────────────────────────────
// Queued guidance is filed as a run handoff artifact on deliver — the run can
// read it from its artifacts. It is never injected into a live process.

// OpsGuideRow is one visible composer row: queued (cancelable), failed
// (requeueable), or terminal history.
struct OpsGuideRow {
	id          string
	label       string
	state       string
	can_cancel  bool
	can_requeue bool
}

// ops_guide_visible_rows lists composer rows for a run: queued first, then
// terminal history newest-last.
fn ops_guide_visible_rows(mut app GuiApp, run_id string) []OpsGuideRow {
	comp := app.ops_composers[run_id] or { return []OpsGuideRow{} }
	mut rows := []OpsGuideRow{}
	for it in comp.queued_items() {
		rows << OpsGuideRow{it.id, it.text, 'queued', true, false}
	}
	for it in comp.history() {
		if it.status == .delivered {
			rows << OpsGuideRow{it.id, it.text, 'delivered', false, false}
		} else if it.status == .failed {
			rows << OpsGuideRow{it.id, it.text, 'failed', false, true}
		} else if it.status == .canceled {
			rows << OpsGuideRow{it.id, it.text, 'canceled', false, false}
		}
	}
	return rows
}

// ops_guide_action_w is the fixed width of the row action button.
fn ops_guide_action_w() int {
	return 64
}

// ops_guide_origin is the facts-zone origin shared by draw, hover and click.
fn ops_guide_origin(l OperationsLayout) (int, int, int) {
	return l.side_x + 12, l.side_y + 64, l.side_w - 24
}

fn operations_guide_row_rect(l OperationsLayout, i int) (int, int, int, int) {
	gx, gy, gw := ops_guide_origin(l)
	return gx, gy + 46 + i * 22, gw, 20
}

// ops_guide_draft reads the preserved per-run draft ('' when none).
fn ops_guide_draft(mut app GuiApp, run_id string) string {
	comp := app.ops_composers[run_id] or { return '' }
	return comp.draft_text()
}

// ops_guide_set_draft stores the per-run draft (get-modify-write: map values
// are copies).
fn ops_guide_set_draft(mut app GuiApp, run_id string, text string) {
	mut comp := app.ops_composers[run_id] or { swarm_rt.new_queue_composer(run_id) }
	comp.set_draft(text)
	app.ops_composers[run_id] = comp
}

// ops_guide_type appends typed input to the run draft.
fn ops_guide_type(mut app GuiApp, ch string) {
	if app.ops_guide_run == '' {
		return
	}
	ops_guide_set_draft(mut app, app.ops_guide_run, ops_guide_draft(mut app, app.ops_guide_run) + ch)
}

// ops_guide_backspace deletes one rune from the run draft.
fn ops_guide_backspace(mut app GuiApp) {
	if app.ops_guide_run == '' {
		return
	}
	d := ops_guide_draft(mut app, app.ops_guide_run)
	if d.len > 0 {
		ops_guide_set_draft(mut app, app.ops_guide_run, d[..d.len - 1])
	}
}

// draw_operations_guide renders the draft field plus queued/history rows for
// a run inside the detail facts zone.
fn draw_operations_guide(mut app GuiApp, l OperationsLayout, run_id string) {
	gx, gy, gw := ops_guide_origin(l)
	app.gg.draw_text(gx, gy, 'Guidance — ${run_id}', gg.TextCfg{
		color: app.pnl_text
		size: 12
		bold: true
	})
	draft := ops_guide_draft(mut app, run_id)
	operations_field(mut app, gx, gy + 16, gw, 24, draft, 'Type guidance, Enter queues…', app.operations_focus == 5, false)
	rows := ops_guide_visible_rows(mut app, run_id)
	for i, r in rows {
		if i >= 6 {
			break
		}
		rx, ry, rw, rh := operations_guide_row_rect(l, i)
		app.gg.draw_text(rx, ry + 3, utf8_truncate(r.label, (rw - 70) / 6), gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
		app.gg.draw_text(rx + rw - 130, ry + 3, r.state, gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
		if r.can_cancel {
			operations_button(mut app, rx + rw - ops_guide_action_w(), ry, ops_guide_action_w(), rh, 'Cancel', app.operations_hover == 80 + i, false, false)
		} else if r.can_requeue {
			operations_button(mut app, rx + rw - ops_guide_action_w(), ry, ops_guide_action_w(), rh, 'Requeue', app.operations_hover == 80 + i, false, false)
		}
	}
	app.gg.draw_text(gx, gy + 46 + 6 * 22 + 4, 'Queued guidance is filed as a run artifact on deliver — never injected into a live process.', gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
	})
}

// operations_click_guide routes guide-block hits: field focus plus row
// actions (cancel queued, requeue failed).
fn operations_click_guide(mut app GuiApp, l OperationsLayout, mx int, my int, run_id string) bool {
	gx, gy, gw := ops_guide_origin(l)
	if rect_contains(mx, my, gx, gy + 16, gw, 24) {
		app.operations_focus = 5
		app.header_search_focus = false
		app.workspace_focus = false
		app.ghost_focused = false
		return true
	}
	rows := ops_guide_visible_rows(mut app, run_id)
	for i, r in rows {
		if i >= 6 {
			break
		}
		rx, ry, rw, rh := operations_guide_row_rect(l, i)
		aw := ops_guide_action_w()
		if rect_contains(mx, my, rx + rw - aw, ry, aw, rh) {
			mut comp := app.ops_composers[run_id] or { return true }
			if r.can_cancel {
				comp.cancel_before_delivery(r.id) or {
					app.inspector_msg = 'Cancel failed: ${err.msg()}'
					return true
				}
				app.inspector_msg = 'Guidance ${r.id} canceled before delivery'
			} else if r.can_requeue {
				comp.requeue(r.id) or {
					app.inspector_msg = 'Requeue failed: ${err.msg()}'
					return true
				}
				app.inspector_msg = 'Guidance ${r.id} requeued'
			} else {
				return true
			}
			app.ops_composers[run_id] = comp
			return true
		}
	}
	return false
}

// operations_guide_submit queues the draft (when non-empty) and delivers all
// queued items as run handoff artifacts. Failures keep the text: the item is
// marked failed and the draft is restored, never lost.
fn operations_guide_submit(mut app GuiApp, run_id string) {
	if app.desktop == unsafe { nil } {
		return
	}
	mut comp := app.ops_composers[run_id] or { swarm_rt.new_queue_composer(run_id) }
	if ops_guide_draft(mut app, run_id).trim_space() != '' {
		comp.enqueue() or {
			app.inspector_msg = 'Queue failed: ${err.msg()}'
			app.ops_composers[run_id] = comp
			return
		}
	}
	mut delivered := 0
	for it in comp.queued_items() {
		comp.begin_deliver(it.id) or {
			app.inspector_msg = 'Deliver failed: ${err.msg()}'
			continue
		}
		artifact := app.desktop.engine_write_handoff_artifact(run_id, 'guidance/${it.id}.md', it.text) or {
			comp.mark_failed(it.id, err.msg()) or {}
			comp.set_draft(it.text)
			app.inspector_msg = 'Deliver failed (${it.id}): artifact write failed — text restored to draft'
			continue
		}
		comp.mark_delivered(it.id, artifact) or {}
		delivered++
	}
	app.ops_composers[run_id] = comp
	app.engine_rev = app.desktop.app_state_snapshot().revision
	app.api_calls = app.desktop.engine_api_calls()
	if delivered > 0 {
		app.inspector_msg = 'Guidance filed: ${delivered} artifact(s) on run ${run_id}'
	} else {
		app.inspector_msg = 'Nothing queued — type guidance first'
		app.operations_focus = 5
	}
}

// ── loop create block ───────────────────────────────────────────────────────

// operations_create_tier_rect is the tier selector row (click cycles L1→L2→L3).
fn operations_create_tier_rect(l OperationsLayout) (int, int, int, int) {
	return l.side_x + 12, l.side_y + 64 + 30, l.side_w - 24, 22
}

// operations_create_btn_rect places the Create (0) / Cancel (1) buttons.
fn operations_create_btn_rect(l OperationsLayout, i int) (int, int, int, int) {
	bw := (l.side_w - 24 - 8) / 2
	return l.side_x + 12 + i * (bw + 8), l.side_y + 64 + 58, bw, 24
}

// draw_operations_create renders the new-loop block: name field, tier chips,
// cadence note, Create/Cancel. Works with an empty catalog.
fn draw_operations_create(mut app GuiApp, l OperationsLayout) {
	cx := l.side_x + 12
	cw := l.side_w - 24
	cy := l.side_y + 64
	app.gg.draw_text(cx, cy, 'New loop', gg.TextCfg{
		color: app.pnl_text
		size: 12
		bold: true
	})
	operations_field(mut app, cx, cy + 16, cw, 24, app.loops_create_name, 'Loop name (kebab-case)…', app.operations_focus == 4, false)
	tx, ty, tw, th := operations_create_tier_rect(l)
	tiers := ['L1', 'L2', 'L3']
	for i, t in tiers {
		sel := app.loops_create_tier == i
		bw := tw / 3
		bx := tx + i * bw
		operations_button(mut app, bx, ty, bw - 4, th, t, app.operations_hover == 81, sel, false)
	}
	app.gg.draw_text(cx, cy + 30 + 26, 'cadence ${app.loops_create_cadence} · cron flag stays off until scheduled', gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
	})
	b0x, b0y, b0w, b0h := operations_create_btn_rect(l, 0)
	operations_button(mut app, b0x, b0y, b0w, b0h, 'Create', app.operations_hover == 82, true, false)
	b1x, b1y, b1w, b1h := operations_create_btn_rect(l, 1)
	operations_button(mut app, b1x, b1y, b1w, b1h, 'Cancel', app.operations_hover == 83, false, false)
}

// operations_click_create routes create-block hits: tier cycle + Create/Cancel.
fn operations_click_create(mut app GuiApp, l OperationsLayout, mx int, my int) bool {
	cx := l.side_x + 12
	cw := l.side_w - 24
	cy := l.side_y + 64
	if rect_contains(mx, my, cx, cy + 16, cw, 24) {
		app.operations_focus = 4
		app.header_search_focus = false
		app.workspace_focus = false
		app.ghost_focused = false
		return true
	}
	tx, ty, tw, th := operations_create_tier_rect(l)
	if rect_contains(mx, my, tx, ty, tw, th) {
		app.loops_create_tier = (app.loops_create_tier + 1) % 3
		return true
	}
	b0x, b0y, b0w, b0h := operations_create_btn_rect(l, 0)
	if rect_contains(mx, my, b0x, b0y, b0w, b0h) {
		operations_loop_create_submit(mut app)
		return true
	}
	b1x, b1y, b1w, b1h := operations_create_btn_rect(l, 1)
	if rect_contains(mx, my, b1x, b1y, b1w, b1h) {
		app.loops_show_create = false
		app.loops_create_name = ''
		app.operations_focus = 0
		return true
	}
	return false
}

// operations_spawn_submit spawns the typed job command (Enter key path).
fn operations_spawn_submit(mut app GuiApp) {
	if app.desktop == unsafe { nil } {
		return
	}
	cmd := app.ops_job_spawn.trim_space()
	if cmd == '' {
		app.inspector_msg = 'Job spawn needs a command — type one in the field'
		app.operations_focus = 3
		return
	}
	job_id := app.desktop.engine_spawn_job(cmd, []) or {
		app.inspector_msg = 'Job spawn failed: ${err.msg()}'
		return
	}
	app.engine_rev = app.desktop.app_state_snapshot().revision
	app.api_calls = app.desktop.engine_api_calls()
	app.ops_job_spawn = ''
	app.inspector_msg = 'Job requested: ${job_id}'
}

// operations_loop_create_submit creates the typed loop via the Engine.
fn operations_loop_create_submit(mut app GuiApp) {
	if app.desktop == unsafe { nil } {
		return
	}
	name := app.loops_create_name.trim_space()
	if name == '' {
		app.inspector_msg = 'Loop create needs a name — kebab-case, e.g. nightly-audit'
		app.operations_focus = 4
		return
	}
	tiers := ['L1', 'L2', 'L3']
	tier := tiers[app.loops_create_tier]
	app.desktop.engine_create_loop(name, tier, app.loops_create_cadence, '') or {
		app.inspector_msg = 'Loop create failed: ${err.msg()}'
		return
	}
	app.engine_rev = app.desktop.app_state_snapshot().revision
	app.api_calls = app.desktop.engine_api_calls()
	app.loops_show_create = false
	app.loops_create_name = ''
	app.operations_focus = 0
	app.inspector_msg = 'Loop created: ${name} (${tier})'
}

fn draw_operations_detail(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	l := operations_layout(app, w, h)
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	x, y, iw, ih := l.side_x, l.side_y, l.side_w, l.side_h
	app.gg.draw_rect_filled(x, y, iw, ih, app.pnl_bg)
	app.gg.draw_line(x, y, x, y + ih, app.pnl_border)
	app.gg.draw_text(x + 16, y + 12, operations_detail_titles[l.tab], gg.TextCfg{
		color: app.pnl_text
		size: 17
		family: app.fonts.display
	})
	all := operations_rows(mut app, l.tab)
	sel := operations_selected(app, l.tab, all.len)
	if sel < 0 {
		draw_operations_detail_empty(mut app, l, all.len)
		return
	}
	row := all[sel]
	// status pill top-right, mark + name below the title
	label, _ := operations_pill(app, row.status)
	pw := label.len * 7 + 22
	operations_draw_pill(mut app, x + iw - pw - 14, y + 12, row.status, pw)
	mark := pixelart.environment_for(operations_tab_marks[l.tab])
	sc.draw(mark, pid, x + 16, y + 44, 3)
	name_x := x + 16 + mark.width() * 3 + 12
	app.gg.draw_text(name_x, y + 44, utf8_truncate(row.cells[0], text_fit_chars(x + iw - name_x - 12, 15)), gg.TextCfg{
		color: app.pnl_text
		size: 15
		bold: true
	})
	facts, desc := operations_detail_facts(mut app, l.tab, sel)
	acts := operations_actions(mut app, l.tab, sel)
	appr_top := operations_detail_content_bottom(l)
	// Slice B (#1229): the guidance composer (Swarms) and the loop create
	// block (Loops) take the facts zone with fixed geometry so draw, hover
	// and click always agree. Facts return when the block closes.
	mut cy := y + 64
	if l.tab == 2 && app.ops_guide_run == row.id {
		draw_operations_guide(mut app, l, row.id)
	} else if l.tab == 1 && app.loops_show_create {
		draw_operations_create(mut app, l)
	} else {
		if desc != '' {
			draw_wrapped_text(mut app, name_x, cy, x + iw - name_x - 12, desc, 2)
			cy += 30
		}
		cy += 12
		app.gg.draw_rect_filled(x + 12, cy, iw - 24, 1, tint(pc(app, `W`), 70))
		cy += 10
		// fact rows: label column + value column; stop before the action zone
		for f in facts {
			if cy + 18 > appr_top {
				break
			}
		app.gg.draw_text(x + 16, cy, f[0], gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		vx := x + 96
		if f[0] == 'Status' {
			operations_draw_pill(mut app, vx, cy - 3, row.status, x + iw - vx - 14)
		} else {
			app.gg.draw_text(vx, cy, utf8_truncate(f[1], text_fit_chars(x + iw - vx - 12, 12)), gg.TextCfg{
				color: app.pnl_text
				size: 12
				mono: f[0] in ['ID', 'Command', 'Work dir', 'Worktree', 'Schedule', 'Budget']
			})
		}
		cy += 20
		}
	}
	// job logs sheet (Open logs) — real lines from the Engine, newest last
	if l.tab == 0 && app.jobs_show_logs && app.jobs_logs_job == row.id && appr_top - cy > 60 {
		logs := app.desktop.engine_job_logs(row.id)
		lh := appr_top - cy - 6
		app.gg.draw_rect_filled(x + 12, cy, iw - 24, lh, term_bg)
		app.gg.draw_rect_empty(x + 12, cy, iw - 24, lh, col_line)
		max_rows := (lh - 8) / 13
		start := if logs.len > max_rows { logs.len - max_rows } else { 0 }
		for i in start .. logs.len {
			app.gg.draw_text(x + 18, cy + 4 + (i - start) * 13, utf8_truncate(logs[i], (iw - 40) / 7), gg.TextCfg{
				color: col_slate_dim
				size: 10
				mono: true
			})
		}
		if logs.len == 0 {
			app.gg.draw_text(x + 18, cy + 6, 'No log lines recorded.', gg.TextCfg{
				color: col_slate_dim
				size: 10
				mono: true
			})
		}
	}
	// pending approvals for the selected swarm — real gates, real resolve
	if l.tab == 2 {
		draw_operations_tasks(mut app, l, row.id)
		draw_operations_approvals(mut app, l, row.id)
	}
	for i, a in acts {
		ax, ay, aw, ah := operations_action_rect(l, i, acts.len)
		operations_button(mut app, ax, ay, aw, ah, a.label, app.operations_hover == 60 + i, a.primary, a.danger)
	}
	// related destinations — the real places that produce or consume this work
	rel := operations_related(l.tab)
	for i, r in rel {
		rx, ry, rw, rh := operations_related_rect(l, i)
		hover := app.operations_hover == 70 + i
		app.gg.draw_text(rx, ry + 3, utf8_truncate(r[0] + ' →', (rw - 4) / 7), gg.TextCfg{
			color: if hover { app.pnl_text } else { app.pnl_success }
			size: 12
			bold: true
		})
		_ = rh
	}
	if app.inspector_msg != '' {
		app.gg.draw_text(x + 12, y + ih - 16, utf8_truncate(app.inspector_msg, (iw - 24) / 6), gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
	}
}

// operations_detail_content_bottom is where fact rows must stop: above approvals
// (Swarms) or above the action row.
fn operations_detail_content_bottom(l OperationsLayout) int {
	_, act_y, _, _ := operations_action_rect(l, 0, 1)
	if l.tab == 2 {
		_, ty, _, _ := operations_board_rect(l, 4)
		return ty - 26
	}
	return act_y - 8
}

// operations_related lists the destinations linked from each detail kind:
// (label, panel id).
fn operations_related(tab int) [][]string {
	return match tab {
		0 { [['View loops', '7'], ['View swarms', '8']] }
		1 { [['View jobs', '6'], ['Open Office', '0']] }
		2 { [['View jobs', '6'], ['Open Office', '0']] }
		else { [['View jobs', '6'], ['Open Workspace', '9']] }
	}
}

// operations_detail_facts returns (label, value) rows plus a description for the
// selected record. Only measured or configured facts are emitted — a missing
// value is omitted, not filled.
fn operations_detail_facts(mut app GuiApp, tab int, sel int) ([][]string, string) {
	mut rows := [][]string{}
	if app.desktop == unsafe { nil } {
		return rows, ''
	}
	match tab {
		0 {
			jobs := app.desktop.engine_jobs_catalog()
			if sel >= jobs.len {
				return rows, ''
			}
			j := jobs[sel]
			rows << ['ID', j.id]
			rows << ['Status', job_status_key(j.status)]
			rows << ['Started', format_started_time(j.started_at)]
			if j.finished_at > 0 {
				rows << ['Finished', format_started_time(j.finished_at)]
			}
			rows << ['Duration', format_duration_ms(j.duration_ms)]
			if j.status == .done || j.status == .failed {
				rows << ['Exit code', '${j.exit_code}']
			}
			if j.retry_count > 0 {
				rows << ['Retries', '${j.retry_count}']
			}
			if j.work_dir != '' {
				rows << ['Work dir', j.work_dir]
			}
			logs := app.desktop.engine_job_logs(j.id)
			cnt := if logs.len > 0 { logs.len } else { j.logs.len }
			rows << ['Logs', if cnt == 0 { 'none recorded' } else { '${cnt} lines' }]
			cmd := (j.cmd + ' ' + j.args.join(' ')).trim_space()
			return rows, cmd
		}
		1 {
			loops := app.desktop.loops_catalog()
			if sel >= loops.len {
				return rows, ''
			}
			e := loops[sel]
			rows << ['Tier', loop_tier_label(e.tier)]
			rows << ['Cadence', e.cadence]
			// Slice B (#1229): the cron value is a configuration flag —
			// there is no scheduler daemon, so it is never rendered as an
			// installed timer (no Next-run promise either).
			rows << ['Schedule', app.desktop.engine_loop_schedule_state(e.name)]
			if e.verifier.trim_space() != '' {
				rows << ['Verifier', e.verifier]
			}
			mut bud := []string{}
			if e.budget.max_tokens > 0 {
				bud << '${e.budget.max_tokens} tok'
			}
			if e.budget.max_runs_per_day > 0 {
				bud << '${e.budget.max_runs_per_day}/d'
			}
			if e.budget.max_wall_seconds > 0 {
				bud << '${e.budget.max_wall_seconds}s wall'
			}
			if bud.len > 0 {
				rows << ['Budget', bud.join(' · ')]
			}
			total, spent, _ := app.desktop.engine_loop_budget_ledger(e.name)
			if total > 0 {
				rows << ['Ledger', '${spent} / ${total} tok']
			}
			if e.last_run.trim_space() != '' {
				rows << ['Last run', e.last_run]
			}
			// Slice B (#1229): audit / cost / validate / receipts from the
			// Engine. Missing values are omitted, never filled.
			aud := app.desktop.engine_loop_audit(e.name)
			if aud.len > 0 && aud[0].runs > 0 {
				rows << ['Audit', '${aud[0].runs} runs · ${aud[0].success_rate} ok · ${aud[0].tokens} tok']
			}
			if cost := app.desktop.engine_loop_cost(e.name) {
				if cost.budget.max_tokens > 0 {
					rows << ['Cost', '${cost.spent} / ${cost.budget.max_tokens} tok · ${cost.cost_tier}']
				}
			}
			content := loop_entry_canonical(e)
			diags := app.desktop.engine_loop_validate(e.name, content)
			rows << ['Validate', if diags.len == 0 { 'pass' } else { diags[0].message }]
			rec := app.desktop.engine_loop_receipts(e.name)
			if rec.len > 0 {
				rows << ['Receipts', '${rec.len} kept']
			}
			if e.last_exit.trim_space() != '' {
				rows << ['Last exit', e.last_exit]
			}
			if e.exit_conditions.len > 0 {
				rows << ['Exits', e.exit_conditions.join(', ')]
			}
			if e.resumable {
				rows << ['Resumable', 'STATE.md']
			}
			return rows, if e.goal.trim_space() != '' { e.goal } else { e.description }
		}
		2 {
			list := app.desktop.swarm_list()
			if sel >= list.len {
				return rows, ''
			}
			s := list[sel]
			rows << ['Recipe', s.recipe.str()]
			rows << ['Backend', s.backend.str()]
			rows << ['Status', swarm_status_key(s.status)]
			rows << ['Started', format_started_time(s.created_at)]
			// Slice B (#1229): the report view behind the facts — remaining
			// budget, mailbox task backlog, prune stamp. Tokens, never
			// currency; no CI provider is rendered anywhere.
			if s.budget_total > 0 {
				rows << ['Budget', '${s.budget_spent} / ${s.budget_total} tok · ${s.budget_total - s.budget_spent} left']
			}
			if s.worktree != '' {
				rows << ['Worktree', s.worktree]
			}
			rows << ['Handoffs', '${app.desktop.swarm_handoffs(s.id).len}']
			rows << ['Artifacts', '${app.desktop.handoff_artifacts(s.id).len}']
			rows << ['Tasks', '${app.desktop.swarm_queued_tasks(s.id).len} in mailbox']
			pruned := app.desktop.swarm_pruned_at(s.id)
			if pruned != '' {
				rows << ['Pruned', format_started_time(pruned.i64())]
			}
			return rows, s.task
		}
		else {
			checks := app.desktop.engine_doctor()
			if sel >= checks.len {
				return rows, ''
			}
			c := checks[sel]
			rows << ['ID', c.id]
			rows << ['Category', c.category]
			rows << ['Status', if c.status == 'ok' { 'pass' } else { c.status }]
			rows << ['Fixable', if c.fixable { 'yes — dry-run first' } else { 'no' }]
			return rows, c.message
		}
	}
	return rows, ''
}

// draw_operations_tasks renders the run's task board: queued rows with a
// Complete button plus done rows, all bound to mailbox records. The header
// counts both columns; an empty mailbox says so instead of rendering rows.
fn draw_operations_tasks(mut app GuiApp, l OperationsLayout, run_id string) {
	queued := app.desktop.swarm_queued_tasks(run_id)
	done := app.desktop.swarm_done_tasks(run_id)
	_, hy, _, _ := operations_board_rect(l, 4)
	app.gg.draw_text(l.side_x + 16, hy - 4, if queued.len == 0 && done.len == 0 {
		'No tasks in mailbox'
	} else {
		'Tasks · ${queued.len} queued · ${done.len} done'
	}, gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
		bold: queued.len > 0
	})
	mut shown := 0
	for q in queued {
		if shown >= 4 {
			break
		}
		tx, ty, tw, th := operations_board_rect(l, 4 - shown)
		bx, by, bw, bh := operations_board_done_rect(l, 4 - shown)
		app.gg.draw_rect_filled(tx, ty, tw, bh, tint(pc(app, `m`), 40))
		app.gg.draw_text(tx + 6, ty + 3, utf8_truncate('${q.handoff_id} → ${q.to_role}', (tw - 90) / 7), gg.TextCfg{
			color: app.pnl_text
			size: 11
			mono: true
		})
		app.gg.draw_rect_filled(bx, by, bw, bh, tint(app.pnl_select, 60))
		app.gg.draw_text(bx + 8, by + 3, 'Complete', gg.TextCfg{
			color: app.pnl_text
			size: 10
			bold: true
		})
		shown++
		_ = th
	}
	for d in done {
		if shown >= 4 {
			break
		}
		tx, ty, _, _ := operations_board_rect(l, 4 - shown)
		app.gg.draw_text(tx + 6, ty + 3, utf8_truncate('✓ ${d.handoff_id}', (l.side_w - 60) / 7), gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
			mono: true
		})
		shown++
	}
}

fn draw_operations_approvals(mut app GuiApp, l OperationsLayout, run_id string) {
	pending := app.desktop.swarm_approvals(run_id)
	_, ty, _, _ := operations_approval_rect(l, 0)
	app.gg.draw_text(l.side_x + 16, ty - 16, if pending.len == 0 {
		'No pending approvals'
	} else {
		'Approvals · ${pending.len} pending'
	}, gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
		bold: pending.len > 0
	})
	for i, p in pending {
		if i >= 3 {
			break
		}
		ax, ay, aw, ah := operations_approval_rect(l, i)
		kind := p.kind.str()
		kcol := match p.kind {
			.spend { app.pnl_select }
			.scope { pc(app, `C`) }
			.destructive { pc(app, `a`) }
		}
		app.gg.draw_rect_filled(ax, ay, aw, ah, tint(kcol, 24))
		app.gg.draw_rect_empty(ax, ay, aw, ah, tint(kcol, 120))
		app.gg.draw_text(ax + 6, ay + 3, utf8_truncate('${kind} · ${p.message}', (aw - 64) / 7), gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
		// approve (sage check) · reject (rust ×) — real Engine gates
		app.gg.draw_rect_filled(ax + aw - 48, ay + 2, 20, 16, app.pnl_success)
		draw_check_glyph(mut app, ax + aw - 43, ay + 4, app.pnl_bg)
		app.gg.draw_rect_filled(ax + aw - 24, ay + 2, 20, 16, pc(app, `a`))
		app.gg.draw_text(ax + aw - 18, ay + 1, '×', gg.TextCfg{
			color: pc(app, `e`)
			size: 12
			bold: true
		})
	}
}

// draw_operations_detail_empty is the truthful "nothing selected" card: a small
// scene and the real totals behind the table.
fn draw_operations_detail_empty(mut app GuiApp, l OperationsLayout, total int) {
	// Slice B (#1229): the create block owns the column while open — an
	// empty catalog is the most common place to create the first loop.
	if l.tab == 1 && app.loops_show_create {
		draw_operations_create(mut app, l)
		return
	}
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	x, y, iw := l.side_x, l.side_y, l.side_w
	// one soft paper card: scene on top, copy inside it — no empty frame
	cy := y + 44
	scene_h := if l.side_h > 360 { 118 } else { 84 }
	ch := scene_h + 92
	draw_paper_sheet(mut app, x + 12, cy, iw - 24, ch)
	s := if scene_h >= 110 { 3 } else { 2 }
	tray := pixelart.environment_for(.tray)
	lamp := pixelart.environment_for(.lamp)
	plant := pixelart.environment_for(.plant)
	rug := pixelart.environment_for(.rug)
	clock := pixelart.environment_for(.wall_clock)
	gw := lamp.width() * s + tray.width() * s + plant.width() * s + 16
	gx := x + 12 + (iw - 24 - gw) / 2
	base := cy + scene_h - 6
	rs := if rug.width() * s <= iw - 40 { s } else { 2 }
	sc.draw(rug, pid, x + 12 + (iw - 24 - rug.width() * rs) / 2, base - rug.height() * rs + 6, rs)
	sc.draw(lamp, pid, gx, base - lamp.height() * s, s)
	sc.draw(tray, pid, gx + lamp.width() * s + 8, base - tray.height() * s, s)
	sc.draw(plant, pid, gx + lamp.width() * s + tray.width() * s + 16, base - plant.height() * s, s)
	sc.draw(clock, pid, x + iw - 24 - clock.width() * 2 - 8, cy + 8, 2)
	ty := cy + scene_h + 8
	app.gg.draw_text(x + 24, ty, 'Nothing selected', gg.TextCfg{
		color: app.pnl_text
		size: 15
		family: app.fonts.display
	})
	app.gg.draw_text(x + 24, ty + 22, 'Select a row to see its details.', gg.TextCfg{
		color: app.pnl_text_mut
		size: 12
	})
	noun := ['jobs in the supervisor', 'loop templates in the catalog', 'swarm runs recorded',
		'doctor checks reported'][l.tab]
	app.gg.draw_text(x + 24, ty + 42, '${total} ${noun}.', gg.TextCfg{
		color: app.pnl_text_mut
		size: 12
	})
	if app.inspector_msg != '' {
		app.gg.draw_text(x + 12, y + l.side_h - 16, utf8_truncate(app.inspector_msg, (iw - 24) / 6), gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
	}
}

// ── interaction ─────────────────────────────────────────────────────────────

// operations_hover records the hovered element id (app.operations_hover) from the
// same layout the frame draws.
fn operations_hover(mut app GuiApp, w int, h int) {
	app.operations_hover = -1
	if !operations_is_panel(app.selected_panel) {
		return
	}
	l := operations_layout(app, w, h)
	mx, my := app.mouse_x, app.mouse_y
	for i in 0 .. operations_tab_labels.len {
		tx, ty, tw, th := operations_tab_rect(l, i)
		if rect_contains(mx, my, tx, ty, tw, th) {
			app.operations_hover = 1 + i
			return
		}
	}
	fx, fy, fw, fh := operations_filter_rect(l)
	if rect_contains(mx, my, fx, fy, fw, fh) {
		app.operations_hover = 11
		return
	}
	if l.tab == 0 && l.strip_h > 0 {
		bx, by, bw, bh := operations_spawn_btn_rect(l)
		if rect_contains(mx, my, bx, by, bw, bh) {
			app.operations_hover = 32
			return
		}
	}
	if l.tab == 2 {
		for i in 0 .. 3 {
			bx, by, bw, bh := operations_backend_rect(l, i)
			if rect_contains(mx, my, bx, by, bw, bh) {
				app.operations_hover = 20 + i
				return
			}
			rx, ry, rw, rh := operations_recipe_rect(l, i)
			if rect_contains(mx, my, rx, ry, rw, rh) {
				app.operations_hover = 24 + i
				return
			}
		}
		if l.topo_h > 0 {
			zx, zy, pxz, pyz, zw, zh := operations_zoom_rects(l)
			if rect_contains(mx, my, zx, zy, zw, zh) {
				app.operations_hover = 50
				return
			}
			if rect_contains(mx, my, pxz, pyz, zw, zh) {
				app.operations_hover = 51
				return
			}
		}
	}
	if l.tab == 3 {
		ax, ay, aw, ah := operations_fixall_rect(l)
		if rect_contains(mx, my, ax, ay, aw, ah) {
			app.operations_hover = 30
			return
		}
		for i, chip in app.doctor_chips {
			if rect_contains(mx, my, chip.x, chip.y, chip.w, chip.h) {
				app.operations_hover = 40 + i
				return
			}
		}
	}
	visible := operations_visible_rows(l)
	for vi in 0 .. visible {
		rx, ry, rw, rh := operations_row_rect(l, vi)
		if rect_contains(mx, my, rx, ry, rw, rh) {
			app.operations_hover = 100 + vi
			return
		}
	}
	// detail column
	n_act := 3
	for i in 0 .. n_act {
		ax, ay, aw, ah := operations_action_rect(l, i, n_act)
		_ = ax
		_ = aw
		if my >= ay && my < ay + ah && mx >= l.side_x && mx < l.side_x + l.side_w {
			// resolve against the real action count for the selection
			all := operations_rows(mut app, l.tab)
			acts := operations_actions(mut app, l.tab, operations_selected(app, l.tab, all.len))
			for j in 0 .. acts.len {
				bx, by, bw, bh := operations_action_rect(l, j, acts.len)
				if rect_contains(mx, my, bx, by, bw, bh) {
					app.operations_hover = 60 + j
					return
				}
			}
			return
		}
	}
	if l.tab == 2 {
		all_g := operations_rows(mut app, l.tab)
		sel_g := operations_selected(app, l.tab, all_g.len)
		if sel_g >= 0 && app.ops_guide_run == all_g[sel_g].id {
			rows_g := ops_guide_visible_rows(mut app, all_g[sel_g].id)
			for i in 0 .. rows_g.len {
				gx, gy, gw, gh := operations_guide_row_rect(l, i)
				if rect_contains(mx, my, gx + gw - ops_guide_action_w(), gy, ops_guide_action_w(), gh) {
					app.operations_hover = 80 + i
					return
				}
			}
		}
	}
	if l.tab == 1 && app.loops_show_create {
		tx, ty, tw, th := operations_create_tier_rect(l)
		if rect_contains(mx, my, tx, ty, tw, th) {
			app.operations_hover = 81
			return
		}
		c0x, c0y, c0w, c0h := operations_create_btn_rect(l, 0)
		if rect_contains(mx, my, c0x, c0y, c0w, c0h) {
			app.operations_hover = 82
			return
		}
		c1x, c1y, c1w, c1h := operations_create_btn_rect(l, 1)
		if rect_contains(mx, my, c1x, c1y, c1w, c1h) {
			app.operations_hover = 83
			return
		}
	}
	for i in 0 .. 2 {
		rx, ry, rw, rh := operations_related_rect(l, i)
		if rect_contains(mx, my, rx, ry, rw, rh) {
			app.operations_hover = 70 + i
			return
		}
	}
}

// operations_click handles every Operations hit. Returns true when consumed.
// Any click clears the text-field focus first (focus follows the pointer).
fn operations_click(mut app GuiApp, mx int, my int, w int, h int) bool {
	if !operations_is_panel(app.selected_panel) {
		return false
	}
	l := operations_layout(app, w, h)
	app.operations_focus = 0
	// dry-run preview is modal inside the panel (#1108)
	if l.tab == 3 && app.doctor_preview != '' {
		px, py, _, ph := doctor_preview_geom(l.fx, l.fy, l.fw)
		if rect_contains(mx, my, px + 14, py + ph - 32, 120, 22) {
			doctor_preview_confirm(mut app)
			return true
		}
		if rect_contains(mx, my, px + 144, py + ph - 32, 90, 22) {
			app.doctor_preview = ''
			app.doctor_preview_lines = []
			app.inspector_msg = 'Doctor dry-run cancelled — nothing was written'
			return true
		}
		return true
	}
	// tabs → the four Operations panels (nav and tabs stay in sync)
	for i in 0 .. operations_tab_labels.len {
		tx, ty, tw, th := operations_tab_rect(l, i)
		if rect_contains(mx, my, tx, ty, tw, th) {
			if operations_tab_panels[i] != app.selected_panel {
				select_panel(mut app, operations_tab_panels[i])
				app.operations_status_filter = 0
			}
			return true
		}
	}
	sx, sy, sw, sh := operations_search_rect(l)
	if rect_contains(mx, my, sx, sy, sw, sh) {
		app.operations_focus = 1
		app.header_search_focus = false
		app.workspace_focus = false
		app.ghost_focused = false
		return true
	}
	fx, fy, fw, fh := operations_filter_rect(l)
	if rect_contains(mx, my, fx, fy, fw, fh) {
		labels, _ := operations_filter_options(l.tab)
		app.operations_status_filter = (app.operations_status_filter + 1) % labels.len
		operations_set_scroll(mut app, l.tab, 0)
		return true
	}
	if l.tab == 0 && operations_click_spawn_strip(mut app, l, mx, my) {
		return true
	}
	if l.tab == 2 && operations_click_swarm_strip(mut app, l, mx, my) {
		return true
	}
	if l.tab == 3 && operations_click_doctor_strip(mut app, l, mx, my) {
		return true
	}
	// table rows
	all := operations_rows(mut app, l.tab)
	rows := operations_apply_filter(all, app.jobs_filter, operations_filter_key(l.tab, app.operations_status_filter))
	visible := operations_visible_rows(l)
	start := clamp_scroll(operations_scroll_of(app, l.tab), rows.len, visible)
	for vi in 0 .. visible {
		ri := start + vi
		if ri >= rows.len {
			break
		}
		rx, ry, rw, rh := operations_row_rect(l, vi)
		if rect_contains(mx, my, rx, ry, rw, rh) {
			r := rows[ri]
			operations_set_selected(mut app, l.tab, r.idx)
			if l.tab == 0 && app.jobs_logs_job != r.id {
				app.jobs_show_logs = false
			}
			// Doctor: the fix column opens the dry-run preview directly
			if l.tab == 3 && r.fixable && mx >= rx + rw - 28 - (rw - 16 - 28) * 8 / 100 {
				doctor_preview_open(mut app, r.id)
				return true
			}
			app.inspector_msg = operations_select_msg(l.tab, r)
			return true
		}
	}
	// topology nodes / edges (Swarms) — attach desk VT / copy artifact (#1101)
	if l.tab == 2 && l.topo_h > 0 && operations_click_topology(mut app, l, mx, my) {
		return true
	}
	// detail column: approvals, actions, related links
	if rect_contains(mx, my, l.side_x, l.side_y, l.side_w, l.side_h) {
		return operations_click_detail(mut app, l, mx, my, all.len)
	}
	// anything else inside the panel is consumed (no other handler owns it)
	return rect_contains(mx, my, l.fx, l.fy, l.fw, l.fh)
}

fn operations_select_msg(tab int, r OperationsRow) string {
	return match tab {
		0 { 'Job selected: ${r.id}' }
		1 { 'Loop selected: ${r.id}' }
		2 { 'Swarm selected: ${r.id}' }
		else { 'Doctor ${r.id} [${r.cells[1]}] ${r.status}: ${r.cells[3]}' }
	}
}

fn operations_click_swarm_strip(mut app GuiApp, l OperationsLayout, mx int, my int) bool {
	tx, ty, tw, th := operations_task_rect(l)
	if rect_contains(mx, my, tx, ty, tw, th) {
		app.operations_focus = 2
		app.header_search_focus = false
		app.workspace_focus = false
		app.ghost_focused = false
		return true
	}
	for i, bname in ['auto', 'herdr', 'tmux'] {
		bx, by, bw, bh := operations_backend_rect(l, i)
		if bx + bw > l.right_x + l.right_w {
			break // same overflow guard as draw_operations_launch_strip: undrawn = inert
		}
		if rect_contains(mx, my, bx, by, bw, bh) {
			app.swarm_backend = bname
			app.inspector_msg = 'Swarm backend: ${bname}'
			return true
		}
	}
	for i, rname in ['pair', 'team', 'full'] {
		rx, ry, rw, rh := operations_recipe_rect(l, i)
		if rx + rw > l.right_x + l.right_w {
			break // undrawn recipe buttons must not launch swarms
		}
		if rect_contains(mx, my, rx, ry, rw, rh) {
			if app.desktop == unsafe { nil } {
				return true
			}
			task := app.swarm_task.trim_space()
			if task == '' {
				app.inspector_msg = 'Swarm launch needs a task — type one in the Task field'
				app.operations_focus = 2
				return true
			}
			run_id := app.desktop.swarm_launch(rname, app.swarm_backend, task) or {
				app.inspector_msg = 'Swarm launch failed: ${err.msg()}'
				return true
			}
			app.engine_rev = app.desktop.app_state_snapshot().revision
			app.api_calls = app.desktop.engine_api_calls()
			list := app.desktop.swarm_list()
			for si, s in list {
				if s.id == run_id {
					app.swarm_selected = si
				}
			}
			app.inspector_msg = 'Swarm ${rname} requested: ${run_id} (${app.swarm_backend})'
			return true
		}
	}
	return false
}

fn operations_click_doctor_strip(mut app GuiApp, l OperationsLayout, mx int, my int) bool {
	ax, ay, aw, ah := operations_fixall_rect(l)
	if rect_contains(mx, my, ax, ay, aw, ah) {
		if app.desktop == unsafe { nil } {
			return true
		}
		rev := app.desktop.engine_doctor_fix_all() or {
			app.inspector_msg = 'Doctor fix all failed: ${err}'
			return true
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
			'Doctor Fix All applied — revision ${rev} · real repairs + audit stamps'
		}
		return true
	}
	for chip in app.doctor_chips {
		if rect_contains(mx, my, chip.x, chip.y, chip.w, chip.h) {
			rev := app.desktop.engine_doctor_fix_category(chip.cat) or {
				app.inspector_msg = 'Doctor category fix ${chip.cat} failed: ${err}'
				return true
			}
			app.engine_rev = app.desktop.app_state_snapshot().revision
			if app.engine_rev == 0 {
				app.engine_rev = rev
			}
			app.api_calls = app.desktop.engine_api_calls()
			app.inspector_msg = if rev == 0 {
				'Doctor ${chip.cat}: nothing fixable — all pass ✓'
			} else {
				'Doctor ${chip.cat} fixed — revision ${rev}'
			}
			return true
		}
	}
	return false
}

fn operations_click_topology(mut app GuiApp, l OperationsLayout, mx int, my int) bool {
	zx, zy, pxz, pyz, zw, zh := operations_zoom_rects(l)
	if rect_contains(mx, my, zx, zy, zw, zh) {
		if app.swarm_zoom > -1 {
			app.swarm_zoom--
		}
		app.inspector_msg = 'Swarm topology zoom ${app.swarm_zoom}'
		return true
	}
	if rect_contains(mx, my, pxz, pyz, zw, zh) {
		if app.swarm_zoom < 1 {
			app.swarm_zoom++
		}
		app.inspector_msg = 'Swarm topology zoom ${app.swarm_zoom}'
		return true
	}
	for n in app.swarm_nodes {
		if n.w > 0 && rect_contains(mx, my, n.x, n.y, n.w, 30) {
			di := swarm_role_desk(app, n.role)
			if di < 0 {
				app.inspector_msg = 'Swarm ${n.role}: no office desk to attach'
				return true
			}
			if app.term_mode_saved < 0 {
				app.term_mode_saved = app.term_mode
			}
			app.term_view = di
			app.term_mode = 2
			app.term_visible = true
			app.inspector_msg = 'Swarm ${n.role} attached — desk ${di} VT fullscreen (Esc exits)'
			return true
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
			return true
		}
	}
	return false
}

fn operations_click_detail(mut app GuiApp, l OperationsLayout, mx int, my int, total int) bool {
	// Slice B (#1229): the create block works with no selection (empty
	// catalog), and the guide block owns its rows — both precede the
	// selection-gated path below.
	if l.tab == 1 && app.loops_show_create {
		return operations_click_create(mut app, l, mx, my)
	}
	if l.tab == 2 && app.desktop != unsafe { nil } {
		gall := operations_rows(mut app, l.tab)
		gsel := operations_selected(app, l.tab, gall.len)
		if gsel >= 0 && app.ops_guide_run == gall[gsel].id {
			return operations_click_guide(mut app, l, mx, my, gall[gsel].id)
		}
	}
	sel := operations_selected(app, l.tab, total)
	if sel < 0 || app.desktop == unsafe { nil } {
		return true
	}
	// related links work for every selection
	rel := operations_related(l.tab)
	for i, r in rel {
		rx, ry, rw, rh := operations_related_rect(l, i)
		if rect_contains(mx, my, rx, ry, rw, rh) {
			select_panel(mut app, r[1].int())
			return true
		}
	}
	if l.tab == 2 {
		list := app.desktop.swarm_list()
		if sel < list.len {
			// task board Complete buttons — same row order as the draw
			queued := app.desktop.swarm_queued_tasks(list[sel].id)
			mut tshown := 0
			for q in queued {
				if tshown >= 4 {
					break
				}
				bx, by, bw, bh := operations_board_done_rect(l, 4 - tshown)
				if rect_contains(mx, my, bx, by, bw, bh) {
					rev := app.desktop.swarm_task_done(list[sel].id, q.handoff_id) or {
						app.inspector_msg = 'Task ${q.handoff_id} failed: ${err.msg()}'
						return true
					}
					app.engine_rev = app.desktop.app_state_snapshot().revision
					if app.engine_rev == 0 {
						app.engine_rev = rev
					}
					app.inspector_msg = 'Task ${q.handoff_id} completed rev=${rev}'
					return true
				}
				tshown++
			}
			pending := app.desktop.swarm_approvals(list[sel].id)
			for i, p in pending {
				if i >= 3 {
					break
				}
				ax, ay, aw, ah := operations_approval_rect(l, i)
				if rect_contains(mx, my, ax + aw - 48, ay, 20, ah) || rect_contains(mx, my, ax + aw - 24, ay, 20, ah) {
					approved := mx < ax + aw - 26
					rev := app.desktop.swarm_approve(list[sel].id, p.id, approved) or {
						app.inspector_msg = 'Approval ${p.id} failed: ${err.msg()}'
						return true
					}
					app.engine_rev = app.desktop.app_state_snapshot().revision
					if app.engine_rev == 0 {
						app.engine_rev = rev
					}
					app.inspector_msg = 'Approval ${p.kind.str()} ${if approved {
						'approved'
					} else {
						'rejected'
					}} rev=${rev}'
					return true
				}
			}
		}
	}
	acts := operations_actions(mut app, l.tab, sel)
	for i, a in acts {
		ax, ay, aw, ah := operations_action_rect(l, i, acts.len)
		if rect_contains(mx, my, ax, ay, aw, ah) {
			operations_run_action(mut app, l.tab, sel, a.kind)
			return true
		}
	}
	return true
}

// operations_run_action executes a detail action through the Engine and reports the
// actual outcome. Failures are shown as failures.
fn operations_run_action(mut app GuiApp, tab int, sel int, kind string) {
	match tab {
		0 {
			jobs := app.desktop.engine_jobs_catalog()
			if sel >= jobs.len {
				return
			}
			j := jobs[sel]
			match kind {
				'cancel' {
					rev := app.desktop.engine_cancel_job(j.id) or {
						app.inspector_msg = 'Job cancel failed: ${err.msg()}'
						return
					}
					app.engine_rev = rev
					app.api_calls = app.desktop.engine_api_calls()
					app.inspector_msg = 'Job canceled: ${j.id} (rev ${rev})'
				}
				'retry' {
					new_id := app.desktop.engine_retry_job(j.id) or {
						app.inspector_msg = 'Job retry failed: ${err.msg()}'
						return
					}
					app.api_calls = app.desktop.engine_api_calls()
					app.inspector_msg = 'Job retried: ${j.id} → ${new_id}'
				}
				'logs' {
					if app.jobs_show_logs && app.jobs_logs_job == j.id {
						app.jobs_show_logs = false
					} else {
						app.jobs_show_logs = true
						app.jobs_logs_job = j.id
					}
				}
				else {}
			}
		}
		1 {
			loops := app.desktop.loops_catalog()
			if sel >= loops.len {
				return
			}
			e := loops[sel]
			match kind {
				'run' {
					job_id := app.desktop.loop_run(e.name) or {
						app.inspector_msg = 'Loop ${e.name} failed to start: ${err.msg()}'
						return
					}
					app.inspector_msg = 'Loop run started: ${e.name} — job ${job_id}'
				}
				'schedule' {
					next := !e.cron_enabled
					app.desktop.toggle_loop_cron(e.name, next) or {
						app.inspector_msg = 'Loop ${e.name} schedule failed: ${err.msg()}'
						return
					}
					// the cron value is a flag, never an installed timer —
					// the Schedule fact row says so explicitly.
					app.inspector_msg = 'Loop schedule flag ${if next { 'set' } else { 'cleared' }}: ${e.name}'
				}
				'new' {
					app.loops_show_create = true
					app.operations_focus = 4
					app.header_search_focus = false
					app.workspace_focus = false
					app.ghost_focused = false
					app.inspector_msg = 'New loop — name it below, Enter creates'
				}
				'delete' {
					app.desktop.engine_delete_loop(e.name) or {
						app.inspector_msg = 'Loop delete failed: ${err.msg()}'
						return
					}
					app.api_calls = app.desktop.engine_api_calls()
					app.selected_loop = -1
					app.inspector_msg = 'Loop deleted: ${e.name}'
				}
				else {}
			}
		}
		2 {
			list := app.desktop.swarm_list()
			if sel >= list.len {
				return
			}
			s := list[sel]
			match kind {
				'copy' {
					copy_to_clipboard(mut app, s.id)
					app.inspector_msg = 'Copied ${s.id}'
				}
				'stop' {
					// Stop and cancel share the Engine path — the run lands
					// in 'canceled' either way; the message names the verb.
					rev := app.desktop.swarm_stop(s.id) or {
						app.inspector_msg = 'Swarm stop failed: ${err.msg()}'
						return
					}
					app.engine_rev = rev
					app.api_calls = app.desktop.engine_api_calls()
					app.inspector_msg = 'Swarm stopped: ${s.id} (rev ${rev})'
				}
				'promote' {
					tgt := ops_promote_target(s.recipe.str())
					rev := app.desktop.swarm_promote(s.id, tgt) or {
						app.inspector_msg = 'Swarm promote failed: ${err.msg()}'
						return
					}
					app.engine_rev = rev
					app.api_calls = app.desktop.engine_api_calls()
					app.inspector_msg = 'Swarm promoted → ${tgt}: ${s.id} (rev ${rev})'
				}
				'prune' {
					rev := app.desktop.swarm_prune(s.id) or {
						app.inspector_msg = 'Swarm prune failed: ${err.msg()}'
						return
					}
					app.engine_rev = rev
					app.api_calls = app.desktop.engine_api_calls()
					app.inspector_msg = 'Swarm pruned: ${s.id} — worktrees removed, artifacts kept (rev ${rev})'
				}
				'guide' {
					if app.ops_guide_run == s.id {
						app.ops_guide_run = ''
						if app.operations_focus == 5 {
							app.operations_focus = 0
						}
					} else {
						app.ops_guide_run = s.id
						app.operations_focus = 5
						app.header_search_focus = false
						app.workspace_focus = false
						app.ghost_focused = false
					}
				}
				'queue' {
					operations_guide_submit(mut app, s.id)
				}
				else {}
			}
		}
		else {
			checks := app.desktop.engine_doctor()
			if sel >= checks.len {
				return
			}
			c := checks[sel]
			if kind == 'fix' {
				doctor_preview_open(mut app, c.id)
			} else if kind == 'copy' {
				copy_to_clipboard(mut app, '${c.id}: ${c.message}')
				app.inspector_msg = 'Copied ${c.id}'
			}
		}
	}
}

// operations_scroll scrolls the table when the wheel is over it.
fn operations_scroll(mut app GuiApp, delta int, w int, h int) bool {
	if !operations_is_panel(app.selected_panel) {
		return false
	}
	l := operations_layout(app, w, h)
	if !rect_contains(app.mouse_x, app.mouse_y, l.right_x, l.table_y, l.right_w, l.table_h) {
		return false
	}
	all := operations_rows(mut app, l.tab)
	rows := operations_apply_filter(all, app.jobs_filter, operations_filter_key(l.tab, app.operations_status_filter))
	visible := operations_visible_rows(l)
	operations_set_scroll(mut app, l.tab, clamp_scroll(operations_scroll_of(app, l.tab) + delta, rows.len, visible))
	return true
}

// operations_key feeds the focused Operations text field (search or swarm
// task). Returns true when the key was consumed. Escape releases focus.
fn operations_key(mut app GuiApp, e &gg.Event) bool {
	if app.operations_focus == 0 || !operations_is_panel(app.selected_panel) {
		return false
	}
	// Slice B (#1229): Escape only releases focus — it never clears a draft,
	// closes a block, or destroys queued work. Enter confirms the focused
	// composer (spawn / create / guidance); search and swarm-task blur.
	if e.key_code == .escape {
		app.operations_focus = 0
		return true
	}
	if e.key_code == .enter {
		if app.operations_focus == 3 {
			operations_spawn_submit(mut app)
			return true
		}
		if app.operations_focus == 4 {
			operations_loop_create_submit(mut app)
			return true
		}
		if app.operations_focus == 5 && app.ops_guide_run != '' {
			operations_guide_submit(mut app, app.ops_guide_run)
			return true
		}
		app.operations_focus = 0
		return true
	}
	if e.key_code == .tab {
		app.operations_focus = 0
		return true
	}
	if e.key_code == .backspace {
		match app.operations_focus {
			1 {
				if app.jobs_filter.len > 0 {
					app.jobs_filter = app.jobs_filter[..app.jobs_filter.len - 1]
				}
			}
			2 {
				if app.swarm_task.len > 0 {
					app.swarm_task = app.swarm_task[..app.swarm_task.len - 1]
				}
			}
			3 {
				if app.ops_job_spawn.len > 0 {
					app.ops_job_spawn = app.ops_job_spawn[..app.ops_job_spawn.len - 1]
				}
			}
			4 {
				if app.loops_create_name.len > 0 {
					app.loops_create_name = app.loops_create_name[..app.loops_create_name.len - 1]
				}
			}
			5 {
				ops_guide_backspace(mut app)
			}
			else {}
		}
		return true
	}
	is_mod := (e.modifiers & u32(gg.Modifier.ctrl)) != 0 || (e.modifiers & u32(gg.Modifier.super)) != 0
	if !is_mod && ((e.char_code >= 32 && e.char_code < 127) || e.char_code > 127) {
		ch := rune(e.char_code).str()
		if app.operations_focus == 1 {
			app.jobs_filter += ch
			operations_set_scroll(mut app, operations_tab_for_panel(app.selected_panel), 0)
		} else if app.operations_focus == 2 {
			app.swarm_task += ch
		} else if app.operations_focus == 3 {
			app.ops_job_spawn += ch
		} else if app.operations_focus == 4 {
			app.loops_create_name += ch
		} else if app.operations_focus == 5 {
			ops_guide_type(mut app, ch)
		}
		return true
	}
	return true
}
