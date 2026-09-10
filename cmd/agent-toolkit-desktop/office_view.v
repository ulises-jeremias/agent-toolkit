module main

import gg
import desktop.pixelart
import desktop_engine

// VC8 (#1173) — Office overview refinement against office.jpg.
//
// The room itself is the VC3.5-locked composition (office_room.v). This
// file adds the surrounding operational UI the reference shows around it:
// four metric cards across the top, and — to the right of the room — an
// Agent Roster and a Today column. Every number is real Engine state; on an
// idle machine the cards read 0 with honest sub-lines, the roster shows the
// catalog agents idle (catalog ≠ runtime), and Today shows truthful pending
// items derived from real records (attention jobs, doctor warnings,
// onboarding pending) — never invented approvals or activity.

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
			app.gg.draw_text(tx, cy + ch - 18, utf8_truncate(m.sub, onb_fit(cx + cw - tx - 8, 11)), gg.TextCfg{
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
		app.gg.draw_text(x + 44, ry + 1, utf8_truncate(agent_entry.id, onb_fit(w - 120, 12)), gg.TextCfg{
			color: app.pnl_text
			size: 12
			bold: true
		})
		role := if agent_entry.role == '' { agent_entry.tier } else { agent_entry.role }
		app.gg.draw_text(x + 44, ry + 16, utf8_truncate(role, onb_fit(w - 60, 10)), gg.TextCfg{
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

// draw_office_today shows truthful pending work: attention jobs, doctor
// warnings and onboarding pending items. Empty means genuinely nothing.
fn draw_office_today(mut app GuiApp, l OfficeLayout, attention []desktop_engine.JobRecord, y0 int, h int) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	x := l.side_x
	w := l.side_w
	app.gg.draw_rect_filled(x + 2, y0 + 3, w, h, tint(col_ink, 14))
	app.gg.draw_rect_filled(x, y0, w, h, pc(app, `P`))
	app.gg.draw_rect_empty(x, y0, w, h, tint(pc(app, `W`), 70))
	app.gg.draw_text(x + 12, y0 + 8, 'Today', gg.TextCfg{
		color: app.pnl_text
		size: 15
		family: app.fonts.display
	})
	now := ui_now()
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	mname := if now.month >= 1 && now.month <= 12 { months[now.month - 1] } else { '' }
	stamp := '${mname} ${now.day}'
	app.gg.draw_text(x + w - 12 - stamp.len * 7, y0 + 12, stamp, gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
	})
	mut ry := y0 + 34
	// attention jobs (failed/queued) — real records
	if attention.len > 0 {
		app.gg.draw_text(x + 12, ry, 'Attention (${attention.len})', gg.TextCfg{
			color: pc(app, `a`)
			size: 12
			bold: true
		})
		ry += 18
		for j in attention {
			if ry + 16 > y0 + h - 8 {
				break
			}
			app.gg.draw_text(x + 16, ry, utf8_truncate('${j.status} · ${j.id}', onb_fit(w - 28, 11)), gg.TextCfg{
				color: app.pnl_text
				size: 11
			})
			ry += 16
		}
		ry += 6
	}
	// doctor warnings — real checks
	mut warns := 0
	mut first_warn := ''
	if app.desktop != unsafe { nil } {
		for c in app.desktop.engine_doctor() {
			if c.status == 'warn' || c.status == 'fail' {
				warns++
				if first_warn == '' {
					first_warn = c.name
				}
			}
		}
	}
	if warns > 0 && ry + 34 < y0 + h {
		app.gg.draw_text(x + 12, ry, 'Warnings (${warns})', gg.TextCfg{
			color: app.pnl_select
			size: 12
			bold: true
		})
		ry += 18
		app.gg.draw_text(x + 16, ry, utf8_truncate('${first_warn} — see Operations', onb_fit(w - 28, 11)), gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
		ry += 22
	}
	// recommended next steps — derived from real onboarding pending items
	has_desktop := app.desktop != unsafe { nil }
	mut pending_items := []string{}
	if has_desktop {
		pending_items = app.desktop.onboarding_status(app.harness_root).pending_items.clone()
	}
	if ry + 40 < y0 + h {
		app.gg.draw_text(x + 12, ry, 'Workspace setup', gg.TextCfg{
			color: app.pnl_text
			size: 12
			bold: true
		})
		ry += 18
		for s in pending_items {
			if ry + 16 > y0 + h - 8 {
				break
			}
			app.gg.draw_rect_empty(x + 16, ry + 2, 10, 10, app.pnl_border_hi)
			app.gg.draw_text(x + 32, ry, utf8_truncate(s, onb_fit(w - 44, 11)), gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
			ry += 16
		}
		if !has_desktop && ry + 16 <= y0 + h - 8 {
			app.gg.draw_text(x + 16, ry, 'Setup state unavailable.', gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
		} else if pending_items.len == 0 && ry + 16 <= y0 + h - 8 {
			app.gg.draw_text(x + 16, ry, 'No onboarding steps pending.', gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
		}
	}
	if attention.len == 0 && warns == 0 && ry + 30 < y0 + h {
		// quiet day: a small scene instead of an empty box
		plant := pixelart.environment_for(.plant)
		tray := pixelart.environment_for(.tray)
		sc.draw(tray, pid, x + w / 2 - tray.width() - 6, y0 + h - 12 - tray.height() * 2, 2)
		sc.draw(plant, pid, x + w / 2 + 6, y0 + h - 12 - plant.height() * 2, 2)
	}
}

fn draw_office_detail(mut app GuiApp, w int, h int) {
	l := office_detail_layout(app, w, h)
	ix := inspector_x(app, w)
	iy := l.room_y - 4
	ih := content_bottom(app, h) - iy
	app.gg.draw_rect_filled(ix, iy, inspector_w, ih, app.pnl_card)
	app.gg.draw_line(ix, iy, ix, iy + ih, app.pnl_border)
	mut agents := []desktop_engine.AgentEntry{}
	mut attention := []desktop_engine.JobRecord{}
	if app.desktop != unsafe { nil } {
		agents = app.desktop.engine_agents_search('', '')
		attention = app.desktop.engine_jobs_catalog().filter(it.status == .failed || it.status == .queued)
	}
	roster_h := l.room_h * 52 / 100
	draw_office_roster(mut app, l, agents, l.room_y, roster_h)
	draw_office_today(mut app, l, attention, l.room_y + roster_h + 10, l.room_h - roster_h - 10)
}

// office_roster_click selects the corresponding floor desk only when the real
// catalog ID is represented there. Otherwise it leaves selection empty and
// reports the catalog record without inventing a room mapping.
fn office_roster_click(mut app GuiApp, mx int, my int, w int, h int) bool {
	if app.desktop == unsafe { nil } {
		return false
	}
	l := office_detail_layout(app, w, h)
	roster_h := l.room_h * 52 / 100
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
	return false
}
