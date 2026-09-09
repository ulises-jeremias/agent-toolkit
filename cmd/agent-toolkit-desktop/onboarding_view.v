module main

import gg
import time
import desktop.pixelart
import desktop_engine

// VC4 (#1173) — Paper Co. setup journey.
//
// Canonical visual reference: docs/desktop/assets/design/onboarding.jpg with
// concept-board.jpg as the shell/material authority. The composition is an
// editorial masthead, a welcome header, a five-step progress strip, illustrated
// setup sheets, and a dedicated "Your setup so far" preview column that
// replaces the Office inspector while onboarding owns the screen.
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

const onb_choice_copy = ['Detect tools, set up a workspace, enable capabilities.',
	'Connect to a setup you already configured.', 'Search this computer for existing workspaces.']

// workspace cards (stage 2)
const onb_ws_choices = ['Create workspace', 'Reuse a workspace']

const onb_ws_copy = ['Fresh workspace, recommended structure.', 'Use a folder you already have.']

// recommended capabilities (stage 3) — labels are user-facing, the sub-line is
// the real catalog fact behind each one
const onb_caps = ['Multi-agent collaboration (MCP)', 'Task planning and execution', 'Workspace memory',
	'Observability and insights']

// OnbLayout is computed once per frame and reused by drawing, clicking and
// hovering, so the interactive geometry can never drift from the drawn one.
struct OnbLayout {
	fx        int
	fy        int
	fw        int
	fh        int
	mast_x    int // masthead spans the full board width (body + preview)
	mast_w    int
	head_h    int // masthead band
	board_top int // fy + head_h — where both body and preview sheets start
	welc_y    int // welcome header
	step_y    int // progress strip
	body_y    int
	body_h    int
	foot_y    int
	side_x    int // preview column (own surface, replaces the inspector)
	side_w    int
	side_h    int
	compact   bool
	active    int // current stage — the only one shown full-width when compact
}

fn onb_layout(app &GuiApp, w int, h int) OnbLayout {
	term_h := if app.term_visible { app.term_height } else { 0 }
	fy := 52
	fh := h - 52 - 28 - term_h
	side_w := if w >= 1180 { inspector_w } else { 0 }
	fx := panel_fx(app)
	fw := w - (dock_w + 8) - side_w
	compact := fw < 660 || fh < 560
	// the masthead is one banner spanning body + preview, like the reference's
	// hero strip above the whole app screenshot — not squeezed into the body
	// column alone
	head_h := if compact {
		0
	} else if fw + side_w >= 900 { 56 } else { 48 }
	board_top := fy + head_h
	welc_y := board_top + 3
	welc_h := if compact { 30 } else { 36 }
	step_y := welc_y + welc_h
	body_y := step_y + 26
	foot_y := fy + fh - 28
	return OnbLayout{
		fx: fx
		fy: fy
		fw: fw
		fh: fh
		mast_x: fx
		mast_w: fw + side_w - 12
		head_h: head_h
		board_top: board_top
		welc_y: welc_y
		step_y: step_y
		body_y: body_y
		body_h: foot_y - body_y - 8
		foot_y: foot_y
		side_x: if app.lang.is_rtl() { 0 } else { w - side_w }
		side_w: side_w
		side_h: fh - head_h
		compact: compact
		active: app.onboarding_step
	}
}

// ── shared rects ────────────────────────────────────────────────────────────

// onb_sec_rect returns the sheet rectangle for section i (0..4) in the
// reference's board layout: sections 1/2 on the top row, 3/4 below, and the
// review strip spanning the full width underneath.
fn onb_sec_rect(l OnbLayout, i int) (int, int, int, int) {
	// compact: recompose rather than shrink — only the active stage renders,
	// full-width, like a focused single-stage view. Inactive stages return a
	// degenerate rect so their cards/hit-tests are inert, not overlapping.
	if l.compact {
		if i == l.active {
			return l.fx + 16, l.body_y, l.fw - 32, l.body_h
		}
		return l.fx, l.body_y, 0, 0
	}
	gap := 10
	cols := if l.fw >= 700 { 2 } else { 1 }
	total := l.fw - 32 - (cols - 1) * gap
	// 55/45 split: choices and workspace get the room the illustrations need
	cw0 := if cols == 2 { total * 55 / 100 } else { total }
	cw1 := total - cw0
	avail := l.foot_y - l.body_y - 6
	// review always reserves enough for its header + all five facts stacked
	// above the CTA button (22 + 5*14 rows + 12 clearance + 40 button) so the
	// Personas row can never clip, regardless of overall window height
	rev_h := 138
	rows_h := avail - rev_h - gap
	// the decision row is taller: illustration + title + copy needs the room
	rh0 := if cols == 2 { (rows_h - gap) * 54 / 100 } else { (rows_h - 3 * gap) / 4 }
	rh1 := if cols == 2 { rows_h - gap - rh0 } else { rh0 }
	if i == 4 {
		return l.fx + 16, l.body_y + rows_h + gap, l.fw - 32, rev_h
	}
	col := if cols == 2 { i % 2 } else { 0 }
	row := if cols == 2 { i / 2 } else { i }
	cx := if col == 0 { l.fx + 16 } else { l.fx + 16 + cw0 + gap }
	cy := if row == 0 { l.body_y } else { l.body_y + rh0 + gap }
	return cx, cy, if col == 0 { cw0 } else { cw1 }, if row == 0 { rh0 } else { rh1 }
}

fn onb_step_rect(l OnbLayout, i int) (int, int, int, int) {
	cw := (l.fw - 32) / onb_stages.len
	return l.fx + 16 + i * cw, l.step_y, cw, 34
}

// decision cards inside a section sheet (setup choice, workspace)
fn onb_card_rect(l OnbLayout, sec int, i int, total int) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, sec)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	gap := 8
	cw := (sw - 24 - (total - 1) * gap) / total
	mut ch := sh - 46
	if ch < 68 {
		ch = 68 // floor: art + title + one copy line never overlap each other
	}
	return sx + 12 + i * (cw + gap), sy + 34, cw, ch
}

// tool discovery cards inside section 1, two columns
fn onb_tool_rect(l OnbLayout, i int) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, 1)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	gap := 8
	cols := 2
	cw := (sw - 24 - gap) / cols
	rows := 2
	mut ch := (sh - 44 - (rows - 1) * gap) / rows
	if ch < 54 {
		ch = 54 // floor: name + path + pill never compress into overlap
	}
	col := i % cols
	row := i / cols
	return sx + 12 + col * (cw + gap), sy + 34 + row * (ch + gap), cw, ch
}

fn onb_cap_rect(l OnbLayout, i int) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, 3)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	mut rh := (sh - 44) / onb_caps.len
	if rh < 26 {
		rh = 26 // floor: checkbox + label never overlap the row beneath it
	}
	return sx + 12, sy + 32 + i * rh, sw - 24, rh - 4
}

fn onb_cta_rect(l OnbLayout) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, 4)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	cw := if sw > 460 { 320 } else { sw - 24 }
	return sx + sw - 12 - cw, sy + sh - 40, cw, 32
}

fn onb_next_rect(l OnbLayout) (int, int, int, int) {
	return l.fx + l.fw - 104, l.foot_y + 2, 88, 26
}

fn onb_back_rect(l OnbLayout) (int, int, int, int) {
	return l.fx + l.fw - 196, l.foot_y + 2, 84, 26
}

fn onb_skip_rect(l OnbLayout) (int, int, int, int) {
	return l.fx + 16, l.foot_y + 2, 66, 26
}

fn onb_diag_rect(l OnbLayout) (int, int, int, int) {
	return l.fx + 92, l.foot_y + 2, 86, 26
}

fn onb_rescan_rect(l OnbLayout) (int, int, int, int) {
	sx, sy, sw, sh := onb_sec_rect(l, 1)
	if sh < 40 {
		return 0, 0, 0, 0
	}
	return sx + sw - 90, sy + 6, 78, 22
}

// onb_art_scale keeps pixel art integral: the largest whole multiplier that
// fits the available band, never a stretched sprite.
fn onb_art_scale(sw int, sh int, aw int, ah int) int {
	mut sc := 1
	for m := 6; m >= 1; m-- {
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
	} else if size <= 12 { 6 } else { 7 }
	n := px / adv
	return if n < 4 { 4 } else { n }
}

fn onb_hit(mx int, my int, x int, y int, w int, h int) bool {
	return mx >= x && mx < x + w && my >= y && my < y + h
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
	mut sc := app.pixel_cache
	st := app.desktop.onboarding_status(app.harness_root)

	// warm paper world behind the whole journey
	app.gg.draw_rect_filled(l.fx, l.fy, l.fw, l.fh, app.pnl_bg)

	if !l.compact {
		draw_onb_masthead(mut app, l, pid)
	}
	draw_onb_welcome(mut app, l, pid)
	draw_onb_steps(mut app, l)

	// the reference is a board, not a one-screen-at-a-time wizard: all five
	// setup sheets are on the desk at once and the active one is framed
	for i in 0 .. onb_stages.len {
		sx, sy, sw, sh := onb_sec_rect(l, i)
		if sh < 40 {
			continue
		}
		pixel_panel(mut app, sx, sy, sw, sh, 'default')
		if i == app.onboarding_step {
			app.gg.draw_rect_empty(sx + 1, sy + 1, sw - 2, sh - 2, app.pnl_select)
			app.gg.draw_rect_filled(sx + 1, sy + 1, sw - 2, 2, app.pnl_select)
		}
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
	_ = sc
}

// masthead: one editorial banner spanning body + preview, like the hero strip
// above the whole app screenshot in concept-board.jpg / onboarding.jpg — not
// squeezed into the body column alone.
fn draw_onb_masthead(mut app GuiApp, l OnbLayout, pid pixelart.PaletteId) {
	mut sc := app.pixel_cache
	x := l.mast_x
	mw := l.mast_w
	y := l.fy + 3
	// the banner spans body + preview: paint its full background first, or
	// the strip above the preview column stays the app's dark base color
	app.gg.draw_rect_filled(x, l.fy, mw, l.head_h, app.pnl_bg)
	app.gg.draw_text(x + 46, y, 'Agent Toolkit Desktop', gg.TextCfg{
		color: app.pnl_text
		size: 22
		family: app.fonts.display
	})
	app.gg.draw_text(x + 48, y + 24, 'A  H O M E   F O R   Y O U R   A I   A G E N T S', gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
	})
	app.gg.draw_line(x + 46, y + 21, x + 380, y + 21, app.pnl_border)
	app.gg.draw_text(x + 46, y + 30, 'PLAN · BUILD · DELEGATE · OBSERVE · TOGETHER', gg.TextCfg{
		color: app.pnl_text_mut
		size: 9
		bold: true
	})
	// small botanical accent left of the title
	plant := pixelart.environment_for(.plant)
	sc.draw(plant, pid, x, y - 2, 2)

	// right-side editorial rhythm — gated by the width actually available so
	// it never crowds; each column is its own short, honest tagline
	if mw >= 620 {
		nest := pixelart.environment_for(.nest)
		nx := x + mw - 150
		sc.draw(nest, pid, nx, y - 1, 2)
		app.gg.draw_text(nx + 44, y, 'Small Agents', gg.TextCfg{
			color: app.pnl_text
			size: 12
			family: app.fonts.display
		})
		app.gg.draw_text(nx + 44, y + 15, 'Brighter Worlds.', gg.TextCfg{
			color: app.pnl_text
			size: 12
			family: app.fonts.display
		})
		app.gg.draw_text(nx + 44, y + 32, 'INSPIRED BY NATURE.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 8
		})
		app.gg.draw_text(nx + 44, y + 42, 'BUILT FOR BUILDERS.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 8
		})
	}
	if mw >= 860 {
		cx := x + mw - 460
		app.gg.draw_text(cx, y, 'SAME', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
			bold: true
		})
		app.gg.draw_text(cx, y + 12, 'CURIOSITY.', gg.TextCfg{
			color: app.pnl_text
			size: 10
			bold: true
		})
		app.gg.draw_text(cx, y + 26, 'MORE', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
			bold: true
		})
		app.gg.draw_text(cx, y + 38, 'CAPABILITY.', gg.TextCfg{
			color: app.pnl_text
			size: 10
			bold: true
		})
	}
	app.gg.draw_line(l.fx + 12, l.fy + l.head_h - 2, x + mw, l.fy + l.head_h - 2, app.pnl_border)
}

fn draw_onb_welcome(mut app GuiApp, l OnbLayout, pid pixelart.PaletteId) {
	mut sc := app.pixel_cache
	y := l.welc_y
	if !l.compact {
		pot := pixelart.environment_for(.plant)
		sc.draw(pot, pid, l.fx + 16, y - 1, 2)
	}
	tx := if l.compact { l.fx + 16 } else { l.fx + 60 }
	app.gg.draw_text(tx, y, 'Welcome to', gg.TextCfg{
		color: app.pnl_text_mut
		size: 12
	})
	app.gg.draw_text(tx, y + 14, 'Agent Toolkit Desktop', gg.TextCfg{
		color: app.pnl_text
		size: 19
		family: app.fonts.display
	})
	if !l.compact && l.fw > 720 {
		app.gg.draw_text(tx + 220, y + 18, "Let's get you set up — a few quick steps and you'll be building with agents.", gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	}
	// real local date and time — never the reference's fictional date
	now := time.now()
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	mname := if now.month >= 1 && now.month <= 12 { months[now.month - 1] } else { '' }
	stamp := '${mname} ${now.day}, ${now.year}'
	clock := '${now.hour:02d}:${now.minute:02d}'
	if l.fw > 560 {
		app.gg.draw_text(l.fx + l.fw - 92, y - 1, stamp, gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		app.gg.draw_text(l.fx + l.fw - 92, y + 13, clock, gg.TextCfg{
			color: app.pnl_text
			size: 18
			family: app.fonts.display
		})
	}
}

fn draw_onb_steps(mut app GuiApp, l OnbLayout) {
	for i, name in onb_stages {
		sx, sy, sw, _ := onb_step_rect(l, i)
		done := i < app.onboarding_step
		here := i == app.onboarding_step
		// connector rule between the medallions
		if i > 0 {
			app.gg.draw_line(sx - 14, sy + 14, sx + 2, sy + 14, app.pnl_border)
		}
		md := 22
		mx0 := sx + 6
		my0 := sy + 3
		fill := if here {
			app.pnl_select
		} else if done {
			app.pnl_success
		} else {
			app.pnl_card
		}
		app.gg.draw_rect_filled(mx0 + 2, my0 + 2, md, md, tint(col_ink, 30))
		app.gg.draw_rect_filled(mx0, my0, md, md, fill)
		app.gg.draw_rect_empty(mx0, my0, md, md, if here || done {
			fill
		} else {
			app.pnl_border
		})
		if done {
			onb_check(mut app, mx0 + 6, my0 + 5, app.pnl_bg)
		} else {
			app.gg.draw_text(mx0 + 7, my0 + 4, '${i + 1}', gg.TextCfg{
				color: if here { app.pnl_bg } else { app.pnl_text_mut }
				size: 13
				bold: true
			})
		}
		app.gg.draw_text(sx + 6 + md + 8, sy + 4, name, gg.TextCfg{
			color: if here { app.pnl_text } else { app.pnl_text_mut }
			size: 13
			bold: here
		})
		hint_px := sw - (md + 14)
		if hint_px > 40 {
			app.gg.draw_text(sx + 6 + md + 8, sy + 20, utf8_truncate(onb_stage_hints[i], onb_fit(hint_px, 11)), gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
		}
	}
}

fn draw_onb_sheet_title(mut app GuiApp, l OnbLayout, sec int, title string, sub string) {
	sx, sy, sw, _ := onb_sec_rect(l, sec)
	app.gg.draw_text(sx + 12, sy + 8, '${sec + 1}. ${title}', gg.TextCfg{
		color: app.pnl_text
		size: font_body_sm
		family: app.fonts.display
	})
	if sub != '' && sw > 260 {
		app.gg.draw_text(sx + 12, sy + 24, utf8_truncate(sub, (sw - 110) / 6), gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
	}
}

// stage 0 — three illustrated choices
fn draw_onb_choice(mut app GuiApp, l OnbLayout, pid pixelart.PaletteId) {
	if l.compact && l.active != 0 {
		return
	}
	mut sc := app.pixel_cache
	draw_onb_sheet_title(mut app, l, 0, 'How would you like to get started?', '')
	arts := [pixelart.EnvironmentAsset.welcome_desk, .cabinet, .board]
	for i, title in onb_choices {
		cx, cy, cw, ch := onb_card_rect(l, 0, i, onb_choices.len)
		sel := app.onb_choice == i
		pixel_panel(mut app, cx, cy, cw, ch, if sel { 'inset' } else { 'default' })
		if sel {
			app.gg.draw_rect_empty(cx + 1, cy + 1, cw - 2, ch - 2, app.pnl_success)
		}
		// radio
		app.gg.draw_rect_filled(cx + 8, cy + 8, 12, 12, app.pnl_bg)
		app.gg.draw_rect_empty(cx + 8, cy + 8, 12, 12, app.pnl_border_hi)
		if sel {
			app.gg.draw_rect_filled(cx + 11, cy + 11, 6, 6, app.pnl_success)
		}
		art := pixelart.environment_for(arts[i])
		mut band := ch - 66
		if band > ch * 46 / 100 {
			band = ch * 46 / 100
		}
		if band < 30 {
			band = 30
		}
		scale := onb_art_scale(art.width(), art.height(), cw - 16, band - 6)
		sc.draw(art, pid, cx + (cw - art.width() * scale) / 2, cy + 6 + (band - art.height() * scale) / 2, scale)
		ty := cy + band + 8
		cy2 := onb_wrapped_title(mut app, cx + 10, ty, cw - 18, title)
		mut lines := (cy + ch - 6 - cy2) / 12
		if lines > 2 {
			lines = 2
		}
		draw_onb_wrapped(mut app, cx + 10, cy2, cw - 18, onb_choice_copy[i], lines)
	}
}

// stage 1 — tool discovery as product UI, not a diagnostic dump
fn draw_onb_tools(mut app GuiApp, l OnbLayout) {
	if l.compact && l.active != 1 {
		return
	}
	cat := app.desktop.engine_tool_discovery_catalog_cached()
	found := cat.filter(it.found).len
	draw_onb_sheet_title(mut app, l, 1, 'Detected developer tools', '${found} of ${cat.len} found on this computer')
	rx, ry, rw, rh := onb_rescan_rect(l)
	pixel_panel(mut app, rx, ry, rw, rh, if app.onboarding_hover == 20 {
		'inset'
	} else {
		'default'
	})
	app.gg.draw_text(rx + 18, ry + 5, '⟳ Rescan', gg.TextCfg{
		color: app.pnl_text
		size: 12
	})
	_, ssy, _, ssh := onb_sec_rect(l, 1)
	// detected tools first — an empty machine still shows the roster honestly
	mut roster := cat.filter(it.found)
	roster << cat.filter(!it.found)
	mut shown := 0
	for t in roster {
		if shown >= 4 {
			break
		}
		cx, cy, cw, ch := onb_tool_rect(l, shown)
		if cy + ch > ssy + ssh - 6 {
			break
		}
		pixel_panel(mut app, cx, cy, cw, ch, 'default')
		// tool medallion
		app.gg.draw_rect_filled(cx + 8, cy + 9, 22, 22, app.pnl_card_sel)
		app.gg.draw_rect_empty(cx + 8, cy + 9, 22, 22, app.pnl_border)
		initial := if t.display_name.len > 0 { t.display_name[0..1].to_upper() } else { '?' }
		app.gg.draw_text(cx + 15, cy + 13, initial, gg.TextCfg{
			color: app.pnl_text
			size: 14
			family: app.fonts.display
		})
		label := if t.found { 'Ready' } else { 'Missing' }
		pill_c := if t.found { app.pnl_success } else { app.pnl_text_mut }
		name_px := cw - 34 - (label.len * 6 + 8) - 4
		app.gg.draw_text(cx + 36, cy + 8, utf8_truncate(t.display_name, onb_fit(name_px, 12)), gg.TextCfg{
			color: app.pnl_text
			size: 12
			bold: true
		})
		// truthful status pill
		pw := label.len * 6 + 12
		app.gg.draw_rect_filled(cx + cw - pw - 8, cy + 8, pw, 15, tint(pill_c, 60))
		app.gg.draw_rect_empty(cx + cw - pw - 8, cy + 8, pw, 15, pill_c)
		app.gg.draw_text(cx + cw - pw - 2, cy + 10, label, gg.TextCfg{
			color: pill_c
			size: 10
		})
		detail := if t.found {
			t.resolved_path
		} else {
			'Install to enable seamless integration'
		}
		app.gg.draw_text(cx + 36, cy + 24, utf8_truncate(detail, onb_fit(cw - 46, 10)), gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
			mono: t.found
		})
		shown++
	}
	if cat.len > shown {
		app.gg.draw_text(l.fx + 16, ssy + ssh - 14, '', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
		sx1, sy1, sw1, sh1 := onb_sec_rect(l, 1)
		app.gg.draw_text(sx1 + sw1 - 150, sy1 + sh1 - 13, '+${cat.len - shown} more in Settings → Targets', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
	}
}

// stage 2 — where the agents live
fn draw_onb_workspace(mut app GuiApp, l OnbLayout, pid pixelart.PaletteId, st desktop_engine.OnboardingStatus) {
	if l.compact && l.active != 2 {
		return
	}
	mut sc := app.pixel_cache
	draw_onb_sheet_title(mut app, l, 2, 'Workspace setup', 'Where your agents, tasks and data live')
	arts := [pixelart.EnvironmentAsset.welcome_desk, .cabinet]
	for i, title in onb_ws_choices {
		cx, cy, cw, ch := onb_card_rect(l, 2, i, onb_ws_choices.len)
		sel := app.onb_ws_choice == i
		pixel_panel(mut app, cx, cy, cw, ch, if sel { 'inset' } else { 'default' })
		if sel {
			app.gg.draw_rect_empty(cx + 1, cy + 1, cw - 2, ch - 2, app.pnl_success)
		}
		app.gg.draw_rect_filled(cx + 8, cy + 8, 12, 12, app.pnl_bg)
		app.gg.draw_rect_empty(cx + 8, cy + 8, 12, 12, app.pnl_border_hi)
		if sel {
			app.gg.draw_rect_filled(cx + 11, cy + 11, 6, 6, app.pnl_success)
		}
		art := pixelart.environment_for(arts[i])
		mut band := ch - 62
		if band > ch * 46 / 100 {
			band = ch * 46 / 100
		}
		if band < 28 {
			band = 28
		}
		scale := onb_art_scale(art.width(), art.height(), cw - 16, band - 6)
		sc.draw(art, pid, cx + (cw - art.width() * scale) / 2, cy + 4 + (band - art.height() * scale) / 2, scale)
		ty := cy + band + 4
		wy := onb_wrapped_title(mut app, cx + 10, ty, cw - 18, title)
		mut wlines := (cy + ch - 6 - wy) / 12
		if wlines > 2 {
			wlines = 2
		}
		draw_onb_wrapped(mut app, cx + 10, wy, cw - 18, onb_ws_copy[i], wlines)
	}
	sx, sy, sw, sh := onb_sec_rect(l, 2)
	path := if app.onboarding_harness != '' { app.onboarding_harness } else { app.harness_root }
	state := if st.workspace_exists { 'ready' } else { 'not created yet' }
	app.gg.draw_text(sx + 12, sy + sh - 16, utf8_truncate(path, (sw - 120) / 6), gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
		mono: true
	})
	app.gg.draw_text(sx + sw - 16 - state.len * 6, sy + sh - 16, state, gg.TextCfg{
		color: if st.workspace_exists { app.pnl_success } else { app.pnl_text_mut }
		size: 10
	})
}

// stage 3 — recommended capabilities in user language, real catalog facts
fn draw_onb_capabilities(mut app GuiApp, l OnbLayout) {
	if l.compact && l.active != 3 {
		return
	}
	draw_onb_sheet_title(mut app, l, 3, 'Recommended capabilities', 'A great starting point — change these later')
	_, s3y, _, s3h := onb_sec_rect(l, 3)
	for i, name in onb_caps {
		cx, cy, cw, ch := onb_cap_rect(l, i)
		if cy + ch > s3y + s3h - 4 {
			break
		}
		on := app.onb_cap_on[i]
		app.gg.draw_rect_filled(cx, cy, cw, ch, if on { app.pnl_card } else { app.pnl_bg })
		app.gg.draw_rect_empty(cx, cy, cw, ch, app.pnl_border)
		app.gg.draw_rect_filled(cx + 10, cy + (ch - 16) / 2, 16, 16, if on {
			app.pnl_success
		} else {
			app.pnl_card_sel
		})
		app.gg.draw_rect_empty(cx + 10, cy + (ch - 16) / 2, 16, 16, if on {
			app.pnl_success
		} else {
			app.pnl_border_hi
		})
		if on {
			onb_check(mut app, cx + 13, cy + (ch - 16) / 2 + 3, app.pnl_bg)
		}
		app.gg.draw_text(cx + 34, cy + 4, utf8_truncate(name, onb_fit(cw - 44, 12)), gg.TextCfg{
			color: app.pnl_text
			size: 12
			bold: true
		})
		if ch >= 34 {
			app.gg.draw_text(cx + 34, cy + 18, utf8_truncate(onb_cap_fact(mut app, i), onb_fit(cw - 44, 10)), gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
			})
		}
	}
}

// stage 4 — truthful summary + finish
fn draw_onb_review(mut app GuiApp, l OnbLayout, st desktop_engine.OnboardingStatus) {
	if l.compact && l.active != 4 {
		return
	}
	draw_onb_sheet_title(mut app, l, 4, 'Review and finish', '')
	cat := app.desktop.engine_tool_discovery_catalog_cached()
	found := cat.filter(it.found)
	tools := if found.len == 0 {
		'none detected'
	} else if found.len <= 2 {
		found.map(it.display_name).join(', ')
	} else {
		'${found[0].display_name}, ${found[1].display_name} +${found.len - 2} more'
	}
	caps_on := app.onb_cap_on.filter(it).len
	rows := [
		['Setup method', onb_choice_verb(app)],
		['Tools detected', tools],
		['Workspace',
			if st.workspace_exists { app.harness_root } else { onb_ws_choices[app.onb_ws_choice] }],
		['Capabilities',
			'${caps_on} of ${onb_caps.len} enabled · ${st.installed_count} skills installed'],
		['Personas', if st.persona_count > 0 {
			'${st.persona_count} bootstrapped'
		} else {
			'will be created on finish'
		}],
	]
	sx, sy, sw, sh := onb_sec_rect(l, 4)
	// two summary columns keep the strip compact like the reference
	col_w := sw - 24 - 360
	step := 14
	for i, r in rows {
		ry := sy + 22 + i * step
		if ry + 10 > sy + sh - 4 {
			break
		}
		app.gg.draw_text(sx + 12, ry, r[0], gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
		app.gg.draw_text(sx + 104, ry, utf8_truncate(r[1], onb_fit(col_w - 104, 10)), gg.TextCfg{
			color: app.pnl_text
			size: 10
		})
	}
	// primary call to action — the wording matches what really happens: every
	// stage already committed its own transaction, this finalizes onboarding
	cx, cy, cw, ch := onb_cta_rect(l)
	hov := app.onboarding_hover == 30
	app.gg.draw_rect_filled(cx + 3, cy + 3, cw, ch, tint(col_ink, 35))
	app.gg.draw_rect_filled(cx, cy, cw, ch, if hov {
		app.pnl_success
	} else {
		tint(app.pnl_success, 220)
	})
	app.gg.draw_rect_empty(cx, cy, cw, ch, app.pnl_success)
	app.gg.draw_text(cx + 16, cy + 8, 'Finish setup and enter the office  →', gg.TextCfg{
		color: app.pnl_bg
		size: 13
		bold: true
	})
}

fn draw_onb_diagnostics(mut app GuiApp, l OnbLayout, st desktop_engine.OnboardingStatus) {
	dh := 96
	dy := l.foot_y - dh - 6
	pixel_panel(mut app, l.fx + 16, dy, l.fw - 32, dh, 'terminal')
	app.gg.draw_text(l.fx + 28, dy + 6, 'Diagnostics', gg.TextCfg{
		color: app.pnl_text_mut
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
		app.gg.draw_text(l.fx + 28, dy + 24 + i * 16, utf8_truncate(ln, (l.fw - 60) / 6), gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
			mono: true
		})
	}
}

fn draw_onb_footer(mut app GuiApp, l OnbLayout, st desktop_engine.OnboardingStatus) {
	app.gg.draw_line(l.fx + 12, l.foot_y - 4, l.fx + l.fw - 12, l.foot_y - 4, app.pnl_border)
	sx, sy, sw, sh := onb_skip_rect(l)
	pixel_panel(mut app, sx, sy, sw, sh, if app.onboarding_hover == 12 {
		'inset'
	} else {
		'default'
	})
	app.gg.draw_text(sx + 18, sy + 6, 'Skip', gg.TextCfg{
		color: app.pnl_text_mut
		size: 12
	})
	dx, dy, dw, dh := onb_diag_rect(l)
	pixel_panel(mut app, dx, dy, dw, dh, if app.onb_diag { 'inset' } else { 'default' })
	app.gg.draw_text(dx + 10, dy + 6, if app.onb_diag { 'Hide details' } else { 'Details' }, gg.TextCfg{
		color: app.pnl_text_mut
		size: 12
	})
	if app.onboarding_step > 0 {
		bx, by, bw, bh := onb_back_rect(l)
		pixel_panel(mut app, bx, by, bw, bh, if app.onboarding_hover == 10 {
			'inset'
		} else {
			'default'
		})
		app.gg.draw_text(bx + 26, by + 6, 'Back', gg.TextCfg{
			color: app.pnl_text
			size: 12
		})
	}
	nx, ny, nw, nh := onb_next_rect(l)
	is_last := app.onboarding_step >= onb_last_stage
	pixel_panel(mut app, nx, ny, nw, nh, if app.onboarding_hover == 11 {
		'inset'
	} else {
		'default'
	})
	app.gg.draw_text(nx + 18, ny + 6, if is_last { 'Finish' } else { 'Next →' }, gg.TextCfg{
		color: app.pnl_select
		size: 12
		bold: true
	})
	msg := if app.onboarding_msg != '' {
		app.onboarding_msg
	} else {
		'step ${app.onboarding_step + 1} of ${onb_stages.len} · ${st.pending_items.len} pending'
	}
	app.gg.draw_text(l.fx + 190, l.foot_y + 8, utf8_truncate(msg, (l.fw - 420) / 6), gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
	})
}

// onb_wrapped_title lays a card title over up to two lines and returns the
// baseline after it, so long catalog wording is never cut mid-word.
fn onb_wrapped_title(mut app GuiApp, x int, y int, w int, s string) int {
	per := onb_fit(w, 12)
	if s.len <= per {
		app.gg.draw_text(x, y, s, gg.TextCfg{
			color: app.pnl_text
			size: 12
			bold: true
		})
		return y + 15
	}
	mut cut := per
	for cut > 0 && s[cut] != ` ` {
		cut--
	}
	if cut == 0 {
		cut = per
	}
	app.gg.draw_text(x, y, s[..cut], gg.TextCfg{
		color: app.pnl_text
		size: 12
		bold: true
	})
	rest := s[cut + 1..]
	app.gg.draw_text(x, y + 13, utf8_truncate(rest, per), gg.TextCfg{
		color: app.pnl_text
		size: 12
		bold: true
	})
	return y + 28
}

fn draw_onb_wrapped(mut app GuiApp, x int, y int, w int, s string, max_lines int) {
	per := onb_fit(w, 10)
	words := s.split(' ')
	mut line := ''
	mut ln := 0
	for word in words {
		cand := if line == '' { word } else { line + ' ' + word }
		if cand.len > per {
			app.gg.draw_text(x, y + ln * 12, line, gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
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
		app.gg.draw_text(x, y + ln * 12, line, gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
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
	y := l.board_top
	iw := l.side_w
	ih := l.side_h
	app.gg.draw_rect_filled(x, y, iw, ih, app.pnl_bg)
	app.gg.draw_line(x, y, x, y + ih, app.pnl_border)
	app.gg.draw_text(x + 16, y + 10, 'Your setup so far', gg.TextCfg{
		color: app.pnl_text
		size: font_body_md
		family: app.fonts.display
	})

	// illustrated welcome scene — environment only, never runtime state
	sy := y + 34
	sh := if ih > 500 { 236 } else { 190 }
	pixel_panel(mut app, x + 12, sy, iw - 24, sh, 'default')
	draw_onb_scene(mut app, x + 12, sy, iw - 24, sh, pid)
	app.gg.draw_text(x + 18, sy + sh + 6, 'A friendly setup for brighter builders.', gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
	})

	// truthful facts that grow as the journey advances
	mut rows := [][]string{}
	rows << ['Setup', onb_choice_verb(app)]
	cat := app.desktop.engine_tool_discovery_catalog_cached()
	rows << ['Tools', '${cat.filter(it.found).len} of ${cat.len} found']
	rows << ['Workspace', if st.workspace_exists { 'ready' } else { 'not created yet' }]
	rows << ['Skills', '${st.installed_count} installed']
	rows << ['Targets', '${st.enabled_targets_count} enabled']
	rows << ['Personas', '${st.persona_count} bootstrapped']
	ry0 := sy + sh + 24
	for i, r in rows {
		ry := ry0 + i * 20
		if ry + 18 > y + ih - 96 {
			break
		}
		app.gg.draw_text(x + 18, ry, r[0], gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		app.gg.draw_text(x + 110, ry, r[1], gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
	}

	// Hornero editorial card
	qy := y + ih - 84
	if qy > ry0 {
		pixel_panel(mut app, x + 12, qy, iw - 24, 64, 'inset')
		app.gg.draw_text(x + 24, qy + 10, '“A quieter internet can be', gg.TextCfg{
			color: app.pnl_text
			size: 12
			family: app.fonts.display
		})
		app.gg.draw_text(x + 24, qy + 26, 'a kinder place.”', gg.TextCfg{
			color: app.pnl_text
			size: 12
			family: app.fonts.display
		})
		app.gg.draw_text(x + 24, qy + 46, '— The Hornero Principle', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
		nest := pixelart.environment_for(.nest)
		sc.draw(nest, pid, x + iw - 62, qy + 22, 2)
	}
}

// draw_onb_scene composes the welcome office: floor, wall, shelf, sign, desk
// with an idle builder agent, plants and a rug. Static and deterministic.
fn draw_onb_scene(mut app GuiApp, x int, y int, w int, h int, pid pixelart.PaletteId) {
	mut sc := app.pixel_cache
	s := if w >= 250 && h >= 210 { 3 } else { 2 }
	wall_h := h * 42 / 100
	// wall, wainscot and plank floor reuse the Office material grammar
	app.gg.draw_rect_filled(x + 1, y + 1, w - 2, wall_h, pc(app, `p`))
	app.gg.draw_rect_filled(x + 1, y + wall_h, w - 2, h - wall_h - 1, pc(app, `m`))
	for i := 0; i < (h - wall_h) / 9; i++ {
		ly := y + wall_h + 4 + i * 9
		app.gg.draw_line(x + 1, ly, x + w - 2, ly, pc(app, `M`))
		off := if i % 2 == 0 { 0 } else { 26 }
		for jx := x + 8 + off; jx < x + w - 8; jx += 52 {
			app.gg.draw_line(jx, ly, jx, ly + 9, pc(app, `M`))
		}
	}
	app.gg.draw_rect_filled(x + 1, y + wall_h - 3, w - 2, 3, pc(app, `W`))
	base := y + wall_h + 3

	// framed office sign — the reference's wall plate, with our own words
	l1 := 'AGENTS MAKE A KINDER'
	l2 := 'TECH TOMORROW'
	plate_w := l1.len * 6 + 18
	plate_h := 34
	sgx := x + (w - plate_w) / 2
	sgy := y + 10
	app.gg.draw_rect_filled(sgx + 2, sgy + 2, plate_w, plate_h, pc(app, `W`))
	app.gg.draw_rect_filled(sgx, sgy, plate_w, plate_h, pc(app, `p`))
	app.gg.draw_rect_empty(sgx, sgy, plate_w, plate_h, pc(app, `W`))
	app.gg.draw_rect_empty(sgx + 2, sgy + 2, plate_w - 4, plate_h - 4, pc(app, `M`))
	app.gg.draw_text(sgx + 9, sgy + 6, l1, gg.TextCfg{
		color: pc(app, `k`)
		size: 9
		bold: true
	})
	app.gg.draw_text(sgx + 9, sgy + 19, l2, gg.TextCfg{
		color: pc(app, `k`)
		size: 9
		bold: true
	})

	// left wall: shelf with books; right wall: window light + a framed picture
	shelf := pixelart.environment_for(.shelf)
	sc.draw(shelf, pid, x + 8, base - shelf.height() * 2 - 2, 2)
	books := pixelart.environment_for(.books)
	sc.draw(books, pid, x + 10, base - books.height() * 2 - shelf.height() * 2 - 4, 2)
	win := pixelart.environment_for(.window)
	sc.draw(win, pid, x + w - win.width() * 2 - 12, y + 8, 2)
	if w >= 250 {
		picture := pixelart.environment_for(.picture)
		sc.draw(picture, pid, x + w - picture.width() * 2 - 14, y + 32, 2)
	}

	// reception: builder behind the welcome desk, on a rug, a visitor chair
	// opposite — the middle band reads as a room, not a floating prop
	desk := pixelart.environment_for(.welcome_desk)
	chair := pixelart.environment_for(.chair)
	rug := pixelart.environment_for(.rug)
	dx := x + (w - desk.width() * s) / 2
	dy := y + h - desk.height() * s - 14
	rgs := if rug.width() * 2 <= w - 24 { 2 } else { 1 }
	sc.draw(rug, pid, x + (w - rug.width() * rgs) / 2, y + h - rug.height() * rgs - 5, rgs)
	if w >= 220 {
		sc.draw(chair, pid, dx - chair.width() * s - 6, dy + desk.height() * s / 2, s)
	}
	agent := pixelart.with_identity(pixelart.agent_for_state(.idle), 1)
	sc.draw(agent, pid, dx + (desk.width() * s - agent.width() * s) / 2, dy - agent.height() * s + 8, s)
	sc.draw(desk, pid, dx, dy, s)

	// lounge corner + greenery, mirroring the Office grammar
	couch := pixelart.environment_for(.couch)
	if w >= 250 {
		sc.draw(couch, pid, x + 10, y + h - couch.height() * 2 - 34, 2)
	}
	plant := pixelart.environment_for(.plant)
	sc.draw(plant, pid, x + w - plant.width() * 2 - 10, y + h - plant.height() * 2 - 6, 2)
	sc.draw(plant, pid, x + 12, base - plant.height() * 2, 2)
	lamp := pixelart.environment_for(.lamp)
	sc.draw(lamp, pid, x + w - lamp.width() * 2 - 14, base - lamp.height() * 2, 2)
	// nest detail — the Hornero motif watches over the room
	nest := pixelart.environment_for(.nest)
	sc.draw(nest, pid, x + 14, y + 8, 2)
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
	if onb_hit(mx, my, sx2, sy2, sw2, sh2) {
		app.show_onboarding = false
		if app.selected_panel == 11 {
			app.selected_panel = 0
		}
		app.onboarding_msg = 'Setup skipped — press o to resume'
		return true
	}
	dx, dy, dw, dh := onb_diag_rect(l)
	if onb_hit(mx, my, dx, dy, dw, dh) {
		app.onb_diag = !app.onb_diag
		return true
	}
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
	return onb_hit(mx, my, l.fx, l.fy, l.fw, l.fh)
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
	if onb_hit(mx, my, sx, sy, sw, sh) {
		app.onboarding_hover = 12
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
