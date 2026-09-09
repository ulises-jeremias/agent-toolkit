module main

import gg
import os
import time
import desktop.pixelart
import desktop_engine

// VC7 (#1173) — Workspace destination, visual convergence pass.
//
// No dedicated reference exists for Workspace: the composition is derived
// from concept-board.jpg (materials), office.jpg (shell + card grammar) and
// library.jpg (collection/detail grammar). The destination keeps every
// existing action — path field, Validate / Switch / Initialize, known
// workspaces, file tree, editor, git rails, memory palace — and re-composes
// them as one Paper Co. page: editorial header, an "Active workspace" paper
// sheet with a small filing scene, known workspaces as folder cards, the IDE
// block below, and a "Workspace details" column on the right that replaces
// the generic inspector.
//
// Truth: every value here comes from the Engine or a real filesystem check
// (os.exists on the active root). Unknown renders as "—"; empty renders as
// an honest sentence. Nothing is inferred from the illustration.

// WorkspaceLayout is computed once per frame and shared by drawing, click,
// hover and scroll handlers, so a visual reflow can never move a hit target.
struct WorkspaceLayout {
	fx         int
	fy         int
	fw         int
	fh         int
	head_h     int
	hero_y     int
	hero_h     int
	field_x    int
	field_y    int
	field_w    int
	validate_x int
	validate_w int
	switch_x   int
	switch_w   int
	init_x     int
	init_w     int
	scene_x    int // hero illustration; scene_w == 0 when the width cannot afford it
	scene_w    int
	known_y    int
	known_h    int
	mid_y      int // IDE block: file tree | editor | git rails
	mid_h      int
	mem_y      int // memory palace strip
	mem_h      int
	compact    bool
}

// ws_tree_w / ws_git_w are the IDE column widths the existing file-tree,
// editor and git-rail handlers in main.v hit-test against.
const ws_tree_w = 180
const ws_git_w = 240

fn workspace_layout(app &GuiApp, w int, h int) WorkspaceLayout {
	fx := panel_fx(app)
	fy := 52
	fw := panel_fw(app, w)
	term_h := if app.term_visible { app.term_height } else { 0 }
	fh := h - fy - 28 - term_h
	compact := fh < 520 || fw < 640
	head_h := if compact { 44 } else { 60 }
	hero_y := fy + head_h + 4
	hero_h := if compact { 84 } else { 112 }
	scene_w := if !compact && fw >= 720 { 200 } else { 0 }
	scene_x := fx + fw - 12 - scene_w
	right := if scene_w > 0 { scene_x - 12 } else { fx + fw - 24 }
	init_w := 78
	switch_w := 62
	validate_w := 68
	init_x := right - init_w
	switch_x := init_x - 6 - switch_w
	validate_x := switch_x - 6 - validate_w
	field_x := fx + 24
	field_y := hero_y + if compact { 30 } else { 46 }
	mut field_w := validate_x - 8 - field_x
	if field_w < 120 {
		field_w = 120
	}
	known_y := hero_y + hero_h + 8
	known_h := if compact { 46 } else { 78 }
	mem_h := if compact { 44 } else { 92 }
	mem_y := fy + fh - mem_h - 8
	mid_y := known_y + known_h + 8
	mut mid_h := mem_y - 8 - mid_y
	if mid_h < 100 {
		mid_h = 100
	}
	return WorkspaceLayout{
		fx: fx
		fy: fy
		fw: fw
		fh: fh
		head_h: head_h
		hero_y: hero_y
		hero_h: hero_h
		field_x: field_x
		field_y: field_y
		field_w: field_w
		validate_x: validate_x
		validate_w: validate_w
		switch_x: switch_x
		switch_w: switch_w
		init_x: init_x
		init_w: init_w
		scene_x: scene_x
		scene_w: scene_w
		known_y: known_y
		known_h: known_h
		mid_y: mid_y
		mid_h: mid_h
		mem_y: mem_y
		mem_h: mem_h
		compact: compact
	}
}

// ── shared Paper Co. primitives (used by the Insights and Settings sheets too) ──

// paper_sheet is the soft material surface: warm paper, a quiet wood-tinted
// edge and a hard 2px shadow — the same treatment onboarding settled on,
// deliberately not the bordered pixel_panel.
fn paper_sheet(mut app GuiApp, x int, y int, w int, h int) {
	ensure_pixel_cache(mut app)
	app.gg.draw_rect_filled(x + 2, y + 3, w, h, tint(col_ink, 14))
	app.gg.draw_rect_filled(x, y, w, h, pc(app, `P`))
	app.gg.draw_rect_empty(x, y, w, h, tint(pc(app, `W`), 70))
}

// paper_pill draws a small status chip (text + tone bar, never color alone)
// and returns its width so callers can flow text after it.
fn paper_pill(mut app GuiApp, x int, y int, label string, tone gg.Color) int {
	pw := label.len * 6 + 18
	app.gg.draw_rect_filled(x, y, pw, 16, tint(tone, 60))
	app.gg.draw_rect_filled(x, y, 3, 16, tone)
	app.gg.draw_text(x + 9, y + 2, label, gg.TextCfg{
		color: app.pnl_text
		size: 10
		bold: true
	})
	return pw
}

// paper_button is the conventional action button in the paper material:
// ink on paper by default, sage when primary. Hover lifts the edge.
fn paper_button(mut app GuiApp, x int, y int, w int, h int, label string, primary bool, hover bool) {
	bg := if primary {
		if hover { app.pnl_success } else { tint(app.pnl_success, 220) }
	} else {
		if hover { app.pnl_card_sel } else { pc(app, `p`) }
	}
	fg := if primary { app.pnl_bg } else { app.pnl_text }
	app.gg.draw_rect_filled(x + 1, y + 2, w, h, tint(col_ink, 24))
	app.gg.draw_rect_filled(x, y, w, h, bg)
	app.gg.draw_rect_empty(x, y, w, h, if primary {
		app.pnl_success
	} else {
		tint(pc(app, `W`), 120)
	})
	tw := label.len * 7
	app.gg.draw_text(x + (w - tw) / 2, y + (h - 14) / 2, label, gg.TextCfg{
		color: fg
		size: 11
		bold: true
	})
}

// local_stamp returns the real local date and clock — never a fictional
// reference date.
fn local_stamp() (string, string) {
	now := time.now()
	months := ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
	mname := if now.month >= 1 && now.month <= 12 { months[now.month - 1] } else { '' }
	return '${mname} ${now.day}, ${now.year}', '${now.hour:02d}:${now.minute:02d}'
}

// destination_header is the editorial page head every non-Office destination
// shares in the references: pixel mark, Fraunces title, one-line subtitle,
// and the real date/clock at the right edge.
fn destination_header(mut app GuiApp, fx int, fy int, fw int, head_h int, mark pixelart.Sprite, title string, subtitle string) {
	ensure_pixel_cache(mut app)
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	big := head_h >= 56
	s := if big { 3 } else { 2 }
	mx := fx + 16
	my := fy + (head_h - mark.height() * s) / 2
	sc.draw(mark, pid, mx, my, s)
	tx := mx + mark.width() * s + 14
	app.gg.draw_text(tx, fy + if big { 8 } else { 6 }, title, gg.TextCfg{
		color: app.pnl_text
		size: if big { 26 } else { 20 }
		family: app.fonts.display
	})
	stamp, clock := local_stamp()
	clock_w := if fw > 560 { 96 } else { 0 }
	if big {
		app.gg.draw_text(tx + 2, fy + 38, utf8_truncate(subtitle, onb_fit(fw - (tx - fx) - clock_w - 24, 12)), gg.TextCfg{
			color: app.pnl_text_mut
			size: 12
		})
	}
	if clock_w > 0 {
		cx := fx + fw - clock_w
		app.gg.draw_text(cx, fy + 8, stamp, gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
		app.gg.draw_text(cx, fy + 22, clock, gg.TextCfg{
			color: app.pnl_text
			size: if big { 20 } else { 16 }
			family: app.fonts.display
		})
	}
	// brass rule closes the head, the same trim as the Office wall
	app.gg.draw_rect_filled(fx + 12, fy + head_h - 2, fw - 24, 1, tint(pc(app, `W`), 110))
}

// ── truth helpers ───────────────────────────────────────────────────────────

// ws_scaffold_names are the scaffold entries the Engine seeds
// (onboarding_ensure_workspace) plus the AGENTS.md contract that marks a
// workspace as initialized (workspace_is_initialized).
const ws_scaffold_names = ['knowledge/', 'personas/', 'packs/', 'repos/', 'projects/', 'AGENTS.md']

// ws_scaffold_present checks the REAL directory state of root for each
// scaffold entry. A trailing '/' entry must be a directory; a plain entry a
// file. Returns an empty list when there is no root — unknown, not missing.
fn ws_scaffold_present(root string) []bool {
	clean := os.expand_tilde_to_home(root.trim_space())
	if clean == '' || !os.is_dir(clean) {
		return []bool{}
	}
	mut out := []bool{cap: ws_scaffold_names.len}
	for name in ws_scaffold_names {
		p := os.join_path(clean, name.trim_right('/'))
		out << if name.ends_with('/') { os.is_dir(p) } else { os.is_file(p) }
	}
	return out
}

// ws_seed_warnings returns the persisted seed warnings of the last
// initialization (workspace/seed_warnings), empty when none were recorded.
fn ws_seed_warnings(mut app GuiApp) []string {
	if app.desktop == unsafe { nil } {
		return []string{}
	}
	raw := app.desktop.app_state_snapshot().raw.data['workspace/seed_warnings'] or { '' }
	return raw.split('|').filter(it.trim_space() != '')
}

// ws_state_label maps the active-workspace truth to a label + tone.
fn ws_state_label(app &GuiApp) (string, gg.Color) {
	if app.harness_root == '' {
		return 'No workspace', app.pnl_text_mut
	}
	if app.workspace_initialized {
		return 'Ready', app.pnl_success
	}
	return 'Needs setup', app.pnl_select
}

// ── drawing ─────────────────────────────────────────────────────────────────

fn draw_workspace(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	l := workspace_layout(app, w, h)
	app.gg.draw_rect_filled(l.fx, l.fy, l.fw, l.fh, app.pnl_bg)
	destination_header(mut app, l.fx, l.fy, l.fw, l.head_h, pixelart.environment_for(.cabinet_tall), tr(app, 'panel.workspace'), 'Files, project context and memory for the active workspace')
	draw_ws_hero(mut app, l)
	draw_ws_known(mut app, l)
	// IDE block — the existing brokered surfaces, unchanged renderers
	draw_file_tree_panel(mut app, l.fx + 12, l.mid_y, ws_tree_w, l.mid_h)
	editor_w := l.fw - 24 - ws_tree_w - 4 - ws_git_w
	draw_editor_panel(mut app, l.fx + 12 + ws_tree_w + 4, l.mid_y, editor_w, l.mid_h)
	draw_git_rails_panel(mut app, l.fx + l.fw - ws_git_w - 12, l.mid_y, ws_git_w, l.mid_h)
	draw_memory_palace_panel(mut app, l.fx + 12, l.mem_y, l.fw - 24, l.mem_h)
}

// draw_ws_hero is the "Active workspace" paper sheet: state pill, path
// field, the three real actions, the last notice, and a small filing scene.
fn draw_ws_hero(mut app GuiApp, l WorkspaceLayout) {
	x := l.fx + 12
	y := l.hero_y
	w := l.fw - 24
	paper_sheet(mut app, x, y, w, l.hero_h)
	app.gg.draw_text(x + 12, y + 8, 'Active workspace', gg.TextCfg{
		color: app.pnl_text
		size: 17
		family: app.fonts.display
	})
	label, tone := ws_state_label(app)
	paper_pill(mut app, x + 12 + 'Active workspace'.len * 9 + 8, y + 11, label, tone)
	if !l.compact {
		src := if app.workspace_source == '' { '—' } else { app.workspace_source }
		app.gg.draw_text(x + 12, y + 30, 'Source: ${src}', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	}
	// path field — mono, focus ring in sage, blinking caret when focused
	field_bg := if app.workspace_focus { app.pnl_bg } else { pc(app, `p`) }
	field_bd := if app.workspace_focus { app.pnl_success } else { tint(pc(app, `W`), 120) }
	app.gg.draw_rect_filled(l.field_x, l.field_y, l.field_w, 28, field_bg)
	app.gg.draw_rect_empty(l.field_x, l.field_y, l.field_w, 28, field_bd)
	if app.workspace_focus {
		app.gg.draw_rect_empty(l.field_x + 1, l.field_y + 1, l.field_w - 2, 26, field_bd)
	}
	max_chars := (l.field_w - 16) / 7
	path_label := workspace_path_label(app.workspace_draft, if max_chars < 12 {
		12
	} else {
		max_chars
	})
	app.gg.draw_text(l.field_x + 8, l.field_y + 7, path_label, gg.TextCfg{
		color: app.pnl_text
		size: 12
		mono: true
	})
	if app.workspace_focus && app.frame % 30 < 15 {
		cursor_x := l.field_x + 8 + path_label.len * 7
		if cursor_x < l.field_x + l.field_w - 4 {
			app.gg.draw_rect_filled(cursor_x, l.field_y + 6, 2, 16, app.pnl_success)
		}
	}
	hy := app.mouse_y >= l.field_y && app.mouse_y <= l.field_y + 28
	paper_button(mut app, l.validate_x, l.field_y, l.validate_w, 28, 'Validate', false, hy
		&& app.mouse_x >= l.validate_x && app.mouse_x <= l.validate_x + l.validate_w)
	paper_button(mut app, l.switch_x, l.field_y, l.switch_w, 28, 'Switch', false, hy
		&& app.mouse_x >= l.switch_x && app.mouse_x <= l.switch_x + l.switch_w)
	// Initialize is the primary (sage) action only while the folder still
	// needs setup — a ready workspace does not shout for re-initialization
	paper_button(mut app, l.init_x, l.field_y, l.init_w, 28, 'Initialize', !app.workspace_initialized, hy && app.mouse_x >= l.init_x && app.mouse_x <= l.init_x + l.init_w)
	if app.workspace_notice != '' {
		bad := app.workspace_notice.contains('error') || app.workspace_notice.contains('Could not')
			|| app.workspace_notice.contains('failed')
		app.gg.draw_text(l.field_x, l.field_y + 34, utf8_truncate(app.workspace_notice, onb_fit(l.field_w + 180, 11)), gg.TextCfg{
			color: if bad { app.pnl_danger } else { app.pnl_text_mut }
			size: 11
		})
	} else if !l.compact {
		app.gg.draw_text(l.field_x, l.field_y + 34, 'Validate checks the folder · Switch makes it active · Initialize adds the workspace structure', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	}
	if l.scene_w > 0 {
		draw_ws_scene(mut app, l.scene_x, y + 8, l.scene_w - 8, l.hero_h - 16)
	}
}

// draw_ws_scene is a small filing corner: tall cabinet, a desk with a folder
// stack, a plant — illustration only, static, no runtime meaning.
fn draw_ws_scene(mut app GuiApp, x int, y int, w int, h int) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	wall_h := h * 45 / 100
	app.gg.draw_rect_filled(x, y, w, wall_h, tint(pc(app, `m`), 70))
	floor_col := if app.appearance_dark {
		mix(pc(app, `S`), pc(app, `w`), 0.22)
	} else {
		mix(pc(app, `w`), pc(app, `p`), 0.62)
	}
	app.gg.draw_rect_filled(x, y + wall_h, w, h - wall_h, floor_col)
	app.gg.draw_rect_filled(x, y + wall_h - 2, w, 2, pc(app, `W`))
	app.gg.draw_rect_empty(x, y, w, h, tint(pc(app, `W`), 70))
	base := y + h - 6
	cabinet := pixelart.environment_for(.cabinet_tall)
	desk := pixelart.environment_for(.desk)
	folders := pixelart.environment_for(.folder_stack)
	plant := pixelart.environment_for(.plant)
	s := onb_art_scale(cabinet.width() + desk.width() + plant.width() + 10, cabinet.height(), w - 12, h - 10)
	total := (cabinet.width() + desk.width() + plant.width()) * s + 10 * s
	mut gx := x + (w - total) / 2
	sc.draw(cabinet, pid, gx, base - cabinet.height() * s, s)
	gx += cabinet.width() * s + 5 * s
	sc.draw(desk, pid, gx, base - desk.height() * s, s)
	fs := if s > 1 { s - 1 } else { 1 }
	sc.draw(folders, pid, gx + (desk.width() * s - folders.width() * fs) / 2, base - desk.height() * s - folders.height() * fs + 4 * s, fs)
	gx += desk.width() * s + 5 * s
	sc.draw(plant, pid, gx, base - plant.height() * s, s)
}

// draw_ws_known renders the bounded discovery list (Engine known_workspaces)
// as folder cards: leaf name, truthful state, why it is listed, path. Click
// fills the draft for Validate/Switch — discovery never switches by itself.
// Hit rects are rebuilt every frame from this same geometry
// (app.known_ws_rects; the click handler in main.v reads them).
fn draw_ws_known(mut app GuiApp, l WorkspaceLayout) {
	x := l.fx + 12
	y := l.known_y
	w := l.fw - 24
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	app.known_ws_rects.clear()
	known := if app.desktop != unsafe { nil } {
		app.desktop.engine_known_workspaces()
	} else {
		[]desktop_engine.KnownWorkspace{}
	}
	app.gg.draw_text(x + 2, y, 'Known workspaces', gg.TextCfg{
		color: app.pnl_text
		size: 13
		bold: true
	})
	app.gg.draw_text(x + 4 + 'Known workspaces'.len * 8, y + 2, '${known.len} discovered · active, previous, default, recent projects', gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
	})
	if known.len == 0 {
		app.gg.draw_text(x + 2, y + 22, 'No known workspaces yet — set a path above and Initialize.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 12
		})
		return
	}
	cy := y + 20
	folders := pixelart.environment_for(.folder_stack)
	if l.compact {
		// one row of chips: mark + leaf + state dot
		mut cx := x
		for i, k in known {
			leaf := k.path.all_after_last('/')
			cw := leaf.len * 7 + 44
			if cx + cw > x + w {
				app.gg.draw_text(cx + 4, cy + 5, '+${known.len - i} more', gg.TextCfg{
					color: app.pnl_text_mut
					size: 10
				})
				break
			}
			app.gg.draw_rect_filled(cx, cy, cw, 24, if k.is_active {
				tint(app.pnl_success, 60)
			} else {
				pc(app, `P`)
			})
			app.gg.draw_rect_empty(cx, cy, cw, 24, if k.is_active {
				app.pnl_success
			} else {
				tint(pc(app, `W`), 90)
			})
			sc.draw(folders, pid, cx + 4, cy + 7, 1)
			app.gg.draw_text(cx + 22, cy + 5, leaf, gg.TextCfg{
				color: app.pnl_text
				size: 11
				mono: true
				bold: k.is_active
			})
			_, tone := ws_known_state(app, k)
			app.gg.draw_rect_filled(cx + cw - 10, cy + 9, 5, 5, tone)
			app.known_ws_rects << KnownWsRect{
				x: cx
				y: cy
				w: cw
				h2: 24
				path: k.path
			}
			cx += cw + 6
		}
		return
	}
	card_w := 212
	gap := 8
	mut per_row := (w + gap) / (card_w + gap)
	if per_row < 1 {
		per_row = 1
	}
	for i, k in known {
		if i >= per_row {
			app.gg.draw_text(x + i * (card_w + gap) + 6, cy + 20, '+${known.len - i} more — type a path above', gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
			break
		}
		cx := x + i * (card_w + gap)
		draw_ws_known_card(mut app, cx, cy, card_w, 56, k)
		app.known_ws_rects << KnownWsRect{
			x: cx
			y: cy
			w: card_w
			h2: 56
			path: k.path
		}
	}
}

// ws_known_state is the truthful chip for a discovered workspace:
// missing beats everything (the directory is gone), then active, ready, folder.
fn ws_known_state(app &GuiApp, k desktop_engine.KnownWorkspace) (string, gg.Color) {
	if !k.exists {
		return 'Missing', app.pnl_danger
	}
	if k.is_active {
		return 'Active', app.pnl_success
	}
	if k.initialized {
		return 'Ready', app.pnl_text_mut
	}
	return 'Folder', app.pnl_select
}

fn draw_ws_known_card(mut app GuiApp, x int, y int, w int, h int, k desktop_engine.KnownWorkspace) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	hover := app.mouse_x >= x && app.mouse_x < x + w && app.mouse_y >= y && app.mouse_y < y + h
	app.gg.draw_rect_filled(x + 2, y + 3, w, h, tint(col_ink, 14))
	app.gg.draw_rect_filled(x, y, w, h, if k.is_active {
		tint(app.pnl_success, 50)
	} else if hover {
		app.pnl_card_sel
	} else {
		pc(app, `P`)
	})
	if k.is_active {
		// sage double outline — the reference's highlighted card
		app.gg.draw_rect_empty(x, y, w, h, app.pnl_success)
		app.gg.draw_rect_empty(x + 1, y + 1, w - 2, h - 2, app.pnl_success)
	} else {
		edge_a := if hover { u8(160) } else { u8(70) }
		app.gg.draw_rect_empty(x, y, w, h, tint(pc(app, `W`), edge_a))
	}
	folders := pixelart.environment_for(.folder_stack)
	sc.draw(folders, pid, x + 8, y + (h - folders.height() * 2) / 2, 2)
	leaf := k.path.all_after_last('/')
	label, tone := ws_known_state(app, k)
	pill_w := label.len * 6 + 18
	name_max := (w - 44 - pill_w - 16) / 7
	app.gg.draw_text(x + 40, y + 7, utf8_truncate(leaf, if name_max < 6 { 6 } else { name_max }), gg.TextCfg{
		color: app.pnl_text
		size: 13
		bold: true
	})
	paper_pill(mut app, x + w - pill_w - 8, y + 7, label, tone)
	app.gg.draw_text(x + 40, y + 25, utf8_truncate(k.path, onb_fit(w - 48, 10)), gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
		mono: true
	})
	why := if k.has_projects { '${k.why} · has projects' } else { k.why }
	app.gg.draw_text(x + 40, y + 39, why, gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
	})
}

// ── right column: "Workspace details" (replaces the inspector on panel 9) ──

// WsDetailLayout — fixed section rhythm so the click geometry (preferences
// sheet) is shared with drawing. Sections that do not fit are dropped from
// the bottom up: quote first, then preferences.
struct WsDetailLayout {
	ix         int
	iy         int
	iw         int
	ih         int
	scaffold_y int
	seed_y     int
	editor_y   int
	git_y      int
	prefs_y    int // 0 when the preferences sheet does not fit
	quote_y    int // 0 when the editorial card does not fit
}

fn ws_detail_layout(app &GuiApp, w int, h int) WsDetailLayout {
	term_h := if app.term_visible { app.term_height } else { 0 }
	ix := inspector_x(app, w)
	iy := 52
	iw := inspector_w
	ih := h - iy - 28 - term_h
	limit := iy + ih - 8
	scaffold_y := iy + 40
	mut y := scaffold_y + 22 + ws_scaffold_names.len * 17 + 10
	// secondary truth sections drop out (0) when the column is too short —
	// e.g. a tall terminal on a small window — rather than overlapping
	mut seed_y := 0
	if y + 54 <= limit {
		seed_y = y
		y += 54
	}
	mut editor_y := 0
	if y + 50 <= limit {
		editor_y = y
		y += 50
	}
	mut git_y := 0
	if y + 50 <= limit {
		git_y = y
		y += 50
	}
	mut prefs_y := 0
	if y + prefs_sheet_height() <= limit {
		prefs_y = y
		y += prefs_sheet_height() + 8
	}
	mut quote_y := 0
	if y + 62 <= limit {
		quote_y = limit - 62
	}
	return WsDetailLayout{
		ix: ix
		iy: iy
		iw: iw
		ih: ih
		scaffold_y: scaffold_y
		seed_y: seed_y
		editor_y: editor_y
		git_y: git_y
		prefs_y: prefs_y
		quote_y: quote_y
	}
}

fn ws_section_label(mut app GuiApp, x int, y int, label string) {
	app.gg.draw_text(x, y, label, gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
		bold: true
	})
	app.gg.draw_rect_filled(x, y + 14, inspector_w - 32, 1, tint(pc(app, `W`), 90))
}

fn draw_workspace_detail(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	d := ws_detail_layout(app, w, h)
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	x := d.ix
	y := d.iy
	app.gg.draw_rect_filled(x, y, d.iw, d.ih, app.pnl_bg)
	app.gg.draw_line(x, y, x, y + d.ih, app.pnl_border)
	app.gg.draw_text(x + 16, y + 10, 'Workspace details', gg.TextCfg{
		color: app.pnl_text
		size: 17
		family: app.fonts.display
	})
	sc.draw(pixelart.environment_for(.folder_stack), pid, x + d.iw - 44, y + 10, 2)

	// scaffold checklist — real os.exists on the active root
	ws_section_label(mut app, x + 16, d.scaffold_y, 'SCAFFOLD')
	present := ws_scaffold_present(app.harness_root)
	for i, name in ws_scaffold_names {
		ry := d.scaffold_y + 22 + i * 17
		app.gg.draw_text(x + 36, ry, name, gg.TextCfg{
			color: app.pnl_text
			size: 11
			mono: true
		})
		if present.len == 0 {
			app.gg.draw_text(x + 16, ry, '—', gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
			continue
		}
		if present[i] {
			onb_check(mut app, x + 16, ry + 1, app.pnl_success)
			app.gg.draw_text(x + d.iw - 70, ry, 'present', gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
			})
		} else {
			app.gg.draw_text(x + 16, ry, '—', gg.TextCfg{
				color: app.pnl_text_mut
				size: 11
			})
			app.gg.draw_text(x + d.iw - 70, ry, 'missing', gg.TextCfg{
				color: app.pnl_select
				size: 10
			})
		}
	}
	if present.len == 0 {
		app.gg.draw_text(x + 16, d.scaffold_y + 22 + ws_scaffold_names.len * 17 - 4, 'No active workspace — nothing was checked.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
	}

	if d.seed_y > 0 {
		draw_ws_detail_seed(mut app, x, d)
	}
	if d.editor_y > 0 {
		draw_ws_detail_editor(mut app, x, d)
	}
	if d.git_y > 0 {
		draw_ws_detail_git(mut app, x, d)
	}
	if d.prefs_y > 0 {
		draw_preferences_sheet(mut app, x + 8, d.prefs_y, d.iw - 16)
	}
	if d.quote_y > 0 {
		draw_paper_quote(mut app, x + 8, d.quote_y, d.iw - 16, '"Good tools make', 'brighter builders."', '— Hornero')
	}
}

// draw_ws_detail_seed — seed warnings persisted by the last initialization (workspace/seed_warnings).
fn draw_ws_detail_seed(mut app GuiApp, x int, d WsDetailLayout) {
	// seed warnings — persisted by the last initialization
	ws_section_label(mut app, x + 16, d.seed_y, 'SEED WARNINGS')
	warns := ws_seed_warnings(mut app)
	if warns.len == 0 {
		app.gg.draw_text(x + 16, d.seed_y + 20, 'None recorded by the last initialization.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	} else {
		app.gg.draw_text(x + 16, d.seed_y + 20, '${warns.len} blocked write(s):', gg.TextCfg{
			color: app.pnl_select
			size: 11
			bold: true
		})
		app.gg.draw_text(x + 16, d.seed_y + 34, utf8_truncate(warns[0], onb_fit(d.iw - 32, 10)), gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
			mono: true
		})
	}
}

// draw_ws_detail_editor — the active editor tab — MCP templates opened from the MCP drawer land here.
fn draw_ws_detail_editor(mut app GuiApp, x int, d WsDetailLayout) {
	// editor — what the IDE block currently holds (MCP templates route here)
	ws_section_label(mut app, x + 16, d.editor_y, 'EDITOR')
	if app.editor_tabs.len > 0 && app.active_tab >= 0 && app.active_tab < app.editor_tabs.len {
		t := app.editor_tabs[app.active_tab]
		kind := if t.syntax == 'json' && t.path.contains('mcp') { 'MCP template' } else { t.syntax }
		app.gg.draw_text(x + 16, d.editor_y + 20, utf8_truncate(t.title, onb_fit(d.iw - 120, 12)), gg.TextCfg{
			color: app.pnl_text
			size: 12
			bold: true
		})
		paper_pill(mut app, x + d.iw - 16 - (kind.len * 6 + 18), d.editor_y + 18, kind, app.pnl_select)
		app.gg.draw_text(x + 16, d.editor_y + 35, utf8_truncate(t.path, onb_fit(d.iw - 32, 10)), gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
			mono: true
		})
	} else {
		app.gg.draw_text(x + 16, d.editor_y + 20, 'No file open — click a file in the tree.', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	}
}

// draw_ws_detail_git — git availability before counts: no root / not a repo / backend unavailable.
fn draw_ws_detail_git(mut app GuiApp, x int, d WsDetailLayout) {
	// git — availability before counts
	ws_section_label(mut app, x + 16, d.git_y, 'GIT')
	if app.desktop == unsafe { nil } {
		app.gg.draw_text(x + 16, d.git_y + 20, '—', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
		})
	} else {
		st := app.desktop.engine_git_workspace_status()
		line := if st.root == '' {
			'No active workspace.'
		} else if !st.is_repo {
			'Not a git repository.'
		} else if !st.backend_available {
			'Repository found — git backend unavailable.'
		} else {
			changes := app.desktop.engine_git_changes()
			if changes.len == 0 {
				'Repository · working tree clean'
			} else {
				'Repository · ${changes.len} changed file(s)'
			}
		}
		app.gg.draw_text(x + 16, d.git_y + 20, line, gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
	}
}

// draw_paper_quote is the small editorial card the reference closes its
// right columns with: two Fraunces lines, an attribution and the nest mark.
fn draw_paper_quote(mut app GuiApp, x int, y int, w int, l1 string, l2 string, by string) {
	mut sc := app.pixel_cache
	pid := office_palette_id(app)
	app.gg.draw_rect_filled(x, y, w, 62, tint(pc(app, `m`), 60))
	app.gg.draw_rect_empty(x, y, w, 62, tint(pc(app, `W`), 70))
	app.gg.draw_text(x + 12, y + 10, l1, gg.TextCfg{
		color: app.pnl_text
		size: 12
		family: app.fonts.display
	})
	app.gg.draw_text(x + 12, y + 26, l2, gg.TextCfg{
		color: app.pnl_text
		size: 12
		family: app.fonts.display
	})
	app.gg.draw_text(x + 12, y + 44, by, gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
	})
	sc.draw(pixelart.environment_for(.nest), pid, x + w - 50, y + 18, 2)
}

// workspace_detail_click routes clicks inside the right column. Only the
// preferences sheet is interactive today; the truth sections are read-only.
fn workspace_detail_click(mut app GuiApp, mx int, my int, w int, h int) bool {
	d := ws_detail_layout(app, w, h)
	if !onb_hit(mx, my, d.ix, d.iy, d.iw, d.ih) {
		return false
	}
	if d.prefs_y > 0 && preferences_click(mut app, d.ix + 8, d.prefs_y, d.iw - 16, mx, my) {
		return true
	}
	// clicks elsewhere in the column are consumed so they never fall through
	// to the generic inspector geometry (which this column replaces)
	return true
}
