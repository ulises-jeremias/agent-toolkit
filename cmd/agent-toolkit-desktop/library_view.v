module main

import gg
import desktop.pixelart
import desktop_engine

// VC5 (#1173) — the Library as an illustrated collection.
//
// Canonical visual reference: docs/desktop/assets/design/library.jpg with
// concept-board.jpg as the shell/material authority. One composition serves
// the four Library tabs (Skills · Agents · Products · MCP — panels 1/2/10/3):
// an editorial header band with a composed pixel-art bookshelf banner, a tab
// bar, a wide search field, category chips, a card grid, and a detail column
// that replaces the Office inspector while a Library panel is selected.
//
// Truth: every value comes from Engine catalogs and configuration state
// (skills/agents/products/packs/MCP/targets). The reference's install counts,
// ratings, publishers, dates and "Verified" badges have no truthful source in
// the bundled catalog and are deliberately absent — cards and the detail pane
// show domain, stability, kind, installed/enabled configuration state, real
// provenance/receipt evidence when it exists, and product membership.
// Illustration (marks, banner) is catalog identity and environment only; it
// never encodes runtime activity or popularity.
//
// Geometry: lib_layout() is computed once per frame and shared by drawing,
// hover, click and wheel handling (single source of geometry).

// tab order in the tab bar → panel id
const lib_tab_panels = [1, 2, 10, 3]

// hovered chrome element codes (lib_hover_ui)
const lib_ui_tab0 = 10 // 10..13 tabs
const lib_ui_search = 20
const lib_ui_chip0 = 30 // 30..59 chips
const lib_ui_primary = 60
const lib_ui_second = 61
const lib_ui_third = 62

// lib_is_panel reports whether a panel id is served by the Library composition.
fn lib_is_panel(p int) bool {
	return p in lib_tab_panels
}

// lib_tab_for_panel maps a panel id to its tab index (-1 when not a Library panel).
fn lib_tab_for_panel(p int) int {
	for i, tp in lib_tab_panels {
		if tp == p {
			return i
		}
	}
	return -1
}

// LibLayout is the per-frame geometry shared by draw and hit-testing.
struct LibLayout {
	fx       int
	fy       int
	fw       int
	fh       int
	side_x   int
	side_w   int
	side_y   int // detail column top: under the header band when the banner spans it
	head_y   int
	head_h   int
	banner_x int
	banner_w int // 0 when the banner is hidden
	tabs_y   int
	tabs_h   int
	search_y int
	search_h int
	chips_y  int
	chips_h  int
	grid_y   int
	grid_h   int
	cols     int
	rows     int // full card rows that fit
	card_w   int
	card_h   int
	gap      int
	compact  bool
	tab      int
}

// lib_side_w is the detail column width: wider than the Office inspector at
// desktop widths so the detail pane can carry actions + facts without
// shrinking type.
fn lib_side_w(w int) int {
	return if w >= 1180 { 340 } else { inspector_w }
}

fn lib_layout(mut app GuiApp, w int, h int) LibLayout {
	term_h := if app.term_visible { app.term_height } else { 0 }
	side_w := lib_side_w(w)
	rtl := app.lang.is_rtl()
	fx := if rtl { side_w + 8 } else { dock_w + 8 }
	fw := w - dock_w - 8 - side_w
	fy := 52
	fh := h - fy - 28 - term_h
	compact := fw < 560 || fh < 400
	head_y := fy + 6
	head_h := if compact { 52 } else { 84 }
	tabs_y := head_y + head_h + 4
	tabs_h := 30
	search_y := tabs_y + tabs_h + 6
	search_h := 32
	chips_y := search_y + search_h + 6
	chip_rows := lib_chip_rows(mut app, fx, fw)
	chips_h := chip_rows * 24 + (chip_rows - 1) * 4
	grid_y := chips_y + chips_h + 8
	grid_bottom := fy + fh - 20
	grid_h := grid_bottom - grid_y
	gap := 8
	cols := if fw >= 1000 {
		4
	} else if fw >= 600 {
		3
	} else if fw >= 400 {
		2
	} else {
		1
	}
	card_w := (fw - 24 - (cols - 1) * gap) / cols
	mut card_h := 102
	mut rows := (grid_h + gap) / (card_h + gap)
	if rows < 2 && (grid_h - gap) / 2 >= 86 {
		// short windows: two slightly shorter rows beat one row over dead
		// space (cards below 100px drop the footer line, see draw_lib_grid)
		rows = 2
		card_h = (grid_h - gap) / 2
	}
	if rows < 1 {
		rows = if grid_h >= 60 { 1 } else { 0 }
	}
	if rows >= 1 && card_h >= 102 {
		// tall windows: let cards grow (up to a 3-line description) instead
		// of leaving a dead band under the grid
		fit := (grid_h - (rows - 1) * gap) / rows
		if fit > card_h {
			card_h = if fit > 128 { 128 } else { fit }
		}
	}
	// the banner spans the right half of the whole content row — panel and
	// detail column alike — exactly like the reference's header band; the
	// title/subtitle keep the room their text needs and the banner takes
	// the rest. Hidden when that rest is too narrow to read as a scene.
	sub_px := tr(app, 'lib.subtitle').runes().len * 7 + 20
	shelf_px := 14 + 14 * 3 + 14
	title_need := shelf_px + sub_px // room the header text block needs
	mut banner_x := 0
	mut banner_w := 0
	if rtl {
		// mirrored: the header text sits at the right end of the panel and
		// the banner takes the left half of the content row (window edge →
		// wherever the text block begins), so it never covers the title
		mut banner_end := fx + fw - title_need
		if banner_end > fx + fw / 2 {
			banner_end = fx + fw / 2
		}
		banner_x = 8
		banner_w = banner_end - 8
	} else {
		title_px := fx + title_need
		banner_x = if title_px > fx + fw / 2 { title_px } else { fx + fw / 2 }
		banner_w = (w - 8) - banner_x
	}
	if compact || banner_w < 300 {
		banner_w = 0
		banner_x = if rtl { fx } else { fx + fw }
	}
	return LibLayout{
		fx: fx
		fy: fy
		fw: fw
		fh: fh
		side_x: if rtl { 0 } else { w - side_w }
		side_w: side_w
		side_y: if banner_w > 0 { tabs_y } else { fy }
		head_y: head_y
		head_h: head_h
		banner_x: banner_x
		banner_w: banner_w
		tabs_y: tabs_y
		tabs_h: tabs_h
		search_y: search_y
		search_h: search_h
		chips_y: chips_y
		chips_h: chips_h
		grid_y: grid_y
		grid_h: grid_h
		cols: cols
		rows: rows
		card_w: card_w
		card_h: card_h
		gap: gap
		compact: compact
		tab: lib_tab_for_panel(app.selected_panel)
	}
}

// ── shared rects ────────────────────────────────────────────────────────────

fn lib_tab_rect(l LibLayout, i int) (int, int, int, int) {
	tw := if l.fw >= 640 { 118 } else { (l.fw - 24 - 3 * 6) / 4 }
	return l.fx + 12 + i * (tw + 6), l.tabs_y, tw, l.tabs_h
}

fn lib_search_rect(l LibLayout) (int, int, int, int) {
	// the count badge on the right needs ~110px; the field takes the rest
	return l.fx + 12, l.search_y, l.fw - 24 - 116, l.search_h
}

fn lib_chip_w(label string) int {
	return label.len * 6 + 20
}

// lib_chip_rows measures how many chip rows the current tab's labels need.
// Rows grow with the catalog (no cap): every chip is drawn and hit-testable,
// and the grid below recomputes from chips_h. The chip list is catalog-
// driven (Skills domains), so a silently dropped chip would be a filter the
// user can never reach.
fn lib_chip_rows(mut app GuiApp, fx int, fw int) int {
	return lib_chip_rows_for(lib_chips(mut app), fx, fw)
}

fn lib_chip_rows_for(labels []string, fx int, fw int) int {
	mut x := fx + 12
	mut rows := 1
	for lb in labels {
		cw := lib_chip_w(lb)
		if x + cw > fx + fw - 12 && x > fx + 12 {
			rows++
			x = fx + 12
		}
		x += cw + 6
	}
	return rows
}

// lib_chip_rect returns the rect for chip i of labels — the same wrapping
// walk as lib_chip_rows, so drawing and hit-testing never disagree. w == 0
// only for an out-of-range index.
fn lib_chip_rect(l LibLayout, labels []string, i int) (int, int, int, int) {
	mut x := l.fx + 12
	mut row := 0
	for j, lb in labels {
		cw := lib_chip_w(lb)
		if x + cw > l.fx + l.fw - 12 && x > l.fx + 12 {
			row++
			x = l.fx + 12
		}
		if j == i {
			return x, l.chips_y + row * 28, cw, 24
		}
		x += cw + 6
	}
	return 0, 0, 0, 0
}

// lib_card_rect returns the rect of the visible card slot v (row-major).
fn lib_card_rect(l LibLayout, v int) (int, int, int, int) {
	if l.cols == 0 {
		return 0, 0, 0, 0
	}
	col := v % l.cols
	row := v / l.cols
	return l.fx + 12 + col * (l.card_w + l.gap), l.grid_y + row * (l.card_h + l.gap), l.card_w, l.card_h
}

// detail-pane action buttons: primary + up to two secondary
fn lib_btn_rect(l LibLayout, which int) (int, int, int, int) {
	x := l.side_x + 16
	inner := l.side_w - 32
	y := lib_detail_actions_y(l)
	pw := if inner >= 300 { 132 } else { 112 }
	sw := (inner - pw - 16) / 2
	return match which {
		0 { x, y, pw, 34 }
		1 { x + pw + 8, y, sw, 34 }
		else { x + pw + 8 + sw + 8, y, sw, 34 }
	}
}

fn lib_detail_actions_y(l LibLayout) int {
	return l.side_y + 176
}

// ── items (Engine truth → one card model) ───────────────────────────────────

struct LibItem {
	id    string
	name  string
	desc  string
	tags  []string
	foot  string // left footer fact (configuration truth)
	foot2 string // right footer fact (catalog truth)
	mark  pixelart.Sprite
	on    bool // installed / enabled — configuration truth only
}

// lib_chips returns the category chips for the active tab. Skills: catalog
// domains. Agents: tiers. Products: kind. MCP: configuration facets.
fn lib_chips(mut app GuiApp) []string {
	match lib_tab_for_panel(app.selected_panel) {
		0 {
			mut out := ['All']
			if app.desktop != unsafe { nil } {
				out << app.desktop.engine_skills_domains()
			}
			return out
		}
		1 {
			return ['All', 'orchestrator', 'holistic', 'specialist', 'archived']
		}
		2 {
			return ['All', 'products', 'packs']
		}
		3 {
			return ['All', 'enabled', 'docker']
		}
		else {
			return ['All']
		}
	}
}

fn lib_chip_active(app &GuiApp, label string) bool {
	if lib_tab_for_panel(app.selected_panel) == 0 {
		return (label == 'All' && app.skills_domain == '') || app.skills_domain == label
	}
	return (label == 'All' && app.lib_filter == '') || app.lib_filter == label
}

fn lib_set_chip(mut app GuiApp, label string) {
	v := if label == 'All' { '' } else { label }
	if lib_tab_for_panel(app.selected_panel) == 0 {
		app.skills_domain = v
		app.skills_scroll = 0
		app.skills_selected = 0
	} else {
		app.lib_filter = v
		app.lib_scroll = 0
		app.lib_sel = 0
	}
	app.inspector_msg = if v == '' { 'Filter: all' } else { 'Filter: ${v}' }
}

// lib_items returns the card models for the active tab. The result is cached
// per frame + filter key: draw, detail, hover and click all read the same
// list, and the products/packs catalogs are parsed at most once per frame.
// Actions bust the cache (lib_invalidate) so the next read sees Engine state.
fn lib_items(mut app GuiApp) []LibItem {
	key := '${app.selected_panel}|${app.skills_query}|${app.skills_domain}|${app.lib_filter}'
	if app.lib_cache_frame == app.frame && app.lib_cache_key == key {
		return app.lib_cache
	}
	out := lib_items_uncached(mut app)
	app.lib_cache = out
	app.lib_cache_key = key
	app.lib_cache_frame = app.frame
	return out
}

fn lib_invalidate(mut app GuiApp) {
	app.lib_cache_frame = -1
}

fn lib_items_uncached(mut app GuiApp) []LibItem {
	mut out := []LibItem{}
	if app.desktop == unsafe { nil } {
		return out
	}
	q := app.skills_query
	match lib_tab_for_panel(app.selected_panel) {
		0 {
			installed := app.desktop.engine_skills_installed()
			for s in app.desktop.engine_skills_search(q, app.skills_domain) {
				on := s.id in installed
				mut tags := [s.domain]
				if s.stability != '' {
					tags << s.stability
				}
				if s.kind != '' && s.kind != 'skill' {
					tags << s.kind
				}
				out << LibItem{
					id: s.id
					name: if s.name != '' { s.name } else { s.id }
					desc: s.description
					tags: tags
					foot: if on { 'installed' } else { 'not installed' }
					mark: pixelart.mark_for_domain(s.domain)
					on: on
				}
			}
		}
		1 {
			tier := if app.lib_filter == 'archived' { '' } else { app.lib_filter }
			for i, a in app.desktop.engine_agents_search(q, tier) {
				if app.lib_filter == 'archived' && !a.archived {
					continue
				}
				if app.lib_filter != 'archived' && a.archived {
					continue
				}
				mut tags := [a.tier]
				if a.role != '' && a.role.to_lower() != a.tier.to_lower() {
					tags << a.role
				}
				if a.archived {
					tags << 'archived'
				}
				foot := if a.delegates_to.len > 0 {
					'delegates to ${a.delegates_to.len}'
				} else {
					'no delegation'
				}
				foot2 := if a.collaborates_with.len > 0 {
					'${a.collaborates_with.len} collaborators'
				} else {
					''
				}
				out << LibItem{
					id: a.id
					name: a.id
					desc: if a.description != '' { a.description } else { a.role }
					tags: tags
					foot: foot
					foot2: foot2
					mark: pixelart.with_identity(pixelart.agent_for_state(.idle), i % 3)
				}
			}
		}
		2 {
			if app.lib_filter != 'packs' {
				prods := if q != '' {
					app.desktop.engine_products_search(q)
				} else {
					app.desktop.engine_products_catalog()
				}
				for p in prods {
					// products.yaml is the only truthful source here: the Engine's
					// skill_ids/version/receipt_path fields are placeholders, not
					// catalog facts, so they are deliberately not shown
					out << LibItem{
						id: p.id
						name: if p.name != '' { p.name } else { p.id }
						desc: p.description.trim("'")
						tags: ['product']
						foot: 'distributions/products.yaml'
						mark: pixelart.mark_for(.delivery)
					}
				}
			}
			if app.lib_filter != 'products' {
				packs := if q != '' {
					app.desktop.engine_packs_search(q)
				} else {
					app.desktop.engine_packs_catalog()
				}
				for pk in packs {
					mut tags := ['pack']
					if pk.docs_only {
						tags << 'docs-only'
					}
					tags << '${pk.skill_count} skills'
					out << LibItem{
						id: pk.id
						name: if pk.name != '' { pk.name } else { pk.id }
						desc: if pk.docs_only {
							'Documentation pack — enables guidance without installing skills (ADR-006).'
						} else {
							'Solution pack from packs/${pk.id}.'
						}
						tags: tags
						foot: if pk.enabled { 'enabled' } else { 'not enabled' }
						mark: pixelart.mark_for(.pack)
						on: pk.enabled
					}
				}
			}
		}
		3 {
			provs := if q != '' {
				app.desktop.engine_mcp_search(q)
			} else {
				app.desktop.engine_mcp_catalog()
			}
			for i, p in provs {
				if app.lib_filter == 'enabled' && !p.enabled {
					continue
				}
				if app.lib_filter == 'docker' && !p.requires_docker {
					continue
				}
				// deterministic node colour per provider — identity, not health
				swaps := ['B', 'c', 'f', 'r', 's', 'm']
				sw := swaps[i % swaps.len]
				mark := if sw == 'B' {
					pixelart.mark_for(.mcp)
				} else {
					pixelart.with_materials(pixelart.mark_for(.mcp), 'B', sw, '-' + sw)
				}
				mut tags := []string{}
				if p.health != '' {
					tags << p.health
				}
				if p.requires_docker {
					tags << 'docker'
				}
				out << LibItem{
					id: p.id
					name: if p.name != '' { p.name } else { p.id }
					desc: if p.description != '' {
						p.description
					} else {
						'MCP provider template ${p.id}.'
					}
					tags: tags
					foot: if p.enabled { 'enabled' } else { 'not enabled' }
					foot2: if p.version != '' { 'v${p.version}' } else { '' }
					mark: mark
					on: p.enabled
				}
			}
		}
		else {}
	}
	return out
}

// lib_scroll_row / lib_selected read the per-tab state (Skills keeps its
// pre-existing fields so shortcuts and tests stay valid).
fn lib_scroll_row(app &GuiApp) int {
	return if lib_tab_for_panel(app.selected_panel) == 0 {
		app.skills_scroll
	} else {
		app.lib_scroll
	}
}

fn lib_set_scroll_row(mut app GuiApp, v int) {
	if lib_tab_for_panel(app.selected_panel) == 0 {
		app.skills_scroll = v
	} else {
		app.lib_scroll = v
	}
}

fn lib_selected(app &GuiApp) int {
	return if lib_tab_for_panel(app.selected_panel) == 0 {
		app.skills_selected
	} else {
		app.lib_sel
	}
}

fn lib_set_selected(mut app GuiApp, v int) {
	if lib_tab_for_panel(app.selected_panel) == 0 {
		app.skills_selected = v
	} else {
		app.lib_sel = v
	}
}

// lib_visible_range clamps the scroll row and returns [start, end) item
// indexes for the visible grid (selection is revalidated by callers).
fn lib_visible_range(mut app GuiApp, l LibLayout, total int) (int, int) {
	if l.cols == 0 || l.rows == 0 {
		return 0, 0
	}
	total_rows := (total + l.cols - 1) / l.cols
	row := clamp_scroll(lib_scroll_row(app), total_rows, l.rows)
	lib_set_scroll_row(mut app, row)
	start := row * l.cols
	mut end := start + l.rows * l.cols
	if end > total {
		end = total
	}
	return start, end
}

// ── text helpers ────────────────────────────────────────────────────────────

// lib_wrap splits s into at most max_lines lines of about per characters,
// marking overflow with an ellipsis on the last line.
fn lib_wrap(s string, per int, max_lines int) []string {
	mut lines := []string{}
	if max_lines <= 0 || per <= 0 {
		return lines
	}
	mut line := ''
	for word in s.split(' ') {
		if word == '' {
			continue
		}
		cand := if line == '' { word } else { line + ' ' + word }
		if cand.runes().len > per && line != '' {
			lines << line
			line = word
			if lines.len == max_lines {
				break
			}
		} else {
			line = cand
		}
	}
	if lines.len < max_lines && line != '' {
		lines << line
	}
	if lines.len == max_lines {
		joined := lines.join(' ')
		if joined.runes().len < s.trim_space().runes().len {
			last := lines[max_lines - 1]
			cut := if last.runes().len > per - 1 { per - 1 } else { last.runes().len }
			lines[max_lines - 1] = utf8_truncate(last, cut) + '…'
		}
	}
	// hard-clip any line that is still too long (single very long words)
	for i, ln in lines {
		if ln.runes().len > per {
			lines[i] = utf8_truncate(ln, per - 1) + '…'
		}
	}
	return lines
}

// lib_clip truncates to n runes and marks the cut with an ellipsis.
fn lib_clip(s string, n int) string {
	if n <= 1 || s.runes().len <= n {
		return s
	}
	return utf8_truncate(s, n - 1) + '…'
}

fn lib_text(mut app GuiApp, x int, y int, s string, size int, c gg.Color, bold bool) {
	app.gg.draw_text(x, y, s, gg.TextCfg{
		color: c
		size: size
		bold: bold
	})
}

// lib_check draws a check glyph from pixel runs (the bundled fonts have no
// dependable ✓ glyph).
fn lib_check(mut app GuiApp, x int, y int, c gg.Color) {
	onb_check(mut app, x, y, c)
}

// lib_sheet is the soft paper surface every card and the detail column sit
// on: a quiet edge, a faint drop, no wireframe double borders.
fn lib_sheet(mut app GuiApp, x int, y int, w int, h int) {
	app.gg.draw_rect_filled(x + 2, y + 2, w, h, tint(col_ink, 12))
	app.gg.draw_rounded_rect_filled(x, y, w, h, 4, pc(app, `P`))
	app.gg.draw_rounded_rect_empty(x, y, w, h, 4, tint(pc(app, `W`), 60))
}

// lib_pill draws a chip; filled sage when active.
fn lib_pill(mut app GuiApp, x int, y int, w int, h int, label string, active bool, hover bool) {
	sage := app.pnl_success
	if active {
		app.gg.draw_rounded_rect_filled(x, y, w, h, h / 2, sage)
	} else {
		app.gg.draw_rounded_rect_filled(x, y, w, h, h / 2, if hover {
			tint(pc(app, `m`), 140)
		} else {
			tint(pc(app, `m`), 90)
		})
	}
	lib_text(mut app, x + 10, y + (h - 14) / 2, label, 11, if active {
		app.pnl_bg
	} else {
		app.pnl_text
	}, active)
}

// lib_tag is the small manila fact chip on cards and in the detail pane.
fn lib_tag(mut app GuiApp, x int, y int, label string, accent bool) int {
	w := label.len * 6 + 14
	app.gg.draw_rounded_rect_filled(x, y, w, 18, 4, if accent {
		tint(app.pnl_success, 70)
	} else {
		tint(pc(app, `m`), 110)
	})
	lib_text(mut app, x + 7, y + 2, label, 11, if accent { app.pnl_success } else { app.pnl_text }, false)
	return w
}

// ── drawing ─────────────────────────────────────────────────────────────────

// draw_library is the panel body for panels 1/2/10/3.
fn draw_library(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	l := lib_layout(mut app, w, h)
	pid := office_palette_id(app)
	app.gg.draw_rect_filled(l.fx, l.fy, l.fw, l.fh, app.pnl_bg)
	if l.banner_w > 0 {
		// header band continues over the detail column (drawn later, below it)
		app.gg.draw_rect_filled(l.side_x, l.fy, l.side_w, l.side_y - l.fy, app.pnl_bg)
	}

	draw_lib_header(mut app, l, pid)
	draw_lib_tabs(mut app, l, pid)
	items := lib_items(mut app)
	draw_lib_search(mut app, l, items.len)
	draw_lib_chips(mut app, l)
	draw_lib_grid(mut app, l, pid, items)
}

fn draw_lib_header(mut app GuiApp, l LibLayout, pid pixelart.PaletteId) {
	mut sc := app.pixel_cache
	rtl := app.lang.is_rtl()
	y := l.head_y
	// bookshelf mark beside the title, like the reference; in RTL the mark
	// hugs the panel's right edge and the text block starts where the
	// (left-side) banner ends
	shelf := pixelart.environment_for(.shelf)
	s := if l.compact { 2 } else { 3 }
	x := if rtl { l.fx + l.fw - 14 - shelf.width() * s } else { l.fx + 14 }
	sc.draw(shelf, pid, x, y + (l.head_h - shelf.height() * s) / 2 - 2, s)
	tx := if rtl {
		if l.banner_w > 0 { l.banner_x + l.banner_w + 12 } else { l.fx + 14 }
	} else {
		x + shelf.width() * s + 14
	}
	title := tr(app, 'nav.group.library')
	app.gg.draw_text(tx, y + (if l.compact { 2 } else { 10 }), title, gg.TextCfg{
		color: app.pnl_text
		size: if l.compact { 22 } else { 28 }
		family: app.fonts.display
	})
	sub := tr(app, 'lib.subtitle')
	max_px := if rtl {
		x - tx - 12
	} else if l.banner_w > 0 {
		l.banner_x - tx - 12
	} else {
		l.fw - (tx - l.fx) - 20
	}
	app.gg.draw_text(tx, y + (if l.compact { 30 } else { 46 }), utf8_truncate(sub, onb_fit(max_px, 13)), gg.TextCfg{
		color: app.pnl_text_mut
		size: 13
	})
	if l.banner_w > 0 {
		draw_lib_banner(mut app, l.banner_x, y, l.banner_w, l.head_h, pid)
	}
}

// draw_lib_banner composes the header illustration as a floor-to-ceiling
// reading room, layered back to front: dark wood back wall with a crown band,
// plank floor (same rhythm as the Office room), one continuous wall of tall
// shelves (butted, alternating book materials) broken only by a reading nook
// — chalkboard sign, pendant lamp with a warm pool, welcome desk with an idle
// builder, a side table with a globe — then a ladder, plants of two sizes and
// book piles on the floor. Deterministic and static; environmental only —
// nothing here encodes catalog counts or runtime activity.
fn draw_lib_banner(mut app GuiApp, x int, y int, w int, h int, pid pixelart.PaletteId) {
	mut sc := app.pixel_cache
	ink := app.appearance_dark
	// ── surfaces: back wall, crown, floor planks ─────────────────────────
	wall := if ink {
		mix(pc(app, `S`), pc(app, `W`), 0.45)
	} else {
		mix(pc(app, `W`), pc(app, `k`), 0.22)
	}
	seam := mix(wall, pc(app, `k`), 0.30)
	floor_h := 12
	floor_y := y + h - floor_h
	floor_col := if ink {
		mix(pc(app, `S`), pc(app, `w`), 0.22)
	} else {
		mix(pc(app, `w`), pc(app, `p`), 0.62)
	}
	floor_seam := if ink {
		mix(floor_col, pc(app, `k`), 0.40)
	} else {
		mix(pc(app, `W`), floor_col, 0.50)
	}
	floor_hi := if ink {
		mix(floor_col, pc(app, `w`), 0.10)
	} else {
		mix(floor_col, pc(app, `p`), 0.22)
	}
	app.gg.draw_rounded_rect_filled(x, y, w, h, 4, wall)
	for py := y + 14; py < floor_y - 2; py += 12 {
		app.gg.draw_rect_filled(x + 2, py, w - 4, 1, seam)
	}
	crown_h := 6
	app.gg.draw_rect_filled(x + 1, y + 1, w - 2, crown_h, pc(app, `W`))
	app.gg.draw_rect_filled(x + 1, y + crown_h, w - 2, 1, pc(app, `w`))
	// wainscot rail just above the floor
	app.gg.draw_rect_filled(x + 1, floor_y - 3, w - 2, 2, pc(app, `w`))
	// floor: two plank rows with staggered joints (Office room rhythm)
	app.gg.draw_rect_filled(x + 1, floor_y, w - 2, floor_h - 1, floor_col)
	ph := floor_h / 2
	for row_i in 0 .. 2 {
		py := floor_y + row_i * ph
		if row_i == 1 {
			app.gg.draw_rect_filled(x + 1, py, w - 2, ph - 1, floor_hi)
		}
		app.gg.draw_rect_filled(x + 1, py, w - 2, 1, floor_seam)
		mut jx := x + 4 + if row_i == 0 { 0 } else { 13 }
		for jx < x + w - 2 {
			app.gg.draw_rect_filled(jx, py + 1, 1, ph - 1, floor_seam)
			jx += 26
		}
	}
	app.gg.draw_rounded_rect_empty(x, y, w, h, 4, tint(pc(app, `k`), 140))
	base := floor_y + 1

	// ── sprites and material variants ───────────────────────────────────
	shelf_a := pixelart.with_materials(pixelart.environment_for(.bookshelf_wide), 'Ww', 'wW', '-light')
	shelf_b := pixelart.with_materials(shelf_a, 'crfa', 'acrf', '-alt')
	plant := pixelart.environment_for(.plant)
	board := pixelart.with_materials(pixelart.environment_for(.chalkboard), 'W', 'w', '-light')
	ladder := pixelart.with_materials(pixelart.environment_for(.ladder), 'w', 'B', '-brass')
	desk := pixelart.environment_for(.welcome_desk)
	lamp := pixelart.environment_for(.lamp)
	books := pixelart.environment_for(.books)
	globe := pixelart.environment_for(.globe)
	table := pixelart.environment_for(.meeting_table)
	agent := pixelart.with_identity(pixelart.agent_for_state(.idle), 2)
	// pendant: the lamp head only, hung from the crown on a cable
	pendant := pixelart.Sprite{
		name: 'env-lamp-pendant'
		rows: lamp.rows[0..4]
	}
	s := onb_art_scale(shelf_a.width(), shelf_a.height(), w, h - floor_h - crown_h)
	sw := shelf_a.width() * s
	shelf_top := base - shelf_a.height() * s

	// ── continuous shelving with one nook opening ────────────────────────
	pad := 4
	total := w - 2 * pad
	nook_min := 130
	mut n := (total - nook_min) / sw
	if n < 0 {
		n = 0
	}
	n_left := n / 2 + n % 2
	n_right := n / 2
	nook_x := x + pad + n_left * sw
	nook_w := total - n * sw
	mut cx := x + pad
	for i in 0 .. n_left {
		sc.draw(if i % 2 == 0 { shelf_a } else { shelf_b }, pid, cx, shelf_top, s)
		cx += sw
	}
	cx = nook_x + nook_w
	for i in 0 .. n_right {
		sc.draw(if i % 2 == 1 { shelf_a } else { shelf_b }, pid, cx, shelf_top, s)
		cx += sw
	}

	// ── reading nook: lamp pool first, then sign, desk, builder, table ───
	nook_cx := nook_x + nook_w / 2
	pool_w := if nook_w > 160 { 120 } else { nook_w - 20 }
	app.gg.draw_rounded_rect_filled(nook_cx - pool_w / 2, floor_y - 30, pool_w, 30 + floor_h - 3, 14, tint(pc(app, `b`), 80))
	app.gg.draw_rounded_rect_filled(nook_cx - pool_w / 3, floor_y - 16, pool_w * 2 / 3, 16 + floor_h - 3, 8, tint(pc(app, `B`), 50))
	// pendant lamp on a cable from the crown
	ps := 2
	pend_x := nook_cx - pendant.width() * ps / 2
	pend_y := y + crown_h + 10
	app.gg.draw_rect_filled(nook_cx - 1, y + crown_h, 2, pend_y - y - crown_h, pc(app, `k`))
	sc.draw(pendant, pid, pend_x, pend_y, ps)
	// chalkboard sign on the wall, left of the lamp — two honest words
	bs := 2
	bx := nook_x + 6
	by := y + crown_h + 6
	if bx + board.width() * bs < pend_x - 2 {
		sc.draw(board, pid, bx, by, bs)
		app.gg.draw_text(bx + 6, by + 3, 'plan', gg.TextCfg{
			color: pc(app, `e`)
			size: 9
			bold: true
		})
		app.gg.draw_text(bx + 6, by + 12, 'build', gg.TextCfg{
			color: pc(app, `e`)
			size: 9
			bold: true
		})
	}
	// framed picture on the wall over the side table (right of the lamp)
	picture := pixelart.environment_for(.picture)
	pic_x := nook_x + nook_w - picture.width() * 2 - 8
	if pic_x > pend_x + pendant.width() * ps + 6 {
		sc.draw(picture, pid, pic_x, y + crown_h + 8, 2)
	}
	// welcome desk with the idle builder under the lamp
	ds := 2
	dx := nook_cx - desk.width() * ds / 2
	dy := base - desk.height() * ds
	sc.draw(agent, pid, dx + (desk.width() * ds - agent.width() * ds) / 2, dy - agent.height() * ds + 10, ds)
	sc.draw(desk, pid, dx, dy, ds)
	// side table with the globe, right side of the nook
	ts := 2
	tx := dx + desk.width() * ds + 6
	if tx + table.width() * ts <= nook_x + nook_w - 2 {
		sc.draw(table, pid, tx, base - table.height() * ts, ts)
		sc.draw(globe, pid, tx + (table.width() * ts - globe.width() * 2) / 2, base - table.height() * ts - globe.height() * 2 + 4, 2)
	}
	// book pile on the floor, left of the desk
	if dx - books.width() * 2 - 4 > nook_x {
		sc.draw(books, pid, dx - books.width() * 2 - 4, base - books.height() * 2, 2)
	}

	// ── foreground: ladder, plants of two sizes, more book piles ─────────
	if n_left > 0 {
		lx := nook_x - ladder.width() * s - 4 * s
		sc.draw(ladder, pid, lx, base - ladder.height() * s, s)
	}
	sc.draw(plant, pid, x + pad + 2, base - plant.height() * 3, 3)
	if n_right > 0 {
		sc.draw(plant, pid, x + w - pad - plant.width() * 2 - 2, base - plant.height() * 2, 2)
		sc.draw(books, pid, x + w - pad - plant.width() * 2 - books.width() * 2 - 6, base - books.height() * 2, 2)
	}
}

fn draw_lib_tabs(mut app GuiApp, l LibLayout, pid pixelart.PaletteId) {
	mut sc := app.pixel_cache
	labels := [tr(app, 'panel.skills'), tr(app, 'panel.agents'), tr(app, 'panel.products'),
		tr(app, 'panel.mcp')]
	mut marks := [pixelart.mark_for(.core), pixelart.agent_for_state(.idle),
		pixelart.mark_for(.pack), pixelart.mark_for(.mcp)]
	if app.appearance_dark {
		// the 1px ink outline vanishes on Ink chrome at 16px; steel keeps
		// the glyph legible (material variant, same grid)
		for i in [0, 2, 3] {
			marks[i] = pixelart.with_materials(marks[i], 'k', 'l', '-ink')
		}
	}
	// one hairline under the whole tab row; the active tab carries a sage bar
	app.gg.draw_rect_filled(l.fx + 12, l.tabs_y + l.tabs_h - 1, l.fw - 24, 1, tint(pc(app, `W`), 70))
	for i, lb in labels {
		tx, ty, tw, th := lib_tab_rect(l, i)
		active := i == l.tab
		hover := app.lib_hover_ui == lib_ui_tab0 + i
		if hover && !active {
			app.gg.draw_rect_filled(tx, ty, tw, th - 2, tint(pc(app, `m`), 60))
		}
		m := marks[i]
		ms := 1
		my := ty + (th - m.height() * ms) / 2 - 1
		sc.draw(m, pid, tx + 8, my, ms)
		lib_text(mut app, tx + 8 + m.width() * ms + 8, ty + 7, utf8_truncate(lb, onb_fit(tw - 40, 14)), 14, if active {
			app.pnl_text
		} else {
			app.pnl_text_mut
		}, active)
		if active {
			app.gg.draw_rect_filled(tx, ty + th - 3, tw, 3, app.pnl_success)
		}
	}
}

fn draw_lib_search(mut app GuiApp, l LibLayout, count int) {
	sx, sy, sw, sh := lib_search_rect(l)
	focus := app.lib_hover_ui == lib_ui_search
	app.gg.draw_rounded_rect_filled(sx, sy, sw, sh, 6, pc(app, `P`))
	app.gg.draw_rounded_rect_empty(sx, sy, sw, sh, 6, if focus {
		app.pnl_success
	} else {
		tint(pc(app, `W`), 110)
	})
	// magnifier glyph from runs — functional icon class, not a sprite
	gx := sx + 12
	gy := sy + 9
	app.gg.draw_rounded_rect_empty(gx, gy, 9, 9, 4, app.pnl_text_mut)
	app.gg.draw_rect_filled(gx + 8, gy + 8, 2, 5, app.pnl_text_mut)
	app.gg.draw_rect_filled(gx + 9, gy + 9, 3, 2, app.pnl_text_mut)
	q := app.skills_query
	hint := match l.tab {
		0 { 'Search skills, e.g. "review", "figma", "github"…' }
		1 { 'Search agents, e.g. "reviewer", "planner"…' }
		2 { 'Search products and packs…' }
		else { 'Search MCP providers, e.g. "github", "slack"…' }
	}
	shown := if q == '' { hint } else { q }
	lib_text(mut app, sx + 30, sy + 8, utf8_truncate(shown, onb_fit(sw - 44, 13)), 13, if q == '' {
		app.pnl_text_mut
	} else {
		app.pnl_text
	}, false)
	if q != '' {
		// caret: typing goes here while a Library panel is active
		app.gg.draw_rect_filled(sx + 30 + shown.runes().len * 7 + 2, sy + 8, 1, 15, app.pnl_text)
	}
	// honest result count on the right instead of a Filters/Sort control we
	// do not have
	total := lib_total(mut app)
	label := if count == total { '${total}' } else { '${count} of ${total}' }
	kind := match l.tab {
		0 { 'skills' }
		1 { 'agents' }
		2 { 'items' }
		else { 'providers' }
	}
	lib_text(mut app, sx + sw + 12, sy + 9, '${label} ${kind}', 12, app.pnl_text_mut, false)
}

// lib_total is the unfiltered catalog size for the active tab.
fn lib_total(mut app GuiApp) int {
	if app.desktop == unsafe { nil } {
		return 0
	}
	return match lib_tab_for_panel(app.selected_panel) {
		0 { app.desktop.engine_skills_stats().total }
		1 { agents_active_total(mut app) }
		2 { app.desktop.engine_products_catalog().len + app.desktop.engine_packs_catalog().len }
		else { app.desktop.engine_mcp_stats().total }
	}
}

fn draw_lib_chips(mut app GuiApp, l LibLayout) {
	labels := lib_chips(mut app)
	for i, lb in labels {
		cx, cy, cw, ch := lib_chip_rect(l, labels, i)
		if cw == 0 {
			continue
		}
		lib_pill(mut app, cx, cy, cw, ch, lb, lib_chip_active(app, lb), app.lib_hover_ui == lib_ui_chip0 + i)
	}
}

fn draw_lib_grid(mut app GuiApp, l LibLayout, pid pixelart.PaletteId, items []LibItem) {
	mut sc := app.pixel_cache
	if items.len == 0 {
		msg := if app.desktop == unsafe { nil } {
			'Catalog unavailable — Engine not booted.'
		} else if app.skills_query != '' || app.skills_domain != '' || app.lib_filter != '' {
			'Nothing matches — clear the search or filter (Esc).'
		} else {
			'This catalog is empty in the resolved toolkit root.'
		}
		lib_text(mut app, l.fx + 16, l.grid_y + 12, msg, 13, app.pnl_text_mut, false)
		return
	}
	start, end := lib_visible_range(mut app, l, items.len)
	mut sel := lib_selected(app)
	if sel >= items.len || sel < 0 {
		sel = 0
		lib_set_selected(mut app, 0)
	}
	for idx in start .. end {
		item := items[idx]
		cx, cy, cw, ch := lib_card_rect(l, idx - start)
		is_sel := idx == sel
		is_hover := idx == app.lib_hover
		lib_sheet(mut app, cx, cy, cw, ch)
		if is_sel {
			app.gg.draw_rounded_rect_filled(cx, cy, cw, ch, 4, tint(app.pnl_success, 28))
			app.gg.draw_rounded_rect_empty(cx, cy, cw, ch, 4, app.pnl_success)
			app.gg.draw_rounded_rect_empty(cx + 1, cy + 1, cw - 2, ch - 2, 4, app.pnl_success)
		} else if is_hover {
			app.gg.draw_rounded_rect_empty(cx, cy, cw, ch, 4, tint(app.pnl_success, 140))
		}
		// mark: 48px identity tile
		ms := 48 / item.mark.width()
		mx := cx + 10
		my := cy + 10
		app.gg.draw_rounded_rect_filled(mx - 2, my - 2, 52, 52, 6, tint(pc(app, `m`), 70))
		sc.draw(item.mark, pid, mx + (48 - item.mark.width() * ms) / 2, my + (48 - item.mark.height() * ms) / 2, ms)
		tx := cx + 70
		tw := cw - 70 - 10
		lib_text(mut app, tx, cy + 9, lib_clip(item.name, onb_fit(tw, 14)), 14, app.pnl_text, true)
		desc_lines := if ch >= 120 { 3 } else { 2 }
		for li, ln in lib_wrap(item.desc, onb_fit(tw, 12), desc_lines) {
			lib_text(mut app, tx, cy + 28 + li * 14, ln, 12, app.pnl_text_mut, false)
		}
		// tags row; short cards fold the configuration fact into an accent tag
		short := ch < 100
		mut tgx := cx + 10
		tgy := if short { cy + ch - 26 } else { cy + ch - 40 }
		if short && item.on {
			tgx += lib_tag(mut app, tgx, tgy, item.foot, true) + 5
		}
		for t in item.tags {
			tw2 := t.len * 6 + 14
			if tgx + tw2 > cx + cw - 8 {
				break
			}
			tgx += lib_tag(mut app, tgx, tgy, t, false) + 5
		}
		if !short {
			// footer facts: configuration truth left, catalog truth right
			fy2 := cy + ch - 16
			lib_text(mut app, cx + 10, fy2, item.foot, 11, if item.on {
				app.pnl_success
			} else {
				app.pnl_text_mut
			}, item.on)
			if item.foot2 != '' && cw > 180 {
				fw2 := item.foot2.len * 6
				lib_text(mut app, cx + cw - 10 - fw2, fy2, item.foot2, 11, app.pnl_text_mut, false)
			}
		}
	}
	// scroll indicator + honest count under the grid
	total_rows := (items.len + l.cols - 1) / l.cols
	row := lib_scroll_row(app)
	foot := if items.len > end - start {
		'${start + 1}–${end} of ${items.len} · wheel or ↑↓ to scroll · Enter toggles the selected card'
	} else {
		'${items.len} shown · Enter toggles the selected card'
	}
	lib_text(mut app, l.fx + 14, l.fy + l.fh - 16, utf8_truncate(foot, onb_fit(l.fw - 40, 11)), 11, app.pnl_text_mut, false)
	if total_rows > l.rows && l.rows > 0 {
		track_x := l.fx + l.fw - 8
		bar_h := if l.grid_h * l.rows / total_rows < 16 {
			16
		} else {
			l.grid_h * l.rows / total_rows
		}
		bar_y := l.grid_y + (l.grid_h - bar_h) * row / (total_rows - l.rows)
		app.gg.draw_rect_filled(track_x, l.grid_y, 3, l.grid_h, tint(pc(app, `W`), 40))
		app.gg.draw_rect_filled(track_x, bar_y, 3, bar_h, tint(pc(app, `W`), 160))
	}
}

// ── detail column (replaces the Office inspector for Library panels) ─────────

struct LibFact {
	label string
	value string
	ok    bool // draws a check instead of a dash when true
	mono  bool
}

struct LibDetail {
	title     string
	sub       string
	desc      string
	tags      []string
	mark      pixelart.Sprite
	primary   string
	on        bool // primary is a "remove/disable" action (outlined)
	quiet     bool // primary is a non-mutating helper (copy), drawn as a plain button
	second    string
	third     string
	compat    []LibFact
	prov      []LibFact
	inc_title string
	included  []string
	inc_mono  bool // included lines are code (masked template), not a checklist
	quote     string
	quote_by  string
}

// lib_targets_fact summarizes the targets registry: enabled targets are the
// real destinations a capability deploys to.
fn lib_targets_fact(mut app GuiApp) (string, bool) {
	tg := app.desktop.engine_targets()
	en := tg.filter(it.enabled).map(it.id)
	if en.len == 0 {
		return '0 of ${tg.len} enabled', false
	}
	mut s := en[..if en.len > 3 { 3 } else { en.len }].join(', ')
	if en.len > 3 {
		s += ' +${en.len - 3}'
	}
	return s, true
}

fn lib_detail(mut app GuiApp, items []LibItem) ?LibDetail {
	if app.desktop == unsafe { nil } || items.len == 0 {
		return none
	}
	sel := lib_selected(app)
	if sel < 0 || sel >= items.len {
		return none
	}
	item := items[sel]
	tfact, tok := lib_targets_fact(mut app)
	found := app.desktop.engine_tool_discovery_catalog_cached()
	nfound := found.filter(it.found).len
	match lib_tab_for_panel(app.selected_panel) {
		0 {
			s := app.desktop.engine_skill_detail(item.id) or { return none }
			installed := s.id in app.desktop.engine_skills_installed()
			mut prov := [
				LibFact{'Source', 'skills/${s.id}/SKILL.md', false, true},
				LibFact{'Stability', if s.stability != '' { s.stability } else { 'unknown' }, s.stability == 'stable', false},
			]
			if r := app.desktop.engine_skill_receipt(s.id) {
				prov << LibFact{'Receipt', '${r.installed_at} · v${r.version}', true, true}
				prov << LibFact{'Digest', utf8_truncate(r.digest, 16), false, true}
			} else {
				prov << LibFact{'Receipt', 'none — not deployed yet', false, false}
			}
			mut inc := ['SKILL.md — definition and instructions']
			if s.triggers != '' {
				inc << 'Triggers: ${utf8_truncate(s.triggers, 40)}'
			}
			return LibDetail{
				title: item.name
				sub: s.id
				desc: s.description
				tags: item.tags
				mark: item.mark
				primary: if installed { 'Remove' } else { 'Install' }
				on: installed
				second: 'Copy id'
				third: ''
				compat: [
					LibFact{'Targets', tfact, tok, false},
					LibFact{'Tools found', '${nfound} of ${found.len} on this computer', nfound > 0, false},
					LibFact{'Selected', if installed { 'yes — in this workspace' } else { 'no' }, installed, false},
				]
				prov: prov
				inc_title: "What's included"
				included: inc
				quote: '"Good tools make brighter builders."'
				quote_by: '— Hornero'
			}
		}
		1 {
			mut ag := desktop_engine.AgentEntry{}
			for a in app.desktop.engine_agents_search('', '') {
				if a.id == item.id {
					ag = a
					break
				}
			}
			mut prov := [
				LibFact{'Source', if ag.source_file != '' {
					ag.source_file
				} else {
					'agents/${ag.id}/AGENT.md'
				}, false, true},
			]
			if ag.provenance != '' {
				prov << LibFact{'Provenance', utf8_truncate(ag.provenance, 28), false, true}
			}
			if r := app.desktop.engine_agent_receipt(ag.id) {
				prov << LibFact{'Receipt', r.installed_at, true, true}
			} else {
				prov << LibFact{'Receipt', 'none — not deployed yet', false, false}
			}
			mut inc := ['AGENT.md — persona contract']
			for d in ag.delegates_to {
				inc << 'Delegates to ${d}'
			}
			for c in ag.collaborates_with {
				inc << 'Collaborates with ${c}'
			}
			return LibDetail{
				title: ag.id
				sub: 'agents/${ag.id}'
				desc: if ag.description != '' { ag.description } else { ag.role }
				tags: item.tags
				mark: item.mark
				primary: 'Copy id'
				quiet: true
				second: ''
				compat: [
					LibFact{'Targets', tfact, tok, false},
					LibFact{'Holistic owner', if ag.holistic_owner != '' {
						ag.holistic_owner
					} else {
						'—'
					}, ag.holistic_owner != '', false},
					LibFact{'Archived', if ag.archived { 'yes' } else { 'no' }, !ag.archived, false},
				]
				prov: prov
				inc_title: 'Relationships'
				included: inc
				quote: '"Different agents. A brighter tomorrow."'
				quote_by: '— Agent Toolkit'
			}
		}
		2 {
			if item.tags.len > 0 && item.tags[0] == 'pack' {
				mut pk := desktop_engine.PackEntry{}
				for p in app.desktop.engine_packs_catalog() {
					if p.id == item.id {
						pk = p
						break
					}
				}
				return LibDetail{
					title: item.name
					sub: 'packs/${pk.id}'
					desc: item.desc
					tags: item.tags
					mark: item.mark
					primary: if pk.enabled { 'Disable' } else { 'Enable' }
					on: pk.enabled
					second: 'Copy id'
					compat: [
						LibFact{'Targets', tfact, tok, false},
						LibFact{'Docs-only', if pk.docs_only { 'yes (ADR-006)' } else { 'no' }, true, false},
						LibFact{'Enabled', if pk.enabled { 'yes' } else { 'no' }, pk.enabled, false},
					]
					prov: [
						LibFact{'Source', if pk.provenance != '' {
							pk.provenance
						} else {
							'packs/${pk.id}/config.yaml'
						}, false, true},
					]
					inc_title: "What's included"
					included: ['${pk.skill_count} skills referenced']
					quote: '"Small agents. Brighter worlds."'
					quote_by: '— Agent Toolkit'
				}
			}
			mut pr := desktop_engine.ProductEntry{}
			for p in app.desktop.engine_products_catalog() {
				if p.id == item.id {
					pr = p
					break
				}
			}
			return LibDetail{
				title: item.name
				sub: 'products/${pr.id}'
				desc: pr.description.trim("'")
				tags: item.tags
				mark: item.mark
				primary: 'Install'
				second: 'Copy id'
				compat: [
					LibFact{'Targets', tfact, tok, false},
					LibFact{'Tools found', '${nfound} of ${found.len} on this computer', nfound > 0, false},
				]
				prov: [
					LibFact{'Source', 'distributions/products.yaml', false, true},
					LibFact{'Composition', 'not exposed by Engine yet', false, false},
				]
				inc_title: ''
				included: []
				quote: '"Good tools make brighter builders."'
				quote_by: '— Hornero'
			}
		}
		3 {
			mut mp := desktop_engine.McpProvider{}
			for p in app.desktop.engine_mcp_catalog() {
				if p.id == item.id {
					mp = p
					break
				}
			}
			if app.mcp_drawer != mp.id {
				// first selection (or a stale drawer): load the masked
				// template, receipt and probe once, not per frame
				lib_select_mcp(mut app, mp.id)
			}
			probe := if mcp_probe_fresh(app, mp.id) {
				LibFact{'Probe', utf8_truncate(app.mcp_probe_detail, 30), app.mcp_probe_ok, false}
			} else {
				LibFact{'Probe', 'not run — press Probe', false, false}
			}
			mut inc := []string{}
			if app.mcp_drawer == mp.id {
				for i, ln in app.mcp_drawer_template.split('\n') {
					if i >= 6 {
						inc << '…'
						break
					}
					inc << ln
				}
			}
			receipt := if app.mcp_drawer == mp.id && !app.mcp_drawer_receipt.starts_with('(no receipt') {
				utf8_truncate(app.mcp_drawer_receipt, 30)
			} else {
				'none — enable to create one'
			}
			return LibDetail{
				title: item.name
				sub: 'mcp/${mp.id}'
				desc: item.desc
				tags: item.tags
				mark: item.mark
				primary: if mp.enabled { 'Disable' } else { 'Enable' }
				on: mp.enabled
				second: 'Probe'
				third: 'Template'
				compat: [
					LibFact{'Targets', tfact, tok, false},
					LibFact{'Docker', if mp.requires_docker { 'required' } else { 'not required' }, !mp.requires_docker, false},
					LibFact{'Health', if mp.health != '' { mp.health } else { 'unknown' }, mp.health == 'healthy', false},
					probe,
				]
				prov: [
					LibFact{'Template', if mp.template_path != '' {
						mp.template_path
					} else {
						'defaults (no file)'
					}, mp.template_path != '', true},
					LibFact{'Registry', if mp.registry_path != '' {
						mp.registry_path
					} else {
						'mcp/registry'
					}, false, true},
					LibFact{'Version', if mp.version != '' { mp.version } else { 'unknown' }, mp.version != '', false},
					LibFact{'Receipt', receipt, false, true},
				]
				inc_title: 'Template (secrets masked)'
				included: inc
				inc_mono: true
				quote: '"Same curiosity. More capability."'
				quote_by: '— Agent Toolkit'
			}
		}
		else {
			return none
		}
	}
}

// draw_library_detail is the right column while a Library panel is active.
fn draw_library_detail(mut app GuiApp, w int, h int) {
	ensure_pixel_cache(mut app)
	l := lib_layout(mut app, w, h)
	pid := office_palette_id(app)
	mut sc := app.pixel_cache
	x := l.side_x
	y := l.side_y
	iw := l.side_w
	ih := l.fy + l.fh - y
	app.gg.draw_rect_filled(x, y, iw, ih, app.pnl_bg)
	app.gg.draw_rect_filled(x + 8, y + 6, iw - 16, ih - 12, pc(app, `P`))
	app.gg.draw_rect_empty(x + 8, y + 6, iw - 16, ih - 12, tint(pc(app, `W`), 60))
	items := lib_items(mut app)
	d := lib_detail(mut app, items) or {
		lib_text(mut app, x + 20, y + 22, 'Select a card to see details', 14, app.pnl_text_mut, false)
		return
	}
	px := x + 16
	inner := iw - 32
	// identity block
	ms := 64 / d.mark.width()
	app.gg.draw_rounded_rect_filled(px, y + 16, 68, 68, 8, tint(pc(app, `m`), 70))
	sc.draw(d.mark, pid, px + 2 + (64 - d.mark.width() * ms) / 2, y + 18 + (64 - d.mark.height() * ms) / 2, ms)
	tx := px + 80
	tw := inner - 80
	lib_text(mut app, tx, y + 18, lib_clip(d.title, onb_fit(tw, 17)), 17, app.pnl_text, true)
	app.gg.draw_text(tx, y + 40, lib_clip(d.sub, tw / 6), gg.TextCfg{
		color: app.pnl_text_mut
		size: 11
		mono: true
	})
	// tags under the sub line
	mut tgx := tx
	for t in d.tags {
		tw2 := t.len * 6 + 14
		if tgx + tw2 > px + inner {
			break
		}
		tgx += lib_tag(mut app, tgx, y + 58, t, false) + 5
	}
	// description
	mut dy := y + 92
	for ln in lib_wrap(d.desc, onb_fit(inner, 12), 5) {
		lib_text(mut app, px, dy, ln, 12, app.pnl_text, false)
		dy += 14
	}
	// actions
	ay := lib_detail_actions_y(l)
	if ay < dy + 6 {
		// long description: still keep buttons visible below it
		dy = ay - 6
	}
	bx, by, bw, bh := lib_btn_rect(l, 0)
	hov0 := app.lib_hover_ui == lib_ui_primary
	if d.on {
		app.gg.draw_rounded_rect_filled(bx, by, bw, bh, 6, if hov0 {
			tint(app.pnl_danger, 40)
		} else {
			pc(app, `P`)
		})
		app.gg.draw_rounded_rect_empty(bx, by, bw, bh, 6, app.pnl_danger)
		lib_text(mut app, bx + (bw - d.primary.len * 8) / 2, by + 9, d.primary, 14, app.pnl_danger, true)
	} else if d.quiet {
		app.gg.draw_rounded_rect_filled(bx, by, bw, bh, 6, if hov0 {
			tint(pc(app, `m`), 140)
		} else {
			tint(pc(app, `m`), 80)
		})
		app.gg.draw_rounded_rect_empty(bx, by, bw, bh, 6, tint(pc(app, `W`), 90))
		lib_text(mut app, bx + (bw - d.primary.len * 8) / 2, by + 9, d.primary, 14, app.pnl_text, true)
	} else {
		app.gg.draw_rect_filled(bx + 2, by + 3, bw, bh, tint(col_ink, 30))
		app.gg.draw_rounded_rect_filled(bx, by, bw, bh, 6, if hov0 {
			app.pnl_success
		} else {
			tint(app.pnl_success, 225)
		})
		lib_text(mut app, bx + (bw - d.primary.len * 8) / 2, by + 9, d.primary, 14, app.pnl_bg, true)
	}
	for i, lb in [d.second, d.third] {
		if lb == '' {
			continue
		}
		sx, sy, sw, sh := lib_btn_rect(l, i + 1)
		hov := app.lib_hover_ui == lib_ui_second + i
		app.gg.draw_rounded_rect_filled(sx, sy, sw, sh, 6, if hov {
			tint(pc(app, `m`), 140)
		} else {
			tint(pc(app, `m`), 80)
		})
		app.gg.draw_rounded_rect_empty(sx, sy, sw, sh, 6, tint(pc(app, `W`), 90))
		lib_text(mut app, sx + (sw - lb.len * 7) / 2, sy + 10, utf8_truncate(lb, onb_fit(sw - 8, 12)), 12, app.pnl_text, false)
	}
	// fact sections
	mut fy := ay + 34 + 14
	bottom := y + ih - 12
	fy = draw_lib_facts(mut app, px, fy, inner, 'Compatibility', d.compat, bottom)
	fy = draw_lib_facts(mut app, px, fy, inner, 'Provenance', d.prov, bottom)
	// what's included checklist
	if d.included.len > 0 && fy + 40 < bottom {
		lib_text(mut app, px, fy, d.inc_title, 12, app.pnl_text, true)
		fy += 18
		for item in d.included {
			if fy + 16 > bottom - 6 {
				break
			}
			if d.inc_mono {
				app.gg.draw_text(px + 6, fy, utf8_truncate(item, (inner - 6) / 6), gg.TextCfg{
					color: app.pnl_text
					size: 11
					mono: true
				})
			} else {
				app.gg.draw_rect_filled(px, fy + 1, 12, 12, tint(app.pnl_success, 60))
				lib_check(mut app, px + 2, fy + 1, app.pnl_success)
				lib_text(mut app, px + 18, fy, utf8_truncate(item, onb_fit(inner - 18, 11)), 11, app.pnl_text, false)
			}
			fy += 15
		}
		fy += 6
	}
	// editorial quote card right after the facts when there is room
	qh := 52
	if fy + qh + 6 < bottom && d.quote != '' {
		qy := fy + 4
		app.gg.draw_rounded_rect_filled(px, qy, inner, qh, 6, tint(pc(app, `m`), 60))
		app.gg.draw_text(px + 12, qy + 10, lib_clip(d.quote, onb_fit(inner - 52, 12)), gg.TextCfg{
			color: app.pnl_text
			size: 12
			family: app.fonts.display
		})
		lib_text(mut app, px + 12, qy + 30, d.quote_by, 10, app.pnl_text_mut, false)
		nest := pixelart.environment_for(.nest)
		sc.draw(nest, pid, px + inner - nest.width() * 2 - 10, qy + qh - nest.height() * 2 - 6, 2)
	}
}

// draw_lib_facts draws a titled label/value list and returns the next y.
fn draw_lib_facts(mut app GuiApp, x int, y0 int, w int, title string, facts []LibFact, bottom int) int {
	mut y := y0
	if facts.len == 0 || y + 20 > bottom {
		return y
	}
	lib_text(mut app, x, y, title, 12, app.pnl_text, true)
	y += 17
	lw := if w >= 300 { 92 } else { 84 }
	for f in facts {
		if y + 16 > bottom - 4 {
			break
		}
		lib_text(mut app, x, y, f.label, 11, app.pnl_text_mut, false)
		if f.ok {
			lib_check(mut app, x + lw - 16, y + 1, app.pnl_success)
		} else {
			app.gg.draw_rect_filled(x + lw - 14, y + 7, 6, 1, app.pnl_text_mut)
		}
		per := if f.mono { (w - lw) / 6 } else { onb_fit(w - lw, 11) }
		app.gg.draw_text(x + lw, y, utf8_truncate(f.value, per), gg.TextCfg{
			color: app.pnl_text
			size: 11
			mono: f.mono
		})
		y += 15
	}
	return y + 8
}

// ── actions (real Engine calls only) ────────────────────────────────────────

// lib_primary runs the primary action for the selected card of the active tab.
fn lib_primary(mut app GuiApp) {
	if app.desktop == unsafe { nil } {
		return
	}
	items := lib_items(mut app)
	sel := lib_selected(app)
	if sel < 0 || sel >= items.len {
		return
	}
	item := items[sel]
	match lib_tab_for_panel(app.selected_panel) {
		0 {
			rev := app.desktop.engine_toggle_skill(item.id) or {
				app.inspector_msg = 'Skill ${item.id} error: ${err}'
				return
			}
			installed_now := item.id in app.desktop.engine_skills_installed()
			app.engine_rev = app.desktop.app_state_snapshot().revision
			if app.engine_rev == 0 {
				app.engine_rev = rev
			}
			app.api_calls = app.desktop.engine_api_calls()
			action := if installed_now { 'installed' } else { 'removed' }
			app.inspector_msg = 'Skill ${item.id} ${action} rev=${rev} • Engine TX ✓'
			lib_invalidate(mut app)
		}
		1 {
			copy_to_clipboard(mut app, item.id)
		}
		2 {
			if item.tags.len > 0 && item.tags[0] == 'pack' {
				rev := app.desktop.engine_set_pack_enabled(item.id, !item.on) or {
					app.inspector_msg = 'Pack ${item.id} error: ${err}'
					return
				}
				app.engine_rev = rev
				app.api_calls = app.desktop.engine_api_calls()
				verb := if item.on { 'disabled' } else { 'enabled' }
				app.inspector_msg = 'Pack ${item.id} ${verb} rev=${rev} ✓'
				lib_invalidate(mut app)
				return
			}
			rev := app.desktop.onboarding_set_products_bulk([item.id]) or {
				app.onboarding_msg = 'products install failed: ${err}'
				app.inspector_msg = 'Product ${item.id} error: ${err}'
				return
			}
			app.onboarding_msg = 'Product ${item.id} installed rev=${rev} ✓'
			app.inspector_msg = 'Product ${item.id} installed rev=${rev} ✓'
			app.engine_rev = app.desktop.app_state_snapshot().revision
			app.api_calls = app.desktop.engine_api_calls()
		}
		3 {
			rev := app.desktop.engine_mcp_toggle(item.id) or {
				app.inspector_msg = 'MCP ${item.id} toggle failed: ${err} (secret guard? use \${ENV_VAR})'
				return
			}
			prov_json := app.desktop.engine_mcp_provenance_json(item.id)
			app.engine_rev = app.desktop.app_state_snapshot().revision
			if app.engine_rev == 0 {
				app.engine_rev = rev
			}
			app.api_calls = app.desktop.engine_api_calls()
			app.inspector_msg = 'MCP ${item.id} toggled rev=${rev} • ${prov_json} • Engine TX'
			lib_invalidate(mut app)
			lib_select_mcp(mut app, item.id)
		}
		else {}
	}
}

// lib_secondary runs the second/third detail button (which = 0/1).
fn lib_secondary(mut app GuiApp, which int) {
	if app.desktop == unsafe { nil } {
		return
	}
	items := lib_items(mut app)
	sel := lib_selected(app)
	if sel < 0 || sel >= items.len {
		return
	}
	item := items[sel]
	match lib_tab_for_panel(app.selected_panel) {
		3 {
			if which == 0 {
				mcp_run_probe(mut app, item.id, true)
			} else {
				mut tpath := ''
				for p in app.desktop.engine_mcp_catalog() {
					if p.id == item.id {
						tpath = p.template_path
						break
					}
				}
				if app.mcp_drawer != item.id {
					lib_select_mcp(mut app, item.id)
				}
				mcp_open_template(mut app, item.id, tpath)
			}
		}
		else {
			if which == 0 {
				copy_to_clipboard(mut app, item.id)
			}
		}
	}
}

// lib_select_mcp loads the masked template/receipt/probe cache for the
// selected provider so the detail pane can show them without per-frame IO.
fn lib_select_mcp(mut app GuiApp, id string) {
	for p in app.desktop.engine_mcp_catalog() {
		if p.id == id {
			mcp_drawer_open(mut app, p.id, p.template_path, p.provenance)
			return
		}
	}
}

// lib_select selects card idx and loads tab-specific detail caches.
fn lib_select(mut app GuiApp, idx int, items []LibItem) {
	lib_set_selected(mut app, idx)
	if idx < 0 || idx >= items.len || app.desktop == unsafe { nil } {
		return
	}
	item := items[idx]
	match lib_tab_for_panel(app.selected_panel) {
		0 {
			if r := app.desktop.engine_skill_receipt(item.id) {
				app.inspector_msg = 'Receipt: ${r.skill_id} ${r.installed_at} digest=${r.digest}'
			} else {
				app.inspector_msg = 'Selected ${item.id} — Install → Engine TX'
			}
		}
		3 {
			lib_select_mcp(mut app, item.id)
		}
		else {
			app.inspector_msg = 'Selected ${item.id}'
		}
	}
}

// lib_switch_tab moves to another Library panel, resetting per-tab state.
fn lib_switch_tab(mut app GuiApp, tab int) {
	if tab < 0 || tab >= lib_tab_panels.len {
		return
	}
	app.lib_filter = ''
	app.lib_scroll = 0
	app.lib_sel = 0
	app.lib_hover = -1
	select_panel(mut app, lib_tab_panels[tab])
}

// ── interaction (same geometry as drawing) ──────────────────────────────────

// library_click handles a click for panels 1/2/10/3. Returns true when the
// click landed inside the Library surface (panel + detail column).
fn library_click(mut app GuiApp, mx int, my int, w int, h int) bool {
	l := lib_layout(mut app, w, h)
	in_panel := onb_hit(mx, my, l.fx, l.fy, l.fw, l.fh)
	in_side := onb_hit(mx, my, l.side_x, l.fy, l.side_w, l.fh)
	_ = l.side_y
	if !in_panel && !in_side {
		return false
	}
	for i in 0 .. lib_tab_panels.len {
		tx, ty, tw, th := lib_tab_rect(l, i)
		if onb_hit(mx, my, tx, ty, tw, th) {
			if i != l.tab {
				lib_switch_tab(mut app, i)
			}
			return true
		}
	}
	sx, sy, sw, sh := lib_search_rect(l)
	if onb_hit(mx, my, sx, sy, sw, sh) {
		app.palette_open = false
		app.ghost_focused = false
		app.inspector_msg = 'Type to search — Esc clears'
		return true
	}
	labels := lib_chips(mut app)
	for i, lb in labels {
		cx, cy, cw, ch := lib_chip_rect(l, labels, i)
		if cw > 0 && onb_hit(mx, my, cx, cy, cw, ch) {
			lib_set_chip(mut app, lb)
			return true
		}
	}
	items := lib_items(mut app)
	if in_panel {
		start, end := lib_visible_range(mut app, l, items.len)
		for idx in start .. end {
			cx, cy, cw, ch := lib_card_rect(l, idx - start)
			if onb_hit(mx, my, cx, cy, cw, ch) {
				lib_select(mut app, idx, items)
				return true
			}
		}
		return true
	}
	// detail column buttons
	bx, by, bw, bh := lib_btn_rect(l, 0)
	if onb_hit(mx, my, bx, by, bw, bh) {
		lib_primary(mut app)
		return true
	}
	d := lib_detail(mut app, items) or { return true }
	for i, lb in [d.second, d.third] {
		if lb == '' {
			continue
		}
		x2, y2, w2, h2 := lib_btn_rect(l, i + 1)
		if onb_hit(mx, my, x2, y2, w2, h2) {
			lib_secondary(mut app, i)
			return true
		}
	}
	return true
}

// library_hover_at updates card/chrome hover state.
fn library_hover_at(mut app GuiApp, mx int, my int, w int, h int) {
	l := lib_layout(mut app, w, h)
	app.lib_hover = -1
	app.lib_hover_ui = -1
	for i in 0 .. lib_tab_panels.len {
		tx, ty, tw, th := lib_tab_rect(l, i)
		if onb_hit(mx, my, tx, ty, tw, th) {
			app.lib_hover_ui = lib_ui_tab0 + i
			return
		}
	}
	sx, sy, sw, sh := lib_search_rect(l)
	if onb_hit(mx, my, sx, sy, sw, sh) {
		app.lib_hover_ui = lib_ui_search
		return
	}
	labels := lib_chips(mut app)
	for i in 0 .. labels.len {
		cx, cy, cw, ch := lib_chip_rect(l, labels, i)
		if cw > 0 && onb_hit(mx, my, cx, cy, cw, ch) {
			app.lib_hover_ui = lib_ui_chip0 + i
			return
		}
	}
	for i in 0 .. 3 {
		bx, by, bw, bh := lib_btn_rect(l, i)
		if onb_hit(mx, my, bx, by, bw, bh) {
			app.lib_hover_ui = lib_ui_primary + i
			return
		}
	}
	if onb_hit(mx, my, l.fx, l.grid_y, l.fw, l.grid_h) {
		total := lib_items(mut app).len
		start, end := lib_visible_range(mut app, l, total)
		for idx in start .. end {
			cx, cy, cw, ch := lib_card_rect(l, idx - start)
			if onb_hit(mx, my, cx, cy, cw, ch) {
				app.lib_hover = idx
				return
			}
		}
	}
}

// library_scroll handles the wheel over the card grid (delta in rows).
fn library_scroll(mut app GuiApp, mx int, my int, delta int, w int, h int) bool {
	l := lib_layout(mut app, w, h)
	if !onb_hit(mx, my, l.fx, l.grid_y, l.fw, l.grid_h) {
		return false
	}
	total := lib_items(mut app).len
	if l.cols == 0 {
		return true
	}
	total_rows := (total + l.cols - 1) / l.cols
	step := if delta > 0 {
		1
	} else if delta < 0 { -1 } else { 0 }
	lib_set_scroll_row(mut app, clamp_scroll(lib_scroll_row(app) + step, total_rows, l.rows))
	return true
}

// library_key handles panel-local keys for Library panels. Documented panel
// shortcuts (digits, p/i/o) fall through — see is_panel_nav_key.
fn library_key(mut app GuiApp, e &gg.Event) bool {
	if e.key_code == .backspace {
		if app.skills_query.len > 0 {
			app.skills_query = utf8_truncate(app.skills_query, app.skills_query.runes().len - 1)
		}
		lib_set_scroll_row(mut app, 0)
		return true
	}
	if e.key_code == .escape {
		app.skills_query = ''
		app.skills_domain = ''
		app.lib_filter = ''
		return true
	}
	if e.key_code == .up {
		lib_set_scroll_row(mut app, lib_scroll_row(app) - 1)
		return true
	}
	if e.key_code == .down {
		lib_set_scroll_row(mut app, lib_scroll_row(app) + 1)
		return true
	}
	if e.key_code == .left || e.key_code == .right {
		cur := lib_selected(app)
		next := if e.key_code == .left { cur - 1 } else { cur + 1 }
		if next >= 0 {
			items := lib_items(mut app)
			if next < items.len {
				lib_select(mut app, next, items)
			}
		}
		return true
	}
	if e.key_code == .enter {
		lib_primary(mut app)
		return true
	}
	// the shared search field owns printable text while a Library panel is
	// active — including spaces, so multi-word queries ("code review") work;
	// documented nav keys (digits, p/i/o) still fall through
	if e.char_code >= 32 && e.char_code < 127 && !is_panel_nav_key(e.char_code) {
		app.skills_query += rune(e.char_code).str()
		lib_set_scroll_row(mut app, 0)
		return true
	}
	return false
}
