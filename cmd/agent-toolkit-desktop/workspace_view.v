module main

import gg
import os
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
	tree_w     int // IDE column widths — read by the on_event handlers in main.v
	git_w      int
	git_tab_w  int // pitch of the CHANGES / HISTORY / COMPARE tabs
	mem_y      int // memory palace strip
	mem_h      int
	compact    bool
}

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
	// narrow panels shrink the side columns so the editor keeps ≥150px; below
	// 500px the git rails drop out entirely (git availability stays visible in
	// the details column) — a zero width also disables their hit rects
	tree_w := if fw < 500 {
		140
	} else if fw < 640 { 150 } else { 180 }
	git_w := if fw < 500 {
		0
	} else if fw < 640 { 180 } else { 240 }
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
		tree_w: tree_w
		git_w: git_w
		git_tab_w: if git_w > 0 { (git_w - 12) / 3 } else { 0 }
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
	now := ui_now()
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

// ws_scaffold_cached memoizes ws_scaffold_present by root, refreshed every
// ~2s (120 frames) so a network mount cannot stall the render thread.
fn ws_scaffold_cached(mut app GuiApp, root string) []bool {
	if app.ws_scaffold_root == root && app.frame - app.ws_scaffold_frame < 120 {
		return app.ws_scaffold_vals
	}
	app.ws_scaffold_root = root
	app.ws_scaffold_vals = ws_scaffold_present(root)
	app.ws_scaffold_frame = app.frame
	return app.ws_scaffold_vals
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
	draw_file_tree_panel(mut app, l.fx + 12, l.mid_y, l.tree_w, l.mid_h)
	editor_w := l.fw - 24 - l.tree_w - 4 - l.git_w
	draw_editor_panel(mut app, l.fx + 12 + l.tree_w + 4, l.mid_y, editor_w, l.mid_h)
	if l.git_w > 0 {
		draw_git_rails_panel(mut app, l.fx + l.fw - l.git_w - 12, l.mid_y, l.git_w, l.mid_h, l.git_tab_w)
	}
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
			// the notice sits under the last visible card, inside the sheet
			app.gg.draw_text(x, cy + 62, '+${known.len - i} more — type a path above', gg.TextCfg{
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
	app.gg.draw_text(x + 40, y + 39, utf8_truncate(why, (w - 48) / 6), gg.TextCfg{
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
	present := ws_scaffold_cached(mut app, app.harness_root)
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

// ── IDE sub-panels — paper sheets, same hit geometry as the main.v handlers ──
//
// Geometry contract (read by on_event in main.v; do not move): file-tree rows
// start at y+24 with 18px pitch and (h-28)/18 visible; editor tabs sit at
// y+6..y+24, x+6 onwards, width title.len*7+28, gap 4; git rail tabs at
// x+6+i*git_tab_w, git_tab_w-4 wide, y..y+22; CHANGES rows at y+40 (20px), HISTORY rows at
// y+40 (22px); memory field at y+20..y+40 and result rows at y+44 (18px).

// ws_sheet_title is the 14px Fraunces title every IDE sheet opens with.
fn ws_sheet_title(mut app GuiApp, x int, y int, title string) {
	app.gg.draw_text(x, y, title, gg.TextCfg{
		color: app.pnl_text
		size: 14
		family: app.fonts.display
	})
}

// ws_empty_copy renders product copy (12px) with the technical detail as a
// second muted line (11px) — never implementation-speak as the headline.
fn ws_empty_copy(mut app GuiApp, x int, y int, w int, head string, detail string) {
	app.gg.draw_text(x, y, utf8_truncate(head, onb_fit(w, 12)), gg.TextCfg{
		color: app.pnl_text
		size: 12
	})
	if detail != '' {
		draw_onb_wrapped(mut app, x, y + 16, w, detail, 3)
	}
}

// ws_underline_tab draws a library-style tab label: bold + sage underline
// when active, muted otherwise. The rect is the hit target the handler uses.
fn ws_underline_tab(mut app GuiApp, x int, y int, w int, h int, label string, active bool, size int) {
	hover := onb_hit(app.mouse_x, app.mouse_y, x, y, w, h)
	if hover && !active {
		app.gg.draw_rect_filled(x, y, w, h, app.pnl_card_sel)
	}
	tw := label.len * (size / 2 + 1)
	app.gg.draw_text(x + (w - tw) / 2, y + (h - size) / 2 - 1, label, gg.TextCfg{
		color: if active { app.pnl_text } else { app.pnl_text_mut }
		size: size
		bold: active
	})
	if active {
		app.gg.draw_rect_filled(x + 4, y + h - 2, w - 8, 2, app.pnl_success)
	}
}

// ws_git_unavailable returns the product copy for a git rail that cannot
// show data yet: headline + technical detail, or empty strings when it can.
fn ws_git_unavailable(st desktop_engine.GitWorkspaceStatus) (string, string) {
	if st.root == '' {
		return 'No workspace yet', 'Choose a workspace above to inspect its repository.'
	}
	if !st.is_repo {
		return 'Not a git repository', 'The active workspace has no .git folder.'
	}
	if !st.backend_available {
		return 'Git backend unavailable', 'A repository was found, but no git reader is wired in this build.'
	}
	return '', ''
}

// draw_file_tree_panel — left column: twisty, kind mark, git dot, virtualized.
fn draw_file_tree_panel(mut app GuiApp, x int, y int, w int, h int) {
	paper_sheet(mut app, x, y, w, h)
	ws_sheet_title(mut app, x + 10, y + 4, 'Files')
	flat := file_tree_visible(app)
	row_h := 18
	visible := (h - 28) / row_h
	if visible < 1 {
		return
	}
	if flat.len > 0 {
		app.gg.draw_text(x + w - 10 - '${flat.len}'.len * 6, y + 8, '${flat.len}', gg.TextCfg{
			color: app.pnl_text_mut
			size: 10
		})
	}
	app.gg.draw_rect_filled(x + 8, y + 22, w - 16, 1, tint(pc(app, `W`), 70))
	if flat.len == 0 {
		head, detail := if app.harness_root == '' {
			'No workspace yet', 'Choose or initialize a workspace above.'
		} else if !app.workspace_initialized {
			'No files yet', 'Initialize the workspace to add its folders.'
		} else {
			'No files yet', 'The workspace folder has nothing to list.'
		}
		ws_empty_copy(mut app, x + 10, y + 32, w - 20, head, detail)
		return
	}
	app.file_tree_scroll = clamp_scroll(app.file_tree_scroll, flat.len, visible)
	start := app.file_tree_scroll
	mut end := start + visible
	if end > flat.len {
		end = flat.len
	}
	for idx in start .. end {
		n := flat[idx]
		row := idx - start
		ry := y + 24 + row * row_h
		hover := idx == app.file_tree_hover
		sel := n.path == app.file_tree_selected
		if sel {
			app.gg.draw_rect_filled(x + 2, ry - 1, w - 4, row_h, tint(app.pnl_success, 70))
			app.gg.draw_rect_filled(x + 2, ry - 1, 3, row_h, app.pnl_success)
		} else if hover {
			app.gg.draw_rect_filled(x + 2, ry - 1, w - 4, row_h, app.pnl_card_sel)
		}
		indent := n.depth * 12
		if n.kind == 'dir' {
			tw := if n.expanded { '−' } else { '+' }
			app.gg.draw_text(x + 8 + indent, ry + 2, tw, gg.TextCfg{
				color: app.pnl_text_mut
				size: 12
				bold: true
			})
		}
		// small manila tab for folders, paper leaf for files
		if n.kind == 'dir' {
			app.gg.draw_rect_filled(x + 20 + indent, ry + 5, 9, 7, pc(app, `m`))
			app.gg.draw_rect_filled(x + 20 + indent, ry + 4, 4, 1, pc(app, `M`))
		} else {
			app.gg.draw_rect_filled(x + 21 + indent, ry + 4, 7, 9, pc(app, `p`))
			app.gg.draw_rect_empty(x + 21 + indent, ry + 4, 7, 9, tint(pc(app, `W`), 120))
		}
		name_col := if sel || n.kind == 'dir' { app.pnl_text } else { app.pnl_text_mut }
		max_chars := (w - 34 - indent - 16) / 7
		lbl := utf8_truncate(n.name, if max_chars < 4 { 4 } else { max_chars })
		app.gg.draw_text(x + 34 + indent, ry + 3, lbl, gg.TextCfg{
			color: name_col
			size: 12
			mono: n.kind == 'file'
		})
		if n.git_status != '' {
			dot_col := if n.git_status == 'modified' { app.pnl_select } else { app.pnl_success }
			app.gg.draw_rect_filled(x + w - 14, ry + 6, 6, 6, dot_col)
		}
	}
	if flat.len > visible {
		mut bar_h := (h - 28) * visible / flat.len
		if bar_h < 10 {
			bar_h = 10
		}
		bar_y := y + 24 + (h - 28 - bar_h) * start / (flat.len - visible)
		app.gg.draw_rect_filled(x + w - 4, y + 24, 2, h - 28, tint(pc(app, `W`), 60))
		app.gg.draw_rect_filled(x + w - 4, bar_y, 2, bar_h, app.pnl_select)
	}
}

// draw_editor_panel — centre column: underlined tabs, gutter + syntax lines.
fn draw_editor_panel(mut app GuiApp, x int, y int, w int, h int) {
	paper_sheet(mut app, x, y, w, h)
	tab_h := 28
	if app.editor_tabs.len == 0 {
		ws_sheet_title(mut app, x + 12, y + 6, 'Nothing open')
		ws_empty_copy(mut app, x + 12, y + 30, w - 24, 'Click a file in the tree to open it here.', 'Files stay inside the active workspace.')
		return
	}
	mut tx := x + 6
	for i, tab in app.editor_tabs {
		active := i == app.active_tab
		tw := tab.title.len * 7 + 28
		if tx + tw > x + w - 6 {
			break
		}
		ws_underline_tab(mut app, tx, y + 6, tw, 18, tab.title, active, 12)
		if tab.dirty {
			app.gg.draw_rect_filled(tx + tw - 12, y + 12, 5, 5, app.pnl_danger)
		}
		tx += tw + 4
	}
	app.gg.draw_rect_filled(x + 8, y + tab_h - 2, w - 16, 1, tint(pc(app, `W`), 70))
	content_y := y + tab_h + 4
	content_h := h - tab_h - 24
	if content_h < 20 {
		return
	}
	active := if app.active_tab >= 0 && app.active_tab < app.editor_tabs.len {
		app.editor_tabs[app.active_tab]
	} else {
		EditorTab{}
	}
	lines := active.content.split_into_lines()
	row_h := 14
	visible := content_h / row_h
	if visible < 1 {
		return
	}
	app.editor_scroll = clamp_scroll(app.editor_scroll, lines.len, visible)
	start := app.editor_scroll
	mut end := start + visible
	if end > lines.len {
		end = lines.len
	}
	app.gg.draw_rect_filled(x + 6, content_y, w - 12, content_h, pc(app, `p`))
	app.gg.draw_rect_filled(x + 6, content_y, 34, content_h, tint(pc(app, `m`), 50))
	for idx in start .. end {
		line := lines[idx]
		row := idx - start
		ly := content_y + 4 + row * row_h
		app.gg.draw_text(x + 10, ly, '${idx + 1:3d}', gg.TextCfg{
			color: app.pnl_text_mut
			size: 11
			mono: true
		})
		tokens := highlight_line_local(line, active.syntax)
		mut cx := x + 46
		for tok in tokens {
			app.gg.draw_text(cx, ly, tok.text, gg.TextCfg{
				color: syntax_color(tok.kind)
				size: 12
				mono: true
			})
			cx += tok.text.len * 6
			if cx > x + w - 10 {
				break
			}
		}
	}
	if lines.len > visible {
		mut bar_h := content_h * visible / lines.len
		if bar_h < 12 {
			bar_h = 12
		}
		bar_y := content_y + (content_h - bar_h) * start / (lines.len - visible)
		app.gg.draw_rect_filled(x + w - 8, content_y, 2, content_h, tint(pc(app, `W`), 60))
		app.gg.draw_rect_filled(x + w - 8, bar_y, 2, bar_h, app.pnl_select)
	}
	state := if active.dirty { 'unsaved changes' } else { 'saved' }
	app.gg.draw_text(x + 12, y + h - 16, '${active.syntax} · ${lines.len} lines · ${state}', gg.TextCfg{
		color: app.pnl_text_mut
		size: 10
		mono: true
	})
}

// draw_git_rails_panel — right column: CHANGES / HISTORY / COMPARE tabs,
// commit graph lanes and diff preview.
// Git-rail visible-row budgets, shared by drawing (draw_git_rails_panel) and
// the wheel/hover paths in main.v so scroll clamps match what is drawn.
// mid_h is the rail's full height; the panel reserves 30px for its tab strip.
fn ws_git_changes_visible(mid_h int) int {
	v := (mid_h - 30 - 20) / 20
	return if v < 0 { 0 } else { v }
}

fn ws_git_history_visible(mid_h int) int {
	v := (mid_h - 30 - 40) / 22
	return if v < 0 { 0 } else { v }
}

fn draw_git_rails_panel(mut app GuiApp, x int, y int, w int, h int, tab_w int) {
	paper_sheet(mut app, x, y, w, h)
	for ri, rn in ['CHANGES', 'HISTORY', 'COMPARE'] {
		ws_underline_tab(mut app, x + 6 + ri * tab_w, y + 2, tab_w - 4, 20, rn.to_lower().capitalize(), app.git_rail == rn, 11)
	}
	app.gg.draw_rect_filled(x + 8, y + 24, w - 16, 1, tint(pc(app, `W`), 70))
	y0 := y + 26
	inner_h := h - 30
	if inner_h < 30 || app.desktop == unsafe { nil } {
		return
	}
	st := app.desktop.engine_git_workspace_status()
	if app.git_rail == 'CHANGES' {
		head, detail := ws_git_unavailable(st)
		if head != '' {
			ws_empty_copy(mut app, x + 10, y0 + 6, w - 20, head, detail)
			return
		}
		changes := app.desktop.engine_git_changes()
		summary := if changes.len == 0 {
			'Working tree clean'
		} else {
			'${changes.len} changed file(s)'
		}
		app.gg.draw_text(x + 10, y0, summary, gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
		row_h := 20
		visible := ws_git_changes_visible(h)
		if visible < 1 {
			return
		}
		app.git_scroll = clamp_scroll(app.git_scroll, changes.len, visible)
		start := app.git_scroll
		mut end := start + visible
		if end > changes.len {
			end = changes.len
		}
		for idx in start .. end {
			c := changes[idx]
			row := idx - start
			ry := y0 + 14 + row * row_h
			if idx == app.git_hover {
				app.gg.draw_rect_filled(x + 4, ry - 1, w - 8, row_h, app.pnl_card_sel)
			}
			status_col := match c.status {
				'modified' { app.pnl_select }
				'added' { app.pnl_success }
				'deleted' { app.pnl_danger }
				else { app.pnl_text_mut }
			}
			app.gg.draw_rect_filled(x + 10, ry + 6, 7, 7, status_col)
			app.gg.draw_text(x + 22, ry + 2, utf8_truncate(c.path.all_after_last('/'), (w - 90) / 7), gg.TextCfg{
				color: app.pnl_text
				size: 12
				mono: true
			})
			app.gg.draw_text(x + 22, ry + 12, utf8_truncate(c.path, (w - 40) / 6), gg.TextCfg{
				color: app.pnl_text_mut
				size: 9
				mono: true
			})
			staged := if c.staged { 'staged' } else { 'unstaged' }
			app.gg.draw_text(x + w - 56, ry + 4, staged, gg.TextCfg{
				color: if c.staged { app.pnl_success } else { app.pnl_text_mut }
				size: 10
			})
		}
		if changes.len > visible {
			mut bar_h := (inner_h - 20) * visible / changes.len
			if bar_h < 10 {
				bar_h = 10
			}
			bar_y := y0 + 14 + (inner_h - 20 - bar_h) * app.git_scroll / (changes.len - visible)
			app.gg.draw_rect_filled(x + w - 4, y0 + 14, 2, inner_h - 20, tint(pc(app, `W`), 60))
			app.gg.draw_rect_filled(x + w - 4, bar_y, 2, bar_h, app.pnl_select)
		}
	} else if app.git_rail == 'HISTORY' {
		head, detail := ws_git_unavailable(st)
		if head != '' {
			ws_empty_copy(mut app, x + 10, y0 + 6, w - 20, head, detail)
			return
		}
		graph := app.desktop.engine_git_graph(20)
		app.gg.draw_text(x + 10, y0, '${graph.commits.len} commits · ${graph.max_lane + 1} lane(s)', gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
		row_h := 22
		visible := ws_git_history_visible(h)
		if visible < 1 {
			return
		}
		app.git_scroll = clamp_scroll(app.git_scroll, graph.commits.len, visible)
		start := app.git_scroll
		mut end := start + visible
		if end > graph.commits.len {
			end = graph.commits.len
		}
		for idx in start .. end {
			c := graph.commits[idx]
			lane := graph.lanes[idx]
			row := idx - start
			ry := y0 + 14 + row * row_h
			sel := c.hash == app.git_selected
			if sel {
				app.gg.draw_rect_filled(x + 4, ry - 1, w - 8, row_h, tint(app.pnl_success, 70))
				app.gg.draw_rect_filled(x + 4, ry - 1, 3, row_h, app.pnl_success)
			} else if idx == app.git_hover {
				app.gg.draw_rect_filled(x + 4, ry - 1, w - 8, row_h, app.pnl_card_sel)
			}
			dot_x := x + 12 + lane * 10
			app.gg.draw_rect_filled(dot_x, ry + 7, 7, 7, if sel {
				app.pnl_success
			} else {
				app.pnl_select
			})
			if c.parents.len > 1 {
				app.gg.draw_rect_filled(dot_x + 3, ry + 2, 1, 5, app.pnl_text_mut)
			}
			hash := if c.hash.len >= 7 { c.hash[..7] } else { c.hash }
			app.gg.draw_text(x + 44, ry + 1, hash, gg.TextCfg{
				color: app.pnl_text
				size: 11
				mono: true
			})
			app.gg.draw_text(x + 44, ry + 11, utf8_truncate(c.message, (w - 100) / 6), gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
			})
			app.gg.draw_text(x + w - 52, ry + 1, utf8_truncate(c.author, 7), gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
			})
			if c.refs.len > 0 {
				app.gg.draw_text(x + w - 52, ry + 11, utf8_truncate(c.refs[0], 7), gg.TextCfg{
					color: app.pnl_success
					size: 10
				})
			}
		}
		diff_y := y0 + 14 + visible * row_h + 6
		if diff_y + 40 < y + h - 4 {
			app.gg.draw_rect_filled(x + 8, diff_y, w - 16, 1, tint(pc(app, `W`), 70))
			if app.git_selected != '' {
				hunks := app.desktop.engine_git_diff(app.git_selected)
				if hunks.len > 0 {
					app.gg.draw_text(x + 10, diff_y + 6, '${hunks[0].file}  +${hunks[0].new_count} -${hunks[0].old_count}', gg.TextCfg{
						color: app.pnl_text
						size: 11
						mono: true
					})
				} else {
					app.gg.draw_text(x + 10, diff_y + 6, 'No hunks for this commit.', gg.TextCfg{
						color: app.pnl_text_mut
						size: 11
					})
				}
			} else {
				app.gg.draw_text(x + 10, diff_y + 6, 'Select a commit to preview its diff.', gg.TextCfg{
					color: app.pnl_text_mut
					size: 11
				})
			}
		}
	} else { // COMPARE
		head, detail := ws_git_unavailable(st)
		if head != '' {
			ws_empty_copy(mut app, x + 10, y0 + 6, w - 20, head, detail)
			return
		}
		hunks := app.desktop.engine_git_compare('HEAD~1', 'HEAD')
		app.gg.draw_text(x + 10, y0, 'HEAD~1 → HEAD · ${hunks.len} hunk(s)', gg.TextCfg{
			color: app.pnl_text
			size: 11
		})
		row_h := 14
		visible := (inner_h - 20) / row_h
		if visible < 1 {
			return
		}
		if hunks.len == 0 {
			ws_empty_copy(mut app, x + 10, y0 + 20, w - 20, 'Nothing to compare', 'The last two commits do not differ, or there is only one commit.')
			return
		}
		// flatten hunks into one line list so the wheel scroll (diff_scroll)
		// is clamped against the REAL total and actually applied
		mut flat_text := []string{}
		mut flat_col := []gg.Color{}
		for hunk in hunks {
			flat_text << '— ${hunk.file}'
			flat_col << app.pnl_select
			for line in hunk.lines {
				col := match line.kind {
					.addition { app.pnl_success }
					.deletion { app.pnl_danger }
					else { app.pnl_text_mut }
				}
				prefix := match line.kind {
					.addition { '+' }
					.deletion { '-' }
					else { ' ' }
				}
				flat_text << prefix + line.text
				flat_col << col
			}
		}
		app.diff_scroll = clamp_scroll(app.diff_scroll, flat_text.len, visible)
		mut end_i := app.diff_scroll + visible
		if end_i > flat_text.len {
			end_i = flat_text.len
		}
		for idx in app.diff_scroll .. end_i {
			row := idx - app.diff_scroll
			is_file := flat_text[idx].starts_with('— ')
			app.gg.draw_text(if is_file { x + 10 } else { x + 14 }, y0 + 14 + row * row_h, utf8_truncate(flat_text[idx], (w - 28) / 6), gg.TextCfg{
				color: flat_col[idx]
				size: 11
				mono: true
			})
		}
		if flat_text.len > visible {
			app.gg.draw_text(x + w - 90, y0, '${app.diff_scroll + 1}–${end_i} of ${flat_text.len}', gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
			})
		}
	}
}

// draw_memory_palace_panel — bottom strip: recall query field + results.
// Diagnostics (embedding scheme, broker path) are not user-facing copy.
fn draw_memory_palace_panel(mut app GuiApp, x int, y int, w int, h int) {
	paper_sheet(mut app, x, y, w, h)
	ws_sheet_title(mut app, x + 10, y + 2, 'Memory')
	mode := if app.memory_semantic { 'semantic' } else { 'keyword' }
	paper_pill(mut app, x + w - 10 - (mode.len * 6 + 18), y + 3, mode, app.pnl_select)
	// query field — same hit rect as before (y+20..y+40)
	typing := app.memory_query != ''
	app.gg.draw_rect_filled(x + 8, y + 20, w - 16, 20, if typing {
		app.pnl_bg
	} else {
		pc(app, `p`)
	})
	app.gg.draw_rect_empty(x + 8, y + 20, w - 16, 20, if typing {
		app.pnl_success
	} else {
		tint(pc(app, `W`), 120)
	})
	q := if typing { app.memory_query } else { 'Search memory — type to recall' }
	app.gg.draw_text(x + 14, y + 24, q, gg.TextCfg{
		color: if typing { app.pnl_text } else { app.pnl_text_mut }
		size: 12
	})
	if h < 60 || app.desktop == unsafe { nil } {
		return
	}
	if typing {
		results := app.desktop.engine_memory_recall(app.memory_query, 5)
		row_h := 18
		visible := (h - 48) / row_h
		if visible < 1 {
			return
		}
		app.memory_scroll = clamp_scroll(app.memory_scroll, results.len, visible)
		start := app.memory_scroll
		mut end := start + visible
		if end > results.len {
			end = results.len
		}
		for idx in start .. end {
			r := results[idx]
			row := idx - start
			ry := y + 44 + row * row_h
			if idx == app.memory_hover {
				app.gg.draw_rect_filled(x + 10, ry - 1, w - 20, row_h, app.pnl_card_sel)
			}
			pct := int(r.score * 100)
			app.gg.draw_text(x + 14, ry + 2, '${pct}%', gg.TextCfg{
				color: if pct > 70 { app.pnl_success } else { app.pnl_text_mut }
				size: 11
				bold: pct > 70
			})
			app.gg.draw_text(x + 50, ry + 2, utf8_truncate(r.entry.title, 40), gg.TextCfg{
				color: app.pnl_text
				size: 11
			})
			app.gg.draw_text(x + 50 + 40 * 7, ry + 3, utf8_truncate(r.snippet, (w - 50 - 40 * 7 - 20) / 6), gg.TextCfg{
				color: app.pnl_text_mut
				size: 10
			})
		}
		if results.len == 0 {
			ws_empty_copy(mut app, x + 14, y + 46, w - 28, 'No matches for "${app.memory_query}"', '')
		}
		return
	}
	entries := app.desktop.engine_memory_entries()
	line := if entries.len == 0 {
		'Nothing recorded yet — memories appear as agents and loops save learnings.'
	} else {
		'${entries.len} memories recorded'
	}
	app.gg.draw_text(x + 14, y + 48, utf8_truncate(line, onb_fit(w - 28, 11)), gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
	})
}
