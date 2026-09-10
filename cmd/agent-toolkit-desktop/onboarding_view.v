module main

import gg
import desktop.pixelart
import desktop_engine

// VC4 (#1173) — Paper Co. setup journey, second visual-lock pass.
//
// Canonical visual reference: docs/desktop/assets/design/onboarding.jpg with
// concept-board.jpg as the shell/material authority. The first VC4 pass
// closed structural gaps (masthead content, card clipping, review rows,
// responsive recomposition) but still read as a bordered utility screen. This
// pass changes HOW onboarding occupies the whole window: it replaces the
// generic header + production sidebar with a dedicated editorial shell
// (draw_onboarding_masthead_shell + draw_onboarding_sidebar, wired from
// frame() in main.v), enlarges type across the board, trades hard borders
// for warm paper/manila fills, and composes each illustration as a small
// scene instead of one centered icon.
//
// Truth: every value shown here comes from Engine (onboarding_status, tool
// discovery, targets, skills, products, personas). Illustration is
// environmental only — it never implies runtime activity. Engine internals
// (revision, api counters, root-resolution chain, ADR ids) live behind the
// Details affordance instead of dominating first run.

// five user-facing stages; the Engine work each one commits is in onb_apply_stage
const onb_stages = ['Setup Choice', 'Tools', 'Workspace', 'Capabilities', 'Review']

const onb_stage_hints = ['How would you like to begin?', "We'll find what you have",
	'Choose where agents live', 'Recommended for you', 'Confirm and finish']

const onb_last_stage = 4

// setup-choice cards (stage 0) — each maps to real product behaviour
const onb_choices = ['Set up for me', 'Existing setup', 'Find my setup']

const onb_choice_copy = ['Create a new workspace.', 'Use a configured setup.',
	'Find existing workspaces.']

// workspace cards (stage 2)
const onb_ws_choices = ['Create workspace', 'Reuse a workspace']

const onb_ws_copy = ['Create a fresh workspace.', 'Use an existing folder.']

// recommended capabilities (stage 3) — labels are user-facing, the sub-line is
// the real catalog fact behind each one
const onb_caps = ['Multi-agent collaboration (MCP)', 'Task planning and execution', 'Workspace memory',
	'Observability and insights']

// ── the editorial shell (replaces the generic header + production sidebar) ──

// shell_mast_h is shared by onboarding and every regular destination.
// It follows the reference's editorial band while leaving useful content at
// compact heights.
fn shell_mast_h(h int) int {
	mut m := h * 13 / 100
	if m < 78 {
		m = 78
	}
	if m > 128 {
		m = 128
	}
	return m
}

// draw_onboarding_sidebar replaces the production nav with the reference's
// simplified onboarding rail: brand, three quiet rows, and a landscape
// illustration with an editorial quote filling the rest of the column.
pub fn draw_onboarding_sidebar(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	pid := office_palette_id(app)
	mh := shell_mast_h(h)
	x0 := dock_x(app, w)
	y0 := mh
	y1 := h - 28
	app.gg.draw_rect_filled(x0, y0, dock_w, y1 - y0, col_charcoal)
	app.gg.draw_line(x0 + dock_w, y0, x0 + dock_w, y1, col_line)

	app.gg.draw_text(x0 + 18, y0 + 18, 'Agent Toolkit', gg.TextCfg{
		color: col_paper
		size: 18
		family: app.fonts.display
	})
	app.gg.draw_text(x0 + 18, y0 + 40, 'Desktop', gg.TextCfg{
		color: col_paper
		size: 18
		family: app.fonts.display
	})

	rows := ['Get Started', 'Help', 'Settings']
	for i, label in rows {
		ry := y0 + 74 + i * 34
		active := i == 0
		if active {
			app.gg.draw_rect_filled(x0 + 8, ry - 6, dock_w - 16, 26, col_ink700)
			app.gg.draw_rect_filled(x0 + 8, ry - 6, 3, 26, col_brass)
		}
		app.gg.draw_text(x0 + 22, ry, label, gg.TextCfg{
			color: if active { col_paper } else { col_slate_dim }
			size: 13
			bold: active
		})
	}

	// landscape band: rolling hills, a tree line and the nest, filling the
	// rest of the rail — the editorial illustration the reference closes
	// its sidebar with, not dead space
	land_y := y0 + 74 + rows.len * 34 + 14
	land_h := y1 - land_y
	if land_h > 60 {
		draw_onb_landscape(mut app, x0, land_y, dock_w, land_h, pid)
	}
}

// draw_onb_landscape is a small original pixel-art panorama: two hill bands,
// a tree line and the hornero nest, closing the sidebar the way the
// reference's village/hills illustration does.
fn draw_onb_landscape(mut app GuiApp, x int, y int, w int, h int, pid pixelart.PaletteId) {
	mut sc := app.pixel_cache
	ground := y + h - 44
	app.gg.draw_rect_filled(x, y, w, h, col_ink700)
	// dusk sky band over two hills — the illustration fills the rail instead
	// of leaving a dead dark block above a thin strip of green
	sky_h := (ground - y) * 30 / 100
	app.gg.draw_rect_filled(x, y, w, sky_h, tint(pc(app, `s`), 90))
	hill1_y := y + sky_h
	app.gg.draw_rect_filled(x, hill1_y, w, ground - hill1_y, pc(app, `f`))
	hill2_y := ground - (ground - hill1_y) * 45 / 100
	app.gg.draw_rect_filled(x, hill2_y, w, ground - hill2_y, pc(app, `F`))
	// tree line along the back hill
	plant := pixelart.environment_for(.plant)
	mut px := x + 10
	for px < x + w - 20 {
		plant_scale := if ((px - x) / 34) % 3 == 0 { 3 } else { 2 }
		sc.draw(plant, pid, px, hill1_y - plant.height() * plant_scale + 6, plant_scale)
		px += 34
	}
	nest := pixelart.environment_for(.nest)
	sc.draw(nest, pid, x + w / 2 - 14, hill2_y - 22, 2)
	// A tiny hillside workshop gives the rail a real place, not a flat color
	// field: stepped roof, lit window, path, and one idle catalog-world agent.
	house_x := x + w - 70
	house_y := ground - 48
	app.gg.draw_rect_filled(house_x, house_y + 14, 46, 34, pc(app, `m`))
	app.gg.draw_rect_filled(house_x - 4, house_y + 12, 54, 5, pc(app, `W`))
	app.gg.draw_rect_filled(house_x + 2, house_y + 7, 42, 5, pc(app, `W`))
	app.gg.draw_rect_filled(house_x + 8, house_y + 2, 30, 5, pc(app, `W`))
	app.gg.draw_rect_filled(house_x + 8, house_y + 23, 12, 12, pc(app, `p`))
	app.gg.draw_rect_empty(house_x + 8, house_y + 23, 12, 12, pc(app, `W`))
	for step in 0 .. 4 {
		app.gg.draw_rect_filled(x + 94 - step * 7, ground - 8 - step * 7, 24 + step * 14, 7, pc(app, `p`))
	}
	agent := pixelart.agent_for_state(.idle)
	sc.draw(agent, pid, x + 54, ground - agent.height() * 2, 2)
	// Foreground grove and a stepped path break up the broad hill mass.
	path_col := tint(pc(app, `m`), 170)
	path_h := (ground - hill2_y - 8) / 4
	for step in 0 .. 4 {
		path_x := x + w / 2 - 5 + (if step % 2 == 0 { -4 } else { 4 })
		app.gg.draw_rect_filled(path_x, hill2_y + 8 + step * path_h, 10 + step * 2, path_h + 2, path_col)
	}
	for tx in [x + 10, x + w - 42] {
		sc.draw(plant, pid, tx, ground - plant.height() * 3, 3)
	}
	app.gg.draw_text(x + 16, ground + 10, 'Different Agents.', gg.TextCfg{
		color: col_paper
		size: 11
		family: app.fonts.display
	})
	app.gg.draw_text(x + 16, ground + 25, 'A Brighter Tomorrow.', gg.TextCfg{
		color: col_slate_dim
		size: 10
		family: app.fonts.display
	})
}

// OnbLayout is computed once per frame and reused by drawing, clicking and
// hovering, so the interactive geometry can never drift from the drawn one.
struct OnbLayout {
	fx      int
	fy      int
	fw      int
	fh      int
	welc_y  int
	welc_h  int
	step_y  int
	step_h  int
	body_y  int
	body_h  int
	foot_y  int
	side_x  int // preview column (own surface, replaces the inspector)
	side_w  int
	side_h  int
	compact bool
	active  int // current stage — the only one shown full-width when compact
}

fn onb_layout(app &GuiApp, w int, h int) OnbLayout {
	term_h := if app.term_visible { onb_effective_term_h(app) } else { 0 }
	mh := shell_mast_h(h)
	fy := mh
	fh := h - mh - 28 - term_h
	side_w := if w >= 1180 { 340 } else { 0 }
	rtl := app.lang.is_rtl()
	// LTR: dock | board | preview.  RTL: preview | board | dock.
	fx := if rtl { side_w + 16 } else { dock_x(app, w) + dock_w + 16 }
	fw := w - dock_w - 16 - side_w - 16
	compact := fw < 700 || fh < 480
	welc_y := fy + 6
	welc_h := if compact { 36 } else { 46 }
	step_y := welc_y + welc_h + 2
	step_h := if compact { 38 } else { 56 }
	body_y := step_y + step_h + 8
	foot_y := fy + fh - 28
	return OnbLayout{
		fx: fx
		fy: fy
		fw: fw
		fh: fh
		welc_y: welc_y
		welc_h: welc_h
		step_y: step_y
		step_h: step_h
		body_y: body_y
		body_h: foot_y - body_y - 8
		foot_y: foot_y
		side_x: if app.lang.is_rtl() { dock_x(app, w) + dock_w } else { w - side_w }
		side_w: side_w
		side_h: fh
		compact: compact
		active: app.onboarding_step
	}
}

// ── shared rects ────────────────────────────────────────────────────────────

// onb_sec_rect returns the sheet rectangle for section i (0..4) in the
// reference's board layout: sections 1/2 on the top row, 3/4 below, and the
// review strip spanning the full width underneath. Compact: only the active
// stage renders, full-width, like a focused single-stage view — a
// recomposition, not a shrink.
fn onb_sec_rect(l OnbLayout, i int) (int, int, int, int) {
	if l.compact {
		if i == l.active {
			return l.fx, l.body_y, l.fw, l.body_h
		}
		return l.fx, l.body_y, 0, 0
	}
	gap := 12
	cols := if l.fw >= 640 { 2 } else { 1 }
	total := l.fw - (cols - 1) * gap
	// 55/45 split: choices and workspace get the room the illustrations need
	cw0 := if cols == 2 { total * 55 / 100 } else { total }
	cw1 := total - cw0
	avail := l.foot_y - l.body_y - 8
	// row0/row1 are fixed minimums sized to what their cards actually need
	// (illustration band + title + copy), so a card can never spill past its
	// own sheet into the row beneath it. Review — the most gracefully
	// degrading sheet, it already truncates rows honestly — gets whatever
	// height remains instead of forcing the rows to compress.
	mut row0 := 158
	mut row1 := 126
	rev_min := 92
	need := row0 + row1 + rev_min + 2 * gap
	if avail < need {
		// short board (e.g. 1024x640 with the terminal hidden is not compact
		// yet): shrink the two rows proportionally so review + footer still fit
		shrink := avail - rev_min - 2 * gap
		row0 = shrink * 158 / (158 + 126)
		row1 = shrink - row0
	}
	mut rev_h := avail - row0 - row1 - 2 * gap
	if rev_h < rev_min {
		rev_h = rev_min
	}
	if i == 4 {
		return l.fx, l.body_y + row0 + gap + row1 + gap, l.fw, rev_h
	}
	if cols == 2 {
		// two sheets per row (Setup Choice+Tools, Workspace+Capabilities)
		col := i % 2
		row := i / 2
		cx := if col == 0 { l.fx } else { l.fx + cw0 + gap }
		cy := if row == 0 { l.body_y } else { l.body_y + row0 + gap }
		return cx, cy, if col == 0 { cw0 } else { cw1 }, if row == 0 { row0 } else { row1 }
	}
	// single column: four sheets stacked at the same fixed heights, paired
	rn := [row0, row1, row0, row1]
	mut cy := l.body_y
	for j in 0 .. i {
		cy += rn[j] + gap
	}
	return l.fx, cy, l.fw, rn[i]
}

fn onb_step_rect(l OnbLayout, i int) (int, int, int, int) {
	cw := l.fw / onb_stages.len
	return l.fx + i * cw, l.step_y, cw, l.step_h
}

// decision cards inside a section sheet (setup choice, workspace)
fn onb_card_rect(l OnbLayout, sec int, i int, total int) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, sec)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	gap := 12
	cw := (sw - (total - 1) * gap) / total
	mut ch := sh - 46
	if ch < 74 {
		ch = 74 // floor: scene + title + one copy line never overlap each other
	}
	return sx + i * (cw + gap), sy + 40, cw, ch
}

// tool discovery cards inside section 1, two columns
fn onb_tool_rect(l OnbLayout, i int) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, 1)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	gap := 8
	cols := 2
	cw := (sw - gap) / cols
	rows := 2
	ch := (sh - 40 - (rows - 1) * gap) / rows
	col := i % cols
	row := i / cols
	return sx + col * (cw + gap), sy + 40 + row * (ch + gap), cw, ch
}

fn onb_cap_rect(l OnbLayout, i int) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, 3)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	mut rh := (sh - 40) / onb_caps.len
	if rh < 22 {
		rh = 22 // floor: an 18px box + 13px label fit; rows past the sheet are dropped
	}
	return sx, sy + 40 + i * rh, sw, rh - 4
}

fn onb_cta_rect(l OnbLayout) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, 4)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	cw := if sw > 460 { 260 } else { sw - 24 }
	return sx + sw - cw, sy + sh - 46, cw, 38
}

fn onb_next_rect(l OnbLayout) (int, int, int, int) {
	return l.fx + l.fw - 116, l.foot_y + 2, 100, 30
}

fn onb_back_rect(l OnbLayout) (int, int, int, int) {
	return l.fx + l.fw - 220, l.foot_y + 2, 92, 30
}

fn onb_skip_rect(l OnbLayout) (int, int, int, int) {
	return l.fx, l.foot_y + 6, 50, 22
}

fn onb_diag_rect(l OnbLayout) (int, int, int, int) {
	return l.fx + 62, l.foot_y + 6, 66, 22
}

fn onb_rescan_rect(l OnbLayout) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, 1)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	return sx + sw - 96, sy + 8, 84, 24
}

// onb_art_scale keeps pixel art integral: the largest whole multiplier that
// fits the available band, never a stretched sprite.
fn onb_art_scale(sw int, sh int, aw int, ah int) int {
	mut sc := 1
	for m := 8; m >= 1; m-- {
		if sw * m <= aw && sh * m <= ah {
			sc = m
			break
		}
	}
	return sc
}

// onb_check draws a checkmark from pixel runs — the brand fonts do not carry a
// dependable ✓ glyph and fell back to a stray letterform.
fn onb_check(mut app GuiApp, x int, y int, c gg.Color) {
	app.gg.draw_rect_filled(x + 1, y + 5, 2, 4, c)
	app.gg.draw_rect_filled(x + 3, y + 7, 2, 3, c)
	app.gg.draw_rect_filled(x + 5, y + 4, 2, 4, c)
	app.gg.draw_rect_filled(x + 7, y + 1, 2, 4, c)
}

// onb_fit returns how many characters of the UI font fit in px at a size.
// Plex Sans averages ~0.56em, so this is deliberately slightly conservative.
fn onb_fit(px int, size int) int {
	adv := if size <= 10 {
		5
	} else if size <= 13 {
		7
	} else {
		8
	}
	n := px / adv
	return if n < 4 { 4 } else { n }
}

fn onb_hit(mx int, my int, x int, y int, w int, h int) bool {
	return mx >= x && mx < x + w && my >= y && my < y + h
}

// onb_sheet_fill is the soft material surface every sheet/card sits on:
// warm cream when active, a quieter manila tint otherwise, and a brass
// accent bar instead of a hard outline. This is the deliberate replacement
// for the bordered-panel treatment the first VC4 pass over-used.
fn onb_sheet_fill(mut app GuiApp, x int, y int, w int, h int, active bool) {
	// the reference's sheets are light paper on the warm canvas with a very
	// quiet edge — hierarchy comes from tone and whitespace, not outlines
	app.gg.draw_rect_filled(x + 2, y + 3, w, h, tint(col_ink, 14))
	app.gg.draw_rect_filled(x, y, w, h, pc(app, `P`))
	app.gg.draw_rect_empty(x, y, w, h, tint(pc(app, `W`), 70))
	if active {
		app.gg.draw_rect_filled(x, y, w, 3, app.pnl_select)
	}
}

// ── truth helpers ───────────────────────────────────────────────────────────

// onb_cap_fact returns the real catalog fact behind each recommended
// capability. Nothing here claims runtime activity.
fn onb_cap_fact(mut app GuiApp, i int) string {
	return match i {
		0 { '${mcp_total(mut app)} MCP providers in catalog' }
		1 { '${agents_active_total(mut app)} agent personas available' }
		2 { 'knowledge/ ledger seeded in the workspace' }
		else { '${skills_total(mut app)} skills · insights and loops' }
	}
}

fn onb_choice_verb(app &GuiApp) string {
	return match app.onb_choice {
		1 { 'Connect to existing setup' }
		2 { 'Search this computer' }
		else { 'Set everything up for me' }
	}
}

// ── drawing ─────────────────────────────────────────────────────────────────

fn draw_onboarding(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	l := onb_layout(app, w, h)
	pid := office_palette_id(app)
	st := app.desktop.onboarding_status(app.harness_root)

	// warm paper world behind the whole journey
	app.gg.draw_rect_filled(l.fx - 16, l.fy, l.fw + 32, l.fh, app.pnl_bg)

	draw_onb_welcome(mut app, l)
	draw_onb_steps(mut app, l)

	// the reference is a board, not a one-screen-at-a-time wizard: every
	// setup sheet gets a soft material surface, the active one accented
	for i in 0 .. onb_stages.len {
		sx, sy, sw, sh := onb_sec_rect(l, i)
		if sh < 40 {
			continue
		}
		onb_sheet_fill(mut app, sx, sy, sw, sh, i == app.onboarding_step)
	}
	draw_onb_choice(mut app, l, pid)
	draw_onb_tools(mut app, l)
	draw_onb_workspace(mut app, l, pid, st)
	draw_onb_capabilities(mut app, l)
	draw_onb_review(mut app, l, st)

	if app.onb_diag {
		draw_onb_diagnostics(mut app, l, st)
	}
	draw_onb_footer(mut app, l, st)
}

fn draw_onb_welcome(mut app GuiApp, l OnbLayout) {
	y := l.welc_y
	app.gg.draw_text(l.fx, y, 'Welcome to', gg.TextCfg{
		color: app.pnl_text_mut
		size: 13
	})
	app.gg.draw_text(l.fx, y + 16, 'Agent Toolkit Desktop', gg.TextCfg{
		color: app.pnl_text
		size: 24
		family: app.fonts.display
	})
	if !l.compact && l.fw > 760 {
		app.gg.draw_text(l.fx + 280, y + 22, "Let's get you set up — a few quick steps and you'll be building with agents.", gg.TextCfg{
			color: app.pnl_text_mut
			size: 12
		})
	}
	// real local date and time — never the reference's fictional date
	now := ui_now()
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	mname := if now.month >= 1 && now.month <= 12 { months[now.month - 1] } else { '' }
	stamp := '${mname} ${now.day}, ${now.year}'
	clock := '${now.hour:02d}:${now.minute:02d}'
	if l.fw > 560 {
		app.gg.draw_text(l.fx + l.fw - 92, y, stamp, gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		app.gg.draw_text(l.fx + l.fw - 92, y + 16, clock, gg.TextCfg{
			color: app.pnl_text
			size: 20
			family: app.fonts.display
		})
	}
}

fn draw_onb_steps(mut app GuiApp, l OnbLayout) {
	md := if l.step_h >= 52 { 36 } else { 26 }
	// one continuous journey rule behind every medallion, like the reference
	rule_y := l.step_y + md / 2 + 2
	app.gg.draw_rect_filled(l.fx + md / 2, rule_y, l.fw - md, 2, tint(pc(app, `W`), 90))
	for i, name in onb_stages {
		sx, sy, sw, sh := onb_step_rect(l, i)
		done := i < app.onboarding_step
		here := i == app.onboarding_step
		mx0 := sx
		my0 := sy + 2
		fill := if here {
			app.pnl_select
		} else if done {
			app.pnl_success
		} else {
			app.pnl_card
		}
		app.gg.draw_rect_filled(mx0 + 3, my0 + 3, md, md, tint(col_ink, 30))
		app.gg.draw_rect_filled(mx0, my0, md, md, fill)
		app.gg.draw_rect_empty(mx0, my0, md, md, if here || done {
			fill
		} else {
			tint(pc(app, `W`), 120)
		})
		if done {
			onb_check(mut app, mx0 + md / 2 - 4, my0 + md / 2 - 3, app.pnl_bg)
		} else {
			app.gg.draw_text(mx0 + md / 2 - 5, my0 + md / 2 - 8, '${i + 1}', gg.TextCfg{
				color: if here { app.pnl_bg } else { app.pnl_text_mut }
				size: if md >= 30 { 16 } else { 13 }
				bold: true
			})
		}
		label_x := sx + md + 10
		app.gg.draw_text(label_x, sy + 3, name, gg.TextCfg{
			color: if here { app.pnl_text } else { app.pnl_text_mut }
			size: if sh >= 52 { 15 } else { 13 }
			bold: here
		})
		hint_px := sx + sw - label_x - 8
		if sh >= 52 && hint_px > 40 {
			app.gg.draw_text(label_x, sy + 20, utf8_truncate(onb_stage_hints[i], onb_fit(hint_px, 11)), gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
		}
	}
}

fn draw_onb_sheet_title(mut app GuiApp, l OnbLayout, sec int, title string, sub string) {
	sx, sy, sw, sh := onb_sec_rect(l, sec)
	if sh < 40 {
		return // compact: this sheet is not the active one, its rect is inert
	}
	app.gg.draw_text(sx + 14, sy + 10, title, gg.TextCfg{
		color: app.pnl_text
		size: 17
		family: app.fonts.display
	})
	if sub != '' && sw > 300 {
		app.gg.draw_text(sx + 14, sy + 28, utf8_truncate(sub, onb_fit(sw - 130, 11)), gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	}
}

// stage 0 — three illustrated choices, each a small composed scene
fn draw_onb_choice(mut app GuiApp, l OnbLayout, pid pixelart.PaletteId) {
	draw_onb_sheet_title(mut app, l, 0, 'How would you like to get started?', '')
	for i, title in onb_choices {
		cx, cy, cw, ch := onb_card_rect(l, 0, i, onb_choices.len)
		if ch == 0 {
			continue
		}
		sel := app.onb_choice == i
		// unselected: warm manila card on the paper sheet; selected: a sage
		// wash with a sage edge — the reference's green-highlighted choice
		card_tone := if sel { tint(app.pnl_success, 170) } else { tint(pc(app, `m`), 90) }
		app.gg.draw_rect_filled(cx, cy, cw, ch, card_tone)
		if sel {
			app.gg.draw_rect_empty(cx, cy, cw, ch, app.pnl_success)
			app.gg.draw_rect_empty(cx + 1, cy + 1, cw - 2, ch - 2, app.pnl_success)
		}
		// radio, top-right corner — quiet, not a wireframe input
		app.gg.draw_rect_filled(cx + cw - 24, cy + 8, 14, 14, app.pnl_bg)
		app.gg.draw_rect_empty(cx + cw - 24, cy + 8, 14, 14, app.pnl_border_hi)
		if sel {
			app.gg.draw_rect_filled(cx + cw - 21, cy + 11, 8, 8, app.pnl_success)
		}
		band := if ch * 44 / 100 < 42 { 42 } else { ch * 44 / 100 }
		draw_onb_choice_scene(mut app, i, cx + 8, cy + 4, cw - 16, band, pid)
		ty := cy + band + 6
		app.gg.draw_text(cx + 12, ty, title, gg.TextCfg{
			color: app.pnl_text
			size: 15
			family: app.fonts.display
		})
		mut lines := (cy + ch - 6 - (ty + 19)) / 14
		if lines > 3 {
			lines = 3
		}
		draw_onb_wrapped(mut app, cx + 12, ty + 19, cw - 24, onb_choice_copy[i], lines)
	}
}

// draw_onb_choice_scene composes 2-3 sprites into a small cluster per choice
// instead of one icon centered in empty space.
fn draw_onb_choice_scene(mut app GuiApp, i int, x int, y int, w int, h int, pid pixelart.PaletteId) {
	mut sc := app.pixel_cache
	base := y + h - 4
	match i {
		0 {
			desk := pixelart.environment_for(.welcome_desk)
			chair := pixelart.environment_for(.chair)
			plant := pixelart.environment_for(.plant)
			s := onb_art_scale(desk.width() + chair.width() + 4, desk.height(), w - 8, h - 8)
			gx := x + (w - (desk.width() + chair.width() + 4) * s) / 2
			sc.draw(chair, pid, gx, base - chair.height() * s, s)
			sc.draw(desk, pid, gx + chair.width() * s + 4 * s, base - desk.height() * s, s)
			if w > 140 {
				sc.draw(plant, pid, x + w - plant.width() * s - 4, base - plant.height() * s, s)
			}
		}
		1 {
			cabinet := pixelart.environment_for(.cabinet)
			books := pixelart.environment_for(.books)
			s := onb_art_scale(cabinet.width() + books.width() + 4, cabinet.height(), w - 8, h - 8)
			gx := x + (w - (cabinet.width() + books.width() + 4) * s) / 2
			sc.draw(cabinet, pid, gx, base - cabinet.height() * s, s)
			sc.draw(books, pid, gx + cabinet.width() * s + 4 * s, base - books.height() * s, s)
		}
		else {
			shelf := pixelart.environment_for(.shelf)
			window := pixelart.environment_for(.window)
			s := onb_art_scale(shelf.width() + window.width() + 4, shelf.height(), w - 8, h - 8)
			gx := x + (w - (shelf.width() + window.width() + 4) * s) / 2
			sc.draw(shelf, pid, gx, base - shelf.height() * s, s)
			sc.draw(window, pid, gx + shelf.width() * s + 4 * s, base - window.height() * s, s)
		}
	}
}

// stage 1 — tool discovery as product UI, not a diagnostic dump
fn draw_onb_tools(mut app GuiApp, l OnbLayout) {
	cat := app.desktop.engine_tool_discovery_catalog_cached()
	found := cat.filter(it.found).len
	_, _, _, sh_t := onb_sec_rect(l, 1)
	if sh_t < 40 {
		return
	}
	draw_onb_sheet_title(mut app, l, 1, 'Detected developer tools', '${found} of ${cat.len} found on this computer')
	rx, ry, rw, rh := onb_rescan_rect(l)
	if rh > 0 {
		app.gg.draw_rect_filled(rx, ry, rw, rh, if app.onboarding_hover == 20 {
			app.pnl_card_sel
		} else {
			app.pnl_card
		})
		app.gg.draw_text(rx + 14, ry + 5, '⟳ Rescan', gg.TextCfg{
			color: app.pnl_text
			size: 12
		})
	}
	_, ssy, _, ssh := onb_sec_rect(l, 1)
	mut roster := cat.filter(it.found)
	roster << cat.filter(!it.found)
	mut shown := 0
	for t in roster {
		if shown >= 4 {
			break
		}
		cx, cy, cw, ch := onb_tool_rect(l, shown)
		if ch == 0 || cy + ch > ssy + ssh - 6 {
			break
		}
		app.gg.draw_rect_filled(cx, cy, cw, ch, app.pnl_card)
		// bigger identity mark
		mk := if ch > 80 { 32 } else { 24 }
		app.gg.draw_rect_filled(cx + 10, cy + 10, mk, mk, app.pnl_card_sel)
		app.gg.draw_rect_empty(cx + 10, cy + 10, mk, mk, app.pnl_border)
		initial := if t.display_name.len > 0 { t.display_name[0..1].to_upper() } else { '?' }
		app.gg.draw_text(cx + 10 + mk / 2 - 6, cy + 10 + mk / 2 - 9, initial, gg.TextCfg{
			color: app.pnl_text
			size: if mk > 28 { 18 } else { 15 }
			family: app.fonts.display
		})
		label := if t.found { 'Ready' } else { 'Missing' }
		pill_c := if t.found { app.pnl_success } else { app.pnl_text_mut }
		name_x := cx + 16 + mk
		pw := label.len * 7 + 16
		app.gg.draw_text(name_x, cy + 12, utf8_truncate(t.display_name, onb_fit(cw - (mk + 26) - pw, 14)), gg.TextCfg{
			color: app.pnl_text
			size: 14
			bold: true
		})
		app.gg.draw_rect_filled(cx + cw - pw - 10, cy + 10, pw, 20, tint(pill_c, 60))
		app.gg.draw_rect_empty(cx + cw - pw - 10, cy + 10, pw, 20, pill_c)
		app.gg.draw_text(cx + cw - pw - 2, cy + 15, label, gg.TextCfg{
			color: pill_c
			size: 11
		})
		detail := if t.found {
			t.resolved_path
		} else {
			'Install to enable seamless integration'
		}
		app.gg.draw_text(name_x, cy + 32, utf8_truncate(detail, onb_fit(cw - mk - 30, 11)), gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
			mono: t.found
		})
		shown++
	}
	sx1, sy1, sw1, sh1 := onb_sec_rect(l, 1)
	if cat.len > shown && sh1 >= 40 {
		app.gg.draw_text(sx1 + sw1 - 190, sy1 + sh1 - 15, '+${cat.len - shown} more in Settings → Targets', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
	}
}

// stage 2 — where the agents live
fn draw_onb_workspace(mut app GuiApp, l OnbLayout, pid pixelart.PaletteId, st desktop_engine.OnboardingStatus) {
	draw_onb_sheet_title(mut app, l, 2, 'Workspace setup', 'Where agents and data live')
	for i, title in onb_ws_choices {
		cx, cy, cw, ch := onb_card_rect(l, 2, i, onb_ws_choices.len)
		if ch == 0 {
			continue
		}
		sel := app.onb_ws_choice == i
		// unselected: warm manila card on the paper sheet; selected: a sage
		// wash with a sage edge — the reference's green-highlighted choice
		card_tone := if sel { tint(app.pnl_success, 170) } else { tint(pc(app, `m`), 90) }
		app.gg.draw_rect_filled(cx, cy, cw, ch, card_tone)
		if sel {
			app.gg.draw_rect_empty(cx, cy, cw, ch, app.pnl_success)
			app.gg.draw_rect_empty(cx + 1, cy + 1, cw - 2, ch - 2, app.pnl_success)
		}
		app.gg.draw_rect_filled(cx + cw - 24, cy + 8, 14, 14, app.pnl_bg)
		app.gg.draw_rect_empty(cx + cw - 24, cy + 8, 14, 14, app.pnl_border_hi)
		if sel {
			app.gg.draw_rect_filled(cx + cw - 21, cy + 11, 8, 8, app.pnl_success)
		}
		band := if ch * 52 / 100 < 40 { 40 } else { ch * 52 / 100 }
		draw_onb_choice_scene(mut app, i, cx + 8, cy + 4, cw - 16, band, pid)
		ty := cy + band + 4
		app.gg.draw_text(cx + 12, ty, title, gg.TextCfg{
			color: app.pnl_text
			size: 15
			family: app.fonts.display
		})
		mut wlines := (cy + ch - 6 - (ty + 19)) / 14
		if wlines > 2 {
			wlines = 2
		}
		draw_onb_wrapped(mut app, cx + 12, ty + 19, cw - 24, onb_ws_copy[i], wlines)
	}
	sx, sy, sw, sh := onb_sec_rect(l, 2)
	if sh > 0 {
		path := if app.onboarding_harness != '' { app.onboarding_harness } else { app.harness_root }
		state := if st.workspace_exists { 'ready' } else { 'not created yet' }
		app.gg.draw_text(sx + 14, sy + sh - 16, utf8_truncate(path, onb_fit(sw - 140, 11)), gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
			mono: true
		})
		app.gg.draw_text(sx + sw - 14 - state.len * 7, sy + sh - 16, state, gg.TextCfg{
			color: if st.workspace_exists { app.pnl_success } else { app.pnl_text_mut }
			size: 11
		})
	}
}

// stage 3 — recommended capabilities in user language, real catalog facts
fn draw_onb_capabilities(mut app GuiApp, l OnbLayout) {
	draw_onb_sheet_title(mut app, l, 3, 'Recommended capabilities', 'A useful starting point')
	_, s3y, _, s3h := onb_sec_rect(l, 3)
	for i, name in onb_caps {
		cx, cy, cw, ch := onb_cap_rect(l, i)
		if ch == 0 || cy + ch > s3y + s3h - 4 {
			break
		}
		on := app.onb_cap_on[i]
		box := if ch > 34 { 22 } else { 16 }
		app.gg.draw_rect_filled(cx + 14, cy + (ch - box) / 2, box, box, if on {
			app.pnl_success
		} else {
			app.pnl_card_sel
		})
		app.gg.draw_rect_empty(cx + 14, cy + (ch - box) / 2, box, box, if on {
			app.pnl_success
		} else {
			app.pnl_border_hi
		})
		if on {
			onb_check(mut app, cx + 14 + box / 2 - 4, cy + (ch - box) / 2 + box / 2 - 3, app.pnl_bg)
		}
		app.gg.draw_text(cx + 46, cy + ch / 2 - 15, utf8_truncate(name, onb_fit(cw - 60, 13)), gg.TextCfg{
			color: app.pnl_text
			size: 13
			bold: true
		})
		if ch >= 34 {
			app.gg.draw_text(cx + 46, cy + ch / 2 + 1, utf8_truncate(onb_cap_fact(mut app, i), onb_fit(cw - 60, 11)), gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
		}
	}
}

// stage 4 — truthful summary + finish
fn draw_onb_review(mut app GuiApp, l OnbLayout, st desktop_engine.OnboardingStatus) {
	draw_onb_sheet_title(mut app, l, 4, 'Review and finish', '')
	cat := app.desktop.engine_tool_discovery_catalog_cached()
	found := cat.filter(it.found)
	tools := if found.len == 0 {
		'none detected'
	} else {
		'${found.len} found'
	}
	caps_on := app.onb_cap_on.filter(it).len
	rows := [
		['Setup method', onb_choice_verb(app)],
		['Tools detected', tools],
		['Workspace',
			if st.workspace_exists { app.harness_root } else { onb_ws_choices[app.onb_ws_choice] }],
		['Capabilities', '${caps_on} of ${onb_caps.len} enabled'],
		['Personas', if st.persona_count > 0 {
			'${st.persona_count} bootstrapped'
		} else {
			'created on finish'
		}],
	]
	sx, sy, sw, sh := onb_sec_rect(l, 4)
	if sh == 0 {
		return
	}
	// two columns keep all five facts visible even in a compact review strip
	col_w := (sw - 260 - 24) / 2
	step := 20
	for i, r in rows {
		col := i / 3
		row := i % 3
		rx := sx + 14 + col * (col_w + 24)
		ry := sy + 34 + row * step
		if ry + 14 > sy + sh - 4 {
			break
		}
		app.gg.draw_text(rx, ry, r[0], gg.TextCfg{
			color: app.pnl_text_mut
			size: 12
		})
		app.gg.draw_text(rx + 96, ry, utf8_truncate(r[1], onb_fit(col_w - 96, 12)), gg.TextCfg{
			color: app.pnl_text
			size: 12
		})
	}
	// primary call to action — the wording matches what really happens: every
	// stage already committed its own transaction, this finalizes onboarding
	cx, cy, cw, ch := onb_cta_rect(l)
	if ch == 0 {
		return
	}
	hov := app.onboarding_hover == 30
	app.gg.draw_rect_filled(cx + 3, cy + 3, cw, ch, tint(col_ink, 35))
	app.gg.draw_rect_filled(cx, cy, cw, ch, if hov {
		app.pnl_success
	} else {
		tint(app.pnl_success, 220)
	})
	app.gg.draw_text(cx + 22, cy + 11, 'Finish setup and enter the office  →', gg.TextCfg{
		color: app.pnl_bg
		size: 14
		bold: true
	})
}

fn draw_onb_diagnostics(mut app GuiApp, l OnbLayout, st desktop_engine.OnboardingStatus) {
	dh := 96
	dy := l.foot_y - dh - 6
	app.gg.draw_rect_filled(l.fx, dy, l.fw, dh, col_ink700)
	app.gg.draw_text(l.fx + 12, dy + 6, 'Diagnostics', gg.TextCfg{
		color: col_slate_dim
		size: 11
		bold: true
	})
	lines := [
		'rev ${st.revision} · api ${app.api_calls} · first_run=${st.is_first_run}',
		'root: ${app.harness_root}',
		'resolution: AGENT_TOOLKIT_ROOT → XDG → embedded → FHS → checkout (ADR-015/026)',
		'pending: ${st.pending_items.len} · skills ${st.installed_count} · targets ${st.enabled_targets_count} · personas ${st.persona_count}',
	]
	for i, ln in lines {
		app.gg.draw_text(l.fx + 12, dy + 24 + i * 16, utf8_truncate(ln, (l.fw - 30) / 6), gg.TextCfg{
			color: col_slate_dim
			size: 11
			mono: true
		})
	}
}

fn draw_onb_footer(mut app GuiApp, l OnbLayout, st desktop_engine.OnboardingStatus) {
	sx, sy, sw, sh := onb_skip_rect(l)
	app.gg.draw_text(sx, sy, 'Skip', gg.TextCfg{
		color: if app.onboarding_hover == 12 { app.pnl_text } else { app.pnl_text_mut }
		size: 12
	})
	dx, dy, dw, dh := onb_diag_rect(l)
	app.gg.draw_text(dx, dy, if app.onb_diag { 'Hide details' } else { 'Details' }, gg.TextCfg{
		color: if app.onb_diag || app.onboarding_hover == 13 {
			app.pnl_text
		} else {
			app.pnl_text_mut
		}
		size: 12
	})
	_ = sw
	_ = sh
	_ = dw
	_ = dh
	if app.onboarding_step > 0 {
		bx, by, bw, bh := onb_back_rect(l)
		app.gg.draw_rect_filled(bx, by, bw, bh, if app.onboarding_hover == 10 {
			app.pnl_card_sel
		} else {
			app.pnl_card
		})
		app.gg.draw_text(bx + 30, by + 8, 'Back', gg.TextCfg{
			color: app.pnl_text
			size: 13
		})
	}
	nx, ny, nw, nh := onb_next_rect(l)
	is_last := app.onboarding_step >= onb_last_stage
	app.gg.draw_rect_filled(nx, ny, nw, nh, if app.onboarding_hover == 11 {
		tint(app.pnl_select, 200)
	} else {
		app.pnl_select
	})
	app.gg.draw_text(nx + 20, ny + 8, if is_last { 'Finish' } else { 'Next →' }, gg.TextCfg{
		color: app.pnl_bg
		size: 13
		bold: true
	})
	msg := if app.onboarding_msg != '' {
		app.onboarding_msg
	} else {
		'step ${app.onboarding_step + 1} of ${onb_stages.len} · ${st.pending_items.len} pending'
	}
	app.gg.draw_text(l.fx + 130, l.foot_y + 8, utf8_truncate(msg, onb_fit(l.fw - 380, 11)), gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
	})
}

fn draw_onb_wrapped(mut app GuiApp, x int, y int, w int, s string, max_lines int) {
	per := onb_fit(w, 12)
	words := s.split(' ')
	mut line := ''
	mut ln := 0
	for word in words {
		cand := if line == '' { word } else { line + ' ' + word }
		if cand.len > per {
			app.gg.draw_text(x, y + ln * 14, line, gg.TextCfg{
				color: app.pnl_text_mut
				size: 12
			})
			ln++
			line = word
			if ln >= max_lines {
				return
			}
		} else {
			line = cand
		}
	}
	if line != '' && ln < max_lines {
		app.gg.draw_text(x, y + ln * 14, line, gg.TextCfg{
			color: app.pnl_text_mut
			size: 12
		})
	}
}

// ── "Your setup so far" — replaces the Office inspector during onboarding ───

fn draw_onboarding_preview(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	l := onb_layout(app, w, h)
	if l.side_w == 0 {
		return
	}
	pid := office_palette_id(app)
	mut sc := app.pixel_cache
	st := app.desktop.onboarding_status(app.harness_root)
	x := l.side_x
	y := l.fy
	iw := l.side_w
	ih := l.side_h
	app.gg.draw_rect_filled(x, y, iw, ih, app.pnl_bg)
	app.gg.draw_line(x, y, x, y + ih, app.pnl_border)
	app.gg.draw_text(x + 16, y + 10, 'Your setup so far', gg.TextCfg{
		color: app.pnl_text
		size: 17
		family: app.fonts.display
	})

	// illustrated welcome scene owns most of the column — a dense miniature
	// office, not a narrow inspector strip
	sy := y + 34
	sh := ih * 50 / 100
	draw_onb_scene(mut app, x + 8, sy, iw - 16, sh, pid)

	// compact truthful facts strip — two columns so it never sprawls
	fy0 := sy + sh + 12
	mut rows := [][]string{}
	rows << ['Setup', onb_choice_verb(app)]
	cat := app.desktop.engine_tool_discovery_catalog_cached()
	rows << ['Tools', '${cat.filter(it.found).len} of ${cat.len} found']
	rows << ['Workspace', if st.workspace_exists { 'ready' } else { 'not created yet' }]
	rows << ['Skills', '${st.installed_count} installed']
	rows << ['Targets', '${st.enabled_targets_count} enabled']
	rows << ['Personas', '${st.persona_count} bootstrapped']
	for i, r in rows {
		col := i / 3
		row := i % 3
		rx := x + 16 + col * (iw / 2)
		ry := fy0 + row * 30
		if ry + 26 > y + ih - 90 {
			break
		}
		app.gg.draw_text(rx, ry, r[0], gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		app.gg.draw_text(rx, ry + 13, r[1], gg.TextCfg{
			color: app.pnl_text
			size: 12
		})
	}

	// Hornero editorial card
	qy := y + ih - 78
	if qy > fy0 {
		app.gg.draw_rect_filled(x + 8, qy, iw - 16, 62, tint(pc(app, `p`), 12))
		app.gg.draw_text(x + 20, qy + 10, '"A quieter internet can be', gg.TextCfg{
			color: app.pnl_text
			size: 12
			family: app.fonts.display
		})
		app.gg.draw_text(x + 20, qy + 26, 'a kinder place."', gg.TextCfg{
			color: app.pnl_text
			size: 12
			family: app.fonts.display
		})
		app.gg.draw_text(x + 20, qy + 44, '— The Hornero Principle', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
		nest := pixelart.environment_for(.nest)
		sc.draw(nest, pid, x + iw - 58, qy + 18, 2)
	}
}

// draw_onb_scene composes a dense welcome office: wood wall with a framed
// sign and picture, a shelf of books, a window, a reception desk with an
// idle builder and a visitor chair, a lounge corner with a couch, and
// plants/lamp/nest — an original miniature scene, not isolated icons.
// Static and deterministic; illustration only, never runtime state.
fn draw_onb_scene(mut app GuiApp, x int, y int, w int, h int, pid pixelart.PaletteId) {
	mut sc := app.pixel_cache
	scale := if w >= 300 && h >= 220 {
		4
	} else if w >= 220 { 3 } else { 2 }
	wall_h := h * 40 / 100
	app.gg.draw_rect_filled(x, y, w, wall_h, pc(app, `p`))
	app.gg.draw_rect_filled(x, y + wall_h, w, h - wall_h, pc(app, `m`))
	for i := 0; i < (h - wall_h) / 10; i++ {
		ly := y + wall_h + 4 + i * 10
		app.gg.draw_line(x, ly, x + w, ly, pc(app, `M`))
		off := if i % 2 == 0 { 0 } else { 30 }
		for jx := x + 10 + off; jx < x + w - 10; jx += 60 {
			app.gg.draw_line(jx, ly, jx, ly + 10, pc(app, `M`))
		}
	}
	app.gg.draw_rect_filled(x, y + wall_h - 3, w, 3, pc(app, `W`))
	base := y + wall_h + 3

	// framed office sign, centered high on the wall
	l1 := 'AGENTS MAKE A KINDER'
	l2 := 'TECH TOMORROW'
	plate_w := l1.len * 7 + 20
	plate_h := 38
	sgx := x + (w - plate_w) / 2
	sgy := y + 12
	app.gg.draw_rect_filled(sgx + 2, sgy + 2, plate_w, plate_h, pc(app, `W`))
	app.gg.draw_rect_filled(sgx, sgy, plate_w, plate_h, pc(app, `p`))
	app.gg.draw_rect_empty(sgx, sgy, plate_w, plate_h, pc(app, `W`))
	app.gg.draw_text(sgx + 10, sgy + 7, l1, gg.TextCfg{
		color: pc(app, `k`)
		size: 10
		bold: true
	})
	app.gg.draw_text(sgx + 10, sgy + 21, l2, gg.TextCfg{
		color: pc(app, `k`)
		size: 10
		bold: true
	})

	shelf := pixelart.environment_for(.shelf)
	sc.draw(shelf, pid, x + 8, base - shelf.height() * scale - 2, scale)
	books := pixelart.environment_for(.books)
	sc.draw(books, pid, x + 10, base - books.height() * scale - shelf.height() * scale - 4, scale)
	win := pixelart.environment_for(.window)
	sc.draw(win, pid, x + w - win.width() * scale - 14, y + 10, scale)
	if w >= 260 {
		picture := pixelart.environment_for(.picture)
		sc.draw(picture, pid, x + w - picture.width() * scale - 16, y + wall_h - picture.height() * scale - 6, scale)
	}

	desk := pixelart.environment_for(.welcome_desk)
	chair := pixelart.environment_for(.chair)
	rug := pixelart.environment_for(.rug)
	dx := x + (w - desk.width() * scale) / 2
	dy := y + h - desk.height() * scale - 18
	rgs := if rug.width() * scale <= w - 24 { scale } else { scale - 1 }
	sc.draw(rug, pid, x + (w - rug.width() * rgs) / 2, y + h - rug.height() * rgs - 6, rgs)
	if w >= 240 {
		sc.draw(chair, pid, dx - chair.width() * scale - 8, dy + desk.height() * scale / 2, scale)
	}
	agent := pixelart.with_identity(pixelart.agent_for_state(.idle), 1)
	sc.draw(agent, pid, dx + (desk.width() * scale - agent.width() * scale) / 2, dy - agent.height() * scale + 10, scale)
	sc.draw(desk, pid, dx, dy, scale)

	couch := pixelart.environment_for(.couch)
	if w >= 260 {
		sc.draw(couch, pid, x + 10, y + h - couch.height() * scale - 40, scale)
	}
	plant := pixelart.environment_for(.plant)
	sc.draw(plant, pid, x + w - plant.width() * scale - 12, y + h - plant.height() * scale - 8, scale)
	sc.draw(plant, pid, x + 12, base - plant.height() * scale, scale)
	lamp := pixelart.environment_for(.lamp)
	sc.draw(lamp, pid, x + w - lamp.width() * scale - 16, base - lamp.height() * scale, scale)
	nest := pixelart.environment_for(.nest)
	sc.draw(nest, pid, x + 14, y + 8, scale - 1)
}

// ── interaction (single source of geometry, shared with drawing) ────────────

fn onboarding_click(mut app GuiApp, mx int, my int, w int, h int) bool {
	l := onb_layout(app, w, h)
	// step medallions jump to a visited stage only — never skip work forward
	for i in 0 .. onb_stages.len {
		sx, sy, sw, sh := onb_step_rect(l, i)
		if onb_hit(mx, my, sx, sy, sw, sh) && i <= app.onboarding_step {
			app.onboarding_step = i
			app.onboarding_msg = '${onb_stages[i]} — ${onb_stage_hints[i]}'
			return true
		}
	}
	bx, by, bw, bh := onb_back_rect(l)
	if app.onboarding_step > 0 && onb_hit(mx, my, bx, by, bw, bh) {
		app.onboarding_step--
		return true
	}
	nx, ny, nw, nh := onb_next_rect(l)
	if onb_hit(mx, my, nx, ny, nw, nh) {
		onboarding_advance(mut app)
		return true
	}
	sx2, sy2, sw2, sh2 := onb_skip_rect(l)
	if onb_hit(mx, my, sx2 - 4, sy2 - 4, sw2 + 8, sh2 + 8) {
		app.show_onboarding = false
		if app.selected_panel == 11 {
			app.selected_panel = 0
		}
		app.onboarding_msg = 'Setup skipped — press o to resume'
		return true
	}
	dx, dy, dw, dh := onb_diag_rect(l)
	if onb_hit(mx, my, dx - 4, dy - 4, dw + 8, dh + 8) {
		app.onb_diag = !app.onb_diag
		return true
	}
	// simplified onboarding sidebar rows — Get Started is the active row and
	// stays put; Help/Settings are decorative during first run (no
	// navigation surface exists to jump to yet without leaving the journey)
	// every sheet on the board is live, not only the active one
	for i in 0 .. onb_choices.len {
		cx, cy, cw, ch := onb_card_rect(l, 0, i, onb_choices.len)
		if onb_hit(mx, my, cx, cy, cw, ch) {
			app.onb_choice = i
			app.onboarding_step = 0
			app.onboarding_msg = onb_choices[i]
			return true
		}
	}
	rx, ry, rw, rh := onb_rescan_rect(l)
	if onb_hit(mx, my, rx, ry, rw, rh) {
		cat := app.desktop.engine_tool_discovery_catalog()
		app.onboarding_step = 1
		app.onboarding_msg = 'Rescanned — ${cat.filter(it.found).len} of ${cat.len} tools found'
		return true
	}
	for i in 0 .. onb_ws_choices.len {
		cx, cy, cw, ch := onb_card_rect(l, 2, i, onb_ws_choices.len)
		if onb_hit(mx, my, cx, cy, cw, ch) {
			app.onb_ws_choice = i
			app.onboarding_step = 2
			app.onboarding_msg = onb_ws_choices[i]
			return true
		}
	}
	for i in 0 .. onb_caps.len {
		cx, cy, cw, ch := onb_cap_rect(l, i)
		if onb_hit(mx, my, cx, cy, cw, ch) {
			app.onb_cap_on[i] = !app.onb_cap_on[i]
			app.onboarding_step = 3
			return true
		}
	}
	cx4, cy4, cw4, ch4 := onb_cta_rect(l)
	if onb_hit(mx, my, cx4, cy4, cw4, ch4) {
		app.onboarding_step = onb_last_stage
		onboarding_advance(mut app)
		return true
	}
	// clicking a sheet focuses its stage so Next commits the right work
	for i in 0 .. onb_stages.len {
		sx3, sy3, sw3, sh3 := onb_sec_rect(l, i)
		if onb_hit(mx, my, sx3, sy3, sw3, sh3) {
			app.onboarding_step = i
			return true
		}
	}
	// clicks inside the onboarding surface never fall through to the panel below
	return onb_hit(mx, my, l.fx - 16, l.fy, l.fw + 32, l.fh)
		|| onb_hit(mx, my, 0, 0, dock_w, app.gg.height)
}

fn onboarding_hover_at(mut app GuiApp, mx int, my int, w int, h int) {
	l := onb_layout(app, w, h)
	app.onboarding_hover = -1
	bx, by, bw, bh := onb_back_rect(l)
	if onb_hit(mx, my, bx, by, bw, bh) {
		app.onboarding_hover = 10
	}
	nx, ny, nw, nh := onb_next_rect(l)
	if onb_hit(mx, my, nx, ny, nw, nh) {
		app.onboarding_hover = 11
	}
	sx, sy, sw, sh := onb_skip_rect(l)
	if onb_hit(mx, my, sx - 4, sy - 4, sw + 8, sh + 8) {
		app.onboarding_hover = 12
	}
	dxr, dyr, dwr, dhr := onb_diag_rect(l)
	if onb_hit(mx, my, dxr - 4, dyr - 4, dwr + 8, dhr + 8) {
		app.onboarding_hover = 13
	}
	rx, ry, rw, rh := onb_rescan_rect(l)
	if onb_hit(mx, my, rx, ry, rw, rh) {
		app.onboarding_hover = 20
	}
	cx, cy, cw, ch := onb_cta_rect(l)
	if onb_hit(mx, my, cx, cy, cw, ch) {
		app.onboarding_hover = 30
	}
}

// onboarding_advance commits the current stage's real Engine work and moves on.
// Every stage owns its own transaction — nothing is deferred to a fake final
// apply, so the CTA honestly finishes the journey instead of pretending to
// perform everything at once.
fn onboarding_advance(mut app GuiApp) {
	onb_apply_stage(mut app)
	if app.onboarding_step < onb_last_stage {
		app.onboarding_step++
		return
	}
	rev := app.desktop.onboarding_complete(app.harness_root) or {
		app.onboarding_msg = 'Finish failed: ${err}'
		return
	}
	app.engine_rev = app.desktop.app_state_snapshot().revision
	app.api_calls = app.desktop.engine_api_calls()
	app.onboarding_msg = 'Setup complete — welcome to the office (rev ${rev})'
	app.workspace_initialized = app.desktop.onboarding_status(app.harness_root).workspace_exists
	app.show_onboarding = false
	app.selected_panel = 0
	app.onb_diag = false
}

fn onb_apply_stage(mut app GuiApp) {
	harness := if app.onboarding_harness != '' { app.onboarding_harness } else { app.harness_root }
	match app.onboarding_step {
		1 {
			cat := app.desktop.engine_tool_discovery_catalog_cached()
			mut ids := cat.filter(it.found).map(it.id)
			if ids.len == 0 {
				ids = ['claude-code', 'opencode', 'cursor']
			}
			rev := app.desktop.onboarding_set_targets_bulk(ids) or {
				app.onboarding_msg = 'Tools: ${err}'
				return
			}
			app.onboarding_msg = '${ids.len} tools enabled (rev ${rev})'
		}
		2 {
			if app.onb_ws_choice == 0 {
				rev := app.desktop.onboarding_init_with_templates(harness, false) or {
					app.onboarding_msg = 'Workspace: ${err}'
					return
				}
				app.onboarding_msg = 'Workspace ready at ${harness} (rev ${rev})'
			} else {
				rev := app.desktop.onboarding_ensure_workspace(harness) or {
					app.onboarding_msg = 'Workspace: ${err}'
					return
				}
				app.onboarding_msg = 'Workspace connected (rev ${rev})'
			}
			app.workspace_initialized = app.desktop.onboarding_status(harness).workspace_exists
		}
		3 {
			cat := app.desktop.engine_skills_search('', '')
			mut ids := []string{}
			for s in cat {
				if ids.len >= 5 {
					break
				}
				ids << s.id
			}
			if ids.len > 0 {
				rev := app.desktop.onboarding_bulk_install_skills(ids) or {
					app.onboarding_msg = 'Capabilities: ${err}'
					return
				}
				app.onboarding_msg = '${ids.len} skills installed (rev ${rev})'
			}
			app.desktop.onboarding_set_products_bulk(['agent-toolkit-core']) or {}
		}
		4 {
			rev := app.desktop.onboarding_ensure_personas(harness) or {
				app.onboarding_msg = 'Personas: ${err}'
				return
			}
			app.onboarding_msg = 'Personas bootstrapped (rev ${rev})'
		}
		else {}
	}
	app.engine_rev = app.desktop.app_state_snapshot().revision
	app.api_calls = app.desktop.engine_api_calls()
}
