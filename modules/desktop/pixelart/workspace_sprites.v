module pixelart

// Workspace / Insights / Settings props. Product/domain pixel
// marks (DESIGN.md §13 class 2) plus the tall filing cabinet that anchors the
// Workspace hero scene. Same craft rules as sprites.v: readable palette-key
// rows, one light direction (top-left), existing palette keys only.

// tall filing cabinet (12×16): wood frame, four manila drawers, brass pulls
// with a paper label slot on each drawer. Workspace header mark + hero scene.
const env_cabinet_tall = Sprite{
	name: 'env-cabinet-tall'
	rows: [
		'.WWWWWWWWWW.',
		'.WmmmmmmmmW.',
		'.WmeeBBeemW.',
		'.WmmmmmmmmW.',
		'.WWWWWWWWWW.',
		'.WmmmmmmmmW.',
		'.WmeeBBeemW.',
		'.WmmmmmmmmW.',
		'.WWWWWWWWWW.',
		'.WmmmmmmmmW.',
		'.WmeeBBeemW.',
		'.WmmmmmmmmW.',
		'.WWWWWWWWWW.',
		'.WmmmmmmmmW.',
		'.WmeeBBeemW.',
		'.WWWWWWWWWW.',
	]
}

// folder stack (14×10): two tabbed folders — manila under sage — on a
// manila base. Known-workspace card mark; also dresses the hero scene.
const env_folder_stack = Sprite{
	name: 'env-folder-stack'
	rows: [
		'...MMMM.......',
		'..MmmmmMMMMMM.',
		'..MmmmmmmmmM..',
		'..MMMMMMMMMMM.',
		'.FFFF.........',
		'FffffFFFFFFFF.',
		'FfffffffffffF.',
		'FFFFFFFFFFFFF.',
		'.MMMMMMMMMMMM.',
		'..............',
	]
}

// ledger (12×14): a bound account book — ink spine, wood cover, ruled paper
// page and a brass clasp. Insights header mark; empty-state prop.
const env_ledger = Sprite{
	name: 'env-ledger'
	rows: [
		'.kWWWWWWWWW.',
		'.kWppppppppW',
		'.kWpMMMMMMpW',
		'.kWppppppppW',
		'.kWpMMMMMMpW',
		'.kWppppppppW',
		'.kWpMMMMMMpW',
		'.kWppppppppW',
		'.kWpMMMMpppW',
		'.kWppppppppW',
		'.kWppppppBBW',
		'.kWppppppBBW',
		'.kWWWWWWWWWW',
		'............',
	]
}

// chart mark (14×12): three bars — slate, brass, sage — on an ink baseline.
// Insights metric-card and tab mark. Illustration only; bar heights are
// authored, never data.
const env_chart_mark = Sprite{
	name: 'env-chart-mark'
	rows: [
		'..............',
		'..........ff..',
		'..........ff..',
		'......BB..ff..',
		'......BB..ff..',
		'..cc..BB..ff..',
		'..cc..BB..ff..',
		'..cc..BB..ff..',
		'..cc..BB..ff..',
		'.kkkkkkkkkkkk.',
		'.k............',
		'..............',
	]
}

// gear (12×12): steel preferences mark with a slate hub. Settings sheet.
const env_gear = Sprite{
	name: 'env-gear'
	rows: [
		'.....ll.....',
		'..l.llll.l..',
		'..llllllll..',
		'.llllSSllll.',
		'llllSSSSllll',
		'llllSSSSllll',
		'.llllSSllll.',
		'..llllllll..',
		'..l.llll.l..',
		'.....ll.....',
		'............',
		'............',
	]
}
