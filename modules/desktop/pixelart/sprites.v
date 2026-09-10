module pixelart

// Product/domain sprite grids — authored as readable text rows of palette
// keys. A row of '.' is transparent. Every sprite documents its logical
// pixel size; the renderer scales by integer factors with nearest-neighbor
// semantics (via pre-expanded RGBA), keeping pixels crisp.

// AgentVisualState — the truthful runtime state that selects the avatar
// variant. Catalog/idle agents are never rendered as running.
pub enum AgentVisualState {
	idle
	running
	waiting
	attention
	error
}

// EnvironmentAsset — office furniture and operational props.
pub enum EnvironmentAsset {
	desk
	chair
	terminal
	shelf
	plant
	lamp
	cabinet
	rug
	meeting_table
	board
	tray
	window
	door
	couch
	nest
	welcome_desk
	sign
	books
	picture
	bookshelf_wide
	globe
	scroll
	chalkboard
	ladder
	// Operations props and marks — see operations_sprites.v
	server_rack
	wall_clock
	gear_mark
	monitor_tower
	checklist_board
	play_mark
	calendar_mark
	swarm_mark
	alert_mark
	cabinet_tall
	folder_stack
	ledger
	chart_mark
	gear
}

// Sprite is an authored pixel grid with its palette keys.
pub struct Sprite {
pub:
	name  string
	rows  []string // one char per pixel, palette-key or '.'
}

// width/height of the sprite grid.
pub fn (s Sprite) width() int {
	return if s.rows.len > 0 { s.rows[0].len } else { 0 }
}

pub fn (s Sprite) height() int {
	return s.rows.len
}

// validate checks all rows share the same width and use known palette keys.
pub fn (s Sprite) validate(known_keys []u8) []string {
	mut errs := []string{}
	if s.rows.len == 0 {
		errs << '${s.name}: empty grid'
		return errs
	}
	w := s.rows[0].len
	for ri, row in s.rows {
		if row.len != w {
			errs << '${s.name}: row ${ri} width ${row.len} != ${w}'
		}
		for ch in row {
			k := u8(ch)
			if k == `.` {
				continue
			}
			if !(k in known_keys) {
				errs << '${s.name}: row ${ri} has unknown palette key "${ch}"'
				break
			}
		}
	}
	return errs
}

// expand returns the RGBA byte buffer for the sprite at integer scale N
// (nearest-neighbor by construction: each source pixel becomes N×N bytes).
pub fn (s Sprite) expand(p Palette, scale int) []u8 {
	w, h := s.width(), s.height()
	mut out := []u8{len: w * scale * h * scale * 4, cap: w * scale * h * scale * 4}
	for gy in 0 .. h * scale {
		src_y := gy / scale
		row := s.rows[src_y]
		for gx in 0 .. w * scale {
			src_x := gx / scale
			k := u8(row[src_x])
			rgba := p.rgba(k)
			base := (gy * w * scale + gx) * 4
			out[base] = rgba[0]
			out[base + 1] = rgba[1]
			out[base + 2] = rgba[2]
			out[base + 3] = rgba[3]
		}
	}
	return out
}

// ── agent avatar (12×12 logical) — shared anatomy: hair/head/torso/desk edge.
// Variants adjust the posture/head/screen pixels. State semantics come from
// Engine truth; idle agents sit facing the terminal, running agents face the
// screen with an active glow, waiting agents turn toward the inbox.
const agent_idle = Sprite{
	name: 'agent-idle'
	rows: [
		'....hhhh....',
		'...hhhhhh...',
		'...hnnnnh...',
		'...nnnnnn...',
		'....nnnn....',
		'...cccccc...',
		'..cccccccc..',
		'..nccccccn..',
		'..nccccccn..',
		'...cccccc...',
		'...CC..CC...',
		'...CC..CC...',
	]
}

const agent_running = Sprite{
	name: 'agent-running'
	rows: [
		'....hhhh....',
		'...hhhhhh...',
		'...hnnnnh...',
		'...nnsssn...',
		'....nnnn....',
		'...cccccc...',
		'..cccccccc..',
		'..nccccccn..',
		'..nccccccn..',
		'...cccccc...',
		'...CC..CC...',
		'...CC..CC...',
	]
}

const agent_waiting = Sprite{
	name: 'agent-waiting'
	rows: [
		'...hhhh.....',
		'..hhhhhh....',
		'..hnnnnh....',
		'..nnnnnn.r..',
		'...nnnn.....',
		'...cccccc...',
		'..cccccccc..',
		'..nccccccn..',
		'..nccccccn..',
		'...cccccc...',
		'...CC..CC...',
		'...CC..CC...',
	]
}

const agent_attention = Sprite{
	name: 'agent-attention'
	rows: [
		'....hhhh..r.',
		'...hhhhhh.r.',
		'...hnnnnh...',
		'...nnnnnn...',
		'....nnnn....',
		'...cccccc...',
		'..cccccccc..',
		'..nccccccn..',
		'..nccccccn..',
		'...cccccc...',
		'...CC..CC...',
		'...CC..CC...',
	]
}

const agent_error = Sprite{
	name: 'agent-error'
	rows: [
		'..r.hhhh....',
		'....hhhhhh..',
		'..r.hnnnnh..',
		'...nnnnnn...',
		'....nnnn....',
		'...cccccc...',
		'..cccccccc..',
		'..nccccccn..',
		'..nccccccn..',
		'...cccccc...',
		'...CC..CC...',
		'...CC..CC...',
	]
}

// agent_for_state returns the avatar sprite for a truthful visual state.
pub fn agent_for_state(state AgentVisualState) Sprite {
	return match state {
		.idle { agent_idle }
		.running { agent_running }
		.waiting { agent_waiting }
		.attention { agent_attention }
		.error { agent_error }
	}
}

// with_materials returns a variant of s with palette keys remapped
// (from[i] → to[i]); the suffix keeps sprite-cache keys distinct. Used for
// scene-specific material variants (e.g. light-framed shelves on a dark
// wall) without authoring a second grid. Only existing palette keys.
pub fn with_materials(s Sprite, from string, to string, suffix string) Sprite {
	if from.len == 0 || from.len != to.len {
		return s
	}
	mut mapping := map[u8]u8{}
	for i in 0 .. from.len {
		mapping[from[i]] = to[i]
	}
	mut rows := []string{cap: s.rows.len}
	for row in s.rows {
		mut b := []u8{cap: row.len}
		for ch in row {
			k := u8(ch)
			b << if k in mapping { mapping[k] } else { k }
		}
		rows << b.bytestr()
	}
	return Sprite{
		name: s.name + suffix
		rows: rows
	}
}

// with_identity returns a catalog-identity variant of an avatar sprite:
// the shared 12×12 anatomy with deterministic hair/shirt material swaps
// (existing palette keys only, no new colors, no runtime meaning). Variant 0
// is the authored sprite unchanged. The name suffix keeps sprite-cache keys
// distinct per identity.
pub fn with_identity(s Sprite, variant int) Sprite {
	mut mapping := map[u8]u8{}
	mut name_suffix := ''
	if variant == 1 {
		// light-brown hair, sage shirt
		mapping[u8(`h`)] = u8(`m`)
		mapping[u8(`c`)] = u8(`f`)
		mapping[u8(`C`)] = u8(`F`)
		name_suffix = '-id1'
	} else if variant == 2 {
		// dark hair, brass shirt
		mapping[u8(`c`)] = u8(`b`)
		mapping[u8(`C`)] = u8(`B`)
		name_suffix = '-id2'
	} else {
		return s
	}
	mut rows := []string{cap: s.rows.len}
	for row in s.rows {
		mut b := []u8{cap: row.len}
		for ch in row {
			k := u8(ch)
			b << if k in mapping { mapping[k] } else { k }
		}
		rows << b.bytestr()
	}
	return Sprite{
		name: s.name + name_suffix
		rows: rows
	}
}

// ── environment assets ─────────────────────────────────────────────────────

// desk (18×12 logical): wooden top with paper + terminal edge.
const env_desk = Sprite{
	name: 'env-desk'
	rows: [
		'wwwwwwwwwwwwwwwwww',
		'wwwwwwwwwwwwwwwwww',
		'WWWWWWWWWWWWWWWWWW',
		'W..W..........W..W',
		'W..W..........W..W',
		'W..W..........W..W',
		'W..W..........W..W',
		'W..W....mm....W..W',
		'W..W....mm....W..W',
		'WWWWWWWWWWWWWWWWWW',
		'..................',
		'..................',
	]
}

// terminal on desk (10×9): dark screen with glow.
const env_terminal = Sprite{
	name: 'env-terminal'
	rows: [
		'.llllllll.',
		'.lttttttl.',
		'.ltsssstl.',
		'.ltsststl.',
		'.lttttttl.',
		'.llllllll.',
		'...ll.....',
		'.llllllll.',
		'..........',
	]
}

// chair (8×12).
const env_chair = Sprite{
	name: 'env-chair'
	rows: [
		'.WWWWWW.',
		'.W....W.',
		'.W....W.',
		'.WWWWWW.',
		'.W....W.',
		'.W....W.',
		'.W....W.',
		'.W....W.',
		'.WWWWWW.',
		'........',
		'........',
		'........',
	]
}

// bookshelf (14×16): wood frame, shelves with book spines.
const env_shelf = Sprite{
	name: 'env-shelf'
	rows: [
		'.WWWWWWWWWWWW.',
		'.WcrmcfcrcrfW.',
		'.WcrcfmrcfcfW.',
		'.WWWWWWWWWWWW.',
		'.WfcmrcfcmrcW.',
		'.WcmrfcmrfcmW.',
		'.WWWWWWWWWWWW.',
		'.WrcfcmrcfcmrW',
		'.WfmrcfcmrcfcW',
		'.WWWWWWWWWWWW.',
		'.WcmrcfcmrcfcW',
		'.WfcmrcfcmrcfW',
		'.WWWWWWWWWWWW.',
		'.WW........WW.',
		'.WW........WW.',
		'.WWWWWWWWWWWW.',
	]
}

// potted plant (10×14).
const env_plant = Sprite{
	name: 'env-plant'
	rows: [
		'....ff....',
		'..ffFFff..',
		'.fFFffFFf.',
		'.fFffffFf.',
		'..fFffFf..',
		'...ffff...',
		'....ff....',
		'..MMMMMM..',
		'..MmmmmM..',
		'..MmmmmM..',
		'...MmmM...',
		'...MmmM...',
		'..MMMMMM..',
		'..........',
	]
}

// desk lamp (8×12): brass arm + warm head.
const env_lamp = Sprite{
	name: 'env-lamp'
	rows: [
		'..BBBB..',
		'.BBBBBB.',
		'.BeeeBB.',
		'..BBBB..',
		'...ll...',
		'...ll...',
		'....ll..',
		'....ll..',
		'.....ll.',
		'..lllll.',
		'.MMMMMM.',
		'........',
	]
}

// filing cabinet (12×14): steel drawers with handles.
const env_cabinet = Sprite{
	name: 'env-cabinet'
	rows: [
		'.llllllllll.',
		'.lSSSSSSSSl.',
		'.lSSSSeSSSl.',
		'.llllllllll.',
		'.lSSSSSSSSl.',
		'.lSSSeSSSSl.',
		'.llllllllll.',
		'.lSSSSSSSSl.',
		'.lSSSSeSSSl.',
		'.llllllllll.',
		'.lSSSSSSSSl.',
		'.lSSeSSSSSl.',
		'.llllllllll.',
		'.WWWWWWWWWW.',
	]
}

// rug (24×10): warm woven pattern.
const env_rug = Sprite{
	name: 'env-rug'
	rows: [
		'..aaaaaaaaaaaaaaaaaaaa..',
		'.aMMMMMMaaaaaaMMMMMMaa..',
		'aaMbbbbMaaaaaaaaMbbbbMaa',
		'aaMbbbbMaaaaaaaaMbbbbMaa',
		'aaaaaaaaaaaaaaaaaaaaaaaa',
		'aaaaaaaaaaaaaaaaaaaaaaaa',
		'aaMbbbbMaaaaaaaaMbbbbMaa',
		'aaMbbbbMaaaaaaaaMbbbbMaa',
		'.aMMMMMMaaaaaaMMMMMMaa..',
		'..aaaaaaaaaaaaaaaaaaaa..',
	]
}

// meeting table (20×10): wood oval top with legs.
const env_meeting = Sprite{
	name: 'env-meeting'
	rows: [
		'....wwwwwwwwwwww....',
		'..wwwwwwwwwwwwwwww..',
		'.wwwwwwwwwwwwwwwwww.',
		'.wwwwwwwwwwwwwwwwww.',
		'.wwwwwwwwwwwwwwwwww.',
		'..wwwwwwwwwwwwwwww..',
		'....wwwwwwwwwwww....',
		'.....WW......WW.....',
		'.....WW......WW.....',
		'....................',
	]
}

// attention board (16×12): cork board with pinned papers.
const env_board = Sprite{
	name: 'env-board'
	rows: [
		'.WWWWWWWWWWWWWW.',
		'.WmmmmmmmmmmmmW.',
		'.Wm.e...e..e.mW.',
		'.Wm......e....W.',
		'.Wm.e..e.....mW.',
		'.Wm....e..e..mW.',
		'.Wm.e.......emW.',
		'.WmmmmmmmmmmmmW.',
		'.WWWWWWWWWWWWWW.',
		'.W............W.',
		'.WWWWWWWWWWWWWW.',
		'................',
	]
}

// inbox tray (10×8): stacked paper trays.
const env_tray = Sprite{
	name: 'env-tray'
	rows: [
		'.llllllll.',
		'.leeeeel..',
		'.llllllll.',
		'..leeeel..',
		'..llllll..',
		'...leel...',
		'..llllll..',
		'..........',
	]
}

// window (14×12): dark wood frame, sky panes, sill. Wall asset for the
// office room's environmental depth.
const env_window = Sprite{
	name: 'env-window'
	rows: [
		'WWWWWWWWWWWWWW',
		'WssssssssssssW',
		'WssssssssssssW',
		'WssssssssssssW',
		'WWWWWWWWWWWWWW',
		'WssssssssssssW',
		'WssssssssssssW',
		'WssssssssssssW',
		'WWWWWWWWWWWWWW',
		'.WWWWWWWWWWWW.',
		'..............',
		'..............',
	]
}

// door (14×14): manila office door with inner panel and brass knob.
const env_door = Sprite{
	name: 'env-door'
	rows: [
		'WWWWWWWWWWWWWW',
		'WmmmmmmmmmmmmW',
		'WmWWWWWWWWWWmW',
		'WmWmmmmmmmmWmW',
		'WmWmmmmmmmBWmW',
		'WmWmmmmmmmBWmW',
		'WmWmmmmmmmmWmW',
		'WmWmmmmmmmmWmW',
		'WmWmmmmmmmmWmW',
		'WmWmmmmmmmmWmW',
		'WmWWWWWWWWWWmW',
		'WmmmmmmmmmmmmW',
		'WWWWWWWWWWWWWW',
		'.WW........WW.',
	]
}

// couch (20×8): lounge seat, wood frame with manila cushions.
const env_couch = Sprite{
	name: 'env-couch'
	rows: [
		'..WWWWWWWWWWWWWWWW..',
		'.WmmmmmmmmmmmmmmmmW.',
		'.WmmmmmmmmmmmmmmmmW.',
		'WWWWWWWWWWWWWWWWWWWW',
		'.WmmmmmmmWWmmmmmmmW.',
		'.WmmmmmmmWWmmmmmmmW.',
		'.WWWWWWWWWWWWWWWWWW.',
		'..WW............WW..',
	]
}

// Setup-journey props. The hornero nest is the brand motif, the
// welcome desk is the builder station in the onboarding scene, the sign is the
// framed office plate, and the book stack dresses the shelf line.
const env_nest = Sprite{
	name: 'env-nest'
	rows: [
		'.....kk.......',
		'....kNNk......',
		'...kNNNNk.....',
		'..kNNNNNNk....',
		'..kNNNNNNkk...',
		'...kkNNNNNk...',
		'.WWWkkkkkkWWW.',
		'WmmWmmWmmWmmmW',
		'WmmmmmmmmmmmmW',
		'.WWmmmmmmmmWW.',
		'..WWWWWWWWWW..',
	]
}

const env_welcome_desk = Sprite{
	name: 'env-welcome-desk'
	rows: [
		'....WWWWWWWWWW....',
		'...WttttttttttW...',
		'...WtSSSSSSSStW...',
		'...WtSeeeeeeStW...',
		'...WtSSSSSSSStW...',
		'...WttttttttttW...',
		'....WWWWWWWWW.....',
		'WWWWWWWWWWWWWWWWWW',
		'WmmmmmmmmmmmmmmmmW',
		'WWWWWWWWWWWWWWWWWW',
		'W.WW..........WW.W',
		'W.WW..........WW.W',
	]
}

const env_sign = Sprite{
	name: 'env-sign'
	rows: [
		'WWWWWWWWWWWWWWWW',
		'WppppppppppppppW',
		'WpkkkkkkkkkkkkpW',
		'WppppppppppppppW',
		'WpkkkkkkkkkkpppW',
		'WppppppppppppppW',
		'WpkkkkkkkkkkkkpW',
		'WppppppppppppppW',
		'WWWWWWWWWWWWWWWW',
		'..W..........W..',
	]
}

const env_books = Sprite{
	name: 'env-books'
	rows: [
		'..........',
		'.rrr..ffff',
		'.rrr..ffff',
		'.rrr..ffff',
		'bbbbbbbbbb',
		'bbbbbbbbbb',
		'mmmmmmmmmm',
		'WWWWWWWWWW',
	]
}

// a small framed landscape — wall decor for the onboarding welcome scene,
// filling the bare stretch the capture matrix flagged as too empty
const env_picture = Sprite{
	name: 'env-picture'
	rows: [
		'WWWWWWWWWWWW',
		'WeeeeeeeeeeW',
		'WeeFFeeeFFeW',
		'WeeeFFeFFeeW',
		'WeMMMMMMMMeW',
		'WeMMMMMMMMeW',
		'WWWWWWWWWWWW',
	]
}

// Library props. The wide bookshelf is the anchor of the
// Library header banner (four shelves of mixed spines), the globe and scroll
// dress the shelves, the chalkboard carries the banner's decorative sign and
// the ladder leans against the tall shelf. Illustration only: shelf contents
// never encode catalog counts. Authored grids (pinned by
// test_authored_dimensions): bookshelf_wide 24×22, globe 10×12, scroll 12×8,
// chalkboard 20×12, ladder 6×16.

// wide bookshelf (24×22): light-frame variant is derived with with_materials.
const env_bookshelf_wide = Sprite{
	name: 'env-bookshelf-wide'
	rows: [
		'.WWWWWWWWWWWWWWWWWWWWWW.',
		'.W....................W.',
		'.WcrmfcaBcrfmcsarcfmBrW.',
		'.WcrmfcaBcrfmcsarcfmBrW.',
		'.WcrmfcaBcrfmcsarcfmBrW.',
		'.WWWWWWWWWWWWWWWWWWWWWW.',
		'.W....................W.',
		'.WfBcrsm..cfrBcmfsrcaBW.',
		'.WfBcrsm..cfrBcmfsrcaBW.',
		'.WfBcrsm..cfrBcmfsrcaBW.',
		'.WWWWWWWWWWWWWWWWWWWWWW.',
		'.W....................W.',
		'.WmcrfBsac...rfcBsmacrW.',
		'.WmcrfBsac...rfcBsmacrW.',
		'.WmcrfBsac...rfcBsmacrW.',
		'.WWWWWWWWWWWWWWWWWWWWWW.',
		'.W....................W.',
		'.WrfmcaBcsrfmcaBcsrfmcW.',
		'.WrfmcaBcsrfmcaBcsrfmcW.',
		'.WrfmcaBcsrfmcaBcsrfmcW.',
		'.WWWWWWWWWWWWWWWWWWWWWW.',
		'.WW..................WW.',
	]
}

// globe on a brass stand (10×12).
const env_globe = Sprite{
	name: 'env-globe'
	rows: [
		'....kk....',
		'..kkssskk.',
		'.ksssfsssk',
		'.kssffssfk',
		'.ksfffsssk',
		'.kssfsssfk',
		'..kssssk..',
		'....BB....',
		'....BB....',
		'...BBBB...',
		'..MMMMMM..',
		'..........',
	]
}

// rolled document (12×8).
const env_scroll = Sprite{
	name: 'env-scroll'
	rows: [
		'.kkkkkkkkk..',
		'kPPPPPPPPPk.',
		'kPkkkkkkkPk.',
		'kPPPPPPPPPk.',
		'kPkkkkkkPPk.',
		'kPPPPPPPPPk.',
		'.kkkkkkkkkk.',
		'............',
	]
}

// chalkboard sign (20×12): the banner overlays its two words as text.
const env_chalkboard = Sprite{
	name: 'env-chalkboard'
	rows: [
		'WWWWWWWWWWWWWWWWWWWW',
		'WttttttttttttttttttW',
		'WttttttttttttttttttW',
		'WttttttttttttttttttW',
		'WttttttttttttttttttW',
		'WttttttttttttttttttW',
		'WttttttttttttttttttW',
		'WttttttttttttttttttW',
		'WttttttttttttttttttW',
		'WWWWWWWWWWWWWWWWWWWW',
		'..WW............WW..',
		'..WW............WW..',
	]
}

// library ladder (6×16), leans against the tall shelf.
const env_ladder = Sprite{
	name: 'env-ladder'
	rows: [
		'w....w',
		'wwwwww',
		'w....w',
		'w....w',
		'wwwwww',
		'w....w',
		'w....w',
		'wwwwww',
		'w....w',
		'w....w',
		'wwwwww',
		'w....w',
		'w....w',
		'wwwwww',
		'w....w',
		'w....w',
	]
}

// environment_for returns the sprite for an environment asset.
pub fn environment_for(a EnvironmentAsset) Sprite {
	return match a {
		.desk { env_desk }
		.chair { env_chair }
		.terminal { env_terminal }
		.shelf { env_shelf }
		.plant { env_plant }
		.lamp { env_lamp }
		.cabinet { env_cabinet }
		.rug { env_rug }
		.meeting_table { env_meeting }
		.board { env_board }
		.tray { env_tray }
		.window { env_window }
		.door { env_door }
		.couch { env_couch }
		.nest { env_nest }
		.welcome_desk { env_welcome_desk }
		.sign { env_sign }
		.books { env_books }
		.picture { env_picture }
		.bookshelf_wide { env_bookshelf_wide }
		.globe { env_globe }
		.scroll { env_scroll }
		.chalkboard { env_chalkboard }
		.ladder { env_ladder }
		.server_rack { env_server_rack }
		.wall_clock { env_wall_clock }
		.gear_mark { env_gear_mark }
		.monitor_tower { env_monitor_tower }
		.checklist_board { env_checklist_board }
		.play_mark { env_play_mark }
		.calendar_mark { env_calendar_mark }
		.swarm_mark { env_swarm_mark }
		.alert_mark { env_alert_mark }
		.cabinet_tall { env_cabinet_tall }
		.folder_stack { env_folder_stack }
		.ledger { env_ledger }
		.chart_mark { env_chart_mark }
		.gear { env_gear }
	}
}

// all_sprites returns every authored sprite (asset-manifest completeness).
pub fn all_sprites() []Sprite {
	mut out := [
		agent_idle, agent_running, agent_waiting, agent_attention, agent_error,
		env_desk, env_chair, env_terminal, env_shelf, env_plant, env_lamp,
		env_cabinet, env_rug, env_meeting, env_board, env_tray, env_window, env_door, env_couch,
		env_nest, env_welcome_desk, env_sign, env_books, env_picture,
		env_bookshelf_wide, env_globe, env_scroll, env_chalkboard, env_ladder,
		env_cabinet_tall, env_folder_stack, env_ledger, env_chart_mark, env_gear,
	]
	out << library_mark_sprites()
	out << operations_sprites()
	return out
}

// all_environment_assets returns every EnvironmentAsset (mapping coverage).
pub fn all_environment_assets() []EnvironmentAsset {
	return [.desk, .chair, .terminal, .shelf, .plant, .lamp, .cabinet, .rug,
		.meeting_table, .board, .tray, .window, .door, .couch, .nest, .welcome_desk,
		.sign, .books, .picture, .bookshelf_wide, .globe, .scroll, .chalkboard, .ladder,
		.server_rack, .wall_clock, .gear_mark, .monitor_tower, .checklist_board,
		.play_mark, .calendar_mark, .swarm_mark, .alert_mark,
		.cabinet_tall, .folder_stack, .ledger, .chart_mark, .gear]
}

// all_agent_states returns every AgentVisualState (mapping coverage).
pub fn all_agent_states() []AgentVisualState {
	return [.idle, .running, .waiting, .attention, .error]
}
