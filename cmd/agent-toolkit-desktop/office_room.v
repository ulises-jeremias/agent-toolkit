module main

import desktop.pixelart
import gg

// Office room — the flagship visual composition for the Office
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

// zone_plate draws a small mounted sign behind a zone label:
// cream paper plate with a wood frame, deterministic, no per-frame variation.
fn zone_plate(mut app GuiApp, gx int, gy int, txt string, txt_col gg.Color) {
	pw := txt.len * 7 + 12
	app.gg.draw_rect_filled(gx - 3, gy - 3, pw, 15, pc(app, `p`))
	app.gg.draw_rect_empty(gx - 3, gy - 3, pw, 15, pc(app, `W`))
	app.gg.draw_text(gx + 3, gy, txt, gg.TextCfg{
		color: txt_col
		size: 10
	})
}

// draw_office_room composes the pixel-art office inside (x, y, w, h):
// wall band (shelf, attention board, windows, door, archive, filing), wood
// plank floor with zone rugs, meeting zone, lounge corner, and clustered
// workstations for catalog desks with idle agents. attention/running are
// real Engine counts — idle rooms never look busy. The caller passes all
// catalog desks; the grid shows what fits and the overflow is reported
// honestly (footer counts desks actually drawn).
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
	// subtle plank rhythm: alternate rows pull one step toward paper/wood
	floor_col_hi := if ink {
		mix(floor_col, pc(app, `w`), 0.10)
	} else {
		mix(floor_col, pc(app, `p`), 0.22)
	}
	app.gg.draw_rect_filled(x, y, w, h, floor_col)
	app.gg.draw_rect_filled(x, y, w, wall_h, wall_col)
	app.gg.draw_rect_filled(x, y, w, 2, seam_col) // top trim — wall edge
	app.gg.draw_rect_filled(x, y + wall_h - 4, w, 4, pc(app, `W`))
	// plank seams: horizontal rows with staggered vertical joints,
	// deterministic geometry (no random texture regenerated per frame).
	// Alternate rows pull one step toward paper/wood for subtle rhythm.
	ph := 6 * s
	mut py := y + wall_h + ph
	mut row_i := 0
	for py < y + h {
		if row_i % 2 == 1 {
			app.gg.draw_rect_filled(x, py - ph, w, ph, floor_col_hi)
		}
		app.gg.draw_rect_filled(x, py, w, 1, seam_col)
		mut jx := x + if row_i % 2 == 0 { 0 } else { 13 * s }
		for jx < x + w {
			app.gg.draw_rect_filled(jx, py - ph + 1, 1, ph - 1, seam_col)
			jx += 26 * s
		}
		py += ph
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
	door := pixelart.environment_for(.door)
	mut wx := x + 12
	sc.draw(shelf, pid, wx, base - shelf.height() * s, s)
	zone_plate(mut app, wx, base + 14, 'library', app.pnl_text_mut)
	// wall gaps breathe at very wide widths so the band keeps dressing
	// the whole wall instead of bunching near the left edge
	wall_gap := if w >= 900 { 12 * s } else { 6 * s }
	wx += shelf.width() * s + 8 * s
	sc.draw(board, pid, wx, base - board.height() * s, s)
	att := if attention == 0 { 'clear' } else { '${attention} open' }
	zone_plate(mut app, wx, base + 14, 'board · ${att}', if attention == 0 {
		app.pnl_text_mut
	} else {
		app.pnl_select
	})
	wx += board.width() * s + 10 * s
	// up to two windows (three at very wide widths); a long identical
	// strip reads institutional, but a bare wall reads abandoned
	if w >= 560 {
		max_wins := if w >= 900 { 3 } else { 2 }
		mut wins := 0
		for wins < max_wins && wx + window.width() * s < x + w - door.width() * s - cabinet.width() * s - 40 {
			sc.draw(window, pid, wx, base - window.height() * s, s)
			wx += window.width() * s + wall_gap
			wins++
		}
	}
	cab_x := x + w - 12 - cabinet.width() * s
	// door + archive bookshelf dress the remaining wall stretch
	if w >= 640 && wx + door.width() * s + 14 * s < cab_x - 12 {
		sc.draw(door, pid, wx, base - door.height() * s, s)
		wx += door.width() * s + wall_gap
	}
	archive := pixelart.environment_for(.shelf)
	if w >= 700 && wx + archive.width() * s + plant.width() * s < cab_x - 16 {
		sc.draw(archive, pid, wx, base - archive.height() * s, s)
		zone_plate(mut app, wx, base + 14, 'archive', app.pnl_text_mut)
		wx += archive.width() * s + wall_gap
	}
	// framed standing poster dresses a long bare wall stretch
	// (deterministic vector — frame, mat, and three text lines)
	stretch := cab_x - wx
	if stretch > 40 * s {
		poster_w := 16 * s
		poster_h := 12 * s
		px := wx + (stretch - poster_w) / 2
		app.gg.draw_rect_filled(px, base - poster_h, poster_w, poster_h, pc(app, `p`))
		app.gg.draw_rect_empty(px, base - poster_h, poster_w, poster_h, pc(app, `W`))
		app.gg.draw_rect_filled(px + 2 * s, base - poster_h + 2 * s, poster_w - 4 * s, 1, pc(app, `M`))
		app.gg.draw_rect_filled(px + 2 * s, base - poster_h + 4 * s, poster_w - 6 * s, 1, pc(app, `M`))
		app.gg.draw_rect_filled(px + 2 * s, base - poster_h + 6 * s, poster_w - 4 * s, 1, pc(app, `M`))
	}
	if cab_x - wx > plant.width() * s + 16 {
		sc.draw(plant, pid, cab_x - plant.width() * s - 8, base - plant.height() * s, s)
	}
	sc.draw(cabinet, pid, cab_x, base - cabinet.height() * s, s)
	zone_plate(mut app, cab_x - 14, base + 14, 'filing', app.pnl_text_mut)

	// ── meeting zone (left): rug-anchored table with chairs ─────────────
	floor_y := y + wall_h
	mz_w := 44 * s
	mz_cx := x + 16 + mz_w / 2
	table := pixelart.environment_for(.meeting_table)
	chair := pixelart.environment_for(.chair)
	lamp := pixelart.environment_for(.lamp)
	tray := pixelart.environment_for(.tray)
	rug := pixelart.environment_for(.rug)
	table_y := floor_y + 12 * s
	if table_y + table.height() * s + chair.height() * s + 30 < y + h {
		tw := table.width() * s
		// rug under the table anchors the zone (only peeks at the edges)
		sc.draw(rug, pid, mz_cx - rug.width() * s / 2, table_y + 2, s)
		sc.draw(table, pid, mz_cx - tw / 2, table_y, s)
		sc.draw(chair, pid, mz_cx - chair.width() * s / 2, table_y - chair.height() * s - 2, s)
		sc.draw(chair, pid, mz_cx - chair.width() * s / 2, table_y + table.height() * s + 2, s)
		sc.draw(chair, pid, mz_cx - tw / 2 - chair.width() * s - 2, table_y + 2, s)
		sc.draw(chair, pid, mz_cx + tw / 2 + 2, table_y + 2, s)
		zone_plate(mut app, x + 16, table_y + table.height() * s + chair.height() * s + 18, 'meeting', app.pnl_text_mut)
	}
	// inbox tray + lamp against the south wall, left of the lounge
	by := y + h - tray.height() * s - 14
	sc.draw(tray, pid, x + 20, by, s)
	zone_plate(mut app, x + 32 + tray.width() * s, by + 8, 'inbox', app.pnl_text_mut)
	lamp_y := by - lamp.height() * s - 6
	if lamp_y > table_y {
		sc.draw(lamp, pid, x + 20, lamp_y, s)
	}

	// ── workstation clusters (right): paired desks with aisles ──────────
	workspace_x := x + 16 + mz_w + 20
	couch := pixelart.environment_for(.couch)
	// lounge geometry is computed first so the desk grid can keep clear of
	// the couch corner both vertically (avail_h) and horizontally (workspace_w)
	lounge_w := couch.width() * s + rug.width() * s + 20
	lounge_x := x + w - 16 - lounge_w
	lounge_y := y + h - couch.height() * s - 12
	lounge_ok := w >= 620 && lounge_x > workspace_x && lounge_y > table_y + table.height() * s
	workspace_w := x + w - 16 - workspace_x - if lounge_ok { lounge_w - 8 } else { 0 }
	if workspace_w < 40 * s || desks.len == 0 {
		return
	}
	desk := pixelart.environment_for(.desk)
	term := pixelart.environment_for(.terminal)
	dw := desk.width() * s
	aw := pixelart.agent_for_state(.idle).width() * s
	ah := pixelart.agent_for_state(.idle).height() * s
	chw := chair.width() * s
	chh := chair.height() * s
	cell_h := 42 * s
	// lounge reserve: the couch corner keeps the bottom band clear of desks
	// The lounge is already excluded horizontally by workspace_w. Reserving it a
	// second time vertically reduced a tall room to one sparse desk row.
	lounge_h := 0
	avail_h := y + h - 12 - lounge_h - (floor_y + 8 * s)
	// Row-first sizing: fill the vertical space first, then pick the cluster
	// count that fits every catalog desk (fewer dead zones than a fixed grid).
	mut rows := avail_h / cell_h
	rows = if rows < 1 {
		1
	} else if rows > 4 { 4 } else { rows }
	// clusters of two paired desks; aisles between clusters give rhythm
	pod_w := 2 * dw + 4
	// wide rooms breathe: wider aisles keep clusters from huddling left
	aisle := if w >= 900 { 18 * s } else { 12 * s }
	mut pods_per_row := (workspace_w + aisle) / (pod_w + aisle)
	pods_per_row = if pods_per_row < 1 {
		1
	} else if pods_per_row > 3 { 3 } else { pods_per_row }
	if w < 560 {
		pods_per_row = 1
	}
	pods := pods_per_row * rows
	capacity := if desks.len < pods * 2 { desks.len } else { pods * 2 }
	total_w := pods_per_row * pod_w + (pods_per_row - 1) * aisle
	grid_x := workspace_x + (workspace_w - total_w) / 2
	// vertical breathing: spread the pod rows across the available floor
	// and center the block, so large rooms read composed instead of like
	// a small grid floating in empty space
	used_rows := ((capacity + 1) / 2 + pods_per_row - 1) / pods_per_row
	mut step := cell_h
	if used_rows > 0 {
		fit := avail_h / used_rows
		step = if fit > cell_h * 2 {
			cell_h * 2
		} else if fit > cell_h { fit } else { cell_h }
	}
	gy_extra := avail_h - used_rows * step
	grid_y := floor_y + 8 * s + if gy_extra > 0 { gy_extra / 2 } else { 0 }
	// shown counts desks actually drawn — the loop can stop early when a
	// row would not fit, and the footer must never overstate (honest totals).
	mut shown := 0
	for i in 0 .. capacity {
		pod := i / 2
		prow := pod / pods_per_row
		pcol := pod % pods_per_row
		inpod := i % 2
		cy := grid_y + prow * step
		if cy + cell_h > y + h - 10 {
			break
		}
		// subtle aisle rhythm: odd rows shift half a cluster when it fits
		mut shift := if prow % 2 == 1 { (pod_w + aisle) / 3 } else { 0 }
		max_shift := x + w - 16 - pod_w - grid_x - pcol * (pod_w + aisle)
		if shift > max_shift {
			shift = if max_shift > 0 { max_shift } else { 0 }
		}
		cx := grid_x + pcol * (pod_w + aisle) + shift + inpod * (dw + 4)
		if inpod == 0 {
			// Each paired pod sits on a woven rug with a plant at the aisle.
			// These are room materials, not runtime signals.
			rug_s := if s >= 3 { 3 } else { 2 }
			rug_x := cx + pod_w / 2 - rug.width() * rug_s / 2
			sc.draw(rug, pid, rug_x, cy + ah + 4, rug_s)
			if pcol > 0 {
				sc.draw(plant, pid, cx - plant.width() * 2 - 6, cy + ah - plant.height() * 2 / 2, 2)
			}
		}
		// Idle catalog agent behind the desk, deterministic identity variant.
		agent := pixelart.with_identity(pixelart.agent_for_state(.idle), i % 3)
		sc.draw(agent, pid, cx + (dw - aw) / 2, cy, s)
		desk_y := cy + ah - 4
		sc.draw(desk, pid, cx, desk_y, s)
		sc.draw(term, pid, cx + (dw - term.width() * s) / 2, desk_y + 2, s)
		// desk dressing: manila folder or paper stack, deterministic
		if i % 2 == 0 {
			app.gg.draw_rect_filled(cx + 4, desk_y + 3, 2 * s, 3 * s, pc(app, `P`))
			app.gg.draw_rect_filled(cx + 5, desk_y + 4, 2 * s, 3 * s, pc(app, `e`))
		} else {
			app.gg.draw_rect_filled(cx + 4, desk_y + 3, 3 * s, 2 * s, pc(app, `m`))
			app.gg.draw_rect_filled(cx + 4, desk_y + 3, 3 * s, 1, pc(app, `M`))
		}
		chair_y := desk_y + desk.height() * s + 2
		sc.draw(chair, pid, cx + (dw - chw) / 2, chair_y, s)
		// the label belongs to its own pod: anchor it under the chair, not
		// at the row pitch (which drifts against the next row when the
		// rows breathe apart on tall floors)
		// clipped to the desk footprint: long catalog ids used to run into
		// the neighbouring pod's label
		max_chars := (dw + 2) / 6
		mut lbl := desks[i].label
		if max_chars > 1 && lbl.len > max_chars {
			lbl = lbl[..max_chars - 1] + '…'
		}
		app.gg.draw_text(cx, chair_y + chh + 4, lbl, gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
			mono: true
		})
		shown++
	}
	// ── honest totals: bottom corners ────────────────────────────────────
	if running > 0 {
		app.gg.draw_text(x + 14, y + h - 16, '${running} running — see Operations', gg.TextCfg{
			color: app.pnl_select
			size: 10
		})
	}
	// footer note keeps clear of the lounge corner (geometry computed above)
	note := if desks.len > shown {
		'${shown} of ${desks.len} catalog desks'
	} else {
		'${shown} catalog desks'
	}
	note_x := x + w - 24 - note.len * 7 - if lounge_ok { lounge_w - 8 } else { 0 }
	app.gg.draw_text(note_x, y + h - 16, note, gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
	})

	// ── lounge corner (bottom-right): couch on a rug, plant behind ──────
	if lounge_ok {
		// rug under the couch anchors the corner; plant at the rug's edge
		rug_x := lounge_x + 6
		sc.draw(rug, pid, rug_x, lounge_y - 3, s)
		sc.draw(couch, pid, rug_x + (rug.width() * s - couch.width() * s) / 2, lounge_y, s)
		plant_lx := rug_x + rug.width() * s + 4
		sc.draw(plant, pid, plant_lx, lounge_y - plant.height() * s + 6, s)
		// the sign hangs above the couch: below it would fall outside the
		// room, behind the south baseboard
		zone_plate(mut app, rug_x, lounge_y - 15, 'lounge', app.pnl_text_mut)
	}
}
