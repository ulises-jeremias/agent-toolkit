module main

import gg
import time
import desktop.pixelart
import desktop_engine

// VC7 (#1173) — Insights destination, visual convergence pass.
//
// Reference grammar: operations.jpg (metric row + dense table + right-hand
// details), library.jpg (tab strip with a sage underline), concept-board.jpg
// (materials). The seven real tabs stay — cost | waterfall | spans | budgets
// | ci | realtime | gallery — each backed by the same Engine calls as before.
// What changes is the composition: editorial header, four metric cards that
// only show recorded values, pixel-marked tabs, one paper sheet per tab with
// the operations table styling, selectable rows, and a "Report details"
// column on the right that replaces the generic inspector.
//
// Truth: every number is read from the Engine ledger / state. Empty is
// rendered as 0 plus one honest sentence and a small scene; unknown is "—".
// Budget figures are shown as reported, without a currency, because the
// ledger does not record one.

const insights_tabs = ['cost', 'waterfall', 'spans', 'budgets', 'ci', 'realtime', 'gallery']

const insights_tab_labels = ['Cost', 'Waterfall', 'Spans', 'Budgets', 'CI', 'Realtime', 'Gallery']

// InsightsLayout is computed once per frame and shared by drawing, click,
// hover and scroll handlers.
struct InsightsLayout {
	fx        int
	fy        int
	fw        int
	fh        int
	head_h    int
	metric_y  int
	metric_h  int // 0 when compact (the row is dropped, not squeezed)
	tab_y     int
	tab_h     int
	tab_x0    int
	tab_w     int
	content_y int
	content_h int
	inner_x   int
	inner_y   int
	inner_w   int
	rows_y    int // first table row (column header sits 18px above)
	row_h     int
	compact   bool
}

fn insights_layout(app &GuiApp, w int, h int) InsightsLayout {
	fx := panel_fx(app)
	fy := shell_mast_h(h)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	compact := fh < 480 || fw < 640
	head_h := if compact { 44 } else { 60 }
	// At compact widths keep the 2×2 summary only when the remaining height
	// still leaves a useful ledger sheet. Tall/MAX terminal modes win first.
	metric_h := if compact {
		if fh >= 320 { 100 } else { 0 }
	} else {
		78
	}
	metric_y := fy + head_h + 4
	tab_y := metric_y + metric_h + if metric_h > 0 { 10 } else { 0 }
	tab_h := if fh >= 120 { 28 } else { 0 }
	mut tab_w := (fw - 24 - 6 * 6) / insights_tabs.len
	if tab_w > 100 {
		tab_w = 100
	}
	content_y := tab_y + tab_h
	content_h_raw := fy + fh - content_y - 8
	content_h := if content_h_raw > 0 { content_h_raw } else { 0 }
	inner_x := fx + 24
	inner_y := content_y + 14
	return InsightsLayout{
		fx: fx
		fy: fy
		fw: fw
		fh: fh
		head_h: head_h
		metric_y: metric_y
		metric_h: metric_h
		tab_y: tab_y
		tab_h: tab_h
		tab_x0: fx + 12
		tab_w: tab_w
		content_y: content_y
		content_h: content_h
		inner_x: inner_x
		inner_y: inner_y
		inner_w: fw - 48
		rows_y: inner_y + 58
		row_h: 20
		compact: compact
	}
}

fn insights_tab_rect(l InsightsLayout, i int) (int, int, int, int) {
	return l.tab_x0 + i * (l.tab_w + 6), l.tab_y, l.tab_w, l.tab_h
}

// insights_rows_visible is the row budget of the table area (28px footer
// reserve for the row counter).
fn insights_rows_visible(l InsightsLayout) int {
	n := (l.content_y + l.content_h - 28 - l.rows_y) / l.row_h
	return if n < 1 { 1 } else { n }
}

// ── row model ───────────────────────────────────────────────────────────────

// InsRow is one selectable record: table cells + the label/value pairs the
// details column shows. tone marks the status cell (ok / warn / bad / '').
struct InsRow {
	kind   string
	id     string
	tone   string
	cells  []string
	fields [][]string
}

struct InsTable {
	title string
	sub   string
	cols  []string
	col_x []int // offsets from inner_x
	rows  []InsRow
	empty string // one honest sentence when rows.len == 0
	scene int // empty-state scene variant
	hint  string // second muted line: where the real affordance lives
	note  string // truthful caveat rendered under the rows (may be '')
}

fn ins_time(ts i64) string {
	if ts <= 0 {
		return '—'
	}
	return time.unix(ts).format()
}

fn ins_or_dash(s string) string {
	return if s.trim_space() == '' { '—' } else { s }
}

fn ins_status_tone(s string) string {
	low := s.to_lower()
	if low.contains('fail') || low.contains('error') || low.contains('cancel') {
		return 'bad'
	}
	if low.contains('running') || low.contains('done') || low.contains('completed') {
		return 'ok'
	}
	if low.contains('paused') || low.contains('queued') || low.contains('requested') {
		return 'warn'
	}
	return ''
}

// insights_table returns the current tab's rows, memoized per frame / tab /
// width: drawing, metrics, click and details all read the SAME table in a
// frame (collect_engine_logs scans state.data — building it four times a
// frame is wasteful) and the next frame rebuilds so Engine updates show.
fn insights_table(mut app GuiApp, tab string, inner_w int) InsTable {
	key := '${tab}:${inner_w}'
	if app.ins_cache_frame == app.frame && app.ins_cache_key == key {
		return app.ins_cache
	}
	t := insights_table_build(mut app, tab, inner_w)
	app.ins_cache = t
	app.ins_cache_key = key
	app.ins_cache_frame = app.frame
	return t
}

// insights_table_build assembles the current tab's rows from the Engine.
fn insights_table_build(mut app GuiApp, tab string, inner_w int) InsTable {
	has_engine := app.desktop != unsafe { nil }
	match tab {
		'cost' {
			swarms := if has_engine {
				app.desktop.swarm_list()
			} else {
				[]desktop_engine.SwarmRun{}
			}
			jobs := if has_engine {
				app.desktop.engine_jobs_catalog()
			} else {
				[]desktop_engine.JobRecord{}
			}
			mut rows := []InsRow{}
			for r in swarms {
				rows << InsRow{
					kind: 'Swarm run'
					id: r.id
					tone: ins_status_tone(r.status.str())
					cells: [r.id, '${r.recipe.str()} · ${r.status.str()}',
						'${r.budget_spent} / ${r.budget_total}', ins_time(r.created_at)]
					fields: [['Kind', 'Swarm run'], ['Recipe', r.recipe.str()],
						['Backend', r.backend.str()], ['Status', r.status.str()],
						['Budget spent', '${r.budget_spent}'],
						['Budget total', '${r.budget_total} (as reported)'],
						['Created', ins_time(r.created_at)], ['Task', ins_or_dash(r.task)],
						['Worktree', ins_or_dash(r.worktree)], ['Trace', ins_or_dash(r.trace_id)]]
				}
			}
			for j in jobs {
				// every recorded job is a row — ids are Engine-issued, never filtered
				rows << InsRow{
					kind: 'Job'
					id: j.id
					tone: ins_status_tone(j.status.str())
					cells: [j.id, 'job · ${j.status.str()}', 'exit ${j.exit_code}',
						ins_time(j.started_at)]
					fields: [['Kind', 'Job'], ['Status', j.status.str()],
						['Exit code', '${j.exit_code}'], ['Duration', '${j.duration_ms} ms'],
						['Started', ins_time(j.started_at)], ['Finished', ins_time(j.finished_at)],
						['Command', ins_or_dash((j.cmd + ' ' + j.args.join(' ')).trim_space())],
						['Work dir', ins_or_dash(j.work_dir)], ['Retries', '${j.retry_count}']]
				}
			}
			return InsTable{
				title: 'Cost ledger'
				sub: 'Swarm runs and jobs recorded by the Engine ledger. Budget units as reported — no currency is assumed.'
				cols: ['Run / job', 'Kind · status', 'Budget spent / total', 'Started']
				col_x: [0, inner_w * 30 / 100, inner_w * 58 / 100, inner_w * 80 / 100]
				rows: rows
				empty: 'No runs recorded yet. Costs appear here from the ledger as work runs.'
				scene: 0
				hint: 'Launch via Operations → Swarms or Loops'
			}
		}
		'waterfall' {
			agents := if has_engine {
				app.desktop.engine_agents_search('', '')
			} else {
				[]desktop_engine.AgentEntry{}
			}
			mut rows := []InsRow{}
			for a in agents {
				rows << InsRow{
					kind: 'Agent'
					id: a.id
					cells: [a.id, a.tier, a.role, '—']
					fields: [['Kind', 'Catalog agent'], ['Tier', ins_or_dash(a.tier)],
						['Role', ins_or_dash(a.role)], ['Description', ins_or_dash(a.description)],
						['Measured spans', 'none — no tool call has been observed']]
				}
			}
			return InsTable{
				title: 'Tool waterfall'
				sub: 'Per-agent tool spans. Agent identity alone is never evidence that a tool call happened.'
				cols: ['Agent', 'Tier', 'Role', 'Measured spans']
				col_x: [0, inner_w * 32 / 100, inner_w * 50 / 100, inner_w * 78 / 100]
				rows: rows
				empty: 'No agents are available in the resolved catalog.'
				scene: 1
				hint: 'Agents come from the bundled catalog — see Library → Agents'
				note: if rows.len > 0 { 'No measured tool spans yet.' } else { '' }
			}
		}
		'spans' {
			mut sub := 'Measured spans appear after a real job, loop or swarm emits telemetry.'
			if has_engine {
				st := app.desktop.engine_job_stats()
				pids, drops := app.desktop.engine_process_supervisor_stats()
				sub = 'Jobs: pids=${pids} drops=${drops} total=${st.total} running=${st.running} failed=${st.failed}'
			}
			return InsTable{
				title: 'OTel spans'
				sub: sub
				empty: 'No measured spans yet. They appear once a job, loop or swarm emits telemetry.'
				scene: 1
				hint: 'Run a job, loop or swarm via Operations'
			}
		}
		'budgets' {
			loops := if has_engine {
				app.desktop.loops_catalog()
			} else {
				[]desktop_engine.LoopEntry{}
			}
			hist := if has_engine {
				app.desktop.engine_loop_history('')
			} else {
				[]desktop_engine.LoopHistory{}
			}
			with_budget := loops.filter(it.budget.max_tokens > 0 || it.budget.max_wall_seconds > 0).len
			mut rows := []InsRow{}
			for hrow in hist {
				rows << InsRow{
					kind: 'Loop run'
					id: hrow.run_id
					tone: ins_status_tone(hrow.status)
					cells: [hrow.run_id, hrow.loop_name, '${hrow.status} · ${hrow.exit_condition}',
						'${hrow.budget_spent} tok', '${hrow.duration_ms} ms']
					fields: [['Kind', 'Loop run'], ['Loop', hrow.loop_name],
						['Status', ins_or_dash(hrow.status)],
						['Exit condition', ins_or_dash(hrow.exit_condition)],
						['Budget spent', '${hrow.budget_spent} tokens'],
						['Duration', '${hrow.duration_ms} ms'],
						['Started', ins_time(hrow.started_at)]]
				}
			}
			return InsTable{
				title: 'Budgets'
				sub: '${with_budget} of ${loops.len} loop templates declare a budget · run history from the ledger'
				cols: ['Run', 'Loop', 'Status · exit', 'Spent', 'Duration']
				col_x: [0, inner_w * 22 / 100, inner_w * 46 / 100, inner_w * 72 / 100,
					inner_w * 86 / 100]
				rows: rows
				empty: 'No loop runs in the history yet. Budgets are enforced per run; the ledger fills as loops run.'
				scene: 2
				hint: 'Run a loop via Operations → Loops'
			}
		}
		'ci' {
			return InsTable{
				title: 'CI observations'
				sub: 'No CI provider is connected in this build.'
				empty: 'Nothing observed. Workflow names are not results — checks appear here only when a provider reports them.'
				scene: 3
				hint: 'No CI provider can be connected in this build'
			}
		}
		'realtime' {
			logs := if has_engine { collect_engine_logs(app) } else { []TermLine{} }
			mut rows := []InsRow{cap: logs.len}
			// reversed snapshot order; the Engine records no per-event timestamps,
			// so this is NOT chronological — the column is the ledger revision
			for i := logs.len - 1; i >= 0; i-- {
				l := logs[i]
				rows << InsRow{
					kind: 'Event'
					id: l.ts
					tone: ins_status_tone(l.level)
					cells: [l.ts, l.level, l.source, l.msg]
					fields: [['Kind', 'Engine event'], ['Revision', l.ts],
						['Level', ins_or_dash(l.level)], ['Source', ins_or_dash(l.source)],
						['Message', ins_or_dash(l.msg)], ['Raw', ins_or_dash(l.raw)]]
				}
			}
			return InsTable{
				title: 'Realtime feed'
				sub: 'GOD envelopes ${app.god_inbox} in · ${app.god_outbox} out · rev ${app.engine_rev} · api ${app.api_calls} — EventBus, one tick, no polling'
				cols: ['Revision', 'Level', 'Source', 'Message']
				col_x: [0, inner_w * 14 / 100, inner_w * 26 / 100, inner_w * 44 / 100]
				rows: rows
				empty: 'No Engine events observed yet.'
				scene: 1
				hint: 'Events appear here as the Engine works — start something in Operations'
			}
		}
		else {
			return InsTable{
				title: 'Gallery'
			}
		}
	}
}

// ── drawing ─────────────────────────────────────────────────────────────────

fn draw_insights(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	l := insights_layout(app, w, h)
	app.gg.draw_rect_filled(l.fx, l.fy, l.fw, l.fh, app.pnl_bg)
	destination_header(mut app, l.fx, l.fy, l.fw, l.head_h, pixelart.environment_for(.ledger), tr(app, 'panel.insights'), 'Metrics, traces and reports — every number comes from the Engine ledger')
	if l.metric_h > 0 {
		draw_ins_metrics(mut app, l)
	}
	if l.tab_h == 0 || l.content_h < 40 {
		return
	}
	draw_ins_tabs(mut app, l)
	paper_sheet(mut app, l.fx + 12, l.content_y, l.fw - 24, l.content_h)
	if app.insights_tab == 'gallery' {
		draw_insights_gallery(mut app, l)
		return
	}
	t := insights_table(mut app, app.insights_tab, l.inner_w)
	draw_ins_table(mut app, l, t)
}

// draw_ins_metrics — four recorded values, never estimates. Zero is a valid
// state and is written as 0 with a truthful sub-line.
fn draw_ins_metrics(mut app GuiApp, l InsightsLayout) {
	has_engine := app.desktop != unsafe { nil }
	swarms := if has_engine { app.desktop.swarm_list() } else { []desktop_engine.SwarmRun{} }
	jobs := if has_engine {
		app.desktop.engine_jobs_catalog()
	} else {
		[]desktop_engine.JobRecord{}
	}
	loops := if has_engine { app.desktop.loops_catalog() } else { []desktop_engine.LoopEntry{} }
	events := if has_engine { count_engine_logs(app) } else { 0 }
	mut spent := 0
	for r in swarms {
		spent += r.budget_spent
	}
	with_budget := loops.filter(it.budget.max_tokens > 0 || it.budget.max_wall_seconds > 0).len
	runs := swarms.len + jobs.len
	cards := [
		['${runs}', 'Runs recorded', if runs == 0 {
			'no runs yet'
		} else {
			'${swarms.len} swarm · ${jobs.len} jobs'
		}],
		['${spent}', 'Budget spent', if swarms.len == 0 {
			'no ledger rows'
		} else {
			'across ${swarms.len} runs, as reported'
		}],
		['${with_budget}', 'Budgeted loops', if loops.len == 0 {
			'no loop templates'
		} else {
			'of ${loops.len} loop templates'
		}],
		['${events}', 'Events observed', if events == 0 {
			'nothing observed'
		} else {
			'log lines this session'
		}],
	]
	marks := [pixelart.environment_for(.chart_mark), pixelart.environment_for(.ledger),
		pixelart.environment_for(.books), pixelart.environment_for(.board)]
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	gap := 8
	cols := if l.compact { 2 } else { 4 }
	rows := if l.compact { 2 } else { 1 }
	cw := (l.fw - 24 - (cols - 1) * gap) / cols
	ch := (l.metric_h - (rows - 1) * gap) / rows
	for i, c in cards {
		col := i % cols
		row := i / cols
		x := l.fx + 12 + col * (cw + gap)
		y := l.metric_y + row * (ch + gap)
		paper_sheet(mut app, x, y, cw, ch)
		m := marks[i]
		ms := if !l.compact && cw >= 230 { 3 } else { 2 }
		sc.draw(m, pid, x + 10, y + (ch - m.height() * ms) / 2, ms)
		tx := x + 10 + m.width() * ms + 10
		// operations.jpg stack: number / label / fact — the label is never
		// truncated; facts are authored short enough for the narrowest card
		app.gg.draw_text(tx, y + 6, c[0], gg.TextCfg{
			color: app.pnl_text
			size: if l.compact { 18 } else { 22 }
			family: app.fonts.display
		})
		label_y := if l.compact { y + 24 } else { y + 36 }
		app.gg.draw_text(tx, label_y, c[1], gg.TextCfg{
			color: app.pnl_text
			size: if l.compact { 11 } else { 13 }
			bold: true
		})
		// 11px Plex averages ~5.6px/char; onb_fit's 7px would clip real fits
		if !l.compact {
			app.gg.draw_text(tx, y + 56, utf8_truncate(c[2], (cw - (tx - x) - 8) / 6), gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
		}
	}
}

// draw_ins_tabs — pixel-marked tabs; the active one merges into the sheet
// below it and carries the sage underline (library.jpg grammar).
fn draw_ins_tabs(mut app GuiApp, l InsightsLayout) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	marks := [pixelart.environment_for(.ledger), pixelart.environment_for(.chart_mark),
		pixelart.environment_for(.tray), pixelart.environment_for(.books),
		pixelart.environment_for(.board), pixelart.environment_for(.terminal),
		pixelart.environment_for(.picture)]
	with_marks := l.tab_w >= 84
	for i, t in insights_tabs {
		x, y, tw, th := insights_tab_rect(l, i)
		active := app.insights_tab == t
		hover := app.insights_hover == i
		if active {
			app.gg.draw_rect_filled(x + 2, y + 3, tw, th, tint(col_ink, 14))
			app.gg.draw_rect_filled(x, y, tw, th + 2, pc(app, `P`))
			app.gg.draw_rect_empty(x, y, tw, th + 2, tint(pc(app, `W`), 70))
			app.gg.draw_rect_filled(x + 1, y + th, tw - 2, 3, pc(app, `P`)) // merge into the sheet
			app.gg.draw_rect_filled(x + 8, y + th - 3, tw - 16, 3, app.pnl_success)
		} else if hover {
			app.gg.draw_rect_filled(x, y, tw, th, app.pnl_card_sel)
		}
		mut tx := x + 10
		if with_marks {
			m := marks[i]
			sc.draw(m, pid, x + 8, y + (th - m.height()) / 2, 1)
			tx = x + 8 + m.width() + 6
		}
		app.gg.draw_text(tx, y + 7, insights_tab_labels[i], gg.TextCfg{
			color: if active { app.pnl_text } else { app.pnl_text_mut }
			size: if with_marks { 12 } else { 11 }
			bold: active
		})
	}
}

fn ins_tone_color(app &GuiApp, tone string) gg.Color {
	return match tone {
		'ok' { app.pnl_success }
		'warn' { app.pnl_select }
		'bad' { app.pnl_danger }
		else { app.pnl_text_mut }
	}
}

// draw_ins_table renders one tab sheet: title, sub-line, column header,
// alternating rows with selection + hover, footer counter. Empty tables
// render a small scene and one honest sentence instead of a blank grid.
fn draw_ins_table(mut app GuiApp, l InsightsLayout, t InsTable) {
	app.gg.draw_text(l.inner_x, l.inner_y, t.title, gg.TextCfg{
		color: app.pnl_text
		size: 17
		family: app.fonts.display
	})
	draw_onb_wrapped(mut app, l.inner_x, l.inner_y + 22, l.inner_w, t.sub, 2)
	bottom := l.content_y + l.content_h
	if t.rows.len == 0 {
		draw_ins_empty(mut app, l.inner_x, l.inner_y + 44, l.inner_w, bottom - (l.inner_y + 44) - 12, t.scene, t.empty, t.hint)
		return
	}
	// column header
	hy := l.rows_y - 18
	for ci, c in t.cols {
		app.gg.draw_text(l.inner_x + t.col_x[ci] + 6, hy, c.to_upper(), gg.TextCfg{
			color: app.pnl_text_mut
			size: 9
			bold: true
		})
	}
	app.gg.draw_rect_filled(l.inner_x, hy + 14, l.inner_w, 1, tint(pc(app, `W`), 120))
	visible := insights_rows_visible(l)
	app.insights_scroll = clamp_scroll(app.insights_scroll, t.rows.len, visible)
	start := app.insights_scroll
	mut end := start + visible
	if end > t.rows.len {
		end = t.rows.len
	}
	for idx in start .. end {
		r := t.rows[idx]
		row := idx - start
		ry := l.rows_y + row * l.row_h
		selected := idx == app.insights_sel
		hover := onb_hit(app.mouse_x, app.mouse_y, l.inner_x, ry, l.inner_w, l.row_h)
		if selected {
			app.gg.draw_rect_filled(l.inner_x, ry, l.inner_w, l.row_h, tint(app.pnl_success, 70))
			app.gg.draw_rect_filled(l.inner_x, ry, 3, l.row_h, app.pnl_success)
		} else if hover {
			app.gg.draw_rect_filled(l.inner_x, ry, l.inner_w, l.row_h, app.pnl_card_sel)
		} else if row % 2 == 1 {
			app.gg.draw_rect_filled(l.inner_x, ry, l.inner_w, l.row_h, tint(pc(app, `m`), 30))
		}
		for ci, cell in r.cells {
			if ci >= t.col_x.len {
				break
			}
			cx := l.inner_x + t.col_x[ci] + 6
			next := if ci + 1 < t.col_x.len {
				l.inner_x + t.col_x[ci + 1]
			} else {
				l.inner_x + l.inner_w
			}
			mut tx := cx
			if ci == 1 && r.tone != '' {
				// status cell: tone dot + text, never color alone
				app.gg.draw_rect_filled(cx, ry + 7, 6, 6, ins_tone_color(app, r.tone))
				tx += 10
			}
			app.gg.draw_text(tx, ry + 4, utf8_truncate(cell, onb_fit(next - tx - 6, 11)), gg.TextCfg{
				color: if ci == 0 || ci == r.cells.len - 1 {
					app.pnl_text
				} else {
					app.pnl_text_mut
				}
				size: 11
				mono: ci == 0
			})
		}
	}
	// footer — honest counter; scrolling is by wheel over the rows
	counter := if t.rows.len > visible {
		'rows ${start + 1}–${end} of ${t.rows.len} · scroll for more'
	} else {
		'${t.rows.len} row(s)'
	}
	foot := if t.note != '' { '${counter} · ${t.note}' } else { counter }
	app.gg.draw_text(l.inner_x, bottom - 22, foot, gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
	})
}

// ins_center_lines draws text centered on cx, wrapping to at most max_lines
// of ~per characters; returns the y after the last line.
fn ins_center_lines(mut app GuiApp, cx int, y int, per int, text string, size int, col gg.Color, max_lines int) int {
	mut lines := []string{}
	mut line := ''
	for word in text.split(' ') {
		cand := if line == '' { word } else { line + ' ' + word }
		if cand.len > per && line != '' {
			lines << line
			line = word
		} else {
			line = cand
		}
	}
	if line != '' {
		lines << line
	}
	adv := if size <= 11 { 6 } else { 7 }
	mut yy := y
	for i, ln in lines {
		if i >= max_lines {
			break
		}
		app.gg.draw_text(cx - ln.len * adv / 2, yy, ln, gg.TextCfg{
			color: col
			size: size
		})
		yy += size + 4
	}
	return yy
}

// draw_ins_empty is the empty state: scene + sentence + affordance hint as
// ONE centered group anchored in the upper-middle of the sheet (scene centre
// at ~30% height), never a lone sprite floating mid-void.
fn draw_ins_empty(mut app GuiApp, x int, y int, w int, h int, scene int, sentence string, hint string) {
	cx := x + w / 2
	if h < 90 {
		ins_center_lines(mut app, cx, y + 8, onb_fit(w, 12), sentence, 12, app.pnl_text_mut, 2)
		return
	}
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	sprites := match scene {
		0 {
			[pixelart.environment_for(.ledger), pixelart.environment_for(.desk),
				pixelart.environment_for(.plant)]
		}
		1 {
			[pixelart.environment_for(.tray), pixelart.environment_for(.lamp),
				pixelart.environment_for(.plant)]
		}
		2 {
			[pixelart.environment_for(.books), pixelart.environment_for(.shelf),
				pixelart.environment_for(.plant)]
		}
		else {
			[pixelart.environment_for(.board), pixelart.environment_for(.plant)]
		}
	}
	// Empty is still a place. Build a quiet records room rather than leaving
	// three icons adrift in a large sheet. Props are static illustration only.
	art_w := if w - 60 > 520 { 520 } else { w - 60 }
	mut art_h := h * 52 / 100
	if art_h > 220 {
		art_h = 220
	}
	if art_h < 82 {
		art_h = 82
	}
	ax := cx - art_w / 2
	ay := y + 8
	wall_h := art_h * 43 / 100
	app.gg.draw_rect_filled(ax, ay, art_w, wall_h, pc(app, `p`))
	app.gg.draw_rect_filled(ax, ay + wall_h, art_w, art_h - wall_h, pc(app, `m`))
	app.gg.draw_rect_filled(ax, ay + wall_h - 3, art_w, 3, pc(app, `W`))
	for ly := ay + wall_h + 12; ly < ay + art_h; ly += 12 {
		app.gg.draw_line(ax, ly, ax + art_w, ly, tint(pc(app, `W`), 80))
	}
	s := if art_w >= 420 && art_h >= 150 {
		4
	} else if art_w >= 260 { 3 } else { 2 }
	base := ay + art_h - 10
	mut total_w := 0
	for sp in sprites {
		total_w += (sp.width() + 10) * s
	}
	mut gx := cx - total_w / 2
	for sp in sprites {
		sc.draw(sp, pid, gx, base - sp.height() * s, s)
		gx += (sp.width() + 10) * s
	}
	board := pixelart.environment_for(.board)
	if art_w >= 300 {
		sc.draw(board, pid, ax + art_w - board.width() * 2 - 14, ay + 10, 2)
		shelf := pixelart.environment_for(.shelf)
		sc.draw(shelf, pid, ax + 14, ay + wall_h - shelf.height() * 2, 2)
		picture := pixelart.environment_for(.picture)
		sc.draw(picture, pid, cx - picture.width(), ay + 12, 2)
	}
	app.gg.draw_rect_empty(ax, ay, art_w, art_h, tint(pc(app, `W`), 100))
	ty := ins_center_lines(mut app, cx, base + 18, onb_fit(w - 40, 12), sentence, 12, app.pnl_text, 2)
	if hint != '' {
		ins_center_lines(mut app, cx, ty + 4, onb_fit(w - 40, 11), hint, 11, app.pnl_text_mut, 1)
	}
}

// draw_insights_gallery — the living stationery style guide (real tokens
// and fonts). Content carried over; positioned inside the tab sheet.
fn draw_insights_gallery(mut app GuiApp, l InsightsLayout) {
	inner_x := l.inner_x
	inner_y := l.inner_y
	inner_w := l.inner_w
	bottom := l.content_y + l.content_h
	app.gg.draw_text(inner_x, inner_y, 'Gallery — the Paper Co. design system, live from tokens', gg.TextCfg{
		color: app.pnl_text
		size: 17
		family: app.fonts.display
	})
	app.gg.draw_text(inner_x, inner_y + 22, 'Every swatch below is the resolved theme token of the current appearance.', gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
	})
	swatch_names := ['paper', 'cream', 'manila', 'kraft', 'steel', 'ink', 'rust', 'brass', 'sage']
	swatch_cols := [app.pnl_bg, app.pnl_bg, app.pnl_card_sel, app.pnl_border, app.pnl_text_mut,
		app.pnl_text, app.pnl_danger, app.pnl_select, app.pnl_success]
	dark_swatches := ['ink', 'rust', 'brass']
	mut sx := inner_x
	mut sy := inner_y + 48
	for i in 0 .. swatch_names.len {
		if i == 5 {
			sx = inner_x
			sy += 60
		}
		app.gg.draw_rect_filled(sx, sy, 74, 44, swatch_cols[i])
		app.gg.draw_rect_empty(sx, sy, 74, 44, tint(pc(app, `W`), 120))
		swatch_txt_col := if swatch_names[i] in dark_swatches { app.pnl_bg } else { app.pnl_text }
		app.gg.draw_text(sx + 6, sy + 30, swatch_names[i], gg.TextCfg{
			color: swatch_txt_col
			size: 10
			bold: true
		})
		sx += 80
	}
	ty := sy + 60
	if ty + 100 > bottom {
		return
	}
	app.gg.draw_text(inner_x, ty, 'Fraunces Display — letterheads & headlines 22', gg.TextCfg{
		color: app.pnl_text
		size: 22
		family: app.fonts.display
	})
	app.gg.draw_text(inner_x, ty + 34, 'IBM Plex Sans — body copy 15, the humanist grotesk of the office memo.', gg.TextCfg{
		color: app.pnl_text
		size: 15
	})
	app.gg.draw_text(inner_x, ty + 58, 'IBM Plex Mono — receipts, logs, 13px typewriter', gg.TextCfg{
		color: app.pnl_text_mut
		size: 13
		mono: true
	})
	comp_y := ty + 92
	if comp_y + 40 > bottom {
		return
	}
	paper_button(mut app, inner_x, comp_y, 96, 24, 'Primary', true, false)
	paper_button(mut app, inner_x + 108, comp_y, 96, 24, 'Paper', false, false)
	app.gg.draw_rect_filled(inner_x + 216, comp_y, 96, 24, app.pnl_card_sel)
	app.gg.draw_rect_empty(inner_x + 216, comp_y, 96, 24, app.pnl_border_hi)
	app.gg.draw_text(inner_x + 240, comp_y + 6, 'Manila', gg.TextCfg{
		color: app.pnl_text
		size: 11
	})
	app.gg.draw_rect_filled(inner_x + 324, comp_y, 96, 24, app.pnl_danger)
	app.gg.draw_text(inner_x + 348, comp_y + 6, 'Rust', gg.TextCfg{
		color: app.pnl_bg
		size: 11
		bold: true
	})
	// rivet card specimen
	rc_x := inner_x + inner_w - 190
	if rc_x > inner_x + 440 {
		app.gg.draw_rect_filled(rc_x, comp_y - 6, 180, 66, app.pnl_card)
		app.gg.draw_rect_empty(rc_x, comp_y - 6, 180, 66, app.pnl_border)
		app.gg.draw_rect_filled(rc_x + 6, comp_y, 6, 6, tint(app.pnl_select, 180))
		app.gg.draw_rect_filled(rc_x + 168, comp_y, 6, 6, tint(app.pnl_select, 180))
		app.gg.draw_text(rc_x + 20, comp_y + 12, 'Rivet card', gg.TextCfg{
			color: app.pnl_text
			size: 14
			family: app.fonts.display
		})
		app.gg.draw_text(rc_x + 20, comp_y + 30, 'perforated feed strip', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
			mono: true
		})
	}
	app.gg.draw_text(inner_x, bottom - 22, 'tokens: theme/tokens.v · Fraunces + IBM Plex (OFL) in assets/fonts · EN, ES, ZH and AR chrome', gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
	})
}

// ── right column: "Report details" (replaces the inspector on panel 12) ────

fn draw_insights_detail(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	ix := inspector_x(app, w)
	iy := panel_top(app)
	iw := inspector_w
	ih := content_bottom(app, h) - iy
	app.gg.draw_rect_filled(ix, iy, iw, ih, app.pnl_bg)
	app.gg.draw_line(ix, iy, ix, iy + ih, app.pnl_border)
	if ih < 80 {
		return
	}
	app.gg.draw_text(ix + 16, iy + 10, 'Report details', gg.TextCfg{
		color: app.pnl_text
		size: 17
		family: app.fonts.display
	})
	sc.draw(pixelart.environment_for(.chart_mark), pid, ix + iw - 44, iy + 8, 2)
	l := insights_layout(app, w, h)
	t := insights_table(mut app, app.insights_tab, l.inner_w)
	tab_i := insights_tabs.index(app.insights_tab)
	tab_label := if tab_i >= 0 { insights_tab_labels[tab_i] } else { app.insights_tab }
	mut y := iy + 44
	quote_y := iy + ih - 8 - 62
	if app.insights_sel >= 0 && app.insights_sel < t.rows.len {
		r := t.rows[app.insights_sel]
		paper_pill(mut app, ix + 16, y, r.kind, app.pnl_select)
		app.gg.draw_text(ix + 16, y + 22, utf8_truncate(r.id, onb_fit(iw - 32, 13)), gg.TextCfg{
			color: app.pnl_text
			size: 13
			bold: true
			mono: true
		})
		y += 48
		app.gg.draw_rect_filled(ix + 16, y - 6, iw - 32, 1, tint(pc(app, `W`), 90))
		for f in r.fields {
			long := f[1].len > onb_fit(iw - 32, 12)
			need := if long { 46 } else { 32 }
			if y + need > quote_y - 8 {
				app.gg.draw_text(ix + 16, y, '… more fields than fit', gg.TextCfg{
					color: app.pnl_text_mut
					size: 10
				})
				break
			}
			app.gg.draw_text(ix + 16, y, f[0], gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
			})
			if long {
				draw_onb_wrapped(mut app, ix + 16, y + 13, iw - 32, f[1], 2)
			} else {
				app.gg.draw_text(ix + 16, y + 13, f[1], gg.TextCfg{
					color: app.pnl_text
					size: 12
				})
			}
			y += need
		}
	} else {
		// truthful empty card — nothing selected, or nothing selectable
		card_h := 132
		paper_sheet(mut app, ix + 8, y, iw - 16, card_h)
		sc.draw(pixelart.environment_for(.ledger), pid, ix + 24, y + 18, 3)
		app.gg.draw_text(ix + 76, y + 18, 'Nothing selected', gg.TextCfg{
			color: app.pnl_text
			size: 15
			family: app.fonts.display
		})
		sentence := if t.rows.len > 0 {
			'Select a row in the ${tab_label} tab to see its recorded fields.'
		} else {
			'The ${tab_label} tab has no rows to select.'
		}
		draw_onb_wrapped(mut app, ix + 76, y + 40, iw - 92, sentence, 3)
		y += card_h + 16
		ws_section_label(mut app, ix + 16, y, 'SOURCES')
		app.gg.draw_text(ix + 16, y + 20, 'Engine state · swarm and job ledger', gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
		app.gg.draw_text(ix + 16, y + 35, 'EventBus feed · loop history', gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
		app.gg.draw_text(ix + 16, y + 52, 'Values are read as recorded; nothing is estimated.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
		y += 70
	}
	if quote_y > y + 8 {
		draw_paper_quote(mut app, ix + 8, quote_y, iw - 16, '"A quieter internet can be', 'a kinder place."', '— The Hornero Principle')
	}
}

// ── interaction (single source of geometry, shared with drawing) ────────────

// insights_click handles tabs, row selection and the right column. Returns
// true when the click was consumed.
fn insights_click(mut app GuiApp, mx int, my int, w int, h int) bool {
	l := insights_layout(app, w, h)
	// Mirrors draw_insights: suppressed tabs/rows are not drawn and must stay
	// inert. The right column stays live so details remain reachable.
	if l.tab_h == 0 || l.content_h < 40 {
		ix := inspector_x(app, w)
		iy := panel_top(app)
		if onb_hit(mx, my, ix, iy, inspector_w, content_bottom(app, h) - iy) {
			return true
		}
		return false
	}
	for i, t in insights_tabs {
		x, y, tw, th := insights_tab_rect(l, i)
		if onb_hit(mx, my, x, y, tw, th) {
			if app.insights_tab != t {
				app.insights_tab = t
				app.insights_sel = -1
				app.insights_scroll = 0
			}
			app.inspector_msg = 'Insights → ${insights_tab_labels[i]}'
			return true
		}
	}
	if app.insights_tab != 'gallery' {
		tbl := insights_table(mut app, app.insights_tab, l.inner_w)
		if tbl.rows.len > 0 {
			visible := insights_rows_visible(l)
			start := clamp_scroll(app.insights_scroll, tbl.rows.len, visible)
			if onb_hit(mx, my, l.inner_x, l.rows_y, l.inner_w, visible * l.row_h) {
				idx := start + (my - l.rows_y) / l.row_h
				if idx >= 0 && idx < tbl.rows.len {
					app.insights_sel = if app.insights_sel == idx { -1 } else { idx }
					return true
				}
			}
		}
	}
	// the right column is this destination's own surface: consume so the
	// generic inspector geometry never reacts underneath it
	ix := inspector_x(app, w)
	iy := panel_top(app)
	if onb_hit(mx, my, ix, iy, inspector_w, content_bottom(app, h) - iy) {
		return true
	}
	return false
}

// insights_hover_at records the hovered tab (rows compute hover live from
// the mouse position while drawing).
fn insights_hover_at(mut app GuiApp, mx int, my int, w int, h int) {
	l := insights_layout(app, w, h)
	for i in 0 .. insights_tabs.len {
		x, y, tw, th := insights_tab_rect(l, i)
		if onb_hit(mx, my, x, y, tw, th) {
			app.insights_hover = i
			return
		}
	}
}

// insights_scroll_by scrolls the current table when the wheel is over it.
fn insights_scroll_by(mut app GuiApp, delta int, w int, h int) bool {
	if app.insights_tab == 'gallery' {
		return false
	}
	l := insights_layout(app, w, h)
	if !onb_hit(app.mouse_x, app.mouse_y, l.fx + 12, l.content_y, l.fw - 24, l.content_h) {
		return false
	}
	tbl := insights_table(mut app, app.insights_tab, l.inner_w)
	visible := insights_rows_visible(l)
	app.insights_scroll = clamp_scroll(app.insights_scroll + delta, tbl.rows.len, visible)
	return true
}
