module main

import desktop.pixelart
import gg

// VC3 Office room (#1172) — the flagship visual composition for the Office
// overview. Truth comes from desks_for_app (catalog identity) and Engine job
// counts (attention/running, passed in by the caller); this file owns only
// visual composition. Static first: no walking, no bobbing, no ambient
// motion. The room is presentational — selection/hit-testing stays in the
// floor-map view, which keeps its own geometry.

// office_palette_id maps product appearance to the authored pixel-art palette
// variant. Both variants are hand-authored; never an automatic inversion.
fn office_palette_id(app &GuiApp) pixelart.PaletteId {
	return if app.appearance_dark { pixelart.PaletteId.ink } else { pixelart.PaletteId.paper }
}

// ensure_pixel_cache lazily creates the sprite cache on first draw (frame
// time, when sokol is ready) rather than in on_init (which runs before it).
fn ensure_pixel_cache(mut app GuiApp) {
	if app.pixel_cache == unsafe { nil } {
		app.pixel_cache = pixelart.new_sprite_cache(app.gg)
	}
}

// pc resolves a pixelart palette key into a room-surface gg.Color, so floor
// and wall materials follow the authored Paper/Ink variants automatically.
fn pc(app &GuiApp, k u8) gg.Color {
	c := app.pixel_cache.palette(office_palette_id(app)).rgba(k)
	return gg.Color{
		r: c[0]
		g: c[1]
		b: c[2]
		a: 255
	}
}

// draw_office_room composes the pixel-art office inside (x, y, w, h):
// wall band with shelf / attention board / windows / filing cabinet, wood
// plank floor, meeting zone (rug, table, chairs, lamp, tray), and a desk
// grid for catalog workstations with idle agents. attention/running are real
// Engine counts — idle rooms never look busy. The caller passes all catalog
// desks; the grid shows what fits and the overflow is reported honestly.
fn draw_office_room(mut app GuiApp, x int, y int, w int, h int, desks []Desk, attention int, running int) {
	ensure_pixel_cache(mut app)
	pid := office_palette_id(app)
	sc := app.pixel_cache
	s := if w < 560 { 2 } else { 3 }

	// ── surfaces: wall band + wood plank floor ──────────────────────────
	wall_h := 16 * s + 12
	wall_col := mix(pc(app, `p`), pc(app, `m`), 0.30)
	// Floor material follows the authored palette: warm tan on Paper; on Ink
	// a neutral dark well so wood furniture stays legible (never invisible).
	ink := app.appearance_dark
	floor_col := if ink { mix(pc(app, `S`), pc(app, `w`), 0.22) } else { mix(pc(app, `w`), pc(app, `p`), 0.62) }
	seam_col := if ink { mix(floor_col, pc(app, `k`), 0.40) } else { mix(pc(app, `W`), floor_col, 0.50) }
	app.gg.draw_rect_filled(x, y, w, h, floor_col)
	app.gg.draw_rect_filled(x, y, w, wall_h, wall_col)
	app.gg.draw_rect_filled(x, y + wall_h - 4, w, 4, pc(app, `W`))
	// plank seams: horizontal rows with staggered vertical joints,
	// deterministic geometry (no random texture regenerated per frame).
	prow := 6 * s
	mut py := y + wall_h + prow
	mut row_i := 0
	for py < y + h {
		app.gg.draw_rect_filled(x, py, w, 1, seam_col)
		mut jx := x + if row_i % 2 == 0 { 0 } else { 13 * s }
		for jx < x + w {
			app.gg.draw_rect_filled(jx, py - prow + 1, 1, prow - 1, seam_col)
			jx += 26 * s
		}
		py += prow
		row_i++
	}
	// south baseboard — the room's bottom boundary; props can sit against it
	app.gg.draw_rect_filled(x, y + h - 4, w, 4, pc(app, `W`))

	// ── wall furniture: stands on the baseboard ─────────────────────────
	base := y + wall_h - 4
	shelf := pixelart.environment_for(.shelf)
	board := pixelart.environment_for(.board)
	window := pixelart.environment_for(.window)
	cabinet := pixelart.environment_for(.cabinet)
	plant := pixelart.environment_for(.plant)
	mut wx := x + 12
	sc.draw(shelf, pid, wx, base - shelf.height() * s, s)
	app.gg.draw_text(wx, base + 12, 'library', gg.TextCfg{
		color: app.pnl_text_mut
		size:  10
	})
	wx += shelf.width() * s + 8 * s
	sc.draw(board, pid, wx, base - board.height() * s, s)
	att := if attention == 0 { 'clear' } else { '${attention} open' }
	app.gg.draw_text(wx, base + 12, 'board · ${att}', gg.TextCfg{
		color: if attention == 0 { app.pnl_text_mut } else { app.pnl_select }
		size:  10
		bold:  attention > 0
	})
	wx += board.width() * s + 10 * s
	// up to three windows; a long identical strip reads institutional
	archive := pixelart.environment_for(.shelf)
	mut wins := 0
	if w >= 820 {
		for wins < 3 && wx + window.width() * s < x + w - cabinet.width() * s - 20 {
			sc.draw(window, pid, wx, base - window.height() * s, s)
			wx += window.width() * s + 6 * s
			wins++
		}
	}
	cab_x := x + w - 12 - cabinet.width() * s
	// archive bookshelf + plant dress the remaining wall stretch
	if w >= 1000 && wx + archive.width() * s + plant.width() * s < cab_x - 16 {
		sc.draw(archive, pid, wx, base - archive.height() * s, s)
		app.gg.draw_text(wx, base + 12, 'archive', gg.TextCfg{
			color: app.pnl_text_mut
			size:  10
		})
		wx += archive.width() * s + 6 * s
	}
	if cab_x - wx > plant.width() * s + 16 {
		sc.draw(plant, pid, cab_x - plant.width() * s - 8, base - plant.height() * s, s)
	}
	sc.draw(cabinet, pid, cab_x, base - cabinet.height() * s, s)
	app.gg.draw_text(cab_x - 14, base + 12, 'filing', gg.TextCfg{
		color: app.pnl_text_mut
		size:  10
	})

	// ── meeting zone (left): table flanked by chairs, on open floor ─────
	floor_y := y + wall_h
	mz_w := 40 * s
	mz_cx := x + 16 + mz_w / 2
	table := pixelart.environment_for(.meeting_table)
	chair := pixelart.environment_for(.chair)
	lamp := pixelart.environment_for(.lamp)
	tray := pixelart.environment_for(.tray)
	rug := pixelart.environment_for(.rug)
	table_y := floor_y + 12 * s
	if table_y + table.height() * s + chair.height() * s + 30 < y + h {
		tw := table.width() * s
		sc.draw(table, pid, mz_cx - tw / 2, table_y, s)
		sc.draw(chair, pid, mz_cx - chair.width() * s / 2, table_y - chair.height() * s - 2, s)
		sc.draw(chair, pid, mz_cx - chair.width() * s / 2, table_y + table.height() * s + 2, s)
		sc.draw(chair, pid, mz_cx - tw / 2 - chair.width() * s - 2, table_y + 2, s)
		sc.draw(chair, pid, mz_cx + tw / 2 + 2, table_y + 2, s)
		app.gg.draw_text(x + 16, table_y + table.height() * s + chair.height() * s + 16, 'meeting', gg.TextCfg{
			color: app.pnl_text_mut
			size:  10
		})
	}
	// lounge rug + floor plant in the lower-left corner
	rug_y := y + h - rug.height() * s - 30
	if rug_y > table_y + table.height() * s + chair.height() * s + 26 {
		sc.draw(rug, pid, x + 16, rug_y, s)
		sc.draw(chair, pid, x + 16 + rug.width() * s + 8, rug_y + 2, s)
		app.gg.draw_text(x + 16, rug_y + rug.height() * s + 12, 'lounge', gg.TextCfg{
			color: app.pnl_text_mut
			size:  10
		})
	}
	// inbox tray + lamp along the bottom edge, left of the desk grid
	by := y + h - lamp.height() * s - 8
	sc.draw(lamp, pid, x + 16 + rug.width() * s + 8 + chair.width() * s + 20, by, s)
	sc.draw(tray, pid, x + 16 + rug.width() * s + 8 + chair.width() * s + 20 + lamp.width() * s + 14, by + 4, s)
	app.gg.draw_text(x + 28 + rug.width() * s + chair.width() * s + lamp.width() * s + tray.width() * s + 34, by + 12, 'inbox', gg.TextCfg{
		color: app.pnl_text_mut
		size:  10
	})

	// ── workstation grid (right): desk + terminal + papers + chair ──────
	ws_x := x + 16 + mz_w + 20
	ws_w := x + w - 16 - ws_x
	if ws_w < 40 * s || desks.len == 0 {
		return
	}
	desk := pixelart.environment_for(.desk)
	term := pixelart.environment_for(.terminal)
	dw := desk.width() * s
	aw := pixelart.agent_for_state(.idle).width() * s
	ah := pixelart.agent_for_state(.idle).height() * s
	chw := chair.width() * s
	chh := chair.height() * s
	mut cell_w := 34 * s
	cell_h := 42 * s
	avail_h := y + h - 12 - (floor_y + 8 * s)
	// Row-first sizing: fill the vertical space first, then pick the column
	// count that fits every catalog desk (fewer dead zones than a fixed grid).
	mut rows := avail_h / cell_h
	rows = if rows < 1 { 1 } else if rows > 4 { 4 } else { rows }
	mut cols := (desks.len + rows - 1) / rows
	max_cols := ws_w / (26 * s)
	cols = if cols < 2 { 2 } else if cols > 6 { 6 } else { cols }
	if cols > max_cols {
		cols = if max_cols < 2 { 2 } else { max_cols }
	}
	if w < 560 {
		cols = 2
	}
	cell_w = ws_w / cols
	shown := if desks.len < cols * rows { desks.len } else { cols * rows }
	grid_x := ws_x + (ws_w - cols * cell_w) / 2
	for i in 0 .. shown {
		col := i % cols
		row := i / cols
		cx := grid_x + col * cell_w + (cell_w - dw) / 2
		cy := floor_y + 8 * s + row * cell_h
		if cy + cell_h > y + h - 10 {
			break
		}
		// Idle catalog agent behind the desk, deterministic identity variant.
		agent := pixelart.with_identity(pixelart.agent_for_state(.idle), i % 3)
		sc.draw(agent, pid, cx + (dw - aw) / 2, cy, s)
		desk_y := cy + ah - 4
		sc.draw(desk, pid, cx, desk_y, s)
		sc.draw(term, pid, cx + (dw - term.width() * s) / 2, desk_y + 2, s)
		// paper stacks on the desk surface (vector, part of the desk dressing)
		app.gg.draw_rect_filled(cx + 4, desk_y + 3, 2 * s, 3 * s, pc(app, `P`))
		app.gg.draw_rect_filled(cx + 5, desk_y + 4, 2 * s, 3 * s, pc(app, `e`))
		sc.draw(chair, pid, cx + (dw - chw) / 2, desk_y + desk.height() * s + 2, s)
		app.gg.draw_text(cx, cy + cell_h - 12, desks[i].label, gg.TextCfg{
			color: app.pnl_text_mut
			size:  10
			mono:  true
		})
	}
	// ── honest totals: bottom corners ────────────────────────────────────
	if running > 0 {
		app.gg.draw_text(x + 14, y + h - 16, '${running} running — see Operations', gg.TextCfg{
			color: app.pnl_select
			size:  10
		})
	}
	if desks.len > shown {
		app.gg.draw_text(x + w - 190, y + h - 16, '${shown} of ${desks.len} catalog desks', gg.TextCfg{
			color: app.pnl_text_mut
			size:  10
		})
	} else {
		app.gg.draw_text(x + w - 150, y + h - 16, '${shown} catalog desks', gg.TextCfg{
			color: app.pnl_text_mut
			size:  10
		})
	}
}
