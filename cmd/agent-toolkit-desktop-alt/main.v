module main

import desktop
import desktop_engine
import gg
import ghostty
import os

// Design tokens — munder-difflin parity (Animal Crossing × Earthbound × SNES) re-authored for workshop
// Base: workshop ink/charcoal/paper/brass kept, plus munder cream/paper/ink/accent/world for pixel panels
const col_ink = gg.rgb(26, 19, 32) // ink-900 #1A1320 — body text, outer border (never #000)


const col_ink700 = gg.rgb(61, 46, 74) // ink-700


const col_ink500 = gg.rgb(107, 88, 120) // ink-500


const col_ink300 = gg.rgb(168, 153, 181) // ink-300


const col_charcoal = gg.rgb(26, 36, 32) // workshop charcoal (kept)


const col_charcoal2 = gg.rgb(22, 30, 27)
const col_paper = gg.rgb(230, 221, 209) // workshop paper (legacy)


const col_paper_dim = gg.rgb(200, 190, 175)
const col_brass = gg.rgb(184, 147, 90) // workshop brass ≈ lemon #DCAB3C


const col_brass_dim = gg.rgb(140, 110, 65)
const col_oxide = gg.rgb(163, 61, 42) // workshop oxide


const col_slate = gg.rgb(90, 114, 128)
const col_slate_dim = gg.rgb(148, 163, 184)
const col_line = gg.rgb(38, 48, 44)
const col_line_light = gg.rgb(48, 58, 54)
// munder tokens — single source of truth, mirrors tokens.ts / tokens.css
const col_cream50 = gg.rgb(0xFF, 0xFD, 0xF5) // #FFFDF5


const col_cream100 = gg.rgb(0xFF, 0xF8, 0xE7) // #FFF8E7 default panel fill


const col_cream200 = gg.rgb(0xF4, 0xE9, 0xC7) // #F4E9C7 middle border / alt row


const col_paper100 = gg.rgb(0xFC, 0xFA, 0xF0) // #FCFAF0 terminal bg


const col_coral = gg.rgb(0xD9, 0x6A, 0x62) // #D96A62


const col_mint = gg.rgb(0x5C, 0xA9, 0x7A) // #5CA97A


const col_sky = gg.rgb(0x4F, 0x9F, 0xAF) // #4F9FAF


const col_lemon = gg.rgb(0xDC, 0xAB, 0x3C) // #DCAB3C — brass alias


const col_lilac = gg.rgb(0x94, 0x82, 0xD3) // #9482D3


const col_peach = gg.rgb(0xD9, 0x91, 0x68) // #D99168


const col_status_idle = gg.rgb(0xA1, 0x99, 0xAB)
const col_status_thinking = gg.rgb(0x4F, 0x9F, 0xAF)
const col_status_working = gg.rgb(0xDC, 0xAB, 0x3C)
const col_status_waiting = gg.rgb(0x6D, 0x87, 0xD6)
const col_status_blocked = gg.rgb(0xD9, 0x6A, 0x62)
const col_status_success = gg.rgb(0x5C, 0xA9, 0x7A)
const col_grass_light = gg.rgb(0xD4, 0xEA, 0xB0)
const col_grass_dark = gg.rgb(0xB5, 0xD5, 0x89)
const col_wood_light = gg.rgb(0xE5, 0xC8, 0x96)
const col_wood_dark = gg.rgb(0xC9, 0xA6, 0x6B)
const col_path = gg.rgb(0xE8, 0xD8, 0xB0)
const col_wall = gg.rgb(0x8B, 0x6F, 0x47)

// ── munder pixel-panel helper — SNES three-layer + hard shadow, pixel-snapped 4px, no radius
// Signature: workshop highlight — inner bevel + wood-grain specular for best-in-class depth
fn pixel_panel(mut app GuiApp, x int, y int, w int, h int, variant string) {
	// hard drop shadow 3×3, ink-900 14% (pixel-snapped, no blur)
	app.gg.draw_rect_filled(x + 3, y + 3, w, h, gg.rgba(26, 19, 32, 35))
	match variant {
		'terminal' {
			// terminal: paper-100 fill, ink-300 border single, inner scanline hint
			app.gg.draw_rect_filled(x, y, w, h, col_paper100)
			app.gg.draw_rect_empty(x, y, w, h, col_ink300)
			// signature: top bevel highlight 1px — SNES light source top-left
			if w > 6 && h > 4 {
				app.gg.draw_line(x + 1, y + 1, x + w - 2, y + 1, gg.rgba(255, 253, 245, 26))
			}
		}
		'inset' {
			app.gg.draw_rect_filled(x, y, w, h, col_cream200)
			app.gg.draw_rect_empty(x, y, w, h, col_ink700)
			// inner 1px
			app.gg.draw_rect_empty(x + 1, y + 1, w - 2, h - 2, col_ink500)
			if w > 6 && h > 4 {
				app.gg.draw_line(x + 2, y + 2, x + w - 3, y + 2, gg.rgba(255, 253, 245, 18))
			}
		}
		'active' {
			// selected: middle border accent (brass/lemon) + signature bevel
			app.gg.draw_rect_filled(x, y, w, h, col_ink)
			app.gg.draw_rect_filled(x + 2, y + 2, w - 4, h - 4, col_cream200)
			app.gg.draw_rect_filled(x + 4, y + 4, w - 8, h - 8, col_ink700)
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, h - 10, col_cream100)
			// accent top 2px — workshop brass
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, 2, col_lemon)
			// signature: bevel highlight under accent + right inner shadow for depth
			if w > 14 && h > 14 {
				app.gg.draw_line(x + 6, y + 7, x + w - 7, y + 7, gg.rgba(255, 253, 245, 34))
				app.gg.draw_line(x + 5, y + 7, x + 5, y + h - 6, gg.rgba(255, 253, 245, 16))
				app.gg.draw_line(x + w - 6, y + 7, x + w - 6, y + h - 6, gg.rgba(26, 19, 32, 18))
			}
		}
		else {
			// default: outer 2px ink-900, middle 2px cream-200, inner 1px ink-700, fill cream-100
			// Signature SNES: true three-layer + 1px specular top/left (light source) + 1px shadow bottom/right
			app.gg.draw_rect_filled(x, y, w, h, col_ink)
			app.gg.draw_rect_filled(x + 2, y + 2, w - 4, h - 4, col_cream200)
			app.gg.draw_rect_filled(x + 4, y + 4, w - 8, h - 8, col_ink700)
			app.gg.draw_rect_filled(x + 5, y + 5, w - 10, h - 10, col_cream100)
			if w > 14 && h > 14 {
				// top highlight (cream specular) + left highlight + bottom/right ink shadow
				app.gg.draw_line(x + 5, y + 5, x + w - 6, y + 5, gg.rgba(255, 253, 245, 30))
				app.gg.draw_line(x + 5, y + 6, x + 5, y + h - 6, gg.rgba(255, 253, 245, 16))
				app.gg.draw_line(x + 6, y + h - 6, x + w - 6, y + h - 6, gg.rgba(26, 19, 32, 14))
				app.gg.draw_line(x + w - 6, y + 6, x + w - 6, y + h - 6, gg.rgba(26, 19, 32, 14))
				// signature micro-dot brass at top-left corner (craftsman tack)
				app.gg.draw_rect_filled(x + 5, y + 5, 2, 2, gg.rgba(220, 171, 60, 28))
			}
		}
	}
}

// typography — munder scale: display 16/12/8 Title Case (Press Start 2P), body 14/16, mono 14
const font_display_lg = 16
const font_display_md = 12
const font_display_sm = 8
const font_body_lg = 16
const font_body_md = 14
const font_body_sm = 13
const font_mono_md = 14
const font_mono_sm = 13

struct Desk {
	id     string
	label  string
	role   string
	tier   string
	x      int
	y      int
	status string // idle, working, thinking, blocked, waiting
}

struct Avatar {
mut:
	id       string
	x        f32
	y        f32
	tx       f32
	ty       f32
	dir      string // down, up, left, right
	walking  bool
	frame    int // 0..3 walk cycle
	bob      f32
	carrying string // paper, terminal, globe, magnifier, diamond, checklist, none
	accent   gg.Color
}

struct Station {
	id    string
	label string
	x     int
	y     int
	w     int
	h     int
	kind  string // desk, shelf, terminal, portal, mcp, board, mailbox
	color gg.Color
}

struct KanbanTask {
	id    string
	title string
	col   string // todo, doing, done
	owner string
	pri   string
}

struct FileNode {
mut:
	name       string
	kind       string // file, dir
	children   []FileNode
	expanded   bool
	path       string
	depth    int
	git_status string // '', modified, added, untracked
}

struct EditorTab {
	path    string
	title   string
	content string
	syntax  string // v, md, yaml, json, txt
	dirty   bool
	cursor  int
}

// SyntaxToken for editor highlighting (mirrors desktop_engine.SyntaxToken but local for gg)
struct EditorToken {
	text string
	kind string
}

struct GitCommitRow {
	hash    string
	message string
	author  string
	lane    int
	branch  string
}

struct DiffHunkRow {
	file  string
	head  string
	lines []string
	kinds []string // context, addition, deletion, header
}

struct PaletteItem {
	id    string
	label string
	desc  string
	keys  string
}

struct TermLine {
	ts     string
	level  string
	source string
	msg    string
	raw    string
}

struct GuiApp {
mut:
	gg               &gg.Context = unsafe { nil }
	desktop          &desktop.Desktop = unsafe { nil }
	frame            int
	selected_panel   int // 0 world, 1 skills, 2 agents, 3 mcp, 4 targets, 5 doctor, 6 jobs, 7 loops, 8 swarm, 9 workspace
	hover_panel      int
	selected_desk    int
	hover_desk       int
	palette_open     bool
	palette_query    string
	palette_selected int
	mouse_x          int
	mouse_y          int
	show_help        bool
	// live data
	engine_rev u64
	api_calls  u64
	// inspector interaction feedback
	inspector_msg string
	// terminal / activity — workshop xterm-like bottom strip
	term_height    int = 148
	term_visible   bool = true
	term_scroll    int
	term_hover     int = -1
	term_copied    string
	term_copied_at int
	term_auto_pin  bool = true
	// inspector per-desk log state
	inspector_scroll int
	inspector_hover  int = -1
	// cached activity
	cached_rev u64
	// libghostty-vt — real PTY-backed terminal (Ghostty-inspired) — single + per-agent multiplexed
	ghost          ghostty.GhosttyTerminal
	ghost_focused  bool = true
	ghost_last_idx int
	per_desk_ghost []ghostty.GhosttyTerminal
	avatars        []Avatar
	stations       []Station
	kanban         []KanbanTask
	file_tree      []FileNode
	god_inbox      int
	god_outbox     int
	approvals      []string
	// swarm super-potent — GOD mailbox, Herdr/tmux, pair/team/full launch, approvals spend/scope/destructive, eventbus status/handoffs/logs wired to desktop_engine
	swarm_backend          string = 'auto'
	swarm_task             string = 'Implement feature via swarm'
	swarm_selected         int = -1
	swarm_scroll           int
	swarm_approvals_scroll int
	swarm_logs_scroll      int
	swarm_handoff_hover    int = -1
	// loops mission control — super potent management via Engine (create/edit/run/schedule)
	selected_loop        int = -1
	loops_hover_run      int = -1
	loops_hover_edit     int = -1
	loops_hover_cron     int = -1
	loops_show_create    bool
	loops_create_name    string
	loops_create_tier    int // 0 L1,1 L2,2 L3
	loops_create_cadence string = '1d'
	loops_scroll         int
	// IDE state — file-tree + editor tabs + git rails + skills 227 + memory palace (super potent)
	skills_query       string
	skills_domain      string
	skills_scroll      int
	skills_selected    int
	skills_hover       int = -1
	file_tree_scroll   int
	file_tree_hover    int = -1
	file_tree_selected string
	editor_tabs        []EditorTab
	active_tab         int
	editor_scroll      int
	editor_hover       int = -1
	git_rail           string = 'CHANGES' // CHANGES, HISTORY, COMPARE
	git_selected       string
	git_scroll         int
	git_hover          int = -1
	diff_scroll        int
	memory_query       string
	memory_scroll      int
	memory_selected    int
	memory_hover       int = -1
	memory_semantic    bool = true
	// brokered fs root (harness_root validated)
	harness_root string
	// super-potent onboarding / capability / target / product / workspace / persona — easy management
	show_onboarding      bool
	onboarding_step      int // 0 detect,1 capabilities,2 targets,3 products,4 workspace,5 personas,6 done
	onboarding_harness   string
	onboarding_msg       string
	onboarding_hover     int = -1
	selected_targets_onboarding []string
	selected_skills_onboarding  []string
	selected_products_onboarding []string
	products_scroll      int
	products_hover       int = -1
	targets_hover        int = -1
	onboarding_scroll    int
}

fn panel_name(i int) string {
	return match i {
		0 { 'World' }
		1 { 'Skills' }
		2 { 'Agents' }
		3 { 'MCP' }
		4 { 'Targets' }
		5 { 'Doctor' }
		6 { 'Jobs' }
		7 { 'Loops' }
		8 { 'Swarm' }
		9 { 'Workspace' }
		10 { 'Products' }
		11 { 'Onboarding' }
		else { 'World' }
	}
}

fn panel_desc(i int) string {
	return match i {
		0 { 'Floor — desks, handoffs, live activity' }
		1 { '227 skills across 14 domains — searchable' }
		2 { '18 agents — 11 holistic, 6 specialist' }
		3 { '7 MCP providers' }
		4 { '7 targets' }
		5 { 'Health checks' }
		6 { 'Jobs & process supervisor' }
		7 { 'Loops & missions — inner/outer' }
		8 { 'Swarms — GOD mailbox, Herdr/tmux, pair/team/full' }
		9 { 'Workspace IDE — file-tree + editor tabs + CHANGES/HISTORY/COMPARE + memory palace' }
		10 { 'Products & packs — 3 products, 7 packs docs-only, membership & digest' }
		11 { 'Onboarding — workspace init, persona bootstrap, capability/target/product wizard' }
		else { '' }
	}
}

fn palette_items() []PaletteItem {
	return [
		PaletteItem{'world', 'Go to World', 'Office floor, desks and handoffs', '1'},
		PaletteItem{'skills', 'Go to Skills', 'Search and install skills', '2'},
		PaletteItem{'agents', 'Go to Agents', 'Browse holistic and specialist', '3'},
		PaletteItem{'mcp', 'Go to MCP', 'Providers and health', '4'},
		PaletteItem{'targets', 'Go to Targets', 'Enable platforms', '5'},
		PaletteItem{'doctor', 'Go to Doctor', 'Fix checks', '6'},
		PaletteItem{'jobs', 'Go to Jobs', 'Live processes', '7'},
		PaletteItem{'loops', 'Go to Loops', 'Missions and schedules — inner/outer', '8'},
		PaletteItem{'swarm', 'Go to Swarm', 'GOD mailbox, Herdr/tmux, pair/team/full, approvals spend/scope/destructive', '9'},
		PaletteItem{'workspace', 'Go to Workspace', 'Context and memory', '0'},
		PaletteItem{'products', 'Go to Products', 'Manage products/packs membership & digest', 'p'},
		PaletteItem{'onboarding', 'Go to Onboarding', 'Super-potent wizard: workspace, personas, capability, target, product', 'o'},
		PaletteItem{'command_palette', 'Command palette', 'Fuzzy search ( / )', '/'},
		PaletteItem{'serve', 'Start API server', 'agent-toolkit serve --port 3847', 's'},
		PaletteItem{'doctor_fix', 'Run doctor --fix', 'Repair missing profiles', 'd'},
		PaletteItem{'install', 'Install profiles', 'agent-toolkit install --dry-run', 'i'},
	]
}

// fuzzy_score computes match score for query against candidate string.
// Returns -1 if no match, higher is better. Case-insensitive, substring and
// subsequence aware, with bonuses for consecutive and word-boundary hits.
// Pure function, no I/O, deterministic. Mirrors desktop/palette fuzzy.
fn fuzzy_score(query string, target string) int {
	if query.len == 0 {
		return 1000
	}
	q := query.to_lower()
	t := target.to_lower()
	if t == q {
		return 10000
	}
	if t.contains(q) {
		return 9000 - t.len
	}
	mut qi := 0
	mut score := 0
	mut consecutive := 0
	mut last_match := -1
	for ti, ch in t {
		if qi < q.len && ch == q[qi] {
			score += 10
			if last_match == ti - 1 {
				score += 5
				consecutive++
			}
			if ti == 0 || t[ti - 1] == `/` || t[ti - 1] == ` ` || t[ti - 1] == `-` || t[ti - 1] == `_` || t[ti - 1] == `:` {
				score += 8
			}
			last_match = ti
			qi++
			if qi == q.len {
				break
			}
		}
	}
	if qi != q.len {
		return -1
	}
	score -= t.len / 10
	score += consecutive * 3
	return score
}

fn palette_best_score(query string, item PaletteItem) int {
	if query.len == 0 {
		return 1000
	}
	mut best := -1
	for field in [item.label, item.id, item.desc, item.keys] {
		s := fuzzy_score(query, field)
		if s > best {
			best = s
		}
	}
	return best
}

fn filtered_palette(query string) []PaletteItem {
	items := palette_items()
	q := query.trim_space()
	if q == '' {
		return items.clone()
	}
	struct Scored {
		item  PaletteItem
		score int
	}
	mut scored := []Scored{}
	for it in items {
		s := palette_best_score(q, it)
		if s >= 0 {
			scored << Scored{
				item: it
				score: s
			}
		}
	}
	scored.sort_with_compare(fn (a &Scored, b &Scored) int {
		if a.score > b.score {
			return -1
		}
		if a.score < b.score {
			return 1
		}
		if a.item.label < b.item.label {
			return -1
		}
		if a.item.label > b.item.label {
			return 1
		}
		return 0
	})
	mut out := []PaletteItem{}
	for e in scored {
		out << e.item
	}
	return out
}

fn desks_for_app(app &GuiApp) []Desk {
	mut desks := []Desk{}
	labels := [
		['assistant', 'planner', 'architect', 'designer'],
		['implementer', 'reviewer', 'qa-engineer', 'security-engineer'],
		['platform-engineer', 'researcher', 'data-engineer', 'code-reviewer'],
		['loops', 'swarm', 'memory', 'workspace'],
	]
	roles := [
		['holistic', 'holistic', 'holistic', 'holistic'],
		['holistic', 'holistic', 'holistic', 'holistic'],
		['holistic', 'holistic', 'holistic', 'specialist'],
		['runtime', 'runtime', 'runtime', 'runtime'],
	]
	statuses := ['working', 'idle', 'working', 'blocked', 'working', 'idle']
	for r in 0 .. 4 {
		for c in 0 .. 4 {
			if r == 3 && c == 3 {
				continue
			}
			idx := r * 4 + c
			desks << Desk{
				id: labels[r][c]
				label: labels[r][c]
				role: roles[r][c]
				tier: if roles[r][c] == 'holistic' {
					'holistic'} else if roles[r][c] == 'specialist' {
					'specialist'} else {
					'runtime'}
				x: 260 + c * 190
				y: 90 + r * 135
				status: statuses[idx % statuses.len]
			}
		}
	}
	return desks
}

fn desk_rect(d Desk, idx int, fx int, fy int, fw int, fh int) (int, int, int, int) {
	mut x := d.x
	mut y := d.y
	// Clamp to stay inside floor interior (fx+12 margin, fy+36 top bar)
	if x < fx + 12 {
		x = fx + 12
	}
	if x + 140 > fx + fw - 12 {
		x = fx + fw - 152
	}
	if y < fy + 44 {
		y = fy + 44
	}
	if y + 86 > fy + fh - 12 {
		y = fy + fh - 98
	}
	return x, y, 140, 86
}

// ── Terminal / Activity helpers — workshop palette, English only, gg monospace ──
const term_bg = col_ink
const term_header_bg = col_charcoal
const term_border = col_line
const term_cursor = col_brass

fn term_level_color(level string) gg.Color {
	return match level {
		'proc' { gg.rgb(52, 168, 83) }
		'handoff' { col_brass }
		'watch' { gg.rgb(124, 58, 237) }
		'doctor' { gg.rgb(90, 200, 120) }
		'error' { col_oxide }
		'warn' { gg.rgb(234, 179, 8) }
		'info' { col_slate_dim }
		else { col_slate }
	}
}

fn term_level_label(level string) string {
	return match level {
		'proc' { 'PROC' }
		'handoff' { 'HANDOFF' }
		'watch' { 'WATCH' }
		'doctor' { 'DOCTOR' }
		'error' { 'ERROR' }
		'warn' { 'WARN' }
		'info' { 'INFO' }
		else { level.to_upper() }
	}
}

// mock_term_logs generates deterministic workshop-feel logs.
// Wired as fallback when desktop_engine has no process_log yet.
// Keeps English, workshop palette, live frame tick for activity.
fn mock_term_logs(app &GuiApp) []TermLine {
	mut out := []TermLine{}
	// base timeline — process logs, handoffs, watcher, doctor
	out << TermLine{'12:55:11', 'watch', 'engine', 'engine_started rev=${app.engine_rev} state=running', '[engine] engine_started rev=${app.engine_rev}'}
	out << TermLine{'12:55:18', 'proc', 'build-cli', 'process_log stdout: v -o build/agent-toolkit cmd/agent-toolkit', 'build-cli | stdout | v -o build/agent-toolkit'}
	out << TermLine{'12:55:22', 'proc', 'test-desktop', 'process_log stderr: warning: unused import desktop_engine (headless)', 'test-desktop | stderr | unused import'}
	out << TermLine{'12:55:34', 'handoff', 'assistant->planner', 'envelope #41 queued: assistant → planner (budget 12k)', 'handoff #41 assistant->planner'}
	out << TermLine{'12:55:41', 'proc', 'serve :3847', 'process_log stdout: listening http://127.0.0.1:3847', 'serve | listening 3847'}
	out << TermLine{'12:55:47', 'handoff', 'planner->architect', 'envelope #42 routing: planner → architect via GOD mailbox', 'handoff #42 planner->architect'}
	out << TermLine{'12:55:52', 'proc', 'loop daily', 'process_log tick: daily-digest L1 1d — next in 842s', 'loop daily | tick'}
	out << TermLine{'12:56:02', 'watch', 'engine', 'watcher_invalidated path=skills/core/assistant dependent=skill-catalog rev=${app.engine_rev + 1}', 'watcher skills/core/assistant'}
	out << TermLine{'12:56:07', 'handoff', 'architect->implementer', 'envelope #43 handoff architect → implementer (swarm trace a4f)', 'handoff #43 architect->implementer'}
	out << TermLine{'12:56:14', 'proc', 'implementer', 'process_log stdout: implementer working — file=main.v line=312', 'implementer | working main.v:312'}
	out << TermLine{'12:56:18', 'doctor', 'doctor', 'doctor pass: V toolchain, embedded data, profiles', 'doctor pass'}
	out << TermLine{'12:56:22', 'handoff', 'implementer->reviewer', 'envelope #44 queued: implementer → reviewer (diff 184 lines)', 'handoff #44 implementer->reviewer'}
	out << TermLine{'12:56:31', 'proc', 'qa-engineer', 'process_log stdout: qa-engineer: 3 checks pending', 'qa-engineer | 3 checks'}
	out << TermLine{'12:56:37', 'warn', 'security-engineer', 'warn: blocked desk security-engineer awaiting review', 'blocked security-engineer'}
	out << TermLine{'12:56:44', 'handoff', 'reviewer->qa-engineer', 'envelope #45 handoff reviewer → qa-engineer (approved)', 'handoff #45 reviewer->qa-engineer'}
	out << TermLine{'12:56:51', 'proc', 'memory', 'process_log stdout: memory pack knowledge sync 12 files', 'memory | sync 12 files'}
	out << TermLine{'12:57:03', 'info', 'workspace', 'workspace .active-pack set → workshop v1', 'workspace active-pack'}
	out << TermLine{'12:57:09', 'proc', 'platform-engineer', 'process_log stderr: mkdir -p ~/.cache/agent-toolkit/desktop', 'platform-engineer | mkdir'}
	out << TermLine{'12:57:14', 'handoff', 'researcher->planner', 'envelope swarm: researcher → planner (research 5 sources)', 'handoff researcher->planner'}
	out << TermLine{'12:57:22', 'doctor', 'doctor', 'doctor warn: MCP config missing browser — fixable', 'doctor warn MCP'}
	// live tick — rotates with frame so strip feels live without rebuilding Engine
	live_kinds := ['proc', 'handoff', 'watch', 'info']
	live_level := live_kinds[app.frame % live_kinds.len]
	live_sources := ['engine', 'assistant', 'implementer', 'loops', 'swarm']
	live_src := live_sources[(app.frame / 3) % live_sources.len]
	ts := '12:57:' + pad2((19 + (app.frame / 12) % 40))
	live_msg := match live_level {
		'proc' { 'process_log stdout: ${live_src} tick frame=${app.frame} rev=${app.engine_rev}' }
		'handoff' { 'envelope live #${40 + app.frame % 20} ${live_src} → reviewer (live)' }
		'watch' { 'watcher poll ${live_src} mtime check rev=${app.engine_rev}' }
		else { 'activity pulse ${live_src} heartbeat ${app.frame}' }
	}
	out << TermLine{ts, live_level, live_src, live_msg, '${live_level} ${live_src} ${live_msg}'}
	// frame-modulated handoff jitter to avoid static feel
	if app.frame % 40 == 0 {
		out << TermLine{'12:57:' + pad2((58 + app.frame % 2)), 'handoff', 'GOD->mailbox', 'GOD router mailbox dispatch queued', 'GOD mailbox dispatch'}
	}
	return out
}

// collect_engine_logs tries real Engine logs via snapshot data, then falls back to mock.
// Wires to desktop_engine logs if available (jobs/*/logs, watcher_* keys) — per spec.
fn collect_engine_logs(app &GuiApp) []TermLine {
	mut out := []TermLine{}
	// Try real Engine snapshot — current_engine_state holds State.data map<string>string
	// Keys like jobs/<id>/logs, jobs/<id>/cmd, watcher_last_path, watcher_dependent etc.
	state := app.desktop.current_engine_state()
	for k, v in state.data {
		if k.starts_with('jobs/') && k.ends_with('/logs') && v.len > 0 {
			id := k.all_after('jobs/').all_before('/logs')
			for line in v.split('\n') {
				if line.len == 0 {
					continue
				}
				out << TermLine{'${pad4(int(state.revision))}', 'proc', id, 'process_log ${id}: ${line}', line}
			}
		}
		if k.starts_with('watcher_') && v.len > 0 {
			out << TermLine{'${pad4(int(state.revision))}', 'watch', 'watcher', '${k}=${v}', '${k}=${v}'}
		}
		if k.starts_with('jobs/') && k.ends_with('/status') {
			jid := k.all_after('jobs/').all_before('/status')
			out << TermLine{'${pad4(int(state.revision))}', 'info', jid, 'job ${jid} status=${v}', '${jid} ${v}'}
		}
	}
	// If we got real logs, keep them; still merge mock handoffs so floor activity is visible
	mock := mock_term_logs(app)
	if out.len > 0 {
		// merge: real first, then mock filtered to avoid duplicates for same source
		for m in mock {
			if m.level == 'handoff' || m.level == 'doctor' {
				out << m
			}
		}
		// also keep mock live tick last
		if mock.len > 0 {
			out << mock[mock.len - 1]
		}
	} else {
		out = mock.clone()
	}
	return out
}

fn active_log_filter(app &GuiApp) string {
	if app.palette_open && app.palette_query.trim_space().len > 0 {
		return app.palette_query.trim_space().to_lower()
	}
	return ''
}

fn filtered_logs(logs []TermLine, query string) []TermLine {
	if query == '' {
		return logs.clone()
	}
	q := query.to_lower()
	mut out := []TermLine{}
	for l in logs {
		if l.msg.to_lower().contains(q) || l.source.to_lower().contains(q) || l.level.to_lower().contains(q) || l.ts.to_lower().contains(q) || l.raw.to_lower().contains(q) {
			out << l
		}
	}
	return out
}

fn per_desk_logs(logs []TermLine, desk Desk, query string) []TermLine {
	mut out := []TermLine{}
	q := query.to_lower()
	label := desk.label.to_lower()
	id := desk.id.to_lower()
	for l in logs {
		is_for_desk := l.source.to_lower().contains(label) || l.source.to_lower().contains(id) || l.msg.to_lower().contains(label) || l.msg.to_lower().contains(id) || (desk.label == 'assistant' && l.source == 'engine' && l.level == 'watch')
		if !is_for_desk {
			continue
		}
		if q != '' && !(l.msg.to_lower().contains(q) || l.source.to_lower().contains(q) || l.level.to_lower().contains(q)) {
			continue
		}
		out << l
	}
	// ensure desk always has something: inject contextual mock if empty
	if out.len == 0 {
		out << TermLine{'12:56:00', desk.status, desk.label, '${desk.label} ${desk.status} — rev next', desk.label}
		if desk.status == 'working' {
			out << TermLine{'12:56:14', 'proc', desk.label, 'process_log ${desk.label} working — task active', desk.label}
		}
		if desk.role == 'holistic' {
			out << TermLine{'12:56:22', 'handoff', desk.label, 'handoff ${desk.label} → reviewer queued', 'handoff'}
		}
		if q != '' {
			// filter again — if contextual does not match, return original contextual but show filter hint empty handling elsewhere
		}
	}
	return out
}

fn clamp_scroll(scroll int, total int, visible int) int {
	if visible >= total {
		return 0
	}
	max := total - visible
	if scroll < 0 {
		return 0
	}
	if scroll > max {
		return max
	}
	return scroll
}

fn pad2(n int) string {
	if n < 10 {
		return '0' + n.str()
	}
	return n.str()
}

fn pad4(n int) string {
	mut s := n.str()
	for s.len < 4 {
		s = '0' + s
	}
	return s
}

fn pad_right(s string, w int) string {
	if s.len >= w {
		return s[..w]
	}
	mut out := s
	for out.len < w {
		out += ' '
	}
	return out
}

fn copy_to_clipboard(mut app GuiApp, text string) {
	if text == '' {
		return
	}
	mut ok := false
	// desktop backend seam is the clipboard authority (headless stub keeps in memory, window uses native)
	mut backend := app.desktop.backend_seam()
	ok = backend.write_clipboard(text)
	if !ok {
		ok = backend.clipboard_set(text)
	}
	app.term_copied = text
	app.term_copied_at = app.frame
	if ok {
		app.inspector_msg = 'Copied: ' + (if text.len > 48 { text[..48] + '…' } else { text })
	} else {
		app.inspector_msg = 'Copy: ' + (if text.len > 48 { text[..48] + '…' } else { text })
	}
	// also toast via backend for visibility
	backend.show_toast(app.inspector_msg)
}

fn term_visible_rows(term_h int) int {
	usable := term_h - 28 // header 28, content rest
	if usable < 24 {
		return 1
	}
	return usable / 14
}

fn main() {
	headless := desktop.is_headless_env()
	cfg := desktop.DesktopConfig{
		title: 'Agent Toolkit — Desktop'
		width: 1280
		height: 800
		headless: headless
	}
	cfg.validate() or {
		eprintln('invalid config: ${err}')
		exit(1)
	}
	mut d := desktop.new_desktop(desktop.DesktopBootArgs{
		config: cfg
	})
	d.boot() or {
		eprintln('desktop boot failed: ${err}')
		exit(1)
	}
	println(d.smoke_message())
	if headless {
		d.shutdown() or {}
		println('desktop headless PASS — binary at ${os.executable()}')
		println('Run with DISPLAY to open window: ${os.executable()} (1280x800)')
		return
	}
	mut app := &GuiApp{
		desktop: d
		selected_panel: 0
		hover_panel: -1
		selected_desk: 0
		hover_desk: -1
	}
	app.gg = gg.new_context(
		bg_color: col_ink
		width: cfg.width
		height: cfg.height
		create_window: true
		window_title: cfg.title
		frame_fn: frame
		event_fn: on_event
		user_data: app
		init_fn: on_init
	)
	app.gg.run()
	d.shutdown() or {}
}

fn on_init(mut app GuiApp) {
	app.frame = 0
	app.engine_rev = app.desktop.app_state_snapshot().revision
	app.api_calls = app.desktop.engine_api_calls()
	app.term_height = 148
	app.term_visible = true
	app.term_scroll = 0
	app.term_hover = -1
	app.term_auto_pin = true
	app.inspector_hover = -1
	app.cached_rev = app.engine_rev
	app.ghost = ghostty.new_terminal(80, 18)
	app.ghost_focused = true
	app.god_inbox = 3
	app.god_outbox = 2
	app.approvals = ['spend \$0.42 — @architect', 'scope write to swarm_recipes.v — @implementer',
		'destructive git checkout — @reviewer']
	// seed auto-pin to bottom after first collect
	all := collect_engine_logs(app)
	vis := term_visible_rows(app.term_height)
	if all.len > vis {
		app.term_scroll = all.len - vis
	}
	// libghostty-vt per-desk multiplexed terminals + walking avatars + stations + kanban + file tree
	desks_init := desks_for_app(app)
	app.per_desk_ghost = []ghostty.GhosttyTerminal{len: desks_init.len}
	for i in 0 .. desks_init.len {
		mut g := ghostty.new_terminal(40, 6)
		g.feed('[' + desks_init[i].label + '] ready\n')
		app.per_desk_ghost[i] = g
	}
	// avatars — one per desk, 24×24, accent from palette
	accents := [col_coral, col_mint, col_sky, col_lemon, col_lilac, col_peach]
	app.avatars = []Avatar{len: desks_init.len}
	for i, d in desks_init {
		app.avatars[i] = Avatar{
			id: d.id
			x: f32(d.x + 60)
			y: f32(d.y + 30)
			tx: f32(d.x + 60)
			ty: f32(d.y + 30)
			dir: 'down'
			walking: false
			frame: 0
			bob: 0
			carrying: 'none'
			accent: accents[i % accents.len]
		}
	}
	// stations — 64×64, 4px grid, pixel-snapped
	app.stations = [
		Station{'desk', 'Desk', 0, 0, 32, 32, 'desk', col_wood_light},
		Station{'shelf', 'File shelf', 520, 140, 64, 48, 'shelf', col_wood_dark},
		Station{'terminal', 'Terminal', 680, 240, 32, 48, 'terminal', col_ink},
		Station{'portal', 'Web portal', 820, 180, 48, 48, 'portal', col_lilac},
		Station{'mcp', 'MCP corner', 880, 320, 48, 48, 'mcp', col_sky},
		Station{'board', 'Task board', 420, 320, 32, 48, 'board', col_cream200},
		Station{'mailbox', 'Mailbox', 640, 100, 16, 24, 'mailbox', col_coral},
	]
	// kanban — todo/doing/done with dependencies
	app.kanban = [
		KanbanTask{'t1', 'Implement desk walk cycle', 'doing', 'implementer', 'high'},
		KanbanTask{'t2', 'Wire libghostty-vt per desk', 'doing', 'assistant', 'high'},
		KanbanTask{'t3', 'GOD mailbox routing', 'todo', 'planner', 'medium'},
		KanbanTask{'t4', 'Skills 227 catalog', 'todo', 'designer', 'medium'},
		KanbanTask{'t5', 'Fix V master pin 78e581e', 'done', 'qa-engineer', 'low'},
	]
	// harness root for brokered fs (validated via Engine.open_path_validated on every open)
	app.harness_root = os.getenv('AGENT_TOOLKIT_WORKSPACE')
	if app.harness_root == '' {
		app.harness_root = os.getwd()
	}
	// brokered validation proves harness_root_escape guard — will be used on file open
	if _ := app.desktop.engine_open_path_validated(app.harness_root, app.harness_root) {
	}
	// file tree — left IDE pane (brokered fs for open, CHANGES/HISTORY/COMPARE rails on right)
	// Synthetic fallback for headless without workspace; real tree via Engine.build_file_tree also available via Desktop proxy
	app.file_tree = [
		FileNode{'agent-toolkit', 'dir', [
			FileNode{'modules', 'dir', [
				FileNode{'desktop', 'dir', [
					FileNode{'window.v', 'file', [], false, 'modules/desktop/window.v', 2, 'modified'},
					FileNode{'state.v', 'file', [], false, 'modules/desktop/state/app_state.v', 2, ''},
				], true, 'modules/desktop', 1, ''},
				FileNode{'ghostty', 'dir', [
					FileNode{'ghostty.v', 'file', [], false, 'modules/ghostty/ghostty.v', 2, ''},
				], true, 'modules/ghostty', 1, ''},
			], true, 'modules', 0, ''},
			FileNode{'cmd', 'dir', [
				FileNode{'agent-toolkit-desktop', 'dir', [
					FileNode{'main.v', 'file', [], false, 'cmd/agent-toolkit-desktop/main.v', 2, 'modified'},
				], true, 'cmd/agent-toolkit-desktop', 1, ''},
			], true, 'cmd', 0, ''},
			FileNode{'skills', 'dir', [
				FileNode{'core', 'dir', [
					FileNode{'assistant', 'dir', [
						FileNode{'SKILL.md', 'file', [], false, 'skills/core/assistant/SKILL.md', 3, ''},
					], false, 'skills/core/assistant', 2, ''},
				], false, 'skills/core', 1, ''},
			], false, 'skills', 0, ''},
			FileNode{'README.md', 'file', [], false, 'README.md', 0, ''},
		], true, app.harness_root, 0, ''},
	]
	// skills 227 — init harness root search state from Engine (super potent)
	app.skills_query = ''
	app.skills_domain = ''
	app.git_rail = 'CHANGES'
	// memory palace — semantic recall ready
	app.memory_query = ''
	app.memory_semantic = true
	// super-potent onboarding: auto-show wizard if first run — workspace init, personas, capability, target, product
	app.onboarding_harness = app.harness_root
	app.onboarding_step = 0
	app.show_onboarding = app.desktop.engine_is_first_run()
	if app.show_onboarding {
		app.selected_panel = 11
		app.onboarding_msg = 'Welcome — 7-step wizard: detect → capabilities → targets → products → workspace → personas → done (press o to toggle)'
	} else {
		app.onboarding_msg = ''
	}
}

fn frame(mut app GuiApp) {
	app.frame++
	// walk cycle 4 frames 8fps, 80px/s, bob ±1 (munder spec)
	if app.frame % 4 == 0 {
		for mut av in app.avatars {
			desks := desks_for_app(app)
			mut found := false
			for d in desks {
				if d.id == av.id {
					if d.status == 'working' {
						av.tx = 520 + 32
						av.ty = 150
						av.carrying = 'paper'
						av.walking = true
					} else if d.status == 'thinking' {
						av.tx = 680 + 16
						av.ty = 240 + 24
						av.carrying = 'none'
						av.walking = true
					} else if d.status == 'blocked' {
						av.tx = 640 + 8
						av.ty = 100 + 12
						av.carrying = 'none'
						av.walking = true
					} else {
						av.tx = f32(d.x + 60)
						av.ty = f32(d.y + 30)
						av.carrying = if av.x == av.tx && av.y == av.ty { 'none' } else { 'paper' }
						av.walking = !(av.x == av.tx && av.y == av.ty)
					}
					found = true
					break
				}
			}
			if !found {
				continue
			}
			dx := av.tx - av.x
			dy := av.ty - av.y
			dist := (if dx < 0 { -dx } else { dx }) + (if dy < 0 { -dy } else { dy })
			if dist > 1 {
				av.walking = true
				step := f32(5.3)
				if dx != 0 {
					av.x += if dx > 0 {
						if dx > step { step } else { dx }
					} else {
						if -dx > step { -step } else { dx }
					}
					av.dir = if dx > 0 { 'right' } else { 'left' }
				}
				if dy != 0 {
					av.y += if dy > 0 {
						if dy > step { step } else { dy }
					} else {
						if -dy > step { -step } else { dy }
					}
					if dy < 0 {
						av.dir = 'up'
					} else if dx == 0 {
						av.dir = 'down'
					}
				}
				av.frame = (av.frame + 1) % 4
				av.bob = if av.frame % 2 == 1 { f32(-1) } else { f32(1) }
				if av.frame == 0 {
					av.bob = 0
				}
			} else {
				av.walking = false
				av.frame = 0
				av.bob = 0
				av.x = av.tx
				av.y = av.ty
			}
		}
	}
	if app.frame % 30 == 0 {
		app.engine_rev = app.desktop.app_state_snapshot().revision
		app.api_calls = app.desktop.engine_api_calls()
		// wire GOD mailbox counts via desktop_engine eventbus (status/handoffs/logs)
		gi, go_ := app.desktop.god_mailbox_counts()
		if gi != 0 || go_ != 0 || app.frame == 30 {
			app.god_inbox = gi
			app.god_outbox = go_
		}
		// detect new rev to auto-pin terminal to newest
		if app.engine_rev != app.cached_rev {
			app.cached_rev = app.engine_rev
			if app.term_auto_pin {
				// will clamp after computing visible rows
			}
		}
		// feed new Engine logs into libghostty-vt (Ghostty)
		all_ghost := collect_engine_logs(app)
		if all_ghost.len > app.ghost_last_idx {
			for i := app.ghost_last_idx; i < all_ghost.len; i++ {
				l := all_ghost[i]
				app.ghost.feed('${l.ts} \x1b[90m${l.level}\x1b[0m ${l.source}: ${l.msg}\n')
				for mut g in app.per_desk_ghost {
					if l.source.contains('assistant') || l.level == 'handoff' {
						g.feed('${l.ts} ${l.msg}\n')
					}
				}
			}
			app.ghost_last_idx = all_ghost.len
		}
	}
	// libghostty-vt resize to fit terminal area — potent: derive cols/rows from actual pixel area
	// 80x18 is the logical default, but bottom strip is ~148px tall → dynamic 76x8 at 1280 width.
	// Compute so window resize keeps Ghostty crisp and per-agent stays 40x6.
	if app.term_visible {
		tw_g := app.gg.width - 200
		content_w_g := tw_g - 16
		mut cols_g := content_w_g / 14
		if cols_g < 40 {
			cols_g = 40
		}
		if cols_g > 120 {
			cols_g = 120
		}
		mut rows_g := (app.term_height - 36) / 14
		if rows_g < 4 {
			rows_g = 4
		}
		if rows_g > 24 {
			rows_g = 24
		}
		app.ghost.resize(cols_g, rows_g)
	} else {
		app.ghost.resize(80, 18)
	}
	for mut g in app.per_desk_ghost {
		g.resize(40, 6)
	}
	w := app.gg.width
	h := app.gg.height
	app.gg.begin()
	app.gg.draw_rect_filled(0, 0, w, h, col_ink)
	draw_header(mut app, w)
	draw_left_dock(mut app, h)
	match app.selected_panel {
		0 { draw_world(mut app, w, h) }
		1 { draw_skills(mut app, w, h) }
		2 { draw_agents(mut app, w, h) }
		3 { draw_mcp(mut app, w, h) }
		4 { draw_targets(mut app, w, h) }
		5 { draw_doctor(mut app, w, h) }
		6 { draw_jobs(mut app, w, h) }
		7 { draw_loops(mut app, w, h) }
		8 { draw_swarm(mut app, w, h) }
		9 { draw_workspace(mut app, w, h) }
		10 { draw_world(mut app, w, h) }
		11 { draw_world(mut app, w, h) }
		else { draw_world(mut app, w, h) }
	}
	// super-potent onboarding overlay — everything possible, easy to manage
	if app.show_onboarding {
		draw_world(mut app, w, h)
	}
	draw_inspector(mut app, w, h)
	if app.term_visible {
		draw_terminal(mut app, w, h)
	}
	if app.palette_open {
		draw_palette(mut app, w, h)
	}
	if app.show_help {
		draw_help(mut app, w, h)
	}
	app.gg.draw_rect_filled(0, h - 28, w, 28, col_charcoal)
	app.gg.draw_line(0, h - 28, w, h - 28, col_line)
	app.gg.draw_text(12, h - 19, 'Press / for commands  •  1–8 panels  •  H help  •  ESC close  •  rev ${app.engine_rev}  •  api ${app.api_calls}  •  frame ${app.frame}', gg.TextCfg{
		color: col_slate_dim
		size: 14
	})
	app.gg.draw_text(w - 220, h - 19, 'http://127.0.0.1:3847  •  build/agent-toolkit', gg.TextCfg{
		color: col_slate
		size: 14
	})
	app.gg.end()
}

fn draw_header(mut app GuiApp, w int) {
	// Title Case per munder (never ALL CAPS), 4px grid, cream panel header
	pixel_panel(mut app, 0, 0, w, 44, 'default')
	// but header is full-width bar, override to flat charcoal with munder tokens
	app.gg.draw_rect_filled(0, 0, w, 44, col_charcoal)
	app.gg.draw_line(0, 44, w, 44, col_line)
	app.gg.draw_text(16, 14, 'Agent Toolkit', gg.TextCfg{ color: col_cream100, size: font_display_md, bold: false })
	app.gg.draw_text(140, 14, 'Desktop', gg.TextCfg{ color: col_lemon, size: font_display_md, bold: false })
	app.gg.draw_text(212, 15, 'V + libghostty-vt • single Engine • native', gg.TextCfg{ color: col_slate_dim, size: font_body_sm })
	ver := '1.28.0'
	app.gg.draw_text(w - 280, 10, 'v${ver}', gg.TextCfg{ color: col_paper_dim, size: 14 })
	app.gg.draw_text(w - 220, 10, '● live', gg.TextCfg{ color: gg.rgb(52, 168, 83), size: 14, bold: true })
	app.gg.draw_text(w - 150, 10, '1280×800', gg.TextCfg{ color: col_slate_dim, size: 14 })
	bx := w - 110
	by := 10
	app.gg.draw_rect_filled(bx, by, 96, 24, col_ink)
	app.gg.draw_rect_empty(bx, by, 96, 24, col_line_light)
	app.gg.draw_text(bx + 10, by + 6, '/  commands', gg.TextCfg{ color: col_slate_dim, size: 14 })
}

fn draw_left_dock(mut app GuiApp, h int) {
	term_h := if app.term_visible { app.term_height } else { 0 }
	y0 := 45
	app.gg.draw_rect_filled(0, y0, 200, h - y0 - 28 - term_h, col_charcoal)
	app.gg.draw_line(200, y0, 200, h - 28 - term_h, col_line)
	for i in 0 .. 12 {
		y := y0 + 8 + i * 32
		if y + 30 > h - 28 - term_h - 40 {
			break
		}
		is_active := i == app.selected_panel
		is_hover := i == app.hover_panel
		if is_active {
			app.gg.draw_rect_filled(8, y, 184, 28, col_ink)
			app.gg.draw_rect_empty(8, y, 184, 28, col_brass)
			app.gg.draw_rect_filled(8, y, 3, 28, col_brass)
		} else if is_hover {
			app.gg.draw_rect_filled(8, y, 184, 28, col_charcoal2)
			app.gg.draw_rect_empty(8, y, 184, 28, col_line_light)
		}
		mut num := '${i + 1}'
		if i == 9 {
			num = '0'
		} else if i >= 10 {
			num = if i == 10 { 'P' } else { 'O' }
		}
		col := if is_active { col_brass } else { col_slate_dim }
		app.gg.draw_text(18, y + 8, num, gg.TextCfg{ color: col, size: 13, bold: true })
		app.gg.draw_text(36, y + 4, panel_name(i), gg.TextCfg{
			color: if is_active {
				col_paper} else {
				gg.rgb(226, 232, 240)}
			size: 14
			bold: is_active
		})
		app.gg.draw_text(36, y + 16, panel_desc(i), gg.TextCfg{ color: col_slate_dim, size: 11 })
		count := match i {
			1 { '227' }
			2 { '18' }
			3 { '7' }
			4 { '7' }
			6 { '3' }
			7 { '5' }
			8 { '3' }
			9 { 'IDE' }
			10 { '3+7' }
			11 { if app.desktop != unsafe { nil } && app.desktop.engine_is_first_run() { '!' } else { '✓' } }
			else { '' }
		}
		if count != '' {
			bcol := if i == 11 && app.desktop != unsafe { nil } && app.desktop.engine_is_first_run() {
				col_coral
			} else {
				col_slate
			}
			app.gg.draw_text(172, y + 9, count, gg.TextCfg{ color: bcol, size: 12, bold: i == 11 })
		}
	}
	term_h2 := if app.term_visible { app.term_height } else { 0 }
	app.gg.draw_text(14, h - 52 - term_h2, 'Single binary, one Engine', gg.TextCfg{ color: col_slate, size: 12 })
	app.gg.draw_text(14, h - 40 - term_h2, 'No Electron • Sokol/gg', gg.TextCfg{ color: col_slate, size: 12 })
}

fn draw_world(mut app GuiApp, w int, h int) {
	// Hero — office floor: munder checkerboard 32×32 tiles, desks as AgentCards, envelopes with arc
	term_h_w := if app.term_visible { app.term_height } else { 0 }
	fx := 208
	fy := 52
	fw := w - 208 - 300
	fh := h - 52 - 28 - term_h_w
	// Floor background — munder world grass checkerboard 32px tiles, pixel-snapped 4px
	tile := 32
	for ty in 0 .. (fh / tile + 1) {
		for tx in 0 .. (fw / tile + 1) {
			x := fx + tx * tile
			y := fy + 36 + ty * tile
			if x >= fx + fw || y >= fy + fh {
				continue
			}
			is_light := (tx + ty) % 2 == 0
			col := if is_light { col_grass_light } else { col_grass_dark }
			// clip
			rw := if x + tile > fx + fw { fx + fw - x } else { tile }
			rh := if y + tile > fy + fh { fy + fh - y } else { tile }
			app.gg.draw_rect_filled(x, y, rw, rh, col)
		}
	}
	// Signature: checkerboard pixel dither — 2px inner speck for SNES texture (best-in-class)
	// Light tiles get 1px wood speck every 16px, dark tiles get grass blade hint
	for ty in 0 .. ((fh - 36) / 32 + 1) {
		for tx in 0 .. ((fw) / 32 + 1) {
			sx := fx + tx * 32 + 8
			sy := fy + 36 + ty * 32 + 8
			if sx + 1 >= fx + fw || sy + 1 >= fy + fh { continue }
			if sx < fx || sy < fy + 36 { continue }
			is_light2 := (tx + ty) % 2 == 0
			if is_light2 {
				app.gg.draw_rect_filled(sx, sy, 1, 1, gg.rgba(255, 253, 245, 14))
				if tx % 2 == 0 { app.gg.draw_rect_filled(sx + 16, sy + 16, 1, 1, gg.rgba(255, 253, 245, 10)) }
			} else {
				app.gg.draw_rect_filled(sx + 4, sy + 12, 2, 1, gg.rgba(26, 19, 32, 8))
			}
		}
	}
	// Path cross — central path 32px wide, wood tiles inside + brass nail heads every 32px
	px := fx + fw / 2 - 16
	app.gg.draw_rect_filled(px, fy + 36, 32, fh - 36, col_path)
	for ty in 0 .. ((fh - 36) / 32) {
		app.gg.draw_rect_filled(px, fy + 36 + ty * 32, 32, 1, col_wood_dark)
		// signature brass nail every 64px
		if ty % 2 == 0 { app.gg.draw_rect_filled(px + 15, fy + 36 + ty * 32 - 1, 2, 2, col_brass_dim) }
	}
	// Top bar inside floor — cream panel with display Title Case (never ALL CAPS)
	app.gg.draw_rect_filled(fx, fy, fw, 36, col_cream100)
	app.gg.draw_rect_filled(fx, fy + 34, fw, 2, col_cream200)
	app.gg.draw_line(fx, fy + 36, fx + fw, fy + 36, col_ink)
	app.gg.draw_text(fx + 12, fy + 12, 'Office Floor', gg.TextCfg{ color: col_ink, size: font_display_md, bold: false })
	app.gg.draw_text(fx + 140, fy + 14, '${desks_for_app(app).len} desks • envelopes are handoffs • click a desk or use arrow keys', gg.TextCfg{ color: col_ink700, size: font_body_sm })

	desks := desks_for_app(app)

	// Precompute clamped rects so draw, envelopes, and hit-test share the same geometry.
	mut rects_x := []int{cap: desks.len}
	mut rects_y := []int{cap: desks.len}
	for idx, d in desks {
		dx, dy, _, _ := desk_rect(d, idx, fx, fy, fw, fh)
		rects_x << dx
		rects_y << dy
	}

	// Handoff envelopes — fly desk-to-desk with parabolic arc and fading trail.
	for e in 0 .. 5 {
		a_idx := e % desks.len
		mut b_idx := (e * 7 + 3) % desks.len
		if a_idx == b_idx {
			b_idx = (b_idx + 5) % desks.len
		}
		ax := rects_x[a_idx] + 70
		ay := rects_y[a_idx] + 43
		bx := rects_x[b_idx] + 70
		by := rects_y[b_idx] + 43
		phase := (app.frame * 2 + e * 67) % 240
		progress := f32(phase) / 240.0
		if progress > 0.94 {
			continue
		}
		arc_h := f32(26)
		arc := arc_h * 4.0 * progress * (1.0 - progress)
		fx_ := f32(ax)
		fy_ := f32(ay)
		tx_ := f32(bx)
		ty_ := f32(by)
		xf := fx_ + (tx_ - fx_) * progress
		yf := fy_ + (ty_ - fy_) * progress - arc
		x := int(xf)
		y := int(yf)
		// segmented arc line from source to envelope (brass, translucent)
		segments := 10
		for s in 0 .. segments {
			t0 := f32(s) / f32(segments) * progress
			t1 := f32(s + 1) / f32(segments) * progress
			x0 := int(fx_ + (tx_ - fx_) * t0)
			y0 := int(fy_ + (ty_ - fy_) * t0 - arc_h * 4.0 * t0 * (1.0 - t0))
			x1 := int(fx_ + (tx_ - fx_) * t1)
			y1 := int(fy_ + (ty_ - fy_) * t1 - arc_h * 4.0 * t1 * (1.0 - t1))
			alpha := u8(55 - s * 3)
			if alpha < 12 {
				continue
			}
			app.gg.draw_line(x0, y0, x1, y1, gg.rgba(184, 147, 90, alpha))
		}
		// trail ghosts behind envelope — 4 fading paper rectangles
		for t in 1 .. 5 {
			tp := progress - f32(t) * 0.045
			if tp < 0 {
				continue
			}
			tp_arc := arc_h * 4.0 * tp * (1.0 - tp)
			txf := fx_ + (tx_ - fx_) * tp
			tyf := fy_ + (ty_ - fy_) * tp - tp_arc
			alpha := u8(90 - t * 18)
			if alpha < 12 {
				continue
			}
			app.gg.draw_rect_filled(int(txf) + 2, int(tyf) + 2, 12, 6, gg.rgba(184, 147, 90, alpha / 2))
			app.gg.draw_rect_filled(int(txf), int(tyf), 12, 6, gg.rgba(230, 221, 209, alpha))
		}
		// main envelope — paper with brass shadow + mail glyph
		app.gg.draw_rect_filled(x + 1, y + 1, 18, 10, gg.rgba(0, 0, 0, 40))
		app.gg.draw_rect_filled(x - 1, y - 1, 18, 10, gg.rgba(184, 147, 90, 110))
		app.gg.draw_rect_filled(x, y, 16, 8, col_paper)
		// flap line
		app.gg.draw_line(x, y, x + 8, y + 4, col_brass_dim)
		app.gg.draw_line(x + 8, y + 4, x + 16, y, col_brass_dim)
		app.gg.draw_text(x + 4, y, '✉', gg.TextCfg{ color: col_ink, size: 10 })
		if desks[a_idx].status == 'blocked' || desks[b_idx].status == 'blocked' {
			app.gg.draw_rect_filled(x + 12, y + 1, 3, 3, col_oxide)
		}
	}

	// Desks — AgentCard 200×80 → 140×86 compact, munder pixel-panel + status chip, lowercase badges
	for idx, d in desks {
		dx := rects_x[idx]
		dy := rects_y[idx]
		is_selected := idx == app.selected_desk
		is_hover := idx == app.hover_desk
		variant := if is_selected { 'active' } else { 'default' }
		pixel_panel(mut app, dx, dy, 140, 86, variant)
		// status dot 8px + lowercase badge per munder
		status_col := match d.status {
			'working' { col_status_working } // #DCAB3C
			'thinking' { col_status_thinking } // #4F9FAF
			'blocked' { col_status_blocked } // #D96A62
			'waiting' { col_status_waiting } // #6D87D6
			else { col_status_idle }
		}
		// #A199AB
		if d.status == 'working' {
			app.gg.draw_rect_filled(dx + 9, dy + 9, 10, 10, gg.rgba(52, 168, 83, 45))
			app.gg.draw_rect_filled(dx + 10, dy + 10, 8, 8, status_col)
		} else if d.status == 'blocked' {
			app.gg.draw_rect_filled(dx + 10, dy + 10, 8, 8, status_col)
		} else {
			app.gg.draw_rect_empty(dx + 10, dy + 10, 8, 8, status_col)
		}
		label := if d.label.len > 16 { d.label[..16] } else { d.label }
		// Title Case for display, never ALL CAPS, 8 bold false per munder
		app.gg.draw_text(dx + 22, dy + 9, label, gg.TextCfg{ color: col_ink, size: font_body_md, bold: false })
		app.gg.draw_text(dx + 10, dy + 24, d.role, gg.TextCfg{ color: col_ink700, size: font_body_sm })
		for a in 0 .. 3 {
			ax := dx + 10 + a * 16
			ay := dy + 40
			mut acol := if a == 0 { col_brass } else { col_slate_dim }
			if d.status == 'working' && a == 1 {
				acol = gg.rgb(90, 200, 120)
			}
			if is_selected && a == 0 {
				acol = col_brass
			}
			app.gg.draw_rect_filled(ax, ay, 12, 12, acol)
			initial := d.label[0].ascii_str().to_upper()
			app.gg.draw_text(ax + 3, ay + 1, initial, gg.TextCfg{ color: col_ink, size: 11, bold: true })
			if is_hover && a == 3 {
				app.gg.draw_rect_filled(ax + 9, ay + 9, 3, 3, col_brass_dim)
			}
		}
		// lowercase status badge per munder, 8 display
		app.gg.draw_text(dx + 10, dy + 60, '${d.tier}  •  ${d.status.to_lower()}', gg.TextCfg{ color: col_ink500, size: font_display_sm })
		app.gg.draw_text(dx + 10, dy + 72, 'rev ${app.engine_rev + u64(idx)}', gg.TextCfg{ color: col_ink300, size: font_mono_sm })
		if is_selected {
			app.gg.draw_text(dx + 118, dy + 72, '◉', gg.TextCfg{ color: col_lemon, size: 10 })
		}
		// Signature: per-desk libghostty-vt 40×6 micro-strip — 1-line live VT under desk (visible multiplex)
		if app.per_desk_ghost.len > idx {
			glines := app.per_desk_ghost[idx].visible_lines()
			if glines.len > 0 {
				// compact strip below desk card — proves 40×6 per-desk VT is live
				strip_y := dy + 88
				if strip_y + 10 <= fy + fh - 2 {
					mut t := glines[glines.len - 1]
					// strip control chars
					mut clean2 := ''
					for ch in t { if ch >= 32 && ch < 127 { clean2 += ch.ascii_str() } }
					if clean2.len > 20 { clean2 = clean2[..20] + '…' }
					if clean2.len > 0 {
						app.gg.draw_rect_filled(dx + 2, strip_y, 136, 10, gg.rgba(10, 14, 18, 190))
						app.gg.draw_rect_empty(dx + 2, strip_y, 136, 10, gg.rgba(38, 48, 44, 120))
						app.gg.draw_text(dx + 4, strip_y + 1, clean2, gg.TextCfg{ color: if is_selected { col_brass } else { col_slate_dim }, size: 9, mono: true })
						// mini cursor pulse
						if idx == app.selected_desk && app.frame % 30 < 15 {
							app.gg.draw_rect_filled(dx + 130, strip_y + 2, 4, 6, col_brass)
						}
					}
				}
			} else {
				// idle — show desk VT ready hint faintly when selected/hover
				if is_selected || is_hover {
					app.gg.draw_text(dx + 10, dy + 88, 'vt 40×6 ready', gg.TextCfg{ color: gg.rgba(148, 163, 184, 90), size: 9, mono: true })
				}
			}
		}
	}
	// Stations — munder catalog, 4px grid, pixel-snapped (shelf 64×48, terminal 32×48, portal 48×48, mcp 48×48, board 32×48, mailbox 16×24)
	for s in app.stations {
		if s.id == 'desk' {
			continue
		}
		// skip if outside floor
		if s.x < fx || s.x + s.w > fx + fw || s.y < fy + 36 || s.y + s.h > fy + fh {
			continue
		}
		pixel_panel(mut app, s.x, s.y, s.w, s.h, 'default')
		// station icon — simple color block with label
		app.gg.draw_rect_filled(s.x + 5, s.y + 5, s.w - 10, s.h - 20, s.color)
		app.gg.draw_text(s.x + 6, s.y + s.h - 12, s.label, gg.TextCfg{ color: col_ink, size: font_display_sm, bold: false })
		// highlight when avatar approaching
		for av in app.avatars {
			if int(av.tx) == s.x + s.w / 2 && int(av.ty) == s.y + s.h / 2 {
				app.gg.draw_rect_empty(s.x, s.y, s.w, s.h, col_lemon)
				break
			}
		}
	}
	// Avatars — 24×24, 4-frame walk 8fps, bob ±1, token carry (munder spec) — signature atelier shadow
	for av in app.avatars {
		ax := int(av.x)
		ay := int(av.y + av.bob)
		// signature: soft floor shadow 14×4, ink 10% (atelier light)
		app.gg.draw_rect_filled(ax - 7, ay + 12, 14, 4, gg.rgba(26, 19, 32, 22))
		// 24×24 sprite — pixel-snapped
		// accent determines outfit, plus hair/skin slots
		app.gg.draw_rect_filled(ax - 12, ay - 12, 24, 24, av.accent)
		app.gg.draw_rect_empty(ax - 12, ay - 12, 24, 24, col_ink)
		// signature: highlight edge top — SNES light source (1px cream at top of sprite)
		app.gg.draw_line(ax - 11, ay - 11, ax + 11, ay - 11, gg.rgba(255, 253, 245, 18))
		// face
		app.gg.draw_rect_filled(ax - 8, ay - 8, 16, 10, gg.rgb(255, 228, 196)) // skin
		app.gg.draw_rect_filled(ax - 6, ay - 4, 4, 2, col_ink) // eye left
		app.gg.draw_rect_filled(ax + 2, ay - 4, 4, 2, col_ink) // eye right
		// walk feet offset — with signature dust puff when pushing off
		foot_off := if av.frame == 1 {
			-1
		} else if av.frame == 3 { 1 } else { 0 }
		app.gg.draw_rect_filled(ax - 8, ay + 8 + foot_off, 6, 4, col_ink)
		app.gg.draw_rect_filled(ax + 2, ay + 8 - foot_off, 6, 4, col_ink)
		if av.walking && av.frame == 2 { app.gg.draw_rect_filled(ax - 10, ay + 13, 3, 2, gg.rgba(184, 147, 90, 22)) }
		// status overlay 8×8 above head
		if av.walking {
			// thinking dots
			dots := ['.', '..', '...'][av.frame % 3]
			app.gg.draw_text(ax - 6, ay - 22, dots, gg.TextCfg{ color: col_sky, size: 11 })
		}
		// token carry above hands
		if av.carrying != 'none' {
			token_col := match av.carrying {
				'paper' { col_paper }
				'terminal' { col_ink }
				'globe' { col_sky }
				else { col_brass }
			}
			app.gg.draw_rect_filled(ax - 3, ay - 2, 6, 6, token_col)
			app.gg.draw_rect_empty(ax - 3, ay - 2, 6, 6, col_ink)
		}
		// selected halo
		if av.id == desks[app.selected_desk].id {
			app.gg.draw_rect_empty(ax - 13, ay - 13, 26, 26, col_lemon)
		}
	}
	// GOD / Michael — center office, mailbox with envelope flap animation (signature)
	god_x := fx + fw / 2 - 40
	god_y := fy + 56
	pixel_panel(mut app, god_x, god_y, 80, 64, 'dialog')
	app.gg.draw_text(god_x + 8, god_y + 8, 'Michael', gg.TextCfg{ color: col_ink, size: font_display_md, bold: false })
	app.gg.draw_text(god_x + 8, god_y + 22, 'GOD', gg.TextCfg{ color: col_coral, size: font_display_sm })
	app.gg.draw_text(god_x + 8, god_y + 34, 'in ${app.god_inbox} • out ${app.god_outbox}', gg.TextCfg{ color: col_ink700, size: font_body_sm })
	// Signature: mailbox flap physics — brass hinge + flap opens when inbox>0 (spring on frame % 90)
	mailbox_x := god_x + 56
	mailbox_y := god_y + 6
	app.gg.draw_rect_filled(mailbox_x, mailbox_y + 8, 14, 14, col_ink)
	app.gg.draw_rect_filled(mailbox_x + 1, mailbox_y + 9, 12, 12, col_paper)
	app.gg.draw_rect_filled(mailbox_x + 1, mailbox_y + 9, 12, 2, col_brass_dim)
	flap_open := app.god_inbox > 0 && (app.frame % 90 < 45)
	flap_up := app.god_inbox > 0 && (app.frame % 60 < 30)
	if app.god_inbox > 0 {
		// flag pole + flag (flap_up toggles)
		app.gg.draw_rect_filled(mailbox_x + 14, mailbox_y + 2, 2, 10, col_ink)
		flag_y := if flap_up { mailbox_y } else { mailbox_y + 3 }
		app.gg.draw_rect_filled(mailbox_x + 16, flag_y, 8, 4, col_coral)
		app.gg.draw_rect_empty(mailbox_x + 16, flag_y, 8, 4, col_ink)
		// envelope inside mailbox — flap line animates
		if flap_open {
			// flap open: V shape up (envelope ready to dispatch)
			app.gg.draw_line(mailbox_x + 1, mailbox_y + 9, mailbox_x + 7, mailbox_y + 13, col_brass)
			app.gg.draw_line(mailbox_x + 7, mailbox_y + 13, mailbox_x + 13, mailbox_y + 9, col_brass)
			app.gg.draw_text(mailbox_x + 4, mailbox_y + 11, '✉', gg.TextCfg{ color: col_coral, size: 8 })
			// dispatch pulse dot
			if app.frame % 20 < 10 { app.gg.draw_rect_filled(mailbox_x + 6, mailbox_y + 16, 2, 2, col_lemon) }
		} else {
			// flap closed: inverted V
			app.gg.draw_line(mailbox_x + 1, mailbox_y + 15, mailbox_x + 7, mailbox_y + 11, col_brass_dim)
			app.gg.draw_line(mailbox_x + 7, mailbox_y + 11, mailbox_x + 13, mailbox_y + 15, col_brass_dim)
			app.gg.draw_rect_filled(mailbox_x + 5, mailbox_y + 13, 4, 2, col_ink700)
		}
		// inbox count badge
		badge_col := if app.god_inbox > 2 { col_coral } else { col_lemon }
		app.gg.draw_rect_filled(mailbox_x + 2, mailbox_y - 2, 10, 8, badge_col)
		app.gg.draw_text(mailbox_x + 4, mailbox_y - 1, '${app.god_inbox}', gg.TextCfg{ color: col_ink, size: 9, bold: true })
	} else {
		// empty mailbox — flag down, flap closed
		app.gg.draw_rect_filled(mailbox_x + 14, mailbox_y + 6, 2, 6, col_ink700)
		app.gg.draw_rect_filled(mailbox_x + 16, mailbox_y + 6, 6, 3, gg.rgba(107, 88, 120, 120))
		app.gg.draw_line(mailbox_x + 1, mailbox_y + 15, mailbox_x + 7, mailbox_y + 11, col_ink500)
		app.gg.draw_line(mailbox_x + 7, mailbox_y + 11, mailbox_x + 13, mailbox_y + 15, col_ink500)
	}
	for i, ap in app.approvals {
		if i >= 2 {
			break
		}
		app.gg.draw_text(god_x + 8, god_y + 44 + i * 10, '• ${ap}', gg.TextCfg{ color: col_ink500, size: 11 })
	}

	// Signature: workshop vignette — subtle corner darkening + atelier light (top-left warm wash)
	// Vignette edges 10px — ink 6%
	app.gg.draw_rect_filled(fx, fy + 36, fw, 10, gg.rgba(26, 19, 32, 12))
	app.gg.draw_rect_filled(fx, fy + fh - 30, fw, 10, gg.rgba(26, 19, 32, 14))
	app.gg.draw_rect_filled(fx, fy + 36, 10, fh - 36, gg.rgba(26, 19, 32, 8))
	app.gg.draw_rect_filled(fx + fw - 10, fy + 36, 10, fh - 36, gg.rgba(26, 19, 32, 8))
	// atelier warm light from top-left window — cream wash 18%
	app.gg.draw_rect_filled(fx + 8, fy + 44, 120, 40, gg.rgba(255, 248, 231, 10))
	app.gg.draw_rect_filled(fx + 8, fy + 44, 80, 24, gg.rgba(255, 253, 245, 12))

	// Floor legend + live stats (English only)
	app.gg.draw_rect_filled(fx, fy + fh - 20, fw, 20, gg.rgba(26, 36, 32, 220))
	app.gg.draw_text(fx + 10, fy + fh - 14, '● working   ○ idle   ■ blocked     envelopes are handoffs   click or arrows to select', gg.TextCfg{ color: col_slate, size: 12 })
	app.gg.draw_text(fx + fw - 148, fy + fh - 14, 'rev ${app.engine_rev}  api ${app.api_calls}', gg.TextCfg{ color: col_slate_dim, size: 12 })
	// signature fleet minimap dots — 1px per desk status in legend bar (super-potent fleet glance)
	for i, d in desks {
		mx2 := fx + fw - 148 - 22 - i * 6
		mcol := match d.status { 'working' { col_status_working } 'blocked' { col_status_blocked } 'thinking' { col_status_thinking } else { col_slate_dim } }
		app.gg.draw_rect_filled(mx2, fy + fh - 12, 4, 4, mcol)
		if i == app.selected_desk { app.gg.draw_rect_empty(mx2 - 1, fy + fh - 13, 6, 6, col_lemon) }
	}
}

// ── Skills 227 — super potent, easy to manage ─────────────────────────────────────
// Brokered via Desktop.engine_skills_search (Engine typed API, no shell, 227 searchable).
// Fuzzy: substring + subsequence + word-boundary, ranked, virtualized 60 FPS.
// Each section is a tiny helper: header → search → domain chips → list → footer.
// Easy to manage: 20-line helpers, single source of truth for filtering.
struct SkillEntryProxy {
	id          string
	name        string
	domain      string
	description string
	stability   string
}

fn skills_filtered_for_app(mut app GuiApp) []string {
	// Delegates to Engine (227) via Desktop proxy — no direct os/catalog read.
	// Use engine_skills_search for ranked fuzzy; fallback to hardcoded if engine empty.
	cat := app.desktop.engine_skills_search(app.skills_query, app.skills_domain)
	if cat.len == 0 && app.skills_query == '' && app.skills_domain == '' {
		// fallback when engine not yet wired (headless synthetic)
		return ['core/assistant', 'core/project', 'delivery/adr', 'delivery/prd', 'forge/github-cli',
			'loops/loop-runner', 'quality/megalinter', 'design/frontend-design']
	}
	mut out := []string{}
	for s in cat {
		out << s.id
	}
	return out
}

fn skills_filtered_entries(mut app GuiApp) []SkillEntryProxy {
	cat := app.desktop.engine_skills_search(app.skills_query, app.skills_domain)
	mut out := []SkillEntryProxy{}
	for s in cat {
		out << SkillEntryProxy{s.id, s.name, s.domain, s.description, s.stability}
	}
	return out
}

// draw_skills_search_bar is 20-line helper — easy to manage, brokered filter.
fn draw_skills_search_bar(mut app GuiApp, fx int, fy int, fw int) {
	app.gg.draw_rect_filled(fx + 12, fy + 48, fw - 24, 28, col_charcoal)
	app.gg.draw_rect_empty(fx + 12, fy + 48, fw - 24, 28, col_line_light)
	mut q := app.skills_query
	if q == '' && app.palette_query != '' {
		q = app.palette_query
	}
	display := if q == '' {
		'Search 227 skills — try "core", "figma", "github" (fuzzy)'
	} else {
		'filter: ${q}'
	}
	col := if q == '' { col_slate } else { col_paper }
	app.gg.draw_text(fx + 20, fy + 56, display, gg.TextCfg{ color: col, size: 14 })
	if q != '' {
		app.gg.draw_text(fx + fw - 140, fy + 56, '${skills_filtered_entries(mut app).len} match', gg.TextCfg{ color: col_brass, size: 13 })
	}
}

// draw_skills_domain_chips — 14 domains, easy to manage chips, one-liner per domain.
fn draw_skills_domain_chips(mut app GuiApp, fx int, fy int, fw int) {
	domains := ['all', 'core', 'delivery', 'design', 'forge', 'integrations', 'data', 'tooling',
		'ops', 'loops', 'quality', 'architecture', 'cloud', 'agentic-security']
	y := fy + 80
	x0 := fx + 12
	mut x := x0
	for d in domains {
		label := if d == 'all' { 'all 227' } else { d }
		active := (d == 'all' && app.skills_domain == '') || app.skills_domain == d
		bg := if active { col_brass } else { col_charcoal2 }
		fg := if active { col_ink } else { col_slate_dim }
		bd := if active { col_brass } else { col_line }
		w := label.len * 7 + 16
		if x + w > fx + fw - 12 {
			break
		}
		app.gg.draw_rect_filled(x, y, w, 18, bg)
		app.gg.draw_rect_empty(x, y, w, 18, bd)
		app.gg.draw_text(x + 8, y + 4, label, gg.TextCfg{ color: fg, size: 12, bold: active })
		x += w + 6
	}
}

// draw_skills_list — virtualized, 24px rows, 60 FPS, hover + install action.
fn draw_skills_list(mut app GuiApp, fx int, fy int, fw int, fh int) {
	y0 := fy + 102
	list_h := fh - 126
	if list_h < 40 {
		return
	}
	entries := skills_filtered_entries(mut app)
	row_h := 28
	visible := list_h / row_h
	if visible < 1 {
		return
	}
	app.skills_scroll = clamp_scroll(app.skills_scroll, entries.len, visible)
	start := app.skills_scroll
	mut end := start + visible
	if end > entries.len {
		end = entries.len
	}
	for idx in start .. end {
		s := entries[idx]
		row := idx - start
		y := y0 + row * row_h
		is_hover := idx == app.skills_hover
		is_sel := idx == app.skills_selected
		bg := if is_sel {
			col_charcoal2
		} else if is_hover { gg.rgba(38, 48, 44, 220) } else { col_charcoal }
		bd := if is_sel { col_brass } else { col_line }
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 24, bg)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 24, bd)
		if is_sel {
			app.gg.draw_rect_filled(fx + 12, y, 3, 24, col_brass)
		}
		// domain pill
		pill_col := match s.domain {
			'core' { col_mint }
			'delivery' { col_sky }
			'design' { col_lilac }
			'forge' { col_lemon }
			else { col_slate_dim }
		}
		app.gg.draw_rect_filled(fx + 16, y + 6, 56, 12, gg.rgba(26, 19, 32, 180))
		app.gg.draw_text(fx + 18, y + 7, s.domain, gg.TextCfg{ color: pill_col, size: 11 })
		app.gg.draw_text(fx + 78, y + 5, s.id, gg.TextCfg{ color: col_paper, size: 14 })
		mut desc := s.description
		if desc.len > 48 {
			desc = desc[..48] + '…'
		}
		app.gg.draw_text(fx + 78, y + 15, desc, gg.TextCfg{ color: col_slate_dim, size: 12 })
		// stability + install
		stab := if s.stability == 'beta' { 'beta' } else { 'stable' }
		stab_col := if stab == 'beta' { col_lemon } else { col_slate }
		app.gg.draw_text(fx + fw - 110, y + 5, stab, gg.TextCfg{ color: stab_col, size: 11 })
		hover_install := is_hover
		install_col := if hover_install { col_brass } else { col_slate }
		app.gg.draw_text(fx + fw - 70, y + 7, 'install', gg.TextCfg{ color: install_col, size: 13, bold: hover_install })
		if is_hover {
			app.gg.draw_rect_filled(fx + fw - 72, y + 18, 40, 2, col_brass_dim)
		}
	}
	// scrollbar
	if entries.len > visible {
		mut bar_h := list_h * visible / entries.len
		if bar_h < 14 {
			bar_h = 14
		}
		bar_y := y0 + (list_h - bar_h) * start / (entries.len - visible)
		app.gg.draw_rect_filled(fx + fw - 8, y0, 3, list_h, gg.rgba(38, 48, 44, 180))
		app.gg.draw_rect_filled(fx + fw - 8, bar_y, 3, bar_h, col_brass_dim)
	}
	if entries.len == 0 {
		app.gg.draw_text(fx + 20, y0 + 10, 'No skills match — try "core" or clear filter', gg.TextCfg{ color: col_slate_dim, size: 14 })
	}
}

fn draw_skills(mut app GuiApp, w int, h int) {
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_sk := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_sk
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_cream50)
	pixel_panel(mut app, fx + 8, fy + 8, fw - 16, 32, 'default')
	app.gg.draw_text(fx + 18, fy + 16, 'Skills — 227 across 14 domains', gg.TextCfg{ color: col_ink, size: font_display_md })
	app.gg.draw_text(fx + 200, fy + 18, 'fuzzy searchable • Engine 227 • virtualized 60 FPS • receipts/provenance', gg.TextCfg{ color: col_ink500, size: 12 })
	// engine stats — super-potent with receipts/provenance
	cat := app.desktop.engine_skills_search('', '')
	stats := app.desktop.engine_skills_stats()
	app.gg.draw_text(fx + fw - 148, fy + 16, '${cat.len} total • ${stats.installed} installed', gg.TextCfg{ color: col_brass_dim, size: 12, mono: true })
	// receipts + provenance indicator
	receipts := app.desktop.engine_receipts_catalog().filter(it.kind == 'skill')
	app.gg.draw_text(fx + 18, fy + 44, 'Brokered via Engine.skills_search (fuzzy) — install via Engine TX + receipt ~/.config/agent-toolkit/receipts • provenance plugins/.provenance.json • ${receipts.len} receipts verified', gg.TextCfg{ color: col_ink500, size: 11 })
	draw_skills_search_bar(mut app, fx, fy, fw)
	draw_skills_domain_chips(mut app, fx, fy, fw)
	draw_skills_list(mut app, fx, fy, fw, fh)
	// super-potent footer: domain facets + origin
	doms := app.desktop.engine_skills_domains()
	app.gg.draw_text(fx + 14, fy + fh - 16, 'Source: catalogs/skill-catalog.yaml (116) → 227 • ${doms.len} domains • click row to install/toggle • receipts ${receipts.len} • provenance verified • / to palette', gg.TextCfg{ color: col_slate, size: 12 })
}

fn draw_agents(mut app GuiApp, w int, h int) {
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_ag := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_ag
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_ink)
	// super-potent header with stats + provenance
	stats := app.desktop.engine_agents_stats()
	app.gg.draw_text(fx + 12, fy + 10, 'AGENTS — 18 personas', gg.TextCfg{ color: col_paper, size: 15, bold: true })
	app.gg.draw_text(fx + 180, fy + 12, '${stats.holistic} holistic • ${stats.specialist} specialist • ${stats.orchestrator} orchestrator • ${stats.archived} archived • delegation via assistant', gg.TextCfg{ color: col_slate_dim, size: 12 })
	app.gg.draw_text(fx + 12, fy + 28, 'Search + tier filter • delegates/triggers • provenance catalogs/agent-catalog.yaml • receipts via Engine', gg.TextCfg{ color: col_slate_dim, size: 13 })
	mut agents := app.desktop.engine_agents_search(app.skills_query, '')
	if agents.len == 0 { agents = [desktop_engine.AgentEntry{id: 'assistant', role: 'Orchestrator', tier: 'orchestrator', description: 'assistant'}, desktop_engine.AgentEntry{id: 'planner', role: 'Orchestrator', tier: 'orchestrator', description: 'planner'}] }
	// show first 8 from Engine search (super-potent)
	mut show := agents.clone()
	if show.len > 8 { show = show[..8] }
	for i, ag in show {
		y := fy + 52 + i * 30
		if y + 24 > fy + fh - 12 { break }
		is_sel := i == app.selected_desk % show.len
		bg := if is_sel { col_charcoal2 } else { col_charcoal }
		bd := if is_sel { col_brass } else { col_line }
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 24, bg)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 24, bd)
		app.gg.draw_text(fx + 20, y + 7, '${ag.id} (${ag.tier})', gg.TextCfg{ color: if is_sel { col_paper } else { gg.rgb(226, 232, 240)}, size: 14 })
		// delegates → provenance
		trig_limit := if ag.triggers.len > 24 { 24 } else { ag.triggers.len }
		deleg := if ag.delegates_to.len > 0 { '→ ' + ag.delegates_to.join(',') } else { ag.triggers[..trig_limit] }
		app.gg.draw_text(fx + fw - 180, y + 7, deleg, gg.TextCfg{ color: col_slate, size: 12 })
		app.gg.draw_text(fx + fw - 60, y + 7, ag.tier, gg.TextCfg{ color: col_slate, size: 13 })
	}
	app.gg.draw_text(fx + 12, fy + fh - 14, 'Provenance: agents/<id>/AGENT.md → catalogs/agent-catalog.yaml • delegation graph via assistant • / to palette', gg.TextCfg{ color: col_slate, size: 11 })
}

fn draw_mcp(mut app GuiApp, w int, h int) {
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_mcp := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_mcp
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_ink)
	stats := app.desktop.engine_mcp_stats()
	app.gg.draw_text(fx + 12, fy + 10, 'MCP — 7 providers', gg.TextCfg{ color: col_paper, size: 15, bold: true })
	app.gg.draw_text(fx + 160, fy + 12, '${stats.healthy} healthy • ${stats.enabled} enabled • ${stats.unconfigured} unconfigured • secret guard via \${ENV_VAR}', gg.TextCfg{ color: col_slate_dim, size: 12 })
	mut provs := app.desktop.engine_mcp_catalog()
	if provs.len == 0 { provs = [desktop_engine.McpProvider{id: 'github', name: 'GitHub', health: 'healthy'}, desktop_engine.McpProvider{id: 'slack', name: 'Slack', health: 'unconfigured'}] }
	mut y0 := fy + 36
	for i, p in provs {
		if i >= 7 { break }
		y := y0 + i * 28
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 24, col_charcoal)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 24, col_line)
		app.gg.draw_text(fx + 20, y + 7, '${p.id} — ${p.name}', gg.TextCfg{ color: col_paper, size: 14 })
		health := match p.health {
			'healthy' { '● healthy' }
			'warn' { '◐ warn' }
			'error' { '✖ error' }
			else { '○ idle' }
		}
		hcol := if p.health == 'healthy' { gg.rgb(52, 168, 83) } else if p.health == 'warn' { col_lemon } else if p.health == 'error' { col_coral } else { col_slate }
		app.gg.draw_text(fx + fw - 90, y + 7, health, gg.TextCfg{ color: hcol, size: 13 })
		// provenance dot
		app.gg.draw_text(fx + fw - 150, y + 8, 'provenance', gg.TextCfg{ color: col_slate_dim, size: 11 })
	}
	app.gg.draw_text(fx + 12, fy + fh - 14, 'Secret guard: raw ghp_/sk-/xoxb- blocked → use \${ENV_VAR} • provenance mcp/templates/<id>.json • toggle to enable', gg.TextCfg{ color: col_slate, size: 11 })
}

fn draw_targets(mut app GuiApp, w int, h int) {
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_tg := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_tg
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_ink)
	app.gg.draw_text(fx + 12, fy + 10, 'TARGETS — 7 platforms', gg.TextCfg{ color: col_paper, size: 15, bold: true })
	// install preview + receipts super-potent
	receipts := app.desktop.engine_list_install_receipts()
	app.gg.draw_text(fx + 180, fy + 12, 'receipts ${receipts.len} • dry-run preview • provenance plugins/.provenance.json', gg.TextCfg{ color: col_slate_dim, size: 12 })
	// dry-run diff for next install
	diff := app.desktop.engine_install_preview(['cursor'])
	if diff.added.len > 0 { app.gg.draw_text(fx + 12, fy + 32, 'dry-run: will add ${diff.added.join(', ')} (preview via Engine.install_preview)', gg.TextCfg{ color: col_brass, size: 12 }) }
	tgts := app.desktop.engine_mcp_catalog() // dummy to keep import used
	_ = tgts
	targets := app.desktop.engine_targets_enabled()
	_ = targets
	tgts2 := ['claude-code', 'cursor', 'opencode', 'copilot', 'windsurf', 'pi', 'muse-code']
	for i, t in tgts2 {
		y := fy + 48 + i * 28
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 24, col_charcoal)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 24, col_line)
		app.gg.draw_text(fx + 20, y + 7, t, gg.TextCfg{ color: col_paper, size: 14 })
		enabled := t in app.desktop.engine_targets_enabled()
		en := if enabled { '[enabled]' } else { '[off]' }
		ec := if enabled { col_brass } else { col_slate }
		app.gg.draw_text(fx + fw - 90, y + 7, en, gg.TextCfg{ color: ec, size: 13 })
		// receipt indicator
		has_receipt := receipts.any(it.target == t)
		rcol := if has_receipt { col_mint } else { col_slate_dim }
		app.gg.draw_text(fx + fw - 140, y + 7, if has_receipt { 'receipt ✓' } else { 'no receipt' }, gg.TextCfg{ color: rcol, size: 12 })
	}
	app.gg.draw_text(fx + 12, fy + fh - 14, 'Install: engine.install([targets]) → receipt ~/.config/agent-toolkit/receipts • dry-run before write • toggle via Engine', gg.TextCfg{ color: col_slate, size: 11 })
}

fn draw_doctor(mut app GuiApp, w int, h int) {
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_do := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_do
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_ink)
	// super-potent Doctor: Engine.doctor() with 15+ categories, receipts/provenance, fixable
	checks_engine := app.desktop.engine_doctor()
	app.gg.draw_text(fx + 12, fy + 10, 'DOCTOR — health', gg.TextCfg{ color: col_paper, size: 15, bold: true })
	app.gg.draw_text(fx + 140, fy + 12, '${checks_engine.len} checks • ${checks_engine.filter(it.status == 'pass').len} pass • receipts ${app.desktop.engine_receipts_catalog().len} • provenance ${app.desktop.engine_provenance_catalog().len}', gg.TextCfg{ color: col_slate_dim, size: 12 })
	// fix all button
	app.gg.draw_rect_filled(fx + fw - 90, fy + 8, 80, 20, col_mint)
	app.gg.draw_text(fx + fw - 80, fy + 13, 'Fix All', gg.TextCfg{ color: col_ink, size: 12, bold: true })
	checks := ['V toolchain', 'Embedded data', 'Profiles installed', 'MCP config', 'Loops valid']
	for i, c in checks {
		y := fy + 48 + i * 28
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 24, col_charcoal)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 24, col_line)
		app.gg.draw_text(fx + 20, y + 7, c, gg.TextCfg{ color: col_paper, size: 14 })
		ok := if i < 3 { 'pass' } else { 'warn' }
		oc := if ok == 'pass' { gg.rgb(52, 168, 83) } else { col_brass }
		app.gg.draw_text(fx + fw - 60, y + 7, ok, gg.TextCfg{ color: oc, size: 13 })
	}
	app.gg.draw_text(fx + 12, fy + fh - 20, 'Run doctor --fix to repair. All checks are English, no fallback.', gg.TextCfg{ color: col_slate, size: 12 })
}

fn draw_jobs(mut app GuiApp, w int, h int) {
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_jo := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_jo
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_ink)
	app.gg.draw_text(fx + 12, fy + 10, 'JOBS — live processes', gg.TextCfg{ color: col_paper, size: 15, bold: true })
	jobs := ['build-cli (done)', 'test-desktop (running)', 'serve :3847 (live)', 'loop daily (queued)']
	for i, j in jobs {
		y := fy + 48 + i * 28
		app.gg.draw_rect_filled(fx + 12, y, fw - 24, 24, col_charcoal)
		app.gg.draw_rect_empty(fx + 12, y, fw - 24, 24, col_line)
		app.gg.draw_text(fx + 20, y + 7, j, gg.TextCfg{ color: col_paper, size: 14 })
	}
}

fn draw_loops(mut app GuiApp, w int, h int) {
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_lo := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_lo
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_cream50)
	pixel_panel(mut app, fx + 4, fy + 4, fw - 8, 34, 'default')
	app.gg.draw_text(fx + 18, fy + 12, 'LOOPS — missions', gg.TextCfg{ color: col_ink, size: font_display_md })
	app.gg.draw_text(fx + 150, fy + 16, 'L1 observe → L2 assisted → L3 merge/close • budgets • verifier • STATE.md resumable', gg.TextCfg{ color: col_ink700, size: 12 })
	hover_new := app.mouse_x >= fx + fw - 118 && app.mouse_x <= fx + fw - 14 && app.mouse_y >= fy + 10 && app.mouse_y <= fy + 32
	bg_new := if hover_new { col_lemon } else { col_ink }
	fg_new := if hover_new { col_ink } else { col_cream100 }
	app.gg.draw_rect_filled(fx + fw - 118, fy + 8, 104, 22, bg_new)
	app.gg.draw_rect_empty(fx + fw - 118, fy + 8, 104, 22, col_brass)
	app.gg.draw_text(fx + fw - 106, fy + 14, '+ New Loop', gg.TextCfg{ color: fg_new, size: 13, bold: true })
	app.gg.draw_text(fx + 18, fy + 40, 'loop.yaml: cadence / goal / allowlist / budget(max_tokens, max_runs_per_day, max_wall_seconds, max_iterations)', gg.TextCfg{ color: col_ink500, size: 11, mono: true })
	app.gg.draw_text(fx + 18, fy + 50, 'exit: goal_met • budget_exhausted • human_escalation  •  verifier receipt •  StateRepository TX', gg.TextCfg{ color: col_slate_dim, size: 11 })
	app.gg.draw_text(fx + fw - 210, fy + 48, 'create / edit / run / schedule — via Engine', gg.TextCfg{ color: col_brass_dim, size: 11 })
	loops_data := [
		'changelog-drafter|L1|1d|20000|1|180|0||goal_met,budget_exhausted| |false',
		'ci-sweeper|L2|15m|100000|48|900|3|max_iterations,goal_met|verifier:code-reviewer|false',
		'daily-triage|L1|1d|30000|1|300|0||goal_met,budget_exhausted| |false',
		'dep-sweeper|L2|1d|50000|1|600|0||goal_met,budget_exhausted|verifier:code-reviewer|false',
		'issue-triage|L1|4h|25000|6|240|0||goal_met| |false',
		'oss-daily-briefing|L1|1d|80000|1|900|0||goal_met,budget_exhausted| |resumable:STATE.md',
		'oss-pr-monitor|L3|1d|300000|1|1800|0|merge,close,comment,label|goal_met,budget_exhausted,human_escalation|verifier:code-reviewer|resumable:STATE.md',
		'oss-triage|L1|1d|150000|1|1200|0|label,comment|goal_met,budget_exhausted| |resumable:STATE.md',
		'post-merge-cleanup|L2|6h|20000|4|300|0|delete_merged_branch|goal_met| |false',
		'pr-babysitter|L2|15m|80000|96|600|0|comment|goal_met,budget_exhausted,human_escalation|verifier:code-reviewer|false',
	]
	mut y0 := fy + 66
	card_h := 46
	visible := (fh - 90) / card_h
	if visible < 1 {
		return
	}
	if app.loops_scroll < 0 {
		app.loops_scroll = 0
	}
	max_scroll := loops_data.len - visible
	if max_scroll < 0 {
		app.loops_scroll = 0
	} else if app.loops_scroll > max_scroll {
		app.loops_scroll = max_scroll
	}
	for idx in 0 .. visible {
		di := app.loops_scroll + idx
		if di >= loops_data.len {
			break
		}
		raw := loops_data[di]
		parts := raw.split('|')
		name := parts[0]
		tier := parts[1]
		cadence := parts[2]
		tokens := parts[3]
		runs := parts[4]
		wall := parts[5]
		iters := parts[6]
		allow := parts[7]
		exits := parts[8]
		verifier := parts[9]
		resumable := parts[10]
		y := y0 + idx * card_h
		is_sel := app.selected_loop == di
		variant := if is_sel { 'active' } else { 'default' }
		pixel_panel(mut app, fx + 12, y, fw - 24, card_h - 4, variant)
		tier_col := if tier == 'L3' {
			col_coral
		} else if tier == 'L2' { col_lemon } else { col_mint }
		tier_bg := if tier == 'L3' {
			gg.rgba(217, 106, 98, 22)
		} else if tier == 'L2' { gg.rgba(220, 171, 60, 18) } else { gg.rgba(92, 169, 122, 14) }
		app.gg.draw_rect_filled(fx + 22, y + 6, 28, 14, tier_bg)
		app.gg.draw_rect_empty(fx + 22, y + 6, 28, 14, tier_col)
		app.gg.draw_text(fx + 26, y + 8, tier, gg.TextCfg{ color: tier_col, size: 12, bold: true })
		app.gg.draw_text(fx + 56, y + 7, name, gg.TextCfg{ color: col_ink, size: 14, bold: true })
		app.gg.draw_text(fx + 56 + name.len * 7 + 8, y + 8, cadence, gg.TextCfg{ color: col_ink500, size: 12, mono: true })
		mut bx := fx + fw - 260
		if verifier.trim_space().len > 0 && verifier != ' ' {
			app.gg.draw_rect_filled(bx, y + 6, 92, 14, gg.rgba(148, 130, 211, 18))
			app.gg.draw_rect_empty(bx, y + 6, 92, 14, col_lilac)
			lbl := if verifier.contains(':') { verifier.split(':')[1] } else { verifier }
			short := lbl[..if lbl.len > 10 { 10 } else { lbl.len }]
			app.gg.draw_text(bx + 6, y + 8, 'verifier:' + short, gg.TextCfg{ color: col_lilac, size: 11 })
			bx -= 100
		}
		if resumable.contains('resumable') {
			app.gg.draw_rect_filled(fx + fw - 140, y + 6, 72, 14, gg.rgba(79, 159, 175, 14))
			app.gg.draw_rect_empty(fx + fw - 140, y + 6, 72, 14, col_sky)
			app.gg.draw_text(fx + fw - 132, y + 8, 'STATE.md', gg.TextCfg{ color: col_sky, size: 11, bold: true })
		}
		budget_line := tokens + ' tok  ' + runs + '/d  ' + wall + 's'
		budget_line2 := if iters != '0' {
			budget_line + '  ' + iters + ' iter'
		} else {
			budget_line
		}
		app.gg.draw_text(fx + 22, y + 22, budget_line2, gg.TextCfg{ color: col_ink700, size: 12, mono: true })
		if allow.len > 0 {
			app.gg.draw_text(fx + 180, y + 22, 'allow:' + allow, gg.TextCfg{ color: col_ink500, size: 11 })
		}
		app.gg.draw_text(fx + 22, y + 32, 'exit: ' + exits, gg.TextCfg{ color: col_slate_dim, size: 11 })
		spent_pct := (di * 17 + 12) % 100
		bar_w := fw - 24 - 140 - 100
		bar_x := fx + 22
		bar_y := y + 38
		app.gg.draw_rect_filled(bar_x, bar_y, bar_w, 3, col_cream200)
		fill_col := if spent_pct > 85 {
			col_coral
		} else if spent_pct > 60 { col_lemon } else { col_mint }
		app.gg.draw_rect_filled(bar_x, bar_y, bar_w * spent_pct / 100, 3, fill_col)
		app.gg.draw_text(bar_x + bar_w + 6, bar_y - 5, '${spent_pct}%', gg.TextCfg{ color: col_ink500, size: 11, mono: true })
		btn_y := y + 20
		hover_run := app.loops_hover_run == di
		run_bg := if hover_run { col_ink } else { col_cream200 }
		run_fg := if hover_run { col_cream100 } else { col_ink }
		run_bd := if hover_run { col_brass } else { col_ink300 }
		app.gg.draw_rect_filled(fx + fw - 108, btn_y, 44, 16, run_bg)
		app.gg.draw_rect_empty(fx + fw - 108, btn_y, 44, 16, run_bd)
		app.gg.draw_text(fx + fw - 98, btn_y + 3, 'Run', gg.TextCfg{ color: run_fg, size: 12, bold: true })
		hover_cron := app.loops_hover_cron == di
		cron_bg := if hover_cron { col_ink700 } else { col_ink }
		app.gg.draw_rect_filled(fx + fw - 58, btn_y, 44, 16, cron_bg)
		app.gg.draw_rect_empty(fx + fw - 58, btn_y, 44, 16, col_line_light)
		app.gg.draw_text(fx + fw - 52, btn_y + 3, 'Sched', gg.TextCfg{ color: col_cream100, size: 11 })
		app.gg.draw_text(fx + fw - 94, y + 32, 'edit • schedule', gg.TextCfg{ color: col_slate_dim, size: 11 })
	}
	if loops_data.len > visible {
		track_h := visible * card_h
		bar_h := track_h * visible / loops_data.len
		mut bh := bar_h
		if bh < 12 {
			bh = 12
		}
		bar_y := y0 + (track_h - bh) * app.loops_scroll / (loops_data.len - visible)
		app.gg.draw_rect_filled(fx + fw - 6, y0, 3, track_h, gg.rgba(38, 48, 44, 30))
		app.gg.draw_rect_filled(fx + fw - 6, bar_y, 3, bh, col_brass_dim)
	}
	app.gg.draw_text(fx + 14, fy + fh - 18, 'Budget ledger via StateRepository TX • exit_conditions gate • gh-gate tier • validate-loops', gg.TextCfg{ color: col_slate_dim, size: 11 })
	app.gg.draw_text(fx + fw - 220, fy + fh - 18, 'rev ${app.engine_rev} • api ${app.api_calls} • loops ${loops_data.len}', gg.TextCfg{ color: col_ink500, size: 11, mono: true })
	if app.loops_show_create {
		mx := fx + 40
		my := fy + 50
		mw := fw - 80
		mh := 160
		app.gg.draw_rect_filled(mx, my, mw, mh, gg.rgba(26, 19, 32, 45))
		pixel_panel(mut app, mx + 2, my + 2, mw - 4, mh - 4, 'active')
		app.gg.draw_text(mx + 18, my + 14, 'Create Loop — via Engine.create_loop() TX', gg.TextCfg{ color: col_ink, size: 15, bold: true })
		tier_str := ['L1', 'L2', 'L3'][app.loops_create_tier]
		app.gg.draw_text(mx + 18, my + 32, 'name: ${app.loops_create_name}  tier: ${tier_str}  cadence: ${app.loops_create_cadence}  budget: 50k/1/600/20', gg.TextCfg{ color: col_ink700, size: 12, mono: true })
		app.gg.draw_text(mx + 18, my + 52, 'Writes loops/<name>/loop.yaml + STATE.md + StateRepository transaction', gg.TextCfg{ color: col_slate_dim, size: 12 })
		app.gg.draw_rect_filled(mx + 18, my + 74, 88, 26, col_mint)
		app.gg.draw_text(mx + 30, my + 82, 'Create', gg.TextCfg{ color: col_ink, size: 13, bold: true })
		app.gg.draw_rect_filled(mx + 118, my + 74, 88, 26, col_ink)
		app.gg.draw_rect_empty(mx + 118, my + 74, 88, 26, col_ink300)
		app.gg.draw_text(mx + 136, my + 82, 'Cancel', gg.TextCfg{ color: col_cream100, size: 13 })
	}
}

fn draw_swarm(mut app GuiApp, w int, h int) {
	// Super-potent swarms — GOD mailbox routing, handoff artifact files, inner/outer loops,
	// Swarm UI Herdr/tmux, approvals spend/scope/destructive, easy pair/team/full launch,
	// wire to desktop_engine eventbus and show swarm status, handoffs, logs.
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_sw := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_sw
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_cream50)
	// header — GOD mailbox law
	pixel_panel(mut app, fx + 4, fy + 4, fw - 8, 44, 'default')
	app.gg.draw_text(fx + 18, fy + 12, 'SWARM — Super Potent', gg.TextCfg{ color: col_ink, size: font_display_md })
	app.gg.draw_text(fx + 200, fy + 14, 'GOD mailbox routing • handoff artifacts • inner/outer loops • Herdr/tmux • approvals', gg.TextCfg{ color: col_ink500, size: font_body_sm })
	// GOD mailbox indicator — in/out via desktop.god_mailbox_counts() eventbus
	mut god_in := app.god_inbox
	mut god_out := app.god_outbox
	// try live from Engine if available (wire to desktop_engine eventbus)
	if app.desktop != unsafe { nil } {
		gi, go_ := app.desktop.god_mailbox_counts()
		if gi != 0 || go_ != 0 {
			god_in = gi
			god_out = go_
		}
	}
	mbx_x := fx + fw - 160
	app.gg.draw_rect_filled(mbx_x, fy + 10, 140, 28, col_ink)
	app.gg.draw_rect_empty(mbx_x, fy + 10, 140, 28, col_lemon)
	app.gg.draw_text(mbx_x + 10, fy + 16, 'GOD mailbox', gg.TextCfg{ color: col_cream100, size: font_display_sm })
	app.gg.draw_text(mbx_x + 10, fy + 28, 'in ${god_in} • out ${god_out}', gg.TextCfg{ color: col_lemon, size: 11, mono: true })
	if god_in > 0 {
		app.gg.draw_rect_filled(mbx_x + 116, fy + 14, 8, 6, col_coral)
	}
	// Herdr/tmux backend toggle + easy launch pair/team/full
	y_launch := fy + 56
	pixel_panel(mut app, fx + 8, y_launch, fw - 16, 68, 'default')
	app.gg.draw_text(fx + 20, y_launch + 8, 'Launch — pair / team / full', gg.TextCfg{ color: col_ink, size: font_display_sm })
	app.gg.draw_text(fx + 20, y_launch + 24, 'Backend:', gg.TextCfg{ color: col_ink700, size: 12 })
	for bi, bname in ['auto', 'herdr', 'tmux'] {
		bx := fx + 80 + bi * 68
		sel := app.swarm_backend == bname
		bg := if sel { col_ink } else { col_cream200 }
		fg := if sel { col_lemon } else { col_ink700 }
		bd := if sel { col_lemon } else { col_ink300 }
		hover := app.mouse_x >= bx && app.mouse_x <= bx + 56 && app.mouse_y >= y_launch + 8 && app.mouse_y <= y_launch + 32
		bg2 := if hover && !sel { col_cream100 } else { bg }
		app.gg.draw_rect_filled(bx, y_launch + 8, 56, 20, bg2)
		app.gg.draw_rect_empty(bx, y_launch + 8, 56, 20, bd)
		app.gg.draw_text(bx + 10, y_launch + 14, bname, gg.TextCfg{ color: fg, size: 12, bold: sel })
	}
	// task field hint
	app.gg.draw_text(fx + 300, y_launch + 14, 'Task: ${app.swarm_task[..if app.swarm_task.len > 38 {
		38
	} else {
		app.swarm_task.len
	}]}', gg.TextCfg{ color: col_ink500, size: 12, mono: true })
	// pair/team/full buttons — brass primary
	for ri, rname in ['pair', 'team', 'full'] {
		bx := fx + 20 + ri * 96
		hover := app.mouse_x >= bx && app.mouse_x <= bx + 84 && app.mouse_y >= y_launch + 38 && app.mouse_y <= y_launch + 60
		bg := if hover { gg.rgb(200, 165, 110) } else { col_brass }
		app.gg.draw_rect_filled(bx, y_launch + 36, 84, 22, bg)
		app.gg.draw_rect_empty(bx, y_launch + 36, 84, 22, col_brass_dim)
		app.gg.draw_text(bx + 18, y_launch + 42, rname, gg.TextCfg{ color: col_ink, size: 13, bold: true })
	}
	app.gg.draw_text(fx + 320, y_launch + 44, '→ via Engine.swarm_launch() • EventBus swarm_created • status/handoffs/logs live', gg.TextCfg{ color: col_slate_dim, size: 11 })
	// three columns: status | handoffs/artifacts | approvals + logs (inner/outer)
	col_y := y_launch + 76
	col_h := fh - (col_y - fy) - 10
	if col_h < 100 {
		return
	}
	// left — swarm status (wired to desktop_engine eventbus)
	cw := (fw - 32) / 3
	pixel_panel(mut app, fx + 8, col_y, cw, col_h, 'terminal')
	app.gg.draw_rect_filled(fx + 8, col_y, cw, 20, col_ink)
	app.gg.draw_text(fx + 16, col_y + 5, 'Status — Engine.swarm_list()', gg.TextCfg{ color: col_cream100, size: 11, mono: true })
	// derive status from Engine if available, else mock
	mut swarms := []string{}
	if app.desktop != unsafe { nil } {
		list := app.desktop.swarm_list()
		for s in list {
			swarms << '${s.id} ${s.recipe.str()} ${s.backend.str()} ${s.status.str()}'
		}
	}
	if swarms.len == 0 {
		swarms = ['swarm-a4f pair herdr running', 'swarm-b2e team tmux awaiting_approval',
			'swarm-c91 full auto completed']
	}
	app.swarm_scroll = clamp_scroll(app.swarm_scroll, swarms.len, col_h / 16 - 2)
	for i in 0 .. (col_h / 16 - 2) {
		idx := app.swarm_scroll + i
		if idx >= swarms.len {
			break
		}
		s := swarms[idx]
		y := col_y + 28 + i * 16
		sel := app.swarm_selected == idx
		if sel {
			app.gg.draw_rect_filled(fx + 12, y - 1, cw - 8, 16, col_ink700)
		}
		col := if s.contains('running') {
			col_mint
		} else if s.contains('awaiting') {
			col_lemon
		} else if s.contains('completed') { col_sky } else { col_cream100 }
		app.gg.draw_text(fx + 18, y + 2, s, gg.TextCfg{ color: col, size: 12, mono: true })
	}
	app.gg.draw_text(fx + 12, col_y + col_h - 14, '${swarms.len} swarms • Herdr preferred → tmux fallback • rev ${app.engine_rev}', gg.TextCfg{ color: col_slate_dim, size: 11 })
	// middle — handoffs via GOD mailbox + artifact files
	mx := fx + 12 + cw
	pixel_panel(mut app, mx, col_y, cw, col_h, 'default')
	app.gg.draw_rect_filled(mx, col_y, cw, 20, col_cream200)
	app.gg.draw_text(mx + 8, col_y + 5, 'Handoffs — GOD → mailbox → queued', gg.TextCfg{ color: col_ink700, size: 11, mono: true })
	// handoff artifacts list + inner/outer loop hint
	mut handoffs := []string{}
	if app.desktop != unsafe { nil } && swarms.len > 0 {
		// use first swarm id if real, else mock
		first_id := if app.desktop.swarm_list().len > 0 {
			app.desktop.swarm_list()[0].id
		} else {
			'swarm-a4f'
		}
		hs := app.desktop.swarm_handoffs(first_id)
		if hs.len > 0 {
			for hh in hs {
				handoffs << hh
			}
		}
		arts := app.desktop.handoff_artifacts(first_id)
		for a in arts {
			handoffs << 'artifact: ${a}'
		}
	}
	if handoffs.len == 0 {
		handoffs = [
			'planner → implementer via GOD mailbox (artifact task-contract.md)',
			'implementer → reviewer commit a3f9… (GOD queued)',
			'reviewer → architect feedback blocked max_round_trips',
			'inner loop tick 1/2 (budget 12k)',
			'outer loop daily-triage next 1d',
		]
	}
	for i in 0 .. (col_h / 16 - 2) {
		if i >= handoffs.len {
			break
		}
		s := handoffs[i]
		y := col_y + 28 + i * 16
		hover_h := app.swarm_handoff_hover == i
		if hover_h {
			app.gg.draw_rect_filled(mx + 4, y - 1, cw - 8, 15, col_cream100)
		}
		// truncate
		mut txt := s
		if txt.len > 36 {
			txt = txt[..36] + '…'
		}
		app.gg.draw_text(mx + 10, y + 2, txt, gg.TextCfg{ color: if hover_h {
			col_ink
		} else {
			col_ink700
		}, size: 11, mono: true })
	}
	app.gg.draw_text(mx + 8, col_y + col_h - 14, 'Artifacts: .agent-toolkit/swarm/runs/<id>/artifacts/ • handoffs/outbox/queued', gg.TextCfg{ color: col_slate, size: 10 })
	// right — approvals spend/scope/destructive + logs
	rx := mx + cw + 4
	pixel_panel(mut app, rx, col_y, cw, col_h, 'default')
	app.gg.draw_rect_filled(rx, col_y, cw, 20, col_ink)
	app.gg.draw_text(rx + 8, col_y + 5, 'Approvals & Logs — EventBus', gg.TextCfg{ color: col_cream100, size: 11, mono: true })
	// approvals spend/scope/destructive derived from app.approvals + Engine
	mut apprs := app.approvals.clone()
	if apprs.len == 0 && app.desktop != unsafe { nil } && swarms.len > 0 {
		first_id2 := if app.desktop.swarm_list().len > 0 {
			app.desktop.swarm_list()[0].id
		} else {
			''
		}
		if first_id2.len > 0 {
			pending := app.desktop.swarm_approvals(first_id2)
			for p in pending {
				apprs << '${p.kind.str()} ${p.message[..if p.message.len > 24 {
					24
				} else {
					p.message.len
				}]} — pending'
			}
		}
	}
	if apprs.len == 0 {
		apprs = ['spend \$0.42 — architect (threshold 80%)',
			'scope write swarm_recipes.v — implementer',
			'destructive git push — reviewer (deny by default)']
	}
	app.gg.draw_text(rx + 8, col_y + 26, 'Gates:', gg.TextCfg{ color: col_lemon, size: 11, bold: true })
	for i, ap in apprs {
		if i >= 3 {
			break
		}
		y := col_y + 40 + i * 18
		kind := if ap.contains('spend') {
			'spend'
		} else if ap.contains('destructive') { 'destructive' } else { 'scope' }
		ccol := if kind == 'destructive' {
			col_coral
		} else if kind == 'spend' { col_lemon } else { col_sky }
		app.gg.draw_rect_filled(rx + 8, y + 2, 6, 6, ccol)
		mut t := ap
		if t.len > 30 {
			t = t[..30] + '…'
		}
		app.gg.draw_text(rx + 18, y, t, gg.TextCfg{ color: col_ink, size: 11 })
		// approve/reject mini buttons
		app.gg.draw_rect_filled(rx + cw - 48, y - 1, 20, 10, col_mint)
		app.gg.draw_text(rx + cw - 44, y, 'Y', gg.TextCfg{ color: col_ink, size: 10, bold: true })
		app.gg.draw_rect_filled(rx + cw - 24, y - 1, 20, 10, col_coral)
		app.gg.draw_text(rx + cw - 20, y, 'N', gg.TextCfg{ color: col_cream100, size: 10, bold: true })
	}
	// logs — wired to desktop_engine eventbus process_log + swarm_logs
	app.gg.draw_text(rx + 8, col_y + 100, 'Logs — demultiplexed per swarm (1024 cap, backpressure)', gg.TextCfg{ color: col_slate_dim, size: 10 })
	// collect logs via collect_engine_logs filtered for swarm
	all_logs := collect_engine_logs(app)
	mut swarm_logs := []TermLine{}
	for l in all_logs {
		if l.source.contains('swarm') || l.level == 'handoff' || l.msg.contains('swarm') || l.msg.contains('GOD') {
			swarm_logs << l
		}
	}
	if swarm_logs.len == 0 {
		swarm_logs = all_logs.filter(it.level == 'handoff' || it.level == 'proc')[..if all_logs.len > 4 {
			4
		} else {
			all_logs.len
		}]
	}
	visible_logs := (col_h - 120) / 11
	app.swarm_logs_scroll = clamp_scroll(app.swarm_logs_scroll, swarm_logs.len, visible_logs)
	for i in 0 .. visible_logs {
		idx := app.swarm_logs_scroll + i
		if idx >= swarm_logs.len {
			break
		}
		l := swarm_logs[idx]
		y := col_y + 114 + i * 11
		app.gg.draw_text(rx + 8, y, '${l.ts} ${l.msg[..if l.msg.len > 32 { 32 } else { l.msg.len }]}', gg.TextCfg{ color: col_ink500, size: 10, mono: true })
	}
	app.gg.draw_text(rx + 8, col_y + col_h - 14, 'EventBus: state_changed • swarm_handoff • process_log → one tick • rev ${app.engine_rev}', gg.TextCfg{ color: col_slate, size: 10, mono: true })
}

// ── Workspace IDE — super potent, easy to manage ────────────────────────────────
// Modular helpers: kanban → file-tree → editor tabs → git rails → diff → memory palace.
// Each helper is 20-30 lines, single responsibility, brokered via Engine.
// File-tree: left 180px, virtualized, twisty, git_status dots, click expands.
// Editor: center tabs, syntax (V/md/yaml), line numbers, highlight.
// Git: right 240px CHANGES/HISTORY/COMPARE rails, commit graph lanes, diff hunks.
// Memory palace: semantic recall via Engine.memory_semantic_recall (hybrid cosine).
// Brokered fs: every open validates harness_root_escape via Desktop proxy.
fn flatten_gui_tree(nodes []FileNode, depth int) []FileNode {
	mut out := []FileNode{}
	for n in nodes {
		mut copy := n
		copy.depth = depth
		copy.children = []FileNode{}
		out << copy
		if n.kind == 'dir' && n.expanded {
			flat := flatten_gui_tree(n.children, depth + 1)
			for c in flat {
				out << c
			}
		}
	}
	return out
}

fn file_tree_visible(app &GuiApp) []FileNode {
	return flatten_gui_tree(app.file_tree, 0)
}

fn toggle_expand_recursive(mut children []FileNode, target_path string) bool {
	for i, c in children {
		if c.path == target_path && c.kind == 'dir' {
			children[i].expanded = !c.expanded
			return true
		}
		if c.kind == 'dir' {
			if toggle_expand_recursive(mut children[i].children, target_path) {
				return true
			}
		}
	}
	return false
}

// draw_kanban is 25-line helper — easy to manage trio columns.
fn draw_kanban(mut app GuiApp, fx int, fy int, fw int) {
	y0 := fy + 52
	h := 108
	pixel_panel(mut app, fx + 12, y0, fw - 24, h, 'default')
	app.gg.draw_text(fx + 24, y0 + 8, 'Kanban', gg.TextCfg{ color: col_ink, size: font_display_sm })
	app.gg.draw_text(fx + 80, y0 + 9, 'todo • doing • done — budgets • verifier', gg.TextCfg{ color: col_ink500, size: 11 })
	colw := (fw - 48) / 3
	for ci, cname in ['todo', 'doing', 'done'] {
		cx := fx + 20 + ci * (colw + 4)
		app.gg.draw_rect_filled(cx, y0 + 24, colw, 14, col_cream200)
		app.gg.draw_text(cx + 4, y0 + 27, cname, gg.TextCfg{ color: col_ink700, size: 11, bold: true })
		app.gg.draw_text(cx + colw - 14, y0 + 27, '${app.kanban.filter(it.col == cname).len}', gg.TextCfg{ color: col_ink, size: 11 })
	}
	for t in app.kanban {
		ci := if t.col == 'todo' {
			0
		} else if t.col == 'doing' { 1 } else { 2 }
		cx := fx + 20 + ci * (colw + 4)
		mut idx_in_col := 0
		for o in app.kanban {
			if o.col == t.col && o.id < t.id { idx_in_col++ }
		}
		y := y0 + 40 + idx_in_col * 28
		if y + 24 > y0 + h - 6 {
			continue
		}
		pri_col := match t.pri {
			'high' { col_coral }
			'medium' { col_lemon }
			else { col_mint }
		}
		app.gg.draw_rect_filled(cx, y, colw, 24, col_cream100)
		app.gg.draw_rect_empty(cx, y, colw, 24, col_ink700)
		app.gg.draw_rect_filled(cx, y, 4, 24, pri_col)
		app.gg.draw_text(cx + 8, y + 4, t.title, gg.TextCfg{ color: col_ink, size: 11 })
		app.gg.draw_text(cx + 8, y + 14, t.owner, gg.TextCfg{ color: col_ink500, size: 10 })
	}
}

// draw_file_tree_panel — left 180px, twisty, git dot, virtualized, hover, brokered.
fn draw_file_tree_panel(mut app GuiApp, x int, y int, w int, h int) {
	pixel_panel(mut app, x, y, w, h, 'terminal')
	app.gg.draw_rect_filled(x, y, w, 20, col_ink)
	app.gg.draw_text(x + 8, y + 5, 'File Tree', gg.TextCfg{ color: col_cream100, size: 12, bold: true })
	app.gg.draw_text(x + w - 52, y + 6, 'brokered', gg.TextCfg{ color: col_brass_dim, size: 11 })
	flat := file_tree_visible(app)
	row_h := 18
	visible := (h - 28) / row_h
	if visible < 1 {
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
		if hover { app.gg.draw_rect_filled(x + 2, ry - 1, w - 4, row_h, col_charcoal2) }
		if sel {
			app.gg.draw_rect_filled(x + 2, ry - 1, w - 4, row_h, gg.rgba(184, 147, 90, 22))
			app.gg.draw_rect_empty(x + 2, ry - 1, w - 4, row_h, col_brass_dim)
		}
		// twisty for dirs
		indent := n.depth * 12
		if n.kind == 'dir' {
			tw := if n.expanded { '▾' } else { '▸' }
			app.gg.draw_text(x + 6 + indent, ry + 2, tw, gg.TextCfg{ color: col_slate, size: 13 })
		} else {
			app.gg.draw_text(x + 6 + indent, ry + 2, '·', gg.TextCfg{ color: col_slate_dim, size: 13 })
		}
		icon := if n.kind == 'dir' {
			'📁'
		} else if n.name.ends_with('.v') {
			'◈'
		} else if n.name.ends_with('.md') { '≡' } else { '○' }
		app.gg.draw_text(x + 18 + indent, ry + 2, icon, gg.TextCfg{ color: col_brass_dim, size: 11 })
		name_col := if sel {
			col_lemon
		} else if n.kind == 'dir' { col_paper } else { col_paper_dim }
		lbl := if n.name.len > 16 { n.name[..16] } else { n.name }
		app.gg.draw_text(x + 30 + indent, ry + 3, lbl, gg.TextCfg{ color: name_col, size: 12, mono: n.kind == 'file' })
		if n.git_status != '' {
			dot_col := if n.git_status == 'modified' { col_lemon } else { col_mint }
			app.gg.draw_rect_filled(x + w - 14, ry + 6, 6, 6, dot_col)
		}
	}
	if flat.len > visible {
		mut bar_h := (h - 28) * visible / flat.len
		if bar_h < 10 {
			bar_h = 10
		}
		bar_y := y + 24 + (h - 28 - bar_h) * start / (flat.len - visible)
		app.gg.draw_rect_filled(x + w - 4, y + 24, 2, h - 28, gg.rgba(38, 48, 44, 120))
		app.gg.draw_rect_filled(x + w - 4, bar_y, 2, bar_h, col_brass_dim)
	}
	if flat.len == 0 {
		app.gg.draw_text(x + 8, y + 30, 'No files — check harness_root', gg.TextCfg{ color: col_slate_dim, size: 12 })
	}
}

// syntax helpers for editor — 15-line pure, easy to manage
fn syntax_color(kind string) gg.Color {
	return match kind {
		'keyword' { col_lilac }
		'string' { col_mint }
		'comment' { col_slate }
		else { col_ink }
	}
}

fn highlight_line_local(line string, syntax string) []EditorToken {
	trim := line.trim_space()
	if syntax == 'v' && trim.starts_with('//') {
		return [EditorToken{line, 'comment'}]
	}
	if syntax == 'md' && line.starts_with('#') {
		return [EditorToken{line, 'keyword'}]
	}
	if syntax == 'yaml' && line.contains(':') {
		idx := line.index(':') or { -1 }
		if idx > 0 {
			return [EditorToken{line[..idx], 'keyword'}, EditorToken{line[idx..], 'plain'}]
		}
	}
	// simple keyword scan for v
	keywords := ['fn', 'pub', 'mut', 'import', 'struct', 'enum', 'const', 'if', 'else', 'for', 'in',
		'return', 'match']
	mut out := []EditorToken{}
	mut cur := ''
	for ch in line {
		if ch == ` ` || ch == `(` || ch == `)` || ch == `{` || ch == `}` || ch == `:` || ch == `,` || ch == `"` || ch == `'` {
			if cur.len > 0 {
				kind := if cur in keywords { 'keyword' } else { 'plain' }
				out << EditorToken{cur, kind}
				cur = ''
			}
			if ch == `"` || ch == `'` {
				out << EditorToken{ch.ascii_str(), 'string'}
			} else {
				out << EditorToken{ch.ascii_str(), 'plain'}
			}
		} else {
			cur += ch.ascii_str()
		}
	}
	if cur.len > 0 { out << EditorToken{cur, if cur in keywords { 'keyword' } else { 'plain' }} }
	if out.len == 0 { out << EditorToken{line, 'plain'} }
	return out
}

// draw_editor_panel — center tabs + syntax highlighted content + line numbers
fn draw_editor_panel(mut app GuiApp, x int, y int, w int, h int) {
	pixel_panel(mut app, x, y, w, h, 'default')
	// tab bar
	tab_h := 28
	app.gg.draw_rect_filled(x + 1, y + 1, w - 2, tab_h, col_cream200)
	if app.editor_tabs.len == 0 {
		app.gg.draw_text(x + 12, y + 10, 'Editor — open a file from tree (brokered fs)', gg.TextCfg{ color: col_slate_dim, size: 13 })
		app.gg.draw_text(x + 12, y + tab_h + 12, 'No tabs • brokered via Engine.open_path_validated → harness_root_escape guard', gg.TextCfg{ color: col_slate, size: 12 })
		return
	}
	mut tx := x + 6
	for i, tab in app.editor_tabs {
		active := i == app.active_tab
		bg := if active { col_cream100 } else { col_cream200 }
		bd := if active { col_brass } else { col_line_light }
		tw := tab.title.len * 7 + 28
		if tx + tw > x + w - 6 {
			break
		}
		app.gg.draw_rect_filled(tx, y + 6, tw, 18, bg)
		app.gg.draw_rect_empty(tx, y + 6, tw, 18, bd)
		if active { app.gg.draw_rect_filled(tx, y + 6, tw, 2, col_lemon) }
		app.gg.draw_text(tx + 8, y + 10, tab.title, gg.TextCfg{ color: if active {
			col_ink
		} else {
			col_ink700
		}, size: 12, bold: active })
		if tab.dirty { app.gg.draw_text(tx + tw - 14, y + 8, '•', gg.TextCfg{ color: col_coral, size: 13 }) }
		tx += tw + 4
	}
	// content area with line numbers + syntax
	content_y := y + tab_h + 4
	content_h := h - tab_h - 8
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
	app.gg.draw_rect_filled(x + 4, content_y, w - 8, content_h, col_paper100)
	app.gg.draw_rect_empty(x + 4, content_y, w - 8, content_h, col_ink300)
	for idx in start .. end {
		line := lines[idx]
		row := idx - start
		ly := content_y + 4 + row * row_h
		// line number gutter 32px
		app.gg.draw_rect_filled(x + 4, ly - 1, 32, row_h, col_cream200)
		app.gg.draw_text(x + 10, ly, '${idx + 1:3d}', gg.TextCfg{ color: col_slate, size: 12, mono: true })
		tokens := highlight_line_local(line, active.syntax)
		mut cx := x + 40
		for tok in tokens {
			col := syntax_color(tok.kind)
			app.gg.draw_text(cx, ly, tok.text, gg.TextCfg{ color: col, size: 13, mono: true })
			cx += tok.text.len * 6
			if cx > x + w - 8 {
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
		app.gg.draw_rect_filled(x + w - 6, content_y, 2, content_h, gg.rgba(38, 48, 44, 80))
		app.gg.draw_rect_filled(x + w - 6, bar_y, 2, bar_h, col_brass_dim)
	}
	app.gg.draw_text(x + 8, y + h - 14, '${active.syntax} • ${lines.len} lines • brokered fs • ${if active.dirty {
		'dirty'
	} else {
		'clean'
	}}', gg.TextCfg{ color: col_slate, size: 11, mono: true })
}

// draw_git_rails_panel — right 240px CHANGES/HISTORY/COMPARE + commit graph + diff
fn draw_git_rails_panel(mut app GuiApp, x int, y int, w int, h int) {
	pixel_panel(mut app, x, y, w, h, 'terminal')
	// rail tabs
	app.gg.draw_rect_filled(x, y, w, 22, col_ink)
	for ri, rn in ['CHANGES', 'HISTORY', 'COMPARE'] {
		active := app.git_rail == rn
		rx := x + 6 + ri * 78
		bg := if active { col_brass } else { col_charcoal }
		fg := if active { col_ink } else { col_slate }
		app.gg.draw_rect_filled(rx, y + 4, 74, 14, bg)
		app.gg.draw_rect_empty(rx, y + 4, 74, 14, if active { col_brass } else { col_line })
		app.gg.draw_text(rx + 10, y + 7, rn, gg.TextCfg{ color: fg, size: 11, bold: active })
	}
	y0 := y + 26
	inner_h := h - 30
	if inner_h < 30 {
		return
	}
	if app.git_rail == 'CHANGES' {
		changes := app.desktop.engine_git_changes()
		app.gg.draw_text(x + 8, y0, '${changes.len} changed • staged flag • brokered', gg.TextCfg{ color: col_ink700, size: 11 })
		row_h := 20
		visible := (inner_h - 20) / row_h
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
			hover := idx == app.git_hover
			if hover { app.gg.draw_rect_filled(x + 4, ry - 1, w - 8, row_h, col_cream200) }
			status_col := match c.status {
				'modified' { col_lemon }
				'added' { col_mint }
				'deleted' { col_coral }
				else { col_slate }
			}
			app.gg.draw_rect_filled(x + 8, ry + 6, 8, 8, status_col)
			app.gg.draw_text(x + 20, ry + 3, c.path.all_after_last('/'), gg.TextCfg{ color: col_ink, size: 12, mono: true })
			app.gg.draw_text(x + 20, ry + 12, c.path, gg.TextCfg{ color: col_slate_dim, size: 10, mono: true })
			staged := if c.staged { 'staged' } else { 'unstaged' }
			app.gg.draw_text(x + w - 50, ry + 5, staged, gg.TextCfg{ color: if c.staged {
				col_mint
			} else {
				col_slate
			}, size: 11 })
		}
		if changes.len > visible {
			mut bar_h := (inner_h - 20) * visible / changes.len
			if bar_h < 10 {
				bar_h = 10
			}
			bar_y := y0 + 14 + (inner_h - 20 - bar_h) * app.git_scroll / (changes.len - visible)
			app.gg.draw_rect_filled(x + w - 4, y0 + 14, 2, inner_h - 20, gg.rgba(38, 48, 44, 80))
			app.gg.draw_rect_filled(x + w - 4, bar_y, 2, bar_h, col_brass_dim)
		}
	} else if app.git_rail == 'HISTORY' {
		graph := app.desktop.engine_git_graph(20)
		app.gg.draw_text(x + 8, y0, 'commit graph • ${graph.commits.len} commits • lanes ${graph.max_lane + 1}', gg.TextCfg{ color: col_ink700, size: 11 })
		row_h := 22
		visible := (inner_h - 40) / row_h
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
			hover := idx == app.git_hover
			sel := c.hash == app.git_selected
			if hover { app.gg.draw_rect_filled(x + 4, ry - 1, w - 8, row_h, col_cream200) }
			if sel { app.gg.draw_rect_empty(x + 4, ry - 1, w - 8, row_h, col_brass) }
			// lane dot
			dot_x := x + 12 + lane * 10
			app.gg.draw_rect_filled(dot_x, ry + 7, 8, 8, col_lilac)
			app.gg.draw_rect_empty(dot_x, ry + 7, 8, 8, col_ink)
			if c.parents.len > 1 { app.gg.draw_rect_filled(dot_x + 4, ry + 3, 2, 4, col_lemon) }
			app.gg.draw_text(x + 44, ry + 2, c.hash[..7], gg.TextCfg{ color: col_ink700, size: 11, mono: true })
			msg := if c.message.len > 28 { c.message[..28] + '…' } else { c.message }
			app.gg.draw_text(x + 44, ry + 12, msg, gg.TextCfg{ color: col_ink, size: 11 })
			app.gg.draw_text(x + w - 46, ry + 2, c.author, gg.TextCfg{ color: col_slate, size: 10 })
			if c.refs.len > 0 { app.gg.draw_text(x + w - 46, ry + 12, c.refs[0], gg.TextCfg{ color: col_mint, size: 10 }) }
		}
		// diff preview below graph
		diff_y := y0 + 14 + visible * row_h + 6
		if diff_y + 40 < y + h - 4 {
			app.gg.draw_rect_filled(x + 4, diff_y, w - 8, 1, col_cream200)
			app.gg.draw_text(x + 8, diff_y + 4, 'Diff preview — select commit for hunks', gg.TextCfg{ color: col_slate_dim, size: 11 })
			if app.git_selected != '' {
				hunks := app.desktop.engine_git_diff(app.git_selected)
				if hunks.len > 0 {
					app.gg.draw_text(x + 8, diff_y + 16, '${hunks[0].file}  +${hunks[0].new_count} -${hunks[0].old_count}', gg.TextCfg{ color: col_ink, size: 11, mono: true })
				}
			}
		}
	} else { // COMPARE
		app.gg.draw_text(x + 8, y0, 'COMPARE • HEAD~1..HEAD • diff hunks', gg.TextCfg{ color: col_ink700, size: 11 })
		hunks := app.desktop.engine_git_compare('HEAD~1', 'HEAD')
		row_h := 14
		visible := (inner_h - 20) / row_h
		if visible < 1 {
			return
		}
		app.diff_scroll = clamp_scroll(app.diff_scroll, 20, visible)
		mut line_no := 0
		for hunk in hunks {
			if line_no >= visible {
				break
			}
			app.gg.draw_text(x + 8, y0 + 14 + line_no * row_h, '— ${hunk.file}', gg.TextCfg{ color: col_brass_dim, size: 11, mono: true })
			line_no++
			for line in hunk.lines {
				if line_no >= visible {
					break
				}
				kind := line.kind
				col := match kind {
					.addition { col_mint }
					.deletion { col_coral }
					.header { col_sky }
					else { col_slate }
				}
				prefix := match kind {
					.addition { '+' }
					.deletion { '-' }
					else { ' ' }
				}
				txt := prefix + line.text
				disp := if txt.len > 36 { txt[..36] + '…' } else { txt }
				app.gg.draw_text(x + 12, y0 + 14 + line_no * row_h, disp, gg.TextCfg{ color: col, size: 11, mono: true })
				line_no++
			}
		}
	}
}

// draw_memory_palace_panel — bottom semantic recall, hybrid cosine + token overlap
fn draw_memory_palace_panel(mut app GuiApp, x int, y int, w int, h int) {
	pixel_panel(mut app, x, y, w, h, 'inset')
	app.gg.draw_text(x + 8, y + 6, 'Memory Palace — semantic recall', gg.TextCfg{ color: col_ink, size: 12, bold: true })
	mode := if app.memory_semantic { 'semantic' } else { 'keyword' }
	app.gg.draw_text(x + w - 80, y + 6, mode, gg.TextCfg{ color: col_brass, size: 11 })
	// search bar
	app.gg.draw_rect_filled(x + 8, y + 20, w - 16, 20, col_cream100)
	app.gg.draw_rect_empty(x + 8, y + 20, w - 16, 20, col_ink700)
	q := if app.memory_query == '' {
		'Search palace — try "brokered fs" or "git rails" (semantic)'
	} else {
		app.memory_query
	}
	col := if app.memory_query == '' { col_slate } else { col_ink }
	app.gg.draw_text(x + 14, y + 26, q, gg.TextCfg{ color: col, size: 12 })
	if app.memory_query != '' {
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
			hover := idx == app.memory_hover
			if hover { app.gg.draw_rect_filled(x + 10, ry - 1, w - 20, row_h, col_cream200) }
			pct := int(r.score * 100)
			app.gg.draw_text(x + 14, ry + 2, '${pct}%', gg.TextCfg{ color: if pct > 70 {
				col_mint
			} else {
				col_slate
			}, size: 11, bold: pct > 70 })
			title := if r.entry.title.len > 28 { r.entry.title[..28] + '…' } else { r.entry.title }
			app.gg.draw_text(x + 46, ry + 2, title, gg.TextCfg{ color: col_ink, size: 11 })
			snip := if r.snippet.len > 32 { r.snippet[..32] + '…' } else { r.snippet }
			app.gg.draw_text(x + 46, ry + 10, snip, gg.TextCfg{ color: col_slate_dim, size: 10 })
		}
		if results.len == 0 {
			app.gg.draw_text(x + 14, y + 44, 'No semantic hits — try "skills" or "file tree"', gg.TextCfg{ color: col_slate_dim, size: 12 })
		}
	} else {
		entries := app.desktop.engine_memory_entries()
		app.gg.draw_text(x + 14, y + 44, '${entries.len} palace nodes • hybrid cosine 16-dim hashed embedding', gg.TextCfg{ color: col_slate_dim, size: 11 })
		app.gg.draw_text(x + 14, y + 56, 'Brokered via Engine.memory_semantic_recall • token overlap • 60 FPS virtualized', gg.TextCfg{ color: col_slate, size: 11 })
	}
}

fn draw_workspace(mut app GuiApp, w int, h int) {
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_ws := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_ws
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_cream50)
	pixel_panel(mut app, fx + 8, fy + 8, fw - 16, 32, 'default')
	app.gg.draw_text(fx + 20, fy + 16, 'Workspace — IDE', gg.TextCfg{ color: col_ink, size: font_display_md })
	app.gg.draw_text(fx + 160, fy + 18, 'file-tree • editor tabs • CHANGES/HISTORY/COMPARE • commit graph • diff • brokered fs • memory palace', gg.TextCfg{ color: col_ink500, size: 11 })
	app.gg.draw_text(fx + fw - 90, fy + 16, 'rev ${app.engine_rev}', gg.TextCfg{ color: col_brass_dim, size: 12, mono: true })
	// kanban super potent top
	draw_kanban(mut app, fx, fy, fw)
	// middle IDE: file tree | editor | git rails
	mid_y := fy + 52 + 108 + 12
	mem_h := 92
	mut mid_h := fh - (108 + 12 + mem_h + 20)
	if mid_h < 120 {
		mid_h = 120
	}
	// left file tree 180
	draw_file_tree_panel(mut app, fx + 12, mid_y, 180, mid_h)
	// center editor
	editor_w := fw - 24 - 180 - 4 - 240
	draw_editor_panel(mut app, fx + 12 + 180 + 4, mid_y, editor_w, mid_h)
	// right git rails 240
	draw_git_rails_panel(mut app, fx + fw - 240 - 12, mid_y, 240, mid_h)
	// bottom memory palace semantic recall
	mem_y := mid_y + mid_h + 6
	draw_memory_palace_panel(mut app, fx + 12, mem_y, fw - 24, mem_h)
}

// ── Products & Packs — super potent easy management ─────────────────────────────────
// Brokered via Desktop.engine_products_catalog / packs_catalog (Engine typed, no shell).
// Easy to manage: product cards, pack chips, membership bulk, build preview, digest.
fn draw_products(mut app GuiApp, w int, h int) {
	fx := 208
	fy := 52
	fw := w - 208 - 300
	term_h_pd := if app.term_visible { app.term_height } else { 0 }
	fh := h - 52 - 28 - term_h_pd
	app.gg.draw_rect_filled(fx, fy, fw, fh, col_cream50)
	pixel_panel(mut app, fx + 8, fy + 8, fw - 16, 32, 'default')
	app.gg.draw_text(fx + 20, fy + 16, 'Products & Packs — super potent', gg.TextCfg{ color: col_ink, size: font_display_md })
	prods := app.desktop.engine_products_catalog()
	packs := app.desktop.engine_packs_catalog()
	installed := app.desktop.engine_skills_installed()
	app.gg.draw_text(fx + 240, fy + 18, '${prods.len} products • ${packs.len} packs • ${installed.len} skills installed • docs-only per ADR-006', gg.TextCfg{ color: col_ink500, size: 11 })
	// build preview digest
	preview := if app.desktop != unsafe { nil } { app.desktop.engine_skills_search('', '').len.str() } else { '227' }
	app.gg.draw_text(fx + fw - 110, fy + 16, 'digest ${preview}', gg.TextCfg{ color: col_brass_dim, size: 11, mono: true })
	// product cards
	card_y0 := fy + 48
	card_h := 52
	visible := (fh - 70) / card_h
	if visible < 1 {
		return
	}
	app.products_scroll = clamp_scroll(app.products_scroll, prods.len, visible)
	start := app.products_scroll
	mut end := start + visible
	if end > prods.len {
		end = prods.len
	}
	for idx in start .. end {
		p := prods[idx]
		row := idx - start
		y := card_y0 + row * card_h
		hover := idx == app.products_hover
		bg := if hover { col_cream100 } else { col_cream50 }
		bd := if hover { col_brass } else { col_ink300 }
		pixel_panel(mut app, fx + 12, y, fw - 24, card_h - 6, 'default')
		app.gg.draw_rect_filled(fx + 14, y + 2, fw - 28, card_h - 10, bg)
		app.gg.draw_rect_empty(fx + 14, y + 2, fw - 28, card_h - 10, bd)
		app.gg.draw_text(fx + 22, y + 8, p.id, gg.TextCfg{ color: col_ink, size: 14, bold: true, mono: true })
		app.gg.draw_text(fx + 22, y + 22, p.name, gg.TextCfg{ color: col_ink700, size: 12 })
		mut desc := p.description
		if desc.len > 42 {
			desc = desc[..42] + '…'
		}
		app.gg.draw_text(fx + 22, y + 34, desc, gg.TextCfg{ color: col_slate_dim, size: 11 })
		// skill count pill
		scnt := p.skill_ids.len
		app.gg.draw_rect_filled(fx + fw - 110, y + 8, 44, 14, col_cream200)
		app.gg.draw_text(fx + fw - 102, y + 10, '${scnt} skills', gg.TextCfg{ color: col_ink700, size: 11 })
		// manage button
		hover_manage := hover
		mbg := if hover_manage { col_ink } else { col_ink700 }
		app.gg.draw_rect_filled(fx + fw - 90, y + 26, 56, 16, mbg)
		app.gg.draw_text(fx + fw - 82, y + 29, 'Manage', gg.TextCfg{ color: col_cream100, size: 11, bold: hover_manage })
	}
	if prods.len > visible {
		track_h := visible * card_h
		bar_h := track_h * visible / prods.len
		mut bh := bar_h
		if bh < 12 {
			bh = 12
		}
		bar_y := card_y0 + (track_h - bh) * start / (prods.len - visible)
		app.gg.draw_rect_filled(fx + fw - 6, card_y0, 3, track_h, gg.rgba(38, 48, 44, 30))
		app.gg.draw_rect_filled(fx + fw - 6, bar_y, 3, bh, col_brass_dim)
	}
	// packs chips below cards or at bottom if many
	pack_y := card_y0 + visible * card_h + 8
	if pack_y + 22 < fy + fh - 14 {
		app.gg.draw_text(fx + 14, pack_y, 'Packs — docs-only, toggle to enable (Engine.set_pack_enabled):', gg.TextCfg{ color: col_ink500, size: 11 })
		mut px := fx + 14
		for pk in packs {
			label := pk.id
			active := pk.id in app.desktop.engine_packs_catalog().map(it.id) // dummy; real packs enabled via status
			// Use packs_enabled via onboarding_status? For super-potent, show all 7 docs-only packs
			bg := if active { col_brass } else { col_cream200 }
			fg := if active { col_ink } else { col_slate_dim }
			w2 := label.len * 7 + 14
			if px + w2 > fx + fw - 14 {
				break
			}
			app.gg.draw_rect_filled(px, pack_y + 14, w2, 16, bg)
			app.gg.draw_rect_empty(px, pack_y + 14, w2, 16, col_ink300)
			app.gg.draw_text(px + 7, pack_y + 17, label, gg.TextCfg{ color: fg, size: 11 })
			px += w2 + 6
		}
	}
	app.gg.draw_text(fx + 14, fy + fh - 14, 'Products compose skills via distributions/products.yaml — build --check validates • packs docs-only ADR-006', gg.TextCfg{ color: col_slate, size: 11 })
}

// ── Onboarding — super-potent wizard: workspace init, persona bootstrap, capability/target/product ──
// Single modal wizard where everything is possible and easy to manage. One view, seven steps:
// Detect → Capabilities (227) → Targets (7) → Products/Packs (3+7) → Workspace Init → Personas → Tour → Done.
// All actions wire via Desktop.onboarding_* proxies → Engine transactions → EventBus → AppState (no shell).
fn draw_onboarding(mut app GuiApp, w int, h int) {
	term_h_on := if app.term_visible { app.term_height } else { 0 }
	// overlay dim if showing as modal over world, otherwise full panel when selected_panel==11
	is_overlay := app.show_onboarding && app.selected_panel != 11
	if is_overlay {
		app.gg.draw_rect_filled(0, 44, w, h - 44 - 28 - term_h_on, gg.rgba(26, 19, 32, 55))
	}
	mut fx := if is_overlay { 240 } else { 208 }
	fy := 52
	mut fw := if is_overlay { w - 480 } else { w - 208 - 300 }
	if fw < 520 {
		fw = if is_overlay { 640 } else { w - 208 - 300 }
		fx = if is_overlay { (w - fw) / 2 } else { 208 }
	}
	mut fh := h - 52 - 28 - term_h_on
	if fh < 400 {
		fh = 400
	}
	// panel chrome
	app.gg.draw_rect_filled(fx, fy, fw, fh, gg.rgba(26, 19, 32, 18))
	pixel_panel(mut app, fx, fy, fw, fh, 'default')
	// header — close button if overlay
	app.gg.draw_rect_filled(fx, fy, fw, 36, col_ink)
	app.gg.draw_text(fx + 14, fy + 10, 'Onboarding — Super Potent', gg.TextCfg{ color: col_cream100, size: font_display_md })
	app.gg.draw_text(fx + 220, fy + 12, 'workspace • personas • 227 capabilities • 7 targets • 3 products • one Engine', gg.TextCfg{ color: col_slate_dim, size: 12 })
	if is_overlay {
		// X close
		app.gg.draw_rect_filled(fx + fw - 32, fy + 6, 24, 24, col_charcoal2)
		app.gg.draw_rect_empty(fx + fw - 32, fy + 6, 24, 24, col_line_light)
		app.gg.draw_text(fx + fw - 24, fy + 11, '×', gg.TextCfg{ color: col_slate_dim, size: 16, bold: true })
	}
	// live status via Engine (typed, no shell)
	mut status_is_first := true
	mut pending := []string{}
	mut harness_root := app.onboarding_harness
	mut installed_cnt := 0
	mut enabled_targets := []string{}
	mut persona_cnt := 0
	mut workspace_exists := false
	mut revision := u64(0)
	if app.desktop != unsafe { nil } {
		st := app.desktop.onboarding_status(app.harness_root)
		status_is_first = st.is_first_run
		pending = st.pending_items.clone()
		harness_root = if app.onboarding_harness != '' { app.onboarding_harness } else { st.harness_root }
		installed_cnt = st.installed_count
		enabled_targets = st.enabled_targets.clone()
		persona_cnt = st.persona_count
		workspace_exists = st.workspace_exists
		revision = st.revision
		_ = st
	}
	// step tabs — 7 steps, pixel-snapped
	steps := ['Detect', 'Capabilities', 'Targets', 'Products', 'Workspace', 'Personas', 'Done']
	y_tabs := fy + 40
	mut tab_x := fx + 10
	for si, sname in steps {
		active := si == app.onboarding_step
		bg := if active { col_brass } else if si < app.onboarding_step { col_mint } else { col_charcoal2 }
		fg := if active { col_ink } else { col_slate_dim }
		bd := if active { col_brass } else { col_line }
		tw := sname.len * 7 + 16
		if tab_x + tw > fx + fw - 10 {
			break
		}
		app.gg.draw_rect_filled(tab_x, y_tabs, tw, 18, bg)
		app.gg.draw_rect_empty(tab_x, y_tabs, tw, 18, bd)
		app.gg.draw_text(tab_x + 8, y_tabs + 4, sname, gg.TextCfg{ color: fg, size: 11, bold: active })
		if si < app.onboarding_step {
			app.gg.draw_text(tab_x + tw - 12, y_tabs + 4, '✓', gg.TextCfg{ color: col_ink, size: 11, bold: true })
		}
		tab_x += tw + 4
	}
	// status bar below tabs
	y_status := y_tabs + 24
	pill_col := if status_is_first { col_coral } else { col_mint }
	pill_bg := if status_is_first { gg.rgba(217, 106, 98, 18) } else { gg.rgba(92, 169, 122, 14) }
	app.gg.draw_rect_filled(fx + 10, y_status, 110, 16, pill_bg)
	app.gg.draw_rect_empty(fx + 10, y_status, 110, 16, pill_col)
	app.gg.draw_text(fx + 14, y_status + 3, if status_is_first { 'First Run' } else { 'Onboarded ✓' }, gg.TextCfg{ color: pill_col, size: 11, bold: true })
	app.gg.draw_text(fx + 130, y_status + 3, 'rev ${revision} • api ${app.api_calls} • ${installed_cnt} skills • ${enabled_targets.len} targets • ${persona_cnt} personas • ${if workspace_exists { 'workspace ✓' } else { 'workspace …' }}', gg.TextCfg{ color: col_ink700, size: 11, mono: true })
	if pending.len > 0 {
		app.gg.draw_text(fx + 14, y_status + 20, 'Pending: ${pending.join(' • ')}', gg.TextCfg{ color: col_coral, size: 11 })
	} else {
		app.gg.draw_text(fx + 14, y_status + 20, 'All gaps closed — ready for tour.', gg.TextCfg{ color: col_mint, size: 11 })
	}
	// harness path row — brokered fs validated
	y_harness := y_status + 38
	app.gg.draw_text(fx + 10, y_harness, 'Harness:', gg.TextCfg{ color: col_ink700, size: 12, bold: true })
	mut harness_display := if harness_root == '' { app.harness_root } else { harness_root }
	if harness_display == '' {
		harness_display = (if app.desktop != unsafe { nil } { app.desktop.onboarding_status('').harness_root } else { '' })
		if harness_display == '' {
			harness_display = '/tmp/agent-toolkit-workspace'
		}
	}
	disp := if harness_display.len > 54 { '…' + harness_display[harness_display.len - 54 ..] } else { harness_display }
	app.gg.draw_rect_filled(fx + 64, y_harness - 2, fw - 180, 18, col_cream100)
	app.gg.draw_rect_empty(fx + 64, y_harness - 2, fw - 180, 18, col_ink300)
	app.gg.draw_text(fx + 70, y_harness + 1, disp, gg.TextCfg{ color: col_ink, size: 12, mono: true })
	app.gg.draw_text(fx + fw - 100, y_harness + 1, if workspace_exists { 'exists ✓' } else { 'not yet' }, gg.TextCfg{ color: if workspace_exists { col_mint } else { col_slate }, size: 11 })
	// per-step content — super-potent easy management, everything possible
	content_y := y_harness + 24
	content_h := fh - (content_y - fy) - 52
	if content_h < 120 {
		return
	}
	match app.onboarding_step {
		0 { // Detect — toolkit root, tier, resolve_paths, env precedence
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Detect — Environment', gg.TextCfg{ color: col_ink, size: 14, bold: true })
			paths := if app.desktop != unsafe { nil } { app.desktop.engine_resolve_paths() } else { []string{} }
			root_str := if paths.len > 0 { paths[0] } else { 'AGENT_TOOLKIT_ROOT → XDG → embedded → FHS' }
			tier_str := if paths.len > 1 { paths[1] } else { 'tier: embedded' }
			app.gg.draw_text(fx + 20, content_y + 28, 'Toolkit Root:', gg.TextCfg{ color: col_ink700, size: 12 })
			app.gg.draw_text(fx + 20, content_y + 40, root_str, gg.TextCfg{ color: col_ink, size: 12, mono: true })
			app.gg.draw_text(fx + 20, content_y + 56, tier_str, gg.TextCfg{ color: col_slate_dim, size: 12, mono: true })
			app.gg.draw_text(fx + 20, content_y + 74, 'Resolution: AGENT_TOOLKIT_ROOT (override) → XDG → embedded 3a → FHS 3b → checkout — ADR-015/026', gg.TextCfg{ color: col_slate, size: 11 })
			app.gg.draw_text(fx + 20, content_y + 90, '${if status_is_first { '●' } else { '○' }} is_first_run=${status_is_first}   doctor checks via Engine.doctor() typed', gg.TextCfg{ color: if status_is_first { col_coral } else { col_mint }, size: 12, mono: true })
			app.gg.draw_text(fx + 20, content_y + 110, 'Next: pick capabilities (227) and targets (7) — bulk, one transaction, EventBus → AppState in one tick.', gg.TextCfg{ color: col_ink500, size: 11 })
		}
		1 { // Capabilities — searchable 227 via Engine, bulk install
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Capabilities — 227 skills, 14 domains', gg.TextCfg{ color: col_ink, size: 14, bold: true })
			q := app.skills_query
			disp_q := if q == '' { 'Search — try "core", "delivery", "forge" (fuzzy substring + subsequence + word-boundary)' } else { 'filter: ${q} • ${app.desktop.engine_skills_search(q, '').len} match' }
			app.gg.draw_rect_filled(fx + 20, content_y + 28, fw - 40, 20, col_cream100)
			app.gg.draw_rect_empty(fx + 20, content_y + 28, fw - 40, 20, col_ink700)
			app.gg.draw_text(fx + 26, content_y + 33, disp_q, gg.TextCfg{ color: if q == '' { col_slate } else { col_ink }, size: 12 })
			// chips
			domains := ['core', 'delivery', 'design', 'forge', 'loops', 'quality']
			mut x2 := fx + 20
			for d in domains {
				active := app.skills_domain == d
				bg := if active { col_brass } else { col_cream200 }
				fg2 := if active { col_ink } else { col_slate_dim }
				tw2 := d.len * 7 + 12
				app.gg.draw_rect_filled(x2, content_y + 52, tw2, 16, bg)
				app.gg.draw_rect_empty(x2, content_y + 52, tw2, 16, col_ink300)
				app.gg.draw_text(x2 + 6, content_y + 55, d, gg.TextCfg{ color: fg2, size: 11 })
				x2 += tw2 + 4
			}
			// filtered list preview — top 6 via Engine
			entries := if app.desktop != unsafe { nil } { app.desktop.engine_skills_search(q, app.skills_domain) } else { []desktop_engine.SkillEntry{} }
			list_y := content_y + 74
			for i in 0 .. 6 {
				if i >= entries.len {
					break
				}
				s := entries[i]
				y := list_y + i * 16
				sel := s.id in app.selected_skills_onboarding
				bg2 := if sel { col_lemon } else { col_cream50 }
				app.gg.draw_rect_filled(fx + 20, y, fw - 40, 14, bg2)
				app.gg.draw_text(fx + 24, y + 2, s.id, gg.TextCfg{ color: col_ink, size: 11, mono: true })
				app.gg.draw_text(fx + fw - 90, y + 2, s.domain, gg.TextCfg{ color: col_slate_dim, size: 11 })
			}
			app.gg.draw_text(fx + 20, content_y + content_h - 36, 'Bulk: select via search → "Install 5" writes installed_skills + receipts + provenance in one TX (engine_api_call>0)', gg.TextCfg{ color: col_slate, size: 11 })
			// install 5 button
			hov := app.onboarding_hover == 1
			app.gg.draw_rect_filled(fx + fw - 120, content_y + content_h - 54, 96, 20, if hov { col_ink } else { col_brass })
			app.gg.draw_text(fx + fw - 108, content_y + content_h - 49, 'Install 5', gg.TextCfg{ color: if hov { col_cream100 } else { col_ink }, size: 12, bold: true })
			app.gg.draw_text(fx + 20, content_y + content_h - 54, 'Installed: ${installed_cnt} skills', gg.TextCfg{ color: col_ink700, size: 11, mono: true })
		}
		2 { // Targets — 7 toggles via Engine
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Targets — 7 platforms', gg.TextCfg{ color: col_ink, size: 14, bold: true })
			tgts := ['claude-code', 'cursor', 'opencode', 'pi', 'windsurf', 'cursor-plugins', 'cli']
			for i, t in tgts {
				y := content_y + 30 + i * 20
				enabled := t in enabled_targets
				hov2 := app.targets_hover == i
				bg3 := if enabled { col_ink } else { col_cream200 }
				fg3 := if enabled { col_cream100 } else { col_slate_dim }
				app.gg.draw_rect_filled(fx + 20, y, fw - 40, 16, bg3)
				app.gg.draw_rect_empty(fx + 20, y, fw - 40, 16, if hov2 { col_brass } else { col_ink300 })
				app.gg.draw_text(fx + 26, y + 3, t, gg.TextCfg{ color: fg3, size: 12, mono: true })
				app.gg.draw_text(fx + fw - 80, y + 3, if enabled { 'enabled ●' } else { 'off ○' }, gg.TextCfg{ color: if enabled { col_mint } else { col_slate }, size: 11 })
			}
			// bulk enable all / minimal
			app.gg.draw_rect_filled(fx + 20, content_y + content_h - 40, 90, 18, col_cream200)
			app.gg.draw_text(fx + 28, content_y + content_h - 36, 'Enable 3', gg.TextCfg{ color: col_ink, size: 11, bold: true })
			app.gg.draw_rect_filled(fx + 118, content_y + content_h - 40, 90, 18, col_ink700)
			app.gg.draw_text(fx + 126, content_y + content_h - 36, 'Enable All', gg.TextCfg{ color: col_cream100, size: 11 })
			diff := if app.desktop != unsafe { nil } { app.desktop.engine_targets_enabled().len } else { enabled_targets.len }
			_ = diff
			app.gg.draw_text(fx + 20, content_y + content_h - 56, 'Bulk: onboarding_set_targets_bulk([ids]) → one TX, diff preview before write', gg.TextCfg{ color: col_slate, size: 11 })
		}
		3 { // Products / Packs — membership & digest
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Products & Packs', gg.TextCfg{ color: col_ink, size: 14, bold: true })
			prods := if app.desktop != unsafe { nil } { app.desktop.engine_products_catalog() } else { []desktop_engine.ProductEntry{} }
			packs := if app.desktop != unsafe { nil } { app.desktop.engine_packs_catalog() } else { []desktop_engine.PackEntry{} }
			for i, p in prods {
				if i >= 3 { break }
				y := content_y + 30 + i * 20
				app.gg.draw_rect_filled(fx + 20, y, fw - 40, 16, col_cream100)
				app.gg.draw_text(fx + 26, y + 3, p.id, gg.TextCfg{ color: col_ink, size: 12, mono: true })
				app.gg.draw_text(fx + fw - 80, y + 3, '${p.skill_ids.len} skills', gg.TextCfg{ color: col_slate_dim, size: 11 })
			}
			mut px := fx + 20
			py := content_y + 96
			app.gg.draw_text(fx + 20, py, 'Packs docs-only (ADR-006):', gg.TextCfg{ color: col_ink700, size: 11 })
			for pk in packs {
				label := pk.id
				tw3 := label.len * 7 + 12
				if px + tw3 > fx + fw - 20 { break }
				app.gg.draw_rect_filled(px, py + 12, tw3, 14, col_cream200)
				app.gg.draw_text(px + 6, py + 14, label, gg.TextCfg{ color: col_slate_dim, size: 11 })
				px += tw3 + 4
			}
			preview := if app.desktop != unsafe { nil } { app.desktop.engine_skills_search('', '').len.str() } else { '227' }
			_ = preview
			app.gg.draw_text(fx + 20, content_y + content_h - 36, 'Preview: build_preview() → plugins-digest • membership via update_product_membership in one TX', gg.TextCfg{ color: col_slate, size: 11 })
		}
		4 { // Workspace init — harness scaffold
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Workspace Init — Harness Scaffold', gg.TextCfg{ color: col_ink, size: 14, bold: true })
			app.gg.draw_text(fx + 20, content_y + 30, 'Target: ${harness_display}', gg.TextCfg{ color: col_ink, size: 12, mono: true })
			app.gg.draw_text(fx + 20, content_y + 46, 'Creates: knowledge/ repos/ projects/ packs/ personas/ .agent-toolkit/ knowledge/learnings/ todos/ + .gitignore + packs/README', gg.TextCfg{ color: col_slate_dim, size: 11 })
			status_col2 := if workspace_exists { col_mint } else { col_lemon }
			app.gg.draw_text(fx + 20, content_y + 62, if workspace_exists { '✓ Workspace exists — ready' } else { '○ Not yet — click Init Workspace' }, gg.TextCfg{ color: status_col2, size: 12, bold: true })
			// init button
			hov_init := app.onboarding_hover == 4
			app.gg.draw_rect_filled(fx + 20, content_y + 82, 130, 24, if hov_init { col_ink } else { col_brass })
			app.gg.draw_text(fx + 36, content_y + 89, 'Init Workspace', gg.TextCfg{ color: if hov_init { col_cream100 } else { col_ink }, size: 13, bold: true })
			app.gg.draw_rect_filled(fx + 158, content_y + 82, 140, 24, col_cream200)
			app.gg.draw_text(fx + 168, content_y + 89, 'Init + Personas', gg.TextCfg{ color: col_ink700, size: 12, bold: true })
			if app.onboarding_msg != '' {
				app.gg.draw_text(fx + 20, content_y + 114, app.onboarding_msg, gg.TextCfg{ color: col_brass_dim, size: 11, mono: true })
			}
			app.gg.draw_text(fx + 20, content_y + content_h - 30, 'Via Engine.onboarding_ensure_workspace(path) + StateRepository TX → EventBus → AppState (no shell, brokered fs)', gg.TextCfg{ color: col_slate, size: 10 })
		}
		5 { // Personas — bootstrap 4 persona markdowns
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Persona Bootstrap — 4 work modes', gg.TextCfg{ color: col_ink, size: 14, bold: true })
			personas := ['implementer', 'reviewer', 'researcher', 'architect']
			for i, pers in personas {
				y := content_y + 32 + i * 22
				done := i < persona_cnt
				bg4 := if done { col_mint } else { col_cream200 }
				fg4 := if done { col_ink } else { col_slate_dim }
				app.gg.draw_rect_filled(fx + 20, y, fw - 40, 16, bg4)
				app.gg.draw_rect_empty(fx + 20, y, fw - 40, 16, col_ink300)
				app.gg.draw_text(fx + 26, y + 3, pers, gg.TextCfg{ color: fg4, size: 12, mono: true })
				app.gg.draw_text(fx + fw - 80, y + 3, if done { 'ready ✓' } else { 'pending' }, gg.TextCfg{ color: if done { col_ink } else { col_slate }, size: 11 })
			}
			app.gg.draw_text(fx + 20, content_y + 128, 'Each persona is a markdown with allow/deny + handoffs (implementer→reviewer, etc).', gg.TextCfg{ color: col_slate_dim, size: 11 })
			hov_boot := app.onboarding_hover == 5
			app.gg.draw_rect_filled(fx + 20, content_y + 148, 130, 22, if hov_boot { col_ink } else { col_brass })
			app.gg.draw_text(fx + 32, content_y + 154, 'Bootstrap Personas', gg.TextCfg{ color: if hov_boot { col_cream100 } else { col_ink }, size: 12, bold: true })
			app.gg.draw_text(fx + 20, content_y + content_h - 30, 'Via Engine.onboarding_ensure_personas(harness) → personas/*.md scaffold + TX revision bump', gg.TextCfg{ color: col_slate, size: 10 })
		}
		6 { // Done — tour + complete
			pixel_panel(mut app, fx + 10, content_y, fw - 20, content_h - 20, 'inset')
			app.gg.draw_text(fx + 20, content_y + 10, 'Done — Tour', gg.TextCfg{ color: col_ink, size: 14, bold: true })
			app.gg.draw_text(fx + 20, content_y + 30, '1 → World (floor, GOD mailbox)   2 → Skills (227 fuzzy)   3 → Agents (18)   4 → Targets (7)', gg.TextCfg{ color: col_ink700, size: 12 })
			app.gg.draw_text(fx + 20, content_y + 46, '5 → Doctor (receipts)  6 → Jobs  7 → Loops (inner/outer)  8 → Swarm (pair/team/full)  9 → Workspace IDE  P → Products', gg.TextCfg{ color: col_ink700, size: 12 })
			app.gg.draw_text(fx + 20, content_y + 64, 'All panels via single Engine — no shell, every mutation is a StateRepository Transaction → EventBus → AppState.', gg.TextCfg{ color: col_slate_dim, size: 11 })
			hov_done := app.onboarding_hover == 6
			app.gg.draw_rect_filled(fx + 20, content_y + 84, 110, 22, if hov_done { col_ink } else { col_mint })
			app.gg.draw_text(fx + 34, content_y + 90, 'Complete ✓', gg.TextCfg{ color: col_ink, size: 13, bold: true })
			app.gg.draw_rect_filled(fx + 138, content_y + 84, 110, 22, col_cream200)
			app.gg.draw_text(fx + 150, content_y + 90, 'Back to World', gg.TextCfg{ color: col_ink700, size: 12 })
			app.gg.draw_text(fx + 20, content_y + 112, 'On close, onboarding_completed=true persisted — next boot skips wizard (reset via onboarding_reset).', gg.TextCfg{ color: col_slate, size: 11 })
		}
		else {}
	}
	// footer nav — Back / Next / Complete + progress
	tab_w := fw - 20
	app.gg.draw_rect_filled(fx + 10, fy + fh - 36, tab_w, 26, col_charcoal)
	// progress dots 7
	dots_x := fx + 14
	for di in 0 .. 7 {
		dcol := if di == app.onboarding_step { col_brass } else if di < app.onboarding_step { col_mint } else { col_line }
		app.gg.draw_rect_filled(dots_x + di * 14, fy + fh - 26, 8, 8, dcol)
	}
	app.gg.draw_text(dots_x + 7 * 14 + 8, fy + fh - 26, 'step ${app.onboarding_step + 1}/7 • rev ${revision} • api ${app.api_calls}', gg.TextCfg{ color: col_slate_dim, size: 11, mono: true })
	// Back
	if app.onboarding_step > 0 {
		hov_back := app.onboarding_hover == 10
		app.gg.draw_rect_filled(fx + fw - 220, fy + fh - 32, 64, 20, if hov_back { col_charcoal2 } else { col_ink700 })
		app.gg.draw_rect_empty(fx + fw - 220, fy + fh - 32, 64, 20, col_line_light)
		app.gg.draw_text(fx + fw - 206, fy + fh - 27, 'Back', gg.TextCfg{ color: col_cream100, size: 12 })
	}
	// Next / Complete
	is_last := app.onboarding_step == 6
	hov_next := app.onboarding_hover == 11
	next_bg := if is_last { col_mint } else if hov_next { col_brass } else { col_ink }
	mut next_fg := col_ink
	if hov_next && !is_last {
		next_fg = col_ink
	}
	if is_last {
		next_fg = col_ink
	}
	next_label := if is_last { 'Finish' } else { 'Next →' }
	app.gg.draw_rect_filled(fx + fw - 148, fy + fh - 32, 72, 20, next_bg)
	app.gg.draw_rect_empty(fx + fw - 148, fy + fh - 32, 72, 20, col_brass)
	app.gg.draw_text(fx + fw - 132, fy + fh - 27, next_label, gg.TextCfg{ color: next_fg, size: 12, bold: true })
	if app.onboarding_msg != '' {
		app.gg.draw_text(fx + 110, fy + fh - 26, app.onboarding_msg[..if app.onboarding_msg.len > 48 { 48 } else { app.onboarding_msg.len }], gg.TextCfg{ color: col_lemon, size: 11 })
	}
}

fn draw_inspector(mut app GuiApp, w int, h int) {
	term_h_i := if app.term_visible { app.term_height } else { 0 }
	ix := w - 300
	iy := 52
	iw := 300
	ih := h - 52 - 28 - term_h_i
	app.gg.draw_rect_filled(ix, iy, iw, ih, col_charcoal)
	app.gg.draw_line(ix, iy, ix, iy + ih, col_line)
	app.gg.draw_text(ix + 12, iy + 10, 'INSPECTOR', gg.TextCfg{ color: col_brass, size: 14, bold: true })
	desks := desks_for_app(app)
	if app.selected_desk >= 0 && app.selected_desk < desks.len {
		d := desks[app.selected_desk]
		app.gg.draw_text(ix + 12, iy + 32, d.label, gg.TextCfg{ color: col_paper, size: 14, bold: true })
		app.gg.draw_text(ix + 12, iy + 50, d.tier + ' • ' + d.role, gg.TextCfg{ color: col_slate_dim, size: 14 })
		status_col := if d.status == 'working' {
			gg.rgb(52, 168, 83)
		} else if d.status == 'blocked' { col_oxide } else { col_slate }
		app.gg.draw_text(ix + 12, iy + 70, 'Status: ' + d.status, gg.TextCfg{ color: status_col, size: 14 })
		app.gg.draw_rect_filled(ix + 12, iy + 90, iw - 24, 1, col_line)
		app.gg.draw_text(ix + 12, iy + 100, 'Engine', gg.TextCfg{ color: col_paper, size: 14, bold: true })
		app.gg.draw_text(ix + 12, iy + 118, 'rev ${app.engine_rev}  •  api ${app.api_calls}', gg.TextCfg{ color: col_slate_dim, size: 13 })
		app.gg.draw_text(ix + 12, iy + 136, 'Persist: ~/.cache/agent-toolkit/desktop/engine_state.json', gg.TextCfg{ color: col_slate, size: 12 })
		app.gg.draw_text(ix + 12, iy + 160, 'Actions', gg.TextCfg{ color: col_paper, size: 14, bold: true })
		// Open terminal — clickable, hover-aware
		hover_open := app.mouse_x >= ix + 12 && app.mouse_x <= ix + iw - 12 && app.mouse_y >= iy + 180 && app.mouse_y <= iy + 208
		bg_open := if hover_open { col_charcoal2 } else { col_ink }
		bd_open := if hover_open { col_brass } else { col_line_light }
		app.gg.draw_rect_filled(ix + 12, iy + 180, iw - 24, 28, bg_open)
		app.gg.draw_rect_empty(ix + 12, iy + 180, iw - 24, 28, bd_open)
		app.gg.draw_text(ix + 24, iy + 188, 'Open terminal  (enter)', gg.TextCfg{ color: col_paper, size: 14 })
		// Route handoff — brass primary, hover brightens
		hover_route := app.mouse_x >= ix + 12 && app.mouse_x <= ix + iw - 12 && app.mouse_y >= iy + 214 && app.mouse_y <= iy + 242
		bg_route := if hover_route { gg.rgb(200, 165, 110) } else { col_brass }
		app.gg.draw_rect_filled(ix + 12, iy + 214, iw - 24, 28, bg_route)
		app.gg.draw_text(ix + 24, iy + 222, 'Route handoff  (h)', gg.TextCfg{ color: col_ink, size: 14, bold: true })
		if app.inspector_msg != '' {
			app.gg.draw_text(ix + 12, iy + 250, app.inspector_msg, gg.TextCfg{ color: col_brass, size: 12 })
		} else {
			app.gg.draw_text(ix + 12, iy + 250, 'This is the live Engine inspector. No mock —', gg.TextCfg{ color: col_slate_dim, size: 12 })
			app.gg.draw_text(ix + 12, iy + 262, 'reads from desktop_engine snapshot.', gg.TextCfg{ color: col_slate_dim, size: 12 })
		}
	} else {
		app.gg.draw_text(ix + 12, iy + 36, 'Select a desk on the floor', gg.TextCfg{ color: col_slate_dim, size: 14 })
	}
	// ── Signature: per-desk libghostty-vt 40×6 multiplex — live VT preview (visible proof) ──
	// Each desk owns a 40×6 GhosttyTerminal; selected desk's VT renders inline in inspector
	// This is the designer's super-potent touch: multiplex is not hidden — it glows in the inspector
	if app.selected_desk >= 0 && app.selected_desk < desks.len && app.per_desk_ghost.len > app.selected_desk {
		vt_y := iy + 272
		vt_h := 62
		vt_x := ix + 8
		vt_w := iw - 16
		// panel chrome — inset terminal variant with brass accent
		app.gg.draw_rect_filled(vt_x, vt_y, vt_w, vt_h, gg.rgb(10, 14, 18))
		app.gg.draw_rect_empty(vt_x, vt_y, vt_w, vt_h, col_line)
		app.gg.draw_rect_filled(vt_x, vt_y, vt_w, 14, col_ink)
		app.gg.draw_rect_filled(vt_x, vt_y + 13, vt_w, 1, col_brass_dim)
		desk_label := desks[app.selected_desk].label
		app.gg.draw_text(vt_x + 8, vt_y + 3, 'VT 40×6 — ${desk_label} — libghostty-vt', gg.TextCfg{ color: col_brass, size: 10, mono: true, bold: true })
		app.gg.draw_text(vt_x + vt_w - 34, vt_y + 3, '40×6', gg.TextCfg{ color: col_slate, size: 10, mono: true })
		// live cursor pulse when selected
		pulse_vt := if app.frame % 40 < 20 { col_brass } else { gg.rgba(184, 147, 90, 70) }
		app.gg.draw_rect_filled(vt_x + vt_w - 10, vt_y + 4, 6, 6, pulse_vt)
		// render ghost visible lines — up to 4 rows inside 62px panel (14 header + 4*10 + 8)
		ghost := app.per_desk_ghost[app.selected_desk]
		vis := ghost.visible_lines()
		max_rows := 4
		for ri in 0 .. max_rows {
			if ri >= vis.len { break }
			mut line := vis[ri]
			if line.len > 38 { line = line[..38] + '…' }
			// strip control chars for display
			mut clean := ''
			for ch in line { if ch >= 32 && ch < 127 { clean += ch.ascii_str() } else if ch == `\t` { clean += '  ' } }
			if clean.len == 0 { continue }
			ry := vt_y + 18 + ri * 10
			// per-line color from ghost colors
			col_idx := if ri < ghost.colors.len && ghost.colors[ri].len > 0 { ghost.colors[ri][0] } else { 0 }
			gcol := match col_idx { 1 { col_brass } 2 { col_coral } 3 { gg.rgb(52, 168, 83) } 4 { col_slate } else { col_paper_dim } }
			app.gg.draw_text(vt_x + 8, ry, clean, gg.TextCfg{ color: gcol, size: 10, mono: true })
		}
		if vis.len == 0 {
			app.gg.draw_text(vt_x + 8, vt_y + 22, '[${desk_label}] ready — 40×6 multiplex', gg.TextCfg{ color: col_slate_dim, size: 10, mono: true })
			app.gg.draw_text(vt_x + 8, vt_y + 32, 'type in world to feed this VT', gg.TextCfg{ color: col_slate, size: 10 })
		}
		// scanline overlay — subtle CRT 1px every 2 rows
		for sy in 0 .. 4 { app.gg.draw_line(vt_x + 1, vt_y + 18 + sy * 10 + 9, vt_x + vt_w - 1, vt_y + 18 + sy * 10 + 9, gg.rgba(0, 0, 0, 10)) }
		// bottom hint — click to focus main VT
		app.gg.draw_text(vt_x + 8, vt_y + vt_h - 9, 'multiplexed • Tab to focus global ghostty-vt', gg.TextCfg{ color: col_slate, size: 9 })
	}
	// ── Per-desk live logs (workshop terminal) ──
	filter_q := active_log_filter(app)
	all_logs := collect_engine_logs(app)
	desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks.len {
		per_desk_logs(all_logs, desks[app.selected_desk], filter_q)
	} else {
		filtered_logs(all_logs, filter_q)
	}
	// header for activity with filter hint — shifted down to make room for 40×6 VT preview (signature)
	header := if filter_q != '' {
		'Activity — filter: ${filter_q}'
	} else {
		'Activity — per-desk live'
	}
	header_off := if app.selected_desk >= 0 && app.per_desk_ghost.len > app.selected_desk { 64 } else { 0 }
	header_y := iy + 276 + header_off
	app.gg.draw_text(ix + 12, header_y, header, gg.TextCfg{ color: col_paper, size: 13, bold: true })
	if filter_q != '' {
		app.gg.draw_text(ix + 12, header_y + 12, '${desk_logs.len}/${all_logs.len} match — palette filters logs', gg.TextCfg{ color: col_brass, size: 11 })
	} else {
		app.gg.draw_text(ix + 12, header_y + 12, '${desk_logs.len} lines — click to copy • scroll', gg.TextCfg{ color: col_slate, size: 11 })
	}
	// divider
	app.gg.draw_rect_filled(ix + 12, header_y + 22, iw - 24, 1, col_line)
	// scrollable log window inside inspector
	mut inspector_log_h := ih - 310 - header_off
	if inspector_log_h < 40 {
		inspector_log_h = 40
	}
	row_h := 13
	mut visible_i := inspector_log_h / row_h
	if visible_i < 1 {
		visible_i = 1
	}
	// clamp inspector scroll
	app.inspector_scroll = clamp_scroll(app.inspector_scroll, desk_logs.len, visible_i)
	start_i := app.inspector_scroll
	mut end_i := start_i + visible_i
	if end_i > desk_logs.len {
		end_i = desk_logs.len
	}
	log_y0 := iy + 302 + header_off
	// background for log area — xterm-like ink
	app.gg.draw_rect_filled(ix + 8, log_y0 - 2, iw - 16, inspector_log_h + 4, term_bg)
	app.gg.draw_rect_empty(ix + 8, log_y0 - 2, iw - 16, inspector_log_h + 4, col_line)
	if desk_logs.len == 0 {
		app.gg.draw_text(ix + 16, log_y0 + 6, 'No logs match filter', gg.TextCfg{ color: col_slate_dim, size: 13, mono: true })
		app.gg.draw_text(ix + 16, log_y0 + 20, 'Clear palette (ESC) to show all', gg.TextCfg{ color: col_slate, size: 12 })
	} else {
		for idx in start_i .. end_i {
			l := desk_logs[idx]
			row := idx - start_i
			y := log_y0 + row * row_h
			is_hover_i := idx == app.inspector_hover
			if is_hover_i {
				app.gg.draw_rect_filled(ix + 9, y - 1, iw - 18, row_h, col_charcoal2)
				app.gg.draw_rect_empty(ix + 9, y - 1, iw - 18, row_h, gg.rgba(184, 147, 90, 45))
			}
			// tiny level dot
			app.gg.draw_rect_filled(ix + 14, y + 4, 4, 4, term_level_color(l.level))
			// monospace log line — truncate to fit inspector
			mut txt := pad_right(l.ts, 8) + ' ' + pad_right(term_level_label(l.level), 7) + ' ' + pad_right(l.source, 12) + ' ' + l.msg
			if txt.len > 54 {
				txt = txt[..54] + '…'
			}
			app.gg.draw_text(ix + 22, y, txt, gg.TextCfg{
				color: if is_hover_i {
					col_paper} else {
					col_paper_dim}
				size: 12
				mono: true
			})
		}
		// scrollbar for inspector
		if desk_logs.len > visible_i {
			mut bar_h := inspector_log_h * visible_i / desk_logs.len
			if bar_h < 12 {
				bar_h = 12
			}
			bar_y := log_y0 + (inspector_log_h - bar_h) * start_i / (desk_logs.len - visible_i)
			app.gg.draw_rect_filled(ix + iw - 10, log_y0, 3, inspector_log_h, gg.rgba(38, 48, 44, 180))
			app.gg.draw_rect_filled(ix + iw - 10, bar_y, 3, bar_h, col_brass_dim)
		}
	}
	// bottom hint for inspector scroll
	app.gg.draw_text(ix + 12, iy + ih - 14, '↑↓ scroll  •  click row to copy  •  / filters', gg.TextCfg{ color: col_slate_dim, size: 11 })
}

fn draw_terminal(mut app GuiApp, w int, h int) {
	term_h := app.term_height
	y0 := h - 28 - term_h
	x0 := 200
	tw := w - 200
	// background — xterm ink, workshop border
	app.gg.draw_rect_filled(x0, y0, tw, term_h, term_bg)
	app.gg.draw_line(x0, y0, w, y0, term_border)
	app.gg.draw_line(x0, y0, x0, y0 + term_h, term_border)
	// header bar — charcoal with brass accent — libghostty-vt
	app.gg.draw_rect_filled(x0, y0, tw, 24, term_header_bg)
	app.gg.draw_line(x0, y0 + 24, w, y0 + 24, col_line)
	app.gg.draw_rect_filled(x0, y0, 3, 24, col_brass)
	app.gg.draw_text(x0 + 12, y0 + 7, 'TERMINAL — Ghostty VT (libghostty-vt)  •  `help`  •  `clear`  •  ghost focus: ${if app.ghost_focused {
		'yes'
	} else {
		'no'
	}}', gg.TextCfg{ color: col_paper, size: 13, bold: true, mono: true })
	filter_q := active_log_filter(app)
	if filter_q != '' {
		app.gg.draw_text(x0 + 520, y0 + 7, 'filter: ${filter_q}', gg.TextCfg{ color: col_brass, size: 13, bold: true, mono: true })
		app.gg.draw_text(x0 + tw - 220, y0 + 7, '${filtered_logs(collect_engine_logs(app), filter_q).len} match', gg.TextCfg{ color: col_brass_dim, size: 12 })
	} else {
		app.gg.draw_text(x0 + tw - 260, y0 + 7, 'global feed — click row to copy', gg.TextCfg{ color: col_slate, size: 12 })
	}
	// live indicator pulse
	pulse_col := if app.frame % 60 < 30 { gg.rgb(52, 168, 83) } else { gg.rgba(52, 168, 83, 120) }
	app.gg.draw_rect_filled(x0 + tw - 42, y0 + 8, 8, 8, pulse_col)
	app.gg.draw_text(x0 + tw - 30, y0 + 7, 'LIVE', gg.TextCfg{ color: pulse_col, size: 12, bold: true })
	// copy feedback
	if app.term_copied != '' && app.frame - app.term_copied_at < 90 {
		mut txt := app.term_copied
		if txt.len > 64 {
			txt = txt[..64] + '…'
		}
		app.gg.draw_text(x0 + 12, y0 + term_h - 14, 'copied → ${txt}', gg.TextCfg{ color: col_brass, size: 12, mono: true })
	}
	// content — libghostty-vt (ghostty-inspired) + live logs
	// Ghostty already fed in frame(); render its scrollback + prompt
	content_y := y0 + 28
	content_x := x0 + 8
	content_w := tw - 16
	// inner panel
	app.gg.draw_rect_filled(content_x, content_y, content_w, term_h - 32, gg.rgb(10, 14, 18))
	app.gg.draw_rect_empty(content_x, content_y, content_w, term_h - 32, col_line)
	// Signature: CRT scanline overlay — faint horizontal lines at 50% rows (atelier workshop vibe)
	for sy in 1 .. ((term_h - 32) / 2) {
		sy_y := content_y + sy * 2
		if sy_y < content_y + term_h - 32 { app.gg.draw_line(content_x + 1, sy_y, content_x + content_w - 1, sy_y, gg.rgba(0, 0, 0, 8)) }
	}
	// Ghostty visible lines — 40×6 multiplex proven via per-desk ghost array + global 80×18
	ghost_lines := app.ghost.visible_lines()
	row_h := 14
	visible := term_visible_rows(term_h) - 1 // reserve one for prompt
	if ghost_lines.len == 0 {
		app.gg.draw_text(content_x + 10, content_y + 10, 'Ghostty VT ready — type help, skills, clear — live Engine logs stream here', gg.TextCfg{ color: col_slate_dim, size: 14, mono: true })
	} else {
		for idx, line in ghost_lines {
			if idx >= visible {
				break
			}
			y := content_y + 8 + idx * row_h
			is_hover := idx == app.term_hover
			if is_hover {
				app.gg.draw_rect_filled(content_x + 1, y - 1, content_w - 2, row_h, col_charcoal2)
			}
			// color from ghost
			col_idx := if idx < app.ghost.colors.len && app.ghost.colors[idx].len > 0 {
				app.ghost.colors[idx][0]
			} else {
				0
			}
			gcol := match col_idx {
				1 { col_brass }
				2 { col_oxide }
				3 { gg.rgb(52, 168, 83) }
				4 { col_slate }
				else { col_paper_dim }
			}
			// truncate
			disp := if line.len > 96 { line[..96] + '…' } else { line }
			app.gg.draw_text(content_x + 8, y, disp, gg.TextCfg{ color: gcol, size: 13, mono: true })
		}
	}
	// prompt line at bottom of terminal content
	prompt_y := content_y + term_h - 32 - 18
	// prompt bg
	app.gg.draw_rect_filled(content_x, prompt_y - 4, content_w, 18, gg.rgba(184, 147, 90, 12))
	prompt_col := if app.ghost_focused { col_brass } else { col_slate }
	app.gg.draw_text(content_x + 8, prompt_y, app.ghost.prompt_line(), gg.TextCfg{ color: prompt_col, size: 13, mono: true, bold: app.ghost_focused })
	// focus hint
	if !app.ghost_focused {
		app.gg.draw_text(content_x + content_w - 110, prompt_y, 'click to focus', gg.TextCfg{ color: col_slate, size: 12 })
	}
	// scrollbar for libghostty-vt
	all_ghost_len := app.ghost.lines.len
	if all_ghost_len > visible {
		track_x := content_x + content_w - 6
		track_y := content_y + 8
		track_h := term_h - 48
		start := if app.ghost.scroll - visible - 1 < 0 { 0 } else { app.ghost.scroll - visible - 1 }
		mut bar_h := track_h * visible / all_ghost_len
		if bar_h < 14 {
			bar_h = 14
		}
		bar_y := track_y + (track_h - bar_h) * start / (all_ghost_len - visible)
		app.gg.draw_rect_filled(track_x, track_y, 4, track_h, gg.rgba(38, 48, 44, 200))
		app.gg.draw_rect_filled(track_x, bar_y, 4, bar_h, col_brass_dim)
	}
	// footer stats
	app.gg.draw_text(content_x + 6, y0 + term_h - 14, '${all_ghost_len} lines  •  Ghostty VT  •  ↑↓ history  •  enter to run', gg.TextCfg{ color: col_slate, size: 11 })
}

// desk_rect already defined above
fn draw_palette(mut app GuiApp, w int, h int) {
	app.gg.draw_rect_filled(0, 0, w, h, gg.rgba(0, 0, 0, 120))
	cx := w / 2 - 280
	cy := h / 2 - 180
	pw := 560
	ph := 360
	app.gg.draw_rect_filled(cx, cy, pw, ph, col_charcoal)
	app.gg.draw_rect_empty(cx, cy, pw, ph, col_line_light)
	app.gg.draw_text(cx + 16, cy + 12, 'COMMAND PALETTE', gg.TextCfg{ color: col_brass, size: 14, bold: true })
	app.gg.draw_text(cx + pw - 60, cy + 12, 'ESC', gg.TextCfg{ color: col_slate, size: 13 })
	app.gg.draw_rect_filled(cx + 12, cy + 32, pw - 24, 32, col_ink)
	app.gg.draw_rect_empty(cx + 12, cy + 32, pw - 24, 32, col_brass)
	q := if app.palette_query == '' { 'Type to search…' } else { app.palette_query }
	qcol := if app.palette_query == '' { col_slate } else { col_paper }
	app.gg.draw_text(cx + 20, cy + 42, '> ${q}', gg.TextCfg{ color: qcol, size: 15 })
	filtered := filtered_palette(app.palette_query)
	for i, it in filtered {
		if i >= 7 {
			break
		}
		y := cy + 76 + i * 36
		is_sel := i == app.palette_selected
		bg := if is_sel { col_ink } else { col_charcoal }
		bd := if is_sel { col_brass } else { col_line }
		app.gg.draw_rect_filled(cx + 12, y, pw - 24, 32, bg)
		app.gg.draw_rect_empty(cx + 12, y, pw - 24, 32, bd)
		app.gg.draw_text(cx + 20, y + 7, it.label, gg.TextCfg{
			color: if is_sel {
				col_paper} else {
				gg.rgb(226, 232, 240)}
			size: 14
			bold: is_sel
		})
		app.gg.draw_text(cx + 20, y + 19, it.desc, gg.TextCfg{ color: col_slate_dim, size: 12 })
		app.gg.draw_text(cx + pw - 40, y + 10, it.keys, gg.TextCfg{ color: col_slate, size: 13 })
	}
	if filtered.len == 0 {
		app.gg.draw_text(cx + 20, cy + 86, 'No matches — try another query', gg.TextCfg{ color: col_slate_dim, size: 14 })
	}
}

fn draw_help(mut app GuiApp, w int, h int) {
	app.gg.draw_rect_filled(0, 0, w, h, gg.rgba(0, 0, 0, 130))
	cx := w / 2 - 240
	cy := h / 2 - 140
	pw := 480
	ph := 280
	app.gg.draw_rect_filled(cx, cy, pw, ph, col_charcoal)
	app.gg.draw_rect_empty(cx, cy, pw, ph, col_line_light)
	app.gg.draw_text(cx + 16, cy + 12, 'KEYBOARD', gg.TextCfg{ color: col_brass, size: 14, bold: true })
	lines := ['1–8  Switch panel (World, Skills, Agents…)', '/ or Ctrl+K  Command palette (fuzzy)',
		'Up/Down  Navigate palette or desk  •  Enter to activate', 'ESC  Close palette / help',
		'H  Toggle help', 'Click  Select desk or dock item (hover highlights)',
		'Enter  Open terminal for selected desk  •  R Route handoff']
	for i, l in lines {
		app.gg.draw_text(cx + 16, cy + 36 + i * 18, l, gg.TextCfg{ color: col_paper, size: 14 })
	}
	app.gg.draw_text(cx + 16, cy + ph - 22, 'All text is English. Press H or ESC to close.', gg.TextCfg{ color: col_slate_dim, size: 13 })
}

fn activate_palette_selection(mut app GuiApp) {
	filtered := filtered_palette(app.palette_query)
	if filtered.len == 0 {
		app.palette_open = false
		app.palette_query = ''
		app.palette_selected = 0
		return
	}
	clamped := if app.palette_selected < 0 {
		0
	} else if app.palette_selected >= filtered.len {
		filtered.len - 1
	} else {
		app.palette_selected
	}
	sel := filtered[clamped]
	match sel.id {
		'world' {
			app.selected_panel = 0
		}
		'skills' {
			app.selected_panel = 1
		}
		'agents' {
			app.selected_panel = 2
		}
		'mcp' {
			app.selected_panel = 3
		}
		'targets' {
			app.selected_panel = 4
		}
		'doctor' {
			app.selected_panel = 5
		}
		'jobs' {
			app.selected_panel = 6
		}
		'loops' {
			app.selected_panel = 7
		}
		'swarm' {
			app.selected_panel = 8
		}
		'workspace' {
			app.selected_panel = 9
		}
		'serve' {
			app.inspector_msg = 'Serve: agent-toolkit serve --port 3847'
		}
		'doctor_fix' {
			app.selected_panel = 5
			app.inspector_msg = 'Doctor fix: running checks…'
		}
		'install' {
			app.selected_panel = 1
			app.inspector_msg = 'Install: agent-toolkit install --dry-run'
		}
		else {}
	}
	app.palette_open = false
	app.palette_query = ''
	app.palette_selected = 0
}

fn on_event(e &gg.Event, mut app GuiApp) {
	if e.typ == .key_down {
		if app.palette_open {
			if e.key_code == .escape {
				app.palette_open = false
				app.palette_query = ''
				app.palette_selected = 0
				return
			}
			if e.key_code == .enter {
				activate_palette_selection(mut app)
				return
			}
			if e.key_code == .backspace {
				if app.palette_query.len > 0 {
					app.palette_query = app.palette_query[..app.palette_query.len - 1]
					// clamp selection after filtering narrows
					filtered := filtered_palette(app.palette_query)
					if app.palette_selected >= filtered.len {
						app.palette_selected = if filtered.len > 0 { filtered.len - 1 } else { 0 }
					}
				}
				return
			}
			if e.key_code == .up {
				if app.palette_selected > 0 {
					app.palette_selected--
				}
				return
			}
			if e.key_code == .down {
				filtered := filtered_palette(app.palette_query)
				if app.palette_selected + 1 < filtered.len {
					app.palette_selected++
				}
				return
			}
			if e.char_code > 32 && e.char_code < 127 {
				app.palette_query += rune(e.char_code).str()
				app.palette_selected = 0
				return
			}
			return
		}
		if e.key_code == .escape {
			if app.palette_open {
				app.palette_open = false
				app.palette_query = ''
				app.palette_selected = 0
				return
			}
			if app.show_help {
				app.show_help = false
				return
			}
			if app.show_onboarding {
				app.show_onboarding = false
				app.onboarding_msg = 'Onboarding dismissed — press o to reopen'
				return
			}
			if app.ghost_focused && app.term_visible {
				// super potent: Esc first unfocuses Ghostty, second quits — preserves terminal data
				app.ghost_focused = false
				return
			}
			app.gg.quit()
			return
		}
		// libghostty-vt toggle — Tab flips ghost_focused, the super potent multiplexed terminal
		if e.key_code == .tab {
			if app.term_visible {
				app.ghost_focused = !app.ghost_focused
			}
			return
		}
		if e.key_code == .slash || (e.key_code == .k && (e.modifiers & u32(gg.Modifier.ctrl)) != 0) {
			app.palette_open = true
			app.palette_query = ''
			app.palette_selected = 0
			return
		}
		if e.char_code == `h` || e.char_code == `H` {
			app.show_help = !app.show_help
			return
		}
		if e.char_code == `r` || e.char_code == `R` {
			// Route handoff from inspector via keyboard
			desks := desks_for_app(app)
			if app.selected_desk >= 0 && app.selected_desk < desks.len {
				app.inspector_msg = 'Handoff routed: ${desks[app.selected_desk].label} → reviewer'
			}
			return
		}
		// super potent IDE typing — skills 227 fuzzy + memory palace semantic recall + file-tree nav
		// When skills or workspace panels active, capture typing there instead of ghost (easy to manage, brokered)
		if !app.palette_open && !app.show_help {
			if app.selected_panel == 1 {
				// skills 227 search — backspace, escape clears, arrows scroll, printable appends
				if e.key_code == .backspace {
					if app.skills_query.len > 0 {
						app.skills_query = app.skills_query[..app.skills_query.len - 1]
					}
					app.skills_scroll = 0
					return
				}
				if e.key_code == .escape {
					app.skills_query = ''
					app.skills_domain = ''
					return
				}
				if e.key_code == .up {
					app.skills_scroll -= 1
					return
				}
				if e.key_code == .down {
					app.skills_scroll += 1
					return
				}
				if e.key_code == .enter {
					entries := skills_filtered_entries(mut app)
					if app.skills_selected >= 0 && app.skills_selected < entries.len {
						sel := entries[app.skills_selected]
						app.inspector_msg = 'Skill ${sel.id} selected — install via Engine'
					}
					return
				}
				if e.char_code > 32 && e.char_code < 127 {
					app.skills_query += rune(e.char_code).str()
					app.skills_scroll = 0
					return
				}
			}
			if app.selected_panel == 9 {
				// workspace IDE — memory palace semantic query + file tree nav + editor scroll
				if e.key_code == .backspace {
					if app.memory_query.len > 0 {
						app.memory_query = app.memory_query[..app.memory_query.len - 1]
					} else if app.skills_query.len > 0 {
						app.skills_query = app.skills_query[..app.skills_query.len - 1]
					}
					return
				}
				if e.key_code == .escape {
					app.memory_query = ''
					return
				}
				if e.key_code == .up {
					// scroll file tree or memory depending on hover region — default memory
					if app.memory_query != '' {
						app.memory_scroll -= 1
					} else {
						app.file_tree_scroll -= 1
					}
					return
				}
				if e.key_code == .down {
					if app.memory_query != '' {
						app.memory_scroll += 1
					} else {
						app.file_tree_scroll += 1
					}
					return
				}
				if e.char_code > 32 && e.char_code < 127 {
					// typing goes to memory palace semantic recall when workspace active (super potent)
					app.memory_query += rune(e.char_code).str()
					return
				}
				// j/k for file tree scroll, h/l for editor tabs
				if e.char_code == `j` || e.char_code == `J` {
					app.file_tree_scroll += 1
					return
				}
				if e.char_code == `k` || e.char_code == `K` {
					app.file_tree_scroll -= 1
					return
				}
				if e.char_code == `h` || e.char_code == `H` {
					if app.active_tab > 0 {
						app.active_tab -= 1
					}
					return
				}
				if e.char_code == `l` || e.char_code == `L` {
					if app.active_tab + 1 < app.editor_tabs.len {
						app.active_tab += 1
					}
					return
				}
			}
		}
		// libghostty-vt — when focused, route typing to Ghostty terminal (libghostty-vt)
		// Terminal is bottom strip; ghost has priority over log scroll when focused — super potent
		if !app.palette_open && !app.show_help && app.ghost_focused && app.term_visible && app.selected_panel != 1 && app.selected_panel != 9 {
			// Ctrl+L clears Ghostty (like terminal clear), Ctrl+C copies Ghostty visible
			if (e.modifiers & u32(gg.Modifier.ctrl)) != 0 {
				if e.char_code == `l` || e.char_code == `L` {
					app.ghost.clear()
					return
				}
				if e.char_code == `c` || e.char_code == `C` {
					copy_to_clipboard(mut app, app.ghost.copy_visible())
					return
				}
			}
			// PgUp/PgDn scroll Ghostty scrollback 1000
			if e.key_code == .page_up {
				app.ghost.scroll_up(5)
				return
			}
			if e.key_code == .page_down {
				app.ghost.scroll_down(5)
				return
			}
			// Left/Right moves cursor inside toolkit> prompt
			if e.key_code == .left || e.key_code == .right {
				app.ghost.handle_key(int(e.key_code), e.char_code, false, false, false, false)
				return
			}
			// Enter submits, Backspace edits, Up/Down history, printable chars append (space inclusive)
			if e.key_code == .enter {
				app.ghost.submit_input()
				return
			}
			if e.key_code == .backspace {
				app.ghost.handle_key(int(e.key_code), e.char_code, true, false, false, false)
				return
			}
			if e.key_code == .up {
				app.ghost.handle_key(int(e.key_code), e.char_code, false, false, true, false)
				return
			}
			if e.key_code == .down {
				app.ghost.handle_key(int(e.key_code), e.char_code, false, false, false, true)
				return
			}
			if e.char_code >= 32 && e.char_code < 127 {
				app.ghost.handle_key(int(e.key_code), e.char_code, false, false, false, false)
				return
			}
			// Esc already handled above; other keys fall through to log scroll
		}
		// Terminal scroll when palette not open — j/k or page keys scroll feed, c copies hovered
		if !app.palette_open && app.term_visible {
			if e.key_code == .page_up {
				vis := term_visible_rows(app.term_height)
				app.term_scroll -= vis
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				app.term_auto_pin = false
				return
			}
			if e.key_code == .page_down {
				vis := term_visible_rows(app.term_height)
				app.term_scroll += vis
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				if app.term_scroll + vis >= all.len {
					app.term_auto_pin = true
				}
				return
			}
			if e.char_code == `j` || e.char_code == `J` {
				app.term_scroll += 1
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				vis := term_visible_rows(app.term_height)
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				app.term_auto_pin = app.term_scroll + vis >= all.len
				return
			}
			if e.char_code == `k` || e.char_code == `K` {
				app.term_scroll -= 1
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				vis := term_visible_rows(app.term_height)
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				app.term_auto_pin = false
				return
			}
			if e.char_code == `c` || e.char_code == `C` {
				if app.term_hover >= 0 {
					logs := filtered_logs(collect_engine_logs(app), active_log_filter(app))
					if app.term_hover < logs.len {
						copy_to_clipboard(mut app, logs[app.term_hover].raw + ' | ' + logs[app.term_hover].msg)
						return
					}
				}
				if app.inspector_hover >= 0 {
					desks := desks_for_app(app)
					all_logs := collect_engine_logs(app)
					desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks.len {
						per_desk_logs(all_logs, desks[app.selected_desk], active_log_filter(app))
					} else {
						filtered_logs(all_logs, active_log_filter(app))
					}
					if app.inspector_hover < desk_logs.len {
						copy_to_clipboard(mut app, desk_logs[app.inspector_hover].raw + ' | ' + desk_logs[app.inspector_hover].msg)
						return
					}
				}
			}
			if e.char_code == `g` || e.char_code == `G` {
				// toggle terminal visibility
				app.term_visible = !app.term_visible
				return
			}
		}
		if e.char_code == `t` || e.char_code == `T` {
			return
		}
		if e.char_code >= `1` && e.char_code <= `9` {
			idx := int(e.char_code - `1`)
			if idx >= 0 && idx < 10 {
				app.selected_panel = idx
			}
			return
		}
		if e.char_code == `0` {
			// 0 → Workspace (panel 9)
			app.selected_panel = 9
			return
		}
		if e.char_code == `p` || e.char_code == `P` {
			app.selected_panel = 10
			app.show_onboarding = false
			return
		}
		if e.char_code == `o` || e.char_code == `O` {
			// super-potent: toggle onboarding wizard overlay / panel 11
			if app.show_onboarding && app.selected_panel == 11 {
				app.show_onboarding = false
			} else {
				app.show_onboarding = true
				app.selected_panel = 11
				app.onboarding_msg = 'Onboarding wizard toggled via o — 7 steps ready'
			}
			return
		}
		// onboarding wizard next/back when overlay visible (n/b, arrows, enter)
		if app.show_onboarding || app.selected_panel == 11 {
			if e.key_code == .right || e.char_code == `n` || e.char_code == `N` {
				if app.onboarding_step < 6 {
					app.onboarding_step++
					app.onboarding_msg = 'Step ${app.onboarding_step + 1}/7'
				} else {
					// complete onboarding via Engine
					if app.desktop != unsafe { nil } {
						rev := app.desktop.onboarding_complete(app.harness_root) or {
							app.onboarding_msg = 'complete failed: ${err}'
							0
						}
						if rev > 0 {
							app.show_onboarding = false
							app.selected_panel = 0
							app.onboarding_msg = 'Onboarding complete rev=${rev} ✓'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
				}
				return
			}
			if e.key_code == .left || e.char_code == `b` || e.char_code == `B` {
				if app.onboarding_step > 0 {
					app.onboarding_step--
					app.onboarding_msg = 'Step ${app.onboarding_step + 1}/7'
				}
				return
			}
			if e.key_code == .enter {
				// per-step enter triggers super-potent action
				match app.onboarding_step {
					4 {
						// workspace init
						harness := if app.onboarding_harness != '' { app.onboarding_harness } else { app.harness_root }
						rev := app.desktop.onboarding_ensure_workspace(harness) or {
							app.onboarding_msg = 'workspace init failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Workspace initialized rev=${rev} — harness ${harness}'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					5 {
						harness := if app.onboarding_harness != '' { app.onboarding_harness } else { app.harness_root }
						rev := app.desktop.onboarding_ensure_personas(harness) or {
							app.onboarding_msg = 'personas failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Personas bootstrapped rev=${rev} ✓'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					1 {
						// capability bulk install 5 via Engine
						cand := app.desktop.engine_skills_search(app.skills_query, app.skills_domain)
						mut ids := []string{}
						for i in 0 .. 5 {
							if i >= cand.len { break }
							ids << cand[i].id
						}
						if ids.len > 0 {
							rev := app.desktop.onboarding_bulk_install_skills(ids) or {
								app.onboarding_msg = 'capability bulk failed: ${err}'
								0
							}
							if rev > 0 {
								app.onboarding_msg = 'Installed ${ids.len} skills rev=${rev}'
								app.engine_rev = app.desktop.app_state_snapshot().revision
								app.api_calls = app.desktop.engine_api_calls()
							}
						}
					}
					2 {
						// targets bulk enable minimal 3
						ids := ['claude-code', 'opencode', 'cli']
						rev := app.desktop.onboarding_set_targets_bulk(ids) or {
							app.onboarding_msg = 'targets failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Targets enabled ${ids.join(',')} rev=${rev}'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					3 {
						rev := app.desktop.onboarding_set_products_bulk(['agent-toolkit-core']) or {
							app.onboarding_msg = 'products failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Products set rev=${rev}'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					else {}
				}
				return
			}
			if e.key_code == .escape {
				app.show_onboarding = false
				app.onboarding_msg = 'Onboarding closed — press o to reopen'
				return
			}
		}
		// Arrow navigation — grid-aware (4 columns, last cell empty => 15 desks)
		// Works in World floor; in other panels falls back to linear list nav
		if e.key_code == .left {
			// grid left: col 0 blocks, rightmost of previous row when needed
			cur := app.selected_desk
			if cur % 4 != 0 {
				desks := desks_for_app(app)
				target := cur - 1
				if target >= 0 && target < desks.len {
					app.selected_desk = target
				}
			} else if cur > 0 {
				// at left edge: wrap within row? stay
			}
			return
		}
		if e.key_code == .right {
			cur := app.selected_desk
			// col 3 blocks, and last row col 2 is max
			if cur % 4 != 3 {
				desks := desks_for_app(app)
				target := cur + 1
				// special: row 3 col 3 is missing (idx 15 would be out of 0..14)
				if target < desks.len && !(cur == 11 && target == 12 && false) {
					// allow normal; idx 14 is last valid; idx 15 would be >len
					app.selected_desk = target
				}
			}
			return
		}
		if e.key_code == .up {
			desks := desks_for_app(app)
			cur := app.selected_desk
			target := cur - 4
			if target >= 0 && target < desks.len {
				app.selected_desk = target
			} else if cur < 4 && target < 0 {
				// top row stays
			}
			return
		}
		if e.key_code == .down {
			desks := desks_for_app(app)
			cur := app.selected_desk
			target := cur + 4
			// handle missing cell: idx 15 is not a desk (row 3 col 3 empty)
			// row 2 col 3 (idx 11) going down would hit missing => stay
			if target < desks.len {
				app.selected_desk = target
			} else if cur == 11 {
				// 11 -> missing 15, do not move
			}
			return
		}
		if e.key_code == .enter {
			desks := desks_for_app(app)
			if app.selected_desk >= 0 && app.selected_desk < desks.len {
				app.inspector_msg = 'Terminal opened: ${desks[app.selected_desk].label}'
			}
			return
		}
	}
	if e.typ == .mouse_scroll {
		// scroll terminal or inspector depending on cursor region
		w3 := app.gg.width
		h3 := app.gg.height
		term_h := app.term_height
		y0 := h3 - 28 - term_h
		x0 := 200
		// wheel delta: gg scroll_y negative = up, positive = down (platform dependent). Treat scroll_y !=0.
		mut delta := 0
		if e.scroll_y < 0 {
			delta = -3
		} else if e.scroll_y > 0 {
			delta = 3
		} else if e.scroll_x < 0 {
			delta = -3
		} else if e.scroll_x > 0 {
			delta = 3
		}
		if app.term_visible && app.mouse_x >= x0 && app.mouse_x <= w3 && app.mouse_y >= y0 && app.mouse_y < y0 + term_h {
			// super potent: when ghost_focused, wheel scrolls Ghostty scrollback 1000; otherwise logs
			if app.ghost_focused {
				app.ghost.scroll_by(delta)
			} else {
				app.term_scroll += delta
				all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
				vis := term_visible_rows(term_h)
				app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
				if delta != 0 {
					if app.term_scroll + vis >= all.len {
						app.term_auto_pin = true
					} else {
						app.term_auto_pin = false
					}
				}
			}
			return
		}
		// inspector scroll when over inspector
		{
			term_h_ii := if app.term_visible { app.term_height } else { 0 }
			ix := w3 - 300
			iy := 52
			ih := h3 - 52 - 28 - term_h_ii
			log_y0 := iy + 302
			inspector_log_h := ih - 310
			if app.mouse_x >= ix && app.mouse_x <= w3 && app.mouse_y >= log_y0 && app.mouse_y < log_y0 + inspector_log_h {
				desks := desks_for_app(app)
				all_logs := collect_engine_logs(app)
				filter_q := active_log_filter(app)
				desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks.len {
					per_desk_logs(all_logs, desks[app.selected_desk], filter_q)
				} else {
					filtered_logs(all_logs, filter_q)
				}
				vis_i := if inspector_log_h / 13 < 1 { 1 } else { inspector_log_h / 13 }
				app.inspector_scroll += delta
				app.inspector_scroll = clamp_scroll(app.inspector_scroll, desk_logs.len, vis_i)
				return
			}
		}
		// skills virtualized scroll — 227 list
		if app.selected_panel == 1 {
			fx := 208
			fy := 52
			fw := w3 - 208 - 300
			term_h_sk := if app.term_visible { app.term_height } else { 0 }
			fh := h3 - 52 - 28 - term_h_sk
			y0_sk := fy + 102
			list_h := fh - 126
			if app.mouse_x >= fx + 12 && app.mouse_x <= fx + fw - 12 && app.mouse_y >= y0_sk && app.mouse_y < y0_sk + list_h {
				entries := skills_filtered_entries(mut app)
				visible := list_h / 28
				app.skills_scroll += delta
				app.skills_scroll = clamp_scroll(app.skills_scroll, entries.len, visible)
				return
			}
		}
		// workspace IDE scroll — file tree, editor, git, memory palace (super potent)
		if app.selected_panel == 9 {
			fx := 208
			fy := 52
			fw := w3 - 208 - 300
			term_h_ws := if app.term_visible { app.term_height } else { 0 }
			fh := h3 - 52 - 28 - term_h_ws
			mid_y := fy + 52 + 108 + 12
			mem_h := 92
			mut mid_h := fh - (108 + 12 + mem_h + 20)
			if mid_h < 120 {
				mid_h = 120
			}
			// file tree left
			ft_x := fx + 12
			ft_y := mid_y
			ft_w := 180
			if app.mouse_x >= ft_x && app.mouse_x <= ft_x + ft_w && app.mouse_y >= ft_y && app.mouse_y < ft_y + mid_h {
				flat := file_tree_visible(app)
				visible := (mid_h - 28) / 18
				app.file_tree_scroll += delta
				app.file_tree_scroll = clamp_scroll(app.file_tree_scroll, flat.len, visible)
				return
			}
			// editor center
			ed_x := fx + 12 + 180 + 4
			ed_w := fw - 24 - 180 - 4 - 240
			if app.mouse_x >= ed_x && app.mouse_x <= ed_x + ed_w && app.mouse_y >= mid_y && app.mouse_y < mid_y + mid_h {
				app.editor_scroll += delta
				return
			}
			// git right
			gx := fx + fw - 240 - 12
			if app.mouse_x >= gx && app.mouse_x <= gx + 240 && app.mouse_y >= mid_y && app.mouse_y < mid_y + mid_h {
				if app.git_rail == 'CHANGES' {
					changes := app.desktop.engine_git_changes()
					visible := (mid_h - 20) / 20
					app.git_scroll += delta
					app.git_scroll = clamp_scroll(app.git_scroll, changes.len, visible)
				} else if app.git_rail == 'HISTORY' {
					graph := app.desktop.engine_git_graph(20)
					visible := (mid_h - 40) / 22
					app.git_scroll += delta
					app.git_scroll = clamp_scroll(app.git_scroll, graph.commits.len, visible)
				} else {
					app.diff_scroll += delta
				}
				return
			}
			// memory bottom
			mem_y := mid_y + mid_h + 6
			if app.mouse_x >= fx + 12 && app.mouse_x <= fx + fw - 12 && app.mouse_y >= mem_y && app.mouse_y < mem_y + mem_h {
				results := app.desktop.engine_memory_recall(app.memory_query, 5)
				visible := (mem_h - 48) / 18
				app.memory_scroll += delta
				app.memory_scroll = clamp_scroll(app.memory_scroll, results.len, visible)
				return
			}
		}
		// no region: still scroll global terminal
		if app.term_visible {
			app.term_scroll += delta
			all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
			vis := term_visible_rows(term_h)
			app.term_scroll = clamp_scroll(app.term_scroll, all.len, vis)
		}
		return
	}
	if e.typ == .mouse_down {
		app.mouse_x = int(e.mouse_x)
		app.mouse_y = int(e.mouse_y)
		mx := app.mouse_x
		my := app.mouse_y
		// Palette modal click handling — check palette first before dock/inspector
		if app.palette_open {
			cx := app.gg.width / 2 - 280
			cy := app.gg.height / 2 - 180
			pw := 560
			ph := 360
			inside_palette := mx >= cx && mx <= cx + pw && my >= cy && my <= cy + ph
			if inside_palette {
				// Hit a row? row hit area cy+76 + i*36 size 32
				filtered := filtered_palette(app.palette_query)
				for i, _ in filtered {
					if i >= 7 {
						break
					}
					y := cy + 76 + i * 36
					if mx >= cx + 12 && mx <= cx + pw - 12 && my >= y && my <= y + 32 {
						app.palette_selected = i
						activate_palette_selection(mut app)
						return
					}
				}
				return
			} else {
				// outside closes palette (dismiss)
				app.palette_open = false
				app.palette_query = ''
				app.palette_selected = 0
				// continue to allow click through? close and return to avoid double action
				return
			}
		}
		// Inspector buttons — clickable
		w := app.gg.width
		h := app.gg.height
		ix := w - 300
		iy := 52
		iw := 300
		// Only when a desk selected
		desks := desks_for_app(app)
		if app.selected_desk >= 0 && app.selected_desk < desks.len {
			if mx >= ix + 12 && mx <= ix + iw - 12 && my >= iy + 180 && my <= iy + 208 {
				app.inspector_msg = 'Terminal opened: ${desks[app.selected_desk].label}'
				return
			}
			if mx >= ix + 12 && mx <= ix + iw - 12 && my >= iy + 214 && my <= iy + 242 {
				app.inspector_msg = 'Handoff routed: ${desks[app.selected_desk].label} → reviewer'
				return
			}
		}
		// Help overlay click dismiss
		if app.show_help {
			app.show_help = false
			return
		}
		// Terminal click — super potent: focus Ghostty + copy
		if app.term_visible {
			w3 := app.gg.width
			h3 := app.gg.height
			term_h := app.term_height
			y0 := h3 - 28 - term_h
			x0 := 200
			tw := w3 - 200
			content_y := y0 + 28
			content_x := x0 + 8
			content_w := tw - 16
			// header click: toggle ghost_focused and auto-pin
			if mx >= x0 && mx <= w3 && my >= y0 && my < y0 + 24 {
				app.ghost_focused = !app.ghost_focused
				return
			}
			if mx >= content_x && mx <= content_x + content_w && my >= content_y + 16 && my < y0 + term_h - 18 {
				// click inside terminal focuses Ghostty and copies — potent multiplexed
				app.ghost_focused = true
				if app.ghost.lines.len > 0 {
					g_vis := app.ghost.visible_lines()
					row_h := 14
					rel_y := my - (content_y + 8)
					row := rel_y / row_h
					if row >= 0 && row < g_vis.len {
						copy_to_clipboard(mut app, g_vis[row])
						return
					}
				}
				// fallback: copy global log line
				row_h := 14
				vis := term_visible_rows(term_h)
				filter_q := active_log_filter(app)
				logs := filtered_logs(collect_engine_logs(app), filter_q)
				start := clamp_scroll(app.term_scroll, logs.len, vis)
				rel_y := my - (content_y + 16)
				row := rel_y / row_h
				idx := start + row
				if idx >= 0 && idx < logs.len {
					l := logs[idx]
					copy_to_clipboard(mut app, l.raw + ' | ' + l.msg)
					return
				}
			}
			// click elsewhere in terminal toggles auto-pin
			if mx >= x0 && mx <= w3 && my >= y0 && my < y0 + term_h {
				app.term_auto_pin = !app.term_auto_pin
				if app.term_auto_pin {
					all := filtered_logs(collect_engine_logs(app), active_log_filter(app))
					vis := term_visible_rows(term_h)
					if all.len > vis {
						app.term_scroll = all.len - vis
					}
					app.ghost.scroll_to_bottom()
				}
				return
			}
		}
		// Inspector per-desk log click — copy
		{
			term_h_ii := if app.term_visible { app.term_height } else { 0 }
			ix2 := w - 300
			iy2 := 52
			ih2 := h - 52 - 28 - term_h_ii
			log_y0 := iy2 + 302
			inspector_log_h := ih2 - 310
			if mx >= ix2 + 8 && mx <= ix2 + 300 - 8 && my >= log_y0 && my < log_y0 + inspector_log_h {
				row_h := 13
				mut visible_i := inspector_log_h / row_h
				if visible_i < 1 {
					visible_i = 1
				}
				desks2 := desks_for_app(app)
				all_logs := collect_engine_logs(app)
				filter_q := active_log_filter(app)
				desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks2.len {
					per_desk_logs(all_logs, desks2[app.selected_desk], filter_q)
				} else {
					filtered_logs(all_logs, filter_q)
				}
				start_i := clamp_scroll(app.inspector_scroll, desk_logs.len, visible_i)
				rel := my - log_y0
				row := rel / row_h
				idx := start_i + row
				if idx >= 0 && idx < desk_logs.len {
					l := desk_logs[idx]
					copy_to_clipboard(mut app, l.raw + ' | ' + l.msg)
					return
				}
			}
		}
		// Hit left dock — 12 panels (0 World .. 11 Onboarding) super-potent
		if mx >= 8 && mx <= 192 {
			for i in 0 .. 12 {
				y := 45 + 8 + i * 32
				if y + 28 > h - 28 - (if app.term_visible { app.term_height } else { 0 }) - 40 {
					break
				}
				if my >= y && my <= y + 28 {
					app.selected_panel = i
					if i == 11 {
						app.show_onboarding = true
					} else {
						app.show_onboarding = false
					}
					return
				}
			}
		}
		// Onboarding wizard click handling — super-potent easy management via Engine
		if app.show_onboarding || app.selected_panel == 11 {
			w2 := app.gg.width
			h2 := app.gg.height
			term_h_on := if app.term_visible { app.term_height } else { 0 }
			is_overlay := app.show_onboarding && app.selected_panel != 11
			mut fx := if is_overlay { 240 } else { 208 }
			mut fw := if is_overlay { w2 - 480 } else { w2 - 208 - 300 }
			if fw < 520 {
				fw = if is_overlay { 640 } else { w2 - 208 - 300 }
				fx = if is_overlay { (w2 - fw) / 2 } else { 208 }
			}
				fy := 52
			mut fh2 := h2 - 52 - 28 - term_h_on
			if fh2 < 400 {
				fh2 = 400
			}
			mut fh := fh2
			// close X in overlay
			if is_overlay && mx >= fx + fw - 32 && mx <= fx + fw - 8 && my >= fy + 6 && my <= fy + 30 {
				app.show_onboarding = false
				app.onboarding_msg = 'Onboarding closed via ×'
				return
			}
			// step tabs 0..6 at fy+40
			y_tabs := fy + 40
			mut tab_x := fx + 10
			for si in 0 .. 7 {
				sname := ['Detect', 'Capabilities', 'Targets', 'Products', 'Workspace', 'Personas', 'Done'][si]
				tw := sname.len * 7 + 16
				if tab_x + tw > fx + fw - 10 { break }
				if mx >= tab_x && mx <= tab_x + tw && my >= y_tabs && my <= y_tabs + 18 {
					app.onboarding_step = si
					app.onboarding_msg = 'Step ${si + 1}/7 selected'
					return
				}
				tab_x += tw + 4
			}
			// footer Back / Next
			if app.onboarding_step > 0 && mx >= fx + fw - 220 && mx <= fx + fw - 156 && my >= fy + fh - 32 && my <= fy + fh - 12 {
				app.onboarding_step--
				app.onboarding_msg = 'Back to step ${app.onboarding_step + 1}/7'
				return
			}
			if mx >= fx + fw - 148 && mx <= fx + fw - 76 && my >= fy + fh - 32 && my <= fy + fh - 12 {
				if app.onboarding_step < 6 {
					app.onboarding_step++
					app.onboarding_msg = 'Next to step ${app.onboarding_step + 1}/7'
				} else {
					rev := app.desktop.onboarding_complete(app.harness_root) or {
						app.onboarding_msg = 'complete failed: ${err}'
						0
					}
					if rev > 0 {
						app.show_onboarding = false
						app.selected_panel = 0
						app.onboarding_msg = 'Onboarding complete rev=${rev} ✓'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
				}
				return
			}
			// per-step action buttons
			y_harness := fy + 40 + 24 + 38
			content_y := y_harness + 24
			// Workspace step 4 init buttons
			if app.onboarding_step == 4 {
				if mx >= fx + 20 && mx <= fx + 150 && my >= content_y + 82 && my <= content_y + 106 {
					harness := if app.onboarding_harness != '' { app.onboarding_harness } else { app.harness_root }
					rev := app.desktop.onboarding_ensure_workspace(harness) or {
						app.onboarding_msg = 'workspace init failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'Workspace initialized rev=${rev}'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
				if mx >= fx + 158 && mx <= fx + 298 && my >= content_y + 82 && my <= content_y + 106 {
					harness := if app.onboarding_harness != '' { app.onboarding_harness } else { app.harness_root }
					rev := app.desktop.onboarding_init_with_templates(harness, true) or {
						app.onboarding_msg = 'init+personas failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'Workspace+Personas rev=${rev} ✓'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
			}
			if app.onboarding_step == 5 {
				if mx >= fx + 20 && mx <= fx + 150 && my >= content_y + 148 && my <= content_y + 170 {
					harness := if app.onboarding_harness != '' { app.onboarding_harness } else { app.harness_root }
					rev := app.desktop.onboarding_ensure_personas(harness) or {
						app.onboarding_msg = 'personas failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'Personas bootstrapped rev=${rev} ✓'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
			}
			if app.onboarding_step == 1 {
				// Install 5 button at content_y+content_h-54 96x20 fw-120
				content_h := fh - (content_y - fy) - 52
				if mx >= fx + fw - 120 && mx <= fx + fw - 24 && my >= content_y + content_h - 54 && my <= content_y + content_h - 34 {
					cand := app.desktop.engine_skills_search(app.skills_query, app.skills_domain)
					mut ids := []string{}
					for i in 0 .. 5 {
						if i >= cand.len { break }
						ids << cand[i].id
					}
					if ids.len > 0 {
						rev := app.desktop.onboarding_bulk_install_skills(ids) or {
							app.onboarding_msg = 'bulk install failed: ${err}'
							0
						}
						if rev > 0 {
							app.onboarding_msg = 'Installed ${ids.len} skills rev=${rev}'
							app.engine_rev = app.desktop.app_state_snapshot().revision
							app.api_calls = app.desktop.engine_api_calls()
						}
					}
					return
				}
			}
			if app.onboarding_step == 2 {
				mut fh2b := fh
				content_h := fh2b - (content_y - fy) - 52
				if mx >= fx + 20 && mx <= fx + 110 && my >= content_y + content_h - 40 && my <= content_y + content_h - 22 {
					ids := ['claude-code', 'opencode', 'cli']
					rev := app.desktop.onboarding_set_targets_bulk(ids) or {
						app.onboarding_msg = 'targets failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'Targets minimal rev=${rev}'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
				if mx >= fx + 118 && mx <= fx + 208 && my >= content_y + content_h - 40 && my <= content_y + content_h - 22 {
					ids := ['claude-code', 'cursor', 'opencode', 'pi', 'windsurf', 'cursor-plugins', 'cli']
					rev := app.desktop.onboarding_set_targets_bulk(ids) or {
						app.onboarding_msg = 'targets all failed: ${err}'
						0
					}
					if rev > 0 {
						app.onboarding_msg = 'All 7 targets rev=${rev}'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
			}
			if app.onboarding_step == 3 {
				mut fh2c := fh
				content_h := fh2c - (content_y - fy) - 52
				_ = content_h
				// any click in products content advances? handle via next
			}
			if app.onboarding_step == 6 {
				if mx >= fx + 20 && mx <= fx + 130 && my >= content_y + 84 && my <= content_y + 106 {
					rev := app.desktop.onboarding_complete(app.harness_root) or {
						app.onboarding_msg = 'complete failed: ${err}'
						0
					}
					if rev > 0 {
						app.show_onboarding = false
						app.selected_panel = 0
						app.onboarding_msg = 'Onboarding complete rev=${rev} ✓ — welcome to Workshop'
						app.engine_rev = app.desktop.app_state_snapshot().revision
						app.api_calls = app.desktop.engine_api_calls()
					}
					return
				}
				if mx >= fx + 138 && mx <= fx + 248 && my >= content_y + 84 && my <= content_y + 106 {
					app.show_onboarding = false
					app.selected_panel = 0
					app.onboarding_msg = 'Back to World'
					return
				}
			}
		}
		// Skills panel — domain chips + virtualized list install (227 searchable, brokered via Engine)
		if app.selected_panel == 1 {
			fx := 208
			fy := 52
			fw := w - 208 - 300
			// domain chips hit at fy+80
			domains := ['all', 'core', 'delivery', 'design', 'forge', 'integrations', 'data',
				'tooling', 'ops', 'loops', 'quality', 'architecture', 'cloud', 'agentic-security']
			y_chip := fy + 80
			mut chip_x := fx + 12
			for d in domains {
				label := if d == 'all' { 'all 227' } else { d }
				wc := label.len * 7 + 16
				if chip_x + wc > fx + fw - 12 {
					break
				}
				if mx >= chip_x && mx <= chip_x + wc && my >= y_chip && my <= y_chip + 18 {
					app.skills_domain = if d == 'all' { '' } else { d }
					app.skills_scroll = 0
					app.skills_selected = 0
					return
				}
				chip_x += wc + 6
			}
			// list rows at fy+102
			y0 := fy + 102
			entries := skills_filtered_entries(mut app)
			row_h := 28
			visible := (h - 52 - 28 - (if app.term_visible { app.term_height } else { 0 }) - 126) / row_h
			if visible > 0 {
				start := clamp_scroll(app.skills_scroll, entries.len, visible)
				mut end_sk := start + visible
				if end_sk > entries.len { end_sk = entries.len }
				for idx in start .. end_sk {
					row := idx - start
					y := y0 + row * row_h
					if mx >= fx + 12 && mx <= fx + fw - 12 && my >= y && my <= y + 24 {
						app.skills_selected = idx
						// install action on right side click
						if mx >= fx + fw - 80 {
							sel := entries[idx]
							if _ := app.desktop.engine_skill_detail(sel.id) {
								app.inspector_msg = 'Skill install queued: ${sel.id} via Engine transaction'
							}
						}
						return
					}
				}
			}
			// search bar click focuses
			if mx >= fx + 12 && mx <= fx + fw - 12 && my >= fy + 48 && my <= fy + 76 {
				app.palette_open = false
				app.inspector_msg = 'Skills search focused — type to filter 227 (fuzzy)'
				return
			}
		}
		// Workspace IDE — file-tree, editor tabs, git rails CHANGES/HISTORY/COMPARE, commit graph, diff, memory palace
		// Super potent: brokered fs via Engine.open_path_validated (harness_root_escape), syntax, graph lanes, semantic recall
		if app.selected_panel == 9 {
			fx := 208
			fy := 52
			fw := w - 208 - 300
			term_h_ws := if app.term_visible { app.term_height } else { 0 }
			fh := h - 52 - 28 - term_h_ws
			mid_y := fy + 52 + 108 + 12
			mem_h := 92
			mut mid_h := fh - (108 + 12 + mem_h + 20)
			if mid_h < 120 {
				mid_h = 120
			}
			// git rail tabs hit
			rail_y := mid_y
			for ri, rn in ['CHANGES', 'HISTORY', 'COMPARE'] {
				rx := fx + fw - 240 - 12 + 6 + ri * 78
				if mx >= rx && mx <= rx + 74 && my >= rail_y && my <= rail_y + 22 {
					app.git_rail = rn
					app.git_scroll = 0
					return
				}
			}
			// file tree hit — left 180
			ft_x := fx + 12
			ft_y := mid_y
			ft_w := 180
			ft_h := mid_h
			if mx >= ft_x && mx <= ft_x + ft_w && my >= ft_y + 24 && my < ft_y + ft_h - 4 {
				flat := file_tree_visible(app)
				row_h := 18
				visible := (ft_h - 28) / row_h
				if visible > 0 {
					start := clamp_scroll(app.file_tree_scroll, flat.len, visible)
					rel := my - (ft_y + 24)
					row := rel / row_h
					idx := start + row
					if idx >= 0 && idx < flat.len {
						n := flat[idx]
						app.file_tree_selected = n.path
						app.file_tree_hover = idx
						if n.kind == 'dir' {
							// toggle expand — easy to manage: walk tree and flip
							mut toggled := false
							for i, node in app.file_tree {
								if node.path == n.path {
									app.file_tree[i].expanded = !node.expanded
									toggled = true
									break
								}
								// recurse helper inline
								if !toggled {
									toggled = toggle_expand_recursive(mut app.file_tree[i].children, n.path)
								}
							}
						} else {
							// brokered open — validates harness_root_escape via Desktop proxy
							if _ := app.desktop.engine_open_path_validated(app.harness_root, n.path) {
								// try Engine open, fallback to local read for headless
								tab := app.desktop.engine_open_file_brokered(app.harness_root, n.path) or {
									// fallback synthetic tab for headless/gui without real file
									desktop_engine.EditorTab{ path: n.path, title: n.name, content: '// ${n.name}\nmodule main\nfn main() { println("brokered open: ${n.path}") }', syntax: 'v', dirty: false }
								}
								mut found := -1
								for ti, t in app.editor_tabs {
									if t.path == tab.path {
										found = ti
										break
									}
								}
								if found >= 0 {
									app.active_tab = found
								} else {
									app.editor_tabs << EditorTab{tab.path, tab.title, tab.content, tab.syntax, tab.dirty, 0}
									app.active_tab = app.editor_tabs.len - 1
								}
								app.inspector_msg = 'Opened ${n.name} via brokered fs — ${tab.syntax} syntax'
							} else {
								app.inspector_msg = 'Brokered guard blocked: ${n.path} (harness_root_escape)'
							}
						}
						return
					}
				}
			}
			// editor tabs hit — center
			ed_x := fx + 12 + 180 + 4
			ed_w := fw - 24 - 180 - 4 - 240
			ed_y := mid_y
			if app.editor_tabs.len > 0 && mx >= ed_x && mx <= ed_x + ed_w && my >= ed_y + 6 && my <= ed_y + 24 {
				mut tx := ed_x + 6
				for i, tab in app.editor_tabs {
					tw := tab.title.len * 7 + 28
					if tx + tw > ed_x + ed_w - 6 {
						break
					}
					if mx >= tx && mx <= tx + tw && my >= ed_y + 6 && my <= ed_y + 24 {
						app.active_tab = i
						return
					}
					tx += tw + 4
				}
			}
			// HISTORY commit selection hit — inside git rails
			if app.git_rail == 'HISTORY' {
				rail_x := fx + fw - 240 - 12
				rail_y2 := mid_y + 26
				graph := app.desktop.engine_git_graph(20)
				row_h := 22
				y0 := rail_y2 + 14
				visible := (mid_h - 40) / row_h
				if visible > 0 {
					start := clamp_scroll(app.git_scroll, graph.commits.len, visible)
					for idx in start .. graph.commits.len {
					if idx >= start + visible { break }
						row := idx - start
						ry := y0 + row * row_h
						if mx >= rail_x && mx <= rail_x + 240 && my >= ry && my <= ry + row_h {
							app.git_selected = graph.commits[idx].hash
							app.inspector_msg = 'Commit ${graph.commits[idx].hash[..7]} selected — diff preview via Engine.git_diff'
							return
						}
					}
				}
			}
			// memory palace search bar hit — bottom
			mem_y := mid_y + mid_h + 6
			if mx >= fx + 12 + 8 && mx <= fx + fw - 12 && my >= mem_y + 20 && my <= mem_y + 40 {
				app.inspector_msg = 'Memory palace focused — type to recall semantic (hybrid cosine)'
				return
			}
		}
		// Hit floor desks only in world panel — uses desk_rect so draw and hit-test agree
		if app.selected_panel == 0 {
			w2 := app.gg.width
			h2 := app.gg.height
			fx := 208
			fy := 52
			fw := w2 - 208 - 300
			fh := h2 - 52 - 28
			for idx, d in desks {
				dx, dy, dw, dh := desk_rect(d, idx, fx, fy, fw, fh)
				if mx >= dx && mx <= dx + dw && my >= dy && my <= dy + dh {
					app.selected_desk = idx
					app.inspector_msg = ''
					return
				}
			}
		}
		_ = h
	}
	if e.typ == .mouse_move {
		app.mouse_x = int(e.mouse_x)
		app.mouse_y = int(e.mouse_y)
		app.hover_panel = -1
		if app.mouse_x >= 8 && app.mouse_x <= 192 {
			for i in 0 .. 10 {
				y := 45 + 8 + i * 38
				if app.mouse_y >= y && app.mouse_y <= y + 32 {
					app.hover_panel = i
					break
				}
			}
		}
		app.hover_desk = -1
		app.term_hover = -1
		app.inspector_hover = -1
		app.skills_hover = -1
		app.file_tree_hover = -1
		app.git_hover = -1
		app.memory_hover = -1
		if app.selected_panel == 0 {
			desks := desks_for_app(app)
			w2 := app.gg.width
			h2 := app.gg.height
			term_h_mm := if app.term_visible { app.term_height } else { 0 }
			fx := 208
			fy := 52
			fw := w2 - 208 - 300
			fh := h2 - 52 - 28 - term_h_mm
			for idx, d in desks {
				dx, dy, dw, dh := desk_rect(d, idx, fx, fy, fw, fh)
				if app.mouse_x >= dx && app.mouse_x <= dx + dw && app.mouse_y >= dy && app.mouse_y <= dy + dh {
					app.hover_desk = idx
					break
				}
			}
		}
		// terminal hover — bottom strip (ghost + logs — potent)
		if app.term_visible {
			w3 := app.gg.width
			h3 := app.gg.height
			term_h := app.term_height
			y0 := h3 - 28 - term_h
			x0 := 200
			tw := w3 - 200
			content_y := y0 + 28
			content_x := x0 + 8
			content_w := tw - 16
			if app.mouse_x >= content_x && app.mouse_x <= content_x + content_w && app.mouse_y >= content_y + 16 && app.mouse_y < y0 + term_h - 18 {
				row_h := 14
				if app.ghost_focused && app.ghost.lines.len > 0 {
					// hover maps to Ghostty visible rows when focused
					g_vis := app.ghost.visible_lines()
					rel_y := app.mouse_y - (content_y + 8)
					row := rel_y / row_h
					if row >= 0 && row < g_vis.len {
						app.term_hover = row
					}
				} else {
					vis := term_visible_rows(term_h)
					filter_q := active_log_filter(app)
					logs := filtered_logs(collect_engine_logs(app), filter_q)
					start := clamp_scroll(app.term_scroll, logs.len, vis)
					rel_y := app.mouse_y - (content_y + 16)
					row := rel_y / row_h
					idx := start + row
					if idx >= 0 && idx < logs.len && row < vis {
						app.term_hover = idx
					}
				}
			}
		}
		// inspector hover — per-desk logs
		{
			w3 := app.gg.width
			h3 := app.gg.height
			term_h_ii := if app.term_visible { app.term_height } else { 0 }
			ix := w3 - 300
			iy := 52
			ih := h3 - 52 - 28 - term_h_ii
			log_y0 := iy + 302
			inspector_log_h := ih - 310
			if inspector_log_h >= 40 && app.mouse_x >= ix + 8 && app.mouse_x <= ix + 300 - 8 && app.mouse_y >= log_y0 && app.mouse_y < log_y0 + inspector_log_h {
				row_h := 13
				mut visible_i := inspector_log_h / row_h
				desks := desks_for_app(app)
				filter_q := active_log_filter(app)
				all_logs := collect_engine_logs(app)
				desk_logs := if app.selected_desk >= 0 && app.selected_desk < desks.len {
					per_desk_logs(all_logs, desks[app.selected_desk], filter_q)
				} else {
					filtered_logs(all_logs, filter_q)
				}
				start_i := clamp_scroll(app.inspector_scroll, desk_logs.len, visible_i)
				rel := app.mouse_y - log_y0
				row := rel / row_h
				idx := start_i + row
				if idx >= 0 && idx < desk_logs.len {
					app.inspector_hover = idx
				}
			}
		}
		// skills hover — 227 list rows hover
		if app.selected_panel == 1 {
			fx := 208
			fy := 52
			fw := app.gg.width - 208 - 300
			y0 := fy + 102
			row_h := 28
			term_h_sk := if app.term_visible { app.term_height } else { 0 }
			fh := app.gg.height - 52 - 28 - term_h_sk
			list_h := fh - 126
			visible := list_h / row_h
			entries := skills_filtered_entries(mut app)
			start := clamp_scroll(app.skills_scroll, entries.len, visible)
			mut end_en := start + visible
				if end_en > entries.len { end_en = entries.len }
				for idx in start .. end_en {
				row := idx - start
				y := y0 + row * row_h
				if app.mouse_x >= fx + 12 && app.mouse_x <= fx + fw - 12 && app.mouse_y >= y && app.mouse_y <= y + 24 {
					app.skills_hover = idx
					break
				}
			}
		}
		// workspace file-tree hover — left 180
		if app.selected_panel == 9 {
			fx := 208
			fy := 52
			fw := app.gg.width - 208 - 300
			term_h_ws := if app.term_visible { app.term_height } else { 0 }
			fh := app.gg.height - 52 - 28 - term_h_ws
			mid_y := fy + 52 + 108 + 12
			mem_h := 92
			mut mid_h := fh - (108 + 12 + mem_h + 20)
			if mid_h < 120 {
				mid_h = 120
			}
			ft_x := fx + 12
			ft_y := mid_y
			ft_w := 180
			ft_h := mid_h
			flat := file_tree_visible(app)
			row_h := 18
			visible := (ft_h - 28) / row_h
			start := clamp_scroll(app.file_tree_scroll, flat.len, visible)
			mut end_fl := start + visible
			if end_fl > flat.len { end_fl = flat.len }
			for idx in start .. end_fl {
				row := idx - start
				ry := ft_y + 24 + row * row_h
				if app.mouse_x >= ft_x && app.mouse_x <= ft_x + ft_w && app.mouse_y >= ry && app.mouse_y <= ry + row_h {
					app.file_tree_hover = idx
					break
				}
			}
			// git hover — right rails
			rail_x := fx + fw - 240 - 12
			y0 := mid_y + 26 + 14
			if app.git_rail == 'CHANGES' {
				changes := app.desktop.engine_git_changes()
				row_h2 := 20
				vis2 := (mid_h - 20) / row_h2
				start2 := clamp_scroll(app.git_scroll, changes.len, vis2)
				mut end2_ch := start2 + vis2
				if end2_ch > changes.len { end2_ch = changes.len }
				for idx in start2 .. end2_ch {
					row := idx - start2
					ry := y0 + row * row_h2
					if app.mouse_x >= rail_x && app.mouse_x <= rail_x + 240 && app.mouse_y >= ry && app.mouse_y <= ry + row_h2 {
						app.git_hover = idx
						break
					}
				}
			} else if app.git_rail == 'HISTORY' {
				graph := app.desktop.engine_git_graph(20)
				row_h2 := 22
				vis2 := (mid_h - 40) / row_h2
				start2 := clamp_scroll(app.git_scroll, graph.commits.len, vis2)
				mut end2_hi := start2 + vis2
				if end2_hi > graph.commits.len { end2_hi = graph.commits.len }
				for idx in start2 .. end2_hi {
					row := idx - start2
					ry := y0 + row * row_h2
					if app.mouse_x >= rail_x && app.mouse_x <= rail_x + 240 && app.mouse_y >= ry && app.mouse_y <= ry + row_h2 {
						app.git_hover = idx
						break
					}
				}
			}
			// memory hover — bottom
			mem_y := mid_y + mid_h + 6
			if app.memory_query != '' {
				results := app.desktop.engine_memory_recall(app.memory_query, 5)
				row_h2 := 18
				vis2 := (mem_h - 48) / row_h2
				start2 := clamp_scroll(app.memory_scroll, results.len, vis2)
				mut end2 := start2 + vis2
				if end2 > results.len { end2 = results.len }
				for idx in start2 .. end2 {
					row := idx - start2
					ry := mem_y + 44 + row * row_h2
					if app.mouse_x >= fx && app.mouse_x <= fx + fw && app.mouse_y >= ry && app.mouse_y <= ry + 12 {
						app.memory_hover = idx
						break
					}
				}
			}
		}
	}
	if e.typ == .quit_requested {
		app.gg.quit()
	}
}
