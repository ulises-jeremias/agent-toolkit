module main

import gg
import desktop
import desktop.pixelart
import desktop_engine

// Office overview against office.jpg.
//
// The room itself is composed in office_room.v and left untouched here. This
// file adds the surrounding operational UI the reference shows around it:
// four metric cards across the top, and — to the right of the room — an
// Agent Roster above the attention surface. Every number is real Engine
// state; on an idle machine the cards read 0 with honest sub-lines, the
// roster shows the catalog agents idle (catalog ≠ runtime), and the
// attention surface shows run-backed rows projected from real Engine records
// (jobs, swarm runs, loop histories) with explicit states, the approvals
// queue as a projection, and recent completions with evidence — never
// invented approvals or activity. Domain projection lives in
// modules/desktop/facade_office.v; this file owns viewmodel glue, drawing,
// and input.

struct OfficeLayout {
	fx      int
	fy      int
	fw      int
	fh      int
	cards_y int
	card_h  int
	room_x  int
	room_y  int
	room_w  int
	room_h  int
	side_x  int // roster + today column (inside the panel, right of the room)
	side_w  int
	compact bool
	cards_x int
	cards_w int
}

fn office_layout(app &GuiApp, w int, h int) OfficeLayout {
	fx := panel_fx(app)
	fy := shell_mast_h(h)
	fw := panel_fw(app, w)
	fh := content_bottom(app, h) - fy
	compact := fw < 700 || fh < 420
	cards_y := fy + 50
	card_h := if compact { 56 } else { 70 }
	room_y := cards_y + card_h + 12
	room_h := fh - (room_y - fy) - 12
	cards_x := if app.lang.is_rtl() { 16 } else { fx + 16 }
	cards_w := w - dock_w - 32
	// The global shell owns a destination detail column. Office uses that
	// column for Roster + Today, leaving the room as the central hero.
	side_w := 0
	room_w := fw - 32
	return OfficeLayout{
		fx: fx
		fy: fy
		fw: fw
		fh: fh
		cards_y: cards_y
		card_h: card_h
		room_x: fx + 16
		room_y: room_y
		room_w: room_w
		room_h: room_h
		side_x: fx + 16 + room_w + 12
		side_w: side_w
		compact: compact
		cards_x: cards_x
		cards_w: cards_w
	}
}

fn office_detail_layout(app &GuiApp, w int, h int) OfficeLayout {
	base := office_layout(app, w, h)
	return OfficeLayout{
		side_x: inspector_x(app, w) + 8
		side_w: inspector_w - 16
		room_y: base.room_y
		room_h: content_bottom(app, h) - base.room_y - 12
	}
}

fn office_card_rect(l OfficeLayout, i int) (int, int, int, int) {
	gap := 12
	n := 4
	cw := (l.cards_w - (n - 1) * gap) / n
	return l.cards_x + i * (cw + gap), l.cards_y, cw, l.card_h
}

struct OfficeMetric {
	value int
	label string
	sub   string
	mark  pixelart.EnvironmentAsset
	alert bool
}

// office_metrics derives the four reference cards from real Engine state.
fn office_metrics(mut app GuiApp, attention int, agents int, running int) []OfficeMetric {
	mut loops_sched := 0
	mut mcp_enabled := 0
	mut provider_total := 0
	if app.desktop != unsafe { nil } {
		for lp in app.desktop.loops_catalog() {
			if lp.cron_enabled {
				loops_sched++
			}
		}
		for p in app.desktop.engine_mcp_catalog() {
			provider_total++
			if p.enabled {
				mcp_enabled++
			}
		}
	}
	att_sub := if attention == 0 { 'nothing to fix' } else { 'see Operations' }
	ag_sub := if running == 0 { 'none running' } else { '${running} running' }
	lp_sub := if loops_sched == 0 { 'none scheduled' } else { 'cron enabled' }
	// MCP: the GUI only knows health for providers it has probed (60s cache);
	// enabled-count is the honest headline, health is stated only when known
	mcp_sub := if mcp_enabled == 0 {
		'${provider_total} in catalog'
	} else if app.mcp_probe_id != '' && app.frame - app.mcp_probe_at < 3600 {
		if app.mcp_probe_ok { 'last probe healthy' } else { 'last probe failed' }
	} else {
		'enabled · not probed yet'
	}
	return [
		OfficeMetric{attention, 'Needs attention', att_sub, .alert_mark, attention > 0},
		OfficeMetric{agents, 'Catalog agents', ag_sub, .swarm_mark, false},
		OfficeMetric{loops_sched, 'Scheduled loops', lp_sub, .calendar_mark, false},
		OfficeMetric{mcp_enabled, 'MCP enabled', mcp_sub, .gear_mark, false},
	]
}

fn draw_office_cards(mut app GuiApp, l OfficeLayout, metrics []OfficeMetric) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	for i, m in metrics {
		cx, cy, cw, ch := office_card_rect(l, i)
		app.gg.draw_rect_filled(cx + 2, cy + 3, cw, ch, tint(col_ink, 14))
		app.gg.draw_rect_filled(cx, cy, cw, ch, pc(app, `P`))
		app.gg.draw_rect_empty(cx, cy, cw, ch, tint(pc(app, `W`), 70))
		accent := if m.alert { pc(app, `a`) } else { app.pnl_success }
		app.gg.draw_rect_filled(cx, cy, 3, ch, tint(accent, 170))
		mark := pixelart.environment_for(m.mark)
		ms := if ch >= 64 { 3 } else { 2 }
		sc.draw(mark, pid, cx + 14, cy + (ch - mark.height() * ms) / 2, ms)
		tx := cx + 14 + mark.width() * ms + 12
		app.gg.draw_text(tx, cy + 4, '${m.value}', gg.TextCfg{
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

// draw_office_roster lists resolved catalog agents with deterministic identity
// portraits. Jobs currently have no agent attribution, so every roster row is
// explicitly idle even when the separate aggregate says jobs are running.
fn draw_office_roster(mut app GuiApp, l OfficeLayout, agents []desktop_engine.AgentEntry, y0 int, h int) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	x := l.side_x
	w := l.side_w
	app.gg.draw_rect_filled(x + 2, y0 + 3, w, h, tint(col_ink, 14))
	app.gg.draw_rect_filled(x, y0, w, h, pc(app, `P`))
	app.gg.draw_rect_empty(x, y0, w, h, tint(pc(app, `W`), 70))
	app.gg.draw_text(x + 12, y0 + 8, 'Agent Roster', gg.TextCfg{
		color: app.pnl_text
		size: 15
		family: app.fonts.display
	})
	app.gg.draw_text(x + w - 12 - 7 * '${agents.len} agents'.len, y0 + 12, '${agents.len} agents', gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
	})
	row_h := 34
	mut ry := y0 + 32
	desks := desks_for_app(app)
	for i, agent_entry in agents {
		if ry + row_h > y0 + h - 4 {
			left := agents.len - i
			app.gg.draw_text(x + 12, y0 + h - 16, '+${left} more catalog agents', gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
			})
			break
		}
		sel := app.selected_desk >= 0 && app.selected_desk < desks.len
			&& desks[app.selected_desk].id == agent_entry.id
		if sel {
			app.gg.draw_rect_filled(x + 4, ry - 2, w - 8, row_h - 2, tint(app.pnl_success, 200))
		}
		agent := pixelart.with_identity(pixelart.agent_for_state(.idle), i % 3)
		sc.draw(agent, pid, x + 12, ry + 2, 2)
		app.gg.draw_text(x + 44, ry + 1, utf8_truncate(agent_entry.id, text_fit_chars(w - 120, 12)), gg.TextCfg{
			color: app.pnl_text
			size: 12
			bold: true
		})
		role := if agent_entry.role == '' { agent_entry.tier } else { agent_entry.role }
		app.gg.draw_text(x + 44, ry + 16, utf8_truncate(role, text_fit_chars(w - 60, 10)), gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
		// Jobs do not currently carry a catalog-agent attribution. A running
		// aggregate must never be assigned to the first N roster rows.
		state := 'Idle'
		pc_ := app.pnl_text_mut
		pw := state.len * 6 + 12
		app.gg.draw_rect_filled(x + w - pw - 10, ry + 4, pw, 16, tint(pc_, 60))
		app.gg.draw_text(x + w - pw - 4, ry + 6, state, gg.TextCfg{
			color: pc_
			size: 10
		})
		ry += row_h
	}
}

// (Slice A, #1228: the Today column was superseded by the attention surface
// below — attention jobs are run rows now, doctor warnings survive as a
// signals line, and onboarding setup lives in the Workspace panel.)

fn draw_office_detail(mut app GuiApp, w int, h int) {
	l := office_detail_layout(app, w, h)
	ix := inspector_x(app, w)
	iy := l.room_y - 4
	ih := content_bottom(app, h) - iy
	app.gg.draw_rect_filled(ix, iy, inspector_w, ih, app.pnl_card)
	app.gg.draw_line(ix, iy, ix, iy + ih, app.pnl_border)
	mut agents := []desktop_engine.AgentEntry{}
	if app.desktop != unsafe { nil } {
		agents = app.desktop.engine_agents_search('', '')
	}
	// The roster keeps its geometry (shared with office_roster_click); the
	// space below it is the attention surface: live runs, approvals as a
	// projection over the Engine queue, and recent completions.
	roster_h := l.room_h * 40 / 100
	draw_office_roster(mut app, l, agents, l.room_y, roster_h)
	snap := office_attention_snapshot(mut app)
	draw_office_attention(mut app, l, l.room_y + roster_h + 10, l.room_h - roster_h - 10,
		snap)
}

// office_roster_click selects the corresponding floor desk only when the real
// catalog ID is represented there. Otherwise it leaves selection empty and
// reports the catalog record without inventing a room mapping.
fn office_roster_click(mut app GuiApp, mx int, my int, w int, h int) bool {
	if app.desktop == unsafe { nil } {
		return false
	}
	l := office_detail_layout(app, w, h)
	roster_h := l.room_h * 40 / 100
	x := l.side_x
	row_h := 34
	mut ry := l.room_y + 32
	agents := app.desktop.engine_agents_search('', '')
	for agent_entry in agents {
		if ry + row_h > l.room_y + roster_h - 4 {
			break
		}
		if mx >= x + 4 && mx < x + l.side_w - 4 && my >= ry - 2 && my < ry + row_h - 2 {
			app.selected_desk = -1
			for di, desk in desks_for_app(app) {
				if desk.id == agent_entry.id {
					app.selected_desk = di
					break
				}
			}
			app.inspector_msg = 'Catalog agent: ${agent_entry.id} · runtime attribution unavailable'
			return true
		}
		ry += row_h
	}
	// Attention surface below the roster (same geometry as
	// draw_office_attention): run rows select their Engine record, approval
	// and completion rows drill into the inspector, action buttons dispatch
	// through the Engine.
	return office_attention_click(mut app, l, mx, my)
}

// ── attention surface: viewmodel ───────────────────────────────────────────

// OfficeAttentionSnapshot is the live viewmodel for the attention surface:
// run-backed rows, pending approvals, recent completions. engine_live is
// false when no Engine is attached (loading/disconnected) — every list is
// then honestly empty, never synthesized.
struct OfficeAttentionSnapshot {
	rows        []desktop.OfficeRunRow
	approvals   []desktop.OfficeApprovalItem
	completions []desktop.OfficeCompletion
	engine_live bool
	doctor_warns int
}

// office_attention_snapshot reads the Engine lists once per frame and
// projects them through the facade. Empty Engine lists stay empty.
fn office_attention_snapshot(mut app GuiApp) OfficeAttentionSnapshot {
	if app.desktop == unsafe { nil } {
		return OfficeAttentionSnapshot{}
	}
	jobs := app.desktop.engine_jobs_catalog()
	swarms := app.desktop.swarm_list()
	mut histories := []desktop_engine.LoopHistory{}
	for e in app.desktop.loops_catalog() {
		histories << app.desktop.engine_loop_history(e.name)
	}
	queue := app.desktop.engine_approvals_queue()
	live, _ := app.desktop.engine_process_supervisor_stats()
	rows := desktop.office_project_runs(jobs, swarms, histories, queue, live > 0)
	mut titles := map[string]string{}
	for s in swarms {
		titles[s.id] = if s.task.trim_space() != '' { s.task.trim_space() } else { s.id }
	}
	approvals := desktop.office_pending_approvals(queue, fn [titles] (run_id string) string {
		return titles[run_id] or { run_id }
	})
	completions := desktop.office_recent_completions(jobs, swarms, histories, 5)
	mut warns := 0
	for c in app.desktop.engine_doctor() {
		if c.status == 'warn' || c.status == 'fail' {
			warns++
		}
	}
	return OfficeAttentionSnapshot{
		rows: rows
		approvals: approvals
		completions: completions
		engine_live: true
		doctor_warns: warns
	}
}

// office_selected_row resolves the visible selected run from the existing
// cross-panel selection (jobs/swarm/loop index) revalidated against the
// projected rows, or -1. Loop rows match by template name; stale indices
// never select.
fn office_selected_row(app &GuiApp, rows []desktop.OfficeRunRow) int {
	for i, r in rows {
		if r.kind == 'job' && app.jobs_selected >= 0 && r.ref_idx == app.jobs_selected {
			return i
		}
		if r.kind == 'swarm' && app.swarm_selected >= 0 && r.ref_idx == app.swarm_selected {
			return i
		}
	}
	if app.selected_loop >= 0 && app.desktop != unsafe { nil } {
		loops := app.desktop.loops_catalog()
		if app.selected_loop < loops.len {
			for i, r in rows {
				if r.kind == 'loop' && r.loop_name == loops[app.selected_loop].name {
					return i
				}
			}
		}
	}
	return -1
}

// office_run_inspector_text renders the evidence drill-down line for a run:
// title, state, where it runs, what it does, and the first evidence facts.
fn office_run_inspector_text(row desktop.OfficeRunRow) string {
	mut parts := ['${row.title} — ${row.state.label()}']
	where := if row.workspace.trim_space() != '' { row.workspace } else { row.activity }
	if where.trim_space() != '' {
		parts << where.trim_space()
	}
	for e in row.evidence {
		if parts.len >= 5 {
			break
		}
		parts << e
	}
	return parts.join(' · ')
}

// office_approval_inspector_text renders an approval gate for the inspector.
// The gate resolves against the Engine queue; the record stays in the domain.
fn office_approval_inspector_text(item desktop.OfficeApprovalItem) string {
	cost := if item.budget_cost > 0 { ' · cost ${item.budget_cost}' } else { '' }
	return 'Approval ${item.kind} for ${item.run_title}: ${item.message}${cost}'
}

// office_completion_inspector_text renders completion evidence for the inspector.
fn office_completion_inspector_text(c desktop.OfficeCompletion) string {
	mut parts := ['${c.title} — ${c.detail}']
	for e in c.evidence {
		if parts.len >= 5 {
			break
		}
		parts << e
	}
	return parts.join(' · ')
}

// ── attention surface: layout (shared by draw and hit-testing) ─────────────

const office_run_row_h = 30
const office_line_h = 18
const office_act_h = 28

// OfficeAttentionLayout budgets the attention column top-down: runs first,
// then approvals, then completions. Caps shrink completions first so live
// work stays visible on short windows; a zero cap hides that section.
struct OfficeAttentionLayout {
	y0       int
	runs_cap int
	runs_h   int
	appr_y   int
	appr_cap int
	appr_h   int
	comp_y   int
	comp_cap int
	comp_h   int
	act_h    int
}

// office_attention_layout derives visible caps from the available height.
// Pure: draw and click share it, so hit areas always match painted rows.
fn office_attention_layout(y0 int, h int, nruns int, nappr int, ncomp int, sel_has_actions bool) OfficeAttentionLayout {
	act_h := if sel_has_actions { office_act_h } else { 0 }
	empty_pad := if nruns == 0 { 16 } else { 0 }
	mut runs_cap := if nruns < 4 { nruns } else { 4 }
	mut appr_cap := if nappr == 0 { 1 } else if nappr < 3 { nappr } else { 3 }
	mut comp_cap := if ncomp < 3 { ncomp } else { 3 }
	for {
		runs_h := 22 + runs_cap * office_run_row_h + act_h + empty_pad
		appr_h := 22 + appr_cap * office_line_h
		comp_h := if comp_cap == 0 { 0 } else { 22 + comp_cap * office_line_h }
		if runs_h + 10 + appr_h + 10 + comp_h <= h {
			break
		}
		if comp_cap > 0 {
			comp_cap--
			continue
		}
		if appr_cap > 1 {
			appr_cap--
			continue
		}
		if runs_cap > 0 {
			runs_cap--
			continue
		}
		break
	}
	runs_h := 22 + runs_cap * office_run_row_h + act_h + empty_pad
	appr_h := 22 + appr_cap * office_line_h
	comp_h := if comp_cap == 0 { 0 } else { 22 + comp_cap * office_line_h }
	appr_y := y0 + runs_h + 10
	comp_y := appr_y + appr_h + 10
	return OfficeAttentionLayout{
		y0: y0
		runs_cap: runs_cap
		runs_h: runs_h
		appr_y: appr_y
		appr_cap: appr_cap
		appr_h: appr_h
		comp_y: comp_y
		comp_cap: comp_cap
		comp_h: comp_h
		act_h: act_h
	}
}

// office_run_rect is the hit/draw rect of run row i (runs section).
fn office_run_rect(l OfficeLayout, y0 int, i int) (int, int, int, int) {
	return l.side_x + 4, y0 + 22 + i * office_run_row_h, l.side_w - 8, office_run_row_h - 2
}

// office_actions_y is the top of the selected-run action zone (runs section).
fn office_actions_y(y0 int, runs_cap int) int {
	return y0 + 22 + runs_cap * office_run_row_h + 2
}

// office_action_rect is the hit/draw rect of action button i of n.
fn office_action_rect(l OfficeLayout, ay int, i int, n int) (int, int, int, int) {
	gap := 6
	bw := (l.side_w - 8 - (n - 1) * gap) / n
	return l.side_x + 4 + i * (bw + gap), ay, bw, 22
}

// office_appr_rect is the hit/draw rect of approval line i.
fn office_appr_rect(l OfficeLayout, appr_y int, i int) (int, int, int, int) {
	return l.side_x + 4, appr_y + 22 + i * office_line_h, l.side_w - 8, office_line_h - 2
}

// office_comp_rect is the hit/draw rect of completion line i.
fn office_comp_rect(l OfficeLayout, comp_y int, i int) (int, int, int, int) {
	return l.side_x + 4, comp_y + 22 + i * office_line_h, l.side_w - 8, office_line_h - 2
}

// office_state_color maps the attention state to Paper Co. tokens:
// success = running, select = waiting on runtime or a human gate, brass =
// blocked, danger = failed, muted = idle/unknown.
fn office_state_color(app &GuiApp, s desktop.OfficeRunState) gg.Color {
	return match s {
		.running { app.pnl_success }
		.waiting { app.pnl_select }
		.needs_me { app.pnl_select }
		.blocked { col_brass }
		.failed { app.pnl_danger }
		else { app.pnl_text_mut }
	}
}

// office_draw_state_pill draws the run-state pill. Static paint only —
// reduced-motion equivalence is inherent (no animation path exists).
fn office_draw_state_pill(mut app GuiApp, x int, y int, s desktop.OfficeRunState, max_w int) {
	label := s.label()
	col := office_state_color(app, s)
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

// ── attention surface: draw ────────────────────────────────────────────────

// draw_office_attention paints the attention surface: live run rows with
// state pills, approvals projected over the Engine queue, and recent
// completions with evidence on click. Honest empties throughout; static
// paint only.
fn draw_office_attention(mut app GuiApp, l OfficeLayout, y0 int, h int, snap OfficeAttentionSnapshot) {
	x := l.side_x
	w := l.side_w
	if h < 60 {
		return
	}
	app.gg.draw_rect_filled(x + 2, y0 + 3, w, h, tint(col_ink, 14))
	app.gg.draw_rect_filled(x, y0, w, h, pc(app, `P`))
	app.gg.draw_rect_empty(x, y0, w, h, tint(pc(app, `W`), 70))
	app.gg.draw_text(x + 12, y0 + 8, 'Attention', gg.TextCfg{
		color: app.pnl_text
		size: 15
		family: app.fonts.display
	})
	if !snap.engine_live {
		app.gg.draw_text(x + 12, y0 + 32, 'Run state unavailable.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		app.gg.draw_text(x + 12, y0 + 48, 'Engine not connected.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		return
	}
	hot := snap.rows.filter(it.attention).len
	app.gg.draw_text(x + w - 12 - '${snap.rows.len} runs'.len * 7, y0 + 12, '${snap.rows.len} runs', gg.TextCfg{
		color: if hot > 0 { app.pnl_danger } else { app.pnl_text_mut }
		size: 11
	})
	sel := office_selected_row(app, snap.rows)
	sel_has_actions := sel >= 0 && desktop.office_run_actions(snap.rows[sel]).len > 0
	al := office_attention_layout(y0 + 30, h - 30, snap.rows.len, snap.approvals.len,
		snap.completions.len, sel_has_actions)
	ry := al.y0
	// runs section
	app.gg.draw_text(x + 12, ry, 'Live runs', gg.TextCfg{
		color: app.pnl_text
		size: 12
		bold: true
	})
	if snap.rows.len == 0 {
		app.gg.draw_text(x + 12, ry + 22, 'No runs recorded.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	} else {
		for i in 0 .. al.runs_cap {
			row := snap.rows[i]
			rx, ryy, rw, _ := office_run_rect(l, ry, i)
			if i == sel {
				app.gg.draw_rect_filled(rx - 2, ryy - 2, rw + 4, office_run_row_h + 2, tint(app.pnl_select, 60))
			}
			office_draw_state_pill(mut app, rx, ryy + 1, row.state, 96)
			title := utf8_truncate(row.title, text_fit_chars(rx + rw - rx - 108, 12))
			app.gg.draw_text(rx + 108, ryy + 1, title, gg.TextCfg{
				color: app.pnl_text
				size: 12
				bold: row.attention
			})
			mut sub := if row.workspace.trim_space() != '' { row.workspace } else { row.activity }
			if row.approval_id != '' {
				sub = 'approval ${row.approval_id} · ' + sub
			}
			app.gg.draw_text(rx + 108, ryy + 15, utf8_truncate(sub, text_fit_chars(rx + rw - rx - 108, 10)), gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
			})
		}
		if sel >= 0 && sel < al.runs_cap {
			acts := desktop.office_run_actions(snap.rows[sel])
			ay := office_actions_y(ry, al.runs_cap)
			for i, a in acts {
				ax, ab_y, aw, ah := office_action_rect(l, ay, i, acts.len)
				operations_button(mut app, ax, ab_y, aw, ah, a.label, false, a.primary,
					a.danger)
			}
		}
	}
	// approvals section: projection over the Engine queue
	app.gg.draw_text(x + 12, al.appr_y, 'Approvals (${snap.approvals.len})', gg.TextCfg{
		color: if snap.approvals.len > 0 { app.pnl_select } else { app.pnl_text }
		size: 12
		bold: true
	})
	if snap.approvals.len == 0 {
		app.gg.draw_text(x + 12, al.appr_y + 22, 'No pending approvals.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	} else {
		for i in 0 .. al.appr_cap {
			item := snap.approvals[i]
			_, ayy, _, _ := office_appr_rect(l, al.appr_y, i)
			line := utf8_truncate('${item.kind} · ${item.run_title}', text_fit_chars(w - 28, 11))
			app.gg.draw_text(x + 16, ayy, line, gg.TextCfg{
				color: app.pnl_text
				size: 11
			})
		}
	}
	// completions section
	if al.comp_cap > 0 {
		app.gg.draw_text(x + 12, al.comp_y, 'Recent', gg.TextCfg{
			color: app.pnl_text
			size: 12
			bold: true
		})
		if snap.completions.len == 0 {
			app.gg.draw_text(x + 12, al.comp_y + 22, 'No recent completions.', gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
		} else {
			for i in 0 .. al.comp_cap {
				c := snap.completions[i]
				_, cy, _, _ := office_comp_rect(l, al.comp_y, i)
				line := utf8_truncate('${c.title} · ${c.detail}', text_fit_chars(w - 28, 11))
				app.gg.draw_text(x + 16, cy, line, gg.TextCfg{
					color: app.pnl_text_mut
					size: 11
				})
			}
		}
	}
	if snap.doctor_warns > 0 && al.comp_y + al.comp_h + 18 < y0 + h {
		app.gg.draw_text(x + 12, al.comp_y + al.comp_h + 4, '${snap.doctor_warns} warnings — see Operations', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
	}
}

// ── attention surface: input ───────────────────────────────────────────────

// office_attention_click hit-tests the attention surface with the same layout
// the draw path uses. Run rows select their Engine record for the inspector,
// approval rows resolve to their run, completion rows drill evidence, and
// action buttons dispatch through the Engine. Only currently-valid actions
// are painted, so only they can fire.
fn office_attention_click(mut app GuiApp, l OfficeLayout, mx int, my int) bool {
	if app.desktop == unsafe { nil } {
		return false
	}
	roster_h := l.room_h * 40 / 100
	y0 := l.room_y + roster_h + 10
	ah := l.room_h - roster_h - 10
	if ah < 60 {
		return false
	}
	snap := office_attention_snapshot(mut app)
	sel := office_selected_row(app, snap.rows)
	sel_has_actions := sel >= 0 && desktop.office_run_actions(snap.rows[sel]).len > 0
	al := office_attention_layout(y0 + 30, ah - 30, snap.rows.len, snap.approvals.len,
		snap.completions.len, sel_has_actions)
	ry := al.y0
	// action buttons first (smallest targets, painted over the runs section)
	if sel >= 0 && sel < al.runs_cap {
		acts := desktop.office_run_actions(snap.rows[sel])
		ay := office_actions_y(ry, al.runs_cap)
		for i, a in acts {
			ax, ab_y, aw, ahh := office_action_rect(l, ay, i, acts.len)
			if rect_contains(mx, my, ax, ab_y, aw, ahh) {
				office_run_dispatch(mut app, snap.rows[sel], a.kind)
				return true
			}
		}
	}
	for i in 0 .. al.runs_cap {
		rx, ryy, rw, rh := office_run_rect(l, ry, i)
		if rect_contains(mx, my, rx, ryy, rw, rh) {
			office_select_run(mut app, snap.rows[i])
			return true
		}
	}
	for i in 0 .. al.appr_cap {
		if i >= snap.approvals.len {
			break
		}
		ax, ayy, aw, ahh := office_appr_rect(l, al.appr_y, i)
		if rect_contains(mx, my, ax, ayy, aw, ahh) {
			item := snap.approvals[i]
			for r in snap.rows {
				if r.kind == 'swarm' && r.id == item.run_id {
					office_select_run(mut app, r)
					app.inspector_msg = office_approval_inspector_text(item)
					return true
				}
			}
			app.inspector_msg = office_approval_inspector_text(item) + ' · run no longer listed'
			return true
		}
	}
	for i in 0 .. al.comp_cap {
		if i >= snap.completions.len {
			break
		}
		cx, cy, cw, ch := office_comp_rect(l, al.comp_y, i)
		if rect_contains(mx, my, cx, cy, cw, ch) {
			app.inspector_msg = office_completion_inspector_text(snap.completions[i])
			return true
		}
	}
	return false
}

// office_select_run maps a projected row back to the Engine record selection
// the Operations tabs share, and reports its evidence to the inspector.
fn office_select_run(mut app GuiApp, row desktop.OfficeRunRow) {
	match row.kind {
		'job' {
			app.jobs_selected = row.ref_idx
		}
		'swarm' {
			app.swarm_selected = row.ref_idx
		}
		'loop' {
			app.selected_loop = -1
			if app.desktop != unsafe { nil } {
				for li, e in app.desktop.loops_catalog() {
					if e.name == row.loop_name {
						app.selected_loop = li
						break
					}
				}
			}
		}
		else {}
	}
	app.inspector_msg = office_run_inspector_text(row)
	hint := desktop.office_no_actions_hint(row)
	if hint != '' {
		app.inspector_msg += ' · ' + hint
	}
}

// office_run_dispatch executes a valid attention action through the Engine
// and reports the actual outcome. Failures are shown as failures.
fn office_run_dispatch(mut app GuiApp, row desktop.OfficeRunRow, kind string) {
	if app.desktop == unsafe { nil } {
		return
	}
	match kind {
		'cancel' {
			rev := app.desktop.engine_cancel_job(row.id) or {
				app.inspector_msg = 'Job cancel failed: ${err.msg()}'
				return
			}
			app.engine_rev = rev
			app.api_calls = app.desktop.engine_api_calls()
			app.inspector_msg = 'Job canceled: ${row.id} (rev ${rev})'
		}
		'retry' {
			new_id := app.desktop.engine_retry_job(row.id) or {
				app.inspector_msg = 'Job retry failed: ${err.msg()}'
				return
			}
			app.api_calls = app.desktop.engine_api_calls()
			app.inspector_msg = 'Job retried: ${row.id} → ${new_id}'
		}
		'approve' {
			rev := app.desktop.swarm_approve(row.id, row.approval_id, true) or {
				app.inspector_msg = 'Approval ${row.approval_id} failed: ${err.msg()}'
				return
			}
			app.engine_rev = rev
			app.inspector_msg = 'Approved ${row.approval_id} (rev ${rev})'
		}
		'reject' {
			rev := app.desktop.swarm_approve(row.id, row.approval_id, false) or {
				app.inspector_msg = 'Approval ${row.approval_id} failed: ${err.msg()}'
				return
			}
			app.engine_rev = rev
			app.inspector_msg = 'Rejected ${row.approval_id} (rev ${rev})'
		}
		'run' {
			job_id := app.desktop.loop_run(row.loop_name) or {
				app.inspector_msg = 'Loop run failed: ${err.msg()}'
				return
			}
			app.api_calls = app.desktop.engine_api_calls()
			app.inspector_msg = 'Loop started: ${row.loop_name} → ${job_id}'
		}
		else {}
	}
}
