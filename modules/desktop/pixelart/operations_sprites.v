module pixelart

// Operations props and marks. The Operations Floor is a
// command-center room, so it needs infrastructure furniture (server rack,
// monitor tower, checklist board, wall clock) that the Office set does not
// carry, plus four small product marks for the metric cards and the detail
// column (DESIGN.md §13 class 2). Same craft rules as the Office set: one
// palette, one-pixel ink outlines, flat fills, uniform row widths.
//
// Everything here is environment or identity. LED pixels on the rack and the
// glow on the monitor are material, like the glow on env_terminal — they never
// encode runtime state. Runtime truth is drawn by the caller from Engine data.

// server rack (12×20): tall steel cabinet, four dark bays with indicator LEDs.
const env_server_rack = Sprite{
	name: 'env-server-rack'
	rows: [
		'.llllllllll.',
		'.lSSSSSSSSl.',
		'.lSttttttSl.',
		'.lStfatttSl.',
		'.lSttttttSl.',
		'.lSSSSSSSSl.',
		'.lSttttttSl.',
		'.lStfftttSl.',
		'.lSttttttSl.',
		'.lSSSSSSSSl.',
		'.lSttttttSl.',
		'.lStfatttSl.',
		'.lSttttttSl.',
		'.lSSSSSSSSl.',
		'.lSttttttSl.',
		'.lStftfttSl.',
		'.lSttttttSl.',
		'.lSSSSSSSSl.',
		'.llllllllll.',
		'.kk......kk.',
	]
}

// wall clock (10×10): wood rim, paper face, ink hands.
const env_wall_clock = Sprite{
	name: 'env-wall-clock'
	rows: [
		'...WWWW...',
		'.WWeeeeWW.',
		'.WeeekeeW.',
		'WeeeekeeeW',
		'WeeeekeeeW',
		'WeeeekkkeW',
		'WeeeeeeeeW',
		'.WeeeeeeW.',
		'.WWeeeeWW.',
		'...WWWW...',
	]
}

// gear mark (16×16): the Operations product glyph — steel gear, slate hub.
const env_gear_mark = Sprite{
	name: 'env-gear-mark'
	rows: [
		'......kkkk......',
		'......kllk......',
		'..kk..kllk..kk..',
		'.kllkkkllkkkllk.',
		'.kllllllllllllk.',
		'..kllllllllllk..',
		'kkkllkkkkkkllkkk',
		'kllllkSSSSkllllk',
		'kllllkSSSSkllllk',
		'kkkllkkkkkkllkkk',
		'..kllllllllllk..',
		'.kllllllllllllk.',
		'.kllkkkllkkkllk.',
		'..kk..kllk..kk..',
		'......kllk......',
		'......kkkk......',
	]
}

// monitor tower (12×12): wide monitor on a stand over a small tower unit.
const env_monitor_tower = Sprite{
	name: 'env-monitor-tower'
	rows: [
		'.kkkkkkkkkk.',
		'.kttttttttk.',
		'.ktfffttttk.',
		'.kttttttttk.',
		'.ktfftttttk.',
		'.kttttttttk.',
		'.kkkkkkkkkk.',
		'.....ll.....',
		'...llllll...',
		'..SSSSSSSS..',
		'..SfSSSSaS..',
		'..SSSSSSSS..',
	]
}

// checklist board (18×14): wall-mounted dark board with four list rows —
// sage boxes and paper lines; the last box is blank paper. Decorative only.
const env_checklist_board = Sprite{
	name: 'env-checklist-board'
	rows: [
		'WWWWWWWWWWWWWWWWWW',
		'WttttttttttttttttW',
		'WtfftPPPPPPPPPtttW',
		'WtfftttttttttttttW',
		'WttttttttttttttttW',
		'WtfftPPPPPPPtttttW',
		'WtfftttttttttttttW',
		'WttttttttttttttttW',
		'WtfftPPPPPPPPPtttW',
		'WtfftttttttttttttW',
		'WttttttttttttttttW',
		'WteetPPPPPPttttttW',
		'WWWWWWWWWWWWWWWWWW',
		'.W..............W.',
	]
}

// play mark (12×12): sage tile with a paper play glyph — the Jobs mark.
const env_play_mark = Sprite{
	name: 'env-play-mark'
	rows: [
		'kkkkkkkkkkkk',
		'kffffffffffk',
		'kfffkkfffffk',
		'kfffkekffffk',
		'kfffkeekfffk',
		'kfffkeeekffk',
		'kfffkeeekffk',
		'kfffkeekfffk',
		'kfffkekffffk',
		'kfffkkfffffk',
		'kffffffffffk',
		'kkkkkkkkkkkk',
	]
}

// calendar mark (12×12): rust header band, paper grid — the Loops mark.
const env_calendar_mark = Sprite{
	name: 'env-calendar-mark'
	rows: [
		'..kk....kk..',
		'kkkkkkkkkkkk',
		'kaaaaaaaaaak',
		'kkkkkkkkkkkk',
		'kPPPPPPPPPPk',
		'kPkkPkkPkkPk',
		'kPPPPPPPPPPk',
		'kPkkPkkPkkPk',
		'kPPPPPPPPPPk',
		'kPkkPffPkkPk',
		'kPPPPPPPPPPk',
		'kkkkkkkkkkkk',
	]
}

// swarm mark (12×12): three linked nodes — the Swarms mark.
const env_swarm_mark = Sprite{
	name: 'env-swarm-mark'
	rows: [
		'....kkkk....',
		'...kcccck...',
		'...kcccck...',
		'....kkkk....',
		'.....kk.....',
		'....k..k....',
		'...k....k...',
		'.kkkk..kkkk.',
		'kccck..kccck',
		'kccck..kccck',
		'kccck..kccck',
		'.kkk....kkk.',
	]
}

// alert mark (12×12): rust warning triangle with a paper exclamation — the
// Doctor mark.
const env_alert_mark = Sprite{
	name: 'env-alert-mark'
	rows: [
		'.....kk.....',
		'....kaak....',
		'....kaak....',
		'...kaeeak...',
		'...kaeeak...',
		'..kaaeeaak..',
		'..kaaeeaak..',
		'.kaaaaaaaak.',
		'.kaaaeeaaak.',
		'kaaaaaaaaaak',
		'kaaaaaaaaaak',
		'kkkkkkkkkkkk',
	]
}

// operations_sprites lists the Operations additions for the asset manifest.
fn operations_sprites() []Sprite {
	return [env_server_rack, env_wall_clock, env_gear_mark, env_monitor_tower, env_checklist_board,
		env_play_mark, env_calendar_mark, env_swarm_mark, env_alert_mark]
}
